# -*- coding: utf-8 -*-
"""Bölüm 5 (Distopik Gelecek) çevre / nesne / eşya / VFX asset üreticisi — Epic 2D-158.

Karakter sprite'ları kullanıcının yüklediği AI sheet'lerinden extract_future_sprites.py ile gelir.
Kaynak sheet'i olmayan çevre asset'leri burada katmanlı doku hattıyla üretilir:
  - fBm gürültü dokuları, hacim gölgelendirmesi (normal tabanlı ışık), neon yayma (bloom) ve
    atmosferik sis katmanları; düz renk/geometrik placeholder çizim kullanılmaz.
  - output/future_sources/<klasör>/<ad>.png mevcutsa (kullanıcı AI ile ürettiyse) o dosya
    temizlenip hedef boyuta getirilerek prosedürel sürümün yerine geçer (bkz. PROMPTS.md).
Çıktılar: assets/backgrounds/future, assets/environment/future, assets/objects/future,
assets/items/future, assets/effects/future (+ .tres SpriteFrames VFX paketleri).

Çalıştırma (repo kökünden):  py -3.10 2-dgame/tools/generate_future_assets.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from future_sheet_layout import SRC_ROOT  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
D_BG = os.path.join(ROOT, "assets", "backgrounds", "future")
D_ENV = os.path.join(ROOT, "assets", "environment", "future")
D_OBJ = os.path.join(ROOT, "assets", "objects", "future")
D_ITEM = os.path.join(ROOT, "assets", "items", "future")
D_VFX = os.path.join(ROOT, "assets", "effects", "future")
RNG = np.random.default_rng(158)

CYAN = np.array([60, 230, 255], np.float32)
MAGENTA = np.array([255, 60, 200], np.float32)
VIOLET = np.array([120, 70, 255], np.float32)
AMBER = np.array([255, 170, 60], np.float32)
RED = np.array([255, 50, 70], np.float32)


# ---------------------------------------------------------------------------
# Doku çekirdeği
# ---------------------------------------------------------------------------
def value_noise(w, h, cell, seed_off=0):
    rng = np.random.default_rng(158 + seed_off)
    gw, gh = w // cell + 2, h // cell + 2
    grid = rng.random((gh, gw)).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8)).resize((gw * cell, gh * cell), Image.BICUBIC)
    return np.asarray(img).astype(np.float32)[:h, :w] / 255.0


def fbm(w, h, base=128, octaves=5, seed=0):
    total = np.zeros((h, w), np.float32)
    amp, norm = 1.0, 0.0
    cell = base
    for o in range(octaves):
        total += value_noise(w, h, max(2, cell), seed * 31 + o) * amp
        norm += amp
        amp *= 0.5
        cell //= 2
    return total / norm


def vgrad(h, w, top, bottom):
    t = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    return np.broadcast_to(np.asarray(top, np.float32) * (1 - t) + np.asarray(bottom, np.float32) * t, (h, w, 3)).copy()


def shade(height, light=(-0.6, -0.8), strength=2.2):
    gy, gx = np.gradient(height)
    lx, ly = light
    return np.clip(0.5 + (gx * lx + gy * ly) * strength * 10.0, 0.0, 1.0)


def bloom(rgba, radius=6, gain=0.9):
    # yalnızca parlak pikseller (neon) yayılır; mat yüzeyler soluklaşmaz
    lum = rgba[..., :3].max(axis=2)
    bright = rgba.copy()
    bright[..., 3] = np.where(lum > 170, rgba[..., 3], 0)
    img = Image.fromarray(np.clip(bright, 0, 255).astype(np.uint8), "RGBA")
    glow = np.asarray(img.filter(ImageFilter.GaussianBlur(radius))).astype(np.float32)
    out = rgba.copy()
    out[..., :3] = np.clip(out[..., :3] + glow[..., :3] * gain * (glow[..., 3:4] / 255.0), 0, 255)
    out[..., 3] = np.maximum(out[..., 3], glow[..., 3] * 0.55)
    return out


def to_img(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def override(folder, name, size):
    """Kullanıcı AI ile ürettiyse future_sources/<folder>/<name>.png kullanılır."""
    path = os.path.join(SRC_ROOT, folder, name + ".png")
    if not os.path.exists(path):
        return None
    img = Image.open(path).convert("RGBA")
    return img.resize(size, Image.LANCZOS) if size else img


def save(img, folder, name, src_folder=None):
    os.makedirs(folder, exist_ok=True)
    if src_folder:
        repl = override(src_folder, name, img.size)
        if repl is not None:
            img = repl
    img.save(os.path.join(folder, name + ".png"), optimize=True)
    return img


def neon_line(draw_layer, pts, color, width=2):
    d = ImageDraw.Draw(draw_layer)
    d.line(pts, fill=tuple(int(c) for c in color) + (255,), width=width)


# ---------------------------------------------------------------------------
# Parallax (4 katman, 1920x720)
# ---------------------------------------------------------------------------
W, H = 1920, 720


def bg_sky():
    sky = vgrad(H, W, (10, 6, 28), (70, 18, 70))
    clouds = fbm(W, H, 256, 6, 1)
    clouds = np.clip((clouds - 0.42) * 2.4, 0, 1)
    lit = shade(fbm(W, H, 256, 6, 1), (0.2, -1.0), 3.0)
    tint = MAGENTA * 0.35 * (np.linspace(0.2, 1.0, H)[:, None, None]) + CYAN * 0.12
    sky = sky * (1 - clouds[..., None] * 0.7) + (sky * 0.6 + tint * lit[..., None]) * clouds[..., None] * 0.9
    horizon = np.exp(-((np.arange(H) - H * 0.78) / 70.0) ** 2)[:, None, None]
    sky += MAGENTA * 0.45 * horizon
    arr = np.dstack([sky, np.full((H, W), 255.0)])
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for _ in range(3):  # yıldırım
        x = RNG.integers(200, W - 200)
        pts, y = [], 0
        while y < H * 0.6:
            pts.append((x, y))
            x += RNG.integers(-30, 31)
            y += RNG.integers(20, 45)
        neon_line(layer, pts, (210, 200, 255), 2)
    arr = arr + bloom(np.asarray(layer).astype(np.float32), 8, 1.4) * (np.asarray(layer)[..., 3:4] > -1)
    rain = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(rain)
    for _ in range(1400):
        x, y = RNG.integers(0, W), RNG.integers(0, H)
        d.line([(x, y), (x - 4, y + 18)], fill=(150, 170, 255, int(RNG.integers(25, 70))), width=1)
    out = to_img(arr)
    out.alpha_composite(rain)
    return save(out.convert("RGBA"), D_BG, "bg_sky_neon_storm", "parallax")


def _tower_layer(seed, count, hmin, hmax, wmin, wmax, base_col, window_col, haze):
    arr = np.zeros((H, W, 4), np.float32)
    rng = np.random.default_rng(seed)
    tex = fbm(W, H, 32, 4, seed)
    x = -40
    while x < W:
        tw = int(rng.integers(wmin, wmax))
        th = int(rng.integers(hmin, hmax))
        top = H - th
        broken = rng.random() < 0.55
        for cx in range(max(0, x), min(W, x + tw)):
            jag = int(abs(math.sin(cx * 0.21 + seed)) * 26) if broken else 0
            col_top = top + jag
            edge = 1.0 - 0.35 * ((cx - x) / max(1, tw))
            arr[col_top:, cx, :3] = np.asarray(base_col, np.float32) * edge * (0.75 + tex[col_top:, cx, None] * 0.5)
            arr[col_top:, cx, 3] = 255
        # pencere ızgarası
        for wy in range(top + 18, H, 14):
            for wx in range(x + 6, x + tw - 6, 10):
                if 0 <= wx < W - 4 and rng.random() < 0.38:
                    c = window_col if rng.random() < 0.8 else MAGENTA
                    arr[wy:wy + 5, wx:wx + 4, :3] = c * rng.uniform(0.5, 1.0)
        if rng.random() < 0.5 and 0 <= x + tw // 2 < W:  # anten ışığı
            ax = x + tw // 2
            arr[max(0, top - 30):top, ax:ax + 2, :3] = 40
            arr[max(0, top - 30):top, ax:ax + 2, 3] = 255
            arr[max(0, top - 34):max(0, top - 30), ax - 1:ax + 3, :3] = RED
            arr[max(0, top - 34):max(0, top - 30), ax - 1:ax + 3, 3] = 255
        x += tw + int(rng.integers(-10, 30))
    fog = np.linspace(0, 1, H, dtype=np.float32)[:, None] ** 2
    arr[..., :3] = arr[..., :3] * (1 - haze * fog[..., None]) + np.array([90, 30, 110]) * haze * fog[..., None]
    return bloom(arr, 4, 0.8)


def bg_skyscrapers():
    arr = _tower_layer(5, 20, 260, 520, 70, 150, (30, 26, 58), CYAN * 0.8, 0.45)
    return save(to_img(arr), D_BG, "bg_distant_skyscrapers", "parallax")


def bg_viaduct():
    arr = np.zeros((H, W, 4), np.float32)
    tex = fbm(W, H, 48, 5, 9)
    deck_y = 300
    arr[deck_y:deck_y + 46, :, :3] = (np.array([46, 44, 70]) * (0.7 + tex[deck_y:deck_y + 46, :, None] * 0.6))
    arr[deck_y:deck_y + 46, :, 3] = 255
    arr[deck_y + 46:deck_y + 52, :, :3] = CYAN * 0.9
    arr[deck_y + 46:deck_y + 52, :, 3] = 255
    for px in range(60, W, 300):  # kemer ayakları
        for y in range(deck_y + 52, H):
            half = 34 + int((y - deck_y) * 0.08)
            x0, x1 = max(0, px - half), min(W, px + half)
            shade_col = np.linspace(0.55, 1.0, x1 - x0)[:, None]
            arr[y, x0:x1, :3] = np.array([40, 36, 62]) * shade_col * (0.7 + tex[y, x0:x1, None] * 0.5)
            arr[y, x0:x1, 3] = 255
    gap = (980, 1170)  # çökmüş açıklık
    arr[deck_y - 10:deck_y + 60, gap[0]:gap[1], 3] = 0
    rail = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(rail)
    d.line([(0, deck_y - 22), (gap[0], deck_y - 22)], fill=(80, 80, 110, 255), width=6)
    d.line([(gap[1], deck_y - 22), (W, deck_y - 22)], fill=(80, 80, 110, 255), width=6)
    for sx in range(140, W, 420):  # neon tabelalar
        col = tuple(int(c) for c in (MAGENTA if (sx // 420) % 2 else CYAN)) + (255,)
        d.rectangle([sx, deck_y - 120, sx + 70, deck_y - 60], outline=col, width=3)
        for k in range(4):
            d.line([(sx + 10, deck_y - 108 + k * 12), (sx + 20 + (k * 13) % 40, deck_y - 108 + k * 12)], fill=col, width=3)
        d.line([(sx + 35, deck_y - 60), (sx + 35, deck_y)], fill=(60, 60, 80, 255), width=3)
    out = to_img(bloom(arr, 4, 0.6))
    out.alpha_composite(to_img(bloom(np.asarray(rail).astype(np.float32), 5, 1.0)))
    return save(out, D_BG, "bg_mid_viaduct_monorail", "parallax")


def bg_cables():
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(14):  # sarkan kablolar
        x0 = int(RNG.integers(0, W)); x1 = x0 + int(RNG.integers(120, 420)); sag = int(RNG.integers(40, 160))
        pts = [(x0 + (x1 - x0) * t / 20.0, sag * math.sin(math.pi * t / 20.0) + 10) for t in range(21)]
        d.line(pts, fill=(18, 16, 30, 255), width=int(RNG.integers(3, 7)))
    for i in range(10):  # enkaz yığınları
        cx = int(RNG.integers(0, W)); w = int(RNG.integers(80, 220)); h = int(RNG.integers(40, 120))
        poly = [(cx - w // 2, H), (cx - w // 3, H - h * 0.6), (cx - w // 8, H - h), (cx + w // 5, H - h * 0.7), (cx + w // 2, H)]
        d.polygon(poly, fill=(14, 12, 24, 255))
        d.line([(cx - w // 3, H - h * 0.6), (cx + w // 2 + 20, H - h - 30)], fill=(40, 36, 52, 255), width=3)
    arr = np.asarray(layer).astype(np.float32)
    tex = fbm(W, H, 16, 3, 11)
    arr[..., :3] *= (0.7 + tex[..., None] * 0.6)
    holo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hd = ImageDraw.Draw(holo)
    for i in range(7):  # kayan hologram kalıntıları
        x = int(RNG.integers(40, W - 120)); y = int(RNG.integers(260, 560)); w = int(RNG.integers(50, 110))
        col = tuple(int(c) for c in (CYAN if i % 2 else MAGENTA))
        for k in range(0, 40, 4):
            hd.line([(x + int(RNG.integers(-6, 6)), y + k), (x + w, y + k)], fill=col + (70,), width=2)
        hd.rectangle([x, y, x + w, y + 40], outline=col + (150,), width=1)
    for _ in range(500):  # neon yağmur
        x, y = int(RNG.integers(0, W)), int(RNG.integers(0, H))
        hd.line([(x, y), (x - 3, y + 14)], fill=(120, 220, 255, int(RNG.integers(40, 110))), width=1)
    out = to_img(arr)
    out.alpha_composite(to_img(bloom(np.asarray(holo).astype(np.float32), 3, 0.8)))
    return save(out, D_BG, "bg_fg_cables_debris", "parallax")


# ---------------------------------------------------------------------------
# Tilesetler (256x256 = 4x4 x 64px) + zemin nine-patch dokuları (64x96)
# ---------------------------------------------------------------------------
TILE = 64


def surface(w, h, seed, base, accent, style):
    n = fbm(w, h, 32, 5, seed)
    cracks = fbm(w, h, 8, 3, seed + 3)
    col = np.asarray(base, np.float32) * (0.62 + 0.55 * n[..., None])
    light = shade(n, (-0.5, -0.9), 1.6)[..., None]
    col = col * (0.75 + light * 0.5)
    if style == "ruins":
        crack = (np.abs(cracks - 0.5) < 0.018)
        col[crack] *= 0.35
        rebar = (np.arange(w)[None, :] % 21 == 0) & (np.arange(h)[:, None] > h * 0.55)
        col[rebar] = col[rebar] * 0.4 + np.array([110, 70, 50]) * 0.6
    elif style == "factory":
        rows = (np.arange(h)[:, None] % 16 < 2)
        col[np.broadcast_to(rows, (h, w))] *= 0.55
        rivets = ((np.arange(w)[None, :] % 16 == 8) & (np.arange(h)[:, None] % 16 == 8))
        col[rivets] = np.array([200, 200, 210])
        hazard = (np.arange(h)[:, None] < 6) & (((np.arange(w)[None, :] + np.arange(h)[:, None]) // 6) % 2 == 0)
        col[np.broadcast_to(hazard, (h, w))] = AMBER * 0.85
    else:  # citadel
        circuit = ((np.arange(w)[None, :] % 24 == 0) | (np.arange(h)[:, None] % 24 == 12)) & (cracks > 0.55)
        col[circuit] = CYAN
    top = np.zeros((h, w), bool)
    top[:5] = True
    col[top] = col[top] * 0.4 + np.asarray(accent, np.float32) * 0.6
    arr = np.dstack([col, np.full((h, w), 255.0)])
    return bloom(arr, 2, 0.35)


def tilesets():
    specs = [("tileset_neon_ruins", "ground_neon_ruins", (70, 66, 82), MAGENTA, "ruins", 21),
             ("tileset_cyber_factory", "ground_cyber_factory", (64, 70, 84), AMBER, "factory", 22),
             ("tileset_core_citadel", "ground_core_citadel", (26, 28, 50), CYAN, "citadel", 23)]
    for name, ground, base, accent, style, seed in specs:
        atlas = Image.new("RGBA", (TILE * 4, TILE * 4), (0, 0, 0, 0))
        for i in range(16):
            tile = surface(TILE, TILE, seed * 10 + i, base, accent, style)
            if i // 4 > 0:  # yalnızca üst sıra kaplamalı kenar taşır
                tile[:5, :, :3] = tile[6:11, :, :3]
            if i % 4 == 3:  # kırık köşe
                yy, xx = np.mgrid[0:TILE, 0:TILE]
                tile[(xx + yy * 0.7) > TILE * 1.25, 3] = 0
            atlas.paste(to_img(tile), ((i % 4) * TILE, (i // 4) * TILE))
        save(atlas, D_ENV, name, "tilesets")
        save(to_img(surface(64, 96, seed, base, accent, style)), D_ENV, ground)


# ---------------------------------------------------------------------------
# Prop / tuzak / nesne
# ---------------------------------------------------------------------------
def panel(w, h, seed, base=(48, 52, 72), accent=CYAN, rim=True):
    arr = surface(w, h, seed, base, accent, "citadel")
    if rim:
        arr[:, :2, :3] *= 0.4
        arr[:, -2:, :3] *= 0.4
        arr[-2:, :, :3] *= 0.4
    return arr


def sigil(draw, cx, cy, r, col):
    """Kılıç kabzasındaki kadim mühür (Bölüm 1 omuz soketindeki damga ile aynı motif)."""
    c = tuple(int(v) for v in col) + (255,)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=c, width=3)
    draw.polygon([(cx, cy - r + 4), (cx + r * 0.55, cy + r * 0.45), (cx - r * 0.55, cy + r * 0.45)], outline=c, width=2)
    draw.line([(cx, cy - r + 4), (cx, cy + r - 2)], fill=c, width=2)
    draw.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=c)


def _factory_new(name):
    """Bölüm 1'de Taş Devri'ne düşen parçanın "fabrikadan yeni çıkmış" hâli: yosun/pas rengi metale çevrilir."""
    src = np.asarray(Image.open(os.path.join(ROOT, "assets", "mechanical", "stoneage", name)).convert("RGBA")).astype(np.float32)
    gray = src[..., :3].mean(2, keepdims=True)
    cyan_glow = (src[..., 1:2] > src[..., 0:1] + 40) & (src[..., 2:3] > src[..., 0:1] + 30)
    metal = gray * np.array([0.85, 0.92, 1.1]) * 1.1
    src[..., :3] = np.where(cyan_glow, src[..., :3], metal)
    return to_img(src)


def props():
    # Damgalı armatür kalıbı: Bölüm 1'deki dev omuz soketinin üretim kalıbı
    mold = to_img(panel(220, 170, 31, (54, 50, 66), AMBER))
    mold.alpha_composite(_factory_new("massive_armature_socket_fissure.png").resize((180, 125)), (20, 30))
    d = ImageDraw.Draw(mold)
    sigil(d, 186, 32, 18, AMBER)
    save(to_img(bloom(np.asarray(mold).astype(np.float32), 3, 0.6)), D_OBJ, "prop_stamped_armature_mold", "props")
    # T-Rex sibernetik zırh ünitesi (fırlatma kızağında)
    harness = to_img(panel(260, 150, 32, (40, 44, 60), RED))
    claw = _factory_new("domain_heavy_claw_sheath.png")
    spine = _factory_new("domain_reinforcing_spine_strut.png")
    harness.alpha_composite(spine.resize((200, 120)), (30, 10))
    harness.alpha_composite(claw.resize((90, 70)), (160, 70))
    d = ImageDraw.Draw(harness)
    d.text((12, 128), "UNIT-REX-01", fill=(255, 80, 90, 255))
    sigil(d, 236, 22, 14, AMBER)
    save(to_img(bloom(np.asarray(harness).astype(np.float32), 3, 0.7)), D_OBJ, "prop_trex_cyber_harness", "props")
    # Kırık hologram projektörü
    holo = Image.new("RGBA", (96, 128), (0, 0, 0, 0))
    holo.alpha_composite(to_img(panel(96, 28, 33)), (0, 100))
    d = ImageDraw.Draw(holo)
    for k in range(0, 90, 5):
        d.line([(18 + int(RNG.integers(-5, 5)), k + 6), (78, k + 6)], fill=(80, 230, 255, 90), width=2)
    sigil(d, 48, 48, 22, CYAN)
    save(to_img(bloom(np.asarray(holo).astype(np.float32), 4, 0.9)), D_OBJ, "prop_broken_hologram", "props")
    # Kriyo kapsülü ve tahliye kapsülü
    for name, w, h, accent, seed in (("prop_cryo_pod", 72, 140, CYAN, 34), ("prop_evac_capsule", 120, 150, AMBER, 35)):
        arr = panel(w, h, seed, (60, 66, 84), accent)
        yy, xx = np.mgrid[0:h, 0:w]
        glass = ((xx - w / 2) ** 2 / (w * 0.3) ** 2 + (yy - h * 0.42) ** 2 / (h * 0.3) ** 2) < 1
        arr[glass, :3] = arr[glass, :3] * 0.3 + accent * 0.45
        top_round = ((xx - w / 2) ** 2 / (w / 2) ** 2 + (yy - h * 0.2) ** 2 / (h * 0.2) ** 2 > 1) & (yy < h * 0.2)
        arr[top_round, 3] = 0
        save(to_img(bloom(arr, 3, 0.7)), D_OBJ, name, "props")


def traps():
    # Lazer kapısı direkleri
    post = panel(24, 140, 41, (50, 50, 70), RED)
    post[8:14, 6:18, :3] = RED
    save(to_img(bloom(post, 3, 1.0)), D_OBJ, "trap_laser_gate", "traps")
    # Hidrolik pres: kafa + piston (tek doku, üstte piston)
    press = np.zeros((220, 110, 4), np.float32)
    press[:150, 40:70] = panel(30, 150, 42, (110, 110, 120), AMBER)
    press[150:, :] = panel(110, 70, 43, (70, 72, 86), AMBER)
    press[150:158, :, :3] = AMBER * 0.9
    save(to_img(bloom(press, 2, 0.4)), D_OBJ, "trap_hydraulic_press", "traps")
    # Plazma kanalı
    ch = panel(128, 32, 44, (40, 40, 56), MAGENTA)
    ch[10:22, 6:122, :3] = MAGENTA * (0.7 + 0.3 * fbm(116, 12, 4, 2, 45)[..., None])
    save(to_img(bloom(ch, 4, 1.1)), D_OBJ, "trap_plasma_channel", "traps")
    # Konveyör bandı (4 karelik akış animasyonu)
    for f in range(4):
        belt = panel(128, 24, 46, (56, 58, 66), AMBER, rim=False)
        for x in range(-16, 128, 16):
            xx = x + f * 4
            if 0 <= xx < 126:
                belt[3:21, xx:xx + 2, :3] *= 0.45
        save(to_img(belt), D_OBJ, "obj_conveyor_belt_%d" % f)
    # EMP terminali, sunucu düğümü, zaman mühürlü kapı, kontrol noktası işareti
    for name, (w, h), accent, seed in (("obj_emp_terminal", (48, 72), CYAN, 47), ("obj_server_node", (56, 96), MAGENTA, 48),
                                       ("obj_resonance_door", (64, 200), AMBER, 49), ("obj_checkpoint_beacon", (32, 96), CYAN, 50)):
        arr = panel(w, h, seed, (46, 50, 70), accent)
        arr[h // 5:h // 5 + 8, 6:w - 6, :3] = accent
        img = to_img(bloom(arr, 3, 0.8))
        if name == "obj_resonance_door":
            sigil(ImageDraw.Draw(img), w // 2, h // 2, 20, AMBER)
        save(img, D_OBJ, name, "traps")
        dim = np.asarray(img).astype(np.float32)
        dim[..., :3] *= 0.45
        save(to_img(dim), D_OBJ, name + "_off")
    # Gizli kırılabilir duvar ve yamalı zaman radyosu
    wall = surface(64, 128, 51, (66, 62, 80), MAGENTA, "ruins")
    save(to_img(wall), D_OBJ, "obj_secret_wall")
    radio = to_img(panel(44, 32, 52, (90, 70, 50), AMBER))
    d = ImageDraw.Draw(radio)
    d.ellipse([6, 8, 20, 22], outline=(40, 30, 20, 255), width=2)
    d.line([(26, 12), (38, 12)], fill=(255, 170, 60, 255), width=2)
    d.line([(34, 0), (40, 8)], fill=(150, 150, 160, 255), width=1)
    save(radio, D_OBJ, "obj_patchwork_radio")


# ---------------------------------------------------------------------------
# Eşya ikonları (32x32) ve 5. Kalp Parçası (40x48)
# ---------------------------------------------------------------------------
def icon(draw_fn, name, size=(32, 32)):
    img = Image.new("RGBA", (size[0] * 4, size[1] * 4), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(img), img.size)
    arr = bloom(np.asarray(img).astype(np.float32), 5, 0.6)
    save(to_img(arr).resize(size, Image.LANCZOS), D_ITEM, name, "items_vfx")


def items():
    def kit(d, s):
        d.rounded_rectangle([14, 30, 114, 110], 14, fill=(200, 205, 215, 255), outline=(30, 30, 40, 255), width=5)
        d.rectangle([54, 44, 74, 96], fill=(60, 220, 255, 255)); d.rectangle([38, 60, 90, 80], fill=(60, 220, 255, 255))
    def injector(d, s):
        d.polygon([(20, 104), (84, 40), (100, 56), (36, 120)], fill=(170, 180, 200, 255), outline=(30, 30, 40, 255))
        d.polygon([(40, 92), (80, 52), (90, 62), (50, 102)], fill=(255, 170, 60, 255))
        d.line([(96, 30), (112, 14)], fill=(220, 220, 230, 255), width=6)
    def phase(d, s):
        d.ellipse([20, 20, 108, 108], fill=(80, 60, 200, 200), outline=(170, 150, 255, 255), width=6)
        d.ellipse([44, 44, 84, 84], fill=(220, 210, 255, 255))
    def emp(d, s):
        d.ellipse([24, 32, 104, 112], fill=(60, 66, 84, 255), outline=(20, 20, 30, 255), width=5)
        d.rectangle([54, 14, 74, 36], fill=(120, 120, 130, 255))
        for k in range(3):
            d.arc([30 - k * 8, 38 - k * 8, 98 + k * 8, 106 + k * 8], 200, 340, fill=(60, 230, 255, 255), width=4)
    def flare(d, s):
        d.rectangle([52, 30, 76, 112], fill=(90, 40, 80, 255), outline=(20, 10, 20, 255), width=4)
        d.polygon([(64, 4), (82, 34), (46, 34)], fill=(255, 80, 210, 255))
    def chip(d, s):
        d.rectangle([28, 28, 100, 100], fill=(30, 40, 50, 255), outline=(60, 230, 255, 255), width=5)
        for k in range(36, 96, 14):
            d.line([(14, k), (28, k)], fill=(200, 180, 90, 255), width=4); d.line([(100, k), (114, k)], fill=(200, 180, 90, 255), width=4)
        sigil(d, 64, 64, 22, CYAN)
    def tag(d, s):
        d.rounded_rectangle([30, 26, 98, 106], 10, fill=(150, 150, 160, 255), outline=(40, 40, 50, 255), width=4)
        d.line([(44, 56), (84, 56)], fill=(40, 40, 50, 255), width=5); d.line([(44, 74), (76, 74)], fill=(40, 40, 50, 255), width=5)
        d.line([(64, 4), (64, 26)], fill=(120, 120, 130, 255), width=3)
    def proto(d, s):
        d.polygon([(20, 90), (50, 30), (100, 40), (108, 96), (60, 112)], fill=(80, 84, 100, 255), outline=(20, 20, 30, 255))
        sigil(d, 66, 72, 20, AMBER)
    for fn, name in ((kit, "nano_repair_kit"), (injector, "chrono_injector"), (phase, "phase_shield_capsule"),
                     (emp, "emp_grenade"), (flare, "plasma_cutter_flare"), (chip, "core_access_chip"),
                     (tag, "resistance_tag"), (proto, "stamped_prototype_part")):
        icon(fn, name)

    def heart(d, s):
        w, h = s
        d.polygon([(w / 2, h - 12), (10, h * 0.38), (w * 0.3, 14), (w / 2, h * 0.28), (w * 0.7, 14), (w - 10, h * 0.38)],
                  fill=(255, 60, 120, 255), outline=(60, 230, 255, 255))
        for k in range(4):
            d.line([(w * 0.3, h * (0.35 + k * 0.1)), (w * 0.7, h * (0.35 + k * 0.1))], fill=(60, 230, 255, 255), width=4)
        d.ellipse([w / 2 - 14, h * 0.45 - 14, w / 2 + 14, h * 0.45 + 14], fill=(255, 255, 255, 255))
    icon(heart, "heart_piece_5", (40, 48))


# ---------------------------------------------------------------------------
# VFX: particle dokuları + SpriteFrames paketleri
# ---------------------------------------------------------------------------
def radial(size, col, power=2.0):
    yy, xx = np.mgrid[0:size, 0:size]
    r = np.sqrt((xx - size / 2 + 0.5) ** 2 + (yy - size / 2 + 0.5) ** 2) / (size / 2)
    a = np.clip(1 - r, 0, 1) ** power
    arr = np.zeros((size, size, 4), np.float32)
    arr[..., :3] = col
    arr[..., 3] = a * 255
    return arr


def particles():
    save(to_img(radial(16, CYAN, 1.6)), D_VFX, "neon_spark")
    save(to_img(radial(16, MAGENTA, 1.6)), D_VFX, "magenta_spark")
    streak = np.zeros((16, 3, 4), np.float32); streak[..., :3] = (150, 220, 255); streak[..., 3] = np.linspace(0, 200, 16)[:, None]
    save(to_img(streak), D_VFX, "neon_rain_streak")
    glitch = np.zeros((8, 8, 4), np.float32); glitch[..., :3] = CYAN; glitch[..., 3] = 230; glitch[:3, :, :3] = MAGENTA
    save(to_img(glitch), D_VFX, "glitch_pixel")
    shard = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    ImageDraw.Draw(shard).polygon([(2, 14), (8, 1), (14, 10)], fill=(220, 210, 200, 255), outline=(255, 90, 120, 255))
    save(shard, D_VFX, "sword_shell_shard")


def frames_tres(name, frame_files, fps, loop, folder="effects/future"):
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(frame_files) + 1), ""]
    for i, f in enumerate(frame_files):
        lines.append('[ext_resource type="Texture2D" path="res://assets/%s/%s" id="%d_f"]' % (folder, f, i + 1))
    lines.append("")
    entries = ", ".join('{\n"duration": 1.0,\n"texture": ExtResource("%d_f")\n}' % (i + 1) for i in range(len(frame_files)))
    lines += ["[resource]", 'animations = [{\n"frames": [%s],\n"loop": %s,\n"name": &"default",\n"speed": %.1f\n}]' % (
        entries, "true" if loop else "false", fps), ""]
    with open(os.path.join(D_VFX, name + ".tres"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))


def anim_from(src_png, name, count, scale_from, scale_to, rot, fade, fps=14, loop=False, size=128):
    src = Image.open(os.path.join(D_VFX, src_png)).convert("RGBA")
    files = []
    for i in range(count):
        t = i / max(1, count - 1)
        s = scale_from + (scale_to - scale_from) * t
        im = src.resize((max(1, int(src.width * s)), max(1, int(src.height * s))), Image.LANCZOS).rotate(rot * t, expand=True)
        a = np.asarray(im).astype(np.float32)
        a[..., 3] *= (1 - t) if fade else (0.4 + 0.6 * math.sin(math.pi * t))
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        tile = to_img(a)
        if max(tile.size) > size:
            f = size / max(tile.size)
            tile = tile.resize((max(1, int(tile.width * f)), max(1, int(tile.height * f))), Image.LANCZOS)
        canvas.alpha_composite(tile, ((size - tile.width) // 2, (size - tile.height) // 2))
        fname = "%s_%02d.png" % (name, i)
        canvas.save(os.path.join(D_VFX, fname))
        files.append(fname)
    frames_tres(name, files, fps, loop)


def shatter_frames(name="vfx_sword_shell_shatter", count=16, size=192):
    files = []
    rng = np.random.default_rng(77)
    dirs = [(math.cos(a), math.sin(a)) for a in rng.uniform(0, math.tau, 26)]
    for i in range(count):
        t = i / (count - 1)
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        c = size / 2
        if t < 0.35:  # çatlak ağı
            for k, (dx, dy) in enumerate(dirs[:12]):
                L = 20 + 60 * (t / 0.35)
                d.line([(c, c), (c + dx * L, c + dy * L)], fill=(255, 90, 140, 255), width=2)
        for k, (dx, dy) in enumerate(dirs):  # dağılan kabuk parçaları
            if t >= 0.3:
                L = (t - 0.3) / 0.7 * 88 * (0.6 + (k % 5) * 0.1)
                x, y = c + dx * L, c + dy * L
                s = 6 + k % 4
                d.polygon([(x, y - s), (x + s, y + s * 0.6), (x - s * 0.7, y + s * 0.4)],
                          fill=(210, 200, 190, int(255 * (1.2 - t))), outline=(255, 70, 120, 255))
        r = 10 + 70 * t
        d.ellipse([c - r, c - r, c + r, c + r], outline=(255, 60, 140, int(255 * (1 - t))), width=4)
        arr = bloom(np.asarray(img).astype(np.float32), 5, 0.9)
        fname = "%s_%02d.png" % (name, i)
        to_img(arr).save(os.path.join(D_VFX, fname))
        files.append(fname)
    frames_tres(name, files, 14, False)


def vfx_packages():
    particles()
    anim_from("ai_lord_time_ripple.png", "ai_lord_teleport_vfx", 16, 0.3, 1.6, 180, True, 16)
    anim_from("emp_ring.png", "vfx_emp_blast", 16, 0.2, 2.2, 90, True, 16, size=192)
    anim_from("time_clock_ring.png", "vfx_time_fracture", 16, 0.5, 1.1, -120, False, 12, True)
    anim_from("time_vortex.png", "vfx_sixth_core_aura", 16, 0.7, 0.9, 360, False, 12, True)
    shatter_frames()


def main():
    for fn in (bg_sky, bg_skyscrapers, bg_viaduct, bg_cables, tilesets, props, traps, items, vfx_packages):
        fn()
        print("ok:", fn.__name__)


if __name__ == "__main__":
    main()
