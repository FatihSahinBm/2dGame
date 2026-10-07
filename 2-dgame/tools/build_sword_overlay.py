"""Kılıç overlay sprite'larını üretir: assets/items/sword_overlay/sword_<açı>.png

- Her açı için piksel kalıbı kodla, tek tek piksel koyularak oluşturulur.
- Image.rotate / serbest döndürme YOK.
- Açı kuralı (Godot rotation ile aynı, y aşağı): 0 = ileri (+x), 45 = ileri-aşağı,
  90 = aşağı, 135 = geri-aşağı, -45 = ileri-yukarı, -90 = yukarı.
- Eksen boyunca t parametresi: t=0 el noktasındaki kabza (sap) pikseli.
  t=-2 topuz, t=-1..0 sap, t=1 siperlik, t=2..11 bıçak, t=12 uç  => toplam 15 px.
- Renkler yalnızca karakter paletinden.
"""
import json
import os
from PIL import Image

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(PROJECT_DIR, "assets", "items", "sword_overlay")

STEEL_LIGHT = (199, 199, 176, 255)
STEEL_SHADOW = (134, 130, 115, 255)
BRONZE = (159, 128, 63, 255)
LEATHER = (54, 41, 23, 255)

ANGLES = {0: (1, 0), 45: (1, 1), 90: (0, 1), 135: (-1, 1), -45: (1, -1), -90: (0, -1)}

POMMEL_T = -2
GRIP_T = (-1, 0)
GUARD_T = 1
BLADE_T = range(2, 12)
TIP_T = 12


def build_pixels(dx: int, dy: int) -> dict:
    px = {}

    def axis(t):
        return (t * dx, t * dy)

    diagonal = dx != 0 and dy != 0
    # Gölge tarafı: yatay/diyagonalde bir piksel aşağı, dikeyde bir piksel sağ
    shadow = (1, 0) if dx == 0 else (0, 1)

    px[axis(POMMEL_T)] = BRONZE
    for t in GRIP_T:
        px[axis(t)] = LEATHER
    # Siperlik (eksene dik)
    gx, gy = axis(GUARD_T)
    if diagonal:
        perp = (dy, -dx) if dy > 0 else (-dy, dx)
        for k in (-1, 0, 1):
            px[(gx + k * perp[0], gy + k * perp[1])] = BRONZE
    else:
        for k in (-1, 0, 1, 2):
            px[(gx + k * shadow[0], gy + k * shadow[1])] = BRONZE
    # Bıçak: açık çelik ana çizgi + bir piksel gölge çizgisi (2 px kalınlık)
    for t in BLADE_T:
        ax, ay = axis(t)
        px[(ax, ay)] = STEEL_LIGHT
        sp = (ax + shadow[0], ay + shadow[1])
        if sp not in px:
            px[sp] = STEEL_SHADOW
    # Uç: tek piksel (sivri)
    px[axis(TIP_T)] = STEEL_LIGHT
    return px


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    meta = {}
    for angle, (dx, dy) in ANGLES.items():
        px = build_pixels(dx, dy)
        xs = [p[0] for p in px]
        ys = [p[1] for p in px]
        minx, miny = min(xs), min(ys)
        w, h = max(xs) - minx + 1, max(ys) - miny + 1
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        for (x, y), c in px.items():
            im.putpixel((x - minx, y - miny), c)
        name = f"sword_{angle}.png".replace("-", "m")
        im.save(os.path.join(OUT_DIR, name))
        # pivot = t=0 sap pikselinin görsel içindeki konumu
        meta[str(angle)] = {"file": name, "pivot": [-minx, -miny], "size": [w, h]}
        print(f"{name}: {w}x{h} pivot={meta[str(angle)]['pivot']}")
    with open(os.path.join(OUT_DIR, "sword_overlay_meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)


if __name__ == "__main__":
    main()
