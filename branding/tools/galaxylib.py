"""Numpy port of the Three.js spiral galaxy (GalaxyCanvas.tsx star generation) + additive renderer."""
import math
import numpy as np
from lib import *

def _lerpc(a, b, t):
    a = np.asarray(a, np.float32); b = np.asarray(b, np.float32)
    t = np.asarray(t, np.float32)[..., None]
    return a + (b - a) * t

def build_galaxy(scale, rng, density=1.0, twist=2.05):
    """returns dict of arrays: pos(N,3) col(N,3) size alpha bright"""
    P = []; C = []; S = []; A = []; B = []
    def add(p, c, s, a, b):
        P.append(p); C.append(c); S.append(s); A.append(a); B.append(np.broadcast_to(b, (len(s),)))
    g = rng.standard_normal
    # core
    n = int(2000 * density)
    r = np.abs(g(n) * 0.042 * scale); th = rng.random(n) * 2 * np.pi
    t = np.minimum(r / (0.12 * scale), 1)
    c = _lerpc([1, .97, .88], [1, .80, .46], t)
    add(np.stack([r * np.cos(th), g(n) * .008 * scale, r * np.sin(th)], 1), c,
        0.55 + rng.random(n) * 1.7, 0.55 + (1 - t) * 0.45, t < 0.28)
    # arms
    PER = int(7000 * density)
    for arm in range(2):
        off = arm * math.pi
        t = np.arange(PER) / PER
        r = (0.055 + t * 0.945) * scale
        th = off + t * twist * 2 * math.pi
        rf = np.maximum(0.01, r + g(PER) * 0.020 * scale)
        sa = th + g(PER) * (0.036 + t * 0.06)
        c = np.where((t < .20)[:, None], _lerpc([.55, .70, 1], [1, .97, 1], t / .20),
            np.where((t < .52)[:, None], _lerpc([1, .97, 1], [1, .93, .76], (t - .20) / .32),
                     _lerpc([1, .84, .50], [.96, .48, .22], (t - .52) / .48)))
        hii = rng.random(PER) < 0.022
        c = np.where(hii[:, None], _lerpc(c, [1, .30, .58], np.full(PER, .65)), c)
        c = np.minimum(1, c + ((rng.random(PER) - .5) * .08)[:, None])
        size = 0.20 + rng.random(PER) * np.where(t < .18, 2.1, 1.1)
        add(np.stack([rf * np.cos(sa), g(PER) * (0.011 + t * 0.017) * scale, rf * np.sin(sa)], 1), c,
            size, 0.18 + rng.random(PER) * .82, hii)
    # sparse disk
    n = int(1000 * density)
    r = (0.08 + rng.random(n) * .92) * scale; th = rng.random(n) * 2 * np.pi
    add(np.stack([r * np.cos(th), g(n) * .036 * scale, r * np.sin(th)], 1), np.tile([.65, .76, 1], (n, 1)),
        0.16 + rng.random(n) * .5, 0.04 + rng.random(n) * .17, False)
    # halo
    n = int(400 * density)
    r = (0.55 + rng.random(n) * .62) * scale; th = rng.random(n) * 2 * np.pi; ph = np.arccos(2 * rng.random(n) - 1)
    add(np.stack([r * np.sin(ph) * np.cos(th), r * np.cos(ph) * .66, r * np.sin(ph) * np.sin(th)], 1),
        np.tile([.70, .79, 1], (n, 1)), 0.16 + rng.random(n) * .48, 0.04 + rng.random(n) * .14, False)
    cat = lambda L: np.concatenate(L, 0)
    return dict(pos=cat(P).astype(np.float32), col=cat(C).astype(np.float32), size=cat(S).astype(np.float32),
                alpha=cat(A).astype(np.float32), bright=cat(B))

def build_nebula(scale, rng, twist=2.05, n=180):
    PAL = np.array([[.42, .17, .82], [.16, .34, .82], [.04, .60, .72], [.58, .10, .72], [.75, .22, .42]], np.float32)
    P = []; C = []; A = []
    for arm in range(2):
        t = np.arange(n) / n
        r = (0.10 + t * 0.86) * scale; th = arm * math.pi + t * twist * 2 * math.pi
        sc = (rng.random(n) - .5) * .42
        P.append(np.stack([r * np.cos(th + sc), rng.standard_normal(n) * .020 * scale, r * np.sin(th + sc)], 1))
        C.append(PAL[rng.integers(0, len(PAL), n)]); A.append(0.018 + rng.random(n) * .038)
    return np.concatenate(P), np.concatenate(C), np.concatenate(A)

def rotmat(rx, ry, rz):
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]]); Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return (Rx @ Ry @ Rz).astype(np.float32)

class Cam:
    def __init__(self, cx, cy, fov=68.0, cz=158.0, zoom=1.0):
        self.cx, self.cy, self.cz = cx, cy, cz
        self.f = (H / 2) / math.tan(math.radians(fov) / 2) * zoom
    def project(self, p):
        depth = self.cz - p[:, 2]
        return self.cx + self.f * p[:, 0] / depth, self.cy - self.f * p[:, 1] / depth, depth

def render_galaxy(cam, gal, rot, neb=None, star_gain=1.0, mult_size=1.0, core=True, core_gain=1.0, core_scale=1.0, rng=None, glow_mul=1.0):
    """additive linear layer of one galaxy"""
    rng = rng or np.random.default_rng(5)
    out = np.zeros((H, W, 3), np.float32)
    R = rotmat(*rot)
    def prj(P): return cam.project(P @ R.T)
    if neb is not None:
        P, Cn, An = neb
        x, y, d = prj(P)
        px = 240.0 * (340.0 / d) * 2.0 * U * mult_size           # diameter px
        # soft blob = (1-smoothstep(d))^2.4 -> approx gaussian sigma ~ 0.30 R
        sig = px / 2 * 0.36
        amp = Cn * (An * 0.52)[:, None] * 1.7
        out += splat((H, W), x, y, amp, sig)
    # stars
    x, y, d = prj(gal["pos"])
    size_px = gal["size"] * 2.0 * U * (340.0 / d) * mult_size
    tw = 0.82 + 0.18 * rng.random(len(x))
    Rr = np.maximum(size_px, 0.001) / 2
    a = gal["alpha"] * tw * star_gain
    col = gal["col"]
    comps = ((0.56, 0.3676), (0.573, 0.2147), (0.099, 0.1667))
    for amp_k, sg in comps:
        out += splat((H, W), x, y, col * (a * amp_k)[:, None], Rr * sg * glow_mul * 1.0, min_sigma=0.62)
    br = gal["bright"] & (size_px > 3 * U)
    if br.any():
        out = spikes(out, x[br], y[br], col[br] * (a[br] * .5)[:, None], np.clip(size_px[br] * 9, 6, 90 * U))
    if core:
        cx, cy, _ = prj(np.zeros((1, 3), np.float32))
        stops = [(0, (1, .973, .784, 1)), (.06, (1, .863, .392, .92)), (.18, (.784, .431, 1, .58)), (.45, (.314, .216, .863, .20)), (1, (0, 0, 0, 0))]
        for scl, op in ((30, .95), (80, .30), (200, .12)):
            Rpx = scl * cam.f / cam.cz / 2 * core_scale
            n = int(min(Rpx, 2600)) * 2 + 1
            yy, xx = np.mgrid[:n, :n].astype(np.float32); rr = np.hypot(xx - n // 2, yy - n // 2) / (n // 2)
            prof = np.zeros((n, n, 3), np.float32)
            pos = [s[0] for s in stops]
            al = np.interp(rr, pos, [s[3] for s in stops])
            for c in range(3): prof[..., c] = np.interp(rr, pos, [s[1][c] for s in stops]) * al * op * core_gain
            prof[rr > 1] = 0
            x0 = int(round(float(cx[0]))) - n // 2; y0 = int(round(float(cy[0]))) - n // 2
            xa, ya = max(x0, 0), max(y0, 0); xb, yb = min(x0 + n, W), min(y0 + n, H)
            if xb > xa and yb > ya:
                out[ya:yb, xa:xb] += prof[ya - y0:yb - y0, xa - x0:xb - x0]
    return out
