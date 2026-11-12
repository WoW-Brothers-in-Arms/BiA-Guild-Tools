# Draws the icons in the windows' headers (64x64, 32-bit TGA) without any image library.
# Run: python3 scripts/make-icons.py BiAGuildTools/Media /tmp/icons-preview.png
import math, struct, sys, zlib
OUT, PREVIEW = sys.argv[1], sys.argv[2]
N, SS = 64, 4

def in_poly(x, y, pts):
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]; xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside

def in_circle(x, y, cx, cy, r): return (x - cx) ** 2 + (y - cy) ** 2 <= r * r
def seg_dist(x, y, a, b):
    (ax, ay), (bx, by) = a, b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(x - (ax + t * dx), y - (ay + t * dy))

def crown(x, y):
    return (in_poly(x, y, [(0.19, 0.70), (0.14, 0.36), (0.33, 0.52), (0.50, 0.26), (0.67, 0.52), (0.86, 0.36), (0.81, 0.70)])
            or (0.19 <= x <= 0.81 and 0.74 <= y <= 0.83)
            or in_circle(x, y, 0.14, 0.33, 0.05) or in_circle(x, y, 0.50, 0.23, 0.055) or in_circle(x, y, 0.86, 0.33, 0.05))
def crown_cut(x, y): return in_circle(x, y, 0.50, 0.60, 0.045) or in_circle(x, y, 0.33, 0.63, 0.03) or in_circle(x, y, 0.67, 0.63, 0.03)

def shield(x, y):
    if not 0.17 <= y <= 0.88: return False
    if y <= 0.48: return abs(x - 0.5) <= 0.31
    return abs(x - 0.5) <= 0.31 * math.sqrt(max(0.0, 1 - ((y - 0.48) / 0.40) ** 2))
def shield_cut(x, y):
    return min(seg_dist(x, y, (0.35, 0.50), (0.46, 0.62)), seg_dist(x, y, (0.46, 0.62), (0.67, 0.36))) <= 0.045

def anvil(x, y):
    star = abs(x - 0.70) ** 0.6 + abs(y - 0.20) ** 0.6 <= 0.105 ** 0.6
    return (star or in_poly(x, y, [(0.10, 0.40), (0.30, 0.37), (0.30, 0.51), (0.24, 0.50)])
            or (0.30 <= x <= 0.88 and 0.37 <= y <= 0.51)
            or in_poly(x, y, [(0.42, 0.51), (0.76, 0.51), (0.70, 0.67), (0.48, 0.67)])
            or in_poly(x, y, [(0.36, 0.67), (0.82, 0.67), (0.88, 0.82), (0.30, 0.82)]))
def none(x, y): return False

def render(glyph, cut):
    R = 0.028  # outline width
    offs = [(R * math.cos(a * math.pi / 4), R * math.sin(a * math.pi / 4)) for a in range(8)]
    img = []
    for py in range(N):
        row = []
        for px in range(N):
            acc = [0.0, 0.0, 0.0]
            for sy in range(SS):
                for sx in range(SS):
                    x, y = (px + (sx + 0.5) / SS) / N, (py + (sy + 0.5) / SS) / N
                    d = math.hypot(x - 0.5, y - 0.45)
                    k = max(0.0, 1 - d / 0.62)
                    col = (0x1c + (0x52 - 0x1c) * k * k, 0x13 + (0x3a - 0x13) * k * k, 0x0b + (0x1e - 0x0b) * k * k)
                    g = glyph(x, y)
                    if g and not cut(x, y):
                        t = min(1.0, max(0.0, (y - 0.18) / 0.68))
                        col = (255 + (198 - 255) * t, 228 + (140 - 228) * t, 132 + (30 - 132) * t)
                        if glyph(x, y - 0.03) is False or cut(x, y - 0.03): col = tuple(min(255, c + 22) for c in col)  # lit top edge
                    elif g or any(glyph(x + ox, y + oy) for ox, oy in offs):
                        col = (0x2a, 0x18, 0x06)
                    for i in range(3): acc[i] += col[i]
            row.append(tuple(int(round(a / (SS * SS))) for a in acc))
        img.append(row)
    return img

def write_tga(path, img):
    with open(path, "wb") as f:
        f.write(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, N, N, 32, 0x28))  # 8 alpha bits, rows top-down
        for row in img:
            for r, g, b in row: f.write(bytes((b, g, r, 255)))

def write_png(path, imgs, scale=4):
    w, h = N * scale * len(imgs), N * scale
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for img in imgs:
            for x in range(N * scale): raw.extend(img[y // scale][x // scale])
    def chunk(tag, data): return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw))) + chunk(b"IEND", b""))

icons = [("IconAlts", crown, crown_cut), ("IconVersions", shield, shield_cut), ("IconRecipes", anvil, none)]
imgs = []
for name, glyph, cut in icons:
    img = render(glyph, cut)
    write_tga("%s/%s.tga" % (OUT, name), img)
    imgs.append(img)
write_png(PREVIEW, imgs)
print("ok")
