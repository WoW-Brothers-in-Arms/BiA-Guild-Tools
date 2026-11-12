# Draws the symbols of the marker panel (64x64, 32-bit TGA) without any image library: the eight
# target symbols in their colours with a dark outline, one ground marker (white, the panel tints it)
# and the command symbols (white lines, tinted by the panel). The shapes are the design's (canvas
# "BIA Guild Tools", page "Markierungspanel").
# Run: python3 scripts/make-marker-icons.py BiAGuildTools/Media /tmp/marker-preview.png
import math, struct, sys, zlib
OUT, PREVIEW = sys.argv[1], sys.argv[2]
N = 64          # texture size
VIEW = 24.0     # the design's viewBox
SS = 4          # samples per pixel and axis for filled shapes

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


# Target symbols, in the game's order (1 star … 8 skull): path, colour.
TARGETS = [
    ("M12 2l2.9 6.3 6.9.7-5.2 4.6 1.5 6.8L12 16.9 5.9 20.4l1.5-6.8L2.2 9l6.9-.7z", (242, 214, 75)),
    ("M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18z", (240, 138, 44)),
    ("M12 2l8 10-8 10-8-10z", (196, 91, 224)),
    ("M12 3l10 18H2z", (86, 194, 74)),
    ("M15 2a10 10 0 1 0 7 17A8 8 0 1 1 15 2z", (200, 210, 224)),
    ("M4 4h16v16H4z", (59, 143, 224)),
    ("M5 3l7 7 7-7 2 2-7 7 7 7-2 2-7-7-7 7-2-2 7-7-7-7z", (224, 74, 59)),
    ("M12 2a9 9 0 0 0-9 9c0 3 1.5 5 3 6v3h3v-2h2v2h2v-2h2v2h3v-3c1.5-1 3-3 3-6a9 9 0 0 0-9-9z"
     "M8.5 9a2 2 0 1 1 0 4a2 2 0 1 1 0-4zM15.5 9a2 2 0 1 1 0 4a2 2 0 1 1 0-4z", (240, 234, 216)),
]
OUTLINE = 1.1   # dark outline around the target symbols, in viewBox units

# The ground marker: a ring on the ground, a stick and a flame on top (filled), white.
FLARE_LINES = [("M3 17a9 4 0 1 0 18 0a9 4 0 1 0-18 0", 2.0), ("M12 5v11", 2.4)]
FLARE_FILL = "M12 2.2a2.8 2.8 0 1 0 0 5.6a2.8 2.8 0 1 0 0-5.6z"

# Command symbols (white lines): name -> path.
COMMANDS = {
    "Clear":      "M16 3l5 5-11 11H5l-3-3zM9 10l5 5",                       # eraser: marker off the target
    "ClearAll":   "M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13",                     # bin: all target markers
    "Ready":      "M5 12l4 4 10-10",                                         # tick: ready check
    "ClearWorld": "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18zM6 6l12 12",         # crossed circle: all ground markers
    "Pull":       "M6 3h12M6 21h12M7 3c0 4 4 6 5 9c-1 3-5 5-5 9M17 3c0 4-4 6-5 9c1 3 5 5 5 9",  # hourglass: pull timer
}
LINE = 2.0

def scaled(d):
    s = N / VIEW
    return [((a[0] * s, a[1] * s), (b[0] * s, b[1] * s)) for a, b in segments(d)]

def stroke_cov(segs, width, px, py):
    half = width * N / VIEW / 2
    dist = min(seg_dist(px + 0.5, py + 0.5, a, b) for a, b in segs)
    return max(0.0, min(1.0, half + 0.5 - dist))

def inside(segs, x, y):
    # even-odd rule over every closed sub-path
    hit = False
    for (ax, ay), (bx, by) in segs:
        if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
            hit = not hit
    return hit

def fill_cov(segs, px, py):
    n = 0
    for i in range(SS):
        for j in range(SS):
            if inside(segs, px + (i + 0.5) / SS, py + (j + 0.5) / SS): n += 1
    return n / (SS * SS)

def near(segs, px, py, reach):
    return min(seg_dist(px + 0.5, py + 0.5, a, b) for a, b in segs) <= reach

def target(d, color):
    # coloured fill over a dark outline; pixels as (r, g, b, a) 0..1
    segs = scaled(d)
    reach = OUTLINE * N / VIEW
    img = []
    for py in range(N):
        row = []
        for px in range(N):
            line = stroke_cov(segs, OUTLINE * 2, px, py) if near(segs, px, py, reach + 1) else 0.0
            f = fill_cov(segs, px, py) if (near(segs, px, py, 1.5) or inside(segs, px + 0.5, py + 0.5)) else 0.0
            a = max(line, f)
            dark = (24, 16, 10)
            rgb = tuple((dark[k] + (color[k] - dark[k]) * f) / 255 for k in range(3))
            row.append((rgb[0], rgb[1], rgb[2], a))
        img.append(row)
    return img

def white(lines, fills=()):
    lsegs = [(scaled(d), w) for d, w in lines]
    fsegs = [scaled(d) for d in fills]
    img = []
    for py in range(N):
        row = []
        for px in range(N):
            a = 0.0
            for segs, w in lsegs: a = max(a, stroke_cov(segs, w, px, py))
            for segs in fsegs:
                if near(segs, px, py, 1.5) or inside(segs, px + 0.5, py + 0.5): a = max(a, fill_cov(segs, px, py))
            row.append((1.0, 1.0, 1.0, a))
        img.append(row)
    return img

def write_tga(path, img):
    head = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, N, N, 32, 0x28) # top-down, 8 alpha bits
    body = bytearray()
    for row in img:
        for r, g, b, a in row:
            body += bytes((int(round(b * 255)), int(round(g * 255)), int(round(r * 255)), int(round(a * 255))))
    open(path, "wb").write(head + bytes(body))

def write_png(path, imgs, scale=2):
    # on the panel's dark brown, side by side; white symbols shown in the panel's gold
    w, h = N * scale * len(imgs), N * scale
    bg, gold = (21, 16, 12), (240, 192, 48)
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for img, tint in imgs:
            for x in range(N * scale):
                r, g, b, a = img[y // scale][x // scale]
                fg = (r * tint[0], g * tint[1], b * tint[2])
                raw += bytes(int(bg[k] + (fg[k] - bg[k]) * a) for k in range(3))
    def chunk(tag, data): return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw))) + chunk(b"IEND", b"")
    open(path, "wb").write(png)

preview = []
for i, (d, color) in enumerate(TARGETS, 1):
    img = target(d, color)
    write_tga("%s/Marker%d.tga" % (OUT, i), img)
    preview.append((img, (255, 255, 255)))
img = white(FLARE_LINES, [FLARE_FILL])
write_tga("%s/MarkerGround.tga" % OUT, img)
preview.append((img, (59, 143, 224)))
for name, d in COMMANDS.items():
    img = white([(d, LINE)])
    write_tga("%s/MarkerCmd%s.tga" % (OUT, name), img)
    preview.append((img, (224, 74, 59) if name == "ClearWorld" else (240, 192, 48)))
write_png(PREVIEW, preview)
print("wrote", len(preview), "icons")
