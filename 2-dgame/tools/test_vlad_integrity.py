import os
import sys
import json
import re

print("=== 1. Checking chapter_2_vlad.json ===")
json_path = os.path.join("2-dgame", "data", "story", "chapter_2_vlad.json")
assert os.path.exists(json_path), f"Missing {json_path}"
with open(json_path, "r", encoding="utf-8") as f:
    story = json.load(f)
assert story.get("chapter_id") in [2, "chapter_2_vlad", "2"], "Incorrect chapter_id"
stages = story.get("stages", [])
dialogues = story.get("dialogues", {})
print(f"JSON Valid: {len(stages)} stages, {len(dialogues)} dialogue entries")

print("\n=== 2. Checking TSCN files & ExtResources ===")
tscn_files = [
    os.path.join("2-dgame", "scenes", "levels", "vlad", "stage_1_forest_camp.tscn"),
    os.path.join("2-dgame", "scenes", "levels", "vlad", "stage_1_camp.tscn"),
    os.path.join("2-dgame", "scenes", "levels", "vlad", "stage_1_fatih_tent.tscn"),
    os.path.join("2-dgame", "scenes", "levels", "vlad", "stage_1_bridge_assault.tscn"),
    os.path.join("2-dgame", "scenes", "levels", "vlad", "stage_2_castle_dungeon.tscn"),
    os.path.join("2-dgame", "scenes", "levels", "vlad", "stage_3_throne_room.tscn"),
]

missing_resources = []
for tscn in tscn_files:
    assert os.path.exists(tscn), f"Missing {tscn}"
    with open(tscn, "r", encoding="utf-8") as f:
        content = f.read()
    matches = re.findall(r'path="res://([^"]+)"', content)
    for res_path in matches:
        local_path = os.path.join("2-dgame", res_path.replace("/", os.sep))
        if not os.path.exists(local_path):
            missing_resources.append((tscn, res_path, local_path))
    # Check that CombatPlayer has sword enabled
    assert 'has_sword = true' in content, f"CombatPlayer in {tscn} is missing has_sword = true"
    assert 'is_armed = true' in content, f"CombatPlayer in {tscn} is missing is_armed = true"
    print(f"PASS: {tscn} has {len(matches)} valid ExtResources and CombatPlayer sword equipped")

if missing_resources:
    for tscn, res, loc in missing_resources:
        print(f"ERROR: {tscn} references missing {res} -> {loc}")
    sys.exit(1)

print("\n=== 3. Checking GDScript files ===")
scripts = [
    os.path.join("2-dgame", "scripts", "levels", "vlad", "stage_1_forest_camp.gd"),
    os.path.join("2-dgame", "scripts", "levels", "vlad", "stage_1_camp.gd"),
    os.path.join("2-dgame", "scripts", "levels", "vlad", "stage_1_fatih_tent.gd"),
    os.path.join("2-dgame", "scripts", "levels", "vlad", "stage_1_bridge_assault.gd"),
    os.path.join("2-dgame", "scripts", "levels", "vlad", "stage_2_castle_dungeon.gd"),
    os.path.join("2-dgame", "scripts", "levels", "vlad", "stage_3_throne_room.gd"),
    os.path.join("2-dgame", "scripts", "enemies", "vlad_boss.gd"),
    os.path.join("2-dgame", "scripts", "enemies", "blood_knight.gd"),
    os.path.join("2-dgame", "scripts", "objects", "world_parallax_background.gd"),
    os.path.join("2-dgame", "scripts", "objects", "arrow_quiver_item.gd"),
    os.path.join("2-dgame", "scripts", "objects", "commander_orders_drop.gd"),
    os.path.join("2-dgame", "scripts", "objects", "dungeon_chain_lever.gd"),
    os.path.join("2-dgame", "scripts", "objects", "blood_altar_brazier.gd"),
    os.path.join("2-dgame", "scripts", "objects", "throne_blood_sigil.gd"),
    os.path.join("2-dgame", "scripts", "objects", "weak_archway_trap.gd"),
    os.path.join("2-dgame", "scripts", "objects", "castle_bell_mechanism.gd")
]

for sc in scripts:
    assert os.path.exists(sc), f"Missing {sc}"
    with open(sc, "r", encoding="utf-8") as f:
        text = f.read()
    lines = text.split("\n")
    print(f"PASS: {sc} ({len(lines)} lines, {len(text)} bytes)")

print("\n=== 4. Checking 16:9 Dedicated Background Assets ===")
expected_bg = [
    "stage_1_zone_1_time_rift.png",
    "stage_1_zone_2_camp.png",
    "stage_1_zone_3_fatih_tent.png",
    "stage_1_zone_3_fatih_tent_interior.png",
    "stage_1_zone_4_bridge.png",
    "stage_2_zone_1_chain_room.png",
    "stage_2_zone_2_guillotine.png",
    "stage_2_zone_3_bone_archive.png",
    "stage_2_zone_4_blood_altar.png",
    "stage_3_arena_1_throne.png",
    "stage_3_arena_2_balcony.png",
    "stage_3_arena_3_ramparts.png",
    "stage_3_arena_4_belltower.png"
]

for bg in expected_bg:
    bg_path = os.path.join("2-dgame", "assets", "backgrounds", bg)
    assert os.path.exists(bg_path), f"Missing background: {bg_path}"
    print(f"PASS: {bg} exists ({os.path.getsize(bg_path)} bytes)")

print("\n==============================================")
print("ALL VLAD CHAPTER INTEGRITY CHECKS PASSED 100%!")
print("==============================================")
