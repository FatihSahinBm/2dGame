"""Ortak yardımcılar: knight_frames.tres ayrıştırma ve kare kırpma.

Bu modül orijinal karakter piksellerini DEĞİŞTİRMEZ; yalnızca okur.
"""
import os
import re
from PIL import Image

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRES_PATH = os.path.join(PROJECT_DIR, "assets", "characters", "knight", "knight_frames.tres")

# Overlay uygulanacak (kılıçsız çizilmiş) animasyonlar
OVERLAY_ANIMS = [
    "idle", "run", "jump", "jump_apex", "fall", "crouch", "crouch_walk",
    "wall_slide", "roll", "slide", "dash",
]


def res_path_to_fs(res_path: str) -> str:
    return os.path.join(PROJECT_DIR, res_path.replace("res://", "").replace("/", os.sep))


def parse_tres(path: str = TRES_PATH):
    """{anim_name: [(png_fs_path, (x, y, w, h)), ...]} döndürür."""
    text = open(path, encoding="utf-8").read()
    ext = dict((m.group(2), m.group(1)) for m in re.finditer(
        r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', text))
    atlases = {}
    for m in re.finditer(
            r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*atlas = ExtResource\("([^"]+)"\)\s*'
            r'region = Rect2\(([^)]+)\)', text):
        rect = tuple(int(float(v)) for v in m.group(3).split(","))
        atlases[m.group(1)] = (res_path_to_fs(ext[m.group(2)]), rect)
    anims = {}
    anim_block = text[text.index("animations = ["):]
    for m in re.finditer(r'"frames": \[(.*?)\],\s*"loop": \w+,\s*"name": &"([^"]+)"', anim_block, re.S):
        ids = re.findall(r'SubResource\("([^"]+)"\)', m.group(1))
        anims[m.group(2)] = [atlases[i] for i in ids]
    return anims


_cache = {}


def load_frame(png: str, rect) -> Image.Image:
    if png not in _cache:
        _cache[png] = Image.open(png).convert("RGBA")
    x, y, w, h = rect
    return _cache[png].crop((x, y, x + w, y + h))
