"""Schwarzschild ray tracer for a thin accretion disk (Rs = 1). Vectorised numpy."""
import math
import numpy as np
from lib import *

def trace(bx, by, elev_deg=7.0, r_in=3.0, r_out=11.0, max_psi=4.2 * math.pi, dpsi=0.03, nimg=3):
    """bx,by: image-plane coords in Rs units (flattened arrays). Returns per-image-order hits and sky deflection.
    hits[k] = dict(r, phi, mask) for k-th disk crossing (0=primary,1=secondary,..)."""
    n = bx.size
    b = np.hypot(bx, by).astype(np.float64) + 1e-9
    e = math.radians(elev_deg)
    so, co = math.sin(e), math.cos(e)
    ny = by / b; nx = bx / b
    # disk coordinates of orbit plane basis
    u = np.zeros(n); v = 1.0 / b        # u=1/r, v=du/dpsi
    psi = np.zeros(n)
    alive = np.ones(n, bool)
    hits = [dict(r=np.zeros(n, np.float32), phi=np.zeros(n, np.float32), mask=np.zeros(n, bool)) for _ in range(nimg)]
    ncross = np.zeros(n, int)
    # z, x_w, y_w at psi
    def zf(r, ps):
        return r * (np.cos(ps) * so + np.sin(ps) * ny * co)
    idx = np.arange(n)
    r_prev = 1e9 * np.ones(n); z_prev = zf(r_prev, psi) * 0 + (np.cos(0) * so)  # sign only
    z_prev = np.full(n, so)
    sky = np.full(n, math.pi)           # psi_end for escaped rays
    horizon = np.zeros(n, bool)
    # active compaction
    act = idx.copy()
    uu = u.copy(); vv = v.copy(); ps = psi.copy(); zp = z_prev.copy(); rp = r_prev.copy()
    def f(uv):  # d2u/dpsi2
        return -uv + 1.5 * uv * uv
    steps = int(max_psi / dpsi)
    for s in range(steps):
        if act.size == 0: break
        # RK4 on (u, v)
        k1u = vv; k1v = f(uu)
        k2u = vv + .5 * dpsi * k1v; k2v = f(uu + .5 * dpsi * k1u)
        k3u = vv + .5 * dpsi * k2v; k3v = f(uu + .5 * dpsi * k2u)
        k4u = vv + dpsi * k3v; k4v = f(uu + dpsi * k3u)
        un = uu + dpsi / 6 * (k1u + 2 * k2u + 2 * k3u + k4u)
        vn = vv + dpsi / 6 * (k1v + 2 * k2v + 2 * k3v + k4v)
        psn = ps + dpsi
        nyA = ny[act]
        rn = 1.0 / np.maximum(un, 1e-9)
        zn = rn * (np.cos(psn) * so + np.sin(psn) * nyA * co)
        # crossing
        cr = (np.sign(zn) != np.sign(zp)) & (un > 0) & (s > 0)
        if cr.any():
            t = zp[cr] / (zp[cr] - zn[cr])
            rc = rp[cr] + (rn[cr] - rp[cr]) * t
            pc = ps[cr] + dpsi * t
            gi = act[cr]
            xw = rc * (np.cos(pc) * co - np.sin(pc) * ny[gi] * so)
            yw = rc * (np.sin(pc) * nx[gi])
            phi = np.arctan2(yw, xw)
            k = ncross[gi]
            ok = (rc > r_in) & (rc < r_out)
            for kk in range(nimg):
                sel = ok & (k == kk)
                g2 = gi[sel]
                hits[kk]["r"][g2] = rc[sel]; hits[kk]["phi"][g2] = phi[sel]; hits[kk]["mask"][g2] = True
            ncross[gi] += 1
        # termination
        hz = un >= 1.0
        esc = (un <= 0) | (rn > 1e4)
        horizon[act[hz]] = True
        sky[act[esc]] = ps[esc] + dpsi * uu[esc] / np.maximum(uu[esc] - un[esc], 1e-9)
        keep = ~(hz | esc)
        # also finish if too many crossings
        act = act[keep]
        uu = un[keep]; vv = vn[keep]; ps = psn[keep]; zp = zn[keep]; rp = rn[keep]
    return hits, sky, horizon
