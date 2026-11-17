# -*- coding: utf-8 -*-
"""Bölüm 4 (2. Dünya Savaşı) görsel asset üreticisi — Epic 2D-144.

Prosedürel piksel-art (yalnızca Pillow): karakter sprite sheet'leri + SpriteFrames .tres +
JSON manifest, 4 katmanlı parallax arka planları, etkileşimli nesneler, eşya ikonları ve VFX.
Tüm karakter kareleri ortak zemin çıpasına (FEET_Y) hizalıdır; ayak kayması olmaz.
Mısır üreticisindeki insansı figür çizicisini ve sheet yazıcısını yeniden kullanır.

Çalıştırma (2-dgame klasöründen):  python tools/generate_ww2_assets.py
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

from generate_egypt_assets import CLEAR, OUTLINE, build_sheet, gradient, humanoid, out, save

RNG = random.Random(144)
UPSCALE = 2

# ---------------------------------------------------------------------------
# Palet
# ---------------------------------------------------------------------------
SKIN = (196, 150, 118, 255)
SKIN_PALE = (170, 160, 150, 255)
FIELD_GREY = (96, 104, 92, 255)
FIELD_DARK = (64, 70, 62, 255)
OLIVE = (92, 98, 60, 255)
HELMET = (72, 78, 70, 255)
BLACK_COAT = (40, 38, 42, 255)
LEATHER = (92, 62, 40, 255)
STEEL = (130, 136, 142, 255)
STEEL_DARK = (78, 82, 90, 255)
BRASS = (190, 150, 60, 255)
CRIMSON = (190, 30, 40, 255)
OCCULT_RED = (255, 60, 70, 255)
OCCULT_GOLD = (255, 200, 80, 255)
TOXIC = (150, 220, 80, 255)
LAB_WHITE = (214, 216, 206, 255)
FLESH_SICK = (150, 170, 140, 255)
FIRE = (255, 150, 40, 255)
FIRE_CORE = (255, 236, 150, 255)


# ---------------------------------------------------------------------------
# Kostüm parçaları (humanoid extra callback'leri)
# ---------------------------------------------------------------------------
def helmet(color=HELMET):
    def draw(d, pose, _img):
        hx, hy = pose["_head"]
        r = pose["_head_r"]
        d.chord([hx - r - 2, hy - r - 2, hx + r + 2, hy + r], 180, 360, fill=color, outline=OUTLINE)
        d.line([(hx - r - 3, hy - 1), (hx + r + 3, hy - 1)], fill=OUTLINE)
    return draw


def officer_cap(d, pose, _img):
    hx, hy = pose["_head"]
    r = pose["_head_r"]
    d.polygon([(hx - r - 1, hy - r + 1), (hx + r + 2, hy - r - 3), (hx + r + 2, hy - r + 1)], fill=BLACK_COAT, outline=OUTLINE)
    d.line([(hx - r, hy - r + 2), (hx + r + 4, hy - r + 2)], fill=OUTLINE, width=1)
    d.point((hx + 1, hy - r - 1), fill=BRASS)


def gas_mask(d, pose, _img):
    hx, hy = pose["_head"]
    r = pose["_head_r"]
    d.ellipse([hx - r + 1, hy - r + 1, hx + r, hy + r], fill=(60, 64, 58, 255), outline=OUTLINE)
    d.point((hx + 1, hy - 1), fill=(200, 230, 120, 255))
    d.point((hx + 3, hy - 1), fill=(200, 230, 120, 255))
    d.rectangle([hx + 1, hy + 1, hx + 3, hy + r + 1], fill=STEEL_DARK)


def rifle(d, pose, _img):
    x, y = pose["_hand"]
    tilt = pose.get("tilt", 0)
    d.line([(x - 8, y + 3), (x + 9 + tilt, y - 1)], fill=LEATHER, width=2)
    d.line([(x + 4 + tilt, y), (x + 14 + tilt, y - 2)], fill=STEEL, width=1)
    if pose.get("bayonet", 0):
        d.line([(x + 14 + tilt, y - 2), (x + 19 + tilt, y - 3)], fill=(220, 225, 230, 255), width=1)


def back_tank(color=STEEL_DARK, glow=False):
    def draw(d, pose, _img):
        hx = pose["_head"][0]
        sy = pose["_sh_y"]
        d.rounded_rectangle([hx - 9, sy + 1, hx - 4, sy + 12], radius=2, fill=color, outline=OUTLINE)
        if glow:
            d.rectangle([hx - 8, sy + 4, hx - 5, sy + 6], fill=FIRE)
    return draw


def flame_nozzle(flame=0):
    def draw(d, pose, _img):
        x, y = pose["_hand"]
        d.line([(x - 3, y + 2), (x + 6, y)], fill=STEEL_DARK, width=2)
        if flame > 0:
            ln = 8 + flame * 6
            d.polygon([(x + 6, y - 1), (x + 6 + ln, y - 4 - flame), (x + 6 + ln + 3, y + 1), (x + 6 + ln, y + 4 + flame), (x + 6, y + 2)], fill=FIRE)
            d.polygon([(x + 6, y), (x + 6 + ln * 0.6, y - 2), (x + 6 + ln * 0.6, y + 2)], fill=FIRE_CORE)
    return draw


def binoculars(d, pose, _img):
    hx, hy = pose["_head"]
    if pose.get("look", 0):
        d.rectangle([hx + 2, hy - 2, hx + 6, hy + 1], fill=BLACK_COAT, outline=OUTLINE)


def flare_pistol(fire=False):
    def draw(d, pose, _img):
        x, y = pose["_hand"]
        d.rectangle([x - 1, y - 2, x + 4, y + 1], fill=BRASS, outline=OUTLINE)
        if fire:
            d.ellipse([x + 4, y - 6, x + 9, y - 1], fill=(255, 90, 60, 255))
    return draw


def occult_glow(color, strength=1):
    def draw(d, pose, img):
        hx, hy = pose["_head"]
        for k in range(3 + strength * 2):
            a = RNG.random() * math.tau
            rr = 3 + RNG.random() * (5 + strength * 3)
            px, py = hx + math.cos(a) * rr, pose["_sh_y"] + 6 + math.sin(a) * rr
            d.point((px, py), fill=color)
        d.point((hx + 1, hy - 1), fill=color)
        d.point((hx + 3, hy - 1), fill=color)
    return draw


def sick_veins(d, pose, img):
    w, h = img.size
    for y in range(int(pose["_sh_y"]), h - 3, 4):
        for x in range(w):
            px = img.getpixel((x, y))
            if px[3] > 0 and px != OUTLINE and RNG.random() < 0.35:
                d.point((x, y), fill=(120, 40, 80, 255))


def lab_coat(d, pose, _img):
    hx = pose["_head"][0]
    sy, hip = pose["_sh_y"], pose["_hip_y"]
    d.polygon([(hx - 5, sy + 1), (hx + 5, sy + 1), (hx + 7, hip + 7), (hx - 7, hip + 7)], fill=LAB_WHITE, outline=OUTLINE)
    d.line([(hx, sy + 2), (hx, hip + 6)], fill=(170, 170, 160, 255))
    d.point((hx + 2, sy + 4), fill=CRIMSON)


def bandage(d, pose, _img):
    hx, hy = pose["_head"]
    r = pose["_head_r"]
    d.line([(hx - r, hy - 1), (hx + r, hy - 2)], fill=(230, 226, 214, 255))
    d.point((hx + 1, hy - 2), fill=CRIMSON)
    d.point((hx - 1, pose["_hip_y"] - 3), fill=CRIMSON)


def prisoner_stripes(d, pose, _img):
    hx = pose["_head"][0]
    for y in range(int(pose["_sh_y"]) + 2, int(pose["_hip_y"]) + 3, 3):
        d.line([(hx - 3, y), (hx + 3, y)], fill=(70, 80, 110, 255))


def exo_suit(glow):
    def draw(d, pose, _img):
        hx, hy = pose["_head"]
        sy, hip = pose["_sh_y"], pose["_hip_y"]
        d.rectangle([hx - 7, sy - 1, hx + 7, hip + 1], fill=STEEL_DARK, outline=OUTLINE)
        d.rectangle([hx - 9, sy - 2, hx - 5, sy + 4], fill=STEEL, outline=OUTLINE)
        d.rectangle([hx + 5, sy - 2, hx + 9, sy + 4], fill=STEEL, outline=OUTLINE)
        d.ellipse([hx - 3, sy + 3, hx + 3, sy + 9], fill=OCCULT_RED if glow < 2 else OCCULT_GOLD, outline=OUTLINE)
        for k in range(glow):
            d.line([(hx - 2 - k, sy + 6), (hx - 6 - k * 2, sy + 10 + k)], fill=OCCULT_GOLD)
    return draw


def collapsing_core(intensity):
    def draw(d, pose, _img):
        hx = pose["_head"][0]
        sy = pose["_sh_y"]
        rr = 4 + intensity
        d.ellipse([hx - rr, sy + 6 - rr, hx + rr, sy + 6 + rr], fill=OCCULT_GOLD, outline=OCCULT_RED)
        for k in range(6 + intensity * 2):
            a = k * math.tau / (6 + intensity * 2) + intensity * 0.3
            d.line([(hx + math.cos(a) * rr, sy + 6 + math.sin(a) * rr),
                    (hx + math.cos(a) * (rr + 3 + intensity), sy + 6 + math.sin(a) * (rr + 3 + intensity))], fill=OCCULT_RED)
    return draw


def bayonet_saber(d, pose, _img):
    x, y = pose["_hand"]
    d.line([(x, y), (x + 9, y - 6)], fill=(225, 230, 235, 255), width=1)


# ---------------------------------------------------------------------------
# Animasyon yardımcıları (FEET_Y sabit: humanoid zemin çizgisi h-2)
# ---------------------------------------------------------------------------
def loop_frames(size, n, pose_fn, style):
    return [humanoid(size, pose_fn(i / n), style) for i in range(n)]


def walk_pose(base, stride=1.0):
    return lambda t: dict(base, leg=math.sin(t * math.tau) * stride, bob=int(round(abs(math.sin(t * math.tau)) * -1)))


def idle_pose(base):
    return lambda t: dict(base, bob=1 if math.sin(t * math.tau) > 0.3 else 0)


def seq(size, poses, style):
    return [humanoid(size, dict(p), style) for p in poses]


def tinted(style, color):
    return dict(style, skin=color, torso=color, arm=color)


def write_manifest(base, name, size, anims, fps_note):
    fw, fh = size[0] * UPSCALE, size[1] * UPSCALE
    manifest = {
        "character": name,
        "frame_size": [fw, fh],
        "feet_y": fh - 2 * UPSCALE,
        "background": "transparent_rgba",
        "animations": [{"name": a[0], "frames": len(a[1]), "loop": a[2], "fps": a[3]} for a in anims],
        "notes": fps_note,
    }
    with open(out(base + name + "_manifest.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)


def character(folder, name, size, anims, note="Epic 2D-144 prosedürel sprite"):
    base = "res://assets/characters/ww2/%s/" % folder
    build_sheet(base + name + "_sheet.png", base + name + "_frames.tres", size, anims, upscale=UPSCALE)
    write_manifest(base, name, size, anims, note)


def standard_enemy(folder, size, style, attack_poses, extra_anims=()):
    idle = loop_frames(size, 8, idle_pose({"arm": -40}), style)
    walk = loop_frames(size, 12, walk_pose({"arm": -40}), style)
    attack = seq(size, attack_poses, style)
    hurt = seq(size, [{"arm": -150, "lean": -2}, {"arm": -130, "lean": -1}], tinted(style, (240, 130, 110, 255)))
    death = seq(size, [{"fall": f, "arm": -40} for f in (0.15, 0.35, 0.55, 0.75, 0.9, 1.0)], style)
    anims = [("idle", idle, True, 10.0), ("walk", walk, True, 12.0), ("attack", attack, False, 14.0),
             ("hurt", hurt, False, 12.0), ("death", death, False, 10.0)] + list(extra_anims)
    character(folder, folder, size, anims)


# ---------------------------------------------------------------------------
# Standart düşmanlar (5 tip)
# ---------------------------------------------------------------------------
def gen_enemies():
    S = (40, 44)
    infantry = {"skin": SKIN, "cloth": FIELD_DARK, "torso": FIELD_GREY, "arm": FIELD_GREY, "leg": FIELD_DARK, "scale": 1.1,
                "extra": [helmet(), rifle]}
    standard_enemy("trench_infantry", S, infantry, [
        {"arm": -20, "lean": -1, "tilt": -2}, {"arm": -10, "lean": 0}, {"arm": 0, "lean": 2, "bayonet": 1, "tilt": 3},
        {"arm": 0, "lean": 3, "bayonet": 1, "tilt": 5}, {"arm": -5, "lean": 1, "bayonet": 1}, {"arm": -15, "lean": 0}])

    flamer_style = lambda f: {"skin": SKIN, "cloth": OLIVE, "torso": OLIVE, "arm": OLIVE, "leg": FIELD_DARK, "scale": 1.15,
                              "extra": [back_tank(), gas_mask, flame_nozzle(f)]}
    S2 = (56, 44)
    idle = loop_frames(S2, 8, idle_pose({"arm": -10}), flamer_style(0))
    walk = loop_frames(S2, 12, walk_pose({"arm": -10}, 0.8), flamer_style(0))
    attack = [humanoid(S2, {"arm": -5, "lean": 1}, flamer_style(f)) for f in (0, 1, 2, 3, 3, 2, 3, 1)]
    hurt = seq(S2, [{"arm": -150, "lean": -2}, {"arm": -130}], tinted(flamer_style(0), (240, 130, 110, 255)))
    death = seq(S2, [{"fall": f} for f in (0.15, 0.35, 0.55, 0.75, 0.9, 1.0)], flamer_style(0))
    character("flamethrower", "flamethrower", S2, [("idle", idle, True, 10.0), ("walk", walk, True, 12.0),
              ("attack", attack, False, 14.0), ("hurt", hurt, False, 12.0), ("death", death, False, 10.0)])

    sapper = {"skin": SKIN, "cloth": FIELD_DARK, "torso": (84, 80, 70, 255), "arm": (84, 80, 70, 255), "leg": FIELD_DARK,
              "extra": [helmet((60, 64, 58, 255)), gas_mask, bayonet_saber]}
    standard_enemy("gas_sapper", S, sapper, [
        {"arm": -100, "lean": -1}, {"arm": -60, "lean": 1}, {"arm": -10, "lean": 2}, {"arm": 10, "lean": 3}, {"arm": 0, "lean": 1}])

    remnant = {"skin": FLESH_SICK, "cloth": (70, 60, 70, 255), "torso": FLESH_SICK, "scale": 1.15,
               "extra": [sick_veins, occult_glow(OCCULT_RED, 1)]}

    def rising(p):
        img = humanoid(S, {"arm": 30, "crouch": 3}, remnant)
        cut = int(S[1] * (1.0 - p))
        mask = Image.new("L", S, 0)
        ImageDraw.Draw(mask).rectangle([0, cut, S[0], S[1]], fill=255)
        res = Image.new("RGBA", S, CLEAR)
        res.paste(img, (0, 0), mask)
        ImageDraw.Draw(res).ellipse([6, S[1] - 4, S[0] - 6, S[1] - 1], fill=(160, 40, 50, 200))
        return res
    standard_enemy("occult_remnant", S, remnant, [
        {"arm": -90, "lean": 0, "crouch": 1}, {"arm": -40, "lean": 2}, {"arm": 10, "lean": 4}, {"arm": 30, "lean": 3}, {"arm": 0, "lean": 1}],
        extra_anims=[("rise", [rising(p) for p in (0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0)], False, 10.0)])

    scout = {"skin": SKIN, "cloth": FIELD_DARK, "torso": (110, 106, 84, 255), "arm": (110, 106, 84, 255), "leg": FIELD_DARK,
             "extra": [officer_cap, binoculars]}
    S3 = (44, 44)
    idle = [humanoid(S3, {"bob": 1 if i % 4 < 2 else 0, "arm": -80 if i >= 4 else -30, "look": 1 if i >= 4 else 0}, scout) for i in range(8)]
    walk = loop_frames(S3, 12, walk_pose({"arm": -30}), scout)
    fire_style = dict(scout, extra=[officer_cap, flare_pistol(True)])
    attack = [humanoid(S3, {"arm": a, "lean": 0}, fire_style if k >= 3 else dict(scout, extra=[officer_cap, flare_pistol(False)]))
              for k, a in enumerate((-30, -60, -90, -110, -110, -100, -80))]
    hurt = seq(S3, [{"arm": -150, "lean": -2}, {"arm": -130}], tinted(scout, (240, 130, 110, 255)))
    death = seq(S3, [{"fall": f} for f in (0.15, 0.35, 0.55, 0.75, 0.9, 1.0)], scout)
    character("signal_scout", "signal_scout", S3, [("idle", idle, True, 10.0), ("walk", walk, True, 12.0),
              ("attack", attack, False, 12.0), ("hurt", hurt, False, 12.0), ("death", death, False, 10.0)])


# ---------------------------------------------------------------------------
# Müttefik / masum NPC'ler (EgyptSlave animasyon seti: idle, cower, walk, cheer, drained, death)
# ---------------------------------------------------------------------------
def gen_npcs():
    S = (28, 32)
    for folder, style in (
        ("wounded_soldier", {"skin": SKIN, "cloth": (90, 96, 70, 255), "torso": (104, 110, 80, 255), "arm": (104, 110, 80, 255), "extra": [helmet((86, 92, 70, 255)), bandage]}),
        ("prisoner", {"skin": SKIN_PALE, "cloth": (150, 156, 170, 255), "torso": (170, 176, 190, 255), "arm": SKIN_PALE, "extra": [prisoner_stripes]}),
    ):
        idle = loop_frames(S, 8, idle_pose({"arm": 80, "crouch": 2}), style)
        cower = loop_frames(S, 8, lambda t: {"crouch": 4, "arm": -100, "lean": -1, "bob": 1 if t > 0.5 else 0}, style)
        walk = loop_frames(S, 12, walk_pose({"arm": 60}), style)
        cheer = loop_frames(S, 8, lambda t: {"arm": -90 + int(math.sin(t * math.tau) * 20), "bob": -1 if t > 0.5 else 0}, style)
        drained = [humanoid(S, {"crouch": c, "arm": 90, "alpha": al}, tinted(style, (150, 120, 140, 255)))
                   for c, al in ((2, 1.0), (3, 0.9), (4, 0.75), (5, 0.6), (5, 0.45), (6, 0.3))]
        death = seq(S, [{"fall": f, "arm": 90} for f in (0.2, 0.45, 0.7, 0.9, 1.0)], style)
        character(folder, folder, S, [("idle", idle, True, 8.0), ("cower", cower, True, 10.0), ("walk", walk, True, 12.0),
                  ("cheer", cheer, True, 10.0), ("drained", drained, False, 10.0), ("death", death, False, 10.0)])


# ---------------------------------------------------------------------------
# Mini-bosslar
# ---------------------------------------------------------------------------
def gen_minibosses():
    # Mini-Boss 1: Alev Makineli Ağır Siper Subayı
    S = (72, 60)

    def officer(f=0, burst=False):
        return {"skin": SKIN, "cloth": BLACK_COAT, "torso": (58, 60, 54, 255), "arm": (58, 60, 54, 255), "leg": BLACK_COAT, "scale": 1.55,
                "extra": [back_tank((150, 60, 40, 255) if burst else STEEL_DARK, glow=True), helmet((50, 52, 50, 255)), gas_mask, flame_nozzle(f)]}
    anims = [
        ("idle", loop_frames(S, 8, idle_pose({"arm": -10}), officer()), True, 10.0),
        ("walk", loop_frames(S, 12, walk_pose({"arm": -10}, 0.7), officer()), True, 10.0),
        ("telegraph", [humanoid(S, {"arm": -10 - k * 4, "lean": -1, "crouch": k // 2}, officer(1 if k > 3 else 0)) for k in range(6)], False, 12.0),
        ("flame_sweep", [humanoid(S, {"arm": -30 + k * 6, "lean": 1}, officer(3 if k % 2 == 0 else 4)) for k in range(10)], True, 14.0),
        ("groggy", loop_frames(S, 8, lambda t: {"crouch": 4, "arm": 60, "lean": -2 + int(math.sin(t * math.tau) * 2)}, officer(0, True)), True, 10.0),
        ("hurt", seq(S, [{"arm": -150, "lean": -2}, {"arm": -120, "lean": -1}], tinted(officer(), (240, 130, 110, 255))), False, 12.0),
        ("death", seq(S, [{"fall": f, "crouch": 2} for f in (0.0, 0.15, 0.3, 0.5, 0.7, 0.85, 1.0)], officer(0, True)), False, 10.0),
    ]
    character("trench_officer", "trench_officer", S, anims)

    # Mini-Boss 2a: Okült Başhekim
    S = (48, 52)

    def doctor(g=1):
        return {"skin": SKIN_PALE, "cloth": LAB_WHITE, "torso": LAB_WHITE, "arm": LAB_WHITE, "leg": BLACK_COAT, "scale": 1.3,
                "extra": [lab_coat, officer_cap, occult_glow(OCCULT_RED, g)]}
    anims = [
        ("idle", loop_frames(S, 8, idle_pose({"arm": -60}), doctor()), True, 10.0),
        ("walk", loop_frames(S, 12, walk_pose({"arm": -60}, 0.7), doctor()), True, 12.0),
        ("cast", [humanoid(S, {"arm": -60 - k * 15, "bob": -1 if k > 3 else 0}, doctor(1 + k // 2)) for k in range(8)], False, 12.0),
        ("hurt", seq(S, [{"arm": -150, "lean": -2}, {"arm": -120}], tinted(doctor(), (240, 140, 120, 255))), False, 12.0),
        ("death", seq(S, [{"fall": f, "arm": -60} for f in (0.1, 0.3, 0.5, 0.7, 0.9, 1.0)], doctor(3)), False, 10.0),
    ]
    character("occult_doctor", "occult_doctor", S, anims)

    # Mini-Boss 2b: Başarısız Deney
    S = (72, 64)
    beast = {"skin": FLESH_SICK, "cloth": (60, 50, 60, 255), "torso": (130, 150, 120, 255), "arm": FLESH_SICK, "scale": 1.75,
             "extra": [sick_veins, occult_glow(OCCULT_RED, 2)]}
    anims = [
        ("idle", loop_frames(S, 8, idle_pose({"arm": 40, "lean": 2, "crouch": 1}), beast), True, 10.0),
        ("walk", loop_frames(S, 12, walk_pose({"arm": 30, "lean": 2}, 0.6), beast), True, 10.0),
        ("roar", loop_frames(S, 8, lambda t: {"arm": -120 + int(math.sin(t * math.tau) * 15), "lean": -1, "bob": -1}, beast), True, 12.0),
        ("slam", [humanoid(S, {"arm": a, "lean": ln, "crouch": c}, beast) for a, ln, c in
                  ((-150, -1, 0), (-160, -2, 0), (-140, 0, 0), (-60, 2, 2), (20, 3, 4), (40, 3, 4), (20, 2, 3), (0, 1, 1))], False, 14.0),
        ("hurt", seq(S, [{"arm": -120, "lean": -2}, {"arm": -90}], tinted(beast, (240, 150, 140, 255))), False, 12.0),
        ("death", seq(S, [{"fall": f, "arm": 30} for f in (0.1, 0.25, 0.45, 0.65, 0.85, 1.0)], beast), False, 10.0),
    ]
    character("failed_experiment", "failed_experiment", S, anims)


# ---------------------------------------------------------------------------
# Ana Boss: Cani Komutan (3 form; her form ayrı sheet + .tres, ortak animasyon adları)
# ---------------------------------------------------------------------------
def gen_commander():
    S = (72, 76)

    def form_style(form, k=0):
        if form == 1:
            return {"skin": SKIN, "cloth": BLACK_COAT, "torso": BLACK_COAT, "arm": BLACK_COAT, "leg": BLACK_COAT, "scale": 1.6,
                    "extra": [officer_cap, rifle]}
        if form == 2:
            return {"skin": SKIN, "cloth": STEEL_DARK, "torso": STEEL, "arm": STEEL, "leg": STEEL_DARK, "scale": 1.85,
                    "extra": [exo_suit(min(2, k)), helmet(STEEL_DARK)]}
        return {"skin": (210, 160, 120, 255), "cloth": (90, 30, 30, 255), "torso": (120, 40, 40, 255), "arm": (120, 40, 40, 255),
                "leg": (90, 30, 30, 255), "scale": 1.7, "extra": [collapsing_core(min(4, k)), occult_glow(OCCULT_GOLD, 2)]}

    for form in (1, 2, 3):
        st = form_style(form)
        hover = form == 3

        def hp(t, base):
            p = dict(base)
            if hover:
                p["bob"] = -3 + int(round(math.sin(t * math.tau) * 2))
                p["leg"] = 0.2
            return p
        idle = [humanoid(S, hp(i / 12, {"arm": -50, "bob": 1 if (i // 3) % 2 else 0}), form_style(form, i % 3)) for i in range(12)]
        move = [humanoid(S, hp(i / 12, {"arm": -50, "leg": math.sin(i / 12 * math.tau) * 0.8}), st) for i in range(12)]
        telegraph = [humanoid(S, hp(k / 8, {"arm": -50 - k * 10, "lean": -1, "crouch": k // 3}), form_style(form, k)) for k in range(8)]
        if form == 1:
            a1 = [humanoid(S, {"arm": -10, "lean": -1 + (k == 4) * 2, "tilt": -1}, st) for k in range(8)]  # keskin nişancı atışı
            a2 = [humanoid(S, {"arm": -5, "lean": 2 + k // 3, "leg": (k % 2) * 0.8, "bayonet": 1, "tilt": 4}, st) for k in range(8)]  # süngü hücumu
            a3 = [humanoid(S, {"arm": -100 - k * 5, "look": 1}, dict(st, extra=[officer_cap, binoculars])) for k in range(8)]  # telsiz
        elif form == 2:
            a1 = [humanoid(S, {"crouch": max(0, 4 - k), "bob": -k * 2 if k < 4 else -(8 - k) * 2, "arm": -120}, form_style(2, 2)) for k in range(8)]  # şok dalgası sıçrayışı
            a2 = [humanoid(S, {"arm": -150 + k * 25, "lean": k // 3}, form_style(2, 1)) for k in range(8)]  # ağır yumruk
            a3 = [humanoid(S, {"arm": -80, "lean": -1}, form_style(2, k % 3)) for k in range(8)]  # taret çağrısı
        else:
            a1 = [humanoid(S, hp(k / 8, {"arm": -90 + k * 5}), form_style(3, k % 5)) for k in range(8)]  # çapraz ışınlar
            a2 = [humanoid(S, hp(k / 8, {"arm": -170, "lean": 0}), form_style(3, 4)) for k in range(8)]  # arena daralması
            a3 = [humanoid(S, hp(k / 8, {"arm": -140 + k * 8, "bob": -4}), form_style(3, 2)) for k in range(8)]  # deney çağrısı
        transition = [humanoid(S, {"crouch": 3, "arm": -160 + k * 10, "alpha": 1.0 if k % 2 == 0 else 0.7}, form_style(min(3, form + (1 if k > 5 else 0)), k % 4)) for k in range(10)]
        groggy = [humanoid(S, {"crouch": 4, "arm": 70, "lean": -2 + int(math.sin(i / 8 * math.tau) * 2)}, st) for i in range(8)]
        hurt = seq(S, [{"arm": -150, "lean": -2}, {"arm": -130, "lean": -1}], tinted(st, (255, 150, 130, 255)))
        death = seq(S, [{"fall": f, "crouch": 3, "alpha": 1.0 - f * 0.4 if form == 3 else 1.0} for f in (0.0, 0.1, 0.25, 0.4, 0.55, 0.7, 0.85, 1.0)], form_style(form, 4))
        anims = [("idle", idle, True, 12.0), ("move", move, True, 12.0), ("telegraph", telegraph, False, 12.0),
                 ("attack_1", a1, False, 14.0), ("attack_2", a2, False, 14.0), ("attack_3", a3, False, 12.0),
                 ("phase_transition", transition, False, 10.0), ("groggy", groggy, True, 10.0),
                 ("hurt", hurt, False, 12.0), ("death", death, False, 10.0)]
        character("commander", "commander_form%d" % form, S, anims, "Form %d — Vlad paritesinde animasyon seti" % form)

    # Bağımsız VFX katmanı: duman (form 1), okült enerji (form 2), kırmızı-altın çekirdek (form 3)
    def aura(kind, k, n=12):
        img = Image.new("RGBA", S, CLEAR)
        d = ImageDraw.Draw(img)
        cx, base = S[0] // 2, S[1] - 2
        for j in range(14):
            t = (k / n + j / 14.0) % 1.0
            x = cx + math.sin(j * 2.3 + t * math.tau) * (8 + j % 5)
            y = base - t * (S[1] - 6)
            r = 2 + int(3 * (1 - t))
            if kind == "smoke":
                col = (70, 70, 74, int(160 * (1 - t)))
            elif kind == "occult":
                col = (255, 70, 80, int(220 * (1 - t)))
            else:
                col = OCCULT_GOLD[:3] + (int(230 * (1 - t)),) if j % 2 else OCCULT_RED[:3] + (int(230 * (1 - t)),)
            d.ellipse([x - r, y - r, x + r, y + r], fill=col)
        return img
    anims = [(name, [aura(kind, k) for k in range(12)], True, 12.0) for name, kind in (("smoke", "smoke"), ("occult", "occult"), ("core", "core"))]
    character("commander", "commander_aura", S, anims, "Bağımsız duman/okült enerji VFX katmanı")


# ---------------------------------------------------------------------------
# Nesneler, eşyalar, VFX
# ---------------------------------------------------------------------------
def icon(name, draw_fn, size=16):
    img = Image.new("RGBA", (size, size), CLEAR)
    draw_fn(ImageDraw.Draw(img))
    save(img.resize((size * 2, size * 2), Image.NEAREST), "res://assets/items/ww2/%s.png" % name)


def gen_items():
    icon("field_bandage", lambda d: (d.rounded_rectangle([2, 4, 13, 11], 2, fill=(236, 232, 220, 255), outline=OUTLINE), d.rectangle([6, 5, 9, 10], fill=CRIMSON), d.rectangle([4, 6, 11, 9], fill=CRIMSON)))
    icon("adrenaline_syringe", lambda d: (d.line([(2, 13), (12, 3)], fill=STEEL, width=3), d.line([(4, 11), (10, 5)], fill=(255, 220, 60, 255), width=1), d.line([(12, 3), (14, 1)], fill=(230, 230, 230, 255))))
    icon("gas_filter", lambda d: (d.ellipse([3, 3, 12, 12], fill=(70, 76, 68, 255), outline=OUTLINE), d.ellipse([6, 6, 9, 9], fill=TOXIC)))
    icon("stick_grenade", lambda d: (d.line([(4, 13), (9, 6)], fill=LEATHER, width=2), d.rounded_rectangle([8, 1, 14, 7], 1, fill=FIELD_GREY, outline=OUTLINE)))
    icon("phosphor_flare", lambda d: (d.rectangle([6, 4, 9, 14], fill=CRIMSON, outline=OUTLINE), d.ellipse([5, 0, 10, 5], fill=(255, 240, 200, 255))))
    icon("radio_codes", lambda d: (d.rectangle([2, 2, 13, 13], fill=(220, 210, 170, 255), outline=OUTLINE), [d.line([(4, y), (11, y)], fill=OUTLINE) for y in (5, 8, 11)]))
    icon("bunker_keycard", lambda d: (d.rounded_rectangle([1, 4, 14, 12], 1, fill=(160, 40, 40, 255), outline=OUTLINE), d.rectangle([3, 6, 7, 9], fill=BRASS)))
    icon("prisoner_tags", lambda d: (d.ellipse([3, 3, 9, 11], fill=STEEL, outline=OUTLINE), d.ellipse([7, 5, 13, 13], fill=STEEL, outline=OUTLINE), d.line([(4, 1), (10, 4)], fill=STEEL_DARK)))
    # 4. Kalp Parçası (demir çekirdek)
    img = Image.new("RGBA", (20, 24), CLEAR)
    d = ImageDraw.Draw(img)
    d.polygon([(10, 1), (18, 9), (10, 23), (2, 9)], fill=STEEL, outline=OUTLINE)
    d.polygon([(10, 4), (15, 9), (10, 19), (5, 9)], fill=OCCULT_RED)
    d.line([(10, 4), (10, 19)], fill=OCCULT_GOLD)
    d.line([(5, 9), (15, 9)], fill=OCCULT_GOLD)
    save(img.resize((40, 48), Image.NEAREST), "res://assets/items/ww2/heart_piece_4.png")


def gen_objects():
    base = "res://assets/objects/ww2/"
    # Sığınak (siper alma) — beton/kum torbası
    img = Image.new("RGBA", (96, 56), CLEAR)
    d = ImageDraw.Draw(img)
    d.polygon([(4, 55), (12, 8), (84, 8), (92, 55)], fill=(110, 108, 100, 255), outline=OUTLINE)
    d.rectangle([28, 24, 68, 55], fill=(30, 28, 28, 255))
    for x in range(6, 92, 12):
        d.rounded_rectangle([x, 46, x + 11, 54], 3, fill=(150, 130, 90, 255), outline=OUTLINE)
    save(img.resize((192, 112), Image.NEAREST), base + "bunker_shelter.png")
    # Dikenli tel
    img = Image.new("RGBA", (64, 24), CLEAR)
    d = ImageDraw.Draw(img)
    for x in (4, 32, 60):
        d.line([(x, 23), (x, 4)], fill=LEATHER, width=2)
    for k in range(3):
        d.arc([0, 2 + k * 5, 64, 14 + k * 5], 180, 360, fill=STEEL, width=1)
        for x in range(2, 62, 5):
            d.point((x, 6 + k * 5), fill=(200, 200, 205, 255))
    save(img.resize((128, 48), Image.NEAREST), base + "barbed_wire.png")
    # Mayın (2 kare: sönük / yanıp sönen)
    for i, col in enumerate(((90, 96, 80, 255), (255, 60, 50, 255))):
        img = Image.new("RGBA", (16, 8), CLEAR)
        d = ImageDraw.Draw(img)
        d.chord([0, 0, 15, 14], 180, 360, fill=(84, 88, 76, 255), outline=OUTLINE)
        d.point((7, 2), fill=col)
        d.point((8, 2), fill=col)
        save(img.resize((32, 16), Image.NEAREST), base + "landmine_%d.png" % i)
    # Projektör
    img = Image.new("RGBA", (24, 32), CLEAR)
    d = ImageDraw.Draw(img)
    d.line([(12, 31), (12, 14)], fill=STEEL_DARK, width=3)
    d.line([(4, 31), (12, 18), (20, 31)], fill=STEEL_DARK, width=2)
    d.ellipse([4, 2, 20, 16], fill=STEEL, outline=OUTLINE)
    d.ellipse([7, 5, 17, 13], fill=(255, 250, 210, 255))
    save(img.resize((48, 64), Image.NEAREST), base + "searchlight.png")
    # Işık konisi (yumuşak kenarlı)
    cone = Image.new("RGBA", (128, 256), CLEAR)
    for y in range(256):
        half = 6 + y * 0.22
        for x in range(128):
            dx = abs(x - 63.5)
            if dx < half:
                k = 1.0 - dx / half
                cone.putpixel((x, y), (255, 248, 200, int(150 * k * (1.0 - y / 300.0))))
    save(cone, "res://assets/effects/ww2/searchlight_cone.png")
    # Şalter / röle (kapalı, açık)
    for state, lever in (("off", (6, 14, 10, 6)), ("on", (6, 6, 10, 14))):
        img = Image.new("RGBA", (20, 28), CLEAR)
        d = ImageDraw.Draw(img)
        d.rectangle([1, 1, 18, 26], fill=(70, 74, 80, 255), outline=OUTLINE)
        d.rectangle([4, 3, 15, 8], fill=(255, 80, 60, 255) if state == "off" else (90, 255, 120, 255))
        d.line([(lever[0] + 4, 20), (lever[2] + 4, lever[3] + 6)], fill=STEEL, width=2)
        d.ellipse([lever[2] + 2, lever[3] + 4, lever[2] + 6, lever[3] + 8], fill=CRIMSON)
        save(img.resize((40, 56), Image.NEAREST), base + "power_relay_%s.png" % state)
    # Gaz kapısı / laboratuvar kapısı
    img = Image.new("RGBA", (40, 120), CLEAR)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 39, 119], fill=(80, 86, 84, 255), outline=OUTLINE)
    for y in range(8, 118, 14):
        d.line([(3, y), (36, y)], fill=(60, 64, 62, 255))
    d.ellipse([10, 44, 30, 64], fill=STEEL_DARK, outline=OUTLINE)
    d.line([(20, 46), (20, 62)], fill=BRASS, width=2)
    d.line([(12, 54), (28, 54)], fill=BRASS, width=2)
    save(img.resize((80, 240), Image.NEAREST), base + "lab_door.png")
    # Esir hücresi (kapalı / açık)
    for state in ("closed", "open"):
        img = Image.new("RGBA", (48, 56), CLEAR)
        d = ImageDraw.Draw(img)
        d.rectangle([2, 2, 46, 6], fill=STEEL_DARK, outline=OUTLINE)
        d.rectangle([2, 50, 46, 54], fill=STEEL_DARK, outline=OUTLINE)
        for i, x in enumerate(range(4, 46, 6)):
            if state == "open" and 1 <= i <= 4:
                continue
            d.line([(x, 6), (x, 50)], fill=(110, 116, 124, 255), width=2)
        save(img.resize((96, 112), Image.NEAREST), base + "prisoner_cell_%s.png" % state)
    # Okült enerji tüpü (sağlam / kırık)
    for state in ("intact", "broken"):
        img = Image.new("RGBA", (24, 64), CLEAR)
        d = ImageDraw.Draw(img)
        d.rectangle([2, 0, 21, 6], fill=STEEL_DARK, outline=OUTLINE)
        d.rectangle([2, 57, 21, 63], fill=STEEL_DARK, outline=OUTLINE)
        if state == "intact":
            d.rectangle([5, 6, 18, 57], fill=(255, 70, 80, 150), outline=(220, 230, 240, 255))
            for y in range(10, 54, 6):
                d.point((8 + (y % 4), y), fill=OCCULT_GOLD)
        else:
            d.polygon([(5, 57), (7, 40), (10, 48), (13, 36), (18, 57)], fill=(200, 210, 220, 160), outline=OUTLINE)
        save(img.resize((48, 128), Image.NEAREST), base + "energy_tube_%s.png" % state)
    # Bunker tareti
    img = Image.new("RGBA", (40, 32), CLEAR)
    d = ImageDraw.Draw(img)
    d.chord([2, 8, 38, 44], 180, 360, fill=STEEL_DARK, outline=OUTLINE)
    d.rectangle([18, 10, 39, 14], fill=STEEL, outline=OUTLINE)
    d.rectangle([12, 18, 18, 22], fill=OCCULT_RED)
    save(img.resize((80, 64), Image.NEAREST), base + "bunker_turret.png")
    # Telsiz (sabotaj / easter egg)
    img = Image.new("RGBA", (24, 20), CLEAR)
    d = ImageDraw.Draw(img)
    d.rectangle([1, 5, 22, 19], fill=(80, 86, 70, 255), outline=OUTLINE)
    d.line([(18, 5), (21, 0)], fill=STEEL)
    for i, c in enumerate(((255, 80, 60, 255), (255, 200, 60, 255), (90, 220, 110, 255))):
        d.ellipse([4 + i * 5, 8, 7 + i * 5, 11], fill=c)
    d.rectangle([4, 13, 19, 16], fill=(30, 30, 30, 255))
    save(img.resize((48, 40), Image.NEAREST), base + "field_radio.png")
    # Zırhlı tren vagonu
    img = Image.new("RGBA", (160, 56), CLEAR)
    d = ImageDraw.Draw(img)
    d.rectangle([4, 10, 156, 44], fill=(70, 74, 66, 255), outline=OUTLINE)
    d.rectangle([4, 10, 156, 14], fill=(90, 94, 84, 255))
    for x in range(10, 152, 14):
        d.point((x, 18), fill=STEEL)
        d.point((x, 38), fill=STEEL)
    for x in (30, 70, 110):
        d.rectangle([x, 22, x + 18, 30], fill=(20, 20, 22, 255))
    for x in (22, 50, 110, 138):
        d.ellipse([x - 8, 40, x + 8, 55], fill=(40, 40, 44, 255), outline=OUTLINE)
        d.ellipse([x - 3, 45, x + 3, 50], fill=STEEL)
    d.text((60, 31), "IV", fill=(200, 60, 50, 255))
    save(img.resize((320, 112), Image.NEAREST), base + "armored_train_car.png")
    # Arma (Sığınak mahzeni easter egg) ve gelecek damgalı proje dosyası
    img = Image.new("RGBA", (24, 28), CLEAR)
    d = ImageDraw.Draw(img)
    d.polygon([(2, 2), (21, 2), (21, 14), (12, 26), (2, 14)], fill=(40, 50, 120, 255), outline=BRASS)
    d.line([(12, 5), (12, 21)], fill=(220, 220, 230, 255), width=2)
    d.line([(7, 10), (17, 10)], fill=(220, 220, 230, 255), width=2)
    save(img.resize((48, 56), Image.NEAREST), base + "knight_crest.png")
    img = Image.new("RGBA", (20, 24), CLEAR)
    d = ImageDraw.Draw(img)
    d.rectangle([1, 1, 18, 22], fill=(210, 196, 150, 255), outline=OUTLINE)
    d.ellipse([6, 6, 14, 14], outline=(60, 200, 255, 255))
    d.line([(10, 3), (10, 17)], fill=(60, 200, 255, 255))
    d.rectangle([3, 18, 16, 20], fill=CRIMSON)
    save(img.resize((40, 48), Image.NEAREST), base + "future_blueprint.png")
    # Kırılabilir siper bariyeri (kum torbası duvarı)
    img = Image.new("RGBA", (40, 64), CLEAR)
    d = ImageDraw.Draw(img)
    for row in range(6):
        off = 0 if row % 2 == 0 else 6
        for x in range(-6 + off, 40, 12):
            d.rounded_rectangle([x, 64 - (row + 1) * 10, x + 12, 64 - row * 10 - 1], 3, fill=(150, 130, 90, 255), outline=OUTLINE)
    save(img.resize((80, 128), Image.NEAREST), base + "sandbag_barrier.png")


def gen_vfx():
    fx = "res://assets/effects/ww2/"
    # Topçu mermisi patlaması (6 kare)
    for k in range(6):
        img = Image.new("RGBA", (48, 48), CLEAR)
        d = ImageDraw.Draw(img)
        r = 6 + k * 4
        a = int(255 * (1 - k / 6.0))
        d.ellipse([24 - r, 30 - r, 24 + r, 30 + r * 0.6], fill=(255, 160, 50, a))
        d.ellipse([24 - r * 0.6, 30 - r * 0.6, 24 + r * 0.6, 30 + r * 0.3], fill=(255, 240, 170, a))
        for j in range(8):
            ang = j * math.tau / 8
            d.point((24 + math.cos(ang) * (r + 3), 30 + math.sin(ang) * (r + 3) * 0.6), fill=(60, 50, 40, a))
        save(img.resize((96, 96), Image.NEAREST), fx + "explosion_%d.png" % k)
    # Hedef işareti (topçu telegraph)
    img = Image.new("RGBA", (64, 12), CLEAR)
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, 63, 11], outline=(255, 60, 40, 230), width=2)
    d.line([(32, 0), (32, 11)], fill=(255, 60, 40, 230))
    save(img.resize((128, 24), Image.NEAREST), fx + "artillery_marker.png")
    # Zehirli gaz bulutu ve kül zerresi
    img = Image.new("RGBA", (32, 32), CLEAR)
    for y in range(32):
        for x in range(32):
            dist = math.hypot(x - 15.5, y - 15.5) / 16.0
            if dist < 1.0:
                img.putpixel((x, y), (150, 210, 80, int(150 * (1 - dist) ** 1.4)))
    save(img, fx + "gas_puff.png")
    save(Image.new("RGBA", (3, 3), (170, 160, 150, 220)), fx + "ash_flake.png")
    # Alev parçacığı ve okült ışın
    img = Image.new("RGBA", (12, 12), CLEAR)
    for y in range(12):
        for x in range(12):
            dist = math.hypot(x - 5.5, y - 5.5) / 6.0
            if dist < 1.0:
                c = (255, int(240 - 140 * dist), int(150 * (1 - dist)), int(255 * (1 - dist) ** 1.2))
                img.putpixel((x, y), c)
    save(img, fx + "flame_particle.png")
    beam = Image.new("RGBA", (256, 24), CLEAR)
    for y in range(24):
        k = 1.0 - abs(y - 11.5) / 12.0
        for x in range(256):
            beam.putpixel((x, y), (255, int(80 + 150 * k * k), int(60 + 60 * k), int(255 * min(1.0, k * 1.5))))
    save(beam, fx + "occult_beam.png")


# ---------------------------------------------------------------------------
# Arka planlar: her sahne için uzak / orta / yakın katman (+ kül partikülleri sahnede)
# ---------------------------------------------------------------------------
W, H = 1280, 720


def layer(fn):
    img = Image.new("RGBA", (W, H), CLEAR)
    fn(ImageDraw.Draw(img), img)
    return img


def skyline(d, base_y, color, seed, ruined=True, height=(80, 260)):
    rng = random.Random(seed)
    x = -20
    while x < W + 20:
        bw = rng.randint(50, 130)
        bh = rng.randint(*height)
        top = base_y - bh
        pts = [(x, base_y), (x, top)]
        if ruined:
            for k in range(1, 5):
                pts.append((x + bw * k / 5.0, top + rng.randint(0, 50)))
        pts += [(x + bw, top + rng.randint(0, 30)), (x + bw, base_y)]
        d.polygon(pts, fill=color)
        for wy in range(int(top) + 20, base_y - 20, 26):
            for wx in range(x + 10, x + bw - 10, 22):
                if rng.random() < 0.35:
                    d.rectangle([wx, wy, wx + 6, wy + 9], fill=(255, 140, 50, 255) if rng.random() < 0.4 else (20, 18, 20, 255))
        x += bw + rng.randint(4, 30)


def searchlight_beams(d, count, seed, ground):
    rng = random.Random(seed)
    for _ in range(count):
        x = rng.randint(80, W - 80)
        ang = math.radians(rng.randint(-35, 35))
        ln = rng.randint(380, 560)
        tip = (x + math.sin(ang) * ln, ground - math.cos(ang) * ln)
        spread = 40
        d.polygon([(x, ground), (tip[0] - spread, tip[1]), (tip[0] + spread, tip[1])], fill=(255, 250, 210, 34))


def fire_glow(img, y0):
    glow = Image.new("RGBA", (W, H), CLEAR)
    gd = ImageDraw.Draw(glow)
    for _ in range(12):
        x = RNG.randint(0, W)
        r = RNG.randint(60, 140)
        gd.ellipse([x - r, y0 - r // 2, x + r, y0 + r // 2], fill=(255, 110, 30, 90))
    return Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(18)))


def gen_backgrounds():
    bg = "res://assets/backgrounds/ww2/"
    # Ortak: yanan şehir ve hareketli projektörler (uzak katman)
    far = gradient(W, H, (34, 16, 20), (150, 60, 30))
    far = Image.alpha_composite(far, layer(lambda d, _i: searchlight_beams(d, 6, 4401, 560)))
    d = ImageDraw.Draw(far)
    skyline(d, 600, (46, 30, 34, 255), 4402, height=(120, 320))
    far = fire_glow(far, 590)
    save(far, bg + "ww2_far_burning_city.png")
    # Siperler: orta (dikenli tel, yıkık ağaçlar), yakın (siper ön planı)
    save(layer(lambda d, _i: (skyline(d, 640, (60, 46, 42, 255), 4403, height=(40, 140)),
                              [d.line([(x, 640), (x + RNG.randint(-12, 12), 640 - RNG.randint(60, 150))], fill=(40, 30, 26, 255), width=5) for x in range(40, W, 160)])),
         bg + "ww2_trenches_mid.png")

    def trench_near(d, _img):
        for x in range(0, W, 60):
            d.line([(x, 700), (x, 640)], fill=(52, 38, 30, 255), width=4)
            d.arc([x - 30, 630, x + 30, 660], 180, 360, fill=(110, 110, 116, 255), width=1)
        d.rectangle([0, 690, W, H], fill=(50, 36, 28, 255))
    save(layer(trench_near), bg + "ww2_trenches_near.png")

    # Yıkık şehir & viyadük: orta katman viyadük kemerleri
    def viaduct(d, _img):
        d.rectangle([0, 360, W, 384], fill=(70, 62, 60, 255))
        for x in range(0, W + 1, 160):
            d.rectangle([x - 20, 384, x + 20, 680], fill=(66, 58, 56, 255))
        for x in range(0, W, 24):
            d.line([(x, 356), (x + 14, 356)], fill=(40, 40, 44, 255), width=3)
    save(layer(viaduct), bg + "ww2_city_viaduct_mid.png")

    def rubble_near(d, _img):
        for _ in range(26):
            x = RNG.randint(0, W)
            w = RNG.randint(30, 90)
            d.polygon([(x, 720), (x + w * 0.3, 720 - RNG.randint(20, 80)), (x + w, 720)], fill=(44, 38, 38, 255))
        for x in range(0, W, 220):
            d.line([(x, 720), (x + 40, 560)], fill=(60, 50, 46, 255), width=8)
    save(layer(rubble_near), bg + "ww2_city_rubble_near.png")

    # Yeraltı laboratuvarı: duvar, borular, okült tüp ışıkları
    lab_far = gradient(W, H, (18, 20, 24), (44, 40, 46))
    d = ImageDraw.Draw(lab_far)
    for y in range(0, H, 48):
        for x in range(0 if (y // 48) % 2 == 0 else -48, W, 96):
            d.rectangle([x, y, x + 94, y + 46], outline=(30, 32, 36, 255), fill=(38, 40, 46, 255))
    lab_far = Image.alpha_composite(lab_far, layer(lambda d, _i: [d.rectangle([x, 120, x + 50, 520], fill=(255, 70, 80, 60), outline=(120, 130, 140, 255)) for x in range(100, W, 260)]))
    save(lab_far, bg + "ww2_lab_far.png")

    def pipes(d, _img):
        for y in (90, 140, 210):
            d.rectangle([0, y, W, y + 12], fill=(70, 76, 80, 255), outline=OUTLINE)
        for x in range(60, W, 180):
            d.rectangle([x, 0, x + 14, 600], fill=(64, 70, 74, 255), outline=OUTLINE)
            d.ellipse([x - 6, 300, x + 20, 326], fill=(120, 40, 40, 255), outline=OUTLINE)
    save(layer(pipes), bg + "ww2_lab_pipes_mid.png")

    def cables(d, _img):
        for k in range(10):
            x0 = RNG.randint(0, W)
            d.arc([x0 - 200, 600, x0 + 200, 760], 180, 360, fill=(20, 20, 22, 255), width=4)
    save(layer(cables), bg + "ww2_lab_cables_near.png")

    # Komuta sığınağı: harita masaları, okült makine
    bunker = gradient(W, H, (24, 22, 22), (70, 50, 40))
    d = ImageDraw.Draw(bunker)
    d.rectangle([0, 80, W, 110], fill=(60, 56, 52, 255))
    for x in range(0, W, 200):
        d.rectangle([x + 20, 110, x + 40, 600], fill=(54, 50, 48, 255))
    d.ellipse([500, 140, 780, 420], fill=(120, 30, 34, 255), outline=OCCULT_GOLD, width=5)
    for k in range(12):
        a = k * math.tau / 12
        d.line([(640 + math.cos(a) * 140, 280 + math.sin(a) * 140), (640 + math.cos(a) * 190, 280 + math.sin(a) * 190)], fill=OCCULT_RED, width=4)
    save(bunker, bg + "ww2_bunker_far.png")

    def bunker_mid(d, _img):
        for x in (160, 1120):
            d.rectangle([x - 60, 420, x + 60, 560], fill=(80, 70, 56, 255), outline=OUTLINE)
            d.rectangle([x - 54, 426, x + 54, 470], fill=(150, 140, 100, 255))
        for x in range(0, W, 90):
            d.ellipse([x, 60, x + 18, 78], fill=(255, 60, 40, 120))
    save(layer(bunker_mid), bg + "ww2_bunker_mid.png")

    # Anı Kırılması: zaman yırtığı boşluğu
    rift = gradient(W, H, (10, 8, 20), (70, 30, 60))
    d = ImageDraw.Draw(rift)
    for _ in range(9):
        x, y = RNG.randint(80, 1200), RNG.randint(40, 300)
        pts = [(x, y)]
        for _k in range(6):
            x += RNG.randint(-40, 40)
            y += RNG.randint(10, 40)
            pts.append((x, y))
        d.line(pts, fill=(120, 200, 255, 255), width=2)
    for _ in range(120):
        d.point((RNG.randint(0, W), RNG.randint(0, H)), fill=(255, 220, 160, 255))
    save(rift, bg + "ww2_memory_rift_far.png")

    # Zemin dokuları (NinePatch)
    for name, top, body in (("ww2_mud_ground", (92, 70, 50, 255), (60, 44, 32, 255)),
                            ("ww2_concrete_floor", (120, 118, 112, 255), (70, 68, 66, 255)),
                            ("ww2_lab_floor", (90, 96, 100, 255), (50, 54, 58, 255))):
        img = Image.new("RGBA", (64, 96), body)
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, 63, 7], fill=top)
        for _ in range(80):
            x, y = RNG.randint(0, 63), RNG.randint(8, 95)
            d.point((x, y), fill=tuple(max(0, c - 22) for c in body[:3]) + (255,))
        save(img, "res://assets/environment/ww2/%s.png" % name)


def gen_portraits():
    specs = (
        ("commander/commander_form1_sheet.png", (144, 152), (40, 20, 104, 84), "portrait_butcher_commander.png", (40, 16, 18)),
        ("trench_officer/trench_officer_sheet.png", (144, 120), (48, 0, 112, 64), "portrait_trench_officer.png", (50, 40, 30)),
        ("occult_doctor/occult_doctor_sheet.png", (96, 104), (24, 8, 72, 56), "portrait_occult_doctor.png", (30, 20, 30)),
        ("wounded_soldier/wounded_soldier_sheet.png", (56, 64), (8, 6, 48, 46), "portrait_wounded_soldier.png", (50, 56, 40)),
        ("prisoner/prisoner_sheet.png", (56, 64), (8, 6, 48, 46), "portrait_prisoner.png", (40, 44, 60)),
    )
    for rel, frame, box, name, bgc in specs:
        sheet = Image.open(out("res://assets/characters/ww2/" + rel)).convert("RGBA")
        crop = sheet.crop((0, 0) + frame).crop(box)
        canvas = Image.new("RGBA", crop.size, bgc + (255,))
        canvas.alpha_composite(crop)
        save(canvas.resize((256, 256), Image.NEAREST), "res://assets/ui/portraits/" + name)


def main():
    gen_enemies()
    gen_npcs()
    gen_minibosses()
    gen_commander()
    gen_items()
    gen_objects()
    gen_vfx()
    gen_backgrounds()
    gen_portraits()
    print("2. Dünya Savaşı assetleri üretildi.")


if __name__ == "__main__":
    main()
