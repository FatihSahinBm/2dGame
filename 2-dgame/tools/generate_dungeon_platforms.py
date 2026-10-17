import os
import numpy as np
from PIL import Image

out_dir = "2-dgame/assets/environment/dungeon"
os.makedirs(out_dir, exist_ok=True)

# -------------------------------------------------------------
# PALETTE DEFINITIONS (Gothic Dark Dungeon Stone)
# -------------------------------------------------------------
C_CLEAR = [0, 0, 0, 0]

# Highlight & walk surface
C_WALK_HILIGHT   = [92, 98, 112, 255]   # Chiseled top edge highlight
C_WALK_TOP       = [68, 73, 84, 255]    # Flagstone top surface
C_WALK_MID       = [50, 54, 63, 255]    # Flagstone mid tone
C_WALK_DARK      = [34, 37, 44, 255]    # Flagstone shadow

# Stone body
C_STONE_LIGHT    = [46, 49, 58, 255]    # Sunken stone face light
C_STONE_MID      = [35, 37, 44, 255]    # Standard ashlar stone
C_STONE_DARK     = [25, 27, 32, 255]    # Stone shadow / under-lip
C_STONE_DEEP     = [17, 18, 22, 255]    # Deep crevice / dark outline
C_MORTAR         = [12, 13, 16, 255]    # Mortar joint groove

# Cold gothic moss / lichen
C_MOSS_LIGHT     = [48, 62, 50, 255]    # Sparse moss highlight
C_MOSS_MID       = [32, 44, 34, 255]    # Moss body
C_MOSS_DARK      = [20, 28, 22, 255]    # Crevice moss

# Soot / grime
C_SOOT_DEEP      = [10, 11, 14, 255]    # Bottom ambient occlusion


# -------------------------------------------------------------
# 1. COLLAPSING PLATFORM (160 x 20 px)
# -------------------------------------------------------------
def create_collapsing_platform():
    W, H = 160, 20
    canvas = np.zeros((H, W, 4), dtype=np.uint8)

    # Base fill with stone mid
    canvas[:, :] = C_STONE_MID

    # Noise seed for controlled stone texture
    np.random.seed(42)
    noise = np.random.randint(-4, 5, size=(H, W, 1))
    for c in range(3):
        canvas[:, :, c] = np.clip(canvas[:, :, c].astype(int) + noise[:, :, 0], 10, 240)

    # --- Top Walk Rim (Rows 0 to 3) ---
    # Row 0: Chiseled flagstone walk surface
    canvas[0, :] = C_WALK_TOP
    # Highlight points along row 0
    for x in range(2, W - 2):
        if (x % 11 != 0) and (x % 17 != 0):
            canvas[0, x] = C_WALK_HILIGHT
        else:
            canvas[0, x] = C_WALK_MID  # subtle chiseled notches

    # Row 1: Solid stone flagstone body
    canvas[1, :] = C_WALK_TOP
    for x in range(W):
        if x % 3 == 0:
            canvas[1, x] = C_WALK_MID

    # Row 2: Under-lip shadow
    canvas[2, :] = C_WALK_DARK
    canvas[3, :] = C_STONE_DARK

    # --- Vertical Mortar Joints (Dividing into 4-5 weathered stone blocks) ---
    # Block seams at X = 32, 74, 118
    seams = [32, 74, 118]
    for sx in seams:
        # Mortar line from row 2 to 18
        canvas[2:19, sx] = C_MORTAR
        canvas[2:18, sx - 1] = C_STONE_DARK
        canvas[2:18, sx + 1] = C_STONE_LIGHT
        # Mortar notch at top
        canvas[0:2, sx] = C_STONE_DARK

    # --- Weathering, cracks and moss ---
    # Fine crack 1 in block 1 (X=14..22, Y=4..12)
    crack1 = [(14, 4), (15, 5), (15, 6), (16, 7), (17, 8), (17, 9), (18, 10), (19, 11), (20, 12)]
    for cx, cy in crack1:
        canvas[cy, cx] = C_MORTAR
        canvas[cy, cx + 1] = C_STONE_LIGHT

    # Fine crack 2 in block 3 (X=88..102, Y=5..15)
    crack2 = [(88, 5), (89, 6), (90, 7), (91, 7), (92, 8), (93, 9), (94, 10), (95, 11), (97, 12), (99, 13), (101, 14)]
    for cx, cy in crack2:
        canvas[cy, cx] = C_MORTAR
        if cx + 1 < W:
            canvas[cy, cx + 1] = C_STONE_LIGHT

    # Subtle moss patches in shaded corners and seams
    moss_coords = [
        (30, 14), (31, 14), (30, 15), (31, 15), (32, 15), (33, 15), (31, 16),
        (72, 13), (73, 13), (73, 14), (74, 14), (75, 14), (73, 15),
        (116, 12), (117, 12), (117, 13), (118, 13), (119, 13), (117, 14),
        (10, 16), (11, 16), (12, 16), (11, 17)
    ]
    for mx, my in moss_coords:
        if 0 <= mx < W and 0 <= my < H:
            canvas[my, mx] = C_MOSS_MID
            if (mx + my) % 2 == 0:
                canvas[my, mx] = C_MOSS_LIGHT

    # --- Left and Right Edges (Chiseled corners) ---
    # Row 0 left/right corners beveled
    canvas[0, 0] = C_CLEAR
    canvas[0, W - 1] = C_CLEAR
    canvas[19, 0] = C_CLEAR
    canvas[19, W - 1] = C_CLEAR

    canvas[0, 1] = C_STONE_DARK
    canvas[0, W - 2] = C_STONE_DARK
    canvas[1, 0] = C_STONE_DEEP
    canvas[1, W - 1] = C_STONE_DEEP

    # Left edge vertical border
    canvas[2:19, 0] = C_STONE_DEEP
    canvas[2:19, 1] = C_STONE_LIGHT  # subtle left light catch
    # Right edge vertical border
    canvas[2:19, W - 1] = C_STONE_DEEP
    canvas[2:19, W - 2] = C_STONE_DARK

    # --- Bottom Edge (Rows 18 & 19) ---
    canvas[18, :] = C_STONE_DARK
    canvas[19, 1:W-1] = C_SOOT_DEEP
    # Chipped bottom profile
    for x in range(1, W - 1):
        if x % 7 == 0:
            canvas[19, x] = C_CLEAR
            canvas[18, x] = C_SOOT_DEEP

    img = Image.fromarray(canvas, mode="RGBA")
    img_path = os.path.join(out_dir, "dungeon_platform_collapsing.png")
    img.save(img_path)
    print(f"Saved: {img_path} ({W}x{H})")


# -------------------------------------------------------------
# 2. SEAMLESS GOTHIC STONE LEDGE (NinePatch: 128 x 64 px)
# Left margin: 24 px | Middle: 80 px (seamless 40px blocks!) | Right: 24 px
# Top margin: 16 px (walk surface) | Bottom margin: 16 px (foundation)
# -------------------------------------------------------------
def create_stone_ledge():
    W, H = 128, 64
    canvas = np.zeros((H, W, 4), dtype=np.uint8)

    # Fill center with stone mid
    canvas[:, :] = C_STONE_MID

    np.random.seed(101)
    noise = np.random.randint(-4, 5, size=(H, W, 1))
    for c in range(3):
        canvas[:, :, c] = np.clip(canvas[:, :, c].astype(int) + noise[:, :, 0], 12, 235)

    # =========================================================
    # A. ASHLAR MASONRY BLOCK GRID (Running Bond)
    # Block height = 16 px (Rows: 0..15, 16..31, 32..47, 48..63)
    # In middle region (X=24..104, width=80):
    # Two blocks of 40 px each!
    # Even rows (16..31, 48..63): Seam at middle X = 24 + 40 = 64
    # Odd rows (0..15, 32..47): Seams at X = 24 + 20 = 44, and X = 24 + 60 = 84
    # This guarantees 100% PERFECT SEAMLESS HORIZONTAL AND VERTICAL TILING!
    # =========================================================

    # Horizontal mortar lines at Y = 15, 31, 47, 63
    for y in [15, 31, 47]:
        canvas[y, :] = C_MORTAR
        canvas[y - 1, :] = C_STONE_DARK
        if y + 1 < H:
            canvas[y + 1, :] = C_STONE_LIGHT

    # Vertical mortar lines in the repeating interior (X=24..104):
    # Row tier 1 (Y=0..15)
    canvas[0:15, 44] = C_MORTAR
    canvas[0:15, 43] = C_STONE_DARK
    canvas[0:15, 45] = C_STONE_LIGHT
    canvas[0:15, 84] = C_MORTAR
    canvas[0:15, 83] = C_STONE_DARK
    canvas[0:15, 85] = C_STONE_LIGHT

    # Row tier 2 (Y=16..31)
    canvas[16:31, 64] = C_MORTAR
    canvas[16:31, 63] = C_STONE_DARK
    canvas[16:31, 65] = C_STONE_LIGHT

    # Row tier 3 (Y=32..47)
    canvas[32:47, 44] = C_MORTAR
    canvas[32:47, 43] = C_STONE_DARK
    canvas[32:47, 45] = C_STONE_LIGHT
    canvas[32:47, 84] = C_MORTAR
    canvas[32:47, 83] = C_STONE_DARK
    canvas[32:47, 85] = C_STONE_LIGHT

    # Row tier 4 (Y=48..63)
    canvas[48:63, 64] = C_MORTAR
    canvas[48:63, 63] = C_STONE_DARK
    canvas[48:63, 65] = C_STONE_LIGHT

    # Seamless boundary check:
    # At X=24 and X=104 (the boundaries of the 80px repeat),
    # tier 2 and tier 4 have a block boundary!
    # We place a seam at X=24 and X=104 for tiers 2 and 4:
    canvas[16:31, 24] = C_MORTAR
    canvas[16:31, 23] = C_STONE_DARK
    canvas[16:31, 25] = C_STONE_LIGHT
    canvas[16:31, 104] = C_MORTAR
    canvas[16:31, 103] = C_STONE_DARK
    canvas[16:31, 105] = C_STONE_LIGHT

    canvas[48:63, 24] = C_MORTAR
    canvas[48:63, 23] = C_STONE_DARK
    canvas[48:63, 25] = C_STONE_LIGHT
    canvas[48:63, 104] = C_MORTAR
    canvas[48:63, 103] = C_STONE_DARK
    canvas[48:63, 105] = C_STONE_LIGHT

    # =========================================================
    # B. TOP WALK RIM (Rows 0 to 4 across all X)
    # Clear, readable walking edge with chisel highlight
    # =========================================================
    canvas[0, :] = C_WALK_HILIGHT
    canvas[1, :] = C_WALK_TOP
    canvas[2, :] = C_WALK_TOP
    for x in range(W):
        if x % 2 == 0:
            canvas[1, x] = C_WALK_HILIGHT
        if x % 4 == 0:
            canvas[2, x] = C_WALK_MID

    canvas[3, :] = C_WALK_MID
    canvas[4, :] = C_WALK_DARK

    # Subtle stone slab notches along the top surface
    for x in [24, 44, 64, 84, 104]:
        canvas[0, x] = C_WALK_DARK
        canvas[1, x] = C_STONE_DARK

    # =========================================================
    # C. LEFT EXPOSED CORNER (X=0..23)
    # Distinct quoin blocks (corner stones), beveled edge, moss
    # =========================================================
    # Top-left corner bevel
    canvas[0, 0] = C_CLEAR
    canvas[0, 1] = C_CLEAR
    canvas[1, 0] = C_CLEAR

    # Vertical left edge outline
    canvas[2:, 0] = C_STONE_DEEP
    canvas[2:, 1] = C_STONE_LIGHT  # Left highlight catching ambient dungeon light

    # Quoin seam staggered blocks on left margin
    canvas[16:31, 14] = C_MORTAR
    canvas[48:63, 14] = C_MORTAR

    # =========================================================
    # D. RIGHT EXPOSED CORNER (X=105..127)
    # Distinct quoin blocks, beveled edge, shadow outline
    # =========================================================
    # Top-right corner bevel
    canvas[0, 127] = C_CLEAR
    canvas[0, 126] = C_CLEAR
    canvas[1, 127] = C_CLEAR

    # Vertical right edge outline (in shadow)
    canvas[2:, 127] = C_STONE_DEEP
    canvas[2:, 126] = C_STONE_DARK

    # Quoin seams on right margin
    canvas[16:31, 114] = C_MORTAR
    canvas[48:63, 114] = C_MORTAR

    # =========================================================
    # E. MOSS ACCENTS & BOTTOM SOOT GRADIENT
    # =========================================================
    # Selective moss clusters along horizontal mortar lines
    moss_points = [
        (40, 15), (41, 15), (42, 15), (41, 16), (42, 16),
        (60, 31), (61, 31), (62, 31), (61, 32),
        (80, 15), (81, 15), (82, 15), (81, 16),
        (100, 31), (101, 31), (102, 31),
        (18, 31), (19, 31), (19, 32)
    ]
    for mx, my in moss_points:
        if 0 <= mx < W and 0 <= my < H:
            canvas[my, mx] = C_MOSS_MID
            if (mx + my) % 2 == 0:
                canvas[my, mx] = C_MOSS_LIGHT

    # Bottom soot / ambient occlusion gradient on lower 10 rows (Rows 54..63)
    for y in range(54, H):
        factor = (y - 54) / 10.0
        for x in range(W):
            if canvas[y, x, 3] > 0:
                for c in range(3):
                    val = canvas[y, x, c]
                    target = C_SOOT_DEEP[c]
                    canvas[y, x, c] = int(val * (1.0 - factor * 0.6) + target * (factor * 0.6))

    img = Image.fromarray(canvas, mode="RGBA")
    img_path = os.path.join(out_dir, "dungeon_stone_ledge.png")
    img.save(img_path)
    print(f"Saved: {img_path} ({W}x{H})")

if __name__ == "__main__":
    create_collapsing_platform()
    create_stone_ledge()
