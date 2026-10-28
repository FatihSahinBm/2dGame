"""
tools/generate_throne_parallax_assets.py
Generates clean, authentic gothic pixel-art textures for Stage 3 Throne Room parallax depth layers:
1. distant_gothic_skyline.png (Far Parallax Layer)
2. throne_mid_arch_pillars.png (Midground Arena 1)
3. blood_hall_colonnade_mid.png (Midground Arena 2)
4. ramparts_mid_battlements.png (Midground Arena 3)
5. belltower_mid_timber_frame.png (Midground Arena 4)
6. castle_transition_pilaster.png (Near Depth Layer)
7. gothic_ceiling_framing_fg.png (Controlled Foreground Valance)
8. gothic_edge_framing_fg.png (Controlled Foreground Edge Pilaster)
"""

import os
import math
from PIL import Image, ImageDraw

OUTPUT_DIR = "assets/environment/castle"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Common Palette
C_SHADOW = (10, 11, 14, 255)
C_DARK = (24, 27, 34, 255)
C_MID = (46, 52, 64, 255)
C_LIGHT = (68, 76, 92, 255)
C_HILIGHT = (90, 100, 120, 255)


def create_distant_skyline():
    """Seamless horizontal looping far gothic mountain and spire skyline (1024x380)."""
    w, h = 1024, 380
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    # Gradient sky (deep twilight nocturnal)
    for y in range(h):
        t = y / float(h)
        # Deep blue-black to misty slate indigo
        r = int(6 + t * 14)
        g = int(8 + t * 18)
        b = int(18 + t * 32)
        draw.line([(0, y), (w, y)], fill=(r, g, b, 240))

    # Blood Moon / Ominous Cold Moon at x=512, y=90
    moon_cx, moon_cy, moon_r = 512, 85, 36
    # Soft moon glow
    for gr in range(moon_r + 24, moon_r, -2):
        alpha = int(35 * (1.0 - (gr - moon_r) / 24.0))
        draw.ellipse([moon_cx - gr, moon_cy - gr, moon_cx + gr, moon_cy + gr], fill=(160, 180, 210, alpha))
    # Moon body (crescent shadow)
    for my in range(moon_cy - moon_r, moon_cy + moon_r + 1):
        for mx in range(moon_cx - moon_r, moon_cx + moon_r + 1):
            dist = math.hypot(mx - moon_cx, my - moon_cy)
            if dist <= moon_r:
                # Crater shading / crescent mask
                shadow_dist = math.hypot(mx - (moon_cx - 10), my - (moon_cy - 6))
                if shadow_dist > moon_r * 0.75:
                    c_val = int(190 + 30 * math.sin(mx * 0.3) * math.cos(my * 0.2))
                    im.putpixel((mx, my), (c_val, int(c_val * 0.95), int(c_val * 0.9), 255))
                else:
                    im.putpixel((mx, my), (40, 45, 60, 230))

    # Far mountain crags (Layer 1 silhouette)
    c_mount = (14, 18, 28, 255)
    for x in range(w):
        # Seamless sine combination
        rad = 2.0 * math.pi * x / float(w)
        my = int(160 + 45 * math.sin(rad * 2) + 25 * math.sin(rad * 5 + 1.2) + 12 * math.cos(rad * 9))
        draw.line([(x, my), (x, h)], fill=c_mount)

    # Middle spires and fortress silhouettes (Layer 2)
    c_fortress = (9, 12, 19, 255)
    for x in range(w):
        rad = 2.0 * math.pi * x / float(w)
        fy = int(220 + 30 * math.sin(rad * 3 + 0.5) + 18 * math.cos(rad * 7))
        draw.line([(x, fy), (x, h)], fill=c_fortress)

    # Specific distant gothic castle towers (seamlessly spaced)
    tower_xs = [80, 240, 420, 600, 780, 940]
    for tx in tower_xs:
        th = 130 + (tx % 50)
        tw = 28 + (tx % 14)
        top_y = 220 - th
        # Tower base
        draw.rectangle([tx - tw // 2, top_y + 30, tx + tw // 2, h], fill=c_fortress)
        # Crenels
        for c in range(tx - tw // 2, tx + tw // 2, 7):
            draw.rectangle([c, top_y + 20, c + 4, top_y + 30], fill=c_fortress)
        # Pointed cone roof / spire
        draw.polygon([(tx - tw // 2 - 2, top_y + 20), (tx + tw // 2 + 2, top_y + 20), (tx, top_y - 25)], fill=c_fortress)
        # Spire needle tip
        draw.line([(tx, top_y - 25), (tx, top_y - 45)], fill=c_fortress, width=2)

    # Low-altitude gothic mist band (dithered transparent fog at bottom)
    for y in range(260, h):
        factor = (y - 260) / float(h - 260)
        fog_alpha = int(factor * 90)
        draw.line([(0, y), (w, y)], fill=(18, 22, 34, fog_alpha))

    path = os.path.join(OUTPUT_DIR, "distant_gothic_skyline.png")
    im.save(path, "PNG")
    print(f"Saved: {path} ({w}x{h})")


def create_throne_mid_arch():
    """Arena 1 (Throne Room): Lofty pointed gothic arches, pillars, lancet windows (720x520)."""
    w, h = 720, 520
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    # Distant lancet windows in the background (center 360, x=180, x=540)
    window_xs = [180, 360, 540]
    for wx in window_xs:
        win_w, win_h = 70, 240
        top_y = 100
        # Window arch silhouette
        draw.rectangle([wx - win_w // 2, top_y + 40, wx + win_w // 2, top_y + win_h], fill=(16, 22, 32, 230))
        # Pointed gothic top
        draw.polygon([(wx - win_w // 2, top_y + 40), (wx + win_w // 2, top_y + 40), (wx, top_y)], fill=(16, 22, 32, 230))
        # Faint moonlight glow inside window
        draw.rectangle([wx - win_w // 2 + 6, top_y + 46, wx + win_w // 2 - 6, top_y + win_h - 6], fill=(28, 40, 58, 210))
        draw.polygon([(wx - win_w // 2 + 6, top_y + 46), (wx + win_w // 2 - 6, top_y + 46), (wx, top_y + 10)], fill=(32, 48, 70, 210))
        # Stone tracery / mullions
        draw.line([(wx, top_y + 10), (wx, top_y + win_h - 6)], fill=(16, 20, 28, 255), width=3)
        for my in range(top_y + 60, top_y + win_h, 45):
            draw.line([(wx - win_w // 2 + 6, my), (wx + win_w // 2 - 6, my)], fill=(16, 20, 28, 255), width=2)

    # 4 Grand Stone Gothic Pillars (x=60, x=280, x=440, x=660)
    pillar_xs = [60, 280, 440, 660]
    pillar_w = 46

    for px in pillar_xs:
        # Pillar shaft
        draw.rectangle([px - pillar_w // 2, 80, px + pillar_w // 2, h], fill=C_DARK)
        # Vertical fluting lines
        draw.line([(px - 14, 80), (px - 14, h)], fill=C_SHADOW, width=2)
        draw.line([(px - 4, 80), (px - 4, h)], fill=C_MID, width=2)
        draw.line([(px + 6, 80), (px + 6, h)], fill=C_MID, width=2)
        draw.line([(px + 16, 80), (px + 16, h)], fill=C_SHADOW, width=2)
        # Highlight edge
        draw.line([(px - pillar_w // 2, 80), (px - pillar_w // 2, h)], fill=C_LIGHT, width=2)
        # Base plinth
        draw.rectangle([px - pillar_w // 2 - 6, h - 60, px + pillar_w // 2 + 6, h], fill=C_MID)
        draw.rectangle([px - pillar_w // 2 - 10, h - 30, px + pillar_w // 2 + 10, h], fill=C_DARK)
        # Capital at top
        draw.rectangle([px - pillar_w // 2 - 8, 80, px + pillar_w // 2 + 8, 110], fill=C_MID)
        draw.rectangle([px - pillar_w // 2 - 12, 70, px + pillar_w // 2 + 12, 80], fill=C_LIGHT)

    # Pointed Arches connecting the pillars (span 1: 60->280, span 2: 280->440, span 3: 440->660)
    spans = [(60, 280), (280, 440), (440, 660)]
    for x1, x2 in spans:
        mid_x = (x1 + x2) // 2
        apex_y = 20
        # Gothic Arch ribs
        draw.polygon([(x1, 70), (mid_x, apex_y), (mid_x, apex_y + 24), (x1, 94)], fill=C_MID)
        draw.polygon([(x2, 70), (mid_x, apex_y), (mid_x, apex_y + 24), (x2, 94)], fill=C_DARK)
        # Cusp highlight
        draw.line([(x1, 70), (mid_x, apex_y)], fill=C_LIGHT, width=3)
        draw.line([(x2, 70), (mid_x, apex_y)], fill=C_SHADOW, width=2)
        # Keystone ornament
        draw.rectangle([mid_x - 8, apex_y - 6, mid_x + 8, apex_y + 28], fill=C_LIGHT)
        draw.rectangle([mid_x - 6, apex_y - 4, mid_x + 6, apex_y + 26], fill=C_MID)

    path = os.path.join(OUTPUT_DIR, "throne_mid_arch_pillars.png")
    im.save(path, "PNG")
    print(f"Saved: {path} ({w}x{h})")


def create_blood_hall_mid():
    """Arena 2 (Blood Hall): Dark heavy gothic colonnades with restrained crimson accents (720x520)."""
    w, h = 720, 520
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    C_CRIMSON_DARK = (46, 10, 16, 255)
    C_CRIMSON_MID = (78, 16, 26, 255)
    C_CRIMSON_ACCENT = (110, 22, 34, 255)

    # Heavy Norman/Gothic Colonnade Pillars (x=80, x=260, x=460, x=640)
    pillar_xs = [80, 260, 460, 640]
    pw = 56

    for px in pillar_xs:
        # Massive stone column
        draw.rectangle([px - pw // 2, 70, px + pw // 2, h], fill=C_DARK)
        # Masonry ashlar blocks
        for by in range(80, h - 60, 36):
            draw.line([(px - pw // 2, by), (px + pw // 2, by)], fill=C_SHADOW, width=2)
            # Staggered vertical joints
            offset = 12 if (by // 36) % 2 == 0 else -12
            draw.line([(px + offset, by), (px + offset, by + 36)], fill=C_SHADOW, width=1)
        # Edge highlights
        draw.line([(px - pw // 2, 70), (px - pw // 2, h)], fill=C_MID, width=2)
        draw.line([(px + pw // 2, 70), (px + pw // 2, h)], fill=C_SHADOW, width=2)

        # Base and Capital
        draw.rectangle([px - pw // 2 - 8, h - 50, px + pw // 2 + 8, h], fill=C_MID)
        draw.rectangle([px - pw // 2 - 12, h - 25, px + pw // 2 + 12, h], fill=C_DARK)
        draw.rectangle([px - pw // 2 - 10, 70, px + pw // 2 + 10, 105], fill=C_MID)

        # Restrained Blood Sigil / Crimson Wall Drapery strip hanging down column
        drape_w = 16
        draw.rectangle([px - drape_w // 2, 120, px + drape_w // 2, 360], fill=C_CRIMSON_DARK)
        draw.line([(px - drape_w // 2, 120), (px - drape_w // 2, 360)], fill=C_CRIMSON_MID, width=1)
        # Triangular banner bottom
        draw.polygon([(px - drape_w // 2, 360), (px + drape_w // 2, 360), (px, 385)], fill=C_CRIMSON_DARK)
        # Subtle embroidered runic symbol in crimson accent
        draw.rectangle([px - 4, 180, px + 4, 220], fill=C_CRIMSON_MID)
        draw.polygon([(px, 160), (px - 6, 175), (px + 6, 175)], fill=C_CRIMSON_ACCENT)

    # Thick heavy vault arches between pillars
    spans = [(80, 260), (260, 460), (460, 640)]
    for x1, x2 in spans:
        mx = (x1 + x2) // 2
        top_y = 25
        draw.polygon([(x1, 70), (mx, top_y), (mx, top_y + 30), (x1, 100)], fill=C_MID)
        draw.polygon([(x2, 70), (mx, top_y), (mx, top_y + 30), (x2, 100)], fill=C_DARK)
        draw.line([(x1, 70), (mx, top_y)], fill=C_LIGHT, width=2)
        # Crimson stone arch frieze
        draw.line([(x1 + 10, 85), (mx, top_y + 18)], fill=C_CRIMSON_MID, width=2)
        draw.line([(x2 - 10, 85), (mx, top_y + 18)], fill=C_CRIMSON_DARK, width=2)

    path = os.path.join(OUTPUT_DIR, "blood_hall_colonnade_mid.png")
    im.save(path, "PNG")
    print(f"Saved: {path} ({w}x{h})")


def create_ramparts_mid():
    """Arena 3 (Ramparts): Distant castle battlements, crenelated parapets, watchtower (720x520)."""
    w, h = 720, 520
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    # Outer Watchtower on the left (x=140)
    tx, tw, th = 140, 110, 360
    top_y = h - th
    # Tower Body
    draw.rectangle([tx - tw // 2, top_y, tx + tw // 2, h], fill=C_DARK)
    # Masonry courses
    for my in range(top_y + 40, h, 28):
        draw.line([(tx - tw // 2, my), (tx + tw // 2, my)], fill=C_SHADOW, width=1)
    # Narrow Arrow Slits
    for sy in [top_y + 80, top_y + 160, top_y + 240]:
        draw.rectangle([tx - 4, sy, tx + 4, sy + 32], fill=(10, 12, 16, 255))
        draw.line([(tx - 6, sy), (tx - 6, sy + 32)], fill=C_LIGHT, width=1)
    # Machicolations & Corbel overhang
    draw.rectangle([tx - tw // 2 - 8, top_y + 20, tx + tw // 2 + 8, top_y + 40], fill=C_MID)
    for cx in range(tx - tw // 2 - 6, tx + tw // 2 + 6, 16):
        draw.rectangle([cx, top_y + 35, cx + 10, top_y + 48], fill=C_DARK)
    # Crenelated Battlements at tower top
    draw.rectangle([tx - tw // 2 - 8, top_y, tx + tw // 2 + 8, top_y + 20], fill=C_MID)
    for mx in range(tx - tw // 2 - 6, tx + tw // 2 + 6, 24):
        draw.rectangle([mx, top_y - 18, mx + 14, top_y], fill=C_LIGHT)
        draw.rectangle([mx + 2, top_y - 16, mx + 12, top_y], fill=C_MID)

    # Stone Curtain Wall & Parapet extending across the scene (y=240 to h)
    parapet_y = 240
    draw.rectangle([0, parapet_y, w, h], fill=C_DARK)
    # Ashlar stonework on curtain wall
    for y in range(parapet_y + 30, h, 32):
        draw.line([(0, y), (w, y)], fill=C_SHADOW, width=2)
        step = 40
        start_x = 20 if (y // 32) % 2 == 0 else 0
        for x in range(start_x, w, step):
            draw.line([(x, y), (x, y + 32)], fill=C_SHADOW, width=1)

    # Parapet Merlons (crenels) along top
    for mx in range(210, w, 44):
        draw.rectangle([mx, parapet_y - 30, mx + 26, parapet_y], fill=C_MID)
        draw.rectangle([mx + 2, parapet_y - 28, mx + 24, parapet_y - 2], fill=C_DARK)
        draw.line([(mx, parapet_y - 30), (mx + 26, parapet_y - 30)], fill=C_LIGHT, width=2)

    # Ruined / Collapsed Archway Section (echoes the WeakArchway theme at x=480)
    ax = 480
    draw.polygon([(ax - 60, parapet_y - 30), (ax, parapet_y - 100), (ax + 20, parapet_y - 70), (ax - 20, parapet_y - 10)], fill=C_MID)
    draw.line([(ax - 60, parapet_y - 30), (ax, parapet_y - 100)], fill=C_LIGHT, width=2)

    path = os.path.join(OUTPUT_DIR, "ramparts_mid_battlements.png")
    im.save(path, "PNG")
    print(f"Saved: {path} ({w}x{h})")


def create_belltower_mid():
    """Arena 4 (Bell Tower): Massive timber rafters, belfry framing, cross-beams (720x520)."""
    w, h = 720, 520
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    C_WOOD_DARK = (28, 22, 18, 255)
    C_WOOD_MID = (46, 36, 28, 255)
    C_WOOD_LIGHT = (70, 56, 44, 255)
    C_IRON = (20, 22, 26, 255)

    # Background masonry belfry louvers / arch openings (x=160, x=560)
    for bx in [160, 560]:
        bw, bh = 80, 260
        by = 120
        # Dark arch opening
        draw.rectangle([bx - bw // 2, by + 40, bx + bw // 2, by + bh], fill=(12, 14, 20, 240))
        draw.polygon([(bx - bw // 2, by + 40), (bx + bw // 2, by + 40), (bx, by)], fill=(12, 14, 20, 240))
        # Wooden acoustic sound louvers (slats)
        for ly in range(by + 30, by + bh, 18):
            draw.line([(bx - bw // 2 + 4, ly), (bx + bw // 2 - 4, ly + 8)], fill=C_WOOD_MID, width=4)
            draw.line([(bx - bw // 2 + 4, ly), (bx + bw // 2 - 4, ly + 8)], fill=C_WOOD_LIGHT, width=1)

    # Massive Timber Upright Posts (x=80, x=300, x=420, x=640)
    posts = [80, 300, 420, 640]
    post_w = 40
    for px in posts:
        draw.rectangle([px - post_w // 2, 40, px + post_w // 2, h], fill=C_WOOD_MID)
        # Woodgrain streaks
        draw.line([(px - 8, 40), (px - 8, h)], fill=C_WOOD_DARK, width=2)
        draw.line([(px + 4, 40), (px + 4, h)], fill=C_WOOD_LIGHT, width=2)
        draw.line([(px - post_w // 2, 40), (px - post_w // 2, h)], fill=C_WOOD_LIGHT, width=2)
        draw.line([(px + post_w // 2, 40), (px + post_w // 2, h)], fill=C_WOOD_DARK, width=2)
        # Iron bracket bands
        for by in [100, 220, 340, 460]:
            draw.rectangle([px - post_w // 2 - 4, by, px + post_w // 2 + 4, by + 12], fill=C_IRON)
            draw.rectangle([px - post_w // 2 - 2, by + 2, px + post_w // 2 + 2, by + 10], fill=C_LIGHT)
            # Rivets
            draw.point((px - 10, by + 6), fill=C_SHADOW)
            draw.point((px + 10, by + 6), fill=C_SHADOW)

    # Giant Horizontal Tie Beams
    tie_ys = [80, 220, 380]
    for ty in tie_ys:
        draw.rectangle([40, ty, w - 40, ty + 30], fill=C_WOOD_MID)
        draw.line([(40, ty), (w - 40, ty)], fill=C_WOOD_LIGHT, width=2)
        draw.line([(40, ty + 30), (w - 40, ty + 30)], fill=C_WOOD_DARK, width=2)

    # Diagonal Timber Cross Braces (St. Andrew's Crosses in the side bays)
    bays = [(80, 300), (420, 640)]
    for x1, x2 in bays:
        # Diagonal 1
        draw.polygon([(x1, 110), (x2, 220), (x2, 236), (x1, 126)], fill=C_WOOD_MID)
        draw.line([(x1, 110), (x2, 220)], fill=C_WOOD_LIGHT, width=2)
        # Diagonal 2
        draw.polygon([(x2, 110), (x1, 220), (x1, 236), (x2, 126)], fill=C_WOOD_DARK)
        draw.line([(x2, 110), (x1, 220)], fill=C_WOOD_LIGHT, width=2)

    # Vertical Hanging Iron Chains framing the central cavity (around x=360, leaving space for GreatBell)
    for cx in [325, 395]:
        for cy in range(80, 420, 10):
            draw.rectangle([cx - 2, cy, cx + 2, cy + 7], fill=C_SHADOW)
            draw.rectangle([cx - 1, cy + 1, cx + 1, cy + 6], fill=C_LIGHT)

    path = os.path.join(OUTPUT_DIR, "belltower_mid_timber_frame.png")
    im.save(path, "PNG")
    print(f"Saved: {path} ({w}x{h})")


def create_transition_pilaster():
    """Near environment heavy stone transition pilaster/buttress (96x520)."""
    w, h = 96, 520
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    # Column shaft
    draw.rectangle([14, 40, w - 14, h], fill=C_DARK)
    # Rusticated stone blocks
    for y in range(40, h - 50, 26):
        draw.line([(14, y), (w - 14, y)], fill=C_SHADOW, width=2)
        draw.line([(14, y + 1), (w - 14, y + 1)], fill=C_LIGHT, width=1)
    # Fluted inner recess
    draw.rectangle([28, 50, w - 28, h - 60], fill=C_SHADOW)
    draw.rectangle([34, 50, w - 34, h - 60], fill=C_MID)
    # Capital at top
    draw.rectangle([6, 30, w - 6, 50], fill=C_MID)
    draw.rectangle([0, 15, w, 30], fill=C_LIGHT)
    # Base plinth at bottom
    draw.rectangle([8, h - 60, w - 8, h - 30], fill=C_MID)
    draw.rectangle([0, h - 30, w, h], fill=C_DARK)

    path = os.path.join(OUTPUT_DIR, "castle_transition_pilaster.png")
    im.save(path, "PNG")
    print(f"Saved: {path} ({w}x{h})")


def create_foreground_valance():
    """Controlled foreground gothic ceiling arch valance (960x140).
    Kept strictly in upper 80 pixels so characters are never obstructed."""
    w, h = 960, 140
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    C_FG_DEEP = (8, 9, 13, 255)
    C_FG_SHADOW = (14, 16, 22, 255)
    C_FG_EDGE = (28, 34, 46, 255)

    # Top ceiling slab
    draw.rectangle([0, 0, w, 24], fill=C_FG_DEEP)

    # Repeating Gothic Arch Valance Cusps (spans of 160 px)
    span = 160
    for sx in range(0, w, span):
        mx = sx + span // 2
        apex_y = 65
        # Arch rib
        draw.polygon([(sx, 24), (mx, apex_y), (mx, apex_y + 16), (sx, 40)], fill=C_FG_SHADOW)
        draw.polygon([(sx + span, 24), (mx, apex_y), (mx, apex_y + 16), (sx + span, 40)], fill=C_FG_DEEP)
        # Highlight edge
        draw.line([(sx, 24), (mx, apex_y)], fill=C_FG_EDGE, width=2)
        # Dropping Pendant / Tracery Spire at apex (max y=80)
        draw.polygon([(mx - 6, apex_y), (mx + 6, apex_y), (mx, apex_y + 18)], fill=C_FG_EDGE)
        draw.rectangle([mx - 2, apex_y + 16, mx + 2, apex_y + 24], fill=C_FG_DEEP)

    path = os.path.join(OUTPUT_DIR, "gothic_ceiling_framing_fg.png")
    im.save(path, "PNG")
    print(f"Saved: {path} ({w}x{h})")


def create_foreground_edge_pillar():
    """Controlled foreground edge pillar/framing (80x540)."""
    w, h = 80, 540
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    C_FG_DEEP = (8, 9, 13, 255)
    C_FG_EDGE = (28, 32, 44, 255)

    draw.rectangle([0, 0, w, h], fill=C_FG_DEEP)
    # Chiseled stone joints
    for y in range(0, h, 36):
        draw.line([(0, y), (w, y)], fill=(4, 5, 8, 255), width=2)
    # Inner rim light
    draw.line([(w - 3, 0), (w - 3, h)], fill=C_FG_EDGE, width=2)

    path = os.path.join(OUTPUT_DIR, "gothic_edge_framing_fg.png")
    im.save(path, "PNG")
    print(f"Saved: {path} ({w}x{h})")


if __name__ == "__main__":
    print("Generating Vlad Stage 3 Parallax Assets...")
    create_distant_skyline()
    create_throne_mid_arch()
    create_blood_hall_mid()
    create_ramparts_mid()
    create_belltower_mid()
    create_transition_pilaster()
    create_foreground_valance()
    create_foreground_edge_pillar()
    print("All parallax assets generated successfully!")
