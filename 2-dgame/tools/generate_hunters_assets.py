"""
generate_hunters_assets.py
Vectorized & fast generation of distinct pixel-art environment, prop, tileset,
and background assets for Stone Age Level 04: Avcıların İzleri (Traces of the Hunters).
"""

import os
import math
import numpy as np
from PIL import Image, ImageDraw

BG_DIR = "assets/backgrounds/stoneage"
TILE_DIR = "assets/tilesets/stoneage"
PROP_DIR = "assets/props/stoneage"
FX_DIR = "assets/effects/stoneage"

for d in [BG_DIR, TILE_DIR, PROP_DIR, FX_DIR]:
    os.makedirs(d, exist_ok=True)


def noise2d(w, h, scale=10.0, seed=42):
    np.random.seed(seed)
    nw, nh = max(2, int(w / scale)), max(2, int(h / scale))
    grid = np.random.rand(nh, nw).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8)).resize((w, h), Image.Resampling.BILINEAR)
    return np.array(img).astype(np.float32) / 255.0


def make_far_misty_canopy():
    w, h = 1920, 1080
    canvas = np.zeros((h, w, 3), dtype=np.uint8)

    # 1. Sky gradient
    y_indices = np.arange(h)[:, None]
    t = y_indices / float(h)
    r = (32 * (1 - t) + 52 * t).astype(np.uint8)
    g = (44 * (1 - t) + 64 * t).astype(np.uint8)
    b = (54 * (1 - t) + 76 * t).astype(np.uint8)
    canvas[:, :, 0] = r
    canvas[:, :, 1] = g
    canvas[:, :, 2] = b

    # 2. Distant mountain ridges
    n1 = noise2d(w, 200, scale=40, seed=101)
    n2 = noise2d(w, 300, scale=30, seed=102)

    base1 = int(h * 0.45)
    base2 = int(h * 0.58)

    # Ridge 1
    for x in range(w):
        y1 = max(0, min(h - 1, base1 - int(n1[100, x] * 120 + math.sin(x * 0.003) * 60)))
        canvas[y1:h, x, 0] = (canvas[y1:h, x, 0].astype(np.float32) * 0.45 + 26 * 0.55).astype(np.uint8)
        canvas[y1:h, x, 1] = (canvas[y1:h, x, 1].astype(np.float32) * 0.45 + 36 * 0.55).astype(np.uint8)
        canvas[y1:h, x, 2] = (canvas[y1:h, x, 2].astype(np.float32) * 0.45 + 46 * 0.55).astype(np.uint8)

    # Ridge 2
    for x in range(w):
        y2 = max(0, min(h - 1, base2 - int(n2[150, x] * 140 + math.cos(x * 0.004) * 80)))
        canvas[y2:h, x] = [22, 32, 40]

    # Distant tree spires on ridge 2
    for tx in range(0, w, 22):
        th = int(35 + n1[100, tx] * 55)
        ty = base2 - int(n2[150, min(w - 1, tx)] * 140 + math.cos(tx * 0.004) * 80)
        for dy in range(th):
            curr_y = ty - dy
            if 0 <= curr_y < h:
                wl = int(max(1, (th - dy) * 0.35))
                canvas[curr_y, max(0, tx - wl):min(w, tx + wl + 1)] = [18, 28, 34]

    # Vectorized mist blend
    mist = noise2d(w, h, scale=60, seed=777)
    y_start = int(h * 0.3)
    y_factors = ((np.arange(y_start, h) - y_start) / float(h - y_start))[:, None]
    m_slice = mist[y_start:h, :] * 0.35 * y_factors
    m_slice = np.repeat(m_slice[:, :, None], 3, axis=2)
    fog_col = np.array([45.0, 58.0, 68.0])

    sub = canvas[y_start:h, :].astype(np.float32)
    canvas[y_start:h, :] = np.clip(sub * (1.0 - m_slice) + fog_col * m_slice, 0, 255).astype(np.uint8)

    img = Image.fromarray(canvas, "RGB")
    path = os.path.join(BG_DIR, "hunters_far_misty_canopy.png")
    img.save(path)
    print("Created:", path)


def make_mid_shattered_forest():
    w, h = 1920, 1080
    canvas = np.zeros((h, w, 3), dtype=np.uint8)

    # Base gradient
    y_indices = np.arange(h)[:, None]
    t = y_indices / float(h)
    canvas[:, :, 0] = (18 + 10 * t).astype(np.uint8)
    canvas[:, :, 1] = (26 + 18 * t).astype(np.uint8)
    canvas[:, :, 2] = (22 + 12 * t).astype(np.uint8)

    # Massive mid trunks (some broken)
    trunks = [
        (120, 95, False), (280, 80, True), (460, 110, False), (680, 85, False),
        (880, 130, True), (1060, 90, False), (1240, 100, False), (1420, 120, True),
        (1600, 85, False), (1780, 105, False)
    ]
    wood_pale = np.array([130, 110, 80], dtype=np.uint8)

    for tx, tw, is_broken in trunks:
        trunk_top = int(h * 0.48) if is_broken else 0
        x_min, x_max = max(0, tx - tw // 2), min(w, tx + tw // 2)
        span = x_max - x_min
        if span <= 0:
            continue
        rel_x = np.abs(np.arange(span) - span / 2.0) / (span / 2.0)
        shade = (1.0 - rel_x * 0.45)[:, None] # (span, 1)

        # Trunk block
        block = np.zeros((h - trunk_top, span, 3), dtype=np.uint8)
        block[:, :, 0] = np.clip(22 * shade.T, 0, 255)
        block[:, :, 1] = np.clip(34 * shade.T, 0, 255)
        block[:, :, 2] = np.clip(26 * shade.T, 0, 255)
        canvas[trunk_top:h, x_min:x_max] = block

        if is_broken:
            # Splintered ragged crown
            np.random.seed(tx)
            splinters = np.random.randint(18, 55, size=span)
            for i, x in enumerate(range(x_min, x_max)):
                sy = max(0, trunk_top - splinters[i])
                canvas[sy:trunk_top, x] = wood_pale + np.random.randint(-10, 10, size=3, dtype=np.int8)

    # Vectorized fern/canopy crowns
    n_crown = noise2d(w, h, scale=25, seed=555)
    mask = (n_crown > 0.58) & (y_indices > int(h * 0.1)) & (y_indices < int(h * 0.75))
    green_vals = (35 + (n_crown - 0.58) * 120).astype(np.uint8)
    canvas[mask, 0] = (green_vals[mask] * 0.55).astype(np.uint8)
    canvas[mask, 1] = green_vals[mask]
    canvas[mask, 2] = (green_vals[mask] * 0.6).astype(np.uint8)

    # Vectorized lower haze
    haze = noise2d(w, h, scale=50, seed=888)
    y_hz = int(h * 0.65)
    y_prog = ((np.arange(y_hz, h) - y_hz) / float(h - y_hz))[:, None]
    hz_slice = np.repeat((haze[y_hz:h, :] * 0.4 * y_prog)[:, :, None], 3, axis=2)
    hz_col = np.array([24.0, 38.0, 30.0])

    sub = canvas[y_hz:h, :].astype(np.float32)
    canvas[y_hz:h, :] = np.clip(sub * (1.0 - hz_slice) + hz_col * hz_slice, 0, 255).astype(np.uint8)

    img = Image.fromarray(canvas, "RGB")
    path = os.path.join(BG_DIR, "hunters_mid_shattered_forest.png")
    img.save(path)
    print("Created:", path)


def make_near_dense_thicket():
    w, h = 1920, 1080
    canvas = np.zeros((h, w, 3), dtype=np.uint8)

    y_indices = np.arange(h)[:, None]
    t = y_indices / float(h)
    canvas[:, :, 0] = (12 + 10 * t).astype(np.uint8)
    canvas[:, :, 1] = (18 + 14 * t).astype(np.uint8)
    canvas[:, :, 2] = (14 + 10 * t).astype(np.uint8)

    near_trunks = [
        (80, 140), (380, 160), (740, 150), (1120, 170), (1480, 150), (1840, 160)
    ]
    for tx, tw in near_trunks:
        for y in range(h):
            flare = int(max(0, (y - h * 0.6) * 0.4))
            curr_w = tw + flare * 2
            x_min = max(0, tx - curr_w // 2)
            x_max = min(w, tx + curr_w // 2)
            span = x_max - x_min
            if span <= 0:
                continue
            rel_x = np.abs(np.arange(span) - span / 2.0) / (span / 2.0)
            shade = 1.0 - rel_x * 0.45
            canvas[y, x_min:x_max, 0] = np.clip(22 * shade, 0, 255)
            canvas[y, x_min:x_max, 1] = np.clip(34 * shade, 0, 255)
            canvas[y, x_min:x_max, 2] = np.clip(22 * shade, 0, 255)

    # Undergrowth fronds
    n_ferns = noise2d(w, h, scale=18, seed=404)
    y_fern = int(h * 0.5)
    f_mask = (n_ferns > 0.52) & (y_indices >= y_fern)
    y_p = ((np.arange(h) - y_fern) / float(h - y_fern))[:, None]
    green = np.clip(38 + (n_ferns - 0.52) * 110 * y_p, 0, 255).astype(np.uint8)
    canvas[f_mask, 0] = (green[f_mask] * 0.65).astype(np.uint8)
    canvas[f_mask, 1] = green[f_mask]
    canvas[f_mask, 2] = (green[f_mask] * 0.5).astype(np.uint8)

    img = Image.fromarray(canvas, "RGB")
    path = os.path.join(BG_DIR, "hunters_near_dense_thicket.png")
    img.save(path)
    print("Created:", path)


def make_fg_vines_foliage():
    w, h = 1920, 1080
    canvas = np.zeros((h, w, 4), dtype=np.uint8)
    draw_img = Image.fromarray(canvas, "RGBA")
    draw = ImageDraw.Draw(draw_img)

    # Corner silhouette arches
    draw.polygon([(0, 0), (680, 0), (450, 280), (120, 360), (0, 480)], fill=(12, 18, 14, 250))
    draw.polygon([(w, 0), (w - 680, 0), (w - 450, 280), (w - 120, 360), (w, 480)], fill=(12, 18, 14, 250))

    # Hanging prehistoric vines
    np.random.seed(505)
    for vx in [50, 130, 220, 340, 480, 580, 1340, 1450, 1580, 1700, 1820]:
        length = np.random.randint(380, 680)
        thick = np.random.randint(4, 7)
        points = []
        for y in range(0, length, 15):
            ox = int(math.sin(y * 0.012) * 16)
            points.append((vx + ox, y))
        draw.line(points, fill=(10, 16, 12, 245), width=thick)

    path = os.path.join(BG_DIR, "hunters_fg_vines_foliage.png")
    draw_img.save(path)
    print("Created:", path)


def make_hunters_mud_ground():
    w, h = 512, 256
    canvas = np.zeros((h, w, 4), dtype=np.uint8)
    y_indices = np.arange(h)[:, None]
    t = y_indices / float(h)
    canvas[:, :, 0] = (52 * (1 - t * 0.6)).astype(np.uint8)
    canvas[:, :, 1] = (40 * (1 - t * 0.65)).astype(np.uint8)
    canvas[:, :, 2] = (30 * (1 - t * 0.7)).astype(np.uint8)
    canvas[:, :, 3] = 255

    # Texture noise
    sn = (noise2d(w, h, scale=12, seed=707) - 0.5) * 24
    canvas[:, :, 0] = np.clip(canvas[:, :, 0].astype(float) + sn * 1.1, 10, 245).astype(np.uint8)
    canvas[:, :, 1] = np.clip(canvas[:, :, 1].astype(float) + sn * 0.9, 8, 240).astype(np.uint8)
    canvas[:, :, 2] = np.clip(canvas[:, :, 2].astype(float) + sn * 0.7, 6, 235).astype(np.uint8)

    # Top moss & churned loam
    for x in range(w):
        moss_mask = math.sin(x * 0.08) * 0.5 + math.cos(x * 0.22) * 0.5
        if moss_mask > 0.1:
            depth = int(4 + moss_mask * 8)
            for dy in range(depth):
                canvas[dy, x] = [36 + dy * 2, 58 + dy * 3, 34 + dy * 2, 255]
        else:
            canvas[0, x] = [68, 52, 40, 255]
            canvas[1, x] = [54, 42, 32, 255]

    # Embedded pebbles
    np.random.seed(606)
    for _ in range(60):
        px = np.random.randint(4, w - 8)
        py = np.random.randint(12, 140)
        pw = np.random.randint(3, 7)
        ph = np.random.randint(2, 5)
        canvas[py:py+ph, px:px+pw] = [75, 78, 84, 255]
        canvas[py+ph, px:px+pw] = [24, 20, 18, 255]

    canvas[:, -1] = canvas[:, 0]
    canvas[:, -2] = canvas[:, 1]

    img = Image.fromarray(canvas, "RGBA")
    path = os.path.join(TILE_DIR, "hunters_mud_ground.png")
    img.save(path)
    print("Created:", path)


def make_hunters_crushed_log_ledge():
    w, h = 240, 70
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    # Main log body
    draw.polygon([(15, 60), (225, 60), (235, 12), (5, 12)], fill=(44, 34, 24, 255))
    draw.line([(5, 12), (235, 12)], fill=(62, 52, 38, 255), width=2)
    # Moss top
    draw.ellipse([20, 8, 220, 16], fill=(42, 68, 38, 255))
    # Jagged splintered ends
    draw.polygon([(5, 12), (18, 28), (8, 42), (15, 60), (0, 36)], fill=(170, 148, 110, 255))
    draw.polygon([(235, 12), (222, 28), (232, 42), (225, 60), (240, 36)], fill=(170, 148, 110, 255))

    path = os.path.join(TILE_DIR, "hunters_crushed_log_ledge.png")
    draw_img.save(path)
    print("Created:", path)


def make_hunters_moss_rock_ledge():
    w, h = 240, 70
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    draw.polygon([(8, 10), (232, 10), (220, 48), (170, 62), (80, 58), (20, 45)], fill=(46, 50, 56, 255))
    # Top moss coating
    draw.ellipse([8, 6, 232, 14], fill=(38, 64, 40, 255))
    draw.line([(8, 10), (232, 10)], fill=(58, 76, 54, 255), width=2)
    # Underhang shadows & facets
    draw.polygon([(20, 45), (80, 58), (55, 30)], fill=(32, 36, 40, 255))
    draw.polygon([(170, 62), (220, 48), (195, 30)], fill=(32, 36, 40, 255))

    path = os.path.join(TILE_DIR, "hunters_moss_rock_ledge.png")
    draw_img.save(path)
    print("Created:", path)


def make_apex_footprint_deep():
    w, h = 160, 130
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    rim_color = (68, 52, 38, 220)
    pit_color = (20, 14, 10, 255)
    claw_color = (10, 8, 6, 255)
    water_color = (28, 34, 28, 210)

    # 1. Raised displacement rim
    draw.ellipse([54, 76, 106, 118], fill=rim_color)
    draw.polygon([(80, 90), (28, 34), (48, 24), (86, 75)], fill=rim_color)
    draw.polygon([(68, 85), (70, 16), (90, 16), (92, 85)], fill=rim_color)
    draw.polygon([(80, 90), (132, 34), (112, 24), (74, 75)], fill=rim_color)

    # 2. Deep indentation
    draw.ellipse([60, 82, 100, 112], fill=pit_color)
    draw.polygon([(78, 88), (34, 40), (46, 32), (82, 76)], fill=pit_color)
    draw.polygon([(72, 82), (75, 24), (85, 24), (88, 82)], fill=pit_color)
    draw.polygon([(82, 88), (126, 40), (114, 32), (78, 76)], fill=pit_color)

    # 3. Lethal claw gouges
    draw.polygon([(77, 24), (80, 8), (83, 24)], fill=claw_color)
    draw.polygon([(36, 38), (22, 22), (44, 30)], fill=claw_color)
    draw.polygon([(124, 38), (138, 22), (116, 30)], fill=claw_color)

    # 4. Muddy pool in hollow
    draw.ellipse([68, 88, 92, 106], fill=water_color)

    path = os.path.join(PROP_DIR, "apex_footprint_deep.png")
    draw_img.save(path)
    print("Created:", path)


def make_apex_footprint_shallow():
    w, h = 140, 110
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    rim_color = (58, 48, 38, 180)
    pit_color = (24, 18, 14, 230)
    claw_color = (12, 10, 8, 255)

    draw.ellipse([50, 68, 90, 98], fill=rim_color)
    draw.ellipse([54, 72, 86, 94], fill=pit_color)

    draw.polygon([(70, 78), (30, 36), (42, 30), (74, 68)], fill=rim_color)
    draw.polygon([(68, 76), (34, 40), (40, 34), (72, 68)], fill=pit_color)
    draw.polygon([(34, 38), (24, 24), (40, 32)], fill=claw_color)

    draw.polygon([(64, 72), (66, 22), (74, 22), (76, 72)], fill=rim_color)
    draw.polygon([(66, 70), (68, 26), (72, 26), (74, 70)], fill=pit_color)
    draw.polygon([(67, 24), (70, 10), (73, 24)], fill=claw_color)

    draw.polygon([(70, 78), (110, 36), (98, 30), (66, 68)], fill=rim_color)
    draw.polygon([(72, 76), (106, 40), (100, 34), (68, 68)], fill=pit_color)
    draw.polygon([(106, 38), (116, 24), (100, 32)], fill=claw_color)

    path = os.path.join(PROP_DIR, "apex_footprint_shallow.png")
    draw_img.save(path)
    print("Created:", path)


def make_apex_drag_mark():
    w, h = 220, 80
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    draw.ellipse([10, 15, 210, 65], fill=(52, 40, 30, 170))
    draw.ellipse([20, 25, 200, 55], fill=(22, 16, 12, 240))
    for y_line in [32, 40, 48]:
        draw.line([(25, y_line), (195, y_line + 4)], fill=(14, 10, 8, 255), width=2)

    path = os.path.join(PROP_DIR, "apex_drag_mark.png")
    draw_img.save(path)
    print("Created:", path)


def make_shattered_trunk_snapped():
    w, h = 180, 160
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    # Main trunk stump
    draw.polygon([(40, 160), (140, 160), (132, 70), (48, 70)], fill=(32, 42, 28, 255))

    # Splinter spires (pale exposed core wood)
    wood_pale = (186, 161, 123, 255)
    wood_dark = (90, 72, 48, 255)

    splinters = [
        (52, 70, 56, 35), (58, 70, 64, 18), (66, 70, 72, 12),
        (74, 70, 80, 22), (82, 70, 92, 15), (94, 70, 102, 30),
        (104, 70, 114, 25), (116, 70, 124, 45)
    ]
    for sx1, sy1, sx2, top_y in splinters:
        draw.polygon([(sx1, sy1), (sx2, sy1), ((sx1 + sx2) // 2, top_y)], fill=wood_pale)
        draw.line([((sx1 + sx2) // 2, top_y), (sx2, sy1)], fill=wood_dark, width=1)

    path = os.path.join(PROP_DIR, "shattered_trunk_snapped.png")
    draw_img.save(path)
    print("Created:", path)


def make_trampled_cycad_ferns():
    w, h = 160, 90
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    frond_dark = (26, 44, 24, 230)
    frond_mid = (42, 74, 38, 255)
    frond_light = (64, 104, 52, 255)
    stem_color = (78, 64, 42, 255)

    draw.line([(20, 75), (140, 82)], fill=stem_color, width=4)
    draw.line([(30, 68), (145, 74)], fill=stem_color, width=3)

    for fx in range(25, 145, 12):
        draw.polygon([(fx, 78), (fx + 18, 62), (fx + 24, 78)], fill=frond_mid)
        draw.polygon([(fx + 2, 79), (fx + 16, 68), (fx + 20, 80)], fill=frond_light)
        draw.polygon([(fx - 4, 82), (fx + 10, 86), (fx + 18, 84)], fill=frond_dark)

    path = os.path.join(PROP_DIR, "trampled_cycad_ferns.png")
    draw_img.save(path)
    print("Created:", path)


def make_shattered_boulder_rubble():
    w, h = 150, 95
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    draw.polygon([(15, 88), (68, 88), (72, 32), (32, 22), (12, 54)], fill=(48, 52, 58, 255))
    draw.polygon([(82, 88), (135, 88), (140, 58), (122, 28), (80, 36)], fill=(44, 48, 54, 255))
    draw.polygon([(68, 88), (82, 88), (80, 36), (72, 32)], fill=(16, 18, 20, 255))
    draw.polygon([(32, 22), (52, 38), (72, 32)], fill=(66, 72, 80, 255))
    draw.polygon([(80, 36), (105, 42), (122, 28)], fill=(62, 68, 76, 255))
    draw.polygon([(26, 24), (45, 22), (38, 28)], fill=(44, 68, 42, 255))
    draw.polygon([(110, 28), (126, 30), (118, 36)], fill=(44, 68, 42, 255))

    path = os.path.join(PROP_DIR, "shattered_boulder_rubble.png")
    draw_img.save(path)
    print("Created:", path)


def make_prehistoric_ribcage_remnant():
    w, h = 190, 90
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    bone_col = (195, 185, 165, 240)
    bone_shadow = (120, 110, 95, 255)
    ribs = [
        (35, 82, 42, 25, 25), (65, 82, 74, 15, 55),
        (95, 82, 108, 12, 85), (125, 82, 140, 18, 115),
        (155, 82, 168, 30, 145)
    ]
    for bx, by, tx, ty, curve_x in ribs:
        draw.line([(bx, by), (curve_x, (by + ty) // 2), (tx, ty)], fill=bone_col, width=7)
        draw.line([(bx + 2, by), (curve_x + 2, (by + ty) // 2), (tx + 1, ty)], fill=bone_shadow, width=3)

    draw.ellipse([15, 68, 175, 92], fill=(42, 34, 26, 255))
    draw.ellipse([20, 72, 170, 88], fill=(36, 52, 32, 255))

    path = os.path.join(PROP_DIR, "prehistoric_ribcage_remnant.png")
    draw_img.save(path)
    print("Created:", path)


def make_apex_distant_shadow():
    w, h = 320, 240
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    # Indistinct atmospheric predator mass
    shadow_col = (18, 28, 24, 160)
    shadow_core = (12, 20, 16, 210)
    draw.ellipse([60, 40, 260, 180], fill=shadow_col)
    draw.ellipse([90, 60, 230, 160], fill=shadow_core)
    draw.polygon([(80, 120), (10, 160), (120, 150)], fill=(18, 28, 24, 110))
    draw.ellipse([180, 20, 280, 110], fill=shadow_col)

    # Foreground tree silhouettes obscuring details
    trunk_col = (14, 22, 18, 245)
    draw.rectangle([40, 0, 75, 240], fill=trunk_col)
    draw.rectangle([130, 0, 175, 240], fill=trunk_col)
    draw.rectangle([235, 0, 275, 240], fill=trunk_col)
    draw.ellipse([10, -20, 310, 70], fill=(16, 26, 20, 230))

    path = os.path.join(PROP_DIR, "apex_distant_shadow.png")
    draw_img.save(path)
    print("Created:", path)


def make_unstable_deadfall_trunk():
    w, h = 200, 80
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    draw.polygon([(10, 50), (190, 30), (185, 60), (15, 75)], fill=(44, 34, 26, 255))
    draw.polygon([(12, 48), (188, 28), (180, 38), (18, 56)], fill=(62, 50, 38, 255))
    draw.ellipse([60, 34, 130, 52], fill=(42, 66, 38, 240))
    draw.line([(95, 34), (105, 58)], fill=(18, 14, 10, 255), width=2)

    path = os.path.join(PROP_DIR, "unstable_deadfall_trunk.png")
    draw_img.save(path)
    print("Created:", path)


def make_hunters_falling_leaves():
    w, h = 32, 32
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    draw.polygon([(16, 2), (24, 14), (20, 26), (16, 30), (12, 26), (8, 14)], fill=(48, 86, 42, 230))
    draw.line([(16, 4), (16, 28)], fill=(74, 118, 62, 255), width=1)

    path = os.path.join(FX_DIR, "hunters_falling_leaves.png")
    draw_img.save(path)
    print("Created:", path)


if __name__ == "__main__":
    print("=== Generating Stone Age Level 04 Assets ===")
    make_far_misty_canopy()
    make_mid_shattered_forest()
    make_near_dense_thicket()
    make_fg_vines_foliage()
    make_hunters_mud_ground()
    make_hunters_crushed_log_ledge()
    make_hunters_moss_rock_ledge()
    make_apex_footprint_deep()
    make_apex_footprint_shallow()
    make_apex_drag_mark()
    make_shattered_trunk_snapped()
    make_trampled_cycad_ferns()
    make_shattered_boulder_rubble()
    make_prehistoric_ribcage_remnant()
    make_apex_distant_shadow()
    make_unstable_deadfall_trunk()
    make_hunters_falling_leaves()
    print("=== All Stone Age Level 04 Assets Generated Successfully! ===")
