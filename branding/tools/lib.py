"""AyazOS branding: shared numpy rendering helpers (run inside the VM)."""
import os, sys, math
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SCALE = float(os.environ.get("SCALE", "1.0"))
W = int(round(3840 * SCALE)); H = int(round(2160 * SCALE))
U = H / 2160.0                      # pixel unit (1.0 == 4K pixel)
OUT = os.environ.get("OUT", os.path.expanduser("~/brand/out"))
PREV = SCALE < 1.0

def outpath(rel):
    p = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p

# ---------------------------------------------------------------- noise
_GT = np.array([(1,0),(-1,0),(0,1),(0,-1),(.7071,.7071),(-.7071,.7071),(.7071,-.7071),(-.7071,-.7071)], np.float32)

def _hash(ix, iy, seed):
    with np.errstate(over="ignore"):
        h = (ix.astype(np.uint32) * np.uint32(374761393)
             + iy.astype(np.uint32) * np.uint32(668265263)
             + np.uint32((seed * 2246822519 + 3266489917) & 0xFFFFFFFF))
        h = (h ^ (h >> np.uint32(13))) * np.uint32(1274126177)
        h = h ^ (h >> np.uint32(16))
    return h

def gnoise(x, y, seed=0, px=0):
    """2D gradient noise in about [-1,1]. px>0 -> periodic in x with that period (cells)."""
    x = x.astype(np.float32); y = y.astype(np.float32)
    xi = np.floor(x); yi = np.floor(y)
    xf = x - xi; yf = y - yi
    xi = xi.astype(np.int64); yi = yi.astype(np.int64)
    def g(ox, oy, dx, dy):
        cx = xi + ox
        if px: cx = np.mod(cx, px)
        h = _hash(cx, yi + oy, seed) & np.uint32(7)
        gx = _GT[h, 0]; gy = _GT[h, 1]
        return gx * dx + gy * dy
    u = xf * xf * xf * (xf * (xf * 6 - 15) + 10)
    v = yf * yf * yf * (yf * (yf * 6 - 15) + 10)
    n00 = g(0, 0, xf, yf); n10 = g(1, 0, xf - 1, yf)
    n01 = g(0, 1, xf, yf - 1); n11 = g(1, 1, xf - 1, yf - 1)
    a = n00 + u * (n10 - n00); b = n01 + u * (n11 - n01)
    return (a + v * (b - a)) * 1.414

def fbm(x, y, octaves=6, lac=2.0, gain=0.5, seed=0, px=0, ridged=False):
    s = np.zeros_like(x, dtype=np.float32); amp = 1.0; f = 1.0; tot = 0.0
    for o in range(octaves):
        n = gnoise(x * f, y * f, seed + o * 17, px * int(round(f)) if px else 0)
        if ridged: n = 1.0 - np.abs(n); n = n * n
        s += amp * n; tot += amp; amp *= gain; f *= lac
    return s / tot

def grid(w=None, h=None):
    """normalised coords: Y in [-1,1] (down positive), X scaled by aspect."""
    w = w or W; h = h or H
    xs = (np.arange(w, dtype=np.float32) - w / 2 + .5) / (h / 2)
    ys = (np.arange(h, dtype=np.float32) - h / 2 + .5) / (h / 2)
    return np.meshgrid(xs, ys)

def half():  # working-res size for smooth fields
    return max(W // 2, 8), max(H // 2, 8)

def resize(a, w, h, resample=Image.BICUBIC):
    if a.ndim == 2:
        return np.asarray(Image.fromarray(a.astype(np.float32), "F").resize((w, h), resample))
    return np.stack([resize(a[..., c], w, h, resample) for c in range(a.shape[2])], -1)

def up(a):  # half-res field -> full-res
    return resize(a, W, H)

def blur(a, sigma):
    if sigma < 0.3: return a
    a = a.astype(np.float32)
    f = int(sigma // 3)
    sig = (sigma, sigma, 0) if a.ndim == 3 else (sigma, sigma)
    if f < 2:
        return ndi.gaussian_filter(a, sig, mode="nearest")
    h, w = a.shape[:2]
    sm = resize(a, max(w // f, 2), max(h // f, 2), Image.BOX)
    sm = ndi.gaussian_filter(sm, (sigma / f, sigma / f, 0) if a.ndim == 3 else (sigma / f,) * 2, mode="nearest")
    return resize(sm, w, h, Image.BICUBIC)

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)

def mix(a, b, t):
    return a + (b - a) * t

def ramp(t, stops):
    """colour ramp: stops = [(pos,(r,g,b)),...]; t array -> (...,3)"""
    t = np.clip(t, 0, 1)
    pos = np.array([s[0] for s in stops], np.float32)
    cols = np.array([s[1] for s in stops], np.float32)
    return np.stack([np.interp(t, pos, cols[:, c]) for c in range(3)], -1).astype(np.float32)

def hexc(h):
    h = h.lstrip("#"); return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))

# ---------------------------------------------------------------- stars
def splat(shape, x, y, amp, sigma, min_sigma=0.62):
    """Gaussian blobs: peak colour amp (N,3) at (x,y) px, std sigma (N,) px."""
    h, w = shape
    out = np.zeros((h, w, 3), np.float32)
    x = np.asarray(x, np.float32); y = np.asarray(y, np.float32)
    amp = np.asarray(amp, np.float32); sigma = np.maximum(np.asarray(sigma, np.float32), min_sigma)
    ok = (x > -4 * sigma) & (x < w + 4 * sigma) & (y > -4 * sigma) & (y < h + 4 * sigma)
    x, y, amp, sigma = x[ok], y[ok], amp[ok], sigma[ok]
    if len(x) == 0: return out
    bi = np.round(np.log(sigma / min_sigma) / math.log(1.2)).astype(int)
    for b in np.unique(bi):
        s = bi == b
        sg = min_sigma * 1.2 ** b
        wt = amp[s] * (2 * math.pi * sg * sg)
        xx = x[s]; yy = y[s]
        x0 = np.floor(xx).astype(int); y0 = np.floor(yy).astype(int)
        fx = xx - x0; fy = yy - y0
        layer = np.zeros((h, w, 3), np.float32)
        for dx, dy, ww in ((0, 0, (1 - fx) * (1 - fy)), (1, 0, fx * (1 - fy)), (0, 1, (1 - fx) * fy), (1, 1, fx * fy)):
            cx = x0 + dx; cy = y0 + dy
            m = (cx >= 0) & (cx < w) & (cy >= 0) & (cy < h)
            idx = cy[m] * w + cx[m]
            for c in range(3):
                layer[..., c].reshape(-1)[:] += np.bincount(idx, weights=(wt[m, c] * ww[m]), minlength=h * w).astype(np.float32)
        out += blur(layer, sg) if sg > 0.3 else layer
    return out

def spikes(img, x, y, col, length, thick=0.9):
    """add thin diffraction spikes (horizontal+vertical) for a few bright stars."""
    h, w = img.shape[:2]
    layer = np.zeros_like(img)
    for xi, yi, c, L in zip(x, y, col, length):
        L = int(L)
        if L < 3: continue
        xi = int(round(xi)); yi = int(round(yi))
        t = np.arange(-L, L + 1)
        prof = np.exp(-np.abs(t) / (L / 3.2)).astype(np.float32)
        x0, x1 = max(xi - L, 0), min(xi + L + 1, w)
        if 0 <= yi < h and x1 > x0:
            layer[yi, x0:x1] += prof[x0 - (xi - L): x1 - (xi - L), None] * c
        y0, y1 = max(yi - L, 0), min(yi + L + 1, h)
        if 0 <= xi < w and y1 > y0:
            layer[y0:y1, xi] += prof[y0 - (yi - L): y1 - (yi - L), None] * c
    return img + blur(layer, thick)

def bloom(img, k=1.0, thresh=0.0):
    b = np.maximum(img - thresh, 0)
    r = (blur(b, 6 * U) * 0.30 + blur(b, 22 * U) * 0.30 + blur(b, 70 * U) * 0.30 + blur(b, 220 * U) * 0.25)
    return img + r * k

def tonemap(x, exposure=1.0):
    x = x * exposure
    a, b, c, d, e = 2.51, 0.03, 2.43, 0.59, 0.14
    return np.clip((x * (a * x + b)) / (x * (c * x + d) + e), 0, 1)

def srgb(x):
    x = np.clip(x, 0, 1)
    return np.where(x <= 0.0031308, 12.92 * x, 1.055 * np.power(x, 1 / 2.4) - 0.055)

def grain_dither(img, grain=0.010, seed=1):
    rng = np.random.default_rng(seed)
    h, w = img.shape[:2]
    lum = img.mean(-1, keepdims=True)
    g = ndi.gaussian_filter(rng.standard_normal((h, w)).astype(np.float32), 0.65)
    g /= g.std() + 1e-6
    img = img + (g[..., None] * grain * (0.35 + 0.65 * np.sqrt(np.clip(lum, 0, 1))))
    tri = (rng.random((h, w, 1), np.float32) - rng.random((h, w, 1), np.float32)) / 255.0
    return img + tri

def vignette(img, strength=0.35, power=2.2, cx=0.0, cy=0.0):
    X, Y = grid()
    r = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2) / math.hypot(W / H, 1) * 2
    return img * (1 - strength * np.clip(r, 0, 1.2) ** power)[..., None]

def save_jpg(img01, rel, q=92):
    """img01: display-referred float image in [0,1], saved with dither."""
    a = np.clip(img01 * 255 + 0.5, 0, 255).astype(np.uint8)
    p = outpath(rel)
    Image.fromarray(a).save(p, "JPEG", quality=q, subsampling=0, optimize=True)
    print("wrote", p, os.path.getsize(p) // 1024, "KB", flush=True)
    return p

def finish(lin, rel, exposure=1.0, grain=0.010, vig=0.0, post=None, do_tonemap=True, seed=1):
    """linear-light float -> tonemap -> srgb -> grain+dither -> jpeg"""
    x = tonemap(lin, exposure) if do_tonemap else np.clip(lin, 0, 1)
    x = srgb(x)
    if post is not None: x = post(x)
    if vig: x = vignette(x, vig)
    x = grain_dither(x, grain, seed)
    return save_jpg(x, rel)

def bg_stars(n, seed, mag_pow=2.6, bright=1.0, tint=True, sizemul=1.0, amp_mul=1.0):
    """random background stars (full-res layer, linear)."""
    rng = np.random.default_rng(seed)
    x = rng.random(n) * W; y = rng.random(n) * H
    m = rng.random(n) ** mag_pow            # most are faint
    amp = (0.03 + 1.2 * m) * bright * amp_mul
    t = rng.random(n)
    if tint:
        col = np.where(t[:, None] < .18, np.array([1.0, .78, .6]), np.where(t[:, None] < .6, np.array([1.0, .97, .95]), np.array([.72, .82, 1.0])))
    else:
        col = np.ones((n, 3))
    amps = (amp[:, None] * col).astype(np.float32)
    sig = (0.7 + 1.6 * m) * U * 1.15 * sizemul
    core = splat((H, W), x, y, amps, sig)
    glow_sel = m > 0.55
    glow = splat((H, W), x[glow_sel], y[glow_sel], amps[glow_sel] * 0.10, sig[glow_sel] * 2.4 + 1)
    out = core + glow
    big = m > 0.985
    out = spikes(out, x[big], y[big], amps[big] * 0.5, (8 + 90 * m[big]) * U)
    return out
