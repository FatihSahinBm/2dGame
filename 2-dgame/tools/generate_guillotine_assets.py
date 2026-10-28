import os
import numpy as np
from PIL import Image

out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "environment", "dungeon"))
os.makedirs(out_dir, exist_ok=True)

# -------------------------------------------------------------------------
# PALETTE (Dark Gothic Wallachian Dungeon Iron, Honed Steel, Rust & Blood)
# -------------------------------------------------------------------------
C_EDGE_GLINT   = [235, 240, 250, 255] # Razor-sharp steel glint
C_STEEL_HI     = [190, 198, 214, 255] # Cold honed bevel highlight
C_STEEL_MID    = [140, 148, 166, 255] # Honed steel face
C_STEEL_DARK   = [92, 100, 116, 255]  # Bevel shadow transition

C_IRON_HI      = [112, 120, 136, 255] # Forged iron upper rim
C_IRON_LIGHT   = [82, 88, 102, 255]   # Wrought iron face
C_IRON_MID     = [54, 58, 70, 255]    # Heavy dark iron body
C_IRON_DARK    = [34, 38, 48, 255]    # Iron shadow
C_IRON_DEEP    = [18, 20, 26, 255]    # Black iron outline / crease

C_RUST_HI      = [128, 76, 48, 255]   # Surface rust crust
C_RUST_MID     = [88, 50, 34, 255]    # Pitted oxidation
C_RUST_DARK    = [54, 30, 22, 255]    # Seam rust

C_BLOOD_FRESH  = [172, 26, 40, 255]   # Crimson razor blood streak
C_BLOOD_DRIED  = [98, 18, 26, 255]    # Dried coagulated blood
C_BLOOD_CRUST  = [58, 12, 18, 255]    # Old dark crusted stain

C_BRONZE_HI    = [172, 146, 92, 255]  # Bronze rivet highlight
C_BRONZE_MID   = [122, 96, 58, 255]   # Bronze rivet body
C_BRONZE_DARK  = [66, 50, 30, 255]    # Bronze rivet shadow

CLEAR = [0, 0, 0, 0]


def generate_blade():
    """
    Creates guillotine_blade.png (64x68).
    Center is X=32.
    Y=0 in local coordinates is Y=26 in canvas.
    Collar: Y in canvas [2, 14] -> local [-24, -12].
    Wings: Y in canvas 44 -> local +18, X in canvas [4, 59] -> local [-28, +27].
    Lethal tip: Y in canvas 64 -> local +38, X in canvas [31..33].
    """
    W, H = 64, 68
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(888)

    cx = 32
    # Y-offset: y_canvas = y_local + 26
    # y_local = y_canvas - 26

    # 1. Precise Pixel-Art Curve Map for the Blade Profile
    # Left wing starts at x_local = -28, y_local = 18 (x=4, y=44)
    # Right wing starts at x_local = +28, y_local = 18 (x=60, y=44)
    # Bottom tip at x_local = 0, y_local = 38 (x=32, y=64)

    # Stair-stepped crescent bottom curve from dx=28 down to dx=0:
    crescent_curve = [
        # dx, dy_local
        (28, 18), (27, 19), (26, 20), (25, 21), (24, 22), (23, 23),
        (22, 24), (21, 25), (20, 26), (19, 27), (18, 28), (17, 29),
        (16, 30), (15, 31), (14, 32), (13, 32), (12, 33), (11, 33),
        (10, 34), (9, 34),  (8, 35),  (7, 35),  (6, 36),  (5, 36),
        (4, 37),  (3, 37),  (2, 37),  (1, 38),  (0, 38)
    ]

    # Upper flare from collar (y_local=-12, dx=18) to wing (y_local=18, dx=28)
    # 30 vertical pixels, expanding from dx=18 to dx=28:
    flare_curve = {}
    for y_loc in range(-12, 19):
        p = (y_loc - (-12)) / 30.0
        # Gentle flare outward
        dx = int(round(18.0 + p * 10.0))
        flare_curve[y_loc] = dx

    # Bottom curve map by y_local:
    bottom_curve_by_y = {}
    for dx, y_loc in crescent_curve:
        if y_loc not in bottom_curve_by_y:
            bottom_curve_by_y[y_loc] = []
        bottom_curve_by_y[y_loc].append(dx)

    # 2. Build Solid Mask
    blade_mask = np.zeros((H, W), dtype=bool)

    # Collar: y_local from -24 to -12 (y_canvas: 2 to 14), x_local in [-24, 24] (x_canvas: 8 to 56)
    for y_can in range(2, 15):
        blade_mask[y_can, cx - 25:cx + 26] = True

    # Main blade body: y_local from -12 to 38
    for y_loc in range(-12, 39):
        y_can = y_loc + 26
        if y_loc <= 18:
            dx = flare_curve[y_loc]
            blade_mask[y_can, cx - dx:cx + dx + 1] = True
        else:
            # Below wings: bottom crescent boundary
            # Find max dx for this y_loc
            valid_dx = [dx for dx, yl in crescent_curve if yl >= y_loc]
            if valid_dx:
                dx = max(valid_dx)
                blade_mask[y_can, cx - dx:cx + dx + 1] = True

    # 3. Base Iron Fill with Grain & Subtle Texture
    for y in range(H):
        for x in range(W):
            if blade_mask[y, x]:
                noise = np.random.randint(-3, 4)
                # Subtle vertical iron forge grain
                grain = 2 if (x % 4 == 0) else 0
                canvas[y, x] = [
                    np.clip(C_IRON_MID[0] + noise + grain, 20, 240),
                    np.clip(C_IRON_MID[1] + noise + grain, 20, 240),
                    np.clip(C_IRON_MID[2] + noise + grain, 20, 240),
                    255
                ]

    # 4. Top Mount Collar (y_canvas: 2 to 14, x_canvas: 7 to 57)
    # Heavy wrought-iron clamping collar with reinforced bolted flange
    # Top edge bevel
    canvas[2, cx - 24:cx + 25] = C_IRON_HI
    canvas[3, cx - 24:cx + 25] = C_IRON_LIGHT
    # Left & right collar edges
    canvas[2:15, cx - 25] = C_IRON_DEEP
    canvas[2:15, cx + 25] = C_IRON_DEEP
    canvas[3:14, cx - 24] = C_IRON_HI
    canvas[3:14, cx + 24] = C_IRON_DARK

    # Chain clevis bracket at top center (x: cx-4..cx+4, y: 0..4)
    canvas[0:3, cx - 4:cx + 5] = C_IRON_MID
    canvas[0, cx - 4:cx + 5] = C_IRON_HI
    canvas[0:3, cx - 4] = C_IRON_HI
    canvas[0:3, cx + 4] = C_IRON_DEEP
    # Shackle pin rivet
    canvas[1:3, cx - 1:cx + 2] = C_BRONZE_MID
    canvas[1, cx] = C_BRONZE_HI

    # Collar bottom lip / reinforced step (y_canvas: 13 to 14)
    canvas[13, cx - 25:cx + 26] = C_IRON_DEEP
    canvas[14, cx - 25:cx + 26] = C_IRON_HI # Catchlight below step

    # 4 Heavy Bronze Clamp Rivets on Collar
    rivet_x_offsets = [-18, -9, 9, 18]
    for rx in rivet_x_offsets:
        x = cx + rx
        canvas[7:10, x - 1:x + 2] = C_BRONZE_DARK
        canvas[8, x] = C_BRONZE_MID
        canvas[7, x] = C_BRONZE_HI

    # 5. Central Fuller / Blood Channel (y_canvas: 16 to 48, width: 4px)
    for y in range(16, 48):
        canvas[y, cx - 3] = C_IRON_HI # Left specular ridge
        canvas[y, cx - 2:cx + 2] = C_IRON_DEEP # Deep hollow channel
        canvas[y, cx + 2] = C_IRON_DARK # Right shadow ridge
        # Dried blood coagulated in the bottom of the channel
        if y > 26 and (y % 4 != 0):
            canvas[y, cx - 1:cx + 1] = C_BLOOD_DRIED

    # 6. Outer Contours & Shading for Wings (y_canvas: 14 to 44)
    for y_loc in range(-12, 19):
        y_can = y_loc + 26
        dx = flare_curve[y_loc]
        # Left edge
        canvas[y_can, cx - dx] = C_IRON_DEEP
        canvas[y_can, cx - dx + 1] = C_IRON_HI
        canvas[y_can, cx - dx + 2] = C_IRON_LIGHT
        # Right edge
        canvas[y_can, cx + dx] = C_IRON_DEEP
        canvas[y_can, cx + dx - 1] = C_IRON_DARK

    # Wing tips at y_canvas = 44 (y_local = 18):
    canvas[44, cx - 28:cx - 26] = C_STEEL_HI
    canvas[44, cx + 26:cx + 28] = C_STEEL_MID

    # 7. Razor Bevel & Curved Cutting Edge (y_canvas: 44 to 64)
    # Follow the crescent curve stair-steps cleanly
    for dx, y_loc in crescent_curve:
        y_can = y_loc + 26
        lx = cx - dx
        rx = cx + dx

        # Outer dark contour
        canvas[y_can, lx] = C_IRON_DEEP
        canvas[y_can, rx] = C_IRON_DEEP

        # Left cutting bevel (glinting in the light)
        if dx > 0:
            canvas[y_can, lx + 1] = C_EDGE_GLINT
            canvas[y_can, lx + 2] = C_STEEL_HI
            canvas[y_can, lx + 3] = C_STEEL_MID
            if dx > 6:
                canvas[y_can, lx + 4] = C_STEEL_DARK

            # Right cutting bevel
            canvas[y_can, rx - 1] = C_STEEL_MID
            canvas[y_can, rx - 2] = C_STEEL_DARK
            if dx > 6:
                canvas[y_can, rx - 3] = C_IRON_DARK

    # Bottom Lethal Tip (y_canvas: 63 to 65, x_canvas: 31..33)
    canvas[63, cx - 1:cx + 2] = C_EDGE_GLINT
    canvas[64, cx] = C_EDGE_GLINT
    canvas[65, cx] = C_IRON_DEEP # Crisp bottom pixel

    # 8. Dark Gothic Weathering: Rust Pits & Executioner Bloodstains
    # Surface Rust
    rust_coords = [
        (10, cx - 14), (11, cx - 14), (11, cx - 13),
        (8, cx + 13), (9, cx + 14), (10, cx + 13),
        (15, cx - 18), (16, cx - 17), (20, cx - 19),
        (22, cx + 16), (23, cx + 17), (24, cx + 16),
        (30, cx - 12), (31, cx - 11), (34, cx + 10)
    ]
    for ry, rx in rust_coords:
        if blade_mask[ry, rx]:
            canvas[ry, rx] = C_RUST_MID
            if blade_mask[ry + 1, rx]:
                canvas[ry + 1, rx] = C_RUST_DARK

    # Dried execution blood along the lower flat & fresh streaks near razor edge
    blood_coords = [
        # Dried smears on the face
        (48, cx - 12), (49, cx - 11), (50, cx - 10), (51, cx - 9),
        (52, cx - 8), (53, cx - 7), (54, cx - 6), (55, cx - 5),
        (46, cx + 14), (47, cx + 13), (48, cx + 13), (50, cx + 9),
        (52, cx + 7), (53, cx + 6), (54, cx + 5), (55, cx + 4),
        (56, cx - 2), (57, cx - 1), (58, cx), (59, cx + 1),
        # Crimson streaks close to cutting edge
        (56, cx - 8), (57, cx - 7), (58, cx - 6), (59, cx - 5),
        (58, cx + 4), (59, cx + 3), (60, cx + 2), (61, cx + 1),
        (62, cx), (63, cx)
    ]
    for by, bx in blood_coords:
        if blade_mask[by, bx]:
            if by >= 56:
                canvas[by, bx] = C_BLOOD_FRESH
            else:
                canvas[by, bx] = C_BLOOD_DRIED

    # Ensure tip has a deadly crimson drop
    canvas[62, cx - 1:cx + 2] = C_BLOOD_FRESH
    canvas[63, cx] = C_BLOOD_FRESH

    # Clean transparent border around outer shape
    for y in range(H):
        for x in range(W):
            if not blade_mask[y, x]:
                canvas[y, x] = CLEAR

    return canvas


def generate_chain():
    """
    Creates guillotine_chain.png (14x116).
    Heavy interlocking gothic iron chain links from Y=0 to Y=116.
    Center is X=7.
    Pitch = 12px. Links interlock with true 3D visual overlap and clean pixel contours.
    """
    W, H = 14, 116
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    cx = 7
    pitch = 12

    # Template definitions for links
    # 1. First draw all side-profile links (odd indices: 1, 3, 5, 7, 9)
    # They pass vertically through the eyes of the front links
    for idx in range(1, 10, 2):
        base_y = idx * pitch
        # Side link spans dy: -2 to 13 (height 16)
        for dy in range(16):
            y = base_y - 2 + dy
            if y < 0 or y >= H:
                continue

            # Width: 6px (x: cx-2 to cx+3)
            # Tapered rounded ends at top (dy: 0, 1) and bottom (dy: 14, 15)
            if dy in [0, 15]:
                xs = range(cx - 1, cx + 2) # width 3
            elif dy in [1, 14]:
                xs = range(cx - 2, cx + 3) # width 5
            else:
                xs = range(cx - 2, cx + 4) # width 6

            for x in xs:
                dx = x - cx
                if dx == -2:
                    canvas[y, x] = C_IRON_DEEP
                elif dx == -1:
                    canvas[y, x] = C_IRON_HI
                elif dx == 0:
                    canvas[y, x] = C_IRON_LIGHT
                elif dx == 1:
                    canvas[y, x] = C_IRON_MID
                elif dx == 2:
                    canvas[y, x] = C_IRON_DARK
                elif dx == 3:
                    canvas[y, x] = C_IRON_DEEP

    # 2. Draw front-facing oval links (even indices: 0, 2, 4, 6, 8)
    # These overlap the side links in front
    for idx in range(0, 10, 2):
        base_y = idx * pitch

        # Oval outer profile: dy from 0 to 13 (height 14)
        for dy in range(14):
            y = base_y + dy
            if y >= H:
                break

            # Outer width by dy
            if dy in [0, 13]:
                out_x = (-2, 3) # width 6
            elif dy in [1, 12]:
                out_x = (-3, 4) # width 8
            else:
                out_x = (-4, 5) # width 10

            # Inner eye hole by dy
            has_hole = False
            if dy in [3, 10]:
                hole_x = (0, 1)
                has_hole = True
            elif dy in range(4, 10):
                hole_x = (-1, 2)
                has_hole = True

            for dx in range(out_x[0], out_x[1] + 1):
                x = cx + dx
                # If inside inner hole, don't overwrite the side link!
                if has_hole and dx >= hole_x[0] and dx <= hole_x[1]:
                    continue

                # Shading for front link iron ring
                if dx == out_x[0] or dx == out_x[1] or dy in [0, 13]:
                    canvas[y, x] = C_IRON_DEEP
                elif dx in [-3, -2]:
                    canvas[y, x] = C_IRON_HI
                elif dx in [-1, 0]:
                    canvas[y, x] = C_IRON_LIGHT
                elif dx in [1, 2]:
                    canvas[y, x] = C_IRON_MID
                elif dx in [3, 4]:
                    canvas[y, x] = C_IRON_DARK

                # Inner hole edge contour
                if has_hole:
                    if dx == hole_x[0] - 1:
                        canvas[y, x] = C_IRON_DEEP
                    elif dx == hole_x[1] + 1:
                        canvas[y, x] = C_IRON_DEEP

                # Rust flecks in crevices
                if dy in [1, 2, 11, 12] and dx in [0, 1]:
                    canvas[y, x] = C_RUST_MID

    return canvas


def generate_pivot():
    """
    Creates guillotine_pivot.png (24x24).
    Heavy cast-iron wall hub / mounting bracket with 4 corner studs and central pin.
    Center is at X=12, Y=12.
    """
    W, H = 24, 24
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    cx, cy = 12, 12

    # 1. Base Wall Flange / Octagonal Cast-Iron Plate
    for y in range(H):
        for x in range(W):
            dx = abs(x - cx)
            dy = abs(y - cy)
            if max(dx, dy) <= 9 and (dx + dy) <= 14:
                canvas[y, x] = C_IRON_MID

    # Outer Bevel & Contours
    for y in range(H):
        for x in range(W):
            if canvas[y, x, 3] != 0:
                dx = x - cx
                dy = y - cy
                if dy <= -8 or dx <= -8 or (dx + dy <= -12):
                    canvas[y, x] = C_IRON_HI
                elif dy >= 8 or dx >= 8 or (dx + dy >= 12):
                    canvas[y, x] = C_IRON_DEEP

    # 2. Four Corner Mounting Bolts
    corner_bolts = [(6, 6), (17, 6), (6, 17), (17, 17)]
    for bx, by in corner_bolts:
        canvas[by-1:by+2, bx-1:bx+2] = C_IRON_DEEP
        canvas[by, bx] = C_BRONZE_MID
        canvas[by-1, bx] = C_BRONZE_HI

    # 3. Center Bearing Hub (Radius ~5)
    for y in range(cy - 5, cy + 6):
        for x in range(cx - 5, cx + 6):
            r_sq = (x - cx) ** 2 + (y - cy) ** 2
            if r_sq <= 25:
                canvas[y, x] = C_IRON_DARK
            if r_sq <= 16:
                canvas[y, x] = C_IRON_MID
            if r_sq <= 7:
                canvas[y, x] = C_IRON_LIGHT

    # Center Pin / Rivet Head (Radius ~2)
    for y in range(cy - 2, cy + 3):
        for x in range(cx - 2, cx + 3):
            if (x - cx) ** 2 + (y - cy) ** 2 <= 4:
                canvas[y, x] = C_BRONZE_MID
    canvas[cy - 1, cx - 1] = C_BRONZE_HI
    canvas[cy, cx] = C_BRONZE_HI
    canvas[cy + 1, cx + 1] = C_IRON_DEEP

    return canvas


def main():
    blade_img = Image.fromarray(generate_blade(), mode="RGBA")
    blade_path = os.path.join(out_dir, "guillotine_blade.png")
    blade_img.save(blade_path)
    print("Saved blade asset:", blade_path, blade_img.size)

    chain_img = Image.fromarray(generate_chain(), mode="RGBA")
    chain_path = os.path.join(out_dir, "guillotine_chain.png")
    chain_img.save(chain_path)
    print("Saved chain asset:", chain_path, chain_img.size)

    pivot_img = Image.fromarray(generate_pivot(), mode="RGBA")
    pivot_path = os.path.join(out_dir, "guillotine_pivot.png")
    pivot_img.save(pivot_path)
    print("Saved pivot asset:", pivot_path, pivot_img.size)


if __name__ == "__main__":
    main()
