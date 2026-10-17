import os
import numpy as np
from PIL import Image

# Directories
dirs = [
    "2-dgame/assets/environment/forest",
    "2-dgame/assets/environment/camp",
    "2-dgame/assets/environment/bridge",
    "2-dgame/assets/environment/castle"
]
for d in dirs:
    os.makedirs(d, exist_ok=True)


def create_forest_ground():
    W, H = 64, 64
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(101)

    # Base gradient: dark earthy loam to deep abyss
    for y in range(H):
        t = y / float(H)
        r = int(24 * (1.0 - t * 0.6))
        g = int(28 * (1.0 - t * 0.65))
        b = int(32 * (1.0 - t * 0.7))
        canvas[y, :] = [r, g, b, 255]

    # Texture noise
    noise = np.random.randint(-3, 4, size=(H, W, 1))
    for c in range(3):
        canvas[:, :, c] = np.clip(canvas[:, :, c].astype(int) + noise[:, :, 0], 8, 250)

    # Top walk edge (Rows 0-4): moss, needles, soil crust
    for x in range(W):
        # Forest moss/grass blades
        if (x % 5 == 0) or (x % 7 == 0):
            canvas[0, x] = [38, 54, 40, 255] # moss highlight
            canvas[1, x] = [28, 42, 30, 255]
        elif (x % 4 == 0):
            canvas[0, x] = [48, 40, 32, 255] # pebble highlight
            canvas[1, x] = [32, 34, 38, 255]
        else:
            canvas[0, x] = [28, 34, 36, 255] # dark loam crust
            canvas[1, x] = [22, 26, 28, 255]

    # Embedded pebbles and root specks in mid ground (rows 8 to 28)
    for _ in range(18):
        px = np.random.randint(2, W - 3)
        py = np.random.randint(6, 26)
        pw = np.random.randint(2, 4)
        canvas[py, px:px+pw] = [42, 46, 50, 255] # pebble
        canvas[py+1, px:px+pw] = [16, 18, 22, 255] # shadow under pebble

    # Soil layering horizontal strata
    for y_strata in [14, 24, 38]:
        for x in range(W):
            canvas[y_strata, x] = np.clip(canvas[y_strata, x].astype(int) - [4, 4, 4, 0], 6, 255)

    # Seamless wrapping check
    canvas[:, -1] = canvas[:, 0]

    img = Image.fromarray(canvas, 'RGBA')
    img.save("2-dgame/assets/environment/forest/forest_camp_ground.png")
    print("Created forest_camp_ground.png")


def create_camp_ground():
    W, H = 64, 64
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(202)

    # Base gradient: warm trampled camp soil
    for y in range(H):
        t = y / float(H)
        r = int(36 * (1.0 - t * 0.65))
        g = int(30 * (1.0 - t * 0.70))
        b = int(24 * (1.0 - t * 0.75))
        canvas[y, :] = [r, g, b, 255]

    noise = np.random.randint(-4, 5, size=(H, W, 1))
    for c in range(3):
        canvas[:, :, c] = np.clip(canvas[:, :, c].astype(int) + noise[:, :, 0], 6, 250)

    # Top walking crust: trampled gravel & wooden beam trims
    for x in range(W):
        if (x // 16) % 2 == 0:
            # Wooden log board curb segment
            canvas[0, x] = [68, 50, 36, 255] # wood highlight
            canvas[1, x] = [52, 38, 28, 255] # wood grain
            canvas[2, x] = [38, 28, 20, 255]
        else:
            # Compacted packed gravel
            canvas[0, x] = [56, 48, 38, 255] # gravel top
            canvas[1, x] = [42, 35, 28, 255]
            canvas[2, x] = [32, 26, 22, 255]

    # Scattered small campfire charcoal and gravel specks
    for _ in range(20):
        px = np.random.randint(2, W - 3)
        py = np.random.randint(6, 25)
        canvas[py, px:px+2] = [52, 46, 38, 255]
        canvas[py+1, px:px+2] = [18, 14, 12, 255]

    canvas[:, -1] = canvas[:, 0]

    img = Image.fromarray(canvas, 'RGBA')
    img.save("2-dgame/assets/environment/camp/ottoman_camp_ground.png")
    print("Created ottoman_camp_ground.png")


def create_bridge_ground():
    W, H = 64, 64
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(303)

    # Base stone gray
    for y in range(H):
        t = y / float(H)
        r = int(34 * (1.0 - t * 0.6))
        g = int(38 * (1.0 - t * 0.6))
        b = int(44 * (1.0 - t * 0.6))
        canvas[y, :] = [r, g, b, 255]

    noise = np.random.randint(-4, 5, size=(H, W, 1))
    for c in range(3):
        canvas[:, :, c] = np.clip(canvas[:, :, c].astype(int) + noise[:, :, 0], 8, 250)

    # Top walk edge: chiseled bridge curb + cobblestone crown (Rows 0-5)
    for x in range(W):
        # Chiseled top edge
        if x % 8 == 0:
            canvas[0, x] = [48, 54, 64, 255] # chisel groove
            canvas[1, x] = [32, 36, 42, 255]
        else:
            canvas[0, x] = [84, 92, 106, 255] # top stone bevel highlight
            canvas[1, x] = [62, 68, 78, 255]

        # Row 2-4: Cobblestone pavers with mortared joints
        if (x % 16 == 0):
            canvas[2:5, x] = [18, 20, 24, 255] # mortar joint
        else:
            canvas[2, x] = [52, 58, 66, 255]
            canvas[3, x] = [40, 44, 50, 255]
            canvas[4, x] = [32, 36, 42, 255]

    # Row 5: Mortar seam under curb
    canvas[5, :] = [18, 20, 24, 255]

    # Ashlar stone blocks in masonry body
    for row_y in [18, 32, 46]:
        canvas[row_y, :] = [16, 18, 22, 255] # horizontal mortar seam
    for x_joint in [12, 36, 52]:
        canvas[6:18, x_joint] = [16, 18, 22, 255]
    for x_joint in [24, 48]:
        canvas[19:32, x_joint] = [16, 18, 22, 255]
    for x_joint in [16, 40]:
        canvas[33:46, x_joint] = [16, 18, 22, 255]

    # Block highlights along seams
    for row_y in [6, 19, 33]:
        for x in range(W):
            if canvas[row_y, x, 0] > 25:
                canvas[row_y, x] = np.clip(canvas[row_y, x].astype(int) + [12, 14, 16, 0], 0, 255)

    canvas[:, -1] = canvas[:, 0]

    img = Image.fromarray(canvas, 'RGBA')
    img.save("2-dgame/assets/environment/bridge/bridge_stone_ground.png")
    print("Created bridge_stone_ground.png")


def create_throne_ground():
    W, H = 64, 64
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(404)

    # Base royal obsidian purple/dark stone
    for y in range(H):
        t = y / float(H)
        r = int(36 * (1.0 - t * 0.6))
        g = int(28 * (1.0 - t * 0.65))
        b = int(36 * (1.0 - t * 0.6))
        canvas[y, :] = [r, g, b, 255]

    noise = np.random.randint(-3, 4, size=(H, W, 1))
    for c in range(3):
        canvas[:, :, c] = np.clip(canvas[:, :, c].astype(int) + noise[:, :, 0], 8, 250)

    # Top walk edge: Polished obsidian tile with Crimson Blood Inlay
    for x in range(W):
        # Row 0: Polished marble bevel
        canvas[0, x] = [76, 68, 80, 255]

        # Row 1-2: Ornate royal crimson filigree / blood inlay line
        if (x % 8 in [2, 3, 4, 5]):
            canvas[1, x] = [150, 28, 42, 255] # glowing crimson inlay
            canvas[2, x] = [105, 18, 28, 255]
        else:
            canvas[1, x] = [58, 48, 60, 255] # dark marble
            canvas[2, x] = [44, 36, 46, 255]

        # Row 3: Inlay underline
        canvas[3, x] = [28, 20, 26, 255]

        # Row 4-7: Flagstone tile pattern
        if x % 16 == 0:
            canvas[4:8, x] = [16, 12, 16, 255]
        else:
            canvas[4, x] = [48, 40, 50, 255]
            canvas[5, x] = [38, 30, 40, 255]
            canvas[6, x] = [32, 24, 34, 255]
            canvas[7, x] = [26, 20, 28, 255]

    # Castle foundation masonry rows
    for row_y in [20, 36, 50]:
        canvas[row_y, :] = [18, 12, 16, 255]
    for x_joint in [18, 50]:
        canvas[8:20, x_joint] = [18, 12, 16, 255]
    for x_joint in [34]:
        canvas[21:36, x_joint] = [18, 12, 16, 255]

    canvas[:, -1] = canvas[:, 0]

    img = Image.fromarray(canvas, 'RGBA')
    img.save("2-dgame/assets/environment/castle/throne_gothic_floor.png")
    print("Created throne_gothic_floor.png")


def create_ramparts_ground():
    W, H = 64, 64
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(505)

    # Base cold blue/dark stone for battlements
    for y in range(H):
        t = y / float(H)
        r = int(24 * (1.0 - t * 0.6))
        g = int(28 * (1.0 - t * 0.6))
        b = int(36 * (1.0 - t * 0.6))
        canvas[y, :] = [r, g, b, 255]

    noise = np.random.randint(-4, 5, size=(H, W, 1))
    for c in range(3):
        canvas[:, :, c] = np.clip(canvas[:, :, c].astype(int) + noise[:, :, 0], 6, 250)

    # Top battlement curb (Rows 0-5)
    for x in range(W):
        if x % 10 == 0:
            canvas[0, x] = [45, 54, 68, 255]
        else:
            canvas[0, x] = [72, 85, 108, 255] # cold moonlight stone highlight
        canvas[1, x] = [52, 62, 78, 255]
        canvas[2, x] = [38, 46, 58, 255]
        canvas[3, x] = [28, 34, 44, 255]

    canvas[4, :] = [14, 16, 22, 255] # mortar seam

    # Ramparts wall blocks
    for row_y in [18, 34, 48]:
        canvas[row_y, :] = [14, 16, 22, 255]
    for x_joint in [16, 44]:
        canvas[5:18, x_joint] = [14, 16, 22, 255]
    for x_joint in [30]:
        canvas[19:34, x_joint] = [14, 16, 22, 255]

    canvas[:, -1] = canvas[:, 0]

    img = Image.fromarray(canvas, 'RGBA')
    img.save("2-dgame/assets/environment/castle/ramparts_stone_floor.png")
    print("Created ramparts_stone_floor.png")


def create_castle_platform():
    # Exactly 240 x 24 px for the one-way castle platforms
    W, H = 240, 24
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(606)

    # Fill base stone
    canvas[:, :] = [34, 32, 40, 255]
    noise = np.random.randint(-3, 4, size=(H, W, 1))
    for c in range(3):
        canvas[:, :, c] = np.clip(canvas[:, :, c].astype(int) + noise[:, :, 0], 8, 240)

    # Top walk edge (Row 0-2)
    canvas[0, :] = [74, 76, 88, 255] # flagstone top highlight
    canvas[1, :] = [56, 58, 68, 255]
    canvas[2, :] = [42, 42, 50, 255]

    # Carved gothic middle relief (Rows 6-16)
    canvas[6, :] = [20, 18, 24, 255] # carved groove
    canvas[7, :] = [48, 44, 54, 255]
    canvas[16, :] = [18, 16, 22, 255] # bottom groove

    # Underside shadow bevel (Rows 18-23)
    for y in range(18, 24):
        t = (y - 18) / 6.0
        canvas[y, :] = [int(26 * (1.0 - t * 0.5)), int(24 * (1.0 - t * 0.5)), int(30 * (1.0 - t * 0.5)), 255]

    # Forged iron bracket fittings on left and right ends (x: 0..14 and 225..239)
    for cap_range in [range(0, 14), range(226, 240)]:
        for x in cap_range:
            canvas[0, x] = [90, 85, 95, 255] # iron highlight
            canvas[1:22, x] = [45, 42, 50, 255] # dark forged iron plate
            canvas[22:24, x] = [20, 18, 24, 255]
        # Rivet studs
        center_x = 6 if cap_range.start == 0 else 233
        for ry in [5, 11, 17]:
            canvas[ry, center_x] = [120, 115, 125, 255] # rivet shine
            canvas[ry+1, center_x] = [25, 22, 28, 255]  # rivet shadow

    # Subtle decorative brackets every 60px
    for center_x in [60, 120, 180]:
        for y in range(4, 20):
            canvas[y, center_x-2:center_x+3] = [40, 36, 45, 255]
        canvas[10, center_x] = [110, 105, 118, 255]
        canvas[11, center_x] = [22, 20, 26, 255]

    img = Image.fromarray(canvas, 'RGBA')
    img.save("2-dgame/assets/environment/castle/gothic_castle_platform.png")
    print("Created gothic_castle_platform.png")


if __name__ == "__main__":
    create_forest_ground()
    create_camp_ground()
    create_bridge_ground()
    create_throne_ground()
    create_ramparts_ground()
    create_castle_platform()
    print("ALL ENVIRONMENT TEXTURES CREATED SUCCESSFULLY!")
