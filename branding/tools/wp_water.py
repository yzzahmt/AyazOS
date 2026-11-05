"""Calm dark liquid with blue highlights."""
from lib import *
X, Y = grid()
Xp = X * (H / 2); Yp = Y * (H / 2)           # px units relative to centre
rng = np.random.default_rng(909)
h = np.zeros((H, W), np.float32)
drops = [(-0.55, -0.2, 1.0, 520), (0.5, 0.15, 0.85, 480), (0.05, 0.5, 0.6, 420), (1.15, -0.45, 0.7, 380), (-1.2, 0.4, 0.55, 360), (0.0, -0.9, 0.5, 340)]
for dx, dy, amp, wl in drops:
    r = np.hypot(Xp - dx * H / 2, Yp - dy * H / 2) / U
    front = 1500 * (0.55 + 0.6 * amp)
    k = 2 * math.pi / (wl * 0.20)
    env = np.exp(-r / 700) * smoothstep(front, front - 500, r) * (1 - np.exp(-r / 40))
    h += amp * np.sin(k * r - 1.7 * dx) * env * (1 + 0.25 * np.sin(r / 90))
# interference swell + slow noise + tiny capillary ripples
h += 0.30 * fbm(X * 2.2, Y * 2.2, 4, seed=3)
h += 0.045 * fbm(X * 24, Y * 24, 3, seed=9)
h *= 1.0
gy, gx = np.gradient(h)
slope = 38.0 * U
nx = -gx * slope; ny = -gy * slope
nz = np.ones_like(nx)
inv = 1 / np.sqrt(nx * nx + ny * ny + nz * nz)
nx *= inv; ny *= inv; nz *= inv
# lights
def spec(Lx, Ly, Lz, p):
    hx, hy, hz = Lx, Ly, Lz + 1.0
    n = math.sqrt(hx * hx + hy * hy + hz * hz); hx /= n; hy /= n; hz /= n
    return np.clip(nx * hx + ny * hy + nz * hz, 0, 1) ** p
s1 = spec(-0.55, -0.45, 0.7, 260) * 1.4 + spec(-0.55, -0.45, 0.7, 40) * 0.12
s2 = spec(0.7, 0.35, 0.6, 180) * 0.8
fres = (1 - nz) ** 0.6
env_col = np.stack([0.02 + 0.03 * (ny * 3 + 0.5), 0.05 + 0.07 * (ny * 3 + 0.5), 0.12 + 0.12 * (nx * 3 + 0.5)], -1)
base = np.array([0.003, 0.008, 0.02], np.float32)
col = base + env_col * (0.35 + 1.4 * fres[..., None]) * 0.5
col += s1[..., None] * np.array([0.55, 0.72, 1.0], np.float32) + s2[..., None] * np.array([0.52, 0.34, 0.95], np.float32)
# caustic-ish bright lines from curvature
lap = ndi.laplace(blur(h, 1.2 * U)) * 160.0 * U * U
col += np.clip(lap, 0, 1)[..., None] ** 1.6 * np.array([0.12, 0.28, 0.6], np.float32) * 0.55
# broad light falloff
Lg = np.exp(-((X + 0.6) ** 2 + (Y + 0.35) ** 2) / 1.6)
col *= (0.35 + 0.9 * Lg)[..., None]
col = bloom(col, 0.3, thresh=0.15)
finish(col, "wallpapers/water.jpg", exposure=1.15, grain=0.011, vig=0.45)
