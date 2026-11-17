# -*- coding: utf-8 -*-
"""Bölüm 3 (Antik Mısır) görsel asset üreticisi — Epic 2D-143.

Prosedürel piksel-art: karakter sprite sheet'leri (+ SpriteFrames .tres), çevre/arka plan,
etkileşimli nesne ve VFX dokuları üretir. Harici asset gerektirmez (yalnızca Pillow).

Çalıştırma (2-dgame klasöründen):  python tools/generate_egypt_assets.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RNG = random.Random(143)


def out(rel):
    path = os.path.join(ROOT, rel.replace("res://", ""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def save(img, rel):
    img.save(out(rel))
    return rel


# ---------------------------------------------------------------------------
# Renk paleti
# ---------------------------------------------------------------------------
SKIN = (176, 118, 72, 255)
SKIN_DARK = (128, 82, 50, 255)
LINEN = (226, 214, 184, 255)
LINEN_DARK = (170, 156, 128, 255)
GOLD = (236, 190, 64, 255)
GOLD_DARK = (168, 120, 30, 255)
LAPIS = (38, 72, 168, 255)
LAPIS_LIGHT = (70, 120, 220, 255)
BRONZE = (150, 96, 46, 255)
CRIMSON = (170, 36, 40, 255)
BANDAGE = (196, 186, 150, 255)
BANDAGE_DARK = (130, 122, 96, 255)
OUTLINE = (34, 22, 16, 255)
GHOST_GREEN = (120, 255, 170, 255)
CLEAR = (0, 0, 0, 0)


# ---------------------------------------------------------------------------
# İnsansı figür çizici (taban çözünürlükte çizilir, sonra 2x büyütülür)
# ---------------------------------------------------------------------------
def humanoid(size, pose, style):
    """pose: bob, leg (−1..1), arm (açı derece), lean, crouch, fall (0..1), alpha.
    style: skin, cloth, head, extra (çizim callback listesi)."""
    w, h = size
    img = Image.new("RGBA", (w, h), CLEAR)
    d = ImageDraw.Draw(img)
    cx = w // 2
    ground = h - 2
    fall = pose.get("fall", 0.0)
    if fall > 0.0:
        # Ölüm: figür yana devrilir — ayrı tuvalde çizip döndür
        upright = humanoid(size, dict(pose, fall=0.0), style)
        rot = upright.rotate(-88 * fall, resample=Image.NEAREST, center=(cx, ground))
        shifted = Image.new("RGBA", size, CLEAR)
        shifted.paste(rot, (-int(fall * h * 0.42), 0))
        rot = shifted
        if fall >= 1.0:
            a = rot.split()[3].point(lambda v: int(v * 0.85))
            rot.putalpha(a)
        return rot
    bob = pose.get("bob", 0)
    crouch = pose.get("crouch", 0)
    leg = pose.get("leg", 0.0)
    lean = pose.get("lean", 0)
    scale = style.get("scale", 1.0)
    leg_len = int(9 * scale) - crouch
    torso_len = int(11 * scale)
    hip_y = ground - leg_len + bob
    sh_y = hip_y - torso_len
    head_r = int(3 * scale) + 1
    head_c = (cx + lean, sh_y - head_r)
    skin = style.get("skin", SKIN)
    cloth = style.get("cloth", LINEN)
    # Bacaklar
    for side in (-1, 1):
        fx = cx + side * 2 + int(leg * side * 4)
        d.line([(cx + side * 2, hip_y), (fx, ground)], fill=OUTLINE, width=4)
        d.line([(cx + side * 2, hip_y), (fx, ground)], fill=style.get("leg", skin), width=2)
    # Gövde
    d.polygon([(cx - 4, sh_y), (cx + 4 + lean, sh_y), (cx + 4, hip_y), (cx - 4, hip_y)], fill=OUTLINE)
    d.polygon([(cx - 3, sh_y + 1), (cx + 3 + lean, sh_y + 1), (cx + 3, hip_y), (cx - 3, hip_y)], fill=style.get("torso", skin))
    # Etek / peştamal
    d.polygon([(cx - 5, hip_y - 2), (cx + 5, hip_y - 2), (cx + 6, hip_y + 4), (cx - 6, hip_y + 4)], fill=cloth, outline=OUTLINE)
    # Kollar
    arm_ang = math.radians(pose.get("arm", 20))
    arm_len = int(9 * scale)
    for side, extra in ((1, 0), (-1, 25)):
        ang = arm_ang + math.radians(extra) if side == 1 else math.radians(pose.get("arm_back", 200))
        ax = cx + side * 3 + lean
        ex = ax + int(math.cos(ang) * arm_len)
        ey = sh_y + 2 + int(math.sin(ang) * arm_len)
        d.line([(ax, sh_y + 2), (ex, ey)], fill=OUTLINE, width=4)
        d.line([(ax, sh_y + 2), (ex, ey)], fill=style.get("arm", skin), width=2)
        if side == 1:
            pose["_hand"] = (ex, ey)
    # Kafa
    d.ellipse([head_c[0] - head_r, head_c[1] - head_r, head_c[0] + head_r, head_c[1] + head_r], fill=skin, outline=OUTLINE)
    pose["_head"] = head_c
    pose["_head_r"] = head_r
    pose["_sh_y"] = sh_y
    pose["_hip_y"] = hip_y
    for fn in style.get("extra", []):
        fn(d, pose, img)
    if pose.get("alpha", 1.0) < 1.0:
        a = img.split()[3].point(lambda v: int(v * pose["alpha"]))
        img.putalpha(a)
    return img


def nemes(color_a, color_b):
    def draw(d, pose, _img):
        hx, hy = pose["_head"]
        r = pose["_head_r"]
        d.polygon([(hx - r - 2, hy - r), (hx + r + 2, hy - r), (hx + r + 3, hy + r + 4), (hx - r - 3, hy + r + 4)], fill=color_a, outline=OUTLINE)
        for i in range(-r - 1, r + 3, 2):
            d.line([(hx + i, hy - r + 1), (hx + i, hy + r + 3)], fill=color_b)
        d.rectangle([hx - r + 1, hy - 1, hx + r - 1, hy + r - 1], fill=pose.get("_face", SKIN))
        d.point((hx + 1, hy + 1), fill=OUTLINE)
    return draw


def spear(d, pose, _img):
    x, y = pose["_hand"]
    tilt = pose.get("spear_tilt", 0)
    d.line([(x - 2, y + 10), (x + 3 + tilt, y - 18)], fill=BRONZE, width=1)
    d.polygon([(x + 3 + tilt, y - 22), (x + 5 + tilt, y - 17), (x + 1 + tilt, y - 17)], fill=GOLD, outline=OUTLINE)


def shield(d, pose, _img):
    cx = pose["_head"][0] - 6
    sy = pose["_sh_y"]
    d.ellipse([cx - 4, sy + 1, cx + 3, sy + 12], fill=BRONZE, outline=OUTLINE)
    d.point((cx, sy + 6), fill=GOLD)


def chains(d, pose, _img):
    hip = pose["_hip_y"]
    hx = pose["_head"][0]
    for i in range(4):
        d.point((hx - 3 + i * 2, hip + 9), fill=(120, 120, 128, 255))
    d.point((hx + 4, pose["_sh_y"] + 6), fill=(140, 140, 150, 255))


def bandage_lines(d, pose, img):
    w, h = img.size
    for y in range(int(pose["_head"][1] - pose["_head_r"]), h - 2, 3):
        for x in range(w):
            px = img.getpixel((x, y))
            if px[3] > 0 and px != OUTLINE:
                d.point((x, y), fill=BANDAGE_DARK)


def glowing_eyes(color):
    def draw(d, pose, _img):
        hx, hy = pose["_head"]
        d.point((hx + 1, hy - 1), fill=color)
        d.point((hx + 3, hy - 1), fill=color)
    return draw


def gold_mask(cracked):
    def draw(d, pose, _img):
        hx, hy = pose["_head"]
        r = pose["_head_r"]
        d.ellipse([hx - r + 1, hy - r + 1, hx + r - 1, hy + r], fill=GOLD, outline=GOLD_DARK)
        d.rectangle([hx + 1, hy - 1, hx + 3, hy], fill=LAPIS)
        d.line([(hx, hy + r), (hx, hy + r + 4)], fill=LAPIS)  # sakal
        if cracked:
            d.line([(hx - 2, hy - r + 1), (hx + 1, hy + 1), (hx - 1, hy + r)], fill=CRIMSON)
            d.point((hx + 2, hy - 1), fill=(255, 70, 60, 255))
    return draw


def sun_staff(glow):
    def draw(d, pose, _img):
        x, y = pose["_hand"]
        d.line([(x, y + 16), (x + 1, y - 14)], fill=GOLD_DARK, width=2)
        rr = 4 + glow
        d.ellipse([x + 1 - rr, y - 18 - rr, x + 1 + rr, y - 18 + rr], fill=(255, 196, 60, 255), outline=(255, 120, 30, 255))
        if glow > 0:
            for k in range(8):
                a = k * math.pi / 4
                d.line([(x + 1 + math.cos(a) * rr, y - 18 + math.sin(a) * rr),
                        (x + 1 + math.cos(a) * (rr + 3), y - 18 + math.sin(a) * (rr + 3))], fill=(255, 230, 120, 255))
    return draw


def collar(d, pose, _img):
    hx = pose["_head"][0]
    sy = pose["_sh_y"]
    d.rectangle([hx - 5, sy, hx + 5, sy + 2], fill=GOLD, outline=GOLD_DARK)
    d.line([(hx - 4, sy + 1), (hx + 4, sy + 1)], fill=LAPIS)


def build_sheet(rel_png, rel_tres, frame_size, anims, upscale=2, fps=None):
    """anims: liste (ad, kare listesi (PIL img), loop, speed)."""
    fw, fh = frame_size[0] * upscale, frame_size[1] * upscale
    cols = max(len(a[1]) for a in anims)
    sheet = Image.new("RGBA", (fw * cols, fh * len(anims)), CLEAR)
    for row, (_name, frames, _loop, _spd) in enumerate(anims):
        for col, fr in enumerate(frames):
            big = fr.resize((fw, fh), Image.NEAREST)
            sheet.paste(big, (col * fw, row * fh))
    save(sheet, rel_png)
    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             '[ext_resource type="Texture2D" path="%s" id="1_sheet"]' % rel_png, ""]
    for row, (name, frames, _loop, _spd) in enumerate(anims):
        for col in range(len(frames)):
            lines.append('[sub_resource type="AtlasTexture" id="A_%s_%d"]' % (name, col))
            lines.append('atlas = ExtResource("1_sheet")')
            lines.append("region = Rect2(%d, %d, %d, %d)" % (col * fw, row * fh, fw, fh))
            lines.append("")
    lines.append("[resource]")
    blocks = []
    for name, frames, loop, spd in anims:
        fr_txt = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("A_%s_%d")\n}' % (name, i) for i in range(len(frames)))
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fr_txt, "true" if loop else "false", name, spd))
    lines.append("animations = [" + ", ".join(blocks) + "]")
    with open(out(rel_tres), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


# ---------------------------------------------------------------------------
# Karakterler
# ---------------------------------------------------------------------------
def gen_slave():
    st = {"skin": SKIN, "cloth": LINEN, "extra": [chains]}
    S = (28, 30)
    idle = [humanoid(S, {"bob": b, "arm": 80}, st) for b in (0, 1)]
    cower = [humanoid(S, {"crouch": 4, "arm": -100, "lean": -1, "bob": b}, st) for b in (0, 1)]
    walk = [humanoid(S, {"leg": l, "arm": 60 + l * 20}, st) for l in (-1, 0, 1, 0)]
    cheer = [humanoid(S, {"arm": a, "bob": b}, st) for a, b in ((-90, 0), (-70, -1))]
    drained = [humanoid(S, {"crouch": c, "arm": 90, "alpha": al}, dict(st, skin=(150, 140, 160, 255))) for c, al in ((2, 1.0), (4, 0.8), (5, 0.5))]
    death = [humanoid(S, {"fall": f, "arm": 90}, st) for f in (0.3, 0.7, 1.0)]
    base = "res://assets/characters/egypt/slave/"
    build_sheet(base + "slave_sheet.png", base + "slave_frames.tres", S, [
        ("idle", idle, True, 3.0), ("cower", cower, True, 4.0), ("walk", walk, True, 8.0),
        ("cheer", cheer, True, 4.0), ("drained", drained, False, 4.0), ("death", death, False, 6.0)])


def gen_guard():
    st = {"skin": SKIN_DARK, "cloth": LINEN, "torso": SKIN_DARK, "extra": [nemes(LAPIS, GOLD), collar, shield, spear], "scale": 1.15}
    S = (40, 44)
    idle = [humanoid(S, {"bob": b, "arm": -60}, st) for b in (0, 1)]
    walk = [humanoid(S, {"leg": l, "arm": -60}, st) for l in (-1, 0, 1, 0)]
    attack = [humanoid(S, {"arm": a, "lean": ln, "spear_tilt": t}, st) for a, ln, t in ((-110, -1, -4), (-40, 1, 6), (-5, 2, 12), (-30, 0, 4))]
    hurt = [humanoid(S, {"arm": -150, "lean": -2}, dict(st, skin=(230, 120, 100, 255)))]
    death = [humanoid(S, {"fall": f, "arm": -60}, st) for f in (0.3, 0.7, 1.0)]
    base = "res://assets/characters/egypt/pyramid_guard/"
    build_sheet(base + "pyramid_guard_sheet.png", base + "pyramid_guard_frames.tres", S, [
        ("idle", idle, True, 3.0), ("walk", walk, True, 8.0), ("attack", attack, False, 10.0),
        ("hurt", hurt, False, 8.0), ("death", death, False, 6.0)])


def gen_mummy():
    st = {"skin": BANDAGE, "cloth": BANDAGE_DARK, "torso": BANDAGE, "extra": [bandage_lines, glowing_eyes(GHOST_GREEN)], "scale": 1.1}
    S = (36, 38)

    def rising(p):
        img = humanoid(S, {"arm": -20, "crouch": 3}, st)
        cut = int(S[1] * (1.0 - p))
        mask = Image.new("L", S, 0)
        ImageDraw.Draw(mask).rectangle([0, cut, S[0], S[1]], fill=255)
        res = Image.new("RGBA", S, CLEAR)
        res.paste(img, (0, 0), mask)
        d = ImageDraw.Draw(res)
        d.rectangle([4, S[1] - 3, S[0] - 4, S[1] - 1], fill=(160, 120, 70, 255))  # kum yığını
        return res
    rise = [rising(p) for p in (0.2, 0.45, 0.7, 1.0)]
    idle = [humanoid(S, {"bob": b, "arm": -5, "lean": 1}, st) for b in (0, 1)]
    walk = [humanoid(S, {"leg": l * 0.6, "arm": -10, "lean": 1}, st) for l in (-1, 0, 1, 0)]
    attack = [humanoid(S, {"arm": a, "lean": ln}, st) for a, ln in ((-80, 0), (-20, 2), (10, 3), (-10, 1))]
    hurt = [humanoid(S, {"arm": -120, "lean": -2}, dict(st, skin=(220, 160, 140, 255)))]
    death = [humanoid(S, {"fall": f, "arm": -10, "alpha": 1.0 - f * 0.3}, st) for f in (0.3, 0.7, 1.0)]
    base = "res://assets/characters/egypt/mummy/"
    build_sheet(base + "mummy_sheet.png", base + "mummy_frames.tres", S, [
        ("rise", rise, False, 6.0), ("idle", idle, True, 3.0), ("walk", walk, True, 6.0),
        ("attack", attack, False, 9.0), ("hurt", hurt, False, 8.0), ("death", death, False, 6.0)])


def gen_pharaoh():
    S = (64, 72)

    def st(cracked, glow):
        return {"skin": GOLD_DARK, "cloth": LINEN, "torso": (120, 30, 40, 255), "arm": GOLD_DARK, "scale": 1.6,
                "extra": [nemes(LAPIS, GOLD), gold_mask(cracked), collar, sun_staff(glow)]}
    anims = []
    for suffix, cracked in (("", False), ("_enraged", True)):
        anims.append(("idle" + suffix, [humanoid(S, {"bob": b, "arm": -70}, st(cracked, 0)) for b in (0, 1, 1, 0)], True, 4.0))
        anims.append(("walk" + suffix, [humanoid(S, {"leg": l, "arm": -70}, st(cracked, 0)) for l in (-1, 0, 1, 0)], True, 6.0))
        anims.append(("cast" + suffix, [humanoid(S, {"arm": a}, st(cracked, g)) for a, g in ((-80, 0), (-100, 1), (-120, 2), (-120, 3))], False, 6.0))
        anims.append(("beam" + suffix, [humanoid(S, {"arm": -10, "lean": 1}, st(cracked, g)) for g in (3, 4, 3)], True, 10.0))
        anims.append(("summon" + suffix, [humanoid(S, {"arm": a, "bob": -1}, st(cracked, 1)) for a in (-160, -140, -160, -170)], False, 6.0))
    anims.append(("hurt", [humanoid(S, {"arm": -150, "lean": -2}, dict(st(False, 0), skin=(255, 160, 120, 255)))], False, 8.0))
    anims.append(("death", [humanoid(S, {"fall": f, "arm": -70, "crouch": c}, st(True, 0)) for f, c in ((0.0, 3), (0.2, 4), (0.5, 4), (0.8, 4), (1.0, 4))], False, 5.0))
    base = "res://assets/characters/egypt/pharaoh/"
    build_sheet(base + "pharaoh_sheet.png", base + "pharaoh_frames.tres", S, anims)


# ---------------------------------------------------------------------------
# Nesneler
# ---------------------------------------------------------------------------
def gen_objects():
    base = "res://assets/objects/egypt/"
    # Lanetli lahit: kapalı / ruh sömürülmüş (açık, mavi) / kırık
    for state in ("closed", "drained", "broken"):
        img = Image.new("RGBA", (48, 80), CLEAR)
        d = ImageDraw.Draw(img)
        if state == "broken":
            d.polygon([(6, 78), (12, 50), (22, 58), (30, 44), (40, 60), (44, 78)], fill=GOLD_DARK, outline=OUTLINE)
            for _ in range(10):
                x, y = RNG.randint(4, 44), RNG.randint(60, 78)
                d.rectangle([x, y, x + 2, y + 1], fill=GOLD)
        else:
            d.rounded_rectangle([8, 4, 40, 78], radius=12, fill=GOLD if state == "closed" else GOLD_DARK, outline=OUTLINE, width=2)
            d.ellipse([14, 8, 34, 28], fill=GOLD, outline=OUTLINE)
            d.rectangle([18, 15, 30, 18], fill=LAPIS)
            for y in range(32, 74, 6):
                d.line([(12, y), (36, y)], fill=LAPIS, width=2)
            d.line([(24, 32), (24, 74)], fill=CRIMSON)
            if state == "drained":
                d.rectangle([12, 32, 36, 72], fill=(30, 40, 90, 255))
                for _ in range(16):
                    x, y = RNG.randint(13, 35), RNG.randint(33, 71)
                    d.point((x, y), fill=(130, 190, 255, 255))
        save(img.resize((96, 160), Image.NEAREST), base + "sarcophagus_%s.png" % state)
    # Köle kafesi
    for state in ("closed", "open"):
        img = Image.new("RGBA", (48, 56), CLEAR)
        d = ImageDraw.Draw(img)
        d.rectangle([2, 2, 46, 6], fill=BRONZE, outline=OUTLINE)
        d.rectangle([2, 50, 46, 54], fill=BRONZE, outline=OUTLINE)
        bars = range(4, 46, 6)
        for i, x in enumerate(bars):
            if state == "open" and 1 <= i <= 4:
                continue
            d.line([(x, 6), (x, 50)], fill=(90, 70, 50, 255), width=2)
        save(img.resize((96, 112), Image.NEAREST), base + "slave_cage_%s.png" % state)
    # Güneş mührü anahtarı
    img = Image.new("RGBA", (16, 16), CLEAR)
    d = ImageDraw.Draw(img)
    d.ellipse([3, 1, 13, 11], fill=GOLD, outline=OUTLINE)
    d.ellipse([6, 4, 10, 8], fill=(255, 120, 40, 255))
    d.rectangle([7, 11, 9, 15], fill=GOLD_DARK)
    save(img.resize((32, 32), Image.NEAREST), base + "sun_seal_key.png")
    # Güneş mührü kapısı
    img = Image.new("RGBA", (40, 120), CLEAR)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 39, 119], fill=(118, 86, 52, 255), outline=OUTLINE)
    for y in range(6, 118, 12):
        d.line([(2, y), (37, y)], fill=(92, 66, 40, 255))
    for i, cy in enumerate((30, 80)):
        d.ellipse([10, cy - 10, 30, cy + 10], fill=GOLD_DARK, outline=OUTLINE)
        d.ellipse([15, cy - 5, 25, cy + 5], fill=(255, 140, 40, 255))
    save(img.resize((80, 240), Image.NEAREST), base + "sun_seal_door.png")
    # Hiyeroglif tableti
    img = Image.new("RGBA", (28, 36), CLEAR)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 1, 26, 34], radius=4, fill=(196, 170, 120, 255), outline=OUTLINE)
    for row in range(4):
        for col in range(3):
            x, y = 4 + col * 7, 5 + row * 7
            kind = RNG.randint(0, 3)
            if kind == 0:
                d.ellipse([x, y, x + 4, y + 4], outline=LAPIS)
            elif kind == 1:
                d.line([(x, y + 4), (x + 4, y)], fill=LAPIS)
            elif kind == 2:
                d.rectangle([x + 1, y, x + 3, y + 4], fill=CRIMSON)
            else:
                d.polygon([(x, y + 4), (x + 2, y), (x + 4, y + 4)], outline=LAPIS)
    save(img.resize((56, 72), Image.NEAREST), base + "hieroglyph_tablet.png")
    # İksir
    img = Image.new("RGBA", (12, 14), CLEAR)
    d = ImageDraw.Draw(img)
    d.rectangle([4, 0, 7, 3], fill=BRONZE)
    d.ellipse([1, 3, 10, 13], fill=(200, 40, 60, 255), outline=OUTLINE)
    d.point((4, 6), fill=(255, 200, 200, 255))
    save(img.resize((24, 28), Image.NEAREST), base + "healing_potion.png")
    # Kum tuzağı (2 kare girdap)
    for i in range(2):
        img = Image.new("RGBA", (64, 12), CLEAR)
        d = ImageDraw.Draw(img)
        d.ellipse([0, 0, 63, 11], fill=(186, 128, 66, 255))
        for k in range(5):
            a = k * 1.25 + i * 0.6
            d.arc([8 + k * 4, 1 + k, 56 - k * 4, 10 - k], math.degrees(a), math.degrees(a) + 140, fill=(120, 76, 36, 255))
        save(img.resize((128, 24), Image.NEAREST), base + "sand_trap_%d.png" % i)
    # Güneş ışını (dikey şerit), telegraph çizgisi
    beam = Image.new("RGBA", (32, 256), CLEAR)
    for x in range(32):
        k = 1.0 - abs(x - 15.5) / 16.0
        col = (255, int(200 + 55 * k), int(80 + 150 * k * k), int(255 * min(1.0, k * 1.6)))
        for y in range(256):
            beam.putpixel((x, y), col)
    save(beam, "res://assets/effects/egypt/sun_beam.png")
    tele = Image.new("RGBA", (8, 256), CLEAR)
    for y in range(0, 256, 8):
        ImageDraw.Draw(tele).rectangle([2, y, 5, y + 4], fill=(255, 90, 40, 200))
    save(tele, "res://assets/effects/egypt/sun_beam_telegraph.png")
    # Ruh enerjisi parçacığı ve kızıl-mavi büyü parçacığı
    for name, inner, outer in (("soul_wisp", (210, 240, 255, 255), (80, 150, 255, 0)), ("seal_leak", (255, 255, 255, 255), (160, 60, 255, 0))):
        img = Image.new("RGBA", (16, 16), CLEAR)
        for y in range(16):
            for x in range(16):
                dist = math.hypot(x - 7.5, y - 7.5) / 8.0
                if dist < 1.0:
                    t = dist
                    c = tuple(int(inner[j] * (1 - t) + outer[j] * t) for j in range(3)) + (int(255 * (1 - t) ** 1.5),)
                    img.putpixel((x, y), c)
        save(img, "res://assets/effects/egypt/%s.png" % name)
    # Kum fırtınası zerresi
    img = Image.new("RGBA", (4, 2), (220, 120, 70, 200))
    save(img, "res://assets/effects/egypt/sand_grain.png")
    # 3. Kalp Parçası
    img = Image.new("RGBA", (20, 24), CLEAR)
    d = ImageDraw.Draw(img)
    d.polygon([(10, 1), (18, 9), (10, 23), (2, 9)], fill=(255, 196, 70, 255), outline=OUTLINE)
    d.polygon([(10, 4), (15, 9), (10, 19), (5, 9)], fill=(70, 120, 255, 255))
    d.line([(10, 4), (10, 19)], fill=(220, 40, 60, 255))
    save(img.resize((40, 48), Image.NEAREST), "res://assets/items/egypt/heart_piece_3.png")
    # HUD: mühür çatlağı simgesi
    img = Image.new("RGBA", (16, 16), CLEAR)
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, 14, 14], outline=GOLD, width=1)
    d.line([(8, 2), (6, 7), (9, 9), (7, 14)], fill=(220, 40, 70, 255))
    d.line([(9, 2), (11, 6), (8, 9), (10, 13)], fill=(80, 140, 255, 255))
    save(img.resize((32, 32), Image.NEAREST), "res://assets/ui/egypt/seal_crack_icon.png")
    # Havada asılı piramit
    img = Image.new("RGBA", (120, 90), CLEAR)
    d = ImageDraw.Draw(img)
    d.polygon([(60, 4), (116, 70), (4, 70)], fill=(206, 150, 90, 255), outline=(120, 70, 40, 255))
    d.polygon([(60, 4), (116, 70), (60, 70)], fill=(160, 100, 60, 255))
    for y in range(14, 70, 7):
        d.line([(60 - (y - 4) * 0.85, y), (60 + (y - 4) * 0.85, y)], fill=(140, 90, 50, 255))
    d.polygon([(30, 70), (90, 70), (70, 88), (48, 84)], fill=(110, 70, 40, 255))  # kopmuş kaya tabanı
    save(img, "res://assets/environment/egypt/floating_pyramid.png")


# ---------------------------------------------------------------------------
# Zemin ve arka planlar
# ---------------------------------------------------------------------------
def gen_ground(rel, top, body, band=None):
    img = Image.new("RGBA", (64, 96), body)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 63, 7], fill=top)
    for _ in range(80):
        x, y = RNG.randint(0, 63), RNG.randint(8, 95)
        d.point((x, y), fill=tuple(max(0, c - 25) for c in body[:3]) + (255,))
    if band:
        for x in range(0, 64, 16):
            d.rectangle([x, 8, x + 15, 95], outline=band)
        d.rectangle([0, 20, 63, 28], fill=(150, 112, 70, 255))
        for x in range(2, 64, 8):
            d.rectangle([x, 22, x + 3, 26], fill=LAPIS)
    save(img, rel)


def gradient(w, h, top, bottom):
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        t = y / (h - 1)
        c = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,)
        ImageDraw.Draw(img).line([(0, y), (w, y)], fill=c)
    return img


def dunes(d, w, h, base_y, color, amp, freq, phase):
    pts = [(0, h)]
    for x in range(0, w + 8, 8):
        pts.append((x, base_y + math.sin(x * freq + phase) * amp + math.sin(x * freq * 2.7) * amp * 0.3))
    pts.append((w, h))
    d.polygon(pts, fill=color)


def pyramid(d, x, base_y, size, color, shade, float_off=0):
    top = (x, base_y - size - float_off)
    d.polygon([top, (x + size, base_y - float_off), (x - size, base_y - float_off)], fill=color)
    d.polygon([top, (x + size, base_y - float_off), (x, base_y - float_off)], fill=shade)
    if float_off:
        d.polygon([(x - size * 0.5, base_y - float_off), (x + size * 0.5, base_y - float_off), (x, base_y - float_off + size * 0.35)], fill=shade)


def gen_backgrounds():
    W, H = 1280, 720
    # 1 — Kızıl Çöl ve Asılı Piramitler
    img = gradient(W, H, (120, 30, 30), (236, 120, 60))
    d = ImageDraw.Draw(img)
    d.ellipse([900, 90, 1020, 210], fill=(255, 200, 120, 255))
    for x, s, f in ((220, 130, 140), (560, 90, 220), (840, 160, 110), (1120, 70, 260)):
        pyramid(d, x, 470, s, (190, 110, 70, 255), (150, 80, 55, 255), f)
    # zaman kırılması çatlakları
    for _ in range(6):
        x, y = RNG.randint(100, 1200), RNG.randint(40, 300)
        pts = [(x, y)]
        for _k in range(5):
            x += RNG.randint(-30, 30)
            y += RNG.randint(10, 30)
            pts.append((x, y))
        d.line(pts, fill=(120, 200, 255, 255), width=2)
    dunes(d, W, H, 520, (176, 86, 52, 255), 18, 0.006, 0.5)
    dunes(d, W, H, 580, (150, 66, 40, 255), 14, 0.009, 2.0)
    save(img.filter(ImageFilter.GaussianBlur(0.6)), "res://assets/backgrounds/egypt/egypt_01_crimson_desert.png")
    # 2 — Köle Kampı / Anıt-Mezar Avlusu
    img = gradient(W, H, (150, 60, 40), (230, 150, 90))
    d = ImageDraw.Draw(img)
    pyramid(d, 640, 520, 330, (196, 140, 86, 255), (160, 106, 66, 255))
    d.rectangle([520, 250, 760, 520], fill=(110, 76, 50, 255))  # dev anıt kapısı
    d.rectangle([590, 330, 690, 520], fill=(40, 26, 20, 255))
    for x in (120, 300, 980, 1160):
        d.rectangle([x - 14, 220, x + 14, 540], fill=(200, 160, 110, 255))
        d.rectangle([x - 20, 210, x + 20, 226], fill=(170, 130, 80, 255))
        for y in range(240, 520, 26):
            d.line([(x - 10, y), (x + 10, y)], fill=LAPIS, width=2)
    for _ in range(40):
        x, y = RNG.randint(0, W), RNG.randint(300, 520)
        d.point((x, y), fill=(130, 190, 255, 255))  # ruh zerreleri
    dunes(d, W, H, 560, (170, 110, 70, 255), 6, 0.01, 1.0)
    save(img, "res://assets/backgrounds/egypt/egypt_02_monument_courtyard.png")
    # 3 — Lanetli Anıt-Mezar Koridorları
    img = gradient(W, H, (30, 22, 20), (70, 48, 36))
    d = ImageDraw.Draw(img)
    for y in range(0, H, 40):
        for x in range(0 if (y // 40) % 2 == 0 else -40, W, 80):
            d.rectangle([x, y, x + 78, y + 38], outline=(50, 36, 28, 255), fill=(64, 46, 34, 255))
    for row_y in (160, 320):
        d.rectangle([0, row_y, W, row_y + 44], fill=(96, 72, 50, 255))
        for x in range(10, W, 22):
            kind = RNG.randint(0, 3)
            if kind == 0:
                d.ellipse([x, row_y + 10, x + 12, row_y + 22], outline=LAPIS_LIGHT, width=2)
            elif kind == 1:
                d.line([(x, row_y + 34), (x + 12, row_y + 10)], fill=GOLD, width=2)
            elif kind == 2:
                d.rectangle([x + 4, row_y + 8, x + 8, row_y + 34], fill=CRIMSON)
            else:
                d.polygon([(x, row_y + 34), (x + 6, row_y + 10), (x + 12, row_y + 34)], outline=LAPIS_LIGHT)
    save(img, "res://assets/backgrounds/egypt/egypt_03_cursed_tomb.png")
    # 4 — Güneş Taht Odası
    img = gradient(W, H, (60, 24, 16), (160, 80, 30))
    d = ImageDraw.Draw(img)
    d.ellipse([480, 40, 800, 360], fill=(255, 190, 70, 255), outline=(255, 120, 30, 255), width=6)
    for k in range(24):
        a = k * math.pi / 12
        d.line([(640 + math.cos(a) * 170, 200 + math.sin(a) * 170), (640 + math.cos(a) * 260, 200 + math.sin(a) * 260)], fill=(255, 170, 60, 255), width=4)
    for x in (140, 360, 920, 1140):
        d.rectangle([x - 26, 120, x + 26, 560], fill=(186, 140, 90, 255))
        d.polygon([(x - 40, 120), (x + 40, 120), (x + 30, 96), (x - 30, 96)], fill=(220, 170, 90, 255))
        for y in range(150, 540, 30):
            d.rectangle([x - 18, y, x + 18, y + 8], fill=LAPIS)
    d.rectangle([540, 400, 740, 560], fill=(120, 80, 40, 255))  # taht kürsüsü
    d.rectangle([590, 330, 690, 420], fill=GOLD_DARK)
    save(img, "res://assets/backgrounds/egypt/egypt_04_sun_throne.png")
    gen_ground("res://assets/environment/egypt/egypt_sand_ground.png", (230, 160, 90, 255), (186, 120, 70, 255))
    gen_ground("res://assets/environment/egypt/egypt_tomb_floor.png", (150, 112, 70, 255), (92, 66, 46, 255), band=(70, 50, 36, 255))


def main():
    gen_slave()
    gen_guard()
    gen_mummy()
    gen_pharaoh()
    gen_objects()
    gen_backgrounds()
    gen_portraits()
    print("Mısır assetleri üretildi.")



def gen_portraits():
    """Diyalog portreleri: karakter sheet'inin ilk karesinden baş/omuz kırpımı."""
    specs = (
        ("res://assets/characters/egypt/pharaoh/pharaoh_sheet.png", (128, 144), (32, 38, 96, 102), "portrait_pharaoh.png", (60, 20, 16)),
        ("res://assets/characters/egypt/slave/slave_sheet.png", (56, 60), (8, 0, 48, 40), "portrait_slave.png", (90, 60, 40)),
        ("res://assets/characters/egypt/pyramid_guard/pyramid_guard_sheet.png", (80, 88), (16, 8, 64, 56), "portrait_pyramid_guard.png", (40, 30, 60)),
    )
    for sheet_rel, frame, box, name, bg in specs:
        sheet = Image.open(out(sheet_rel)).convert("RGBA")
        crop = sheet.crop((0, 0) + frame).crop(box)
        canvas = Image.new("RGBA", crop.size, bg + (255,))
        canvas.alpha_composite(crop)
        save(canvas.resize((256, 256), Image.NEAREST), "res://assets/ui/portraits/" + name)


if __name__ == "__main__":
    main()
