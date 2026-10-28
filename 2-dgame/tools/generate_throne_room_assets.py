import os
import numpy as np
from PIL import Image

# Output directory for castle environment
OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "environment", "castle"))
os.makedirs(OUT_DIR, exist_ok=True)

CLEAR = [0, 0, 0, 0]


def render_block(canvas, x0, y0, x1, y1, base_color, hi_color, dark_color, deep_color):
    """
    Renders an individual ashlar stone block with directional bevel lighting
    (light from top-left, shadow on bottom-right) and subtle stone grain.
    """
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            n = np.random.randint(-2, 3)
            canvas[y, x] = [
                np.clip(base_color[0] + n, 8, 245),
                np.clip(base_color[1] + n, 8, 245),
                np.clip(base_color[2] + n, 8, 245),
                255
            ]

    # Top highlight bevel (y0)
    canvas[y0, x0:x1 + 1] = hi_color
    # Left highlight bevel (x0)
    canvas[y0:y1 + 1, x0] = hi_color
    # Bottom shadow bevel (y1)
    canvas[y1, x0:x1 + 1] = dark_color
    # Right shadow bevel (x1)
    canvas[y0:y1 + 1, x1] = dark_color

    # Corner specular glint at top-left
    if x1 > x0 and y1 > y0:
        canvas[y0, x0] = [
            np.clip(hi_color[0] + 35, 10, 255),
            np.clip(hi_color[1] + 35, 10, 255),
            np.clip(hi_color[2] + 40, 10, 255),
            255
        ]

    # Subtle surface chisel accent
    w = x1 - x0
    h = y1 - y0
    if w >= 16 and h >= 8:
        cx = x0 + w // 2 - 1
        cy = y0 + h // 2
        canvas[cy, cx:cx + 3] = dark_color
        canvas[cy + 1, cx:cx + 3] = hi_color


def generate_throne_gothic_floor():
    """
    Creates throne_gothic_floor.png (96x96).
    NinePatch layout:
      patch_margin_left = 16
      patch_margin_top = 16
      patch_margin_right = 16
      patch_margin_bottom = 16
      axis_stretch_horizontal = 1 (TILE)
      axis_stretch_vertical = 1 (TILE)

    The center 64px (X: 16 to 79) tiles horizontally seamlessly.
    The center 64px (Y: 16 to 79) tiles vertically seamlessly.
    The top band (Y: 0 to 15, X: 16 to 79) tiles horizontally seamlessly.
    """
    W, H = 96, 96
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(777)

    # Palette
    C_MORTAR       = [10, 11, 14, 255]
    C_SPECULAR     = [135, 142, 162, 255]
    C_WALK_HI      = [98, 106, 126, 255]
    C_PAVER_FACE   = [68, 76, 92, 255]
    C_STONE_MID    = [46, 52, 64, 255]
    C_STONE_ALT    = [36, 40, 50, 255]
    C_STONE_DARK   = [24, 27, 34, 255]
    C_STONE_DEEP   = [16, 18, 22, 255]

    # Royal Wallachian Crimson Inlay
    C_CRIMSON_HI   = [165, 34, 48, 255]
    C_CRIMSON_MID  = [118, 22, 34, 255]
    C_CRIMSON_DEEP = [60, 12, 18, 255]
    C_GOLD_FLECK   = [180, 148, 62, 255]

    # Fill base mortar color
    canvas[:, :] = C_MORTAR

    # ---------------------------------------------------------------------
    # 1. TOP COPING FLAGSTONES & ROYAL CRIMSON INLAY (Y: 0 to 15)
    # ---------------------------------------------------------------------
    # Y = 0: Crisp walkable rim highlight (where character's feet land at Y = 560)
    canvas[0, :] = C_WALK_HI
    for x in range(0, W, 8):
        canvas[0, x:x + 3] = C_SPECULAR

    # Y = 1 to 3: Polished slate/obsidian coping paver face
    for y in range(1, 4):
        canvas[y, :] = C_PAVER_FACE
        for x in range(W):
            if (x + y) % 5 == 0:
                canvas[y, x] = C_WALK_HI
            elif (x * 2 + y) % 7 == 0:
                canvas[y, x] = C_STONE_MID

    # Flagstone paver joints in top band:
    # 32px rhythm: Joints at X = 16, 48, 80 (seamless across X: 16..79 wrap!)
    # Left margin joint: X = 0. Right margin joint: X = 95.
    for jx in [0, 16, 48, 80, 95]:
        canvas[0:4, jx] = C_STONE_DEEP
        if jx + 1 < W:
            canvas[1:4, jx + 1] = C_SPECULAR

    # Y = 4: Upper inlay channel groove
    canvas[4, :] = C_STONE_DEEP

    # Y = 5 to 6: Royal Wallachian crimson runner inlay band!
    # Tiling width is 64px (X: 16 to 79). 4 repeating 16px diamond lozenges:
    # Repetition cycle = 16px: center at dx = 8.
    for x in range(W):
        # Calculate offset within the 16px repeating rhythm
        dx = (x - 16) % 16
        if dx in [7, 8]:
            canvas[5, x] = C_CRIMSON_HI
            canvas[6, x] = C_GOLD_FLECK if dx == 7 else C_CRIMSON_MID
        elif dx in [6, 9]:
            canvas[5, x] = C_CRIMSON_MID
            canvas[6, x] = C_CRIMSON_DEEP
        elif dx in [5, 10]:
            canvas[5, x] = C_CRIMSON_DEEP
            canvas[6, x] = C_CRIMSON_DEEP
        else:
            canvas[5, x] = C_STONE_MID
            canvas[6, x] = C_STONE_DARK

    # Y = 7: Lower inlay channel groove
    canvas[7, :] = C_STONE_DEEP

    # Y = 8 to 11: Coping stone lower chamfer / face
    canvas[8, :] = C_PAVER_FACE
    canvas[9, :] = C_STONE_MID
    canvas[10, :] = C_STONE_ALT
    canvas[11, :] = C_STONE_DARK

    # Y = 12: Deep coping stone overhang drop-shadow
    canvas[12, :] = C_MORTAR

    # Y = 13 to 15: Sub-coping stone frieze band (height 3)
    for y in range(13, 16):
        canvas[y, :] = C_STONE_MID
        # Vertical decorative fluting / dentil accents every 8px
        for x in range(W):
            if (x - 16) % 8 in [0, 1]:
                canvas[y, x] = C_STONE_DARK
            elif (x - 16) % 8 == 2:
                canvas[y, x] = C_PAVER_FACE

    # ---------------------------------------------------------------------
    # 2. CENTER TILED ASHLAR MASONRY (X: 16..79, Y: 16..79)
    # ---------------------------------------------------------------------
    # 4 repeating courses of 16px height each:
    # Course 1: Y = 16 to 31 (height 16: mortar at 16, block 17..31)
    # Course 2: Y = 32 to 47 (height 16: mortar at 32, block 33..47)
    # Course 3: Y = 48 to 63 (height 16: mortar at 48, block 49..63)
    # Course 4: Y = 64 to 79 (height 16: mortar at 64, block 65..78, mortar at 79)
    # Notice: Row 79 is mortar [10, 11, 14], which connects seamlessly to Row 16 mortar!

    canvas[16, :] = C_MORTAR
    canvas[32, :] = C_MORTAR
    canvas[48, :] = C_MORTAR
    canvas[64, :] = C_MORTAR
    canvas[79, :] = C_MORTAR

    # COURSE 1 (Y: 17 to 31, height 15)
    # 32px running bond: Joints at X = 16, 48, 80
    # Left margin: X: 1..15
    render_block(canvas, 1, 17, 15, 31, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    # Center blocks: X: 17..47 (width 31) and X: 49..79 (width 31)
    render_block(canvas, 17, 17, 47, 31, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 49, 17, 79, 31, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    # Right margin: X: 81..94
    render_block(canvas, 81, 17, 94, 31, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)

    # COURSE 2 (Y: 33 to 47, height 15) - Staggered by 16px!
    # Joints at X = 32, 64 (and wrap at 80->16)
    # Left margin + center wrap left half:
    render_block(canvas, 1, 33, 15, 47, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 17, 33, 31, 47, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    # Center full block: X: 33..63 (width 31)
    render_block(canvas, 33, 33, 63, 47, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    # Center wrap right half: X: 65..79 (width 15)
    render_block(canvas, 65, 33, 79, 47, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    # Right margin: X: 81..94
    render_block(canvas, 81, 33, 94, 47, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)

    # COURSE 3 (Y: 49 to 63, height 15) - Aligned with Course 1 rhythm
    # Joints at X = 16, 48, 80
    render_block(canvas, 1, 49, 15, 63, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 17, 49, 47, 63, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 49, 49, 79, 63, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 81, 49, 94, 63, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)

    # COURSE 4 (Y: 65 to 78, height 14 + row 79 mortar) - Staggered by 16px!
    # Joints at X = 32, 64
    render_block(canvas, 1, 65, 15, 78, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 17, 65, 31, 78, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 33, 65, 63, 78, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 65, 65, 79, 78, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 81, 65, 94, 78, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)

    # ---------------------------------------------------------------------
    # 3. BOTTOM MARGIN FOUNDATION (Y: 80 to 95)
    # ---------------------------------------------------------------------
    canvas[80, :] = C_MORTAR
    render_block(canvas, 1, 81, 15, 94, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 17, 81, 47, 94, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 49, 81, 79, 94, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 81, 81, 94, 94, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    canvas[95, :] = C_MORTAR

    # Outer border edges
    canvas[:, 0] = C_MORTAR
    canvas[:, 95] = C_MORTAR

    img = Image.fromarray(canvas, 'RGBA')
    out_path = os.path.join(OUT_DIR, "throne_gothic_floor.png")
    img.save(out_path)
    print("Created:", out_path)


def generate_ramparts_stone_floor():
    """
    Creates ramparts_stone_floor.png (96x96).
    NinePatch layout:
      patch_margin_left = 16
      patch_margin_top = 16
      patch_margin_right = 16
      patch_margin_bottom = 16
      axis_stretch_horizontal = 1 (TILE)
      axis_stretch_vertical = 1 (TILE)

    Cold moonlit slate & weathered dark granite palette for Arena 3 (Ramparts)
    and Arena 4 (Bell Tower).
    """
    W, H = 96, 96
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(888)

    # Palette (Cold Moonlight Stone & Heavy Granite)
    C_MORTAR       = [10, 12, 16, 255]
    C_SPECULAR     = [145, 165, 195, 255]
    C_WALK_HI      = [110, 125, 150, 255]
    C_PAVER_FACE   = [76, 88, 108, 255]
    C_STONE_MID    = [50, 58, 72, 255]
    C_STONE_ALT    = [38, 44, 56, 255]
    C_STONE_DARK   = [26, 30, 40, 255]
    C_STONE_DEEP   = [16, 18, 25, 255]
    C_LICHEN       = [32, 42, 36, 255]

    # Fill base mortar color
    canvas[:, :] = C_MORTAR

    # ---------------------------------------------------------------------
    # 1. TOP DEFENSIVE COPING FLAGSTONES (Y: 0 to 15)
    # ---------------------------------------------------------------------
    # Y = 0: Moonlight rim catchlight
    canvas[0, :] = C_WALK_HI
    for x in range(0, W, 8):
        canvas[0, x:x + 3] = C_SPECULAR

    # Y = 1 to 5: Heavy weathered coping pavers
    for y in range(1, 6):
        canvas[y, :] = C_PAVER_FACE
        for x in range(W):
            if (x + y * 2) % 6 == 0:
                canvas[y, x] = C_WALK_HI
            elif (x * 3 + y) % 7 == 0:
                canvas[y, x] = C_STONE_MID

    # Flagstone paver joints:
    # 32px rhythm at X = 16, 48, 80 (seamless across wrap!)
    for jx in [0, 16, 48, 80, 95]:
        canvas[0:6, jx] = C_STONE_DEEP
        if jx + 1 < W:
            canvas[1:6, jx + 1] = C_SPECULAR

    # Y = 6: Chiseled stone drip-edge bevel
    canvas[6, :] = C_STONE_MID

    # Y = 7: Deep drip-edge undercut shadow
    canvas[7, :] = C_MORTAR

    # Y = 8 to 11: Sub-coping corbelled stone band
    for y in range(8, 12):
        canvas[y, :] = C_STONE_MID
        for x in range(W):
            if (x - 16) % 16 in [0, 1]:
                canvas[y, x] = C_STONE_DARK
            elif (x - 16) % 16 == 2:
                canvas[y, x] = C_WALK_HI

    # Y = 12: Shadow under corbel band
    canvas[12, :] = C_MORTAR

    # Y = 13 to 15: Upper course under battlement coping
    render_block(canvas, 1, 13, 15, 15, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 17, 13, 47, 15, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 49, 13, 79, 15, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 81, 13, 94, 15, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)

    # ---------------------------------------------------------------------
    # 2. CENTER TILED WEATHERED GRANITE MASONRY (X: 16..79, Y: 16..79)
    # ---------------------------------------------------------------------
    canvas[16, :] = C_MORTAR
    canvas[32, :] = C_MORTAR
    canvas[48, :] = C_MORTAR
    canvas[64, :] = C_MORTAR
    canvas[79, :] = C_MORTAR

    # COURSE 1 (Y: 17 to 31)
    render_block(canvas, 1, 17, 15, 31, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 17, 17, 47, 31, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 49, 17, 79, 31, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 81, 17, 94, 31, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)

    # COURSE 2 (Y: 33 to 47) - Staggered by 16px!
    render_block(canvas, 1, 33, 15, 47, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 17, 33, 31, 47, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 33, 33, 63, 47, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 65, 33, 79, 47, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 81, 33, 94, 47, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)

    # COURSE 3 (Y: 49 to 63)
    render_block(canvas, 1, 49, 15, 63, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 17, 49, 47, 63, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 49, 49, 79, 63, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 81, 49, 94, 63, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)

    # COURSE 4 (Y: 65 to 78, row 79 mortar)
    render_block(canvas, 1, 65, 15, 78, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 17, 65, 31, 78, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 33, 65, 63, 78, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 65, 65, 79, 78, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 81, 65, 94, 78, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)

    # Weathered ancient cracks in rampart blocks
    for cx in [38, 70]:
        canvas[22:27, cx] = C_STONE_DEEP
        canvas[23:28, cx + 1] = C_WALK_HI
    for cx in [24, 56]:
        canvas[54:59, cx] = C_STONE_DEEP
        canvas[55:60, cx + 1] = C_WALK_HI

    # Lichen stains in select mortar nooks
    canvas[16, 40:44] = C_LICHEN
    canvas[48, 20:24] = C_LICHEN
    canvas[64, 52:56] = C_LICHEN

    # ---------------------------------------------------------------------
    # 3. BOTTOM MARGIN FOUNDATION (Y: 80 to 95)
    # ---------------------------------------------------------------------
    canvas[80, :] = C_MORTAR
    render_block(canvas, 1, 81, 15, 94, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 17, 81, 47, 94, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 49, 81, 79, 94, C_STONE_ALT, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    render_block(canvas, 81, 81, 94, 94, C_STONE_MID, C_PAVER_FACE, C_STONE_DARK, C_STONE_DEEP)
    canvas[95, :] = C_MORTAR

    canvas[:, 0] = C_MORTAR
    canvas[:, 95] = C_MORTAR

    img = Image.fromarray(canvas, 'RGBA')
    out_path = os.path.join(OUT_DIR, "ramparts_stone_floor.png")
    img.save(out_path)
    print("Created:", out_path)


def generate_gothic_castle_platform():
    """
    Creates gothic_castle_platform.png (240x24).
    Matches 240x24 one-way collision geometry.
    Features:
      - Crisp walkable highlight line at Y = 0 (high contrast for jump target)
      - Polished heavy flagstone coping (Y = 1 to 5) with distinct paver joints
      - Deep shadow groove (Y = 6)
      - Dark ashlar stone platform body (Y = 7 to 16)
      - Beveled underside chamfer (Y = 17 to 20)
      - Transparent cutout underside (Y = 21 to 23) between protruding corbel supports
      - Forged black iron bracket endcaps (X: 1..14 and X: 225..238) with rivets
      - 3 intermediate gothic corbel bracket supports (X: 60, 120, 180) extending to Y = 23
    """
    W, H = 240, 24
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(999)

    # Palette
    C_PLAT_SPECULAR  = [168, 178, 204, 255]
    C_PLAT_WALK_HI   = [128, 138, 160, 255]
    C_PLAT_PAVER_TOP = [84, 92, 110, 255]
    C_PLAT_PAVER_MID = [64, 70, 84, 255]
    C_PLAT_STONE_MID = [48, 52, 64, 255]
    C_PLAT_STONE_DARK= [32, 35, 44, 255]
    C_PLAT_UNDERSIDE = [18, 20, 26, 255]
    C_PLAT_DEEP_VOID = [10, 11, 15, 255]

    # Forged Iron & Rivets
    C_IRON_HI        = [120, 128, 144, 255]
    C_IRON_MID       = [52, 56, 66, 255]
    C_IRON_DARK      = [26, 28, 34, 255]
    C_RIVET_SHINE    = [205, 215, 235, 255]
    C_RIVET_SHADOW   = [16, 17, 22, 255]

    # Corbel Stone
    C_CORBEL_HI      = [78, 86, 102, 255]
    C_CORBEL_MID     = [48, 54, 66, 255]
    C_CORBEL_DARK    = [22, 24, 30, 255]

    # Default canvas is transparent
    canvas[:, :] = CLEAR

    # 1. Base stone body fill (Y: 1 to 20, X: 1 to 238)
    for y in range(1, 21):
        for x in range(1, W - 1):
            n = np.random.randint(-2, 3)
            canvas[y, x] = [
                np.clip(C_PLAT_STONE_MID[0] + n, 10, 240),
                np.clip(C_PLAT_STONE_MID[1] + n, 10, 240),
                np.clip(C_PLAT_STONE_MID[2] + n, 10, 240),
                255
            ]

    # 2. Walkable Top Edge Highlight (Y = 0)
    # High-contrast catchlight line for instant jump readability!
    for x in range(1, W - 1):
        if x % 10 in [0, 1]:
            canvas[0, x] = C_PLAT_SPECULAR
        else:
            canvas[0, x] = C_PLAT_WALK_HI

    # Beveled hand-hewn corners at (0, 0) and (W-1, 0) remain CLEAR for natural silhouette
    canvas[0, 1] = C_PLAT_SPECULAR
    canvas[0, W - 2] = C_PLAT_SPECULAR

    # 3. Flagstone Coping Upper Face (Y = 1 to 4)
    for y in range(1, 5):
        canvas[y, 1:W - 1] = C_PLAT_PAVER_TOP
        for x in range(1, W - 1):
            if (x + y * 2) % 7 == 0:
                canvas[y, x] = C_PLAT_WALK_HI
            elif (x * 3 + y) % 9 == 0:
                canvas[y, x] = C_PLAT_PAVER_MID

    # Flagstone joints every 40px across the 240px slab:
    # Joints at X = 40, 80, 120, 160, 200
    for jx in [40, 80, 120, 160, 200]:
        canvas[0:5, jx] = C_PLAT_DEEP_VOID
        canvas[1:5, jx + 1] = C_PLAT_SPECULAR

    # 4. Coping overhang ledge bevel & drop-shadow (Y = 5, 6)
    canvas[5, 1:W - 1] = C_PLAT_PAVER_MID
    canvas[6, 1:W - 1] = C_PLAT_DEEP_VOID

    # 5. Vertical Platform Body (Y = 7 to 16)
    for y in range(7, 17):
        for x in range(1, W - 1):
            # Subtle vertical masonry texture
            if (x + y) % 8 == 0:
                canvas[y, x] = C_PLAT_STONE_DARK
            elif (x * 2 + y) % 11 == 0:
                canvas[y, x] = C_PLAT_PAVER_MID

    # Mid horizontal chisel groove (Y = 11)
    canvas[11, 1:W - 1] = C_PLAT_DEEP_VOID
    canvas[12, 1:W - 1] = C_PLAT_STONE_DARK

    # 6. Lower Chamfer & Underside Shadow (Y = 17 to 20)
    canvas[17, 1:W - 1] = C_PLAT_STONE_DARK
    canvas[18, 1:W - 1] = C_PLAT_STONE_DARK
    canvas[19, 1:W - 1] = C_PLAT_UNDERSIDE
    canvas[20, 2:W - 2] = C_PLAT_DEEP_VOID

    # Outer left and right perimeter bevels (X = 0 and X = W - 1)
    for y in range(1, 20):
        canvas[y, 0] = C_PLAT_WALK_HI if y < 5 else C_PLAT_STONE_MID
        canvas[y, W - 1] = C_PLAT_STONE_DARK

    # ---------------------------------------------------------------------
    # 7. FORGED BLACK IRON BRACKET ENDCAPS (Left: X: 1..14, Right: X: 225..238)
    # ---------------------------------------------------------------------
    # Left endcap
    for x in range(1, 15):
        # Iron face (Y = 1 to 20)
        canvas[1:21, x] = C_IRON_MID
        # Iron edge highlights
        canvas[1, x] = C_IRON_HI
        canvas[20, x] = C_IRON_DARK
    canvas[1:21, 1] = C_IRON_HI
    canvas[1:21, 14] = C_IRON_DARK

    # Rivets on left endcap (X = 7, Y = 4, 10, 16)
    for ry in [4, 10, 16]:
        canvas[ry, 7] = C_RIVET_SHINE
        canvas[ry + 1, 7] = C_RIVET_SHADOW
        canvas[ry, 6] = C_IRON_HI
        canvas[ry, 8] = C_IRON_DARK

    # Right endcap
    for x in range(225, 239):
        canvas[1:21, x] = C_IRON_MID
        canvas[1, x] = C_IRON_HI
        canvas[20, x] = C_IRON_DARK
    canvas[1:21, 225] = C_IRON_HI
    canvas[1:21, 238] = C_IRON_DARK

    # Rivets on right endcap (X = 232, Y = 4, 10, 16)
    for ry in [4, 10, 16]:
        canvas[ry, 232] = C_RIVET_SHINE
        canvas[ry + 1, 232] = C_RIVET_SHADOW
        canvas[ry, 231] = C_IRON_HI
        canvas[ry, 233] = C_IRON_DARK

    # ---------------------------------------------------------------------
    # 8. ARCHITECTURAL CORBEL BRACKET SUPPORTS (Extending underneath to Y = 23)
    # ---------------------------------------------------------------------
    # Support brackets at:
    # 1. Left end support: X: 4 to 11
    # 2. Corbel 1: X: 57 to 63 (center 60)
    # 3. Corbel 2: X: 117 to 123 (center 120)
    # 4. Corbel 3: X: 177 to 183 (center 180)
    # 5. Right end support: X: 228 to 235

    corbel_specs = [
        (4, 11),
        (57, 63),
        (117, 123),
        (177, 183),
        (228, 235)
    ]

    for (x0, x1) in corbel_specs:
        # Iron vertical reinforcement strap on slab face (Y: 5 to 20)
        strap_w = (x1 - x0)
        cx = (x0 + x1) // 2
        for y in range(5, 21):
            canvas[y, cx - 1:cx + 2] = C_IRON_MID
            canvas[y, cx - 1] = C_IRON_HI
            canvas[y, cx + 1] = C_IRON_DARK
        # Decorative rivet on strap
        canvas[9, cx] = C_RIVET_SHINE
        canvas[10, cx] = C_RIVET_SHADOW

        # Carved stone corbel bracket protruding beneath (Y = 21 to 23)
        # Stepped profile curving inwards
        # Y = 21: Full corbel width
        canvas[21, x0:x1 + 1] = C_CORBEL_MID
        canvas[21, x0] = C_CORBEL_HI
        canvas[21, x1] = C_CORBEL_DARK

        # Y = 22: Inset by 1px on each side
        if x1 - 1 >= x0 + 1:
            canvas[22, x0 + 1:x1] = C_CORBEL_MID
            canvas[22, x0 + 1] = C_CORBEL_HI
            canvas[22, x1 - 1] = C_CORBEL_DARK

        # Y = 23: Inset by 2px (tip of corbel bracket)
        if x1 - 2 >= x0 + 2:
            canvas[23, x0 + 2:x1 - 1] = C_CORBEL_DARK
            canvas[23, x0 + 2] = C_CORBEL_MID

    img = Image.fromarray(canvas, 'RGBA')
    out_path = os.path.join(OUT_DIR, "gothic_castle_platform.png")
    img.save(out_path)
    print("Created:", out_path)


if __name__ == "__main__":
    generate_throne_gothic_floor()
    generate_ramparts_stone_floor()
    generate_gothic_castle_platform()
    print("ALL THRONE ROOM ASSETS GENERATED SUCCESSFULLY!")
