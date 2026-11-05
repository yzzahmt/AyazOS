"""Plymouth boot animation assets: seamless 48-frame lensed black hole loop, welcome text, password-box parts."""
import os, subprocess
from lib import *
from bhrender import bh_geometry, bh_shade

OUTD = outpath("plymouth/ayazos/x").rsplit("/", 1)[0]
N = 48; SZ = 400; SS = 3
S = SZ * SS
rs = S * 0.5 * 0.94 / 8.6
geo = bh_geometry(S, S, rs, S / 2, S / 2, roll=math.radians(-14), elev=13.0, r_in=3.0, r_out=8.6)
STEP = 0.06                                         # pattern phase per frame

def lens_dim():
    yy, xx = np.mgrid[:SZ, :SZ].astype(np.float32)
    r = np.hypot(xx - SZ / 2 + .5, yy - SZ / 2 + .5) / (SZ / 2)
    return (1 - smoothstep(0.80, 1.0, r))[..., None]
edge = lens_dim()

def frame_lin(t):
    img = bh_shade(geo, t * STEP)
    return img

def small(lin_hi):
    x = resize(lin_hi, SZ, SZ, Image.BOX)             # 3x supersample -> 400
    return x

# seamless loop: crossfade the current cycle with the previous one
cache = {}
def get(t):
    if t not in cache: cache[t] = small(frame_lin(t))
    return cache[t]

for k in range(N):
    w = k / N
    lin = (1 - w) * get(k) + w * get(k - N)
    halo = blur(np.maximum(lin - 0.15, 0), 7) * 0.8 + blur(np.maximum(lin - 0.05, 0), 22) * 0.6
    lin = lin + halo
    # keep the event horizon dark: halo should not fill the shadow
    sh = resize(geo["hor"].reshape(S, S).astype(np.float32), SZ, SZ, Image.BOX)
    sh = blur(sh, 1.2)[..., None]
    lin = lin - halo * sh * 0.9
    lin = np.maximum(lin, 0)
    d = srgb(tonemap(lin, 1.45)) * edge
    # unpremultiply against black: alpha = max channel
    a = d.max(-1, keepdims=True)
    rgb = np.where(a > 1e-4, d / np.maximum(a, 1e-4), 0)
    out = np.concatenate([rgb, a], -1)
    rng = np.random.default_rng(k)
    out8 = np.clip(out * 255 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(out8, "RGBA").save(os.path.join(OUTD, "bh-%02d.png" % k), optimize=True)
    print("frame", k, flush=True)
