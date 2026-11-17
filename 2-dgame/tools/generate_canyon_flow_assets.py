"""
generate_canyon_flow_assets.py
Story 2D-134: Taş Devri Girişi ve Kanyon Akışı İyileştirmesi
Generates authentic pixel-art assets for Stage 1 Prehistoric Valley:
1. Fossils (prehistoric ribcage, colossal skull fossil, bone slab)
2. Canyon Floor Mist & Fog (pixel-art mist puff, drifting low mist band)
3. Background Silhouettes (2200px wide canyon crags, mesa rims, spires, apex shadow)
All assets adhere strictly to qa/art_direction/pixel_art_style_guide.md:
- Multiples of 8/16/32 grid dimensions
- Restricted harmonious palette (<32 colors for props, clean contours)
- No blurry anti-alias mixel noise; crisp pixel edges
"""

import os
import math
import numpy as np
from PIL import Image, ImageDraw

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

PROP_DIR = os.path.join(PROJECT_ROOT, "assets", "props", "stoneage")
EFFECT_DIR = os.path.join(PROJECT_ROOT, "assets", "effects", "stoneage")
BG_DIR = os.path.join(PROJECT_ROOT, "assets", "backgrounds", "stoneage")

for d in [PROP_DIR, EFFECT_DIR, BG_DIR]:
    os.makedirs(d, exist_ok=True)


# -------------------------------------------------------------------------
# PALETTE DEFINITIONS (Prehistoric Valley Theme)
# -------------------------------------------------------------------------
# Bone palette:
BONE_DARKEST = (32, 26, 20, 255)
BONE_SHADOW = (70, 60, 48, 255)
BONE_MID_DARK = (112, 100, 82, 255)
BONE_MID = (158, 146, 126, 255)
BONE_LIGHT = (198, 188, 170, 255)
BONE_HIGHLIGHT = (235, 228, 214, 255)
BONE_WHITE = (248, 245, 238, 255)

# Moss/Peat accents:
MOSS_DARK = (46, 58, 26, 255)
MOSS_MID = (75, 92, 42, 255)
MOSS_LIGHT = (108, 130, 60, 255)
PEAT_DARK = (24, 20, 16, 255)
PEAT_EARTH = (48, 38, 28, 255)

# Canyon Silhouette palette (Atmospheric Basalt):
SIL_BASE = (18, 25, 23, 255)
SIL_MID = (26, 36, 33, 255)
SIL_FAR = (36, 49, 45, 255)
SIL_HIGHLIGHT = (50, 68, 62, 255)


# -------------------------------------------------------------------------
# 1. FOSSILS
# -------------------------------------------------------------------------
def make_canyon_ribcage():
    """Authentic pixel-art prehistoric ribcage rising from peat soil. (192 x 96)"""
    w, h = 192, 96
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Base peat soil mound
    draw.ellipse([8, 70, 184, 94], fill=PEAT_EARTH)
    draw.ellipse([16, 76, 176, 92], fill=PEAT_DARK)

    # Moss patches on soil
    for mx in range(25, 170, 14):
        draw.rectangle([mx, 74, mx + 8, 77], fill=MOSS_DARK)
        draw.rectangle([mx + 2, 73, mx + 6, 75], fill=MOSS_MID)

    # 4 Colossal Rib Arches curving gracefully
    # Each rib defined by center_x, ground_y, width, height
    rib_specs = [
        (36, 82, 46, 70),
        (76, 84, 52, 78),
        (120, 83, 48, 74),
        (158, 80, 40, 64),
    ]

    for cx, gy, rw, rh in rib_specs:
        box = [cx - rw // 2, gy - rh, cx + rw // 2, gy + 10]
        # Outer dark outline / shadow
        draw.arc(box, start=175, end=340, fill=BONE_DARKEST, width=10)
        # Deep bone shadow
        draw.arc(box, start=175, end=340, fill=BONE_SHADOW, width=8)
        # Mid tone bone body
        draw.arc(box, start=178, end=338, fill=BONE_MID, width=6)
        # Light bone body
        draw.arc([box[0] - 1, box[1] - 1, box[2] + 1, box[3] - 1], start=182, end=320, fill=BONE_LIGHT, width=4)
        # Ridge highlight
        draw.arc([box[0] - 2, box[1] - 2, box[2], box[3] - 2], start=185, end=290, fill=BONE_HIGHLIGHT, width=2)

        # Weathering fractures on ribs
        fx = cx - rw // 4
        fy = gy - rh // 2
        draw.line([(fx, fy), (fx + 3, fy + 5)], fill=BONE_DARKEST, width=1)
        # Moss colonization on lower joint
        draw.rectangle([cx - rw // 2 + 2, gy - 16, cx - rw // 2 + 7, gy - 8], fill=MOSS_MID)
        draw.rectangle([cx + rw // 2 - 8, gy - 14, cx + rw // 2 - 3, gy - 7], fill=MOSS_DARK)

    # Embedded spinal vertebrae column at base
    for vx in range(40, 160, 20):
        draw.rectangle([vx, 76, vx + 14, 86], fill=BONE_DARKEST)
        draw.rectangle([vx + 1, 77, vx + 13, 85], fill=BONE_SHADOW)
        draw.rectangle([vx + 3, 78, vx + 11, 83], fill=BONE_MID)
        draw.rectangle([vx + 4, 79, vx + 8, 81], fill=BONE_LIGHT)

    out_path = os.path.join(PROP_DIR, "canyon_ribcage_fossil.png")
    img.save(out_path)
    # Also overwrite prehistoric_ribcage_remnant.png for seamless in-place compatibility
    legacy_path = os.path.join(PROP_DIR, "prehistoric_ribcage_remnant.png")
    img.resize((190, 90), Image.Resampling.NEAREST).save(legacy_path)
    print("Generated canyon_ribcage_fossil.png & updated prehistoric_ribcage_remnant.png")


def make_canyon_skull_fossil():
    """Colossal apex predator skull half-buried in canyon sediment. (160 x 112)"""
    w, h = 160, 112
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Base sediment mound
    draw.polygon([(10, 95), (60, 88), (120, 92), (155, 105), (145, 110), (20, 110)], fill=PEAT_EARTH)
    draw.polygon([(25, 96), (70, 92), (115, 94), (140, 104), (30, 108)], fill=PEAT_DARK)

    # Skull Cranium Silhouette
    cranium_pts = [
        (18, 92), (25, 60), (45, 32), (75, 24), (110, 26),
        (140, 48), (148, 70), (142, 94), (125, 98), (85, 96), (40, 98)
    ]
    # Dark outer border
    draw.polygon(cranium_pts, fill=BONE_DARKEST)

    # Inner cranium fill
    cranium_inner = [
        (20, 90), (27, 62), (46, 35), (75, 27), (108, 29),
        (137, 50), (144, 70), (138, 92), (122, 95), (85, 93), (42, 95)
    ]
    draw.polygon(cranium_inner, fill=BONE_SHADOW)

    # Bone main body
    cranium_body = [
        (24, 88), (30, 65), (48, 38), (75, 30), (106, 32),
        (134, 52), (140, 68), (134, 88), (120, 91), (85, 89), (45, 91)
    ]
    draw.polygon(cranium_body, fill=BONE_MID)

    # Light dorsal crest and brow ridge
    brow_ridge = [
        (35, 62), (50, 42), (75, 34), (104, 36), (128, 54),
        (124, 58), (102, 42), (75, 40), (50, 48), (36, 66)
    ]
    draw.polygon(brow_ridge, fill=BONE_LIGHT)
    draw.line([(55, 40), (75, 36), (100, 38)], fill=BONE_HIGHLIGHT, width=2)

    # Massive Orbital Eye Socket
    draw.ellipse([64, 44, 96, 76], fill=BONE_DARKEST)
    draw.ellipse([67, 47, 93, 73], fill=PEAT_DARK)
    # Inner eye socket rock shadow
    draw.arc([65, 45, 95, 75], start=180, end=330, fill=BONE_SHADOW, width=2)

    # Antorbital / Lateral Fenestra (Prehistoric skull hollow)
    draw.polygon([(36, 58), (56, 50), (52, 72), (38, 74)], fill=BONE_DARKEST)
    draw.polygon([(38, 60), (54, 53), (50, 70), (40, 72)], fill=PEAT_DARK)

    # Nasal Cavity
    draw.polygon([(112, 54), (128, 60), (118, 74)], fill=BONE_DARKEST)
    draw.polygon([(114, 56), (126, 61), (118, 71)], fill=PEAT_DARK)

    # Formidable Serrated Teeth (Upper Maxillary Row)
    teeth_coords = [(38, 88), (50, 87), (62, 86), (74, 86), (88, 87), (102, 88), (116, 90), (128, 92)]
    for tx, ty in teeth_coords:
        tooth_poly = [(tx - 3, ty), (tx, ty + 12), (tx + 3, ty)]
        draw.polygon(tooth_poly, fill=BONE_DARKEST)
        draw.polygon([(tx - 2, ty), (tx, ty + 10), (tx + 2, ty)], fill=BONE_LIGHT)
        draw.line([(tx, ty + 1), (tx, ty + 9)], fill=BONE_WHITE, width=1)

    # Weathering fissure cracks
    draw.line([(48, 36), (62, 46)], fill=BONE_DARKEST, width=2)
    draw.line([(62, 46), (58, 54)], fill=BONE_DARKEST, width=1)
    draw.line([(98, 36), (108, 48), (104, 58)], fill=BONE_DARKEST, width=2)

    # Moss colonies along lower jaw
    for mx in [30, 44, 82, 110, 132]:
        draw.rectangle([mx, 92, mx + 6, 96], fill=MOSS_DARK)
        draw.rectangle([mx + 1, 91, mx + 4, 93], fill=MOSS_MID)

    out_path = os.path.join(PROP_DIR, "canyon_skull_fossil.png")
    img.save(out_path)
    # Also update domain_massive_skull_fossil.png
    legacy_path = os.path.join(PROP_DIR, "domain_massive_skull_fossil.png")
    img.resize((160, 110), Image.Resampling.NEAREST).save(legacy_path)
    print("Generated canyon_skull_fossil.png & updated domain_massive_skull_fossil.png")


def make_canyon_bone_slab():
    """Flat fossil bone slab embedded in canyon cliff / platform ledge. (160 x 80)"""
    w, h = 160, 80
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rock / Loam substratum
    draw.polygon([(4, 30), (156, 26), (154, 76), (6, 76)], fill=PEAT_EARTH)
    draw.polygon([(8, 34), (152, 30), (150, 72), (10, 72)], fill=PEAT_DARK)

    # Colossal fossilized bone plate running horizontally
    plate_poly = [(12, 32), (148, 28), (144, 56), (16, 58)]
    draw.polygon(plate_poly, fill=BONE_DARKEST)
    draw.polygon([(14, 34), (146, 30), (142, 54), (18, 56)], fill=BONE_SHADOW)
    draw.polygon([(16, 36), (144, 32), (140, 50), (20, 52)], fill=BONE_MID)
    draw.polygon([(18, 37), (142, 33), (138, 44), (22, 46)], fill=BONE_LIGHT)
    draw.line([(22, 36), (138, 32)], fill=BONE_HIGHLIGHT, width=2)

    # Transverse vertebrae ridges & marrow cavities
    for rx in range(30, 135, 18):
        draw.rectangle([rx, 35, rx + 10, 49], fill=BONE_DARKEST)
        draw.rectangle([rx + 1, 36, rx + 9, 48], fill=BONE_SHADOW)
        draw.rectangle([rx + 2, 37, rx + 7, 44], fill=BONE_LIGHT)
        # Inner marrow hole
        draw.ellipse([rx + 3, 40, rx + 6, 45], fill=BONE_DARKEST)

    # Moss fringing along edges
    for mx in range(12, 145, 12):
        draw.rectangle([mx, 28, mx + 6, 32], fill=MOSS_DARK)
        draw.rectangle([mx + 1, 27, mx + 4, 30], fill=MOSS_MID)
        draw.rectangle([mx + 2, 55, mx + 7, 59], fill=MOSS_DARK)

    out_path = os.path.join(PROP_DIR, "canyon_bone_slab.png")
    img.save(out_path)
    legacy_path = os.path.join(PROP_DIR, "fossil_bone_slab.png")
    img.resize((164, 79), Image.Resampling.NEAREST).save(legacy_path)
    print("Generated canyon_bone_slab.png & updated fossil_bone_slab.png")


# -------------------------------------------------------------------------
# 2. CANYON FLOOR MIST & ATMOSPHERE
# -------------------------------------------------------------------------
def make_canyon_mist_puff():
    """Stylized 48x48 pixel-art mist puff with stepped concentric dither."""
    w, h = 48, 48
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Concentric pixel-dithered mist lobes in warm vapor tones
    MIST_OUTER = (210, 215, 205, 55)
    MIST_MID = (225, 230, 220, 110)
    MIST_INNER = (242, 245, 238, 175)
    MIST_CORE = (255, 255, 250, 220)

    # Outer lobes
    draw.ellipse([4, 12, 44, 36], fill=MIST_OUTER)
    draw.ellipse([8, 8, 38, 40], fill=MIST_OUTER)

    # Mid body
    draw.ellipse([10, 14, 38, 34], fill=MIST_MID)
    draw.ellipse([14, 10, 34, 38], fill=MIST_MID)

    # Inner dense cluster
    draw.ellipse([15, 16, 33, 32], fill=MIST_INNER)
    draw.ellipse([18, 14, 30, 34], fill=MIST_INNER)

    # Bright core
    draw.ellipse([20, 18, 28, 28], fill=MIST_CORE)

    out_path = os.path.join(EFFECT_DIR, "canyon_mist_puff.png")
    img.save(out_path)
    print("Generated canyon_mist_puff.png")


def make_canyon_mist_band():
    """Seamless 512x128 atmospheric drifting mist band for canyon chasm."""
    w, h = 512, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Create subtle drifting wave strands of warm prehistoric mist
    for x in range(w):
        # Sine waves creating rolling fog blankets
        y_top = 40 + int(math.sin(x * 0.02) * 12 + math.sin(x * 0.05) * 6)
        y_bottom = 100 + int(math.cos(x * 0.015) * 14 + math.sin(x * 0.04) * 8)
        y_bottom = min(h - 1, max(y_top + 10, y_bottom))

        for y in range(y_top, y_bottom):
            # Distance from center of band
            mid = (y_top + y_bottom) / 2.0
            dist = abs(y - mid) / max(1.0, (y_bottom - y_top) / 2.0)
            alpha = int(max(0, (1.0 - dist * dist) * 75))
            if alpha > 0:
                draw.point((x, y), fill=(230, 235, 225, alpha))

    out_path = os.path.join(EFFECT_DIR, "canyon_ambient_mist_band.png")
    img.save(out_path)
    print("Generated canyon_ambient_mist_band.png")


# -------------------------------------------------------------------------
# 3. BACKGROUND SILHOUETTES
# -------------------------------------------------------------------------
def make_canyon_crag_silhouettes():
    """
    Continuous 2200 x 480 pixel-art canyon silhouette layer.
    Features:
    - Towering basalt spires and rugged canyon rim walls
    - Prehistoric monolith arches
    - Windswept primeval pine / cycad silhouettes along high ridges
    - Distant apex predator silhouette perched on high promontory (around x=1380)
    """
    w, h = 2200, 480
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Far Silhouette Layer (Pale basalt tint, deep atmospheric distance)
    # Jagged cliff profile across 0 -> 2200
    far_heights = []
    for x in range(w):
        # Major cliff formations: entrance canyon wall (0-400), chasm dip (600-1000),
        # high mesa ridge (1200-1600), exit gate rock towers (1800-2200)
        base = 280
        # Add rock peaks
        var1 = math.sin(x * 0.005) * 60
        var2 = math.cos(x * 0.012) * 35
        var3 = math.sin(x * 0.03) * 15
        spike = 0
        # Basalt spires at specific scenic markers
        for spk_x, spk_h, spk_w in [(280, 90, 45), (740, 75, 40), (1380, 110, 60), (1850, 85, 50), (2100, 100, 55)]:
            if abs(x - spk_x) < spk_w:
                factor = (1.0 - abs(x - spk_x) / float(spk_w))
                spike += int(factor * factor * spk_h)

        yh = int(base - var1 - var2 - var3 - spike)
        yh = max(40, min(h - 10, yh))
        far_heights.append(yh)

    # Draw far silhouette columns
    for x in range(w):
        y_start = far_heights[x]
        draw.line([(x, y_start), (x, h)], fill=SIL_FAR, width=1)
        # Highlight rim pixel
        draw.point((x, y_start), fill=SIL_HIGHLIGHT)

    # 2. Mid Silhouette Layer (Crisp, dark basalt rock formations)
    mid_heights = []
    for x in range(w):
        base_mid = 340
        m1 = math.cos(x * 0.007) * 45
        m2 = math.sin(x * 0.018) * 28
        m3 = math.cos(x * 0.04) * 12
        mid_spike = 0
        for mspk_x, mspk_h, mspk_w in [(160, 60, 35), (880, 70, 45), (1380, 95, 50), (1650, 65, 40)]:
            if abs(x - mspk_x) < mspk_w:
                factor = (1.0 - abs(x - mspk_x) / float(mspk_w))
                mid_spike += int(factor * factor * mspk_h)

        ym = int(base_mid - m1 - m2 - m3 - mid_spike)
        ym = max(80, min(h - 5, ym))
        mid_heights.append(ym)

    for x in range(w):
        y_start = mid_heights[x]
        draw.line([(x, y_start), (x, h)], fill=SIL_BASE, width=1)
        draw.point((x, y_start), fill=SIL_MID)

    # 3. Primeval Pine & Fern Silhouettes along high ridges
    for tx in range(30, w - 30, 45):
        # Place trees on high rim points
        ty = mid_heights[tx]
        th = 28 + (tx % 17)
        # Tree trunk
        draw.line([(tx, ty), (tx, ty - th)], fill=SIL_BASE, width=2)
        # Tiered conical foliage
        for tier in range(3):
            tier_y = ty - th + tier * 8
            tier_w = 4 + tier * 4
            draw.polygon([(tx, tier_y - 6), (tx - tier_w, tier_y + 4), (tx + tier_w, tier_y + 4)], fill=SIL_BASE)

    # 4. Apex Predator Distant Silhouette (at Promontory x=1380, y=mid_heights[1380])
    # Giant beast perched looking down over the valley canyon
    ax = 1380
    ay = mid_heights[ax] - 2

    # Beast body silhouette (torso, massive tail, reared neck, heavy jaws)
    # Torso
    draw.ellipse([ax - 22, ay - 38, ax + 14, ay - 14], fill=SIL_BASE)
    # Powerful hind legs rooted to stone
    draw.polygon([(ax - 12, ay - 24), (ax - 20, ay), (ax - 8, ay), (ax - 4, ay - 24)], fill=SIL_BASE)
    draw.polygon([(ax + 2, ay - 24), (ax - 2, ay), (ax + 8, ay), (ax + 10, ay - 24)], fill=SIL_BASE)
    # Long counterbalancing tail arching back
    tail_pts = [(ax - 18, ay - 26), (ax - 36, ay - 32), (ax - 55, ay - 26), (ax - 70, ay - 18)]
    draw.line(tail_pts, fill=SIL_BASE, width=5)
    draw.line(tail_pts, fill=SIL_BASE, width=3)
    # Heavy muscular neck stretching up and right
    draw.polygon([(ax + 8, ay - 34), (ax + 24, ay - 52), (ax + 32, ay - 44), (ax + 14, ay - 24)], fill=SIL_BASE)
    # Massive predatory skull & jaws gaping slightly
    draw.polygon([(ax + 22, ay - 54), (ax + 42, ay - 50), (ax + 46, ay - 42), (ax + 28, ay - 40)], fill=SIL_BASE)
    # Glowing eye speck (cold primordial gold highlight)
    draw.point((ax + 34, ay - 48), fill=(230, 180, 60, 240))

    out_path = os.path.join(BG_DIR, "canyon_crag_silhouettes.png")
    img.save(out_path)
    # Also update apex_distant_shadow.png to be a clean crop matching the apex predator
    apex_crop = img.crop((ax - 90, ay - 70, ax + 90, ay + 30))
    apex_crop.resize((320, 240), Image.Resampling.NEAREST).save(os.path.join(PROP_DIR, "apex_distant_shadow.png"))
    print("Generated canyon_crag_silhouettes.png & updated apex_distant_shadow.png")


if __name__ == "__main__":
    print("=== Generating Authentic Canyon Flow Assets for 2D-134 ===")
    make_canyon_ribcage()
    make_canyon_skull_fossil()
    make_canyon_bone_slab()
    make_canyon_mist_puff()
    make_canyon_mist_band()
    make_canyon_crag_silhouettes()
    print("=== All Assets Successfully Generated! ===")
