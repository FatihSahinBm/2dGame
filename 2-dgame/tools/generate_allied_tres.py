import os

BASE_DIR = r"c:\Projects\2dgame\2-dgame"
OUTPUT_BASE = os.path.join(BASE_DIR, "assets", "characters", "allies")

FRAME_WIDTH = 160
FRAME_HEIGHT = 256

CONFIG = {
    "fatih": {
        "anims": {
            "idle": {"frames": 8, "speed": 6.0, "loop": True},
            "draw_sword": {"frames": 8, "speed": 8.0, "loop": False},
            "command": {"frames": 8, "speed": 6.0, "loop": True},
            "walk": {"frames": 8, "speed": 7.0, "loop": True},
        }
    },
    "janissary": {
        "anims": {
            "idle": {"frames": 4, "speed": 5.0, "loop": True},
            "walk": {"frames": 8, "speed": 7.0, "loop": True},
            "attack": {"frames": 8, "speed": 9.0, "loop": False},
            "death": {"frames": 6, "speed": 6.0, "loop": False},
        }
    },
    "kemankes": {
        "anims": {
            "idle": {"frames": 5, "speed": 5.0, "loop": True},
            "aim": {"frames": 5, "speed": 6.0, "loop": False},
            "attack": {"frames": 4, "speed": 6.5, "loop": False},
            "death": {"frames": 6, "speed": 6.0, "loop": False},
        }
    }
}

def generate_tres():
    for char_name, data in CONFIG.items():
        char_dir = os.path.join(OUTPUT_BASE, char_name)
        tres_path = os.path.join(char_dir, f"{char_name}_frames.tres")
        
        ext_resources = []
        atlas_textures = []
        anim_blocks = []
        
        ext_id = 1
        for anim_name, info in data["anims"].items():
            res_id = f"{ext_id}_{anim_name}"
            ext_resources.append(f'[ext_resource type="Texture2D" path="res://assets/characters/allies/{char_name}/{anim_name}.png" id="{res_id}"]')
            
            frame_sub_ids = []
            for f in range(info["frames"]):
                atlas_id = f"Atlas_{anim_name}_{f}"
                frame_sub_ids.append(atlas_id)
                x = f * FRAME_WIDTH
                atlas_textures.append(f'[sub_resource type="AtlasTexture" id="{atlas_id}"]\natlas = ExtResource("{res_id}")\nregion = Rect2({x}, 0, {FRAME_WIDTH}, {FRAME_HEIGHT})\n')
            
            frames_entries = []
            for sub_id in frame_sub_ids:
                frames_entries.append('{\n"duration": 1.0,\n"texture": SubResource("' + sub_id + '")\n}')
            
            loop_str = "true" if info["loop"] else "false"
            anim_blocks.append('{\n"frames": [' + ",\n".join(frames_entries) + '],\n"loop": ' + loop_str + ',\n"name": &"' + anim_name + '",\n"speed": ' + str(info["speed"]) + '\n}')
            ext_id += 1
        
        content = '[gd_resource type="SpriteFrames" format=3]\n\n'
        content += "\n".join(ext_resources) + "\n\n"
        content += "\n".join(atlas_textures) + "\n"
        content += "[resource]\nanimations = [" + ",\n".join(anim_blocks) + "]\n"
        
        with open(tres_path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Generated {tres_path}")

if __name__ == "__main__":
    generate_tres()
