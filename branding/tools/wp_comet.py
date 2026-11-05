"""Interacting galaxy pair with a comet streaking through the foreground."""
from lib import *
from galaxylib import *
rng = np.random.default_rng(66)
SC = 85
lin = np.zeros((H, W, 3), np.float32)
# faint violet haze
hw, hh = half(); Xh, Yh = grid(hw, hh)
haze = np.clip(fbm(Xh * 1.1, Yh * 1.1, 6, seed=14) * 0.5 + 0.5 - 0.35, 0, 1)
lin += up(haze[..., None] * np.array([0.020, 0.012, 0.050], np.float32) * 1.6)
# big spiral (left) + companion (upper right)
g1 = build_galaxy(SC, rng, density=3.0); n1 = build_nebula(SC, rng, n=240)
cam1 = Cam(W * 0.36, H * 0.60, zoom=0.82)
lin += render_galaxy(cam1, g1, (0.95, 0.10, 0.9), n1, star_gain=0.5, core_gain=0.55, rng=rng)
g2 = build_galaxy(SC, rng, density=1.4, twist=1.6); n2 = build_nebula(SC, rng, twist=1.6, n=120)
cam2 = Cam(W * 0.70, H * 0.33, zoom=0.34)
l2 = render_galaxy(cam2, g2, (0.55, -0.35, -0.6), n2, star_gain=0.55, core_gain=0.5, rng=rng)
lin += l2 * np.array([0.85, 0.95, 1.2], np.float32)
# tidal bridge: stars strung between them
nb = 9000
t = rng.random(nb); sag = np.sin(t * math.pi) * 0.06 * H
bx = W * (0.36 + 0.34 * t) + rng.normal(0, 26 * U, nb); by = H * (0.60 - 0.27 * t) - sag + rng.normal(0, 30 * U, nb) * (0.4 + np.sin(t * math.pi))
bc = np.where((t < 0.5)[:, None], [0.9, 0.85, 1.0], [0.7, 0.8, 1.0]) * (0.02 + 0.10 * rng.random(nb) ** 2)[:, None]
lin += splat((H, W), bx, by, bc.astype(np.float32), 0.8 * U + 0.5 * rng.random(nb) * U)
lin += blur(splat((H, W), bx, by, bc.astype(np.float32) * 0.4, np.full(nb, 1.0 * U)), 12 * U) * 2.0
lin += bg_stars(9000, 4, mag_pow=3.1, bright=0.9)
# --- comet: head lower right, tail sweeping up-right-away
hx, hy = W * 0.80, H * 0.76
d = np.array([0.74, -0.67]); d /= np.linalg.norm(d)
nrm = np.array([-d[1], d[0]])
def tail(n, length, w0, w1, curve, col, amp, fall, sig):
    s = rng.random(n) ** 1.4
    pos = np.array([hx, hy])[None, :] + d[None, :] * (s * length)[:, None] + nrm[None, :] * (curve * (s * length) ** 2 / length)[:, None]
    wd = (w0 + (w1 - w0) * s) * U
    pos = pos + nrm[None, :] * (rng.normal(0, 1, n) * wd)[:, None] + d[None, :] * (rng.normal(0, 1, n) * wd * 2)[:, None]
    a = amp * np.exp(-s * fall) * (0.4 + 0.6 * rng.random(n))
    return splat((H, W), pos[:, 0], pos[:, 1], np.outer(a, col).astype(np.float32), np.full(n, sig * U))
Lg = 1.15 * W
ion = tail(60000, Lg, 4, 34, -0.02 * Lg * 0.0, np.array([0.30, 0.62, 1.0]), 0.09, 3.2, 1.0)
dust = tail(80000, Lg * 0.82, 14, 120, 0.45, np.array([1.0, 0.82, 0.62]), 0.05, 3.0, 1.8)
dust2 = tail(40000, Lg * 0.6, 8, 70, 0.22, np.array([0.9, 0.7, 0.9]), 0.05, 2.6, 1.4)
lin += ion + dust + dust2 + blur(ion, 14 * U) * 1.5 + blur(dust, 30 * U) * 1.2
# coma + nucleus
Xp, Yp = np.meshgrid(np.arange(W, dtype=np.float32), np.arange(H, dtype=np.float32))
r = np.hypot(Xp - hx, Yp - hy) / U
coma = (np.exp(-(r / 5.5) ** 2) * 10 + np.exp(-(r / 24) ** 2) * 1.8 + np.exp(-r / 80) * 0.22)
lin += coma[..., None] * np.array([0.88, 0.98, 1.0], np.float32)
lin += (np.exp(-r / 260) * 0.05)[..., None] * np.array([0.3, 0.7, 0.9], np.float32)
lin = bloom(lin, 0.45, thresh=0.06)
lin += np.array([0.002, 0.0015, 0.008], np.float32)
finish(lin, "wallpapers/comet-galaxies.jpg", exposure=1.1, grain=0.011, vig=0.42)
