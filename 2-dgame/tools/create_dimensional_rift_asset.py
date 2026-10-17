import os
from PIL import Image
import numpy as np
from scipy.ndimage import gaussian_filter

bg_path = '2-dgame/assets/backgrounds/stage_1_zone_1_time_rift.png'
out_rift_path = '2-dgame/assets/objects/dimensional_time_rift.png'
os.makedirs('2-dgame/assets/objects', exist_ok=True)

bg_img = Image.open(bg_path).convert('RGB')
arr = np.array(bg_img)
H, W, _ = arr.shape

# 1. EXTRACT RIFT
# Rift bbox in original: x=750..1020, y=40..635
rx1, rx2 = 750, 1020
ry1, ry2 = 40, 635

rift_crop = arr[ry1:ry2, rx1:rx2].astype(float)
cH, cW, _ = rift_crop.shape

# Background estimate from surrounding forest
p_left = arr[ry1:ry2, rx1 - cW : rx1].astype(float)
p_right = arr[ry1:ry2, rx2 : rx2 + cW].astype(float)

# Blend columns
blend_cols = np.linspace(0, 1, cW)[np.newaxis, :, np.newaxis]
inpaint_patch = p_left * (1 - blend_cols) + p_right * blend_cols

# Alpha computation for rift:
r, g, b = rift_crop[:,:,0], rift_crop[:,:,1], rift_crop[:,:,2]
ir, ig, ib = inpaint_patch[:,:,0], inpaint_patch[:,:,1], inpaint_patch[:,:,2]

# The rift is characterized by strong red, fiery orange/yellow, black void, and red smoke
# Red excess over background:
red_excess = np.maximum(0.0, r - ir)
# Void: very dark compared to misty background:
void_depth = np.maximum(0.0, 45.0 - np.maximum(np.maximum(r, g), b))

# Chromatic red:
is_red_glow = np.maximum(0.0, r - np.maximum(g, b) - 5.0)

# Combined alpha
alpha = np.clip(red_excess * 1.5 + is_red_glow * 2.0 + void_depth * 6.0, 0, 255)

# Smooth alpha slightly to prevent harsh cutoffs
alpha_smooth = gaussian_filter(alpha, sigma=0.8)

# Center of rift (x: 100..180) void should be fully opaque
alpha_smooth[void_depth > 10.0] = 255.0

# Any pixel with strong red is fully opaque
alpha_smooth[r > 160.0] = 255.0
alpha_smooth[alpha_smooth < 10.0] = 0.0

rift_rgba = np.zeros((cH, cW, 4), dtype=np.uint8)
# Enhance the rift colors for crisp game visual
rift_rgb = rift_crop.copy()
# Boost red vibrance slightly
rift_rgb[:,:,0] = np.clip(rift_rgb[:,:,0] * 1.1, 0, 255)
rift_rgba[:,:,:3] = rift_rgb.astype(np.uint8)
rift_rgba[:,:,3] = np.clip(alpha_smooth, 0, 255).astype(np.uint8)

# Crop tight
rift_img = Image.fromarray(rift_rgba, 'RGBA')
bbox = rift_img.getbbox()
if bbox:
    rift_tight = rift_img.crop(bbox)
else:
    rift_tight = rift_img

# Resize cleanly to a great in-game scale (e.g. 240x520)
rift_tight.save(out_rift_path)
print(f"Saved extracted rift asset: {out_rift_path} size: {rift_tight.size}")

# 2. INPAINT BACKGROUND
# Replace rift area with inpaint_patch smoothly
clean_arr = arr.copy()
# Feather blend edges:
feather = 20
mask = np.ones((cH, cW), dtype=float)
for i in range(feather):
    mask[:, i] = float(i) / feather
    mask[:, -1 - i] = float(i) / feather

inpaint_blended = arr[ry1:ry2, rx1:rx2] * (1 - mask[:,:,np.newaxis]) + inpaint_patch * mask[:,:,np.newaxis]
clean_arr[ry1:ry2, rx1:rx2] = np.clip(inpaint_blended, 0, 255).astype(np.uint8)

clean_img = Image.fromarray(clean_arr, 'RGB')
clean_img.save(bg_path)
print(f"Saved cleaned background (no flat painted rift): {bg_path}")
