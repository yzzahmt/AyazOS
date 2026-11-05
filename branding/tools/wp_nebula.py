from lib import *
hw, hh = half()
X, Y = grid(hw, hh)
# domain-warped fbm clouds
def clouds(sx, sy, seed, warp=0.95):
    px = X * sx + sy * 0.0; py = Y * sx
    q = fbm(px + 3.1, py + 1.7, 5, seed=seed)
    r = fbm(px + warp * q + 8.3, py + warp * q + 2.8, 5, seed=seed + 7)
    return fbm(px + warp * r, py + warp * r, 6, seed=seed + 13), q, r
f, q, r = clouds(1.25, 1.25, 21)
f2, _, _ = clouds(1.9, 1.9, 77, 1.2)
# large scale composition: diagonal cloud band lower-left -> upper-right, calmer top-left
band = np.exp(-(((Y + 0.28 * X - 0.12)) ** 2) / 0.28)
dens = np.clip((f * 0.5 + 0.5) * 1.25 - 0.28, 0, 1) * (0.35 + 0.9 * band)
dens2 = np.clip((f2 * 0.5 + 0.5) * 1.3 - 0.30, 0, 1) * (0.2 + 0.9 * np.exp(-((Y - 0.35 * X + 0.1) ** 2) / 0.4))
dust = smoothstep(0.1, 0.7, fbm(X * 2.2 + 5, Y * 2.2, 5, seed=5, ridged=True))
mixc = smoothstep(-0.4, 0.5, fbm(X * 0.9, Y * 0.9, 3, seed=44))[..., None]
A = ramp(dens, [(0, (0.0, 0.0, 0.0)), (0.18, (0.05, 0.02, 0.20)), (0.42, (0.28, 0.08, 0.62)), (0.7, (0.58, 0.30, 1.0)), (0.9, (0.85, 0.65, 1.0)), (1, (1, 0.95, 1.0))])
B = ramp(dens2, [(0, (0.0, 0.0, 0.0)), (0.2, (0.0, 0.04, 0.2)), (0.5, (0.06, 0.26, 0.8)), (0.8, (0.30, 0.62, 1.0)), (1, (0.8, 0.95, 1.0))])
neb = mix(A * 1.0, B * 1.1, mixc) * (dens ** 1.0 * 1.2 + dens2 * 0.5)[..., None] ** 0.5
neb = A * (dens * 1.6)[..., None] * (1 - 0.6 * mixc) + B * (dens2 * 1.8 + dens * 0.5)[..., None] * (0.4 + 0.6 * mixc)
# magenta HII hot spots
hot = smoothstep(0.55, 0.95, f * 0.5 + 0.5) * band
neb += np.array([0.8, 0.2, 0.55], np.float32) * (hot ** 1.5 * 0.5)[..., None]
neb *= (1 - 0.75 * dust)[..., None] ** 1.2
neb = up(neb)
# fine detail at full res
Xf, Yf = grid()
det = fbm(Xf * 9, Yf * 9, 4, seed=91) * 0.5 + 0.5
neb *= (0.86 + 0.28 * det)[..., None]
lin = neb * 0.9
# stars
st = bg_stars(11000, 12, mag_pow=3.0, bright=1.0, sizemul=0.9)
# stars thinned inside dense dust, boosted in bright nebula
dmask = up(np.clip(1 - 0.8 * dust, 0.15, 1))[..., None]
lin = lin + st * dmask
lin = bloom(lin, 0.4, thresh=0.05)
lin += np.array([0.003, 0.002, 0.012], np.float32)
# calm top-left, darker right edge
tl = smoothstep(0.1, 1.4, np.hypot(Xf + 1.78, Yf + 1.0))
lin *= (0.35 + 0.65 * tl)[..., None]
finish(lin, "wallpapers/nebula.jpg", exposure=1.1, grain=0.011, vig=0.4)
