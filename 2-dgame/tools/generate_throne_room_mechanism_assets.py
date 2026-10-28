import os
import math
import numpy as np
from PIL import Image

OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "environment", "castle"))
os.makedirs(OUT_DIR, exist_ok=True)

CLEAR = [0, 0, 0, 0]


def generate_weak_gothic_archway():
    """
    Creates weak_gothic_archway.png (108x130).
    Spans from platform height down to ground line (Y = 560).
    Features:
      - Pointed gothic archway with transparent center opening
      - Heavy ashlar stone piers and voussoirs matching castle ramparts
      - Jagged structural crack through the central keystone and right pier
      - Chipped stone edges, crumbling mortar, and stress fractures
      - Directional top-left lighting with specular catchlights
    """
    W, H = 108, 130
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(404)

    # Palette (Cold Slate Granite & Dark Mortar matching Ramparts)
    C_MORTAR       = [10, 12, 16, 255]
    C_STONE_SPEC   = [145, 165, 195, 255]
    C_STONE_HI     = [110, 125, 150, 255]
    C_STONE_LIGHT  = [78, 88, 108, 255]
    C_STONE_MID    = [50, 58, 72, 255]
    C_STONE_ALT    = [38, 44, 56, 255]
    C_STONE_DARK   = [26, 30, 40, 255]
    C_STONE_DEEP   = [16, 18, 25, 255]
    C_CRACK_VOID   = [6, 7, 10, 255]
    C_CRACK_DUST   = [95, 90, 80, 255]
    C_LICHEN       = [32, 44, 38, 255]

    cx = W // 2 # 54

    # 1. Compute Outer and Inner Gothic Arch profiles
    # Outer profile: Full masonry block from x=0..107, with arched / stepped pediment at top
    # Inner opening profile: Vertical jambs from y=65..129, pointed arch from y=18..65
    opening_half_w = 26 # 52px wide opening (from cx - 26 to cx + 26)
    
    # Precompute inner arch y for each dx in 0..opening_half_w
    # Pointed arch equation: two intersecting circles centered at cx +/- offset
    inner_arch_y = {}
    r = 38.0
    center_offset = 12.0 # centers at cx - 12 and cx + 12
    for x in range(cx - opening_half_w, cx + opening_half_w + 1):
        if x <= cx:
            # Circle centered at cx + center_offset = 54 + 12 = 66
            dx_c = x - (cx + center_offset)
            val = r**2 - dx_c**2
            if val >= 0:
                inner_arch_y[x] = int(round(65.0 - math.sqrt(val)))
            else:
                inner_arch_y[x] = 18
        else:
            # Circle centered at cx - center_offset = 54 - 12 = 42
            dx_c = x - (cx - center_offset)
            val = r**2 - dx_c**2
            if val >= 0:
                inner_arch_y[x] = int(round(65.0 - math.sqrt(val)))
            else:
                inner_arch_y[x] = 18

    # Ensure apex is at y=18
    inner_arch_y[cx] = 18

    # Build arch mask
    arch_mask = np.zeros((H, W), dtype=bool)
    for y in range(H):
        for x in range(W):
            # Outer boundary:
            # Piers extend from x: 0..107. Upper pediment has a stepped parapet (y=0..10)
            if y < 8:
                # Stepped decorative battlements on top
                if (x >= 4 and x <= 22) or (x >= 32 and x <= 75) or (x >= 85 and x <= 103):
                    arch_mask[y, x] = True
            elif y < 14:
                if x >= 2 and x <= 105:
                    arch_mask[y, x] = True
            else:
                # Full pier width: x: 0 to 107
                arch_mask[y, x] = True

            # Subtract inner opening:
            if x in inner_arch_y:
                top_y = inner_arch_y[x]
                if y >= top_y:
                    arch_mask[y, x] = False

    # 2. Fill Arch Masonry with Ashlar Blocks and Grain
    for y in range(H):
        for x in range(W):
            if arch_mask[y, x]:
                n = np.random.randint(-2, 3)
                grain = 2 if (x + y * 2) % 6 == 0 else 0
                base = C_STONE_MID if (x // 20 + y // 16) % 2 == 0 else C_STONE_ALT
                canvas[y, x] = [
                    np.clip(base[0] + n + grain, 12, 245),
                    np.clip(base[1] + n + grain, 12, 245),
                    np.clip(base[2] + n + grain, 12, 245),
                    255
                ]

    # 3. Horizontal Courses in Piers (Y: 14 to 129)
    # Courses every 16px: Y = 14, 30, 46, 62, 78, 94, 110, 126
    course_y_list = [14, 30, 46, 62, 78, 94, 110, 126]
    for cy in course_y_list:
        for x in range(W):
            if arch_mask[cy, x]:
                canvas[cy, x] = C_MORTAR
                if cy + 1 < H and arch_mask[cy + 1, x]:
                    canvas[cy + 1, x] = C_STONE_HI

    # Vertical mortar joints in piers
    # Staggered every 16px:
    for idx, cy in enumerate(course_y_list):
        y0 = cy + 1
        y1 = course_y_list[idx + 1] - 1 if idx + 1 < len(course_y_list) else H - 1
        stagger = 14 if (idx % 2 == 1) else 0
        # Left pier joints
        for jx in [14 + stagger]:
            if jx < cx - opening_half_w:
                for y in range(y0, y1 + 1):
                    if arch_mask[y, jx]:
                        canvas[y, jx] = C_MORTAR
                        if jx + 1 < W and arch_mask[y, jx + 1]:
                            canvas[y, jx + 1] = C_STONE_HI
        # Right pier joints
        for jx in [cx + opening_half_w + 14 + stagger]:
            if jx < W - 2:
                for y in range(y0, y1 + 1):
                    if arch_mask[y, jx]:
                        canvas[y, jx] = C_MORTAR
                        if jx + 1 < W and arch_mask[y, jx + 1]:
                            canvas[y, jx + 1] = C_STONE_HI

    # 4. Radiating Voussoir Arch Stones (Surrounding the opening curve)
    # Radiating mortar cuts from inner curve outwards by 14px
    for angle_deg in range(15, 170, 16):
        rad = math.radians(angle_deg)
        # Origin depends on left/right side
        ox = (cx - center_offset) if angle_deg >= 90 else (cx + center_offset)
        oy = 65.0
        for dr in range(int(r), int(r) + 15):
            px = int(round(ox - dr * math.cos(rad)))
            py = int(round(oy - dr * math.sin(rad)))
            if 0 <= px < W and 0 <= py < H and arch_mask[py, px]:
                canvas[py, px] = C_MORTAR
                if px + 1 < W and arch_mask[py, px + 1]:
                    canvas[py, px + 1] = C_STONE_HI

    # 5. Inner Opening Rim Bevel & Drop Shadow
    for x in range(cx - opening_half_w, cx + opening_half_w + 1):
        if x in inner_arch_y:
            top_y = inner_arch_y[x]
            # Rim inner border
            if 0 <= top_y - 1 < H and arch_mask[top_y - 1, x]:
                canvas[top_y - 1, x] = C_STONE_DARK
            if 0 <= top_y - 2 < H and arch_mask[top_y - 2, x]:
                canvas[top_y - 2, x] = C_STONE_DEEP

    # Left & right inner jambs
    for y in range(65, H):
        canvas[y, cx - opening_half_w] = C_STONE_HI # Light catch on left jamb
        canvas[y, cx - opening_half_w - 1] = C_STONE_LIGHT
        canvas[y, cx + opening_half_w] = C_STONE_DARK # Shadow on right jamb
        canvas[y, cx + opening_half_w + 1] = C_STONE_DEEP

    # Outer perimeter contours & bevels
    for y in range(H):
        for x in range(W):
            if arch_mask[y, x]:
                # Top outer edge
                if y == 0 or not arch_mask[y - 1, x]:
                    canvas[y, x] = C_STONE_SPEC if x % 6 in [0, 1] else C_STONE_HI
                # Left outer edge
                elif x == 0 or not arch_mask[y, x - 1]:
                    canvas[y, x] = C_STONE_HI
                # Bottom edge resting on ground
                elif y == H - 1:
                    canvas[y, x] = C_MORTAR
                # Right outer edge
                elif x == W - 1 or not arch_mask[y, x + 1]:
                    canvas[y, x] = C_STONE_DARK

    # 6. CENTRAL KEYSTONE & STRUCTURAL DAMAGE / CRACK SYSTEM
    # Keystone apex (cx: 54, y: 4 to 18)
    for y in range(4, 18):
        # Keystone trapezoid profile
        w_k = int(5 + (18 - y) * 0.4)
        canvas[y, cx - w_k] = C_MORTAR
        canvas[y, cx + w_k] = C_MORTAR
        canvas[y, cx - w_k + 1] = C_STONE_HI
        canvas[y, cx + w_k - 1] = C_STONE_DARK

    # A. Massive Fractured Fissure through Keystone:
    # Starts at y=2, x=53, cuts down through keystone into inner arch
    crack_points = [
        (53, 2), (54, 3), (53, 4), (52, 5), (51, 6), (51, 7), (52, 8),
        (53, 9), (54, 10), (55, 11), (55, 12), (56, 13), (56, 14),
        (55, 15), (54, 16), (54, 17), (53, 18)
    ]
    for (px, py) in crack_points:
        if 0 <= px < W and 0 <= py < H:
            canvas[py, px] = C_CRACK_VOID
            if px + 1 < W:
                canvas[py, px + 1] = C_STONE_SPEC # Sharp fractured rock edge
            if px - 1 >= 0:
                canvas[py, px - 1] = C_CRACK_DUST # Crumbled limestone dust

    # B. Secondary Diagonal Shatter Fissure branching into Right Pier:
    branch_crack = [
        (55, 11), (57, 12), (59, 14), (62, 17), (65, 20), (68, 23),
        (70, 26), (71, 30), (73, 34), (74, 39), (75, 45), (76, 52),
        (77, 60), (78, 68), (78, 77), (79, 86), (80, 96)
    ]
    for (px, py) in branch_crack:
        if 0 <= px < W and 0 <= py < H and arch_mask[py, px]:
            canvas[py, px] = C_CRACK_VOID
            if px + 1 < W and arch_mask[py, px + 1]:
                canvas[py, px + 1] = C_STONE_SPEC
            if px - 1 >= 0 and arch_mask[py, px - 1]:
                canvas[py, px - 1] = C_CRACK_DUST

    # Dislodged masonry fragments near keystone
    for (px, py) in [(58, 8), (59, 9), (60, 8), (48, 14), (49, 15)]:
        canvas[py, px] = C_STONE_SPEC
        canvas[py + 1, px] = C_CRACK_VOID

    # Lichen stains in lower mortar recesses
    for (px, py) in [(18, 94), (19, 94), (88, 110), (89, 110)]:
        canvas[py, px] = C_LICHEN

    img = Image.fromarray(canvas, 'RGBA')
    out_path = os.path.join(OUT_DIR, "weak_gothic_archway.png")
    img.save(out_path)
    print("Created:", out_path)


def generate_great_castle_bell():
    """
    Creates great_castle_bell.png (52x58).
    Pivot at top suspension crown loop (26, 2).
    Features:
      - Heavy cast bronze gothic cathedral bell
      - Ornate crown loop for chain suspension
      - Curved bell waist and flaring sound bow
      - Thick cast bronze sound lip / mouth rim
      - Internal forged iron clapper ball visible below rim
      - Warm amber/gold specular highlights, aged brown shadows, and verdigris patina
    """
    W, H = 52, 58
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(606)

    # Palette (Aged Cast Bronze, Verdigris & Iron)
    C_BRONZE_SPEC   = [235, 205, 120, 255] # Sharp golden metallic shine
    C_BRONZE_HI     = [195, 160, 82, 255]  # Catchlight on rounded bell shoulder
    C_BRONZE_LIGHT  = [155, 120, 58, 255]  # Upper lit face
    C_BRONZE_MID    = [118, 88, 42, 255]   # Base cast bronze body
    C_BRONZE_DARK   = [76, 54, 26, 255]    # Bell shadow & under-bevel
    C_BRONZE_DEEP   = [42, 28, 14, 255]    # Deep bronze contour
    C_PATINA        = [58, 110, 88, 255]   # Verdigris / antique copper patina
    C_VOID          = [12, 10, 8, 255]     # Dark hollow inside cavity
    
    # Iron Crown & Clapper
    C_IRON_HI       = [120, 128, 144, 255]
    C_IRON_MID      = [54, 58, 68, 255]
    C_IRON_DARK     = [24, 26, 32, 255]
    C_IRON_VOID     = [12, 14, 18, 255]

    cx = W // 2 # 26

    # 1. Bell Silhouette Mask Computation (Y: 0 to 52)
    # y=0..6: Suspension crown loop (width 12)
    # y=7..13: Crown base flange (width 18..24)
    # y=14..24: Bell shoulder (width 26..32)
    # y=25..42: Bell waist (subtle curve, width 32..40)
    # y=43..48: Sound bow flare (width 42..50)
    # y=49..52: Reinforced sound lip rim (width 50..52)
    bell_half_w = {}
    for y in range(H):
        if y <= 5:
            # Crown loop: width 12 (half 6)
            bell_half_w[y] = 6
        elif y <= 8:
            # Loop base collar: width 16
            bell_half_w[y] = 8
        elif y <= 13:
            # Top flange
            bell_half_w[y] = int(9 + (y - 8) * 0.8)
        elif y <= 22:
            # Shoulder
            bell_half_w[y] = int(13 + (y - 13) * 0.4)
        elif y <= 40:
            # Waist curve (gentle flare)
            t = (y - 22) / 18.0
            bell_half_w[y] = int(17 + t * t * 5.0)
        elif y <= 48:
            # Sound bow sharp flare
            t = (y - 40) / 8.0
            bell_half_w[y] = int(22 + t * 3.5)
        elif y <= 52:
            # Heavy cast bronze mouth rim
            bell_half_w[y] = 25
        else:
            # Underside clapper only
            bell_half_w[y] = 0

    # 2. Fill Bell Body
    for y in range(53):
        hw = bell_half_w[y]
        if hw > 0:
            for dx in range(-hw, hw + 1):
                x = cx + dx
                # Horizontal cylindrical shading (light from left: dx ~ -hw/2)
                t_shade = (dx + hw) / (2.0 * hw) if hw > 0 else 0.5
                n = np.random.randint(-2, 3)

                # Shading zones
                if t_shade < 0.15:
                    col = C_BRONZE_LIGHT # Left bounce/edge
                elif t_shade < 0.40:
                    col = C_BRONZE_HI    # Main specular catchlight column
                elif t_shade < 0.65:
                    col = C_BRONZE_MID   # Body bronze
                elif t_shade < 0.85:
                    col = C_BRONZE_DARK  # Shadow side
                else:
                    col = C_BRONZE_DEEP  # Deep right edge contour

                canvas[y, x] = [
                    np.clip(col[0] + n, 8, 250),
                    np.clip(col[1] + n, 8, 250),
                    np.clip(col[2] + n, 8, 250),
                    255
                ]

    # 3. Crown Suspension Loop Eyehole (Y: 1 to 4, X: cx-2..cx+2)
    # The chain hook passes through this eyehole!
    for y in range(1, 5):
        canvas[y, cx - 2:cx + 3] = CLEAR
        canvas[y, cx - 3] = C_IRON_DARK
        canvas[y, cx + 3] = C_IRON_HI

    # Crown loop iron finish
    for y in range(6):
        hw = bell_half_w[y]
        for dx in range(-hw, hw + 1):
            if canvas[y, cx + dx, 3] > 0:
                canvas[y, cx + dx] = C_IRON_MID
        canvas[y, cx - hw] = C_IRON_HI
        canvas[y, cx + hw] = C_IRON_DARK
    canvas[0, cx - 5:cx + 6] = C_IRON_HI

    # 4. Vertical Specular Glint Streak on Bell Left Face
    for y in range(7, 49):
        hw = bell_half_w[y]
        sx = cx - int(hw * 0.45)
        canvas[y, sx] = C_BRONZE_SPEC
        if sx + 1 < W:
            canvas[y, sx + 1] = C_BRONZE_HI

    # 5. Ornamental Relief Molding Rings & Verdigris Patina
    # Two raised cast relief rings around bell waist (Y = 24 and Y = 42)
    for ry in [24, 42]:
        hw = bell_half_w[ry]
        # Groove above ring
        canvas[ry - 1, cx - hw + 1:cx + hw] = C_BRONZE_DEEP
        # Raised highlighted ridge
        canvas[ry, cx - hw + 1:cx + hw] = C_BRONZE_HI
        # Shadow below ridge
        canvas[ry + 1, cx - hw + 1:cx + hw] = C_BRONZE_DARK
        # Subtle verdigris patina dots in the recessed groove
        for dx in range(-hw + 3, hw - 3, 4):
            canvas[ry - 1, cx + dx] = C_PATINA

    # 6. Heavy Cast Bronze Sound Lip / Mouth Rim (Y: 49 to 52)
    canvas[49, cx - 24:cx + 25] = C_BRONZE_SPEC # Sharp mouth catchlight
    canvas[50, cx - 25:cx + 26] = C_BRONZE_HI
    canvas[51, cx - 25:cx + 26] = C_BRONZE_MID
    canvas[52, cx - 24:cx + 25] = C_BRONZE_DEEP

    # 7. Internal Cavity (Dark Void) and Forged Iron Clapper (Y: 53 to 57)
    # Underside concave curve of the bell mouth
    for dx in range(-23, 24):
        x = cx + dx
        canvas[53, x] = C_VOID

    # Clapper iron ball (X: cx-3..cx+3, Y: 53..57)
    for y in range(53, 58):
        dy = y - 55
        for dx in range(-3, 4):
            if dx * dx + dy * dy <= 9:
                x = cx + dx
                if dx < 0 and dy < 0:
                    canvas[y, x] = C_IRON_HI
                elif dx > 1 or dy > 1:
                    canvas[y, x] = C_IRON_DARK
                else:
                    canvas[y, x] = C_IRON_MID
    # Clapper bottom highlight
    canvas[57, cx] = C_IRON_DARK

    # Outer perimeter contours
    for y in range(H):
        hw = bell_half_w[y]
        if hw > 0:
            canvas[y, cx - hw] = C_BRONZE_HI if y < 48 else C_BRONZE_SPEC
            canvas[y, cx + hw] = C_BRONZE_DEEP

    img = Image.fromarray(canvas, 'RGBA')
    out_path = os.path.join(OUT_DIR, "great_castle_bell.png")
    img.save(out_path)
    print("Created:", out_path)


def generate_great_bell_chain():
    """
    Creates great_bell_chain.png (8x16).
    Seamless vertical tiling for hanging the Great Bell.
    Interlocking heavy forged iron oval links.
    """
    W, H = 8, 16
    canvas = np.zeros((H, W, 4), dtype=np.uint8)

    C_IRON_SPEC   = [150, 160, 180, 255]
    C_IRON_HI     = [115, 122, 138, 255]
    C_IRON_MID    = [54, 58, 68, 255]
    C_IRON_DARK   = [26, 28, 34, 255]
    C_IRON_DEEP   = [12, 14, 18, 255]
    C_RUST        = [95, 52, 34, 255]

    cx = W // 2 # 4

    # LINK 1: Front oval link (Y: 0 to 9, height 10)
    for y in range(10):
        # Outer width
        if y in [0, 9]:
            w_out = 2 # x: 2..5 (width 4)
        elif y in [1, 8]:
            w_out = 3 # x: 1..6 (width 6)
        else:
            w_out = 4 # x: 0..7 (width 8)

        # Inner hole
        has_hole = (y in range(2, 8))
        w_in = 1 if (y in [2, 7]) else 2

        for x in range(cx - w_out, cx + w_out):
            if 0 <= x < W:
                if has_hole and (cx - w_in <= x < cx + w_in):
                    continue # eye hole
                # Shading
                if x == cx - w_out or y in [0, 9]:
                    canvas[y, x] = C_IRON_HI
                elif x == cx + w_out - 1:
                    canvas[y, x] = C_IRON_DARK
                elif x < cx:
                    canvas[y, x] = C_IRON_SPEC if y in [2, 3] else C_IRON_HI
                else:
                    canvas[y, x] = C_IRON_MID

    # LINK 2: Side perpendicular link (Y: 8 to 15 + wrap into 0..1, height 10, pitch 8)
    for y in range(8, 16):
        # Side profile: narrower width = 4 (x: 2..5)
        canvas[y, 2] = C_IRON_HI
        canvas[y, 3] = C_IRON_SPEC
        canvas[y, 4] = C_IRON_MID
        canvas[y, 5] = C_IRON_DARK

    # Rust fleck in interlocking crevice
    canvas[8, 3] = C_RUST
    canvas[9, 4] = C_RUST

    img = Image.fromarray(canvas, 'RGBA')
    out_path = os.path.join(OUT_DIR, "great_bell_chain.png")
    img.save(out_path)
    print("Created:", out_path)


if __name__ == "__main__":
    generate_weak_gothic_archway()
    generate_great_castle_bell()
    generate_great_bell_chain()
    print("ALL MECHANISM ASSETS GENERATED SUCCESSFULLY!")
