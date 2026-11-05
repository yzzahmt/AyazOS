"""Dark glass crystal shards, navy / steel blue (abstract)."""
from lib import *
from PIL import ImageDraw
rng = np.random.default_rng(404)
X, Y = grid()
# --- backdrop: deep navy with soft steel / violet light pools
r = np.hypot(X - 0.45, Y + 0.05)
base = ramp(np.clip(r / 2.2, 0, 1), [(0, (0.030, 0.055, 0.110)), (0.5, (0.012, 0.024, 0.055)), (1, (0.003, 0.006, 0.015))])
pool1 = np.exp(-((X - 0.9) ** 2 + (Y + 0.35) ** 2) / 0.30)[..., None] * np.array([0.05, 0.11, 0.24], np.float32)
pool2 = np.exp(-((X + 0.7) ** 2 + (Y - 0.55) ** 2) / 0.22)[..., None] * np.array([0.10, 0.06, 0.20], np.float32)
canvas = (base + pool1 + pool2).astype(np.float32)
canvas *= (0.92 + 0.16 * (fbm(X * 3, Y * 3, 4, seed=3)[..., None] * 0.5 + 0.5))

# --- shard generation
main = math.radians(-32)
K = 64
shards = []
for i in range(K):
    z = rng.random() ** 0.8
    t = rng.normal(0, 0.52)                                 # position along the main axis (in H units)
    s = rng.normal(0, 0.33)                                 # across
    cx = W / 2 + (t * math.cos(main) - s * math.sin(main)) * H * 1.15 + 0.12 * W
    cy = H / 2 + (t * math.sin(main) + s * math.cos(main)) * H * 1.15
    L = (0.22 + 0.9 * (z ** 1.5) + 0.25 * rng.random()) * H
    Wd = L * (0.10 + 0.22 * rng.random())
    th = main + rng.normal(0, 0.55)
    nv = rng.integers(3, 6)
    ph = np.sort(rng.random(nv) * 2 * math.pi)
    rr = 0.6 + 0.4 * rng.random(nv)
    pts = np.stack([np.cos(ph) * rr * L / 2, np.sin(ph) * rr * Wd / 2], 1)
    R = np.array([[math.cos(th), -math.sin(th)], [math.sin(th), math.cos(th)]])
    pts = pts @ R.T + [cx, cy]
    shards.append((z, pts, rng.random()))
shards.sort(key=lambda s: s[0])

palette = [np.array(c, np.float32) for c in ((0.30, 0.46, 0.72), (0.18, 0.30, 0.55), (0.10, 0.18, 0.38), (0.38, 0.50, 0.85), (0.28, 0.22, 0.62))]
edges = np.zeros((H, W, 3), np.float32)
def tri_mask(tri, pad=6):
    x0 = int(max(tri[:, 0].min() - pad, 0)); x1 = int(min(tri[:, 0].max() + pad, W))
    y0 = int(max(tri[:, 1].min() - pad, 0)); y1 = int(min(tri[:, 1].max() + pad, H))
    if x1 - x0 < 3 or y1 - y0 < 3: return None
    im = Image.new("L", (x1 - x0, y1 - y0), 0)
    ImageDraw.Draw(im).polygon([(float(px - x0), float(py - y0)) for px, py in tri], fill=255)
    m = np.asarray(im, np.float32) / 255
    return x0, y0, x1, y1, ndi.gaussian_filter(m, 0.7)

for z, pts, hue in shards:
    c = pts.mean(0)
    # interior fan point -> faceted look
    inner = c + (rng.random(2) - 0.5) * 0.35 * (pts.max(0) - pts.min(0))
    n = len(pts)
    depth_blur = (1 - z) * 5.0 * U
    for j in range(n):
        tri = np.array([pts[j], pts[(j + 1) % n], inner])
        mk = tri_mask(tri)
        if mk is None: continue
        x0, y0, x1, y1, m = mk
        # facet normal-ish: orientation of the outer edge drives brightness
        e = pts[(j + 1) % n] - pts[j]
        ang = math.atan2(e[1], e[0])
        lit = 0.5 + 0.5 * math.cos(ang - math.radians(-70) + hue * 2)
        pal = palette[int(hue * 5 * 7.13) % 5] if rng.random() < 0.8 else palette[4]
        gy, gx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        d = rng.random() * 6.28
        g = ((gx - c[0]) * math.cos(d) + (gy - c[1]) * math.sin(d)) / (0.5 * H)
        shade = np.clip(0.55 + 0.45 * g, 0.1, 1.2)
        # refraction of the background beneath, shifted
        sh = (rng.normal(0, 38 * U), rng.normal(0, 38 * U))
        yy = np.clip(gy + sh[1], 0, H - 1).astype(int); xx = np.clip(gx + sh[0], 0, W - 1).astype(int)
        refr = canvas[yy, xx]
        facet = pal[None, None, :] * (0.25 + 0.95 * lit) * (0.35 + 0.65 * shade[..., None]) * (0.25 + 0.75 * z)
        col = refr * 1.3 + facet * 0.55
        a = (m * (0.55 + 0.35 * z))[..., None]
        if depth_blur > 0.5: a = a  # far shards simply dimmer
        canvas[y0:y1, x0:x1] = canvas[y0:y1, x0:x1] * (1 - a) + col * a
    # edge light on the polygon outline
    im = Image.new("L", (W, H), 0) if False else None
    for j in range(n):
        p0, p1 = pts[j], pts[(j + 1) % n]
        e = p1 - p0; ang = math.atan2(e[1], e[0])
        k = max(0.0, math.cos(ang - math.radians(-70) + hue * 2)) ** 2 * (0.25 + 0.75 * z) + 0.05
        x0 = int(max(min(p0[0], p1[0]) - 6, 0)); x1 = int(min(max(p0[0], p1[0]) + 6, W))
        y0 = int(max(min(p0[1], p1[1]) - 6, 0)); y1 = int(min(max(p0[1], p1[1]) + 6, H))
        if x1 - x0 < 3 or y1 - y0 < 3: continue
        im = Image.new("L", (x1 - x0, y1 - y0), 0)
        ImageDraw.Draw(im).line([(p0[0] - x0, p0[1] - y0), (p1[0] - x0, p1[1] - y0)], fill=255, width=max(1, int(round(2 * U))))
        lm = ndi.gaussian_filter(np.asarray(im, np.float32) / 255, 0.8 * U + 0.3)
        edges[y0:y1, x0:x1] += lm[..., None] * np.array([0.55, 0.72, 1.0], np.float32) * (k * 0.9)

lin = canvas + edges + blur(edges, 4 * U) * 0.8 + blur(edges, 18 * U) * 0.5
# a few specular glints + soft haze
gl = splat((H, W), rng.random(30) * W, rng.random(30) * H, np.tile([0.5, 0.7, 1.0], (30, 1)) * 0.06, np.full(30, 5 * U))
lin = lin + gl
lin = lin * (0.55 + 0.45 * smoothstep(0.1, 1.4, np.hypot(X + 1.78, Y + 1.0)))[..., None] ** 0.5
finish(lin, "wallpapers/crystal.jpg", exposure=1.2, grain=0.013, vig=0.5)
