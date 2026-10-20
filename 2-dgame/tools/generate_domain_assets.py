"""
generate_domain_assets.py
Generates authentic pixel-art environment, background, bone, tree, nest, and mechanical
props for Stone Age Chapter - Level 06: Dev Yaratığın Bölgesi (The Beast's Domain).
"""

import os
import math
import numpy as np
from PIL import Image, ImageDraw

BG_DIR = "assets/backgrounds/stoneage"
TILE_DIR = "assets/tilesets/stoneage"
PROP_DIR = "assets/props/stoneage"
MECH_DIR = "assets/mechanical/stoneage"
FX_DIR = "assets/effects/stoneage"

for d in [BG_DIR, TILE_DIR, PROP_DIR, MECH_DIR, FX_DIR]:
    os.makedirs(d, exist_ok=True)


def noise2d(w, h, scale=10.0, seed=42):
    np.random.seed(seed)
    nw, nh = max(2, int(w / scale)), max(2, int(h / scale))
    grid = np.random.rand(nh, nw).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8)).resize((w, h), Image.Resampling.BILINEAR)
    return np.array(img).astype(np.float32) / 255.0


# -------------------------------------------------------------
# 1. BACKGROUND LAYERS
# -------------------------------------------------------------
def make_far_colossal_peaks():
    w, h = 1920, 1080
    canvas = np.zeros((h, w, 3), dtype=np.uint8)

    # Brooding, oppressive overcast prehistoric twilight sky
    y_indices = np.arange(h)[:, None]
    t = y_indices / float(h)
    r = (18 * (1 - t) + 32 * t).astype(np.uint8)
    g = (22 * (1 - t) + 38 * t).astype(np.uint8)
    b = (26 * (1 - t) + 44 * t).astype(np.uint8)
    canvas[:, :, 0] = r
    canvas[:, :, 1] = g
    canvas[:, :, 2] = b

    # Far mountain peaks & colossal storm-shrouded monolithic ridges
    n1 = noise2d(w, 200, scale=60, seed=601)
    n2 = noise2d(w, 300, scale=40, seed=602)

    base1 = int(h * 0.40)
    base2 = int(h * 0.54)

    # Furthest jagged mountain chain (z=-50)
    for x in range(w):
        y1 = max(0, min(h - 1, base1 - int(n1[100, x] * 160 + math.sin(x * 0.003) * 90)))
        canvas[y1:h, x, 0] = (canvas[y1:h, x, 0].astype(np.float32) * 0.35 + 16 * 0.65).astype(np.uint8)
        canvas[y1:h, x, 1] = (canvas[y1:h, x, 1].astype(np.float32) * 0.35 + 24 * 0.65).astype(np.uint8)
        canvas[y1:h, x, 2] = (canvas[y1:h, x, 2].astype(np.float32) * 0.35 + 30 * 0.65).astype(np.uint8)

    # Mid-far massive crater wall & volcanic ridge
    for x in range(w):
        y2 = max(0, min(h - 1, base2 - int(n2[150, x] * 140 + math.cos(x * 0.004) * 80)))
        canvas[y2:h, x] = [12, 17, 20]

    # Distant towering tree silhouettes on high ridge
    for tx in range(0, w, 24):
        th = int(35 + n1[100, tx] * 45)
        ty = base2 - int(n2[150, min(w - 1, tx)] * 140 + math.cos(tx * 0.004) * 80)
        for dy in range(th):
            curr_y = ty - dy
            if 0 <= curr_y < h:
                wl = int(max(2, (th - dy) * 0.22))
                x_start = max(0, tx - wl)
                x_end = min(w, tx + wl + 1)
                canvas[curr_y, x_start:x_end] = [9, 13, 15]

    # Ground fog bank rolling in the valley floor
    fog_y = int(h * 0.68)
    for y in range(fog_y, h):
        factor = (y - fog_y) / float(h - fog_y) * 0.25
        canvas[y, :, 0] = np.clip(canvas[y, :, 0].astype(np.float32) + factor * 25, 0, 255).astype(np.uint8)
        canvas[y, :, 1] = np.clip(canvas[y, :, 1].astype(np.float32) + factor * 32, 0, 255).astype(np.uint8)
        canvas[y, :, 2] = np.clip(canvas[y, :, 2].astype(np.float32) + factor * 38, 0, 255).astype(np.uint8)

    img = Image.fromarray(canvas)
    img.save(os.path.join(BG_DIR, "domain_far_colossal_peaks.png"))
    print("Saved domain_far_colossal_peaks.png")


def make_mid_titanic_canopy():
    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Huge prehistoric tree trunks and dense midground canopy with broken splintered crowns
    n_mid = noise2d(w, 200, scale=30, seed=603)
    base_ground = int(h * 0.65)

    # Distant ground line
    ground_pts = [(0, h)]
    for x in range(0, w + 1, 16):
        gy = base_ground + int(n_mid[100, min(w - 1, x)] * 50 + math.sin(x * 0.005) * 30)
        ground_pts.append((x, gy))
    ground_pts.append((w, h))
    draw.polygon(ground_pts, fill=(15, 22, 20, 230))

    # Giant trunk pillars (40 to 90 px wide)
    trunk_x = [60, 220, 410, 630, 850, 1080, 1290, 1520, 1750]
    for tx in trunk_x:
        tw = int(50 + n_mid[50, tx] * 40)
        is_snapped = (tx in [410, 1080, 1520])
        th = int(h * 0.45) if is_snapped else int(h * 0.85)
        top_y = base_ground - th

        # Trunk base to top
        draw.rectangle([tx - tw // 2, max(0, top_y), tx + tw // 2, h], fill=(13, 19, 17, 240))
        # Bark textures & shading
        draw.rectangle([tx - tw // 2, max(0, top_y), tx - tw // 4, h], fill=(10, 15, 13, 245))
        draw.rectangle([tx + tw // 4, max(0, top_y), tx + tw // 2, h], fill=(18, 26, 22, 240))

        if is_snapped:
            # Splintered violent jagged break point
            for sp_i in range(-tw // 2, tw // 2, 4):
                sp_len = int(15 + abs(math.sin(sp_i * 0.4)) * 35)
                draw.line([(tx + sp_i, top_y), (tx + sp_i, top_y - sp_len)], fill=(22, 32, 25, 250), width=3)
        else:
            # High canopy cluster
            draw.ellipse([tx - tw * 1.5, top_y - 60, tx + tw * 1.5, top_y + 80], fill=(16, 25, 20, 210))

    # Dense mid foliage bushes & hanging vines
    for x in range(0, w, 40):
        by = base_ground + int(n_mid[120, x] * 35)
        bw = int(70 + n_mid[100, x] * 50)
        bh = int(45 + n_mid[80, x] * 35)
        draw.ellipse([x - bw // 2, by - bh, x + bw // 2, by + 10], fill=(18, 28, 22, 225))

    img.save(os.path.join(BG_DIR, "domain_mid_titanic_canopy.png"))
    print("Saved domain_mid_titanic_canopy.png")


def make_near_bone_crags():
    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Near rocky pillars, colossal fossilized bones protruding from cliffs, ancient roots
    n_near = noise2d(w, 200, scale=20, seed=604)

    # Giant fossil bone monoliths protruding into the sky
    # Monolith 1 at x=340
    draw.polygon([(300, h), (320, 380), (370, 360), (410, 420), (430, h)], fill=(26, 32, 30, 250))
    # Fossil rib silhouette arching out of rock
    draw.arc([350, 420, 580, 720], start=180, end=320, fill=(45, 48, 42, 240), width=18)

    # Monolith 2 at x=980
    draw.polygon([(920, h), (950, 320), (1010, 300), (1060, 350), (1090, h)], fill=(24, 30, 28, 250))
    # Snapped mechanical cable or support beam embedded into monolith 2
    draw.line([(960, 320), (990, 280), (1030, 290)], fill=(38, 48, 56, 255), width=8)

    # Monolith 3 at x=1620 (Towering claw-scarred cliff face)
    draw.polygon([(1550, h), (1580, 260), (1660, 250), (1740, 310), (1780, h)], fill=(22, 28, 27, 250))
    # 3 massive claw scars gouged down cliff 3
    for c_off in [-16, 0, 16]:
        draw.line([(1640 + c_off, 340), (1630 + c_off, 480)], fill=(12, 16, 15, 240), width=4)

    # Low rocky ridge profile
    base_y = int(h * 0.72)
    pts = [(0, h)]
    for x in range(0, w + 1, 16):
        gy = base_y + int(n_near[100, min(w - 1, x)] * 60 + math.cos(x * 0.006) * 40)
        pts.append((x, gy))
    pts.append((w, h))
    draw.polygon(pts, fill=(20, 26, 23, 255))

    img.save(os.path.join(BG_DIR, "domain_near_bone_crags.png"))
    print("Saved domain_near_bone_crags.png")


def make_fg_framing_roots():
    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Top framing: massive dark twisted ironwood roots creeping down
    # Left overhang
    draw.polygon([(0, 0), (450, 0), (380, 120), (280, 160), (120, 130), (0, 180)], fill=(8, 12, 10, 255))
    # Hanging tendril roots
    root_xs = [80, 160, 240, 320, 370]
    for rx in root_xs:
        draw.line([(rx, 110), (rx + 15, 210), (rx - 5, 290)], fill=(11, 16, 13, 255), width=6)

    # Right overhang
    draw.polygon([(w - 480, 0), (w, 0), (w, 200), (w - 150, 170), (w - 320, 130), (w - 450, 90)], fill=(8, 12, 10, 255))
    root_r_xs = [w - 360, w - 280, w - 190, w - 90]
    for rx in root_r_xs:
        draw.line([(rx, 100), (rx - 12, 220), (rx + 8, 310)], fill=(11, 16, 13, 255), width=6)

    # Bottom edge framing: dark jagged corner crags
    draw.polygon([(0, h - 160), (140, h - 110), (190, h), (0, h)], fill=(9, 13, 11, 255))
    draw.polygon([(w - 220, h), (w - 170, h - 130), (w, h - 180), (w, h)], fill=(9, 13, 11, 255))

    img.save(os.path.join(BG_DIR, "domain_fg_framing_roots.png"))
    print("Saved domain_fg_framing_roots.png")


# -------------------------------------------------------------
# 2. TILESET & TERRAIN TEXTURES
# -------------------------------------------------------------
def make_trampled_soil_ground():
    w, h = 512, 256
    arr = np.zeros((h, w, 4), dtype=np.uint8)

    # Heavy dark primordial loam/peat ground with petrified roots & crushed bone specks
    # Top 32px is surface grass/trampled fern/crushed stone crust
    n = noise2d(w, h, scale=12.0, seed=605)
    n_detail = noise2d(w, h, scale=4.0, seed=606)

    for y in range(h):
        for x in range(w):
            val = n[y, x] * 0.7 + n_detail[y, x] * 0.3
            if y < 14:
                # Top moss/mud crust with dark olive/decayed organic highlights
                r = int(32 + val * 22)
                g = int(45 + val * 30)
                b = int(28 + val * 18)
            elif y < 36:
                # Mud transition with trampled churned loam
                r = int(26 + val * 20)
                g = int(24 + val * 18)
                b = int(20 + val * 14)
            else:
                # Deep compact stone and rich black soil
                depth_f = (y - 36) / float(h - 36)
                r = int((20 + val * 16) * (1.0 - depth_f * 0.4))
                g = int((19 + val * 14) * (1.0 - depth_f * 0.4))
                b = int((18 + val * 12) * (1.0 - depth_f * 0.3))

            arr[y, x] = [r, g, b, 255]

    # Add embedded white bone fragments / fossil specks into the soil
    np.random.seed(607)
    for _ in range(85):
        bx = np.random.randint(4, w - 4)
        by = np.random.randint(18, h - 8)
        bsz = np.random.randint(2, 5)
        bone_color = [165, 155, 135, 255]
        arr[by:by+bsz, bx:bx+bsz] = bone_color

    img = Image.fromarray(arr)
    img.save(os.path.join(TILE_DIR, "domain_trampled_soil_ground.png"))
    print("Saved domain_trampled_soil_ground.png")


def make_fossil_ledge():
    w, h = 256, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Petrified stone ledge embedded with large fossilized bone ribs and teeth
    draw.polygon([(8, 14), (w - 8, 14), (w - 2, 28), (w - 12, 52), (14, 56), (2, 32)], fill=(34, 38, 36, 255))
    # Top walking surface (dark slate stone)
    draw.rectangle([6, 14, w - 6, 22], fill=(52, 58, 54, 255))
    draw.line([(8, 14), (w - 8, 14)], fill=(75, 84, 78, 255), width=2)

    # Fossil bone strata embedded in face
    # Long curved bone plate
    draw.arc([40, 22, 180, 52], start=190, end=350, fill=(155, 148, 130, 255), width=5)
    # Bone nodules
    for bx in [28, 95, 140, 195, 225]:
        draw.ellipse([bx, 28, bx + 12, 38], fill=(168, 160, 142, 255))
        draw.ellipse([bx + 2, 30, bx + 10, 36], fill=(132, 125, 110, 255))

    img.save(os.path.join(TILE_DIR, "domain_fossil_ledge.png"))
    print("Saved domain_fossil_ledge.png")


def make_titan_root_platform():
    w, h = 256, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Massive gnarled ancient prehistoric root serving as natural platform
    draw.polygon([(4, 18), (w - 4, 18), (w - 10, 38), (w - 20, 56), (20, 52), (10, 36)], fill=(32, 24, 18, 255))
    # Top root bark & moss edge
    draw.rectangle([6, 18, w - 6, 24], fill=(48, 42, 28, 255))
    draw.line([(8, 18), (w - 8, 18)], fill=(62, 70, 38, 255), width=2) # Moss highlight

    # Twisted root striations
    for stri in range(24, 50, 6):
        draw.line([(12, stri), (w - 14, stri + 3)], fill=(22, 16, 12, 255), width=2)

    # Embedded claw gouge mark on platform
    draw.line([(90, 18), (115, 34)], fill=(12, 8, 6, 255), width=3)
    draw.line([(100, 18), (125, 34)], fill=(12, 8, 6, 255), width=3)
    draw.line([(110, 18), (135, 34)], fill=(12, 8, 6, 255), width=3)

    img.save(os.path.join(TILE_DIR, "domain_titan_root_platform.png"))
    print("Saved domain_titan_root_platform.png")


# -------------------------------------------------------------
# 3. PROPS: ENVIRONMENT & SHATTERED TREES
# -------------------------------------------------------------
def make_snapped_giant_tree():
    w, h = 160, 220
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Massive prehistoric trunk (100px wide) violently sheared in half by colossal force
    tx, ty = 80, 210
    tw = 90
    trunk_top = 70

    # Trunk body
    draw.polygon([(tx - tw // 2, ty), (tx - tw // 2 + 5, trunk_top),
                  (tx + tw // 2 - 5, trunk_top), (tx + tw // 2, ty)], fill=(38, 28, 22, 255))
    # Left shadow & right highlight
    draw.polygon([(tx - tw // 2, ty), (tx - tw // 2 + 5, trunk_top),
                  (tx - tw // 4, trunk_top), (tx - tw // 4, ty)], fill=(26, 18, 14, 255))
    draw.polygon([(tx + tw // 4, ty), (tx + tw // 4, trunk_top),
                  (tx + tw // 2 - 5, trunk_top), (tx + tw // 2, ty)], fill=(52, 38, 28, 255))

    # Shattered jagged wooden spears pointing upward where it was snapped
    splinters = [
        (-40, 25), (-32, 55), (-24, 30), (-16, 68), (-8, 42),
        (0, 75), (8, 45), (18, 62), (28, 35), (38, 50)
    ]
    for sp_x, sp_len in splinters:
        draw.polygon([(tx + sp_x - 3, trunk_top), (tx + sp_x, trunk_top - sp_len),
                      (tx + sp_x + 3, trunk_top)], fill=(85, 65, 45, 255))
        draw.line([(tx + sp_x, trunk_top), (tx + sp_x, trunk_top - sp_len)], fill=(115, 90, 62, 255), width=1)

    # Moss and hanging bark strips
    draw.line([(tx - 38, 120), (tx - 44, 180)], fill=(45, 58, 35, 255), width=4)
    draw.line([(tx + 35, 100), (tx + 40, 160)], fill=(45, 58, 35, 255), width=3)

    img.save(os.path.join(PROP_DIR, "domain_snapped_giant_tree.png"))
    print("Saved domain_snapped_giant_tree.png")


def make_fallen_colossus_trunk():
    w, h = 280, 90
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Massive fallen tree trunk resting half-buried in mud and ferns
    draw.polygon([(10, 50), (40, 25), (w - 30, 25), (w - 10, 55), (w - 20, 75), (25, 78)], fill=(34, 25, 19, 255))
    # Top highlight
    draw.polygon([(40, 25), (w - 30, 25), (w - 35, 38), (35, 38)], fill=(54, 42, 30, 255))
    # Moss layer on top
    draw.line([(45, 25), (w - 35, 25)], fill=(65, 78, 42, 255), width=4)

    # Snapped end with rings visible (left side)
    draw.ellipse([15, 28, 45, 72], fill=(62, 48, 32, 255))
    draw.ellipse([20, 35, 40, 65], fill=(48, 36, 24, 255))
    draw.ellipse([26, 42, 34, 58], fill=(35, 25, 18, 255))

    # Deep impact crack running along the middle
    draw.line([(60, 48), (140, 44), (190, 52), (250, 46)], fill=(14, 10, 8, 255), width=3)

    img.save(os.path.join(PROP_DIR, "domain_fallen_colossus_trunk.png"))
    print("Saved domain_fallen_colossus_trunk.png")


# -------------------------------------------------------------
# 4. PROPS: COLOSSAL BONES & FOSSILS
# -------------------------------------------------------------
def make_giant_ribcage_cluster():
    w, h = 220, 140
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 4 colossal fossilized prehistoric rib bones protruding out of earth like gothic arches
    ribs = [
        (40, 130, 75, 115),
        (85, 132, 85, 125),
        (135, 130, 80, 120),
        (180, 135, 70, 105),
    ]

    for rx, ry, rw, rh in ribs:
        # Bone arch
        draw.arc([rx - rw // 2, ry - rh, rx + rw // 2, ry + 20], start=170, end=340, fill=(175, 168, 150, 255), width=12)
        # Shadow inner arc
        draw.arc([rx - rw // 2, ry - rh, rx + rw // 2, ry + 20], start=170, end=340, fill=(125, 118, 102, 255), width=6)
        # Highlight outer ridge
        draw.arc([rx - rw // 2 - 2, ry - rh - 2, rx + rw // 2 + 2, ry + 18], start=180, end=300, fill=(215, 208, 190, 255), width=3)

    # Soil mounds at base
    draw.ellipse([10, 115, 210, 140], fill=(24, 20, 16, 255))

    img.save(os.path.join(PROP_DIR, "domain_giant_ribcage_cluster.png"))
    print("Saved domain_giant_ribcage_cluster.png")


def make_massive_skull_fossil():
    w, h = 160, 110
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Massive ancient skull half submerged in peat and moss
    draw.polygon([(20, 80), (45, 30), (105, 25), (145, 65), (135, 95), (60, 95)], fill=(160, 152, 135, 255))
    # Deep eye socket (orbital cavity)
    draw.ellipse([65, 42, 95, 72], fill=(18, 16, 14, 255))
    # Nasal cavity
    draw.polygon([(110, 52), (125, 58), (115, 70)], fill=(22, 20, 18, 255))
    # Giant serrated tooth sockets along lower jaw
    for tx in [45, 60, 75, 90, 105, 120]:
        draw.polygon([(tx, 88), (tx + 4, 102), (tx + 8, 88)], fill=(210, 202, 185, 255))

    # Weathering cracks
    draw.line([(55, 35), (75, 52)], fill=(95, 88, 75, 255), width=2)
    draw.line([(100, 30), (108, 48)], fill=(95, 88, 75, 255), width=2)

    img.save(os.path.join(PROP_DIR, "domain_massive_skull_fossil.png"))
    print("Saved domain_massive_skull_fossil.png")


def make_bone_heap():
    w, h = 130, 60
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Jumbled pile of cracked limb bones, scavenged remains
    bones = [
        ((15, 45), (110, 25), 10),
        ((25, 28), (85, 48), 8),
        ((50, 48), (120, 42), 9),
        ((10, 35), (60, 20), 7)
    ]
    for p1, p2, width in bones:
        draw.line([p1, p2], fill=(165, 158, 140, 255), width=width)
        draw.ellipse([p1[0] - width // 2, p1[1] - width // 2, p1[0] + width // 2, p1[1] + width // 2], fill=(185, 178, 160, 255))
        draw.ellipse([p2[0] - width // 2, p2[1] - width // 2, p2[0] + width // 2, p2[1] + width // 2], fill=(185, 178, 160, 255))

    img.save(os.path.join(PROP_DIR, "domain_bone_heap.png"))
    print("Saved domain_bone_heap.png")


# -------------------------------------------------------------
# 5. PROPS: NEST & TERRITORY SIGNS
# -------------------------------------------------------------
def make_gargantuan_footprint():
    w, h = 110, 70
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Colossal 3-toed theropod footprint pressed deep into dark wet mud with puddle
    # Displaced mud rim
    draw.ellipse([8, 12, 102, 62], fill=(32, 25, 19, 255))

    # Heel pad
    draw.ellipse([18, 24, 48, 52], fill=(12, 9, 7, 255))

    # Middle toe (forward)
    draw.polygon([(40, 32), (88, 34), (100, 36), (88, 42), (40, 44)], fill=(10, 8, 6, 255))
    # Left toe
    draw.polygon([(36, 26), (78, 16), (90, 14), (74, 24), (34, 34)], fill=(10, 8, 6, 255))
    # Right toe
    draw.polygon([(36, 50), (74, 58), (88, 62), (76, 50), (34, 42)], fill=(10, 8, 6, 255))

    # Water reflection in deepest part
    draw.ellipse([30, 32, 55, 46], fill=(18, 26, 32, 220))
    draw.line([(35, 36), (50, 36)], fill=(35, 52, 64, 200), width=1)

    img.save(os.path.join(PROP_DIR, "domain_gargantuan_footprint.png"))
    print("Saved domain_gargantuan_footprint.png")


def make_colossal_claw_scar():
    w, h = 80, 150
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 3 deep raked gouges on vertical stone face
    # Boulder silhouette
    draw.polygon([(8, 10), (72, 15), (76, 140), (12, 145)], fill=(32, 36, 34, 255))
    draw.line([(10, 12), (70, 17)], fill=(50, 56, 52, 255), width=2)

    # 3 claw channels
    scars = [24, 40, 56]
    for sx in scars:
        draw.line([(sx, 25), (sx + 4, 80), (sx - 2, 130)], fill=(12, 14, 13, 255), width=4)
        # Crushed white stone powder along gouge edges
        draw.line([(sx - 2, 28), (sx + 2, 82), (sx - 4, 132)], fill=(85, 92, 88, 255), width=1)

    img.save(os.path.join(PROP_DIR, "domain_colossal_claw_scar.png"))
    print("Saved domain_colossal_claw_scar.png")


def make_nest_depression_mound():
    w, h = 320, 100
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Broad, trampled bedding depression with woven branches, crushed fern fronds, and bone fragments
    # Rim mound
    draw.ellipse([10, 30, w - 10, 95], fill=(28, 22, 16, 255))
    # Trampled hollow center
    draw.ellipse([35, 45, w - 35, 88], fill=(16, 12, 9, 255))

    # Entangled branches around outer rim
    for bx in range(25, w - 25, 28):
        by = int(50 + math.sin(bx * 0.05) * 12)
        draw.line([(bx, by), (bx + 35, by + 10)], fill=(48, 36, 26, 255), width=4)
        draw.line([(bx + 15, by - 5), (bx + 40, by + 15)], fill=(35, 26, 18, 255), width=3)

    # Crushed fern leaves (dark wilted green)
    for fx in range(45, w - 45, 35):
        draw.polygon([(fx, 65), (fx + 18, 58), (fx + 25, 72)], fill=(32, 45, 26, 255))

    # Bone remnants in nest
    draw.line([(120, 70), (160, 66)], fill=(145, 138, 120, 255), width=4)
    draw.line([(190, 72), (230, 68)], fill=(145, 138, 120, 255), width=4)

    img.save(os.path.join(PROP_DIR, "domain_nest_depression_mound.png"))
    print("Saved domain_nest_depression_mound.png")


# -------------------------------------------------------------
# 6. MECHANICAL REMNANTS (CONTINUING LEVEL 05 FORESHADOWING)
# -------------------------------------------------------------
def make_heavy_claw_sheath():
    w, h = 90, 70
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Massive, angular titanium theropod claw sheath, torn from an armature and driven into the dirt
    # Armature joint base
    draw.rectangle([10, 20, 35, 55], fill=(42, 48, 56, 255))
    # Bolt holes and reinforced plating
    draw.ellipse([15, 25, 23, 33], fill=(22, 25, 30, 255))
    draw.ellipse([15, 42, 23, 50], fill=(22, 25, 30, 255))

    # Claw blade extending forward and curved down
    draw.polygon([(35, 24), (72, 38), (85, 58), (55, 52), (35, 50)], fill=(58, 68, 78, 255))
    # Sharp talon edge
    draw.line([(35, 24), (72, 38), (85, 58)], fill=(92, 108, 122, 255), width=2)

    # Hydraulic conduit channel with faint blue dormant tracer
    draw.line([(25, 32), (60, 42)], fill=(55, 120, 160, 255), width=2)

    img.save(os.path.join(MECH_DIR, "domain_heavy_claw_sheath.png"))
    print("Saved domain_heavy_claw_sheath.png")


def make_reinforcing_spine_strut():
    w, h = 130, 80
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Curved articulated titanium cybernetic spine vertebrae strut, twisted and bent
    segments = [
        (20, 45), (42, 32), (68, 28), (95, 36), (115, 55)
    ]
    # Structural spine beam
    for i in range(len(segments) - 1):
        p1 = segments[i]
        p2 = segments[i + 1]
        draw.line([p1, p2], fill=(48, 56, 64, 255), width=14)
        draw.line([p1, p2], fill=(74, 86, 98, 255), width=6)

    # Segment knuckle caps
    for sx, sy in segments:
        draw.ellipse([sx - 10, sy - 10, sx + 10, sy + 10], fill=(36, 42, 50, 255))
        draw.ellipse([sx - 5, sy - 5, sx + 5, sy + 5], fill=(20, 24, 28, 255))

    # Piston cylinder attached to middle
    draw.line([(68, 28), (82, 65)], fill=(65, 75, 85, 255), width=8)

    img.save(os.path.join(MECH_DIR, "domain_reinforcing_spine_strut.png"))
    print("Saved domain_reinforcing_spine_strut.png")


def make_cracked_conduit_housing():
    w, h = 80, 60
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Severed armored cable assembly, cracked open, faint dormant cold blue glow
    # Steel housing block
    draw.polygon([(10, 20), (50, 15), (70, 40), (25, 48)], fill=(40, 46, 52, 255))
    draw.line([(10, 20), (50, 15)], fill=(65, 75, 85, 255), width=2)

    # Ruptured fissure in casing
    draw.polygon([(25, 28), (45, 24), (55, 38), (35, 42)], fill=(15, 20, 25, 255))

    # Glowing exposed coil core
    draw.ellipse([32, 28, 48, 38], fill=(60, 140, 195, 220))
    draw.ellipse([36, 31, 44, 35], fill=(140, 210, 255, 240))

    # Loose severed copper & carbon fiber braided wires trailing
    draw.arc([45, 30, 75, 55], start=0, end=150, fill=(110, 80, 50, 255), width=2)
    draw.arc([50, 20, 78, 48], start=20, end=180, fill=(70, 80, 90, 255), width=2)

    img.save(os.path.join(MECH_DIR, "domain_cracked_conduit_housing.png"))
    print("Saved domain_cracked_conduit_housing.png")


# -------------------------------------------------------------
# 7. EFFECTS & PARTICLES
# -------------------------------------------------------------
def make_spore_mote():
    w, h = 16, 16
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Faint glowing prehistoric forest spore
    draw.ellipse([2, 2, 14, 14], fill=(130, 165, 110, 80))
    draw.ellipse([5, 5, 11, 11], fill=(185, 225, 150, 180))
    draw.ellipse([7, 7, 9, 9], fill=(235, 255, 210, 255))
    img.save(os.path.join(FX_DIR, "domain_spore_mote.png"))
    print("Saved domain_spore_mote.png")


def make_ground_dust():
    w, h = 32, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Stomped soil/dust puff particle
    draw.ellipse([4, 4, 28, 28], fill=(85, 75, 60, 70))
    draw.ellipse([8, 8, 24, 24], fill=(115, 100, 80, 130))
    draw.ellipse([12, 12, 20, 20], fill=(145, 130, 105, 190))
    img.save(os.path.join(FX_DIR, "domain_ground_dust.png"))
    print("Saved domain_ground_dust.png")


if __name__ == "__main__":
    print("Generating assets for Level 06: Dev Yaratığın Bölgesi...")
    make_far_colossal_peaks()
    make_mid_titanic_canopy()
    make_near_bone_crags()
    make_fg_framing_roots()
    make_trampled_soil_ground()
    make_fossil_ledge()
    make_titan_root_platform()
    make_snapped_giant_tree()
    make_fallen_colossus_trunk()
    make_giant_ribcage_cluster()
    make_massive_skull_fossil()
    make_bone_heap()
    make_gargantuan_footprint()
    make_colossal_claw_scar()
    make_nest_depression_mound()
    make_heavy_claw_sheath()
    make_reinforcing_spine_strut()
    make_cracked_conduit_housing()
    make_spore_mote()
    make_ground_dust()
    print("All Level 06 assets successfully generated!")
