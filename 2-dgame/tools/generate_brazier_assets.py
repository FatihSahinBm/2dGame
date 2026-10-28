import os
import numpy as np
from PIL import Image

out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "environment", "dungeon"))
os.makedirs(out_dir, exist_ok=True)

# -------------------------------------------------------------------------
# PALETTE (Dark Wallachian Gothic Forged Iron & Altar Blood Fire)
# -------------------------------------------------------------------------
# Forged Iron
C_IRON_SPECULAR = [148, 158, 178, 255] # Sharp chiseled rim glint
C_IRON_HI       = [112, 122, 140, 255] # Highlight bevel
C_IRON_LIGHT    = [80, 88, 104, 255]   # Upper facing iron
C_IRON_MID      = [52, 58, 70, 255]    # Main iron body
C_IRON_DARK     = [32, 36, 44, 255]    # Shadow bevel
C_IRON_DEEP     = [18, 20, 26, 255]    # Deep contour / crevice
C_MORTAR_DARK   = [12, 13, 16, 255]

# Rust & Ancient Patina
C_RUST_LIGHT    = [132, 70, 44, 255]
C_RUST_DARK     = [84, 40, 24, 255]

# Cold Charcoal & Dead Ash (Unlit Basin)
C_COAL_DEEP     = [14, 15, 18, 255]
C_COAL_MID      = [26, 28, 34, 255]
C_ASH_MID       = [58, 62, 70, 255]
C_ASH_LIGHT     = [88, 94, 104, 255]

# Blood Altar Fire & Embers (Lit State)
C_FIRE_WHITE    = [255, 250, 210, 255] # Incandescent white-gold core
C_FIRE_GOLD     = [255, 210, 60, 255]  # Bright golden flame
C_FIRE_ORANGE   = [255, 125, 28, 255]  # Molten orange body
C_FIRE_RED      = [215, 34, 48, 255]   # Blood crimson flame tongue
C_FIRE_DARK_RED = [140, 18, 32, 230]   # Outer flame contour
C_FIRE_SMOKE    = [60, 16, 24, 140]    # Dissipating blood smoke
C_EMBER_SPARK   = [255, 190, 70, 255]  # Floating incandescent spark

CLEAR = [0, 0, 0, 0]


def generate_brazier_base():
    """
    Creates dungeon_brazier_base.png (32x28).
    Heavy gothic forged-iron brazier pedestal, flared tripod claw feet,
    fluted stem, and wide crenellated iron basin filled with cold dead ash.
    """
    W, H = 32, 28
    canvas = np.zeros((H, W, 4), dtype=np.uint8)

    # 1. TRIPOD CLAW FEET & BASE RING (Y: 18 to 27)
    # Left foot: X in [5, 9] arching down to Y=27
    left_foot = [
        (18, 10), (19, 10), (19, 9), (20, 9), (20, 8),
        (21, 8), (21, 7), (22, 7), (22, 6), (23, 6),
        (24, 6), (25, 5), (26, 5), (26, 6), (27, 5), (27, 6), (27, 7)
    ]
    for y, x in left_foot:
        canvas[y, x] = C_IRON_MID
        if x - 1 >= 0 and canvas[y, x - 1, 3] == 0:
            canvas[y, x - 1] = C_IRON_DEEP
        if x + 1 < W and canvas[y, x + 1, 3] == 0:
            canvas[y, x + 1] = C_IRON_DARK

    # Left foot highlight
    canvas[20:25, 7] = C_IRON_LIGHT
    canvas[26:28, 6] = C_IRON_HI

    # Right foot: X in [22, 26] arching down to Y=27
    right_foot = [
        (18, 21), (19, 21), (19, 22), (20, 22), (20, 23),
        (21, 23), (21, 24), (22, 24), (22, 25), (23, 25),
        (24, 25), (25, 26), (26, 26), (26, 25), (27, 26), (27, 25), (27, 24)
    ]
    for y, x in right_foot:
        canvas[y, x] = C_IRON_DARK
        if x + 1 < W and canvas[y, x + 1, 3] == 0:
            canvas[y, x + 1] = C_IRON_DEEP
        if x - 1 >= 0 and canvas[y, x - 1, 3] == 0:
            canvas[y, x - 1] = C_IRON_MID

    # Rear claw foot (center, slightly recessed at Y: 22..25)
    for y in range(21, 26):
        canvas[y, 15:17] = C_IRON_DARK
    canvas[25, 15:17] = C_IRON_DEEP

    # Central Base Ring / Collar (Y: 18 to 21, width 12: X 10..21)
    for y in range(18, 22):
        canvas[y, 10:22] = C_IRON_MID
        canvas[y, 10] = C_IRON_LIGHT
        canvas[y, 21] = C_IRON_DARK
    canvas[18, 10:22] = C_IRON_HI
    canvas[21, 10:22] = C_IRON_DEEP

    # Base rivets
    canvas[20, 12] = C_IRON_SPECULAR
    canvas[20, 19] = C_IRON_DEEP

    # 2. FLUTED SHAFT & MID-BOSS (Y: 11 to 17)
    # Shaft width 8 px (X: 12 to 19)
    for y in range(11, 18):
        canvas[y, 12:20] = C_IRON_MID
        # Vertical fluting
        canvas[y, 12] = C_IRON_DEEP   # Left outer contour
        canvas[y, 13] = C_IRON_HI     # Left ridge highlight
        canvas[y, 14] = C_IRON_MID    # Left groove
        canvas[y, 15] = C_IRON_LIGHT  # Center ridge
        canvas[y, 16] = C_IRON_MID    # Center groove
        canvas[y, 17] = C_IRON_DARK   # Right ridge shadow
        canvas[y, 18] = C_IRON_DEEP   # Right groove
        canvas[y, 19] = C_IRON_DEEP   # Right outer contour

    # Mid-shaft boss ring (Y: 14..15, width 10: X 11..20)
    canvas[14, 11:21] = C_IRON_HI
    canvas[15, 11:21] = C_IRON_DARK
    canvas[14, 11] = C_IRON_SPECULAR
    canvas[15, 20] = C_IRON_DEEP

    # 3. BOWL SUPPORT BRACKETS (Y: 9 to 11)
    # Flaring out from shaft (X: 12..19) to bowl base (X: 8..23)
    for y in range(9, 12):
        w_spread = (11 - y) * 3
        canvas[y, 12 - w_spread: 20 + w_spread] = C_IRON_MID
        canvas[y, 12 - w_spread] = C_IRON_LIGHT
        canvas[y, 19 + w_spread] = C_IRON_DARK

    # 4. GOTHIC IRON BASIN / BOWL (Y: 3 to 9)
    # Flaring bowl outer envelope
    bowl_rows = [
        (9, 6, 25),
        (8, 5, 26),
        (7, 4, 27),
        (6, 3, 28),
        (5, 3, 28),
        (4, 3, 28),
        (3, 4, 27)
    ]
    for y, x0, x1 in bowl_rows:
        canvas[y, x0:x1 + 1] = C_IRON_MID
        canvas[y, x0] = C_IRON_DEEP
        canvas[y, x1] = C_IRON_DEEP
        canvas[y, x0 + 1] = C_IRON_LIGHT
        canvas[y, x1 - 1] = C_IRON_DARK

    # Bowl bottom shadow bevel at Y=9
    canvas[9, 6:26] = C_IRON_DARK

    # Bowl center front fascia highlight at Y=6..7
    canvas[6, 5:15] = C_IRON_LIGHT
    canvas[6, 8:12] = C_IRON_HI

    # Iron bowl rim band at Y=4..5
    canvas[4, 4:28] = C_IRON_LIGHT
    canvas[4, 4] = C_IRON_SPECULAR
    canvas[4, 27] = C_IRON_DARK
    canvas[5, 4:28] = C_IRON_MID
    canvas[5, 27] = C_IRON_DEEP

    # Gothic Crenellated Rim Teeth (Y: 2 to 3)
    # Teeth at X = 4..5, 9..10, 15..16, 21..22, 26..27
    teeth = [4, 9, 15, 21, 26]
    for tx in teeth:
        canvas[2, tx:tx + 2] = C_IRON_HI
        canvas[2, tx] = C_IRON_SPECULAR
        canvas[3, tx:tx + 2] = C_IRON_LIGHT
        canvas[1, tx:tx + 2] = C_IRON_SPECULAR if tx <= 15 else C_IRON_HI

    # 5. COLD ASH & CHARCOAL BED (Y: 3 to 6, inside the bowl between teeth)
    # Hollow interior
    for y in range(3, 6):
        canvas[y, 6:26] = C_COAL_DEEP
    for x in range(7, 25):
        if x % 3 == 0:
            canvas[4, x] = C_COAL_MID
            canvas[5, x] = C_COAL_DEEP
        elif x % 4 == 1:
            canvas[3, x] = C_ASH_MID
            canvas[4, x] = C_ASH_LIGHT
        elif x % 5 == 2:
            canvas[4, x] = C_ASH_MID
            canvas[5, x] = C_COAL_MID

    # Ash flakes & dead coal bumps
    canvas[3, 8] = C_ASH_LIGHT
    canvas[3, 13] = C_ASH_MID
    canvas[3, 18] = C_ASH_LIGHT
    canvas[3, 23] = C_ASH_MID
    canvas[4, 11] = C_COAL_MID
    canvas[4, 16] = C_COAL_MID
    canvas[4, 20] = C_COAL_MID

    # Subtle rust accents on iron joints
    canvas[10, 8] = C_RUST_LIGHT
    canvas[10, 23] = C_RUST_DARK
    canvas[23, 6] = C_RUST_LIGHT
    canvas[24, 25] = C_RUST_DARK

    return canvas


def generate_flame_frame(frame_idx):
    """
    Generates an individual 24x24 pixel-art flame frame (frame_idx in [0, 1, 2, 3]).
    Designed to sit nestled in the brazier basin at local position (0, -18).
    Bottom rows (Y: 17..23) form the hot glowing ember bed resting inside the iron bowl.
    Upper rows (Y: 2..16) form stylized, undulating blood fire tongues with rising sparks.
    """
    W, H = 24, 24
    canvas = np.zeros((H, W, 4), dtype=np.uint8)

    # 1. GLOWING EMBER BASE (Y: 17 to 23, width 18: X 3..20)
    for y in range(17, 23):
        for x in range(4, 20):
            dist_c = abs(x - 11.5)
            if dist_c < 4.0:
                canvas[y, x] = C_FIRE_GOLD if (y < 20) else C_FIRE_ORANGE
            elif dist_c < 7.0:
                canvas[y, x] = C_FIRE_ORANGE if (y < 20) else C_FIRE_RED
            else:
                canvas[y, x] = C_FIRE_RED if (y < 21) else C_FIRE_DARK_RED

    # Inner intense incandescent heart
    canvas[18:20, 10:14] = C_FIRE_WHITE
    canvas[17:21, 11:13] = C_FIRE_WHITE

    # 2. DANCING FLAME TONGUES (4 procedural animation frames)
    # Define primary flame tongues per frame
    if frame_idx == 0:
        # Central tall tongue leaning slightly left, secondary tongue right
        tongues = [
            # (center_x, top_y, base_y, width)
            (11, 4, 18, 7),  # Main flame
            (15, 7, 18, 5),  # Right flame
            (7, 10, 18, 4),  # Left flame
        ]
        sparks = [(10, 2), (16, 5), (6, 7)]
    elif frame_idx == 1:
        # Flame surges upwards, central crest peaks higher
        tongues = [
            (12, 3, 18, 8),  # Central roaring tongue
            (16, 9, 18, 4),  # Right tongue subsiding
            (8, 8, 18, 5),   # Left tongue rising
        ]
        sparks = [(12, 1), (7, 5), (17, 4)]
    elif frame_idx == 2:
        # Flame curls slightly right, sparks detach
        tongues = [
            (13, 4, 18, 7),  # Main flame crest leaning right
            (8, 7, 18, 5),   # Left flame body
            (17, 10, 18, 4), # Right flame flick
        ]
        sparks = [(14, 2), (8, 4), (18, 7)]
    else: # frame_idx == 3:
        # Lower trough before surging, wider licking edges
        tongues = [
            (11, 5, 18, 8),  # Broad central flame
            (7, 9, 18, 5),   # Left tongue
            (15, 8, 18, 5),  # Right tongue
        ]
        sparks = [(11, 3), (15, 4), (6, 6)]

    # Draw each tongue with layered flame colors (White core -> Gold -> Orange -> Red -> Dark Red)
    for cx, ty, by, w in tongues:
        height = by - ty
        for dy in range(height + 1):
            y = ty + dy
            prog = float(dy) / float(height) # 0.0 at tip, 1.0 at base
            hw = max(0.5, (prog * (w / 2.0)))
            ihw = int(round(hw))

            for dx in range(-ihw, ihw + 1):
                x = cx + dx
                if 0 <= x < W and 0 <= y < H:
                    dist = abs(dx) / (hw + 0.01)
                    if dist < 0.25 and dy > height * 0.4:
                        col = C_FIRE_WHITE
                    elif dist < 0.5:
                        col = C_FIRE_GOLD
                    elif dist < 0.75:
                        col = C_FIRE_ORANGE
                    elif dist < 0.95:
                        col = C_FIRE_RED
                    else:
                        col = C_FIRE_DARK_RED

                    # If pixel is already brighter, don't overwrite with darker
                    if canvas[y, x, 3] == 0 or col[0] > canvas[y, x, 0]:
                        canvas[y, x] = col

    # Floating incandescent spark pixels
    for sx, sy in sparks:
        if 0 <= sx < W and 0 <= sy < H:
            canvas[sy, sx] = C_EMBER_SPARK
            if sy + 1 < H and canvas[sy + 1, sx, 3] == 0:
                canvas[sy + 1, sx] = C_FIRE_DARK_RED

    return canvas


def main():
    base_img = Image.fromarray(generate_brazier_base(), mode="RGBA")
    base_path = os.path.join(out_dir, "dungeon_brazier_base.png")
    base_img.save(base_path)
    print("Saved brazier base asset:", base_path, base_img.size)

    for i in range(4):
        flame_img = Image.fromarray(generate_flame_frame(i), mode="RGBA")
        flame_path = os.path.join(out_dir, f"dungeon_brazier_fire_{i+1}.png")
        flame_img.save(flame_path)
        print(f"Saved brazier flame frame {i+1}:", flame_path, flame_img.size)


if __name__ == "__main__":
    main()
