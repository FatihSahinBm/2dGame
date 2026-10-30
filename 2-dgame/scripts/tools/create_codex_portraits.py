import os
from PIL import Image, ImageDraw, ImageFilter

PORTRAITS_DIR = "C:/Projects/2dgame/2-dgame/assets/ui/portraits"
BASE_DIR = "C:/Projects/2dgame/2-dgame"

os.makedirs(PORTRAITS_DIR, exist_ok=True)

def create_background(size=(128, 128), bg_color=(28, 20, 24), highlight_color=(45, 30, 38)):
    img = Image.new("RGBA", size, bg_color + (255,))
    draw = ImageDraw.Draw(img)
    # Radial spotlight in center
    cx, cy = size[0] // 2, size[1] // 2
    for r in range(54, 0, -2):
        factor = 1.0 - (r / 54.0)
        c = tuple(int(bg_color[i] + (highlight_color[i] - bg_color[i]) * factor * 1.5) for i in range(3))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c + (255,))
    
    # Border
    draw.rectangle([0, 0, size[0] - 1, size[1] - 1], outline=(70, 50, 40, 255), width=2)
    draw.rectangle([2, 2, size[0] - 3, size[1] - 3], outline=(35, 25, 20, 255), width=1)
    return img

def extract_and_composite(source_path, frame_box, output_name, scale_factor=1.0, bg_theme="dark_red"):
    bg_palettes = {
        "dark_red": ((28, 18, 22), (55, 28, 35)),
        "dark_blue": ((16, 22, 32), (28, 42, 60)),
        "dark_green": ((18, 28, 20), (30, 52, 35)),
        "dark_gold": ((32, 25, 18), (60, 48, 30)),
        "dark_purple": ((24, 18, 32), (48, 30, 62)),
    }
    bg_col, hl_col = bg_palettes.get(bg_theme, bg_palettes["dark_red"])
    canvas = create_background((128, 128), bg_col, hl_col)

    if os.path.exists(source_path):
        src = Image.open(source_path).convert("RGBA")
        cropped = src.crop(frame_box)
        
        # Trim transparent margins
        bbox = cropped.getbbox()
        if bbox:
            cropped = cropped.crop(bbox)
        
        # Resize to fit within 100x100
        w, h = cropped.size
        aspect = w / h
        if aspect > 1.0:
            target_w = int(100 * scale_factor)
            target_h = int(target_w / aspect)
        else:
            target_h = int(100 * scale_factor)
            target_w = int(target_h * aspect)
            
        cropped = cropped.resize((target_w, target_h), Image.Resampling.NEAREST)
        
        # Paste centered
        px = (128 - target_w) // 2
        py = (128 - target_h) // 2 + 2
        canvas.paste(cropped, (px, py), cropped)
    
    out_path = os.path.join(PORTRAITS_DIR, output_name)
    canvas.save(out_path)
    print(f"Generated portrait: {out_path}")

# 1. Skeleton
extract_and_composite(
    os.path.join(BASE_DIR, "assets/characters/monsters/skeleton/Attack2.png"),
    (0, 0, 150, 150),
    "portrait_skeleton.png",
    scale_factor=0.95,
    bg_theme="dark_blue"
)

# 2. Flying Eye
extract_and_composite(
    os.path.join(BASE_DIR, "assets/characters/monsters/flying_eye/Attack2.png"),
    (0, 0, 150, 150),
    "portrait_flying_eye.png",
    scale_factor=0.92,
    bg_theme="dark_purple"
)

# 3. Goblin
extract_and_composite(
    os.path.join(BASE_DIR, "assets/characters/monsters/goblin/Attack2.png"),
    (0, 0, 150, 150),
    "portrait_goblin.png",
    scale_factor=0.95,
    bg_theme="dark_green"
)

# 4. Mushroom
extract_and_composite(
    os.path.join(BASE_DIR, "assets/characters/monsters/mushroom/Attack2.png"),
    (0, 0, 150, 150),
    "portrait_mushroom.png",
    scale_factor=0.95,
    bg_theme="dark_purple"
)

# 5. Necromancer
extract_and_composite(
    os.path.join(BASE_DIR, "assets/characters/enemy/_Idle.png"),
    (0, 0, 150, 80),
    "portrait_necromancer.png",
    scale_factor=1.0,
    bg_theme="dark_purple"
)

# 6. Vlad Bat Form
bat_folder = os.path.join(BASE_DIR, "assets/characters/vlad_all_animations/13_bat_idle_fly")
bat_frame = None
if os.path.exists(bat_folder):
    files = sorted([f for f in os.listdir(bat_folder) if f.endswith(".png")])
    if files:
        bat_frame = os.path.join(bat_folder, files[0])
if not bat_frame:
    bat_frame = os.path.join(BASE_DIR, "assets/characters/vlad_all_animations/master_references/04_vlad_bat_master.png")

if bat_frame and os.path.exists(bat_frame):
    extract_and_composite(
        bat_frame,
        (0, 0, 600, 600) if "master" in bat_frame else (0, 0, 128, 128),
        "portrait_vlad_bat.png",
        scale_factor=0.95,
        bg_theme="dark_red"
    )

# 7. Vlad Werewolf Form
ww_folder = os.path.join(BASE_DIR, "assets/characters/vlad_all_animations/09_werewolf_idle")
ww_frame = None
if os.path.exists(ww_folder):
    files = sorted([f for f in os.listdir(ww_folder) if f.endswith(".png")])
    if files:
        ww_frame = os.path.join(ww_folder, files[0])
if not ww_frame:
    ww_frame = os.path.join(BASE_DIR, "assets/characters/vlad_all_animations/master_references/03_vlad_werewolf_master.png")

if ww_frame and os.path.exists(ww_frame):
    extract_and_composite(
        ww_frame,
        (0, 0, 600, 600) if "master" in ww_frame else (0, 0, 128, 128),
        "portrait_vlad_werewolf.png",
        scale_factor=0.95,
        bg_theme="dark_red"
    )

# 8. World Heart (Ancient Heart Relief crop)
extract_and_composite(
    os.path.join(BASE_DIR, "assets/environment/dungeon/ancient_heart_relief.png"),
    (0, 0, 256, 256),
    "portrait_world_heart.png",
    scale_factor=1.0,
    bg_theme="dark_gold"
)

# 9. Castle Targoviste (Distant Gothic Skyline)
extract_and_composite(
    os.path.join(BASE_DIR, "assets/environment/castle/distant_gothic_skyline.png"),
    (0, 0, 400, 300),
    "portrait_castle_targoviste.png",
    scale_factor=1.0,
    bg_theme="dark_blue"
)

# 10. Ancient Relief
extract_and_composite(
    os.path.join(BASE_DIR, "assets/environment/dungeon/ancient_heart_relief.png"),
    (0, 0, 256, 256),
    "portrait_ancient_relief.png",
    scale_factor=1.0,
    bg_theme="dark_gold"
)

print("All Codex portraits created successfully!")

