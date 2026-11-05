"""Render a lensed Schwarzschild black hole + thin accretion disk (shared by wallpaper and Plymouth animation)."""
import math
from lib import *
from bhlib import trace

PALETTE = [(0.0, (0.08, 0.0, 0.20)), (0.20, (0.38, 0.06, 0.85)), (0.45, (0.60, 0.25, 1.0)), (0.70, (0.42, 0.52, 1.0)),
           (0.88, (0.74, 0.88, 1.0)), (1.0, (1.0, 1.0, 1.0))]

def disk_emit(r, phi, rot, r_in, r_out, e_rad, seedshift=0, detail=1.0):
    """emissivity (rgb) of a disk point; rot = rotation phase (radians) of the pattern."""
    ph = phi - rot * (1.0 / np.maximum(r, 1) ** 1.5) * 6.0      # differential rotation
    ph = ph + 1.35 * np.log(r / r_in)                              # spiral shear
    u = (ph / (2 * math.pi)) * 8.0
    v = np.log(r / r_in) * 11.0
    n = fbm(u, v, octaves=int(5 + 2 * detail), lac=2.0, gain=0.55, seed=11 + seedshift, px=8)
    n2 = fbm(u * 1.0, v * 3.0, octaves=3, gain=0.6, seed=31, px=8)
    dens = np.clip(0.62 + 0.9 * n + 0.35 * n2, 0.05, 2.2)
    rings = 0.82 + 0.18 * np.sin(v * 2.6 + 3 * n)
    prof = (r_in / r) ** 2.35 * (1 - 0.8 * np.sqrt(r_in / r) * 0.0)
    edge = smoothstep(r_in, r_in + 0.35, r) * (1 - smoothstep(r_out - 3.0, r_out, r))
    inten = prof * dens * rings * edge
    temp = (r_in / r) ** 0.62
    beta = np.sqrt(0.5 / np.maximum(r - 1.0, 0.2))
    vdoto = -beta * np.sin(phi) * math.cos(e_rad)
    gam = 1 / np.sqrt(1 - beta ** 2)
    g = 1 / (gam * (1 - vdoto)) * np.sqrt(np.clip(1 - 1.0 / r, 0.05, 1))
    boost = np.clip(g, 0.35, 1.9) ** 1.5
    return inten, temp * np.clip(g, 0.5, 1.6), boost

def render_bh(w, h, rs_px, cx, cy, roll=0.0, elev=7.0, rot=0.0, r_in=3.0, r_out=11.0, stars=None, tile=900000, detail=1.0, ring_gain=1.0):
    """returns linear rgb (h,w,3). stars: linear star layer (h,w,3) in same frame (lensed through the hole) or None."""
    X, Y = np.meshgrid(np.arange(w, dtype=np.float32) + .5 - cx, np.arange(h, dtype=np.float32) + .5 - cy)
    c, s = math.cos(roll), math.sin(roll)
    bx = (X * c - Y * s) / rs_px
    by = -(X * s + Y * c) / rs_px                 # up positive in image plane
    bxf = bx.ravel().astype(np.float64); byf = by.ravel().astype(np.float64)
    n = bxf.size
    out = np.zeros((n, 3), np.float32)
    lens_x = np.zeros(n, np.float32); lens_y = np.zeros(n, np.float32)
    hor_all = np.zeros(n, bool)
    e_rad = math.radians(elev)
    D0 = 2.2
    for t0 in range(0, n, tile):
        sl = slice(t0, min(t0 + tile, n))
        hits, sky, hor = trace(bxf[sl], byf[sl], elev, r_in, r_out)
        b = np.hypot(bxf[sl], byf[sl])
        col = np.zeros((sl.stop - sl.start, 3), np.float32)
        for k, hk in enumerate(hits):
            m = hk["mask"]
            if not m.any(): continue
            inten, tmp, boost = disk_emit(hk["r"][m], hk["phi"][m], rot, r_in, r_out, e_rad, seedshift=0, detail=detail)
            fall = (0.82, 0.55, 0.38)[k] if k < 3 else 0.3
            L = inten * boost * fall
            cc = ramp(np.clip(tmp * 1.0, 0, 1), PALETTE)
            col[m] += cc * L[:, None]
        # photon ring / unresolved winding rays
        delta = sky - math.pi
        ring = np.where(hor, 0.0, np.clip((delta - 0.7 * math.pi) / (1.8 * math.pi), 0, 1) ** 2.0)
        ringcol = np.array([0.78, 0.78, 1.0], np.float32)
        col += (ring * 0.9 * ring_gain)[:, None] * ringcol
        out[sl] = col
        bs = b - D0 * delta
        nxh = bxf[sl] / b; nyh = byf[sl] / b
        lens_x[sl] = nxh * bs; lens_y[sl] = nyh * bs
        hor_all[sl] = hor
    img = out.reshape(h, w, 3)
    if stars is not None:
        # unrotate lensed coords back to screen px
        lx = lens_x.reshape(h, w); ly = lens_y.reshape(h, w)
        sx = (lx * c + ly * s) * rs_px + cx          # inverse of roll rotation
        sy = -(-lx * s + ly * c) * rs_px + cy
        # derive proper inverse: bx=(X c - Y s)/rs, by=-(X s + Y c)/rs  =>  X = rs(bx c - by s), Y = -rs(bx s + by c)
        sx = (lx * c - ly * s) * rs_px + cx
        sy = -(lx * s + ly * c) * rs_px + cy
        samp = np.stack([ndi.map_coordinates(stars[..., k], [sy - .5, sx - .5], order=1, mode="nearest") for k in range(3)], -1)
        samp[hor_all.reshape(h, w)] = 0
        img = img + samp
    return img, hor_all.reshape(h, w)
