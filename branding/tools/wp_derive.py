"""Blurred/darkened default (lock screen, low-power) + 1920x1080 thumbnails of every wallpaper."""
import glob, os
from lib import *
src = outpath("wallpapers/default.jpg")
im = np.asarray(Image.open(src).convert("RGB"), np.float32) / 255
lin = np.power(im, 2.2)
b = blur(lin, 38 * (W / 3840.0))
lum = b.mean(-1, keepdims=True)
b = lum + (b - lum) * 0.85                      # slight desaturation
b = b * 0.55 + np.array([0.004, 0.003, 0.012], np.float32)
x = grain_dither(srgb(np.clip(b, 0, 1)), 0.006, 3)
save_jpg(x, "wallpapers/default-blur.jpg", 90)
for p in sorted(glob.glob(os.path.join(OUT, "wallpapers", "*.jpg"))):
    n = os.path.basename(p)
    if n.endswith("-blur.jpg"): continue
    t = Image.open(p).convert("RGB").resize((1920, 1080), Image.LANCZOS)
    tp = outpath("wallpapers/thumbs/" + n); t.save(tp, "JPEG", quality=88, subsampling=0, optimize=True)
    print("thumb", tp, flush=True)
