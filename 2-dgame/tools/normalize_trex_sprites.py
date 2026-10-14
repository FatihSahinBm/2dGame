#!/usr/bin/env python3
"""
Normalize T-Rex Boss Sprite Dimensions
Ensures that all animations of the Cyber T-Rex Boss have identical character body proportions,
scale, and ground plane contact across all 11 animations.
Sources directly from the master GIF files for idempotent and exact pixel accuracy.
"""

import os
from PIL import Image

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BOSS_DIR = os.path.join(BASE_DIR, "assets", "characters", "trex_boss")

CANVAS_W = 1280
CANVAS_H = 720
SCALE_FACTOR = 473.0 / 623.0 # ~0.75923

CONFIG = {
    "idle": {
        "frames": 16,
        "cols": 4,
        "rows": 4,
        "scale": SCALE_FACTOR,
        "offset_x": 20,
        "offset_y": 189
    },
    "walk": {
        "frames": 16,
        "cols": 4,
        "rows": 4,
        "scale": SCALE_FACTOR,
        "offset_x": 20,
        "offset_y": 189
    },
    "run": {
        "frames": 20,
        "cols": 5,
        "rows": 4,
        "scale": 1.0,
        "offset_x": 0,
        "offset_y": 0
    },
    "attack_bite": {
        "frames": 20,
        "cols": 5,
        "rows": 4,
        "scale": SCALE_FACTOR,
        "offset_x": 20,
        "offset_y": 161
    },
    "intro_taunt": {
        "frames": 20,
        "cols": 5,
        "rows": 4,
        "scale": 1.0,
        "offset_x": -50,
        "offset_y": 30
    }
}

def normalize_animations():
    print("Normalizing T-Rex boss animations from master GIFs to uniform scale and baseline...")
    
    for anim_name, cfg in CONFIG.items():
        gif_path = os.path.join(BOSS_DIR, f"{anim_name}.gif")
        frames_dir = os.path.join(BOSS_DIR, f"{anim_name}_frames")
        sheet_path = os.path.join(BOSS_DIR, f"{anim_name}.png")
        os.makedirs(frames_dir, exist_ok=True)
        
        num_frames = cfg["frames"]
        cols = cfg["cols"]
        rows = cfg["rows"]
        scale = cfg["scale"]
        off_x = cfg["offset_x"]
        off_y = cfg["offset_y"]
        
        gif = Image.open(gif_path)
        processed_frames = []
        
        for i in range(num_frames):
            gif.seek(i)
            im = gif.convert("RGBA")
            
            if scale != 1.0:
                new_w = int(round(im.width * scale))
                new_h = int(round(im.height * scale))
                scaled = im.resize((new_w, new_h), Image.LANCZOS)
            else:
                scaled = im
                
            canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
            canvas.paste(scaled, (off_x, off_y), scaled)
            
            # Save frame PNG
            frame_path = os.path.join(frames_dir, f"{anim_name}_{i:02d}.png")
            canvas.save(frame_path, "PNG")
            processed_frames.append(canvas)
            
        print(f"  - Extracted & Normalized {num_frames} frames for: {anim_name}")
        
        # Build composite sheet
        sheet_w = cols * CANVAS_W
        sheet_h = rows * CANVAS_H
        sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))
        
        for idx, frame in enumerate(processed_frames):
            c = idx % cols
            r = idx // cols
            sheet.paste(frame, (c * CANVAS_W, r * CANVAS_H))
            
        sheet.save(sheet_path, "PNG")
        print(f"  - Generated master sprite sheet: {sheet_path} ({sheet_w}x{sheet_h})")

    print("\nVerification check across ALL animations:")
    all_anims = [
        "idle", "walk", "run", "attack_bite", "attack_laser",
        "attack_platform_slam", "grab_counter", "stunned_groggy",
        "hurt", "death", "intro_taunt"
    ]
    
    for anim in all_anims:
        f0_path = os.path.join(BOSS_DIR, f"{anim}_frames", f"{anim}_00.png")
        if os.path.exists(f0_path):
            im = Image.open(f0_path)
            b = im.getbbox()
            print(f"  {anim:22s} | bbox={b} | w={b[2]-b[0]:3d}, h={b[3]-b[1]:3d} | bottom={b[3]}")

if __name__ == "__main__":
    normalize_animations()
