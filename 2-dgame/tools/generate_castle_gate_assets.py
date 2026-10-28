import os
import numpy as np
from PIL import Image

out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "environment", "castle"))
os.makedirs(out_dir, exist_ok=True)

# -------------------------------------------------------------
# PALETTES
# -------------------------------------------------------------
# Stone (Dark Gothic Wallachian Castle Stone)
C_STONE_HI     = [82, 88, 104, 255]   # Chiseled stone edge highlight
C_STONE_LIGHT  = [60, 66, 78, 255]    # Stone face light
C_STONE_MID    = [44, 48, 58, 255]    # Standard ashlar block
C_STONE_DARK   = [30, 33, 40, 255]    # Stone shadow / under-lip
C_STONE_DEEP   = [18, 20, 26, 255]    # Deep crevice / dark outline
C_MORTAR       = [12, 13, 17, 255]    # Mortar joint groove
C_MOSS_LIGHT   = [44, 58, 42, 255]    # Crevice moss
C_MOSS_DARK    = [24, 34, 24, 255]

# Iron (Forged Wrought Iron)
C_IRON_HI      = [140, 146, 162, 255] # Cold metallic edge highlight
C_IRON_LIGHT   = [95, 102, 116, 255]  # Iron face
C_IRON_MID     = [62, 66, 76, 255]    # Wrought iron body
C_IRON_DARK    = [38, 41, 48, 255]    # Iron shadow
C_IRON_RUST    = [72, 42, 34, 255]    # Weathered oxidation / rust
C_IRON_DEEP    = [20, 22, 28, 255]    # Black iron outline

# Wood (Old Gothic Oak Planks)
C_WOOD_HI      = [112, 78, 48, 255]   # Plank edge grain highlight
C_WOOD_LIGHT   = [86, 58, 36, 255]    # Weathered oak face
C_WOOD_MID     = [64, 42, 26, 255]    # Oak body
C_WOOD_DARK    = [44, 28, 18, 255]    # Deep grain shadow
C_WOOD_DEEP    = [28, 18, 12, 255]    # Plank seam gap / shadow

# Portal Interior (Abyssal Dungeon Void)
C_VOID_DEEP    = [8, 6, 10, 255]      # Pitch black depth
C_VOID_MIST    = [32, 12, 18, 255]    # Crimson dungeon ambient haze

CLEAR = [0, 0, 0, 0]


def generate_gate_arch():
    W, H = 88, 220
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(777)

    # Portal opening is transparent (CLEAR) so wooden doors and portcullis are visible through the frame
    # 2. Draw Left Stone Pillar (x: 0 to 22) and Right Stone Pillar (x: 66 to 88)
    for pillar_x_start, is_left in [(0, True), (66, False)]:
        pw = 22
        pillar = canvas[:, pillar_x_start:pillar_x_start + pw]
        pillar[:] = C_STONE_MID

        # Subtle stone noise
        noise = np.random.randint(-4, 5, size=(H, pw, 1))
        for c in range(3):
            pillar[:, :, c] = np.clip(pillar[:, :, c].astype(int) + noise[:, :, 0], 12, 240)

        # Outer edge bevel & Inner doorway bevel
        if is_left:
            pillar[:, 0] = C_STONE_DARK
            pillar[:, 1] = C_STONE_HI
            pillar[:, pw - 1] = C_STONE_DEEP
            pillar[:, pw - 2] = C_STONE_DARK
        else:
            pillar[:, 0] = C_STONE_DEEP
            pillar[:, 1] = C_STONE_DARK
            pillar[:, pw - 1] = C_STONE_DARK
            pillar[:, pw - 2] = C_STONE_HI

        # Ashlar block horizontal mortar lines every 18-22 pixels
        block_y = 12
        while block_y < H - 5:
            pillar[block_y, :] = C_MORTAR
            pillar[block_y + 1, :] = C_STONE_DARK
            if block_y > 0:
                pillar[block_y - 1, :] = C_STONE_HI

            # Vertical staggered joint
            v_x = 10 if (block_y // 20) % 2 == 0 else 16
            v_start = block_y + 2
            v_end = min(H, block_y + 20)
            pillar[v_start:v_end, v_x] = C_MORTAR
            pillar[v_start:v_end, min(pw - 1, v_x + 1)] = C_STONE_HI

            # Moss in some mortar crevices
            if (block_y % 38 == 0):
                pillar[block_y, 4:18] = C_MOSS_LIGHT
                if block_y + 1 < H:
                    pillar[block_y + 1, 6:14] = C_MOSS_DARK

            block_y += 20

    # 3. Top Gothic Arch & Keystone Header (y: 0 to 32, full width)
    # Base fill for the upper wall / tympanum
    canvas[0:24, 18:70] = C_STONE_MID
    noise_arch = np.random.randint(-3, 4, size=(24, 52, 1))
    for c in range(3):
        canvas[0:24, 18:70, c] = np.clip(canvas[0:24, 18:70, c].astype(int) + noise_arch[:, :, 0], 15, 230)

    # Top cornice trim (y: 0 to 6)
    canvas[0, :] = C_STONE_HI
    canvas[1, :] = C_STONE_LIGHT
    canvas[2, :] = C_STONE_MID
    canvas[3, :] = C_STONE_DARK
    canvas[4, :] = C_MORTAR

    # Keystone / Gothic Crest (x: 36 to 52, y: 4 to 22)
    canvas[6:22, 38:50] = C_STONE_LIGHT
    canvas[7:21, 39:49] = C_STONE_HI
    canvas[8:20, 40:48] = C_STONE_MID
    # Carved Vlad Bat Sigil in the keystone center
    canvas[11:15, 42:46] = C_STONE_DEEP
    canvas[12:14, 40:48] = C_STONE_DEEP
    canvas[13, 39:49] = C_STONE_DEEP

    # Arch relief contour (dark carved border tracing the gothic opening)
    for y in range(6, 44):
        progress = max(0.0, (y - 12) / 30.0)
        half_w = int(24.0 * np.sqrt(progress))
        cx = W // 2
        lx = max(0, cx - half_w - 2)
        rx = min(W - 1, cx + half_w + 1)
        canvas[y, lx:lx + 3] = C_STONE_DEEP
        canvas[y, rx - 2:rx + 1] = C_STONE_DEEP

    # Ensure doorway opening under arch curve is completely transparent
    for y in range(H):
        if y >= 24:
            canvas[y, 22:66] = CLEAR
        elif y >= 14:
            progress = (y - 12) / 12.0
            half_w = int(22.0 * np.sqrt(max(0.0, progress)))
            cx = W // 2
            canvas[y, max(0, cx - half_w):min(W, cx + half_w)] = CLEAR

    img = Image.fromarray(canvas, 'RGBA')
    img.save(os.path.join(out_dir, "gothic_gate_arch.png"))
    print("Created gothic_gate_arch.png (88x220)")


def generate_portcullis():
    W, H = 44, 195
    canvas = np.zeros((H, W, 4), dtype=np.uint8)

    # 4 Vertical Iron Bars (x = 4, 15, 26, 37)
    bar_xs = [5, 16, 27, 38]
    bar_width = 3

    for bx in bar_xs:
        # Iron bar body
        canvas[:H - 14, bx:bx + bar_width] = C_IRON_MID
        canvas[:H - 14, bx] = C_IRON_HI # highlight on left edge
        canvas[:H - 14, bx + bar_width - 1] = C_IRON_DARK # shadow on right edge

        # Bottom Pointed Chisel Spike (y: H-14 to H)
        for i in range(14):
            y = H - 14 + i
            cur_w = max(1, bar_width - int(i * 0.25))
            offset = (bar_width - cur_w) // 2
            canvas[y, bx + offset:bx + offset + cur_w] = C_IRON_MID
            canvas[y, bx + offset] = C_IRON_HI
            if cur_w > 1:
                canvas[y, bx + offset + cur_w - 1] = C_IRON_DARK
        # Sharp tip
        canvas[H - 1, bx + bar_width // 2] = C_IRON_HI

    # 5 Horizontal Cross-Ties (y = 20, 60, 100, 140, 175)
    tie_ys = [18, 56, 96, 136, 170]
    tie_h = 4
    for ty in tie_ys:
        canvas[ty:ty + tie_h, 2:W - 2] = C_IRON_MID
        canvas[ty, 2:W - 2] = C_IRON_HI
        canvas[ty + tie_h - 1, 2:W - 2] = C_IRON_DARK
        canvas[ty:ty + tie_h, 2] = C_IRON_HI
        canvas[ty:ty + tie_h, W - 3] = C_IRON_DARK

        # Heavy Rivet Studs at intersections with vertical bars
        for bx in bar_xs:
            rx = bx + (bar_width // 2)
            ry = ty + (tie_h // 2)
            canvas[ry - 1:ry + 2, rx - 1:rx + 2] = C_IRON_DEEP
            canvas[ry, rx] = C_IRON_HI
            canvas[ry - 1, rx] = C_IRON_HI

    img = Image.fromarray(canvas, 'RGBA')
    img.save(os.path.join(out_dir, "gothic_portcullis.png"))
    print("Created gothic_portcullis.png (44x195)")


def generate_door_wing(is_left=True):
    W, H = 22, 195
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(888 if is_left else 999)

    # 1. Base Oak Planks Fill
    canvas[:] = C_WOOD_MID

    # Wood grain noise and vertical streaks
    noise = np.random.randint(-5, 6, size=(H, W, 1))
    for c in range(3):
        canvas[:, :, c] = np.clip(canvas[:, :, c].astype(int) + noise[:, :, 0], 15, 230)

    # Vertical plank seams (Door consists of 3 planks per wing)
    seam_xs = [7, 14]
    for sx in seam_xs:
        canvas[:, sx] = C_WOOD_DEEP
        canvas[:, sx - 1] = C_WOOD_DARK
        if sx + 1 < W:
            canvas[:, sx + 1] = C_WOOD_LIGHT

    # Outer border & Hinge edge
    if is_left:
        canvas[:, 0] = C_WOOD_DARK
        canvas[:, W - 1] = C_WOOD_DEEP # Center split seam
        canvas[:, W - 2] = C_WOOD_DARK
    else:
        canvas[:, 0] = C_WOOD_DEEP # Center split seam
        canvas[:, 1] = C_WOOD_LIGHT
        canvas[:, W - 1] = C_WOOD_DARK

    # 2. Horizontal Forged Iron Reinforcement Straps (y: 22, 70, 120, 168)
    strap_ys = [22, 70, 120, 168]
    strap_h = 7
    for sy in strap_ys:
        canvas[sy:sy + strap_h, :] = C_IRON_MID
        canvas[sy, :] = C_IRON_HI
        canvas[sy + 1, :] = C_IRON_LIGHT
        canvas[sy + strap_h - 1, :] = C_IRON_DEEP
        canvas[sy + strap_h - 2, :] = C_IRON_DARK

        # Heavy Round Iron Rivets (2 rivets per strap)
        rivet_xs = [4, 11, 18]
        for rx in rivet_xs:
            ry = sy + 3
            canvas[ry - 1:ry + 2, rx - 1:rx + 2] = C_IRON_DARK
            canvas[ry, rx] = C_IRON_HI

    # 3. Massive Iron Door Pull-Ring (near center on right side of left door / left side of right door)
    handle_y = 104
    hx = (W - 5) if is_left else 4
    canvas[handle_y - 4:handle_y + 6, hx - 2:hx + 3] = C_IRON_DEEP
    canvas[handle_y - 3:handle_y + 5, hx - 1:hx + 2] = C_IRON_MID
    canvas[handle_y - 2:handle_y + 4, hx] = C_IRON_HI

    filename = "gothic_door_left.png" if is_left else "gothic_door_right.png"
    img = Image.fromarray(canvas, 'RGBA')
    img.save(os.path.join(out_dir, filename))
    print(f"Created {filename} (22x195)")


def generate_debris_particles():
    # Wood Splinter Debris (16x16)
    W, H = 16, 16
    wood_canvas = np.zeros((H, W, 4), dtype=np.uint8)
    for y in range(2, 14):
        w = max(1, int(4 * (1.0 - abs(y - 8) / 7.0)))
        wood_canvas[y, 8 - w:8 + w] = C_WOOD_MID
        wood_canvas[y, 8] = C_WOOD_HI
    Image.fromarray(wood_canvas, 'RGBA').save(os.path.join(out_dir, "door_splinter_debris.png"))

    # Iron Scrap Debris (16x16)
    iron_canvas = np.zeros((H, W, 4), dtype=np.uint8)
    for i in range(12):
        iron_canvas[2 + i, 2 + int(i * 0.9)] = C_IRON_HI
        iron_canvas[2 + i, 3 + int(i * 0.9)] = C_IRON_MID
        iron_canvas[3 + i, 2 + int(i * 0.9)] = C_IRON_DARK
    Image.fromarray(iron_canvas, 'RGBA').save(os.path.join(out_dir, "iron_shard_debris.png"))
    print("Created debris particles (16x16)")


if __name__ == "__main__":
    generate_gate_arch()
    generate_portcullis()
    generate_door_wing(True)
    generate_door_wing(False)
    generate_debris_particles()
    print("ALL GATE TEXTURES GENERATED SUCCESSFULLY!")
