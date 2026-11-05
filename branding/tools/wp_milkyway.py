from lib import *
hw, hh = half()
X, Y = grid(hw, hh)
# band along a diagonal arc
ang = math.radians(-24)
u = X * math.cos(ang) + Y * math.sin(ang)          # along band
v = -X * math.sin(ang) + Y * math.cos(ang)          # across band
v = v - 0.10 * np.sin(u * 1.1 + 0.6) - 0.05 * fbm(u * 1.2, v * 0.5, 3, seed=2)
width = 0.25 + 0.09 * fbm(u * 0.8 + 4, v * 0.3, 3, seed=6)
prof = np.exp(-(v / width) ** 2)
prof2 = np.exp(-(v / (width * 0.42)) ** 2)
core = np.exp(-(((u + 0.35) / 0.9) ** 2)) * 0.8 + 0.3
clouds = fbm(u * 2.5, v * 3.5, 7, seed=3) * 0.5 + 0.5
fine = fbm(u * 7, v * 9, 5, seed=13) * 0.5 + 0.5
dust = smoothstep(0.35, 0.75, fbm(u * 3.2 + 1, v * 6, 6, seed=9, ridged=True) * 0.8 + 0.25 * fbm(u * 8, v * 11, 4, seed=10))
dust_lane = np.exp(-((v - 0.03 * np.sin(u * 3)) / (width * 0.20)) ** 2) * (0.55 + 0.45 * clouds)
light = prof * (0.35 + 0.9 * clouds) * (0.5 + 0.7 * core) + prof2 * 0.7 * fine * core
light = light * (1 - 0.82 * np.clip(dust_lane + dust * prof * 0.9, 0, 1))
col = ramp(np.clip(light * 0.5, 0, 1), [(0, (0.0, 0.0, 0.0)), (0.12, (0.04, 0.05, 0.16)), (0.35, (0.18, 0.18, 0.40)), (0.6, (0.50, 0.42, 0.62)), (0.85, (0.88, 0.74, 0.62)), (1, (1.0, 0.9, 0.75))])
# warm core vs blue edges
warm = smoothstep(0.0, 1.0, prof2 * core)[..., None]
col = col * (0.75 + 0.55 * warm) * np.array([1.0, 1.0, 1.0], np.float32)
# magenta/teal airglow wash
wash = fbm(X * 0.9, Y * 0.9, 3, seed=41) * 0.5 + 0.5
col += (np.array([0.05, 0.01, 0.07], np.float32) * wash[..., None] + np.array([0.0, 0.025, 0.05], np.float32) * (1 - wash[..., None])) * 0.8
mw = up(col * 0.85)
# star density follows the band
st_bg = bg_stars(14000, 5, mag_pow=3.0, bright=1.0)
rng = np.random.default_rng(88)
n = 220000
sx = rng.random(n) * W; sy = rng.random(n) * H
xi = np.clip((sx / W * hw).astype(int), 0, hw - 1); yi = np.clip((sy / H * hh).astype(int), 0, hh - 1)
dens = (0.12 + 1.3 * light[yi, xi]) * (1 - 0.7 * dust[yi, xi])
keep = rng.random(n) < dens * 0.55
sx, sy = sx[keep], sy[keep]
m = rng.random(len(sx)) ** 4.2
tt = rng.random(len(sx))
cols = np.where(tt[:, None] < .25, [1.0, .78, .6], np.where(tt[:, None] < .65, [1, .96, .93], [.7, .82, 1.0])) * (0.04 + 0.9 * m)[:, None]
st_band = splat((H, W), sx, sy, cols.astype(np.float32), (0.65 + 1.3 * m) * U)
lin = mw + st_bg + st_band
# a few bright named-looking stars with spikes
bx = rng.random(24) * W; by = rng.random(24) * H
lin = spikes(lin, bx, by, np.tile([[1, .95, .9]], (24, 1)) * 0.6, (30 + 140 * rng.random(24)) * U)
lin += splat((H, W), bx, by, np.tile([[1, .95, .9]], (24, 1)) * 1.2, np.full(24, 1.5 * U)) + splat((H, W), bx, by, np.tile([[.6, .7, 1]], (24, 1)) * 0.14, np.full(24, 9 * U))
lin = bloom(lin, 0.35, thresh=0.05)
lin += np.array([0.002, 0.003, 0.009], np.float32)
finish(lin, "wallpapers/milky-way.jpg", exposure=1.15, grain=0.012, vig=0.38)
