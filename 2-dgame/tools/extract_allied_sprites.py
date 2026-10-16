import os
import numpy as np
from PIL import Image
from scipy.ndimage import label

BASE_DIR = r"c:\Projects\2dgame\2-dgame"
OUTPUT_BASE = os.path.join(BASE_DIR, "assets", "characters", "allies")

FRAME_WIDTH = 160
FRAME_HEIGHT = 256
TARGET_BOOT_Y = 250

CONFIGS = {
    "fatih": {
        "src": r"C:\Users\bokeg\.gemini\antigravity-ide\brain\b0c00310-1e69-42a3-ab90-f2c6a5a674a6\fatih_sprite_sheet_1792014885452.jpg",
        "bg_colors": [[27, 27, 27]],
        "tol": 26,
        "anims": {
            "idle": {"row": 0, "centers": [96, 214, 331, 449, 566, 684, 801, 918]},
            "draw_sword": {"row": 1, "centers": [95, 212, 329, 446, 563, 680, 797, 913]},
            "command": {"row": 2, "centers": [95, 212, 329, 446, 563, 680, 797, 913]},
            "walk": {"row": 3, "centers": [93, 211, 329, 447, 561, 678, 796, 912]},
        }
    },
    "janissary": {
        "src": r"C:\Users\bokeg\.gemini\antigravity-ide\brain\b0c00310-1e69-42a3-ab90-f2c6a5a674a6\janissary_sprite_sheet_1792014903895.jpg",
        "bg_colors": [[54, 60, 72], [28, 31, 38], [36, 40, 48]],
        "tol": 24,
        "anims": {
            "idle": {"row": 0, "centers": [63, 193, 320, 448]},
            "walk": {"row": 1, "centers": [64, 189, 318, 447, 574, 701, 829, 955]},
            "attack": {"row": 2, "centers": [70, 194, 325, 448, 583, 704, 829, 950]},
            "death": {"row": 3, "centers": [69, 207, 406, 574, 722, 931]},
        }
    },
    "kemankes": {
        "src": r"C:\Users\bokeg\.gemini\antigravity-ide\brain\b0c00310-1e69-42a3-ab90-f2c6a5a674a6\kemankes_sprite_sheet_1792014922313.jpg",
        "bg_colors": [[52, 59, 68], [20, 23, 30], [36, 41, 49]],
        "tol": 24,
        "anims": {
            "idle": {"row": 0, "centers": [131, 309, 513, 739, 922]},
            "aim": {"row": 1, "centers": [140, 334, 527, 722, 911]},
            "attack": {"row": 2, "centers": [137, 302, 766, 929]},
            "death": {"row": 3, "centers": [122, 278, 436, 602, 751, 943]},
        }
    }
}

def clean_background(im, bg_colors, tol):
    im = im.convert("RGBA")
    arr = np.array(im).astype(float)
    rgb = arr[:, :, :3]
    
    min_dist = np.full((arr.shape[0], arr.shape[1]), 999.0)
    for bg in bg_colors:
        dist = np.linalg.norm(rgb - np.array(bg), axis=2)
        min_dist = np.minimum(min_dist, dist)
        
    ramp = 8.0
    alpha = np.clip((min_dist - (tol - 4.0)) / ramp, 0.0, 1.0) * 255.0
    # Clean threshold to avoid semi-transparent haze
    alpha = np.where(alpha < 45.0, 0.0, alpha)
    arr[:, :, 3] = alpha
    return Image.fromarray(arr.astype(np.uint8))

def clean_and_align_frame(raw_crop, target_bottom=TARGET_BOOT_Y, is_death=False):
    arr = np.array(raw_crop)
    alpha = arr[:, :, 3]
    h, w = alpha.shape
    
    # 1. Connected components analysis to eliminate stray specks and neighboring sprite leaks
    lbl, num = label(alpha > 30)
    if num == 0:
        return raw_crop
        
    sizes = [np.count_nonzero(lbl == k) for k in range(1, num+1)]
    main_k = np.argmax(sizes) + 1
    
    keep_mask = np.zeros_like(alpha, dtype=bool)
    keep_mask |= (lbl == main_k)
    
    ys_main, xs_main = np.where(lbl == main_k)
    main_bbox = (ys_main.min(), ys_main.max(), xs_main.min(), xs_main.max())
    
    for k in range(1, num+1):
        if k == main_k:
            continue
        ys, xs = np.where(lbl == k)
        sz = len(xs)
        # Discard tiny dust specks
        if sz < 40:
            continue
        # Discard neighbor sprite fragments leaking into left/right boundary
        if xs.min() <= 6 or xs.max() >= w - 7:
            continue
        # Check proximity to main body
        dist_y = max(0, main_bbox[0] - ys.max(), ys.min() - main_bbox[1])
        dist_x = max(0, main_bbox[2] - xs.max(), xs.min() - main_bbox[3])
        if dist_y < 16 and dist_x < 28:
            keep_mask |= (lbl == k)
            
    # Wipe stray components
    arr[:, :, 3] = np.where(keep_mask, arr[:, :, 3], 0)
    
    # Also wipe any stray pixels at the very bottom edge (below y=251)
    arr[252:, :, 3] = 0
    
    # 2. Foot baseline alignment
    ys, xs = np.where(arr[:, :, 3] > 30)
    if len(ys) == 0:
        return Image.fromarray(arr)
        
    curr_bottom = ys.max()
    shift_y = target_bottom - curr_bottom
    
    shifted = np.zeros_like(arr)
    if shift_y > 0:
        shifted[shift_y:, :] = arr[:h - shift_y, :]
    elif shift_y < 0:
        s = abs(shift_y)
        shifted[:h - s, :] = arr[s:, :]
    else:
        shifted = arr.copy()
        
    return Image.fromarray(shifted)

def extract_frame(cleaned_row, cx, frame_w, frame_h, is_death=False):
    w, h = cleaned_row.size
    half = frame_w // 2
    x0 = cx - half
    x1 = cx + half
    
    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    src_x0 = max(0, x0)
    src_x1 = min(w, x1)
    
    dst_x0 = src_x0 - x0
    dst_x1 = dst_x0 + (src_x1 - src_x0)
    
    crop = cleaned_row.crop((src_x0, 0, src_x1, frame_h))
    frame.paste(crop, (dst_x0, 0))
    
    # Post-process: clean stray pixels & align foot baseline to 250
    return clean_and_align_frame(frame, target_bottom=TARGET_BOOT_Y, is_death=is_death)

def process():
    for name, cfg in CONFIGS.items():
        out_dir = os.path.join(OUTPUT_BASE, name)
        os.makedirs(out_dir, exist_ok=True)
        img = Image.open(cfg["src"])
        w, h = img.size
        print(f"[{name}] Cleaning background and extracting artifact-free frames...")
        cleaned = clean_background(img, cfg["bg_colors"], cfg["tol"])
        
        master_png = os.path.join(out_dir, f"{name}_sheet.png")
        cleaned.save(master_png, "PNG")
        
        for anim_name, anim_cfg in cfg["anims"].items():
            row_idx = anim_cfg["row"]
            centers = anim_cfg["centers"]
            num_f = len(centers)
            is_death = (anim_name == "death")
            
            y0 = row_idx * 256
            y1 = y0 + 256
            row_crop = cleaned.crop((0, y0, w, y1))
            
            strip = Image.new("RGBA", (FRAME_WIDTH * num_f, FRAME_HEIGHT), (0, 0, 0, 0))
            for idx, cx in enumerate(centers):
                frame = extract_frame(row_crop, cx, FRAME_WIDTH, FRAME_HEIGHT, is_death=is_death)
                strip.paste(frame, (idx * FRAME_WIDTH, 0))
                
            strip_path = os.path.join(out_dir, f"{anim_name}.png")
            strip.save(strip_path, "PNG")
            print(f"  - Animation '{anim_name}': {num_f} frames -> {strip_path}")

if __name__ == "__main__":
    process()
    print("All allied sprites successfully cleaned and grounded.")
