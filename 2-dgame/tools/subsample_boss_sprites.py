#!/usr/bin/env python3
"""
Subsample Boss Sprites (Vlad, Ogre, Necromancer)
- Subsamples high-frame animations down to indie-grade 16-24 frames using uniform striding.
- Generates compact, optimized sprite sheet PNGs.
- Rebuilds Godot 4 .tres SpriteFrames with matching Rect2 atlas regions and smooth framerates (10-16 FPS).
- Updates JSON manifests.
- Cleans redundant raw frame dumps (frames/*.png) and videos (.mp4, .gif) to reclaim >1.17 GB disk space.
"""

import os
import sys
import math
import json
import re
import shutil
from PIL import Image

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS_DIR = os.path.join(BASE_DIR, "assets", "characters")

def get_sample_indices(N: int, K: int, is_loop: bool) -> list[int]:
    """Uniform frame sampling to ensure completely smooth motion without visual stutter."""
    if K >= N:
        return list(range(N))
    if is_loop:
        indices = [int(round(i * N / float(K))) % N for i in range(K)]
    else:
        indices = [int(round(i * (N - 1) / float(K - 1))) for i in range(K)]
    for i in range(1, len(indices)):
        if indices[i] <= indices[i - 1]:
            indices[i] = indices[i - 1] + 1
    return indices

def process_sheet(image_path: str, cell_w: int, cell_h: int, orig_cols: int, target_k: int, is_loop: bool):
    """Loads image, crops frames, samples target_k, and rewrites compact sheet."""
    with Image.open(image_path) as im:
        im = im.convert("RGBA")
        total_cells = (im.width // cell_w) * (im.height // cell_h)
        cols = orig_cols
        
        sample_indices = get_sample_indices(total_cells, target_k, is_loop)
        
        frames = []
        for idx in sample_indices:
            c = idx % cols
            r = idx // cols
            x0 = c * cell_w
            y0 = r * cell_h
            x1 = x0 + cell_w
            y1 = y0 + cell_h
            if x1 <= im.width and y1 <= im.height:
                frame = im.crop((x0, y0, x1, y1))
            else:
                frame = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
            frames.append(frame)
            
        new_cols = min(cols, target_k)
        new_rows = math.ceil(target_k / float(new_cols))
        new_w = new_cols * cell_w
        new_h = new_rows * cell_h
        
        new_sheet = Image.new("RGBA", (new_w, new_h), (0, 0, 0, 0))
        for i, frame in enumerate(frames):
            c = i % new_cols
            r = i // new_cols
            new_sheet.paste(frame, (c * cell_w, r * cell_h))
            
        temp_path = image_path + ".tmp.png"
        new_sheet.save(temp_path, "PNG", optimize=True, compress_level=9)
        if os.path.exists(image_path):
            os.remove(image_path)
        os.rename(temp_path, image_path)
        
        return len(frames), new_cols, new_rows, (new_w, new_h), sample_indices

def get_folder_size(path: str) -> int:
    total = 0
    if not os.path.exists(path):
        return 0
    for r, d, files in os.walk(path):
        for f in files:
            total += os.path.getsize(os.path.join(r, f))
    return total

def build_tres_content(uid: str, ext_resources: list[dict], sub_resources: list[dict], animations: list[dict]) -> str:
    lines = []
    lines.append(f'[gd_resource type="SpriteFrames" format=3 uid="{uid}"]\n')
    
    for ext in ext_resources:
        lines.append(f'[ext_resource type="Texture2D" uid="{ext["uid"]}" path="{ext["path"]}" id="{ext["id"]}"]')
    lines.append("")
    
    for sub in sub_resources:
        r = sub["region"]
        lines.append(f'[sub_resource type="AtlasTexture" id="{sub["id"]}"]')
        lines.append(f'atlas = ExtResource("{sub["ext_id"]}")')
        lines.append(f'region = Rect2({int(r[0])}, {int(r[1])}, {int(r[2])}, {int(r[3])})\n')
        
    lines.append("[resource]")
    lines.append("animations = [{")
    for anim_idx, anim in enumerate(animations):
        lines.append('"frames": [')
        frame_items = []
        for fid in anim["frames"]:
            frame_items.append('{\n"duration": 1.0,\n"texture": SubResource("' + fid + '")\n}')
        lines.append(', '.join(frame_items) + '],')
        lines.append(f'"loop": {1 if anim["loop"] else 0},')
        lines.append(f'"name": &"{anim["name"]}",')
        lines.append(f'"speed": {anim["speed"]:.1f}')
        if anim_idx < len(animations) - 1:
            lines.append("}, {")
        else:
            lines.append("}]")
    lines.append("")
    return '\n'.join(lines)

def run():
    print("================================================================================")
    print("STARTING BOSS SPRITE SUBSAMPLING AND MEMORY OPTIMIZATION")
    print("================================================================================")
    
    initial_vlad_sz = get_folder_size(os.path.join(ASSETS_DIR, "vlad_all_animations"))
    initial_ogre_sz = get_folder_size(os.path.join(ASSETS_DIR, "ogre_all_animations"))
    initial_necro_sz = get_folder_size(os.path.join(ASSETS_DIR, "necromancer_all_animations"))
    total_initial = initial_vlad_sz + initial_ogre_sz + initial_necro_sz
    print(f"Initial total boss folder size: {total_initial / (1024*1024):.2f} MB")
    print(f"  - Vlad: {initial_vlad_sz / (1024*1024):.2f} MB")
    print(f"  - Ogre: {initial_ogre_sz / (1024*1024):.2f} MB")
    print(f"  - Necromancer: {initial_necro_sz / (1024*1024):.2f} MB\n")
    
    # --------------------------------------------------------------------------
    # 1. OPTIMIZE VLAD
    # --------------------------------------------------------------------------
    print(">>> 1. Processing Vlad the Impaler...")
    vlad_dir = os.path.join(ASSETS_DIR, "vlad_all_animations")
    vlad_tres_path = os.path.join(vlad_dir, "vlad_frames.tres")
    
    # Read existing ext_resources from vlad_frames.tres to keep UIDs
    with open(vlad_tres_path, "r", encoding="utf-8") as f:
        vlad_tres_raw = f.read()
    vlad_uid_match = re.search(r'uid="(uid://[^"]+)"', vlad_tres_raw)
    vlad_tres_uid = vlad_uid_match.group(1) if vlad_uid_match else "uid://cbem3r2n0qvhb"
    
    vlad_exts = {}
    for match in re.finditer(r'\[ext_resource type="Texture2D" uid="([^"]+)" path="([^"]+)" id="([^"]+)"\]', vlad_tres_raw):
        uid, path, res_id = match.groups()
        vlad_exts[res_id] = {"uid": uid, "path": path, "id": res_id}
        
    # Sheet configs: (folder, prefix, cell_w, cell_h, orig_cols, target_k, is_loop, speed, ext_id)
    vlad_sheet_configs = [
        ("01_normal_idle", "01_normal_idle", 160, 180, 8, 19, True, 10.0, "1_01_normal_idle"),
        ("02_normal_walk", "02_normal_walk", 160, 180, 8, 19, True, 12.0, "2_02_normal_walk"),
        ("03_normal_attack_thrust", "03_normal_attack_thrust", 320, 180, 6, 20, False, 14.0, "3_03_normal_attack_thrust"),
        ("04_normal_attack_impale", "04_normal_attack_impale", 320, 180, 6, 23, False, 14.0, "4_04_normal_attack_impale"),
        ("05_vampire_idle", "05_vampire_idle", 320, 180, 6, 19, True, 10.0, "5_05_vampire_idle"),
        ("06_vampire_glide", "06_vampire_glide", 320, 180, 6, 19, True, 12.0, "6_06_vampire_glide"),
        ("07_vampire_attack_slash", "07_vampire_attack_slash", 320, 180, 6, 21, False, 14.0, "7_07_vampire_attack_slash"),
        ("08_vampire_attack_blood_magic", "08_vampire_attack_blood_magic", 320, 180, 6, 21, False, 14.0, "8_08_vampire_attack_blood_magic"),
        ("09_werewolf_idle", "09_werewolf_idle", 320, 180, 6, 19, True, 10.0, "9_09_werewolf_idle"),
        ("10_werewolf_run", "10_werewolf_run", 320, 180, 6, 24, True, 16.0, "10_10_werewolf_run"),
        ("11_werewolf_attack_claws", "11_werewolf_attack_claws", 320, 180, 6, 24, False, 16.0, "11_11_werewolf_attack_claws"),
        ("12_werewolf_attack_leap", "12_werewolf_attack_leap", 320, 180, 6, 24, False, 14.0, "12_12_werewolf_attack_leap"),
        ("13_bat_idle_fly", "13_bat_idle_fly", 320, 180, 6, 16, True, 12.0, "13_13_bat_idle_fly"),
        ("14_bat_attack_dive", "14_bat_attack_dive", 320, 180, 6, 24, False, 16.0, "14_14_bat_attack_dive"),
        ("15_bat_attack_screech", "15_bat_attack_screech", 320, 180, 6, 24, False, 16.0, "15_15_bat_attack_screech"),
        ("16_transform_blood_smoke", "16_transform_blood_smoke", 320, 180, 6, 24, False, 16.0, "16_16_transform_blood_smoke"),
        ("17_vlad_hurt", "17_vlad_hurt", 320, 180, 6, 24, False, 16.0, "17_17_vlad_hurt"),
        ("18_vlad_death", "18_vlad_death", 320, 180, 6, 24, False, 14.0, "18_18_vlad_death"),
        ("19_vampire_hurt", "19_vampire_hurt", 320, 180, 6, 24, False, 16.0, "19_19_vampire_hurt"),
        ("20_werewolf_hurt", "20_werewolf_hurt", 320, 180, 6, 24, False, 16.0, "20_20_werewolf_hurt"),
        ("21_bat_hurt", "21_bat_hurt", 320, 180, 6, 24, False, 16.0, "21_21_bat_hurt"),
        ("vfx_blood_smoke_burst", "vfx_blood_smoke_burst", 320, 180, 6, 18, False, 16.0, "22_vfx_blood_smoke_burst"),
    ]
    
    vlad_subs = []
    vlad_sheet_data = {} # prefix -> { 'frames': [...], 'speed': ... }
    
    for folder, prefix, cw, ch, ocols, tk, loop, speed, ext_id in vlad_sheet_configs:
        sheet_path = os.path.join(vlad_dir, folder, "sprite_sheet.png")
        if os.path.exists(sheet_path):
            n_frames, ncols, nrows, new_dim, indices = process_sheet(sheet_path, cw, ch, ocols, tk, loop)
            print(f"  [Vlad] {folder:30} -> {n_frames} frames ({new_dim[0]}x{new_dim[1]}), speed {speed} FPS")
            
            frame_ids = []
            for i in range(n_frames):
                sub_id = f"Atlas_{prefix}_{i}"
                c = i % ncols
                r = i // ncols
                rect = (c * cw, r * ch, cw, ch)
                vlad_subs.append({
                    "id": sub_id,
                    "ext_id": ext_id,
                    "region": rect
                })
                frame_ids.append(sub_id)
            vlad_sheet_data[prefix] = {
                "frames": frame_ids,
                "speed": speed,
                "loop": loop,
                "count": n_frames,
                "dimensions": new_dim
            }
            
        # Remove redundant unreferenced frames/ folders and videos in this folder
        frames_dir = os.path.join(vlad_dir, folder, "frames")
        if os.path.exists(frames_dir):
            shutil.rmtree(frames_dir)
        for junk_file in ["preview.gif", "preview.mp4", "prompt.txt"]:
            jp = os.path.join(vlad_dir, folder, junk_file)
            if os.path.exists(jp):
                os.remove(jp)
                
    # Define Vlad's 28 animations
    vlad_anim_definitions = [
        ("attack_impale", "04_normal_attack_impale", False, 14.0),
        ("attack_thrust", "03_normal_attack_thrust", False, 14.0),
        ("bat_attack_dive", "14_bat_attack_dive", False, 16.0),
        ("bat_attack_screech", "15_bat_attack_screech", False, 16.0),
        ("bat_hurt", "21_bat_hurt", False, 16.0),
        ("bat_idle_fly", "13_bat_idle_fly", True, 12.0),
        ("death", "18_vlad_death", False, 14.0),
        ("hurt", "17_vlad_hurt", False, 16.0),
        ("idle", "01_normal_idle", True, 10.0),
        ("normal_attack_impale", "04_normal_attack_impale", False, 14.0),
        ("normal_attack_thrust", "03_normal_attack_thrust", False, 14.0),
        ("normal_death", "18_vlad_death", False, 14.0),
        ("normal_hurt", "17_vlad_hurt", False, 16.0),
        ("normal_idle", "01_normal_idle", True, 10.0),
        ("normal_walk", "02_normal_walk", True, 12.0),
        ("transform_blood_smoke", "16_transform_blood_smoke", False, 16.0),
        ("vampire_attack_blood_magic", "08_vampire_attack_blood_magic", False, 14.0),
        ("vampire_attack_slash", "07_vampire_attack_slash", False, 14.0),
        ("vampire_glide", "06_vampire_glide", True, 12.0),
        ("vampire_hurt", "19_vampire_hurt", False, 16.0),
        ("vampire_idle", "05_vampire_idle", True, 10.0),
        ("vfx_blood_smoke_burst", "vfx_blood_smoke_burst", False, 16.0),
        ("walk", "02_normal_walk", True, 12.0),
        ("werewolf_attack_claws", "11_werewolf_attack_claws", False, 16.0),
        ("werewolf_attack_leap", "12_werewolf_attack_leap", False, 14.0),
        ("werewolf_hurt", "20_werewolf_hurt", False, 16.0),
        ("werewolf_idle", "09_werewolf_idle", True, 10.0),
        ("werewolf_run", "10_werewolf_run", True, 16.0),
    ]
    
    vlad_anims = []
    for anim_name, prefix, loop, speed in vlad_anim_definitions:
        data = vlad_sheet_data.get(prefix)
        if data:
            vlad_anims.append({
                "name": anim_name,
                "frames": data["frames"],
                "loop": loop,
                "speed": speed
            })
            
    vlad_ext_list = [vlad_exts[k] for k in sorted(vlad_exts.keys(), key=lambda x: int(x.split('_')[0]) if x.split('_')[0].isdigit() else 999)]
    vlad_tres_content = build_tres_content(vlad_tres_uid, vlad_ext_list, vlad_subs, vlad_anims)
    with open(vlad_tres_path, "w", encoding="utf-8") as f:
        f.write(vlad_tres_content)
    print(f"  [OK] Saved updated {vlad_tres_path} ({len(vlad_anims)} animations, {len(vlad_subs)} atlas textures).")
    
    # Update Vlad manifest.json
    vlad_man_path = os.path.join(vlad_dir, "manifest.json")
    if os.path.exists(vlad_man_path):
        with open(vlad_man_path, "r", encoding="utf-8") as f:
            vlad_man = json.load(f)
        for item in vlad_man.get("animations", []):
            folder = item.get("folder")
            if folder in vlad_sheet_data:
                d = vlad_sheet_data[folder]
                item["frame_count"] = d["count"]
                item["framerate"] = d["speed"]
                item["duration_seconds"] = round(d["count"] / d["speed"], 3)
                item["sheet_dimensions"] = list(d["dimensions"])
        with open(vlad_man_path, "w", encoding="utf-8") as f:
            json.dump(vlad_man, f, indent=2)
        print(f"  [OK] Updated Vlad manifest.json.")

    # --------------------------------------------------------------------------
    # 2. OPTIMIZE OGRE
    # --------------------------------------------------------------------------
    print("\n>>> 2. Processing Green Ogre Boss...")
    ogre_dir = os.path.join(ASSETS_DIR, "ogre_all_animations")
    ogre_tres_path = os.path.join(ogre_dir, "ogre_frames.tres")
    
    with open(ogre_tres_path, "r", encoding="utf-8") as f:
        ogre_tres_raw = f.read()
    ogre_uid_match = re.search(r'uid="(uid://[^"]+)"', ogre_tres_raw)
    ogre_tres_uid = ogre_uid_match.group(1) if ogre_uid_match else "uid://d38dsr2wjqvqg"
    
    ogre_exts = {}
    for match in re.finditer(r'\[ext_resource type="Texture2D" uid="([^"]+)" path="([^"]+)" id="([^"]+)"\]', ogre_tres_raw):
        uid, path, res_id = match.groups()
        ogre_exts[res_id] = {"uid": uid, "path": path, "id": res_id}
        
    ogre_configs = [
        ("ogre_idle.png", "idle", 624, 304, 6, 18, True, 10.0, "1_idle"),
        ("ogre_walk.png", "walk", 624, 304, 6, 19, True, 12.0, "2_walk"),
        ("ogre_attack.png", "attack", 624, 304, 6, 19, False, 12.0, "3_attack"),
        ("ogre_hurt.png", "hurt", 624, 304, 6, 19, False, 14.0, "4_hurt"),
        ("ogre_death.png", "death", 624, 304, 6, 20, False, 12.0, "5_death"),
    ]
    
    ogre_subs = []
    ogre_sheet_data = {}
    
    for filename, prefix, cw, ch, ocols, tk, loop, speed, ext_id in ogre_configs:
        sheet_path = os.path.join(ogre_dir, filename)
        if os.path.exists(sheet_path):
            n_frames, ncols, nrows, new_dim, indices = process_sheet(sheet_path, cw, ch, ocols, tk, loop)
            print(f"  [Ogre] {filename:25} -> {n_frames} frames ({new_dim[0]}x{new_dim[1]}), speed {speed} FPS")
            frame_ids = []
            for i in range(n_frames):
                sub_id = f"Atlas_{prefix}_{i}"
                c = i % ncols
                r = i // ncols
                rect = (c * cw, r * ch, cw, ch)
                ogre_subs.append({
                    "id": sub_id,
                    "ext_id": ext_id,
                    "region": rect
                })
                frame_ids.append(sub_id)
            ogre_sheet_data[prefix] = {
                "frames": frame_ids,
                "speed": speed,
                "loop": loop,
                "count": n_frames,
                "dimensions": new_dim
            }
            
    # Clean redundant directories in ogre
    for d in ["01_walk", "02_idle", "03_attack", "04_hurt", "05_death", "source_videos"]:
        dp = os.path.join(ogre_dir, d)
        if os.path.exists(dp):
            shutil.rmtree(dp)
            
    ogre_anim_definitions = [
        ("attack", "attack", False, 12.0),
        ("death", "death", False, 12.0),
        ("hit", "hurt", False, 14.0),
        ("hurt", "hurt", False, 14.0),
        ("idle", "idle", True, 10.0),
        ("walk", "walk", True, 12.0),
    ]
    
    ogre_anims = []
    for anim_name, prefix, loop, speed in ogre_anim_definitions:
        data = ogre_sheet_data.get(prefix)
        if data:
            ogre_anims.append({
                "name": anim_name,
                "frames": data["frames"],
                "loop": loop,
                "speed": speed
            })
            
    ogre_ext_list = [ogre_exts[k] for k in sorted(ogre_exts.keys())]
    ogre_tres_content = build_tres_content(ogre_tres_uid, ogre_ext_list, ogre_subs, ogre_anims)
    with open(ogre_tres_path, "w", encoding="utf-8") as f:
        f.write(ogre_tres_content)
    print(f"  [OK] Saved updated {ogre_tres_path} ({len(ogre_anims)} animations, {len(ogre_subs)} atlas textures).")
    
    # Update Ogre character_manifest.json
    ogre_man_path = os.path.join(ogre_dir, "character_manifest.json")
    if os.path.exists(ogre_man_path):
        with open(ogre_man_path, "r", encoding="utf-8") as f:
            ogre_man = json.load(f)
        for act_name, d in ogre_sheet_data.items():
            if "animations" in ogre_man and act_name in ogre_man["animations"]:
                item = ogre_man["animations"][act_name]
                item["frameCount"] = d["count"]
                item["durationSeconds"] = round(d["count"] / d["speed"], 3)
                if "spriteSheetLayout" in item:
                    item["spriteSheetLayout"]["totalFrames"] = d["count"]
        with open(ogre_man_path, "w", encoding="utf-8") as f:
            json.dump(ogre_man, f, indent=2)
        print(f"  [OK] Updated Ogre character_manifest.json.")

    # --------------------------------------------------------------------------
    # 3. OPTIMIZE NECROMANCER
    # --------------------------------------------------------------------------
    print("\n>>> 3. Processing Dark Necromancer...")
    necro_dir = os.path.join(ASSETS_DIR, "necromancer_all_animations")
    necro_tres_path = os.path.join(necro_dir, "necromancer_frames.tres")
    
    with open(necro_tres_path, "r", encoding="utf-8") as f:
        necro_tres_raw = f.read()
    necro_uid_match = re.search(r'uid="(uid://[^"]+)"', necro_tres_raw)
    necro_tres_uid = necro_uid_match.group(1) if necro_uid_match else "uid://hx4e555kqhbx"
    
    necro_exts = {}
    for match in re.finditer(r'\[ext_resource type="Texture2D" uid="([^"]+)" path="([^"]+)" id="([^"]+)"\]', necro_tres_raw):
        uid, path, res_id = match.groups()
        necro_exts[res_id] = {"uid": uid, "path": path, "id": res_id}
        
    necro_configs = [
        ("necromancer_idle.png", "idle", 96, 80, 8, 21, True, 10.0, "1_idle"),
        ("necromancer_walk.png", "walk", 96, 80, 8, 20, True, 12.0, "2_walk"),
        ("necromancer_attack_magic.png", "attack_magic", 96, 80, 8, 20, False, 14.0, "3_magic"),
        ("necromancer_attack_melee.png", "attack_melee", 96, 80, 8, 22, False, 14.0, "4_melee"),
        ("necromancer_hurt.png", "hurt", 96, 80, 8, 16, False, 14.0, "5_hurt"),
        ("necromancer_death.png", "death", 96, 80, 8, 22, False, 14.0, "6_death"),
    ]
    
    necro_subs = []
    necro_sheet_data = {}
    
    for filename, prefix, cw, ch, ocols, tk, loop, speed, ext_id in necro_configs:
        sheet_path = os.path.join(necro_dir, filename)
        if os.path.exists(sheet_path):
            n_frames, ncols, nrows, new_dim, indices = process_sheet(sheet_path, cw, ch, ocols, tk, loop)
            print(f"  [Necro] {filename:30} -> {n_frames} frames ({new_dim[0]}x{new_dim[1]}), speed {speed} FPS")
            frame_ids = []
            for i in range(n_frames):
                sub_id = f"Atlas_{prefix}_{i}"
                c = i % ncols
                r = i // ncols
                rect = (c * cw, r * ch, cw, ch)
                necro_subs.append({
                    "id": sub_id,
                    "ext_id": ext_id,
                    "region": rect
                })
                frame_ids.append(sub_id)
            necro_sheet_data[prefix] = {
                "frames": frame_ids,
                "speed": speed,
                "loop": loop,
                "count": n_frames,
                "dimensions": new_dim
            }
            
    # Clean redundant directories and showcase in necro
    for d in ["01_idle", "02_walk", "03_attack_magic", "04_attack_melee", "05_hurt", "06_death", "raw_videos"]:
        dp = os.path.join(necro_dir, d)
        if os.path.exists(dp):
            shutil.rmtree(dp)
    for junk_file in ["necromancer_all_actions_showcase.gif"]:
        jp = os.path.join(necro_dir, junk_file)
        if os.path.exists(jp):
            os.remove(jp)
            
    necro_anim_definitions = [
        ("attack_magic", "attack_magic", False, 14.0),
        ("attack_melee", "attack_melee", False, 14.0),
        ("death", "death", False, 14.0),
        ("hurt", "hurt", False, 14.0),
        ("idle", "idle", True, 10.0),
        ("walk", "walk", True, 12.0),
    ]
    
    necro_anims = []
    for anim_name, prefix, loop, speed in necro_anim_definitions:
        data = necro_sheet_data.get(prefix)
        if data:
            necro_anims.append({
                "name": anim_name,
                "frames": data["frames"],
                "loop": loop,
                "speed": speed
            })
            
    necro_ext_list = [necro_exts[k] for k in sorted(necro_exts.keys())]
    necro_tres_content = build_tres_content(necro_tres_uid, necro_ext_list, necro_subs, necro_anims)
    with open(necro_tres_path, "w", encoding="utf-8") as f:
        f.write(necro_tres_content)
    print(f"  [OK] Saved updated {necro_tres_path} ({len(necro_anims)} animations, {len(necro_subs)} atlas textures).")
    
    # Update Necro manifest.json
    necro_man_path = os.path.join(necro_dir, "manifest.json")
    if os.path.exists(necro_man_path):
        with open(necro_man_path, "r", encoding="utf-8") as f:
            necro_man = json.load(f)
        if "actions" in necro_man:
            for act_name, d in necro_sheet_data.items():
                if act_name in necro_man["actions"]:
                    item = necro_man["actions"][act_name]
                    item["frameCount"] = d["count"]
                    item["fps"] = d["speed"]
                    item["durationSeconds"] = round(d["count"] / d["speed"], 3)
        with open(necro_man_path, "w", encoding="utf-8") as f:
            json.dump(necro_man, f, indent=2)
        print(f"  [OK] Updated Necro manifest.json.")

    # --------------------------------------------------------------------------
    # SUMMARY OF SPACE RECLAIMED
    # --------------------------------------------------------------------------
    final_vlad_sz = get_folder_size(vlad_dir)
    final_ogre_sz = get_folder_size(ogre_dir)
    final_necro_sz = get_folder_size(necro_dir)
    total_final = final_vlad_sz + final_ogre_sz + final_necro_sz
    saved = total_initial - total_final
    
    print("\n================================================================================")
    print("OPTIMIZATION SUMMARY & DISK SPACE SAVINGS")
    print("================================================================================")
    print(f"Vlad:        {initial_vlad_sz/(1024*1024):.2f} MB -> {final_vlad_sz/(1024*1024):.2f} MB (Saved {(initial_vlad_sz-final_vlad_sz)/(1024*1024):.2f} MB)")
    print(f"Ogre:        {initial_ogre_sz/(1024*1024):.2f} MB -> {final_ogre_sz/(1024*1024):.2f} MB (Saved {(initial_ogre_sz-final_ogre_sz)/(1024*1024):.2f} MB)")
    print(f"Necromancer: {initial_necro_sz/(1024*1024):.2f} MB -> {final_necro_sz/(1024*1024):.2f} MB (Saved {(initial_necro_sz-final_necro_sz)/(1024*1024):.2f} MB)")
    print(f"TOTAL:       {total_initial/(1024*1024):.2f} MB -> {total_final/(1024*1024):.2f} MB")
    print(f"TOTAL RECLAIMED DISK SPACE: {saved / (1024*1024):.2f} MB ({(saved/total_initial)*100:.1f}% reduction!)")
    print("================================================================================")

if __name__ == "__main__":
    run()
