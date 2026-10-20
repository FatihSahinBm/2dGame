"""
generate_fragments_assets.py
Vectorized generation of pixel-art background, tileset, mechanical remnant,
and temporal anomaly assets for Stone Age Level 05: Zamandan Kopan Parçalar (Temporal Fragments).
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


def make_far_chasm_peaks():
    w, h = 1920, 1080
    canvas = np.zeros((h, w, 3), dtype=np.uint8)

    # Sky gradient: cold overcast twilight with faint violet temporal undertone
    y_indices = np.arange(h)[:, None]
    t = y_indices / float(h)
    r = (28 * (1 - t) + 42 * t).astype(np.uint8)
    g = (30 * (1 - t) + 45 * t).astype(np.uint8)
    b = (42 * (1 - t) + 62 * t).astype(np.uint8)
    canvas[:, :, 0] = r
    canvas[:, :, 1] = g
    canvas[:, :, 2] = b

    # Towering basalt fissure crags (Furthest silhouettes)
    n1 = noise2d(w, 200, scale=45, seed=151)
    n2 = noise2d(w, 300, scale=35, seed=152)

    base1 = int(h * 0.42)
    base2 = int(h * 0.56)

    # Ridge 1 (Furthest basalt wall, z=-40)
    for x in range(w):
        y1 = max(0, min(h - 1, base1 - int(n1[100, x] * 130 + math.sin(x * 0.0035) * 75)))
        canvas[y1:h, x, 0] = (canvas[y1:h, x, 0].astype(np.float32) * 0.42 + 22 * 0.58).astype(np.uint8)
        canvas[y1:h, x, 1] = (canvas[y1:h, x, 1].astype(np.float32) * 0.42 + 25 * 0.58).astype(np.uint8)
        canvas[y1:h, x, 2] = (canvas[y1:h, x, 2].astype(np.float32) * 0.42 + 36 * 0.58).astype(np.uint8)

    # Ridge 2 (Chasm gorge pillars)
    for x in range(w):
        y2 = max(0, min(h - 1, base2 - int(n2[150, x] * 150 + math.cos(x * 0.005) * 85)))
        canvas[y2:h, x] = [18, 20, 28]

    # Jagged vertical rock towers rising up
    for tx in range(0, w, 28):
        th = int(45 + n1[100, tx] * 65)
        ty = base2 - int(n2[150, min(w - 1, tx)] * 150 + math.cos(tx * 0.005) * 85)
        for dy in range(th):
            curr_y = ty - dy
            if 0 <= curr_y < h:
                wl = int(max(2, (th - dy) * 0.25))
                canvas[curr_y, max(0, tx - wl):min(w, tx + wl + 1)] = [14, 16, 22]

    # Cold atmospheric haze & dust
    mist = noise2d(w, h, scale=65, seed=853)
    y_start = int(h * 0.32)
    y_factors = ((np.arange(y_start, h) - y_start) / float(h - y_start))[:, None]
    m_slice = np.repeat((mist[y_start:h, :] * 0.32 * y_factors)[:, :, None], 3, axis=2)
    fog_col = np.array([36.0, 42.0, 56.0])

    sub = canvas[y_start:h, :].astype(np.float32)
    canvas[y_start:h, :] = np.clip(sub * (1.0 - m_slice) + fog_col * m_slice, 0, 255).astype(np.uint8)

    img = Image.fromarray(canvas, "RGB")
    path = os.path.join(BG_DIR, "fragments_far_chasm_peaks.png")
    img.save(path)
    print("Created:", path)


def make_mid_fissure_cliffs():
    w, h = 1920, 1080
    canvas = np.zeros((h, w, 3), dtype=np.uint8)

    y_indices = np.arange(h)[:, None]
    t = y_indices / float(h)
    canvas[:, :, 0] = (16 + 12 * t).astype(np.uint8)
    canvas[:, :, 1] = (18 + 14 * t).astype(np.uint8)
    canvas[:, :, 2] = (24 + 18 * t).astype(np.uint8)

    # Mid-ground massive cracked rock cliffs & dry gorge fault-lines
    np.random.seed(351)
    pillars = [
        (100, 130), (280, 110), (480, 150), (710, 120), (940, 160),
        (1160, 130), (1380, 140), (1600, 120), (1800, 150)
    ]

    for px, pw in pillars:
        x_min, x_max = max(0, px - pw // 2), min(w, px + pw // 2)
        span = x_max - x_min
        if span <= 0:
            continue
        rel_x = np.abs(np.arange(span) - span / 2.0) / (span / 2.0)
        shade = (1.0 - rel_x * 0.4)[:, None]

        cliff_top = int(h * 0.35 + np.random.randint(-40, 40))
        block = np.zeros((h - cliff_top, span, 3), dtype=np.uint8)
        block[:, :, 0] = np.clip(26 * shade.T, 0, 255)
        block[:, :, 1] = np.clip(30 * shade.T, 0, 255)
        block[:, :, 2] = np.clip(38 * shade.T, 0, 255)
        canvas[cliff_top:h, x_min:x_max] = block

    # Fissure crack noise
    n_crack = noise2d(w, h, scale=20, seed=452)
    mask = (n_crack > 0.62) & (y_indices > int(h * 0.38))
    canvas[mask, 0] = np.clip(canvas[mask, 0] - 8, 4, 255)
    canvas[mask, 1] = np.clip(canvas[mask, 1] - 8, 4, 255)
    canvas[mask, 2] = np.clip(canvas[mask, 2] - 10, 6, 255)

    img = Image.fromarray(canvas, "RGB")
    path = os.path.join(BG_DIR, "fragments_mid_fissure_cliffs.png")
    img.save(path)
    print("Created:", path)


def make_near_fault_monoliths():
    w, h = 1920, 1080
    canvas = np.zeros((h, w, 3), dtype=np.uint8)

    y_indices = np.arange(h)[:, None]
    t = y_indices / float(h)
    canvas[:, :, 0] = (12 + 10 * t).astype(np.uint8)
    canvas[:, :, 1] = (14 + 10 * t).astype(np.uint8)
    canvas[:, :, 2] = (18 + 12 * t).astype(np.uint8)

    # Near basalt pillars and fractured rock ledges
    monoliths = [
        (60, 150), (320, 180), (660, 160), (1020, 190), (1390, 170), (1750, 180)
    ]
    for mx, mw in monoliths:
        for y in range(h):
            flare = int(max(0, (y - h * 0.55) * 0.35))
            curr_w = mw + flare * 2
            x_min = max(0, mx - curr_w // 2)
            x_max = min(w, mx + curr_w // 2)
            span = x_max - x_min
            if span <= 0:
                continue
            rel_x = np.abs(np.arange(span) - span / 2.0) / (span / 2.0)
            shade = 1.0 - rel_x * 0.42
            canvas[y, x_min:x_max, 0] = np.clip(28 * shade, 0, 255)
            canvas[y, x_min:x_max, 1] = np.clip(32 * shade, 0, 255)
            canvas[y, x_min:x_max, 2] = np.clip(40 * shade, 0, 255)

    # Patchy dried lichen on rock surfaces
    n_lichen = noise2d(w, h, scale=16, seed=653)
    l_mask = (n_lichen > 0.55) & (y_indices >= int(h * 0.45))
    canvas[l_mask, 0] = 34
    canvas[l_mask, 1] = 44
    canvas[l_mask, 2] = 36

    img = Image.fromarray(canvas, "RGB")
    path = os.path.join(BG_DIR, "fragments_near_fault_monoliths.png")
    img.save(path)
    print("Created:", path)


def make_fg_crag_silhouettes():
    w, h = 1920, 1080
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    # Dark basalt crag overhangs framing upper corners and edges
    draw.polygon([(0, 0), (620, 0), (480, 220), (180, 320), (0, 460)], fill=(10, 12, 16, 252))
    draw.polygon([(w, 0), (w - 620, 0), (w - 480, 220), (w - 180, 320), (w, 460)], fill=(10, 12, 16, 252))

    # Jagged stalactite rock points
    for rx, ry, rw, rh in [(160, 290, 35, 120), (320, 180, 40, 160), (w - 340, 180, 42, 150), (w - 180, 280, 30, 110)]:
        draw.polygon([(rx, ry), (rx + rw, ry), (rx + rw // 2, ry + rh)], fill=(8, 10, 14, 255))

    path = os.path.join(BG_DIR, "fragments_fg_crag_silhouettes.png")
    draw_img.save(path)
    print("Created:", path)


def make_fragments_basalt_ground():
    # 512 x 256 Churned gravelly clay, dark basalt bedrock, embedded metal scrap shrapnel
    w, h = 512, 256
    canvas = np.zeros((h, w, 4), dtype=np.uint8)
    y_indices = np.arange(h)[:, None]
    t = y_indices / float(h)
    canvas[:, :, 0] = (44 * (1 - t * 0.55)).astype(np.uint8)
    canvas[:, :, 1] = (46 * (1 - t * 0.55)).astype(np.uint8)
    canvas[:, :, 2] = (54 * (1 - t * 0.6)).astype(np.uint8)
    canvas[:, :, 3] = 255

    # Surface noise
    sn = (noise2d(w, h, scale=10, seed=781) - 0.5) * 22
    canvas[:, :, 0] = np.clip(canvas[:, :, 0].astype(float) + sn * 0.9, 8, 240).astype(np.uint8)
    canvas[:, :, 1] = np.clip(canvas[:, :, 1].astype(float) + sn * 0.95, 8, 240).astype(np.uint8)
    canvas[:, :, 2] = np.clip(canvas[:, :, 2].astype(float) + sn * 1.1, 10, 245).astype(np.uint8)

    # Top crust (rows 0-14): Basalt stone lip with occasional cold slate highlights and dry lichen
    for x in range(w):
        lip_wave = math.sin(x * 0.09) * 0.5 + math.cos(x * 0.25) * 0.5
        if lip_wave > 0.2:
            canvas[0, x] = [58, 68, 54, 255] # Lichen crust
            canvas[1, x] = [46, 54, 44, 255]
        else:
            canvas[0, x] = [62, 66, 76, 255] # Slate stone walk surface
            canvas[1, x] = [48, 52, 60, 255]

    # Embedded metal slivers & shrapnel flecks (unnatural geometric edges in rock)
    np.random.seed(892)
    for _ in range(25):
        mx = np.random.randint(6, w - 12)
        my = np.random.randint(8, 70)
        mw = np.random.randint(4, 9)
        # Metallic glint line
        canvas[my, mx:mx+mw] = [135, 146, 162, 255]
        canvas[my+1, mx:mx+mw] = [40, 44, 52, 255] # Shadow below

    # Subterranean bedrock layers
    for _ in range(40):
        px = np.random.randint(4, w - 8)
        py = np.random.randint(30, 200)
        pw = np.random.randint(4, 10)
        ph = np.random.randint(2, 6)
        canvas[py:py+ph, px:px+pw] = [32, 34, 40, 255]

    canvas[:, -1] = canvas[:, 0]
    canvas[:, -2] = canvas[:, 1]

    img = Image.fromarray(canvas, "RGBA")
    path = os.path.join(TILE_DIR, "fragments_basalt_ground.png")
    img.save(path)
    print("Created:", path)


def make_fragments_fissure_rock_ledge():
    # 240 x 70 Jagged basalt shelf with split fissure and embedded metal shard
    w, h = 240, 70
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    # Basalt rock block
    draw.polygon([(6, 10), (234, 10), (224, 52), (160, 64), (80, 58), (14, 48)], fill=(44, 48, 56, 255))
    draw.line([(6, 10), (234, 10)], fill=(66, 72, 84, 255), width=2)
    # Underside facets
    draw.polygon([(14, 48), (80, 58), (50, 32)], fill=(28, 30, 36, 255))
    draw.polygon([(160, 64), (224, 52), (195, 34)], fill=(28, 30, 36, 255))

    # Deep vertical fissure crack down the middle
    draw.line([(118, 10), (124, 62)], fill=(12, 14, 18, 255), width=3)

    # Embedded metal shear pin in fissure
    draw.polygon([(114, 22), (128, 20), (126, 36), (112, 38)], fill=(115, 126, 142, 255))
    draw.line([(114, 22), (128, 20)], fill=(160, 172, 190, 255), width=1)

    path = os.path.join(TILE_DIR, "fragments_fissure_rock_ledge.png")
    draw_img.save(path)
    print("Created:", path)


def make_fragments_industrial_strut_platform():
    # 240 x 70 Heavy bent metallic girder/strut jammed across chasm gap
    w, h = 240, 70
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    # Sturdy I-beam / structural box girder jammed horizontally
    # Top flange (walkable surface)
    draw.polygon([(8, 12), (232, 12), (230, 22), (10, 22)], fill=(75, 82, 94, 255))
    draw.line([(8, 12), (232, 12)], fill=(140, 152, 168, 255), width=2)

    # Web & bottom flange (with lightening holes / industrial truss cutouts)
    draw.polygon([(15, 22), (225, 22), (220, 50), (20, 50)], fill=(50, 55, 64, 255))
    draw.polygon([(20, 50), (220, 50), (218, 58), (22, 58)], fill=(38, 42, 50, 255))

    # Rectangular truss cutouts showing background
    for ox in [35, 75, 115, 155, 195]:
        draw.rectangle([ox, 28, ox + 24, 44], fill=(0, 0, 0, 0))

    # Scratches, bent impact fold on right end
    draw.polygon([(215, 12), (234, 18), (226, 30), (210, 22)], fill=(110, 120, 136, 255))
    # Rock debris cementing the ends into place
    draw.ellipse([2, 8, 24, 34], fill=(42, 46, 52, 255))
    draw.ellipse([218, 8, 238, 34], fill=(42, 46, 52, 255))

    path = os.path.join(TILE_DIR, "fragments_industrial_strut_platform.png")
    draw_img.save(path)
    print("Created:", path)


def make_small_embedded_plates():
    # 120 x 80 Small dark alloy plates embedded in rock crevice
    w, h = 120, 80
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    # Surrounding rock matrix
    draw.ellipse([10, 15, 110, 70], fill=(38, 42, 48, 255))
    draw.ellipse([25, 25, 95, 60], fill=(20, 22, 26, 255)) # Dark cleft

    # Three overlapping geometric metal plates jutting out
    plate1 = [(32, 36), (62, 28), (68, 52), (38, 58)]
    draw.polygon(plate1, fill=(68, 75, 86, 255))
    draw.line([(32, 36), (62, 28)], fill=(130, 142, 158, 255), width=2)
    # Rivet / bolt head
    draw.ellipse([45, 38, 49, 42], fill=(160, 172, 190, 255))

    plate2 = [(58, 32), (86, 30), (90, 48), (62, 52)]
    draw.polygon(plate2, fill=(82, 90, 102, 255))
    draw.line([(58, 32), (86, 30)], fill=(145, 158, 175, 255), width=2)
    draw.ellipse([72, 36, 76, 40], fill=(175, 188, 205, 255))

    path = os.path.join(MECH_DIR, "small_metal_plating_embedded.png")
    draw_img.save(path)
    print("Created:", path)


def make_severed_mechanical_joint():
    # 150 x 100 Heavy severed mechanical hinge/joint with frayed conduit cables
    w, h = 150, 100
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    # Cylindrical pivot joint housing
    draw.ellipse([40, 25, 95, 75], fill=(55, 60, 70, 255))
    draw.ellipse([48, 33, 87, 67], fill=(78, 86, 98, 255))
    draw.ellipse([58, 43, 77, 57], fill=(30, 34, 40, 255)) # Central pin hole
    draw.line([(48, 33), (87, 33)], fill=(155, 168, 185, 255), width=2) # Upper rim glint

    # Severed bracket arm extending left
    draw.polygon([(18, 42), (48, 36), (48, 64), (18, 58)], fill=(65, 72, 82, 255))
    # Sheared ragged break edge
    draw.polygon([(12, 40), (18, 42), (18, 58), (14, 62)], fill=(120, 132, 148, 255))

    # Frayed conduit cables spilling out on right
    cables = [
        [(85, 42), (105, 38), (125, 44), (138, 40)],
        [(88, 52), (112, 55), (130, 50), (142, 58)],
        [(84, 60), (102, 68), (122, 64), (135, 72)]
    ]
    for pts in cables:
        draw.line(pts, fill=(35, 38, 44, 255), width=3)
        # Copper/alloy core strands sticking out of severed tips
        tip = pts[-1]
        draw.line([tip, (tip[0] + 5, tip[1] - 3)], fill=(185, 140, 80, 255), width=1)
        draw.line([tip, (tip[0] + 6, tip[1] + 2)], fill=(185, 140, 80, 255), width=1)

    path = os.path.join(MECH_DIR, "severed_mechanical_joint.png")
    draw_img.save(path)
    print("Created:", path)


def make_medium_armature_linkage():
    # 180 x 110 Dual-hinged linkage strut with hydraulic cylinder sleeve
    w, h = 180, 110
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    # Rock / dirt mound partially burying lower section
    draw.ellipse([15, 60, 165, 100], fill=(42, 38, 34, 255))

    # Main hydraulic cylinder casing (angled at ~25 degrees)
    draw.polygon([(35, 72), (125, 32), (132, 48), (42, 88)], fill=(62, 68, 78, 255))
    draw.line([(35, 72), (125, 32)], fill=(135, 148, 166, 255), width=2) # Specular highlight

    # Piston rod emerging from cylinder sleeve
    draw.polygon([(125, 32), (155, 18), (160, 28), (130, 42)], fill=(160, 172, 190, 255)) # Polished chrome/steel
    draw.line([(125, 32), (155, 18)], fill=(225, 235, 248, 255), width=2)

    # Spherical rod end bearing at (160, 22)
    draw.ellipse([148, 12, 172, 34], fill=(70, 78, 90, 255))
    draw.ellipse([154, 18, 166, 28], fill=(24, 28, 34, 255)) # Hole

    # Flanged mounting collar with bolts
    draw.polygon([(70, 56), (78, 52), (84, 68), (76, 72)], fill=(85, 94, 108, 255))
    draw.ellipse([73, 58, 77, 62], fill=(180, 192, 210, 255))

    path = os.path.join(MECH_DIR, "medium_armature_linkage.png")
    draw_img.save(path)
    print("Created:", path)


def make_piston_casing_fissure():
    # 170 x 120 Thick alloy piston casing lodged between split rock faces
    w, h = 170, 120
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    # Left & right basalt cliff jaws
    draw.polygon([(0, 10), (55, 35), (48, 110), (0, 110)], fill=(36, 40, 46, 255))
    draw.polygon([(115, 25), (170, 10), (170, 110), (122, 110)], fill=(36, 40, 46, 255))

    # Heavy industrial casing wedged tight between the rocks
    draw.polygon([(46, 40), (122, 30), (125, 88), (48, 96)], fill=(58, 64, 74, 255))
    draw.line([(46, 40), (122, 30)], fill=(125, 138, 155, 255), width=2)

    # Reinforced circumferential ribbing rings
    for rx, ry in [(65, 38), (85, 35), (105, 32)]:
        draw.polygon([(rx, ry), (rx + 8, ry - 1), (rx + 9, ry + 56), (rx + 1, ry + 57)], fill=(82, 90, 104, 255))
        draw.line([(rx, ry), (rx + 8, ry - 1)], fill=(150, 164, 182, 255), width=1)

    # Shadow depth behind
    draw.polygon([(52, 20), (118, 16), (116, 30), (50, 36)], fill=(14, 16, 20, 255))

    path = os.path.join(MECH_DIR, "piston_casing_fissure.png")
    draw_img.save(path)
    print("Created:", path)


def make_massive_armature_socket_fissure():
    # 260 x 180 THE MAJOR CLUE OBJECT:
    # Colossal armored mechanical socket / shoulder articulation assembly wedged into giant basalt fault!
    # Shows heavy bolted flange ring, scorched mounting brackets, and a faint cold blue temporal core pulse.
    w, h = 260, 180
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    # 1. Giant basalt rock crevice engulfing the bottom and rear
    draw.polygon([(10, 160), (250, 160), (242, 85), (195, 60), (150, 40), (75, 45), (18, 90)], fill=(32, 35, 42, 255))
    draw.ellipse([40, 60, 220, 140], fill=(16, 18, 22, 255)) # Deep chasm cavity

    # 2. Heavy armored spherical articulation socket (center (130, 95))
    draw.ellipse([70, 45, 190, 145], fill=(50, 56, 66, 255))
    draw.ellipse([80, 55, 180, 135], fill=(72, 80, 94, 255))
    draw.ellipse([92, 67, 168, 123], fill=(38, 42, 50, 255)) # Inner ball chamber
    draw.line([(80, 55), (180, 55)], fill=(155, 168, 188, 255), width=2) # Polished upper lip

    # 3. Heavy bolted flange collar around socket
    draw.ellipse([64, 38, 196, 152], outline=(90, 100, 116, 255), width=5)
    # Flange bolt heads around perimeter
    angles = np.linspace(0, 2 * math.pi, 12, endpoint=False)
    for a in angles:
        bx = int(130 + math.cos(a) * 62)
        by = int(95 + math.sin(a) * 52)
        draw.ellipse([bx - 3, by - 3, bx + 3, by + 3], fill=(185, 198, 218, 255))

    # 4. Massive structural rib / mounting bracket trailing off into rock
    draw.polygon([(45, 85), (12, 120), (25, 140), (70, 115)], fill=(60, 66, 78, 255))
    draw.line([(45, 85), (12, 120)], fill=(125, 138, 156, 255), width=2)

    # 5. Cold temporal energy glow in core (subtle mysterious pulse)
    glow_col = (56, 189, 248, 140)
    core_col = (147, 197, 253, 210)
    draw.ellipse([110, 80, 150, 110], fill=glow_col)
    draw.ellipse([120, 88, 140, 102], fill=core_col)

    path = os.path.join(MECH_DIR, "massive_armature_socket_fissure.png")
    draw_img.save(path)
    print("Created:", path)


def make_temporal_arc_particle():
    # 32 x 32 Cold blue temporal energy arc particle
    w, h = 32, 32
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    # Jagged lightning-like energy arc
    pts = [(16, 2), (20, 10), (12, 16), (22, 22), (16, 30)]
    draw.line(pts, fill=(56, 189, 248, 230), width=2)
    draw.line([(16, 2), (20, 10), (12, 16)], fill=(224, 242, 254, 255), width=1)

    path = os.path.join(FX_DIR, "temporal_arc_particle.png")
    draw_img.save(path)
    print("Created:", path)


def make_temporal_mote_particle():
    # 16 x 16 Faint floating temporal energy mote
    w, h = 16, 16
    draw_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(draw_img)

    draw.ellipse([2, 2, 14, 14], fill=(96, 165, 250, 90))
    draw.ellipse([5, 5, 11, 11], fill=(191, 219, 254, 220))

    path = os.path.join(FX_DIR, "temporal_mote_particle.png")
    draw_img.save(path)
    print("Created:", path)


if __name__ == "__main__":
    print("=== Generating Stone Age Level 05 Assets ===")
    make_far_chasm_peaks()
    make_mid_fissure_cliffs()
    make_near_fault_monoliths()
    make_fg_crag_silhouettes()
    make_fragments_basalt_ground()
    make_fragments_fissure_rock_ledge()
    make_fragments_industrial_strut_platform()
    make_small_embedded_plates()
    make_severed_mechanical_joint()
    make_medium_armature_linkage()
    make_piston_casing_fissure()
    make_massive_armature_socket_fissure()
    make_temporal_arc_particle()
    make_temporal_mote_particle()
    print("=== All Stone Age Level 05 Assets Generated Successfully! ===")
