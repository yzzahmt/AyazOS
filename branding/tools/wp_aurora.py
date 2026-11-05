from lib import *
Xp, Yp = np.meshgrid(np.arange(W, dtype=np.float32) + .5, np.arange(H, dtype=np.float32) + .5)
xn = Xp / H; yn = Yp / H                       # px / H units
y0 = 0.80                                     # lake line (fraction of H)
# ---- sky gradient
t = np.clip(yn / 0.8, 0, 1)
sky = ramp(t, [(0, (0.004, 0.008, 0.026)), (0.5, (0.008, 0.026, 0.07)), (0.85, (0.02, 0.07, 0.12)), (1, (0.03, 0.10, 0.14))])
# ---- stars
st = bg_stars(13000, 17, mag_pow=3.0, bright=1.0)
lin = sky + st * np.clip(1.25 - yn / 0.75, 0, 1)[..., None] ** 1.3
# ---- aurora curtains (half-res fields, x-detail via full-res noise)
hw, hh = half()
xs = (np.arange(hw, dtype=np.float32) + .5) / hh * 1.0; ys = (np.arange(hh, dtype=np.float32) + .5) / hh
XH, YH = np.meshgrid(xs, ys)
def curtain(seed, base, amp, hgt, c_lo, c_mid, c_hi, gain, shear):
    yb = base + 1.4 * amp * fbm(XH * 1.3, XH * 0 + seed, 3, seed=seed)                  # bottom edge curve y(x)
    yb = yb + 0.0 * YH
    xx = XH + (yb - YH) * shear                                                        # shear toward top
    rays = np.clip(fbm(xx * 40, YH * 1.1 + seed, 5, seed=seed + 3) * 1.5 + 0.55, 0, 1)
    rays2 = fbm(xx * 70, YH * 2.0, 3, seed=seed + 5) * 0.5 + 0.5
    ray = (0.10 + 1.3 * rays ** 2.0) * (0.6 + 0.6 * rays2)
    wav = fbm(xx * 2.2, YH * 0.6, 4, seed=seed + 9) * 0.5 + 0.5
    hh_ = hgt * (0.55 + 0.9 * wav)
    d = yb - YH                                            # >0 above the edge
    prof = np.where(d > 0, np.exp(-d / hh_), np.exp(-(-d) / 0.012)) * smoothstep(-0.03, 0.0, d)
    prof *= smoothstep(0.0, 0.03, d + 0.03)
    k = np.clip(d / (hh_ * 1.6), 0, 1)
    col = np.where((k < 0.35)[..., None], mix(c_lo, c_mid, (k / 0.35)[..., None]), mix(c_mid, c_hi, ((k - 0.35) / 0.65)[..., None]))
    return col * (prof * ray * gain)[..., None]
A = curtain(11, 0.50, 0.09, 0.075, np.array([.25, 1.0, .55]), np.array([.1, .85, .85]), np.array([.55, .25, 1.0]), 2.0, 0.18)
B = curtain(23, 0.38, 0.07, 0.07, np.array([.2, .95, .7]), np.array([.15, .6, 1.0]), np.array([.75, .2, .9]), 1.2, -0.12)
C = curtain(37, 0.585, 0.05, 0.045, np.array([.3, 1.0, .5]), np.array([.2, .9, .6]), np.array([.2, .6, 1.0]), 1.0, 0.05)
aur = up(A + B + C)
aur = blur(aur, 1.5 * U) + blur(aur, 28 * U) * 0.22
lin = lin + aur * (yn < y0)[..., None]
amb = blur(aur[::8, ::8], 6)  # coarse ambient (for scene lighting)
amb_full = resize(amb, W, H)
# ---- mountains
def ridge(seed, base, amp, freq, rough):
    x = (np.arange(W, dtype=np.float32) + .5) / H
    n = (fbm(x * freq, np.full_like(x, seed * 3.1), 7, seed=seed, ridged=True)) ** 1.6
    big = fbm(x * freq * 0.35, np.full_like(x, seed + 0.5), 3, seed=seed + 4)
    return base - amp * (n * 1.0 + 0.5 * big) * rough
layers = [
    (101, 0.60, 0.30, 1.0, 1.0, (0.035, 0.06, 0.11), 0.75),
    (131, 0.67, 0.27, 1.4, 1.0, (0.02, 0.04, 0.075), 0.65),
    (151, 0.74, 0.22, 2.0, 1.0, (0.01, 0.02, 0.04), 0.45),
    (171, 0.80, 0.13, 2.8, 1.0, (0.004, 0.008, 0.016), 0.25),
]
aur_tint = np.array([0.35, 0.95, 0.75], np.float32)
for seed, base, amp, freq, rough, rock, snowk in layers:
    r = ridge(seed, base, amp, freq, rough)                       # ridge height per column (fraction of H)
    depth = (yn - r[None, :])                                      # >0 below the ridge line
    mask = smoothstep(-0.0008, 0.0012, depth)[..., None]
    tex = fbm(xn * 9, yn * 38, 5, seed=seed + 8) * 0.5 + 0.5       # strata-like
    snow = smoothstep(0.05, 0.0, depth) * smoothstep(0.25, 0.7, tex * 0.8 + fbm(xn * 22, yn * 22, 4, seed=seed + 2) * 0.3 + 0.2)
    snow = np.clip(snow, 0, 1)
    light = np.clip(amb_full.mean(-1, keepdims=True) * 2.2, 0, 1) ** 0.8
    rockc = np.array(rock, np.float32) * 0.45 * (0.6 + 0.8 * tex[..., None])
    icec = np.array([0.40, 0.58, 0.80], np.float32) * (light * 0.28 + 0.03) + aur_tint * amb_full * 0.20
    c = mix(rockc + aur_tint * amb_full * 0.025, icec * (0.4 + 0.8 * tex[..., None]), (snow * snowk * 2.0).clip(0, 1)[..., None])
    # rim light on the ridge line
    rim = np.exp(-np.abs(depth) / 0.0016) * (depth > -0.001)
    c = c + (rim * 0.5)[..., None] * (aur_tint * 0.6 + 0.4) * (light + 0.05)
    # haze between layers
    hz = np.array([0.04, 0.10, 0.12], np.float32) * (1 - snowk) * np.exp(-np.clip(depth, 0, 1) / 0.12)[..., None] * 0.03
    c = c + hz
    lin = lin * (1 - mask) + c * mask
# ---- lake reflection
yl = int(y0 * H)
src = lin[:yl].copy()
hgt_ref = H - yl
refl = src[::-1][:hgt_ref].copy()                                    # mirrored rows
rows = np.arange(hgt_ref, dtype=np.float32)[:, None]
xs_ = np.arange(W, dtype=np.float32)[None, :]
rip = fbm(xs_ / H * 5.0 + rows * 0.0, rows / H * 70, 4, seed=71)
dx = rip * (6 + rows * 0.03) * U
map_x = np.clip(xs_ + dx, 0, W - 1); map_y = np.broadcast_to(rows, (hgt_ref, W))
for c in range(3):
    refl[..., c] = ndi.map_coordinates(refl[..., c], [map_y, map_x], order=1, mode="nearest")
refl = mix(refl, blur(refl, 5 * U), np.clip(rows / (0.2 * H), 0, 1)[..., None])
fade = np.exp(-rows / (0.28 * H))[..., None] * 0.55 + 0.12
lake = refl * fade * np.array([0.8, 0.95, 1.0], np.float32) + np.array([0.003, 0.009, 0.015], np.float32)
# soft shoreline blend
lin[yl:] = lake
edge = np.exp(-((np.arange(H) - yl) / (3 * U)) ** 2)[:, None, None] * 0.03
lin = lin + edge * np.array([0.3, 0.6, 0.6], np.float32) * amb_full.mean(-1, keepdims=True)
lin = bloom(lin, 0.35, thresh=0.04)
finish(lin, "wallpapers/aurora.jpg", exposure=1.2, grain=0.010, vig=0.38)
