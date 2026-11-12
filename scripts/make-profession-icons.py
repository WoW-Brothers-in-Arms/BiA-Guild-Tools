# Draws the profession symbols of the Guild Recipes window (64x64, 32-bit TGA, white lines on a
# transparent ground; the window tints them) from the line icons of the design, without any image
# library. Run: python3 scripts/make-profession-icons.py BiAGuildTools/Media /tmp/prof-preview.png
import math, struct, sys, zlib
OUT, PREVIEW = sys.argv[1], sys.argv[2]
N = 64          # texture size
VIEW = 24.0     # the design's viewBox
STROKE = 1.8    # line width in viewBox units (the design uses 1.5-1.6 at 26-28 px; a bit bolder for the game)

# Paths in a 24x24 box. The first seven are the design's; Jewelcrafting, Inscription and First Aid
# are drawn in the same style.
ICONS = {
    "Alchemy":        "M9 3h6M10 3v6l-5 9a2 2 0 0 0 2 3h10a2 2 0 0 0 2-3l-5-9V3",
    "Engineering":    "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M5 19l2-2M17 7l2-2",
    "Cooking":        "M4 10h16v5a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5zM2 10h20M9 6c0-1 1-1 1-2M14 6c0-1 1-1 1-2",
    "Leatherworking": "M7 4l2 2h6l2-2 3 3-2 3v4l2 3-3 3-2-2H9l-2 2-3-3 2-3v-4L4 7z",
    "Blacksmithing":  "M4 8h13a3 3 0 0 0 3-3H7v3zM7 8c0 3 2 5 5 5v3H8v3h10v-3h-4v-3",
    "Tailoring":      "M5 5h14M5 19h14M8 5v14M16 5v14M8 9l8 2M8 13l8 2",
    "Enchanting":     "M12 3l2.5 6.5L21 12l-6.5 2.5L12 21l-2.5-6.5L3 12l6.5-2.5z",
    "Jewelcrafting":  "M7 4h10l4 5-9 11L3 9zM3 9h18M10 4L8.5 9 12 20l3.5-11L14 4",
    "Inscription":    "M20 3C13 4 8 9 6.5 17.5M20 3c-.5 7-5.5 12-13.5 14.5M6.5 17.5L4 21M11 12.5l-3-1",
    "FirstAid":       "M9.5 3h5v6.5H21v5h-6.5V21h-5v-6.5H3v-5h6.5z",
}

def tokens(d):
    out, num = [], ""
    i = 0
    while i < len(d):
        c = d[i]
        if c.isalpha() and c not in "eE":
            if num: out.append(float(num)); num = ""
            out.append(c)
        elif c in " ,":
            if num: out.append(float(num)); num = ""
        elif c == "-" and num and num[-1] not in "eE":
            out.append(float(num)); num = "-"
        elif c == "." and "." in num and num[-1] not in "eE":
            out.append(float(num)); num = "."
        else:
            num += c
        i += 1
    if num: out.append(float(num))
    return out

def arc_points(x1, y1, rx, ry, phi, large, sweep, x2, y2):
    # SVG endpoint arc to centre form (SVG spec, appendix F.6).
    if rx == 0 or ry == 0: return [(x2, y2)]
    phi = math.radians(phi)
    cp, sp = math.cos(phi), math.sin(phi)
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p, y1p = cp * dx + sp * dy, -sp * dx + cp * dy
    rx, ry = abs(rx), abs(ry)
    lam = x1p ** 2 / rx ** 2 + y1p ** 2 / ry ** 2
    if lam > 1: rx, ry = rx * math.sqrt(lam), ry * math.sqrt(lam)
    num = rx ** 2 * ry ** 2 - rx ** 2 * y1p ** 2 - ry ** 2 * x1p ** 2
    den = rx ** 2 * y1p ** 2 + ry ** 2 * x1p ** 2
    co = math.sqrt(max(0.0, num / den)) if den else 0.0
    if large == sweep: co = -co
    cxp, cyp = co * rx * y1p / ry, -co * ry * x1p / rx
    cx, cy = cp * cxp - sp * cyp + (x1 + x2) / 2, sp * cxp + cp * cyp + (y1 + y2) / 2
    def ang(ux, uy, vx, vy):
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return a
    t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and dt > 0: dt -= 2 * math.pi
    if sweep and dt < 0: dt += 2 * math.pi
    steps = max(4, int(abs(dt) * 8))
    pts = []
    for k in range(1, steps + 1):
        t = t1 + dt * k / steps
        x, y = rx * math.cos(t), ry * math.sin(t)
        pts.append((cp * x - sp * y + cx, sp * x + cp * y + cy))
    return pts

def cubic(p0, p1, p2, p3, steps=16):
    pts = []
    for k in range(1, steps + 1):
        t = k / steps; u = 1 - t
        pts.append((u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                    u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]))
    return pts

ARGS = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "A": 7, "Z": 0}

def segments(d):
    toks = tokens(d)
    segs, i = [], 0
    x = y = sx = sy = 0.0
    cmd, last_ctrl = None, None
    while i < len(toks):
        if isinstance(toks[i], str):
            cmd = toks[i]; i += 1
        up = cmd.upper(); rel = cmd != up
        n = ARGS[up]
        a = toks[i:i + n]; i += n
        ox, oy = (x, y) if rel else (0.0, 0.0)
        pts, ctrl = [], None
        if up == "M":
            x, y = a[0] + ox, a[1] + oy
            sx, sy = x, y
            cmd = "l" if rel else "L" # following pairs are lines
        elif up == "L":
            pts = [(a[0] + ox, a[1] + oy)]
        elif up == "H":
            pts = [(a[0] + (x if rel else 0), y)]
        elif up == "V":
            pts = [(x, a[0] + (y if rel else 0))]
        elif up == "C":
            p1, p2, p3 = (a[0] + ox, a[1] + oy), (a[2] + ox, a[3] + oy), (a[4] + ox, a[5] + oy)
            pts, ctrl = cubic((x, y), p1, p2, p3), p2
        elif up == "S":
            p1 = (2 * x - last_ctrl[0], 2 * y - last_ctrl[1]) if last_ctrl else (x, y)
            p2, p3 = (a[0] + ox, a[1] + oy), (a[2] + ox, a[3] + oy)
            pts, ctrl = cubic((x, y), p1, p2, p3), p2
        elif up == "A":
            pts = arc_points(x, y, a[0], a[1], a[2], int(a[3]), int(a[4]), a[5] + ox, a[6] + oy)
        elif up == "Z":
            pts = [(sx, sy)]
        prev = (x, y)
        for p in pts:
            segs.append((prev, p)); prev = p
        if pts: x, y = pts[-1]
        last_ctrl = ctrl
    return segs

def seg_dist(px, py, a, b):
    (ax, ay), (bx, by) = a, b
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / l2))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))

def render(d):
    scale = N / VIEW
    segs = [((a[0] * scale, a[1] * scale), (b[0] * scale, b[1] * scale)) for a, b in segments(d)]
    half = STROKE * scale / 2
    img = []
    for py in range(N):
        row = []
        for px in range(N):
            cx, cy = px + 0.5, py + 0.5
            dist = min(seg_dist(cx, cy, a, b) for a, b in segs)
            row.append(max(0.0, min(1.0, half + 0.5 - dist))) # coverage of the pixel, roughly
        img.append(row)
    return img

def write_tga(path, img):
    head = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, N, N, 32, 0x28) # top-down, 8 alpha bits
    body = bytearray()
    for row in img:
        for a in row: body += bytes((255, 255, 255, int(round(a * 255))))
    open(path, "wb").write(head + bytes(body))

def write_png(path, imgs, scale=2):
    # gold on the window's dark brown, side by side, for a look before the game
    w, h = N * scale * len(imgs), N * scale
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for img in imgs:
            for x in range(N * scale):
                a = img[y // scale][x // scale]
                bg, fg = (12, 9, 6), (240, 192, 48)
                raw += bytes(int(bg[k] + (fg[k] - bg[k]) * a) for k in range(3))
    def chunk(tag, data): return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw))) + chunk(b"IEND", b"")
    open(path, "wb").write(png)

imgs = []
for name, d in ICONS.items():
    img = render(d)
    write_tga("%s/Prof%s.tga" % (OUT, name), img)
    imgs.append(img)
write_png(PREVIEW, imgs)
print("wrote", len(imgs), "icons")
