#!/usr/bin/env python3
"""
tools/generate_dungeon_gate_assets.py
Vlad Chapter Stage 2 Castle Dungeon - Gate & Mechanism Pixel-Art Asset Generator

Generates high-detail dark gothic pixel-art assets:
1. dungeon_chain_bracket.png (28x26): Wall-mounted forged iron pulley bracket with axle pin & anchoring bolts.
2. dungeon_chain_handle.png (18x46): Interlocking iron chain links with medieval forged T-bar pull handle.
3. dungeon_entrance_arch.png (52x160): Gothic pointed stone arch with upper portcullis housing and transparent opening.
4. dungeon_entrance_portcullis.png (24x76): Forged iron portcullis with vertical bars, rivets, and bottom spikes.
5. dungeon_blood_gate_arch.png (74x225): Monumental gothic throne portal with ashlar piers, gargoyle tympanum, blood runes, and transparent opening.
6. dungeon_blood_portcullis.png (42x104): Heavy castle portcullis with 4 bars, cross-braces, diagonal trusses, and sharp drop spikes.
"""

import os
from PIL import Image

OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "environment", "dungeon"))
os.makedirs(OUT_DIR, exist_ok=True)

# Gothic Palette Tokens
STONE_DARKEST = (18, 16, 22, 255)
STONE_DARK    = (28, 26, 34, 255)
STONE_MID     = (42, 40, 50, 255)
STONE_LIGHT   = (62, 60, 72, 255)
STONE_HILITE  = (88, 86, 102, 255)
STONE_MORTAR  = (14, 12, 18, 255)

IRON_DARKEST  = (14, 13, 18, 255)
IRON_DARK     = (24, 23, 30, 255)
IRON_MID      = (38, 37, 46, 255)
IRON_LIGHT    = (58, 57, 68, 255)
IRON_HILITE   = (84, 82, 98, 255)
RUST_DARK     = (44, 26, 20, 255)
RUST_LIGHT    = (76, 42, 28, 255)

BLOOD_DARK    = (60, 8, 14, 255)
BLOOD_MID     = (120, 16, 26, 255)
BLOOD_LIGHT   = (190, 28, 42, 255)
BLOOD_GLOW    = (240, 70, 80, 255)


def generate_chain_bracket() -> Image.Image:
    W, H = 28, 26
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()

    # Wall backplate (rectangular plate with beveled edges)
    for y in range(2, 24):
        for x in range(3, 25):
            px[x, y] = IRON_DARK
            if x in (3, 24) or y in (2, 23):
                px[x, y] = IRON_DARKEST
            elif x in (4, 5) or y == 3:
                px[x, y] = IRON_MID

    # Corner mounting heavy hex-bolts
    bolts = [(5, 4), (22, 4), (5, 21), (22, 21)]
    for bx, by in bolts:
        px[bx, by] = IRON_HILITE
        px[bx+1, by] = IRON_LIGHT
        px[bx, by+1] = IRON_DARKEST
        px[bx+1, by+1] = IRON_DARKEST

    # Center Pulley Wheel / Sprocket
    center_x, center_y = 14, 13
    for dy in range(-7, 8):
        for dx in range(-7, 8):
            dist_sq = dx*dx + dy*dy
            if dist_sq <= 49:
                px[center_x + dx, center_y + dy] = IRON_DARKEST
            if dist_sq <= 36:
                px[center_x + dx, center_y + dy] = IRON_MID
                if (dx + dy) % 3 == 0:
                    px[center_x + dx, center_y + dy] = IRON_LIGHT
            if dist_sq <= 16:
                px[center_x + dx, center_y + dy] = IRON_DARK
            if dist_sq <= 4:
                px[center_x + dx, center_y + dy] = IRON_HILITE

    # Forged mounting bracket arms holding axle
    for y in range(6, 20):
        px[9, y] = IRON_MID
        px[10, y] = IRON_LIGHT
        px[18, y] = IRON_DARKEST
        px[17, y] = IRON_MID

    # Axle hub pin in center
    px[14, 13] = (180, 160, 130, 255)  # Polished bronze/brass axle pivot
    px[13, 13] = IRON_HILITE

    # Bottom chain guide opening
    for x in range(12, 16):
        px[x, 24] = IRON_DARKEST
        px[x, 25] = IRON_LIGHT

    return img


def generate_chain_handle() -> Image.Image:
    W, H = 18, 46
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()

    # Vertical interlocking chain links (y: 0 to 30)
    for link_idx in range(4):
        top_y = link_idx * 7
        # Outer oval
        for dy in range(9):
            y = top_y + dy
            if y >= 32:
                break
            for x in range(6, 12):
                is_rim = (x in (6, 11)) or (dy in (0, 8) and x in range(7, 11))
                if is_rim:
                    if x == 6 or dy == 0:
                        px[x, y] = IRON_HILITE if link_idx % 2 == 0 else IRON_LIGHT
                    else:
                        px[x, y] = IRON_DARKEST
                elif x in (7, 10) and dy in (1, 7):
                    px[x, y] = IRON_MID

    # Heavy forged crossbar pull handle (y: 31 to 45)
    # T-bar connector socket
    for y in range(30, 35):
        for x in range(7, 11):
            px[x, y] = IRON_MID
            if x == 7 or y == 30:
                px[x, y] = IRON_HILITE
            elif x == 10:
                px[x, y] = IRON_DARKEST

    # Heavy horizontal crossbar (y: 35 to 39, x: 1 to 16)
    for y in range(35, 40):
        for x in range(1, 17):
            px[x, y] = IRON_MID
            if y == 35:
                px[x, y] = IRON_HILITE
            elif y == 39:
                px[x, y] = IRON_DARKEST

    # Wrapped grip in center of handle (leather strap wrapping)
    for x in range(5, 13):
        for y in range(35, 40):
            if (x + y) % 3 == 0:
                px[x, y] = (68, 46, 32, 255)  # Leather wrap
            else:
                px[x, y] = (46, 30, 20, 255)

    # Spherical / weighted iron pommel knobs on handle ends
    for y in range(34, 41):
        px[0, y] = IRON_DARKEST
        px[1, y] = IRON_HILITE if y in (35, 36) else IRON_MID
        px[16, y] = IRON_HILITE if y in (35, 36) else IRON_MID
        px[17, y] = IRON_DARKEST

    # Bottom iron ring dangling from handle center
    ring_cx, ring_cy = 9, 42
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            dist_sq = dx*dx + dy*dy
            if 4 <= dist_sq <= 9:
                px[ring_cx + dx, ring_cy + dy] = IRON_LIGHT if dy < 0 else IRON_DARKEST

    return img


def generate_entrance_arch() -> Image.Image:
    W, H = 52, 160
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()

    # Archway dimensions:
    # Left pillar: x = 0..12
    # Right pillar: x = 39..51
    # Opening: x = 13..38 (width 26)
    # Opening height: y = 86..159 (height 74) -> MUST BE TRANSPARENT (0,0,0,0)!
    # Upper stone portcullis housing / lintel: y = 0..85 (height 86)

    # 1. Left Pillar (x: 0..12, y: 0..160)
    for y in range(160):
        for x in range(13):
            # Ashlar stone blocks with horizontal mortar lines every 16px
            is_mortar_h = (y % 16 == 0)
            is_mortar_v = (x == 0) or ((y // 16) % 2 == 0 and x == 7)
            if is_mortar_h or is_mortar_v:
                px[x, y] = STONE_MORTAR
            elif x in (1, 2) or (y % 16 in (1, 2)):
                px[x, y] = STONE_LIGHT
            elif x == 12:
                # Inner groove / portcullis guide track
                px[x, y] = STONE_DARKEST
            elif x == 11:
                px[x, y] = STONE_DARK
            else:
                px[x, y] = STONE_MID if (x + y) % 7 != 0 else STONE_DARK

    # 2. Right Pillar (x: 39..51, y: 0..160)
    for y in range(160):
        for x in range(39, 52):
            is_mortar_h = (y % 16 == 0)
            is_mortar_v = (x == 51) or ((y // 16) % 2 == 1 and x == 45)
            if is_mortar_h or is_mortar_v:
                px[x, y] = STONE_MORTAR
            elif x == 39:
                # Inner groove / portcullis guide track
                px[x, y] = STONE_DARKEST
            elif x == 40:
                px[x, y] = STONE_DARK
            elif x == 50 or (y % 16 in (1, 2)):
                px[x, y] = STONE_LIGHT
            else:
                px[x, y] = STONE_MID if (x + y) % 7 != 0 else STONE_DARK

    # 3. Upper Housing / Tympanum Masonry (x: 13..38, y: 0..85)
    for y in range(86):
        for x in range(13, 39):
            is_mortar_h = (y % 16 == 0)
            is_mortar_v = ((y // 16) % 2 == 0 and x in (19, 31)) or ((y // 16) % 2 == 1 and x == 25)
            if is_mortar_h or is_mortar_v:
                px[x, y] = STONE_MORTAR
            elif y in (1, 2) or (y % 16 in (1, 2)):
                px[x, y] = STONE_LIGHT
            else:
                px[x, y] = STONE_MID if (x * 3 + y * 7) % 5 != 0 else STONE_DARK

    # 4. Pointed Gothic Arch Lintel & Keystone (y: 66..86)
    for x in range(13, 39):
        # Pointed curve: peak at center (x=25, 26) at y=68, springing at y=86 at sides
        dx = abs(x - 25.5)
        curve_y = int(68 + (dx / 12.5) * 18)
        # Carved stone arch border
        for y in range(curve_y - 8, curve_y):
            if 0 <= y < 160:
                if y == curve_y - 8:
                    px[x, y] = STONE_HILITE
                elif y == curve_y - 1:
                    px[x, y] = STONE_DARKEST
                else:
                    px[x, y] = STONE_LIGHT if dx < 4 else STONE_MID

    # Keystone at peak (x: 23..28, y: 60..72)
    for y in range(60, 72):
        for x in range(23, 29):
            if x in (23, 28) or y in (60, 71):
                px[x, y] = STONE_MORTAR
            elif y in (61, 62) or x == 24:
                px[x, y] = STONE_HILITE
            else:
                px[x, y] = STONE_LIGHT

    # Portcullis slot shadow at bottom of upper casing (y: 84..86)
    for x in range(13, 39):
        px[x, 85] = STONE_DARKEST

    # Center opening (y: 86..159, x: 13..38) remains 100% transparent (0, 0, 0, 0)!
    return img


def generate_entrance_portcullis() -> Image.Image:
    W, H = 24, 76
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()

    # 3 Heavy vertical cylindrical iron bars (centers at x: 4, 12, 20)
    bar_centers = [4, 12, 20]
    for bc in bar_centers:
        for y in range(H - 12):  # main shaft
            for offset in (-1, 0, 1):
                x = bc + offset
                if 0 <= x < W:
                    if offset == -1:
                        px[x, y] = IRON_HILITE
                    elif offset == 0:
                        px[x, y] = IRON_LIGHT
                    else:
                        px[x, y] = IRON_DARKEST

        # Sharp bottom drop spikes (y: H - 12 to H - 1)
        # Width 3 at top -> width 1 at bottom point
        spike_y_start = H - 12
        for sy in range(12):
            y = spike_y_start + sy
            if y >= H:
                break
            half_w = 1 if sy < 7 else 0
            for dx in range(-half_w, half_w + 1):
                x = bc + dx
                if 0 <= x < W:
                    if dx < 0 or sy == 0:
                        px[x, y] = IRON_HILITE
                    elif dx == 0 and sy > 8:
                        px[x, y] = (160, 150, 170, 255)  # gleaming sharpened spike point
                    elif dx > 0:
                        px[x, y] = IRON_DARKEST
                    else:
                        px[x, y] = IRON_MID

    # 3 Horizontal forged crossbars with pyramid rivets (y: 8..12, 32..36, 56..60)
    cross_ys = [8, 32, 56]
    for cy in cross_ys:
        for y in range(cy, cy + 5):
            for x in range(W):
                if y == cy:
                    px[x, y] = IRON_HILITE
                elif y == cy + 4:
                    px[x, y] = IRON_DARKEST
                elif x in (0, W - 1):
                    px[x, y] = IRON_DARK
                else:
                    px[x, y] = IRON_MID

        # Heavy square pyramid rivets on intersections
        for bc in bar_centers:
            px[bc, cy + 2] = IRON_HILITE
            px[bc + 1, cy + 2] = IRON_DARKEST
            px[bc, cy + 1] = IRON_HILITE
            px[bc, cy + 3] = IRON_DARKEST

    return img


def generate_blood_gate_arch() -> Image.Image:
    W, H = 74, 225
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()

    # Dimensions:
    # Left Pier: x = 0..14 (width 15)
    # Right Pier: x = 59..73 (width 15)
    # Opening: x = 15..58 (width 44)
    # Opening height: y = 125..224 (height 100) -> MUST BE TRANSPARENT (0,0,0,0)!
    # Upper Tympanum / Vault: y = 0..124 (height 125)

    # 1. Left Ashlar Pier (x: 0..14, y: 0..225)
    for y in range(225):
        for x in range(15):
            is_mortar_h = (y % 20 == 0)
            is_mortar_v = (x == 0) or ((y // 20) % 2 == 0 and x == 8)
            if is_mortar_h or is_mortar_v:
                px[x, y] = STONE_MORTAR
            elif x in (1, 2) or (y % 20 in (1, 2)):
                px[x, y] = STONE_LIGHT
            elif x == 14:
                px[x, y] = STONE_DARKEST  # Portcullis guide channel
            elif x == 13:
                px[x, y] = STONE_DARK
            else:
                px[x, y] = STONE_MID if (x + y) % 5 != 0 else STONE_DARK

    # 2. Right Ashlar Pier (x: 59..73, y: 0..225)
    for y in range(225):
        for x in range(59, 74):
            is_mortar_h = (y % 20 == 0)
            is_mortar_v = (x == 73) or ((y // 20) % 2 == 1 and x == 66)
            if is_mortar_h or is_mortar_v:
                px[x, y] = STONE_MORTAR
            elif x == 59:
                px[x, y] = STONE_DARKEST  # Portcullis guide channel
            elif x == 60:
                px[x, y] = STONE_DARK
            elif x in (71, 72) or (y % 20 in (1, 2)):
                px[x, y] = STONE_LIGHT
            else:
                px[x, y] = STONE_MID if (x + y) % 5 != 0 else STONE_DARK

    # 3. Upper Vault & Tympanum Masonry (x: 15..58, y: 0..124)
    for y in range(125):
        for x in range(15, 59):
            is_mortar_h = (y % 18 == 0)
            is_mortar_v = ((y // 18) % 2 == 0 and x in (25, 47)) or ((y // 18) % 2 == 1 and x == 36)
            if is_mortar_h or is_mortar_v:
                px[x, y] = STONE_MORTAR
            elif y in (1, 2) or (y % 18 in (1, 2)):
                px[x, y] = STONE_LIGHT
            else:
                px[x, y] = STONE_MID if (x * 2 + y * 5) % 7 != 0 else STONE_DARK

    # 4. Pointed Gothic Arch Rib & Moulding (y: 95..125)
    for x in range(15, 59):
        dx = abs(x - 36.5)
        curve_y = int(98 + (dx / 21.5) * 27)
        for y in range(curve_y - 10, curve_y):
            if 0 <= y < 225:
                if y == curve_y - 10:
                    px[x, y] = STONE_HILITE
                elif y == curve_y - 1:
                    px[x, y] = STONE_DARKEST
                else:
                    px[x, y] = STONE_LIGHT if dx < 6 else STONE_MID

    # Carved Wallachian Blood Runes on Tympanum (y: 40..75, x: 24..49)
    runes = [
        # Left occult dagger rune (x: 25..31, y: 46..66)
        (28, 46), (28, 47), (28, 48), (28, 49), (28, 50), (28, 51), (28, 52), (28, 53), (28, 54), (28, 55),
        (26, 50), (27, 50), (29, 50), (30, 50), (27, 56), (29, 56),
        # Center vampire cross rune (x: 34..40, y: 42..68)
        (37, 42), (37, 43), (37, 44), (37, 45), (37, 46), (37, 47), (37, 48), (37, 49), (37, 50),
        (37, 51), (37, 52), (37, 53), (37, 54), (37, 55), (37, 56), (37, 57), (37, 58), (37, 59),
        (34, 48), (35, 48), (36, 48), (38, 48), (39, 48), (40, 48),
        (35, 54), (36, 54), (38, 54), (39, 54),
        # Right blood sigil rune (x: 43..49, y: 46..66)
        (46, 46), (46, 47), (46, 48), (46, 49), (46, 50), (46, 51), (46, 52), (46, 53), (46, 54), (46, 55),
        (44, 50), (45, 50), (47, 50), (48, 50), (45, 56), (47, 56)
    ]
    for rx, ry in runes:
        px[rx, ry] = BLOOD_LIGHT
        # Glow halo
        for gdx, gdy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            gx, gy = rx + gdx, ry + gdy
            if px[gx, gy] != BLOOD_LIGHT:
                px[gx, gy] = BLOOD_MID

    # Slot shadow at bottom of upper vault (y: 123..125)
    for x in range(15, 59):
        px[x, 124] = STONE_DARKEST

    # Center opening (y: 125..224, x: 15..58) is 100% transparent!
    return img


def generate_blood_portcullis() -> Image.Image:
    W, H = 42, 104
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()

    # 4 Heavy cylindrical iron bars (centers at x: 5, 15, 26, 36)
    bar_centers = [5, 15, 26, 36]
    for bc in bar_centers:
        for y in range(H - 14):
            for offset in (-1, 0, 1):
                x = bc + offset
                if 0 <= x < W:
                    if offset == -1:
                        px[x, y] = IRON_HILITE
                    elif offset == 0:
                        px[x, y] = IRON_LIGHT
                    else:
                        px[x, y] = IRON_DARKEST

        # Heavy drop spikes at bottom (y: H - 14 to H - 1)
        spike_start = H - 14
        for sy in range(14):
            y = spike_start + sy
            if y >= H:
                break
            half_w = 1 if sy < 9 else 0
            for dx in range(-half_w, half_w + 1):
                x = bc + dx
                if 0 <= x < W:
                    if dx < 0 or sy == 0:
                        px[x, y] = IRON_HILITE
                    elif dx == 0 and sy > 10:
                        px[x, y] = (180, 170, 190, 255)  # gleaming razor steel spike point
                    elif dx > 0:
                        px[x, y] = IRON_DARKEST
                    else:
                        px[x, y] = IRON_MID

    # 3 Heavy horizontal forged crossbars with pyramid rivets (y: 10..15, 42..47, 74..79)
    cross_ys = [10, 42, 74]
    for cy in cross_ys:
        for y in range(cy, cy + 6):
            for x in range(W):
                if y == cy:
                    px[x, y] = IRON_HILITE
                elif y == cy + 5:
                    px[x, y] = IRON_DARKEST
                elif x in (0, W - 1):
                    px[x, y] = IRON_DARK
                else:
                    px[x, y] = IRON_MID

        # Heavy pyramid rivets on bar intersections
        for bc in bar_centers:
            px[bc, cy + 2] = IRON_HILITE
            px[bc + 1, cy + 2] = IRON_DARKEST
            px[bc, cy + 1] = IRON_HILITE
            px[bc, cy + 3] = IRON_DARKEST

    # Center Diagonal X-Truss Reinforcement (between crossbars 1 & 2: y 16..41)
    for t in range(25):
        # Left-to-right diagonal
        y1 = 16 + t
        x1 = 6 + int(t * (35 - 6) / 25.0)
        if 0 <= x1 < W and 0 <= y1 < H:
            px[x1, y1] = IRON_MID
            if x1 + 1 < W:
                px[x1 + 1, y1] = IRON_DARKEST
        # Right-to-left diagonal
        x2 = 35 - int(t * (35 - 6) / 25.0)
        if 0 <= x2 < W and 0 <= y1 < H:
            px[x2, y1] = IRON_HILITE if x2 < x1 else IRON_MID
            if x2 + 1 < W:
                px[x2 + 1, y1] = IRON_DARKEST

    return img


def main():
    assets = [
        ("dungeon_chain_bracket.png", generate_chain_bracket()),
        ("dungeon_chain_handle.png", generate_chain_handle()),
        ("dungeon_entrance_arch.png", generate_entrance_arch()),
        ("dungeon_entrance_portcullis.png", generate_entrance_portcullis()),
        ("dungeon_blood_gate_arch.png", generate_blood_gate_arch()),
        ("dungeon_blood_portcullis.png", generate_blood_portcullis()),
    ]
    for filename, img in assets:
        path = os.path.join(OUT_DIR, filename)
        img.save(path, "PNG")
        print(f"Saved {filename} ({img.size[0]}x{img.size[1]}) to {path}")


if __name__ == "__main__":
    main()
