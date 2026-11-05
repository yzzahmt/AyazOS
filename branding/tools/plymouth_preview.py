"""Preview: composite frames over black with the welcome text (as Plymouth would), GIF + contact sheet + 1080p still."""
import os
from lib import *
D = outpath("plymouth/ayazos/x").rsplit("/", 1)[0]
wel = Image.open(os.path.join(D, "welcome.png")).convert("RGBA")
frames = [Image.open(os.path.join(D, "bh-%02d.png" % i)).convert("RGBA") for i in range(48)]
def comp(i, w=1920, h=1080, text=1.0):
    bg = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    bg.alpha_composite(frames[i], (w // 2 - 200, int(h * 0.40) - 200))
    t = wel.copy(); a = np.asarray(t, np.float32).copy(); a[..., 3] *= text
    t = Image.fromarray(a.astype(np.uint8), "RGBA")
    bg.alpha_composite(t, (w // 2 - wel.width // 2, int(h * 0.40) + 212))
    return bg.convert("RGB")
comp(10).save(os.path.join(D, "preview-1080p.png"))
small = [comp(i, 640, 400, min(1, max(0, (i - 6) / 10))).resize((640, 400)) for i in range(48)]
# gif on a 480x300 stage (text pre-scaled)
def stage(i):
    im = comp(i, 1920, 1080, min(1, max(0, (i - 4) / 12))).crop((560, 180, 1360, 780)).resize((600, 450), Image.LANCZOS)
    return im
st = [stage(i) for i in range(48)]
st[0].save(os.path.join(D, "preview.gif"), save_all=True, append_images=st[1:], duration=33, loop=0, optimize=True)
sheet = Image.new("RGB", (6 * 200, 2 * 200))
for k, i in enumerate(range(0, 48, 4)):
    sheet.paste(frames[i].convert("RGB").resize((200, 200), Image.LANCZOS), ((k % 6) * 200, (k // 6) * 200))
sheet.save(os.path.join(D, "preview-frames.png"))
# loop seam check: difference between last frame and first
a = np.asarray(frames[47].convert("RGB"), np.float32); b = np.asarray(frames[0].convert("RGB"), np.float32); c = np.asarray(frames[1].convert("RGB"), np.float32)
print("seam diff 47->0:", np.abs(a - b).mean(), " 0->1:", np.abs(b - c).mean())
print(os.path.getsize(os.path.join(D, "preview.gif")) // 1024, "KB gif")
