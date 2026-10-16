import os
from PIL import Image

base_dir = r"2-dgame/assets/characters/enemies/blood_knight"

anims = {
    "idle": 4,
    "walk": 6,
    "attack": 6,
    "hurt": 2,
    "death": 4
}

FRAME_W = 180
FRAME_H = 190

for anim, count in anims.items():
    strip = Image.new("RGBA", (FRAME_W * count, FRAME_H), (0, 0, 0, 0))
    for i in range(count):
        fname = os.path.join(base_dir, f"{anim}_{i}.png")
        if os.path.exists(fname):
            frame = Image.open(fname)
            strip.paste(frame, (i * FRAME_W, 0))
    strip_path = os.path.join(base_dir, f"{anim}.png")
    strip.save(strip_path)
    print(f"Saved strip: {strip_path} size: {strip.size}")

tres_path = os.path.join(base_dir, "blood_knight_frames.tres")

sub_resources = []
anim_blocks = []

ext_res_map = {
    "idle": "1_idle",
    "walk": "2_walk",
    "attack": "3_attack",
    "hurt": "4_hurt",
    "death": "5_death"
}

for anim, count in anims.items():
    ext_id = ext_res_map[anim]
    frame_entries = []
    for i in range(count):
        sub_id = f"Atlas_{anim}_{i}"
        sub_resources.append(f"""[sub_resource type="AtlasTexture" id="{sub_id}"]
atlas = ExtResource("{ext_id}")
region = Rect2({i * FRAME_W}, 0, {FRAME_W}, {FRAME_H})
""")
        frame_entries.append(f"""{{
"duration": 1.0,
"texture": SubResource("{sub_id}")
}}""")
    
    speed = 8.0 if anim in ["walk", "attack"] else (5.0 if anim == "idle" else 6.0)
    loop = "false" if anim in ["hurt", "death", "attack"] else "true"
    frames_joined = ", ".join(frame_entries)
    anim_blocks.append(f"""{{
"frames": [{frames_joined}],
"loop": {loop},
"name": &"{anim}",
"speed": {speed}
}}""")

content = f"""[gd_resource type="SpriteFrames" format=3]

[ext_resource type="Texture2D" path="res://assets/characters/enemies/blood_knight/idle.png" id="1_idle"]
[ext_resource type="Texture2D" path="res://assets/characters/enemies/blood_knight/walk.png" id="2_walk"]
[ext_resource type="Texture2D" path="res://assets/characters/enemies/blood_knight/attack.png" id="3_attack"]
[ext_resource type="Texture2D" path="res://assets/characters/enemies/blood_knight/hurt.png" id="4_hurt"]
[ext_resource type="Texture2D" path="res://assets/characters/enemies/blood_knight/death.png" id="5_death"]

{''.join(sub_resources)}
[resource]
animations = [{', '.join(anim_blocks)}]
"""

with open(tres_path, "w", encoding="utf-8") as f:
    f.write(content)

print(f"Generated: {tres_path}")
