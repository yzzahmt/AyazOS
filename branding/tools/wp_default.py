"""Default wallpaper: port of the website's Three.js spiral galaxy, rendered with additive glow."""
from lib import *
from galaxylib import *
import galaxylib

rng = np.random.default_rng(2024)
SC = 85
gal = build_galaxy(SC, rng, density=2.2)
neb = build_nebula(SC, rng, n=260)
# camera: galaxy sits right of centre so the top-left stays calm
cam = Cam(W * 0.60, H * 0.54, zoom=1.12)
lay = render_galaxy(cam, gal, (0.60, -0.16, 0.55), neb, star_gain=1.0, mult_size=1.0, rng=rng)

bg = bg_stars(5200, 77, mag_pow=3.0, bright=0.95, sizemul=0.85)
# extra far stars like the site's background sphere
lin = lay + bg
lin = bloom(lin, 0.55, thresh=0.05)

# deep violet-space base + faint vertical wash
X, Y = grid()
base = np.zeros((H, W, 3), np.float32)
base[...] = np.array([2, 1, 10], np.float32) / 255 * 0.5
cloud = up(fbm(*grid(*half()) , 5, seed=9) ) if False else None
lin = lin + base

# composition masks: calm top-left, darker right edge for the dock
tl = smoothstep(0.0, 1.0, np.clip(np.hypot((X + 1.78) / 1.5, (Y + 1.0) / 1.0), 0, 1))
mask = 0.28 + 0.72 * tl
re = 1 - 0.65 * smoothstep(0.72, 1.0, (X / (W / H)) * 0.5 + 0.5)
lin = lin * (mask * re)[..., None]
# gentle blue-violet ambient glow behind galaxy
d2 = ((X - (cam.cx - W/2) / (H/2)) ** 2 + (Y - (cam.cy - H/2) / (H/2)) ** 2)
lin += (np.exp(-d2 / 0.55)[..., None] * np.array([.012, .008, .03], np.float32)) * re[..., None]

finish(lin, "wallpapers/default.jpg", exposure=1.05, grain=0.009, vig=0.38)
