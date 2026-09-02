"""Generate clearer stage backgrounds and retouch character sprites for Z Immortal."""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
BG = ROOT / "assets" / "backgrounds"
CHARS = ROOT / "assets" / "characters"
PORTRAITS = ROOT / "assets" / "portraits"
BG.mkdir(parents=True, exist_ok=True)
CHARS.mkdir(parents=True, exist_ok=True)
PORTRAITS.mkdir(parents=True, exist_ok=True)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(w, h, top, bottom, horizontal=False):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = x / max(w - 1, 1) if horizontal else y / max(h - 1, 1)
            px[x, y] = lerp(top, bottom, t)
    return img


def noise_overlay(img: Image.Image, amount=12, seed=1):
    rng = random.Random(seed)
    out = img.convert("RGBA")
    px = out.load()
    w, h = out.size
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            n = rng.randint(-amount, amount)
            r, g, b, a = px[x, y]
            px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)), a)
    return out


def soft_ellipse(draw, box, fill, outline=None):
    draw.ellipse(box, fill=fill, outline=outline)


def paint_mountains(draw, w, h, base_y, color, peaks, amp):
    pts = [(0, h), (0, base_y)]
    for i, p in enumerate(peaks):
        x = int(w * p)
        y = int(base_y - amp * (0.4 + 0.6 * math.sin(i * 1.7)))
        pts.append((x, y))
    pts += [(w, base_y), (w, h)]
    draw.polygon(pts, fill=color)


def paint_path(draw, w, h, y, color, width=70):
    draw.polygon(
        [
            (0, y + width),
            (int(w * 0.35), y - 8),
            (int(w * 0.65), y + 18),
            (w, y + width // 2),
            (w, y + width + 40),
            (0, y + width + 50),
        ],
        fill=color,
    )


def make_stage_bg(name: str, sky_top, sky_bot, ground, path, accents, seed=0):
    w, h = 1280, 720
    img = gradient(w, h, sky_top, sky_bot)
    d = ImageDraw.Draw(img, "RGBA")
    # distant mountains
    paint_mountains(d, w, h, int(h * 0.55), accents[0], [0.15, 0.35, 0.55, 0.75, 0.92], 90)
    paint_mountains(d, w, h, int(h * 0.62), accents[1], [0.1, 0.28, 0.48, 0.68, 0.88], 70)
    # ground plane
    d.rectangle([0, int(h * 0.58), w, h], fill=ground)
    paint_path(d, w, h, int(h * 0.68), path, 90)
    # decorative trees / stones
    rng = random.Random(seed)
    for i in range(8):
        x = rng.randint(40, w - 40)
        y = rng.randint(int(h * 0.6), h - 40)
        r = rng.randint(18, 40)
        soft_ellipse(d, [x - r, y - r * 2, x + r, y], fill=accents[2] + (210,))
        soft_ellipse(d, [x - 6, y - 8, x + 6, y + 18], fill=(70, 55, 40, 220))
    # floating light orbs
    for i in range(12):
        x = rng.randint(20, w - 20)
        y = rng.randint(40, int(h * 0.55))
        r = rng.randint(3, 8)
        soft_ellipse(d, [x - r, y - r, x + r, y + r], fill=(255, 240, 180, 90))
    img = noise_overlay(img, 8, seed).convert("RGB")
    img = ImageEnhance.Color(img).enhance(1.15)
    img = ImageEnhance.Contrast(img).enhance(1.08)
    path_out = BG / f"stage_{name}.png"
    img.save(path_out, optimize=True)
    print("wrote", path_out)
    return path_out


def make_hub_bg():
    w, h = 1280, 720
    img = gradient(w, h, (28, 48, 78), (120, 88, 58))
    d = ImageDraw.Draw(img, "RGBA")
    paint_mountains(d, w, h, int(h * 0.5), (45, 70, 95), [0.2, 0.4, 0.6, 0.8], 110)
    paint_mountains(d, w, h, int(h * 0.58), (62, 92, 78), [0.12, 0.32, 0.52, 0.72, 0.9], 80)
    d.rectangle([0, int(h * 0.62), w, h], fill=(92, 78, 58))
    # plaza
    d.polygon([(0, h), (int(w * 0.15), int(h * 0.62)), (int(w * 0.85), int(h * 0.62)), (w, h)], fill=(150, 130, 100))
    # pavilion silhouette
    cx, cy = int(w * 0.72), int(h * 0.48)
    d.polygon([(cx - 90, cy), (cx, cy - 70), (cx + 90, cy)], fill=(40, 35, 45, 230))
    d.rectangle([cx - 55, cy, cx + 55, cy + 90], fill=(55, 45, 50, 230))
    # lanterns
    for x in [180, 260, 980, 1060]:
        soft_ellipse(d, [x, 220, x + 28, 260], fill=(255, 180, 90, 200))
        d.line([(x + 14, 180), (x + 14, 220)], fill=(80, 60, 40), width=2)
    # blossom dots
    rng = random.Random(7)
    for _ in range(40):
        x, y = rng.randint(0, w), rng.randint(80, int(h * 0.7))
        soft_ellipse(d, [x, y, x + 5, y + 5], fill=(255, 180, 200, 140))
    # vignette panels for UI readability
    for x0, x1 in [(0, 280), (1000, w)]:
        for x in range(x0, x1):
            a = int(110 * (1 - abs(((x - x0) / max(x1 - x0, 1)) - 0.2)))
            d.line([(x, 0), (x, h)], fill=(10, 12, 18, max(0, min(140, a))))
    img = noise_overlay(img, 6, 3).convert("RGB")
    out = BG / "hub_bg.png"
    img.save(out, optimize=True)
    print("wrote", out)


def make_select_bg():
    w, h = 1280, 720
    img = gradient(w, h, (18, 24, 48), (48, 36, 72))
    d = ImageDraw.Draw(img, "RGBA")
    # floating islands
    for i, (cx, cy, rw, rh) in enumerate([(220, 420, 160, 50), (640, 360, 220, 60), (1040, 430, 150, 45)]):
        soft_ellipse(d, [cx - rw, cy - rh, cx + rw, cy + rh], fill=(70, 90, 110, 230))
        soft_ellipse(d, [cx - rw + 20, cy - rh - 30, cx + rw - 20, cy - 10], fill=(90, 130, 100, 200))
        d.line([(cx, cy + rh), (cx + (i - 1) * 180, cy + 120)], fill=(180, 200, 255, 80), width=3)
    for i in range(30):
        x, y = random.Random(i + 9).randint(0, w), random.Random(i + 20).randint(0, h)
        soft_ellipse(d, [x, y, x + 3, y + 3], fill=(220, 230, 255, 160))
    # dim center for cards
    d.rectangle([80, 40, w - 80, h - 40], fill=(8, 10, 20, 90))
    img = noise_overlay(img, 7, 11).convert("RGB")
    out = BG / "select_bg.png"
    img.save(out, optimize=True)
    print("wrote", out)


def key_green(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if g > 140 and g > r + 25 and g > b + 25:
                px[x, y] = (r, g, b, 0)
            elif g > 110 and r < 90 and b < 90:
                px[x, y] = (r, g, b, 0)
    return img


def autocrop(img: Image.Image, pad=8) -> Image.Image:
    bbox = img.getbbox()
    if not bbox:
        return img
    l, t, r, b = bbox
    l = max(0, l - pad)
    t = max(0, t - pad)
    r = min(img.width, r + pad)
    b = min(img.height, b + pad)
    return img.crop((l, t, r, b))


def retouch_sprite(src: Path, dst: Path, max_side=512):
    img = Image.open(src)
    img = key_green(img)
    img = autocrop(img, 12)
    # sharpen a bit for readability at small scale
    img = ImageEnhance.Contrast(img).enhance(1.12)
    img = ImageEnhance.Sharpness(img).enhance(1.25)
    w, h = img.size
    scale = max_side / max(w, h)
    if scale < 1:
        img = img.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
    # ensure square-ish canvas with transparent padding for stable pivot
    side = max(img.width, img.height)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - img.width) // 2, side - img.height), img)
    canvas.save(dst)
    print("sprite", dst, canvas.size)


def draw_stylized_player(path: Path):
    """Fallback clearer stylized sprite if AI art is muddy."""
    s = 384
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # body
    d.ellipse([150, 70, 234, 154], fill=(255, 224, 196))  # head
    d.polygon([(140, 150), (244, 150), (260, 300), (124, 300)], fill=(236, 244, 250))  # robe
    d.polygon([(124, 300), (260, 300), (248, 350), (136, 350)], fill=(60, 140, 150))
    d.rectangle([175, 155, 209, 250], fill=(230, 240, 250))
    # hair
    d.ellipse([148, 55, 236, 120], fill=(35, 32, 40))
    d.polygon([(148, 90), (130, 160), (160, 140)], fill=(35, 32, 40))
    # sword
    d.rectangle([250, 180, 262, 310], fill=(180, 220, 255))
    d.polygon([(248, 170), (264, 170), (256, 145)], fill=(255, 250, 210))
    d.rectangle([245, 205, 267, 215], fill=(200, 170, 90))
    # sash
    d.rectangle([130, 220, 254, 236], fill=(40, 120, 130))
    img = ImageEnhance.Sharpness(img).enhance(1.2)
    img.save(path)
    print("drew", path)


def draw_stylized_mob(path: Path, robe=(70, 78, 92), hair=(30, 30, 35)):
    s = 320
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([110, 50, 210, 150], fill=(255, 220, 190))
    d.polygon([(100, 140), (220, 140), (240, 280), (80, 280)], fill=robe)
    d.ellipse([108, 40, 212, 105], fill=hair)
    d.polygon([(90, 250), (120, 180), (130, 260)], fill=(50, 50, 55))  # arm
    d.polygon([(230, 250), (200, 180), (190, 260)], fill=(50, 50, 55))
    img.save(path)
    print("drew", path)


def draw_stylized_beast(path: Path):
    s = 320
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([70, 120, 250, 230], fill=(250, 245, 230))
    d.ellipse([180, 70, 270, 160], fill=(250, 245, 230))
    d.ellipse([220, 100, 240, 120], fill=(40, 40, 50))
    d.polygon([(70, 170), (20, 140), (50, 190)], fill=(250, 245, 230))
    d.polygon([(90, 210), (40, 250), (100, 235)], fill=(255, 230, 150))
    d.polygon([(120, 210), (70, 270), (130, 240)], fill=(255, 230, 150))
    soft_ellipse(d, [200, 90, 255, 140], fill=(180, 240, 255, 80))
    img.save(path)
    print("drew", path)


def main():
    make_hub_bg()
    make_select_bg()
    stages = {
        "sect": ((70, 120, 170), (180, 150, 90), (70, 110, 70), (140, 120, 80), [(55, 85, 100), (45, 95, 70), (35, 90, 50)]),
        "country": ((90, 110, 140), (200, 160, 110), (110, 100, 80), (160, 140, 100), [(80, 85, 95), (100, 95, 80), (70, 90, 60)]),
        "planet": ((40, 50, 70), (160, 90, 50), (110, 70, 45), (140, 100, 70), [(70, 55, 45), (90, 60, 40), (100, 75, 45)]),
        "galaxy": ((20, 18, 55), (60, 40, 110), (45, 35, 80), (90, 70, 140), [(35, 30, 80), (50, 40, 100), (80, 60, 140)]),
        "world": ((50, 20, 30), (120, 40, 40), (90, 35, 40), (140, 60, 55), [(70, 25, 35), (90, 40, 45), (60, 20, 25)]),
        "universe": ((8, 10, 28), (20, 30, 60), (15, 20, 40), (50, 70, 120), [(15, 20, 45), (25, 35, 70), (40, 60, 100)]),
    }
    for i, (name, (st, sb, g, p, acc)) in enumerate(stages.items()):
        make_stage_bg(name, st, sb, g, p, acc, seed=10 + i)

    # retouch existing AI sprites for clarity; also write stylized fallbacks as *_clear
    for src_name, dst_name in [
        ("player.png", "player.png"),
        ("mob_disciple.png", "mob_disciple.png"),
        ("mob_hare.png", "mob_hare.png"),
    ]:
        src = CHARS / src_name
        if src.exists():
            retouch_sprite(src, CHARS / dst_name, 480)

    # clearer stylized alternatives used by game as primary if present
    draw_stylized_player(CHARS / "player_clear.png")
    draw_stylized_mob(CHARS / "mob_disciple_clear.png", robe=(72, 82, 98))
    draw_stylized_mob(CHARS / "mob_guard_clear.png", robe=(70, 95, 120), hair=(40, 35, 30))
    draw_stylized_mob(CHARS / "mob_bandit_clear.png", robe=(120, 70, 55), hair=(25, 20, 18))
    draw_stylized_beast(CHARS / "mob_beast_clear.png")

    # portrait: crop upper body of player if possible, else stylized head
    src = CHARS / "player.png"
    if src.exists():
        p = Image.open(src).convert("RGBA")
        p = key_green(p)
        p = autocrop(p)
        # take upper 55%
        crop = p.crop((0, 0, p.width, int(p.height * 0.55)))
        canvas = Image.new("RGBA", (512, 640), (0, 0, 0, 0))
        crop = crop.resize((480, int(480 * crop.height / max(crop.width, 1))), Image.Resampling.LANCZOS)
        canvas.paste(crop, ((512 - crop.width) // 2, 40), crop)
        # soft panel bg already handled in UI; save transparent portrait
        canvas.save(PORTRAITS / "player.png")
        print("portrait", PORTRAITS / "player.png")


if __name__ == "__main__":
    main()
