import os
import numpy as np
from PIL import Image

out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "environment", "dungeon"))
os.makedirs(out_dir, exist_ok=True)

# -------------------------------------------------------------------------
# PALETTE (Dark Gothic Wallachian Crypt Stone, Slate, Mortar & Iron Spikes)
# -------------------------------------------------------------------------
# Slate & Ashlar Stone
C_STONE_SPECULAR = [124, 134, 154, 255] # Sharp stone glint / specular corner highlight
C_STONE_HI       = [92, 102, 122, 255]  # Top walkable edge catchlight
C_STONE_LIGHT    = [68, 76, 92, 255]    # Flagstone paver upper face / left bevel
C_STONE_MID      = [48, 54, 66, 255]    # Base dark ashlar masonry body
C_STONE_MID_DARK = [38, 42, 54, 255]    # Slightly darker block variant
C_STONE_DARK     = [28, 32, 40, 255]    # Block shadow / lower bevel
C_STONE_DEEP     = [16, 18, 24, 255]    # Deep chisel groove / stone contour
C_MORTAR         = [10, 11, 15, 255]    # Recessed mortar joint line

# Cracks & Crumbling Mortar (Collapsing Platform)
C_CRACK_VOID     = [6, 7, 10, 255]      # Abyssal structural fault fissure
C_CRACK_DUST     = [104, 98, 86, 255]   # Crumbled limestone / ancient mortar dust
C_CRACK_CHIP     = [140, 146, 160, 255] # Fresh fractured stone chip

# Damp Crypt Crevices
C_MOSS_LIGHT     = [40, 52, 38, 255]    # Subtle dark crypt lichen
C_MOSS_DARK      = [20, 28, 20, 255]    # Shadowed dampness

# Spike Hazard Iron & Stains
C_SPIKE_TIP      = [212, 218, 232, 255] # Sharp forged iron spike tip
C_SPIKE_BODY     = [88, 94, 108, 255]   # Iron spike body
C_SPIKE_DARK     = [40, 44, 52, 255]    # Spike shadow
C_SPIKE_DEEP     = [18, 20, 24, 255]    # Deep iron contour
C_SPIKE_RUST     = [108, 56, 36, 255]   # Encrusted rust
C_SPIKE_BLOOD    = [148, 22, 36, 255]   # Dark dried impalement blood
C_SPIKE_BLOOD_CRUST = [68, 14, 22, 255] # Old crusted blood on base

CLEAR = [0, 0, 0, 0]


def render_block(canvas, x0, y0, x1, y1, is_alt=False):
    """
    Renders an individual 3D ashlar stone block with directional bevel lighting
    (light from top-left, shadow on bottom-right).
    x0, y0: inclusive top-left
    x1, y1: inclusive bottom-right
    """
    base_color = C_STONE_MID_DARK if is_alt else C_STONE_MID

    # Base fill
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            n = np.random.randint(-2, 3)
            canvas[y, x] = [
                np.clip(base_color[0] + n, 15, 230),
                np.clip(base_color[1] + n, 15, 230),
                np.clip(base_color[2] + n, 15, 230),
                255
            ]

    # Top highlight bevel (y0)
    canvas[y0, x0:x1 + 1] = C_STONE_LIGHT
    if x1 - x0 > 4:
        canvas[y0, x0 + 1:x0 + 4] = C_STONE_HI

    # Left highlight bevel (x0)
    canvas[y0:y1 + 1, x0] = C_STONE_LIGHT
    canvas[y0, x0] = C_STONE_HI

    # Bottom shadow bevel (y1)
    canvas[y1, x0:x1 + 1] = C_STONE_DARK

    # Right shadow bevel (x1)
    canvas[y0:y1 + 1, x1] = C_STONE_DARK

    # Subtle stone surface chisel marks
    w = x1 - x0
    h = y1 - y0
    if w >= 12 and h >= 8:
        # Subtle chisel indentation
        cy = y0 + h // 2
        cx = x0 + w // 3
        canvas[cy, cx:cx + 3] = C_STONE_DARK
        canvas[cy + 1, cx:cx + 3] = C_STONE_LIGHT


def generate_stone_ledge():
    """
    Creates dungeon_stone_ledge.png (128x64).
    NinePatch layout:
      patch_margin_left = 24
      patch_margin_top = 16
      patch_margin_right = 24
      patch_margin_bottom = 16
      axis_stretch_horizontal = 1 (TILE)
      axis_stretch_vertical = 1 (TILE)

    The center 80px (X: 24 to 103) tiles horizontally seamlessly.
    The center 32px (Y: 16 to 47) tiles vertically seamlessly.
    """
    W, H = 128, 64
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(520)

    # Fill base mortar color
    canvas[:, :] = C_MORTAR

    # 1. TOP COPING FLAGSTONES (Y: 0 to 6)
    # Coping stones overhang the wall below by 2px, giving strong 3D depth
    # Y = 0: Crisp walkable rim highlight (where character's feet land)
    canvas[0, :] = C_STONE_HI
    for x in range(0, W, 8):
        canvas[0, x:x+3] = C_STONE_SPECULAR

    # Y = 1 to 4: Slate coping pavers
    for y in range(1, 5):
        canvas[y, :] = C_STONE_LIGHT
        # Subtle texture noise on coping face
        for x in range(W):
            if (x + y) % 5 == 0:
                canvas[y, x] = C_STONE_HI
            elif (x * 3 + y) % 7 == 0:
                canvas[y, x] = C_STONE_MID

    # Flagstone paver joints:
    # In center slice (X: 24 to 103), joints at X = 44 and X = 84 (40px rhythm, seamless!)
    # Left margin joint: X = 12
    # Right margin joint: X = 116
    paver_joints = [12, 44, 84, 116]
    for jx in paver_joints:
        canvas[0:5, jx] = C_STONE_DEEP
        canvas[1:5, jx + 1] = C_STONE_SPECULAR # Crisp light catch on paver edge

    # Y = 5: Coping stone lower bevel
    canvas[5, :] = C_STONE_DARK

    # Y = 6: Coping stone deep drop-shadow onto masonry beneath
    canvas[6, :] = C_MORTAR

    # 2. COURSE 0: Top row under coping (Y: 7 to 15, height 9)
    # Blocks of 40px width in center: X: 24..63 and 64..103
    # Left: X: 0..23, Right: X: 104..127
    render_block(canvas, 1, 7, 22, 15, is_alt=True)
    render_block(canvas, 25, 7, 62, 15, is_alt=False)
    render_block(canvas, 65, 7, 102, 15, is_alt=True)
    render_block(canvas, 105, 7, 126, 15, is_alt=False)

    # 3. COURSE A: Repeating Ashlar Row 1 (Y: 17 to 31, height 15)
    # Mortar joint at Y = 16
    canvas[16, :] = C_MORTAR
    # Blocks: 40px blocks
    # Left quoin: X: 1..22
    render_block(canvas, 1, 17, 22, 31, is_alt=False)
    # Center blocks: X: 25..62 and X: 65..102
    render_block(canvas, 25, 17, 62, 31, is_alt=True)
    render_block(canvas, 65, 17, 102, 31, is_alt=False)
    # Right quoin: X: 105..126
    render_block(canvas, 105, 17, 126, 31, is_alt=True)

    # 4. COURSE B: Repeating Ashlar Row 2 (Y: 33 to 47, height 15)
    # Mortar joint at Y = 32
    canvas[32, :] = C_MORTAR
    # Staggered by 20px!
    # Left margin block: X: 1..4
    render_block(canvas, 1, 33, 4, 47, is_alt=True)
    # Quoin block crossing into center: X: 6..42
    render_block(canvas, 6, 33, 42, 47, is_alt=False)
    # Center block: X: 45..82 (width 38 + 2px mortar = 40px!)
    render_block(canvas, 45, 33, 82, 47, is_alt=True)
    # Block crossing from center to right margin: X: 85..122 (width 38)
    render_block(canvas, 85, 33, 122, 47, is_alt=False)
    # Right margin end block: X: 124..126
    render_block(canvas, 124, 33, 126, 47, is_alt=True)

    # 5. COURSE C: Bottom Foundation Course (Y: 49 to 62, height 14)
    # Mortar joint at Y = 48
    canvas[48, :] = C_MORTAR
    # Staggered back to 40px running bond
    render_block(canvas, 1, 49, 22, 62, is_alt=False)
    render_block(canvas, 25, 49, 62, 62, is_alt=True)
    render_block(canvas, 65, 49, 102, 62, is_alt=False)
    render_block(canvas, 105, 49, 126, 62, is_alt=True)

    # Y = 63: Bottom edge shadow
    canvas[63, :] = C_MORTAR

    # 6. ARCHITECTURAL CORNER QUOINS (Left X=0 and Right X=W-1)
    # Left outer boundary
    canvas[:, 0] = C_STONE_DEEP
    canvas[0:5, 0] = C_STONE_SPECULAR # Top-left corner glint
    canvas[6:H-1, 1] = C_STONE_HI     # Left vertical bevel highlight

    # Right outer boundary
    canvas[:, W - 1] = C_STONE_DEEP
    canvas[6:H-1, W - 2] = C_STONE_DARK # Right vertical shadow bevel

    # Alternating Quoin Indentations (giving real castle stepped masonry teeth)
    # Row B (Y: 33..47) quoins are stepped by 2px:
    canvas[32, 0:5] = C_MORTAR
    canvas[48, 0:5] = C_MORTAR

    # 7. DAMP CRYPT LICHEN & AGE ACCENTS
    lichen_spots = [
        (16, 28), (16, 70), (32, 48), (32, 88), (48, 32), (48, 76),
        (25, 12), (42, 44), (56, 64)
    ]
    for ly, lx in lichen_spots:
        canvas[ly, lx] = C_MOSS_LIGHT
        canvas[ly, lx + 1] = C_MOSS_DARK

    return canvas


def generate_collapsing_platform():
    """
    Creates dungeon_platform_collapsing.png (160x20).
    Hand-crafted crumbling gothic slate bridge slab with visible structural fractures,
    chipped edges, loose mortar, and broken ends.
    Walkable surface is at Y=0 (local Y=-10).
    """
    W, H = 160, 20
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(912)

    # 1. Base Stone Body Fill
    canvas[:, :] = C_STONE_MID
    for y in range(H):
        for x in range(W):
            n = np.random.randint(-3, 4)
            canvas[y, x] = [
                np.clip(C_STONE_MID[0] + n, 15, 230),
                np.clip(C_STONE_MID[1] + n, 15, 230),
                np.clip(C_STONE_MID[2] + n, 15, 230),
                255
            ]

    # 2. Coping Flagstone Top Surface (Y: 0 to 5)
    # Y = 0: Top walkable rim highlight
    canvas[0, :] = C_STONE_HI
    for x in range(0, W, 8):
        canvas[0, x:x+3] = C_STONE_SPECULAR

    # Y = 1 to 4: Slate coping pavers
    for y in range(1, 5):
        canvas[y, :] = C_STONE_LIGHT

    # Y = 5: Coping lower bevel
    canvas[5, :] = C_STONE_DARK
    # Y = 6: Coping drop-shadow
    canvas[6, :] = C_MORTAR

    # Y = 7 to 18: Front stone fascia with ashlar block shading
    for y in range(7, 19):
        canvas[y, :] = C_STONE_MID

    # Bottom shadow bevel at Y = 19
    canvas[19, :] = C_MORTAR

    # Sheared stone ends (left and right broken break lines)
    canvas[:, 0] = C_STONE_DEEP
    canvas[1:H-1, 1] = C_STONE_HI
    canvas[:, W-1] = C_STONE_DEEP
    canvas[1:H-1, W-2] = C_STONE_DARK

    # 3. THREE MAJOR STRUCTURAL FAULT LINES / FRACTURES
    # Segment 1: X in [0, 42]
    # Crack 1: around X = 43..45
    # Segment 2: X in [46, 84] (subtly shifted/buckling under stress)
    # Crack 2: around X = 85..87
    # Segment 3: X in [88, 124]
    # Crack 3: around X = 125..127
    # Segment 4: X in [128, 159]

    crack1_coords = [
        (0, 42), (1, 42), (2, 43), (3, 43), (4, 44), (5, 44), (6, 43),
        (7, 43), (8, 44), (9, 44), (10, 45), (11, 45), (12, 44),
        (13, 44), (14, 45), (15, 45), (16, 46), (17, 46), (18, 45), (19, 45)
    ]
    crack2_coords = [
        (0, 86), (1, 86), (2, 85), (3, 85), (4, 84), (5, 84), (6, 85),
        (7, 85), (8, 86), (9, 86), (10, 87), (11, 87), (12, 86),
        (13, 86), (14, 85), (15, 85), (16, 84), (17, 84), (18, 85), (19, 85)
    ]
    crack3_coords = [
        (0, 126), (1, 126), (2, 127), (3, 127), (4, 126), (5, 126), (6, 125),
        (7, 125), (8, 124), (9, 124), (10, 125), (11, 125), (12, 126),
        (13, 126), (14, 127), (15, 127), (16, 126), (17, 126), (18, 125), (19, 125)
    ]

    for crack in [crack1_coords, crack2_coords, crack3_coords]:
        for y, x in crack:
            # 2-pixel wide deep fissure void
            canvas[y, x] = C_CRACK_VOID
            if x + 1 < W:
                canvas[y, x + 1] = C_CRACK_VOID
            # Left edge chipped highlight
            if x - 1 >= 0:
                canvas[y, x - 1] = C_CRACK_CHIP if (y % 3 == 0) else C_STONE_HI
            # Right edge shadow
            if x + 2 < W:
                canvas[y, x + 2] = C_STONE_DARK
            # Mortar dust grains
            if y % 4 == 2 and x - 2 >= 0:
                canvas[y, x - 2] = C_CRACK_DUST

    # 4. Jagged Break Notches on Top Surface (Missing stone teeth)
    # The top surface has visible breaks at each crack:
    for nx in [42, 43, 85, 86, 125, 126]:
        canvas[0, nx] = C_CRACK_VOID
        canvas[1, nx] = C_CRACK_CHIP

    # 5. Middle Sagging / Weakened Section
    # Between crack 1 and crack 2 (X: 45 to 84), the coping stone has sagged down 1px
    # Giving unmistakable visual telegraphing that this bridge is collapsing
    canvas[0, 45:84] = C_STONE_LIGHT
    canvas[1, 45:84] = C_STONE_HI

    # 6. Branch Micro-Fissures on front face
    micro_fissures = [
        (8, 44), (9, 45), (10, 46), (11, 47), (12, 48),
        (13, 84), (14, 83), (15, 82), (16, 81),
        (6, 127), (7, 128), (8, 129), (9, 130)
    ]
    for y, x in micro_fissures:
        if x < W:
            canvas[y, x] = C_CRACK_VOID
            if x + 1 < W:
                canvas[y, x + 1] = C_CRACK_CHIP

    return canvas


def generate_spike_pit():
    """
    Creates dungeon_spike_pit.png (64x32).
    A tileable horizontal band of deadly forged iron spikes, rusty barbs,
    and dark pit trench with execution blood stains.
    Tiles seamlessly at X=0 and X=63.
    """
    W, H = 64, 32
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(612)

    # 1. Base Dark Trench Fill (Y: 16 to 31)
    for y in range(16, H):
        for x in range(W):
            prog = (y - 16.0) / 15.0
            col = [
                int(round(np.clip(18 - prog * 10, 6, 255))),
                int(round(np.clip(14 - prog * 10, 4, 255))),
                int(round(np.clip(22 - prog * 12, 8, 255))),
                255
            ]
            canvas[y, x] = col

    # Socket stone mounting ledge at Y: 16 to 19
    canvas[16, :] = C_STONE_HI
    canvas[17, :] = C_STONE_MID
    canvas[18, :] = C_STONE_DARK

    # 2. Forged Iron Spikes (Thrusting upwards, Y: 0 to 18)
    # Define spikes: (center_x, tip_y, base_width, has_blood)
    spikes = [
        (6, 2, 6, True),   # Tall menacing spike
        (16, 5, 5, False), # Shorter spike
        (26, 1, 7, True),  # Great execution spike
        (37, 4, 5, True),  # Medium spike
        (47, 0, 8, True),  # Colossal central spike
        (58, 3, 6, False), # Right tall spike
    ]

    for sx, tip_y, bw, has_blood in spikes:
        base_y = 17
        height = base_y - tip_y

        for dy in range(height + 1):
            y = tip_y + dy
            p = float(dy) / float(height)
            hw = max(0, int(round((p * bw) / 2.0)))

            for dx in range(-hw, hw + 1):
                x = (sx + dx) % W
                if dx == -hw or dx == hw:
                    canvas[y, x] = C_SPIKE_DEEP # Outer contour
                elif dx < 0:
                    canvas[y, x] = C_SPIKE_TIP if dy < 3 else C_SPIKE_BODY
                elif dx == 0:
                    canvas[y, x] = C_SPIKE_TIP if dy < 2 else C_SPIKE_BODY
                else:
                    canvas[y, x] = C_SPIKE_DARK

            if dy == 0:
                canvas[tip_y, sx % W] = C_SPIKE_TIP

        if has_blood:
            canvas[tip_y + 1, sx % W] = C_SPIKE_BLOOD
            canvas[tip_y + 2, sx % W] = C_SPIKE_BLOOD
            if tip_y + 4 < base_y:
                canvas[tip_y + 3, (sx - 1) % W] = C_SPIKE_BLOOD
                canvas[tip_y + 4, sx % W] = C_SPIKE_BLOOD_CRUST

        canvas[base_y - 2, (sx - 1) % W] = C_SPIKE_RUST
        canvas[base_y - 1, sx % W] = C_SPIKE_RUST
        canvas[base_y - 2, (sx + 1) % W] = C_SPIKE_RUST

    return canvas


def main():
    ledge_img = Image.fromarray(generate_stone_ledge(), mode="RGBA")
    ledge_path = os.path.join(out_dir, "dungeon_stone_ledge.png")
    ledge_img.save(ledge_path)
    print("Saved stone ledge asset:", ledge_path, ledge_img.size)

    plat_img = Image.fromarray(generate_collapsing_platform(), mode="RGBA")
    plat_path = os.path.join(out_dir, "dungeon_platform_collapsing.png")
    plat_img.save(plat_path)
    print("Saved collapsing platform asset:", plat_path, plat_img.size)

    spike_img = Image.fromarray(generate_spike_pit(), mode="RGBA")
    spike_path = os.path.join(out_dir, "dungeon_spike_pit.png")
    spike_img.save(spike_path)
    print("Saved spike pit asset:", spike_path, spike_img.size)


if __name__ == "__main__":
    main()
