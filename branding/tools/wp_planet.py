from lib import *
X, Y = np.meshgrid(np.arange(W, dtype=np.float32) + .5, np.arange(H, dtype=np.float32) + .5)
Rp = 1.05 * W
cx, cy = 0.5 * W, 0.80 * H + Rp
d = np.hypot(X - cx, Y - cy)
alt = (d - Rp)                                  # px above surface (negative = ground)
ang = np.arctan2(X - cx, -(Y - cy))             # angle around planet centre (0 = up)
sun_ang = (0.30 * W - cx) / Rp
da = (ang - sun_ang) * Rp                       # arc distance from sun along limb, px
sunfac = 0.10 + 0.90 * np.exp(-(da / (0.34 * W)) ** 2)
sharp = np.exp(-(da / (0.07 * W)) ** 2)
Hs = 46 * U
a = np.clip(alt, 0, None)
atm = np.exp(-a / Hs)
atm_w = np.exp(-a / (Hs * 0.16))                # thin hot rim
# colour by altitude
col_alt = ramp(1 - np.exp(-a / (Hs * 1.8)), [(0, (1.0, 0.93, 0.78)), (0.12, (0.65, 0.88, 1.0)), (0.4, (0.22, 0.45, 1.0)), (0.75, (0.12, 0.14, 0.62)), (1, (0.05, 0.04, 0.3))])
rim = col_alt * (atm * 0.55 + atm_w * 1.6)[..., None] * sunfac[..., None]
rim *= (alt >= -0.8 * U)[..., None] * smoothstep(-1.5 * U, 1.0 * U, alt)[..., None]
# far airglow (wide, faint)
glow = np.exp(-a / (Hs * 9)) * 0.10 * sunfac
glow_c = np.array([0.18, 0.25, 0.75], np.float32)
sky = glow[..., None] * glow_c * (alt > 0)[..., None]
sky += np.array([0.002, 0.004, 0.012], np.float32)
# ground: dark clouds lit by the glow just under the limb
g = np.clip(-alt, 0, None)
gx = (X / W) * 5.0; 
persp = 1.0 / (0.18 + g / (0.9 * H))                         # compress toward horizon
hwq, hhq = half()
cl = fbm(((X - cx) / Rp * 12 * persp * 0.5)[::2, ::2], (persp * 1.4)[::2, ::2] + (g / H * 0.3)[::2, ::2], 6, seed=3) * 0.5 + 0.5
cl = resize(cl, W, H)
cl2 = resize(fbm(((X - cx) / Rp * 38 * persp * 0.5)[::2, ::2], (persp * 3.1)[::2, ::2], 5, seed=8)[...], W, H) * 0.5 + 0.5
cloud = smoothstep(0.35, 0.8, cl * 0.7 + cl2 * 0.4)
lit = np.exp(-g / (0.09 * H)) * sunfac
ground_c = ramp(np.clip(lit * 1.5, 0, 1), [(0, (0.004, 0.007, 0.018)), (0.3, (0.02, 0.05, 0.14)), (0.7, (0.12, 0.2, 0.5)), (1, (0.75, 0.75, 0.9))])
ground = ground_c * (0.35 + 0.9 * cloud)[..., None]
ground += np.array([0.0015, 0.003, 0.009], np.float32)
# city lights on night side, clustered
rng = np.random.default_rng(31)
N = 9000
lx = rng.random(N) * W; ly = H * (0.80 + 0.2 * rng.random(N) ** 0.8)
m = (np.hypot(lx - cx, ly - cy) < Rp - 8)
lx, ly = lx[m], ly[m]
cluster = fbm(lx / W * 6, ly / H * 6, 3, seed=2)
sel = (cluster > 0.12) & (rng.random(len(lx)) < 0.6) & (ly > 0.835 * H)
lights = splat((H, W), lx[sel], ly[sel], np.tile([1.0, 0.7, 0.4], (sel.sum(), 1)) * (0.03 + 0.25 * rng.random(sel.sum()) ** 3)[:, None] * 0.5, np.full(sel.sum(), 0.9 * U))
lights *= (1 - lit)[..., None] ** 2 * (alt < 0)[..., None]
isg = (alt < 0)[..., None]
lin = np.where(isg, ground + lights, sky + rim)
lin = lin + rim * isg * 0.6                       # rim spills slightly onto the limb edge
# stars above the horizon
st = bg_stars(11000, 55, mag_pow=3.1, bright=1.0)
ext = smoothstep(0, 0.35 * H, -(Y - (cy - Rp - 0)) + 0)  # unused guard
horizon_y = cy - np.sqrt(np.maximum(Rp ** 2 - (X - cx) ** 2, 0))
above = np.clip((horizon_y - Y) / (0.45 * H), 0, 1) ** 0.7
lin = lin + st * (above * (alt > 0))[..., None]
# the sun just breaking over the limb
sx = 0.30 * W; sy = cy - np.sqrt(Rp ** 2 - (sx - cx) ** 2) - 4 * U
r2 = np.hypot(X - sx, Y - sy)
sun = (np.exp(-(r2 / (7 * U)) ** 2) * 6 + np.exp(-(r2 / (30 * U)) ** 2) * 1.6 + np.exp(-r2 / (150 * U)) * 0.30)
sunc = np.array([1.0, 0.93, 0.8], np.float32)
sun_l = sun[..., None] * sunc * (Y < sy + 40 * U)[..., None]
sun_l *= (alt > -2 * U)[..., None]
# horizontal flare along limb + short spikes
streak = np.exp(-np.abs(Y - sy) / (2.2 * U)) * np.exp(-np.abs(X - sx) / (520 * U)) * 1.2
streak2 = np.exp(-np.abs(Y - sy) / (7 * U)) * np.exp(-np.abs(X - sx) / (1100 * U)) * 0.18
sun_l += (streak + streak2)[..., None] * np.array([0.8, 0.88, 1.0], np.float32) * (alt > -2 * U)[..., None]
lin = lin + sun_l
lin = bloom(lin, 0.5, thresh=0.1)
finish(lin, "wallpapers/planet-dawn.jpg", exposure=1.25, grain=0.010, vig=0.35)
