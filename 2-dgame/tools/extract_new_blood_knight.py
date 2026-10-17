import os
from PIL import Image
import numpy as np

src_path = r'C:\Users\bokeg\.gemini\antigravity-ide\brain\61d92e86-99a3-4e61-b69b-dd9c5051b881\blood_knight_redesign_1792246041485.jpg'
out_dir = r'2-dgame/assets/characters/enemies/blood_knight'
os.makedirs(out_dir, exist_ok=True)

im = Image.open(src_path).convert('RGB')
arr = np.array(im).astype(float)
H, W, _ = arr.shape
r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]

# Slate background detection
is_bg = (g >= r - 2) & (b >= g - 2) & (g - r <= 18) & (b - g <= 18) & (r >= 45) & (r <= 135)
fg_mask = ~is_bg

# Create RGBA array
rgba = np.zeros((H, W, 4), dtype=np.uint8)
rgba[:, :, :3] = np.array(im)
rgba[:, :, 3] = np.where(fg_mask, 255, 0).astype(np.uint8)

# Soft edge cleaning: if a pixel is semi-background near edge, smooth it
from scipy.ndimage import binary_erosion
eroded = binary_erosion(fg_mask)
edge = fg_mask & ~eroded

rows_info = [
    ('idle', 20, 205, [(40, 158), (179, 312), (328, 460), (496, 643)]),
    ('walk', 220, 415, [(41, 188), (208, 352), (367, 512), (524, 661), (673, 818)]),
    ('attack', 415, 630, [(24, 156), (198, 314), (330, 487), (505, 662), (666, 839), (859, 1015)]),
    ('hurt', 630, 810, [(0, 155), (163, 327), (348, 508)]),
    ('death', 815, 1020, [(1, 151), (179, 346), (361, 536), (554, 764), (792, 1007)])
]

FRAME_W = 180
FRAME_H = 190
FEET_Y = 175

full_rgba_img = Image.fromarray(rgba, 'RGBA')

for anim_name, y1, y2, cols in rows_info:
    strip = Image.new('RGBA', (FRAME_W * len(cols), FRAME_H), (0, 0, 0, 0))
    for i, (x1, x2) in enumerate(cols):
        # Crop character box
        char_crop = full_rgba_img.crop((x1, y1, x2, y2))
        bbox = char_crop.getbbox()
        if bbox:
            char_tight = char_crop.crop(bbox)
        else:
            char_tight = char_crop
        
        tw, th = char_tight.size
        # Center horizontally, place feet at FEET_Y
        target_x = (FRAME_W - tw) // 2
        target_y = FEET_Y - th
        if target_y < 0:
            # Scale slightly down if it exceeds FRAME_H (e.g. big slash)
            scale_fac = (FRAME_H - 10) / th
            char_tight = char_tight.resize((int(tw * scale_fac), int(th * scale_fac)), Image.Resampling.LANCZOS)
            tw, th = char_tight.size
            target_x = (FRAME_W - tw) // 2
            target_y = FEET_Y - th
        
        # Save individual frame
        single_frame = Image.new('RGBA', (FRAME_W, FRAME_H), (0, 0, 0, 0))
        single_frame.paste(char_tight, (target_x, target_y), char_tight)
        frame_fname = os.path.join(out_dir, f"{anim_name}_{i}.png")
        single_frame.save(frame_fname)
        
        # Paste into strip
        strip.paste(char_tight, (i * FRAME_W + target_x, target_y), char_tight)
    
    strip_fname = os.path.join(out_dir, f"{anim_name}.png")
    strip.save(strip_fname)
    print(f"Saved {anim_name} strip: {strip_fname} size: {strip.size}")

print("Blood Knight sprite extraction complete!")
