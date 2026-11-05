#!/bin/bash
# welcome text + password box parts (run in the VM; needs rsvg-convert, fonts-inter, python3-pil)
set -e
D=~/brand/out/plymouth/ayazos; mkdir -p $D
cat > /tmp/welcome.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="760" height="96" viewBox="0 0 760 96">
  <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#C9D8FA"/></linearGradient></defs>
  <text x="380" y="62" text-anchor="middle" font-family="Inter, 'Inter Display', sans-serif" font-weight="300" font-size="46" letter-spacing="4.5" fill="url(#g)">Welcome to AyazOS</text>
</svg>
SVG
rsvg-convert /tmp/welcome.svg -o $D/welcome.png
python3 - <<'PY'
import os
from PIL import Image, ImageDraw, ImageFilter
D = os.path.expanduser("~/brand/out/plymouth/ayazos")
def rr(w, h, r, fill, outline, ss=4):
    im = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, w * ss - 1, h * ss - 1], r * ss, fill=fill, outline=outline, width=ss)
    return im.resize((w, h), Image.LANCZOS)
# glass panel behind the prompt
box = rr(520, 180, 26, (16, 22, 38, 215), (169, 193, 242, 70))
hl = Image.new("RGBA", box.size, (0, 0, 0, 0)); ImageDraw.Draw(hl).rounded_rectangle([2, 2, 517, 60], 24, fill=(255, 255, 255, 12))
box = Image.alpha_composite(box, hl); box.save(os.path.join(D, "box.png"))
# entry field
rr(400, 48, 24, (255, 255, 255, 14), (169, 193, 242, 90)).save(os.path.join(D, "entry.png"))
# bullet
b = Image.new("RGBA", (64, 64), (0, 0, 0, 0)); ImageDraw.Draw(b).ellipse([8, 8, 55, 55], fill=(232, 240, 255, 255))
b.resize((16, 16), Image.LANCZOS).save(os.path.join(D, "bullet.png"))
# lock-free spinner dot (used as simple progress dot)
PY
ls -la $D | head -5
