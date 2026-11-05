from lib import *
from bhrender import render_bh
stars = bg_stars(4200, 301, mag_pow=3.2, bright=1.0, sizemul=0.9)
stars = stars + bg_stars(220, 302, mag_pow=1.8, bright=0.9)
rs = 0.068 * H
img, hor = render_bh(W, H, rs, W * 0.5, H * 0.53, roll=math.radians(-13), elev=9.5, rot=0.0, stars=stars)
# bloom + anamorphic streak
bright = np.maximum(img - 0.25, 0)
streak = ndi.gaussian_filter1d(blur(bright, 3 * U), 260 * U, axis=1, mode="nearest") * 1.6
halo = bloom(img, 0.6, thresh=0.1) - img + streak * np.array([.55, .45, 1.0], np.float32) * 0.5
X, Y = grid()
shadow = blur(hor.astype(np.float32), 2.5 * U)[..., None]
lin = img + halo * (1 - 0.92 * shadow)
lin = lin + (np.exp(-(X ** 2 + Y ** 2) / 1.2)[..., None] * np.array([.004, .0015, .012], np.float32))
finish(lin, "wallpapers/black-hole.jpg", exposure=1.35, grain=0.010, vig=0.45)
