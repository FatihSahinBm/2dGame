import os
import numpy as np
from PIL import Image

out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "environment", "dungeon"))
os.makedirs(out_dir, exist_ok=True)

# -------------------------------------------------------------------------
# PALETTE (Ancient Gothic Wall Crypt Stone, Dirty Bone & Worn Mineral Pigments)
# -------------------------------------------------------------------------
C_MORTAR       = [14, 13, 18, 255]     # Dark mortar joint
C_STONE_DEEP   = [22, 21, 28, 255]     # Deep carved shadow / chisel groove
C_STONE_DARK   = [36, 35, 44, 255]     # Shadowed ashlar stone
C_STONE_MID    = [52, 52, 62, 255]     # Base gray crypt stone
C_STONE_LIGHT  = [72, 73, 86, 255]     # Stone highlight
C_STONE_HI     = [98, 100, 114, 255]   # Chiseled ridge catchlight

C_BONE_DIRTY   = [92, 88, 76, 255]     # Worn bone sediment / ancient calcified dust
C_BONE_LIGHT   = [128, 122, 108, 255]  # Bone dust highlight in crevices
C_PURPLE_SHADOW= [28, 18, 34, 255]     # Very subtle archaic purple mineral shadow

CLEAR = [0, 0, 0, 0]

def generate_heart_relief():
    W, H = 64, 64
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    np.random.seed(420)

    # 1. Base Stone Tablet / Ashlar Wall Slab (x: 2 to 62, y: 2 to 62)
    # Outer dark mortar border
    for y in range(H):
        for x in range(W):
            if x >= 2 and x < W - 2 and y >= 2 and y < H - 2:
                # Stone base fill
                canvas[y, x] = C_STONE_MID
            else:
                canvas[y, x] = CLEAR

    # Beveled Stone Slab Frame
    canvas[2, 2:W-2] = C_STONE_HI
    canvas[3, 3:W-3] = C_STONE_LIGHT
    canvas[H-3, 2:W-2] = C_STONE_DEEP
    canvas[H-4, 3:W-3] = C_STONE_DARK
    canvas[2:H-2, 2] = C_STONE_HI
    canvas[2:H-2, W-3] = C_STONE_DEEP

    # Subtle stone surface noise (organic masonry texture)
    noise = np.random.randint(-4, 5, size=(H, W, 1))
    for c in range(3):
        canvas[4:H-4, 4:W-4, c] = np.clip(canvas[4:H-4, 4:W-4, c].astype(int) + noise[4:H-4, 4:W-4, 0], 15, 230)

    # Crypt dust / calcified bone sediment settled on top horizontal edges
    canvas[4, 6:W-6] = C_BONE_DIRTY
    canvas[5, 10:W-10] = C_BONE_LIGHT

    # 2. Recessed Gothic Arch Alcove (Sunken oval area where the heart is carved)
    cx, cy = 32, 33
    for y in range(8, 56):
        for x in range(8, 56):
            dx = (x - cx) / 22.0
            dy = (y - cy) / 22.0
            dist_sq = dx*dx + dy*dy
            if dist_sq < 1.0:
                # Recessed alcove base is slightly darker
                canvas[y, x] = C_STONE_DARK
                if dist_sq > 0.85:
                    # Chiseled bevel edge around alcove
                    if y < cy:
                        canvas[y, x] = C_STONE_DEEP
                    else:
                        canvas[y, x] = C_STONE_LIGHT

    # 3. Carved Broken Heart Bas-Relief
    # Mathematical heart formula: (x^2 + y^2 - 1)^3 - x^2 * y^3 <= 0
    # Center around (32, 32), radius ~16 pixels
    heart_mask = np.zeros((H, W), dtype=bool)
    for y in range(14, 52):
        for x in range(14, 50):
            # Scale coordinates into standard heart space: x in [-1.4, 1.4], y in [-1.4, 1.4]
            nx = (x - 32) / 12.5
            ny = -(y - 31) / 12.5  # Invert y so top lobes are above center

            val = (nx**2 + ny**2 - 1.0)**3 - (nx**2) * (ny**3)
            if val <= 0.0:
                heart_mask[y, x] = True

    # Fill heart with raised bas-relief stone tone
    for y in range(H):
        for x in range(W):
            if heart_mask[y, x]:
                canvas[y, x] = C_STONE_LIGHT
                # Bone dust deposits in the heart curves
                if (x + y) % 7 == 0:
                    canvas[y, x] = C_BONE_DIRTY

    # Heart bevel / 3D carved rim
    for y in range(1, H-1):
        for x in range(1, W-1):
            if heart_mask[y, x]:
                # Top/Left highlight, Bottom/Right shadow
                if not heart_mask[y-1, x] or not heart_mask[y, x-1]:
                    canvas[y, x] = C_STONE_HI
                elif not heart_mask[y+1, x] or not heart_mask[y, x+1]:
                    canvas[y, x] = C_STONE_DEEP

    # 4. Jagged Central Fissure (Torn / Shattered rift dividing the heart into two halves)
    # The fissure pulls apart violently with a 2-3 pixel chasm
    fissure_pts = [
        (32, 18), (31, 20), (33, 23), (30, 26), (34, 29),
        (29, 32), (33, 35), (31, 38), (34, 41), (32, 44), (32, 48)
    ]

    for i in range(len(fissure_pts) - 1):
        p1 = fissure_pts[i]
        p2 = fissure_pts[i+1]
        steps = max(abs(p2[0] - p1[0]), abs(p2[1] - p1[1])) * 2
        for s in range(steps + 1):
            t = s / float(steps)
            fx = int(p1[0] + t * (p2[0] - p1[0]))
            fy = int(p1[1] + t * (p2[1] - p1[1]))
            # Carve deep groove
            for ox in [-1, 0, 1]:
                canvas[fy, fx + ox] = C_STONE_DEEP
            # Subtle purple shadow in deep rift
            canvas[fy, fx] = C_PURPLE_SHADOW
            # Fractured jagged highlight edge on the right half
            if fx + 2 < W:
                canvas[fy, fx + 2] = C_STONE_HI

    # Radiating branch cracks (spreading out across the tablet)
    branch_cracks = [
        [(33, 23), (37, 21), (42, 23), (48, 20)],
        [(30, 26), (25, 27), (21, 25), (15, 28)],
        [(34, 29), (39, 33), (44, 32), (50, 36)],
        [(31, 38), (26, 41), (22, 40), (16, 45)],
    ]
    for branch in branch_cracks:
        for i in range(len(branch) - 1):
            p1, p2 = branch[i], branch[i+1]
            steps = max(abs(p2[0] - p1[0]), abs(p2[1] - p1[1])) * 2
            for s in range(steps + 1):
                t = s / float(steps)
                bx = int(p1[0] + t * (p2[0] - p1[0]))
                by = int(p1[1] + t * (p2[1] - p1[1]))
                canvas[by, bx] = C_STONE_DEEP
                if s % 2 == 0:
                    canvas[by - 1, bx] = C_STONE_HI

    # Save relief base
    base_img = Image.fromarray(canvas, 'RGBA')
    base_path = os.path.join(out_dir, "ancient_heart_relief.png")
    base_img.save(base_path)
    print("Created ancient_heart_relief.png (64x64)")

    # -------------------------------------------------------------------------
    # 5. Glow / Resonance Overlay (Deep amethyst / purple vein pulse)
    # -------------------------------------------------------------------------
    glow_canvas = np.zeros((H, W, 4), dtype=np.uint8)
    C_GLOW_CORE = [210, 120, 255, 255] # Amethyst core
    C_GLOW_MID  = [150, 60, 220, 180]  # Ethereal violet
    C_GLOW_EDGE = [90, 20, 160, 90]    # Outer dark aura

    for i in range(len(fissure_pts) - 1):
        p1 = fissure_pts[i]
        p2 = fissure_pts[i+1]
        steps = max(abs(p2[0] - p1[0]), abs(p2[1] - p1[1])) * 2
        for s in range(steps + 1):
            t = s / float(steps)
            fx = int(p1[0] + t * (p2[0] - p1[0]))
            fy = int(p1[1] + t * (p2[1] - p1[1]))
            # Glow core
            glow_canvas[fy, fx] = C_GLOW_CORE
            for ox in [-1, 1]:
                glow_canvas[fy, fx + ox] = C_GLOW_MID
            for ox in [-2, 2]:
                glow_canvas[fy, fx + ox] = C_GLOW_EDGE

    # Faint branch cracks glow
    for branch in branch_cracks:
        for i in range(len(branch) - 1):
            p1, p2 = branch[i], branch[i+1]
            steps = max(abs(p2[0] - p1[0]), abs(p2[1] - p1[1])) * 2
            for s in range(steps + 1):
                t = s / float(steps)
                bx = int(p1[0] + t * (p2[0] - p1[0]))
                by = int(p1[1] + t * (p2[1] - p1[1]))
                glow_canvas[by, bx] = C_GLOW_MID

    glow_img = Image.fromarray(glow_canvas, 'RGBA')
    glow_path = os.path.join(out_dir, "ancient_heart_relief_glow.png")
    glow_img.save(glow_path)
    print("Created ancient_heart_relief_glow.png (64x64)")


if __name__ == "__main__":
    generate_heart_relief()
