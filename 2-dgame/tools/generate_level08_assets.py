"""
generate_level08_assets.py
Generates authentic pixel-art assets for Stone Age Chapter - Level 08:
- Heart Fragment (Idle, Glow, Pickup particles)
- Time Rift (Portal tear, distortion shockwave, energy particles)
- Flashback sequence (1462 Wallachia camp backdrop, spectral sword soul vision)
- Boss aftermath props (Fallen inert cyber-rex wreckage, crater scorch, plating rubble)
"""

import os
import math
import numpy as np
from PIL import Image, ImageDraw

HEART_DIR = "assets/objects/stoneage/heart_fragment"
RIFT_DIR = "assets/effects/stoneage/time_rift"
FLASH_DIR = "assets/backgrounds/flashbacks"
AFTER_DIR = "assets/environment/stoneage/aftermath"

for d in [HEART_DIR, RIFT_DIR, FLASH_DIR, AFTER_DIR]:
    os.makedirs(d, exist_ok=True)


def noise2d(w, h, scale=10.0, seed=42):
    np.random.seed(seed)
    nw, nh = max(2, int(w / scale)), max(2, int(h / scale))
    grid = np.random.rand(nh, nw).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8)).resize((w, h), Image.Resampling.BILINEAR)
    return np.array(img).astype(np.float32) / 255.0


# -------------------------------------------------------------
# 1. HEART FRAGMENT ASSETS
# -------------------------------------------------------------
def make_heart_fragment_idle():
    w, h = 48, 48
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Crystalline divine heart fragment: sharp facets, cracked right edge, glowing cyan-gold core
    # Outer dark stone-crystal boundary
    outer_poly = [
        (24, 6), (34, 10), (42, 20), (38, 30),
        (28, 42), (24, 45), (18, 38), (8, 26),
        (6, 16), (14, 8)
    ]
    draw.polygon(outer_poly, fill=(24, 45, 60, 255))

    # Inner crystalline body
    inner_poly = [
        (24, 9), (32, 12), (38, 20), (35, 28),
        (27, 38), (24, 42), (19, 36), (10, 24),
        (9, 16), (15, 11)
    ]
    draw.polygon(inner_poly, fill=(45, 120, 165, 255))

    # Facet shards & highlights (Pale Cyan & Gold)
    draw.polygon([(24, 9), (32, 12), (28, 22), (22, 18)], fill=(110, 215, 255, 255))
    draw.polygon([(15, 11), (22, 18), (18, 28), (10, 24)], fill=(75, 175, 230, 255))
    draw.polygon([(22, 18), (28, 22), (24, 34), (18, 28)], fill=(160, 240, 255, 255))

    # Pulsing Golden Core in center
    draw.ellipse([21, 19, 27, 27], fill=(255, 220, 110, 255))
    draw.ellipse([23, 21, 25, 25], fill=(255, 255, 210, 255))

    # Jagged fracture on right flank where other pieces broke off
    fracture = [(38, 20), (32, 23), (36, 26), (30, 30), (35, 28)]
    draw.line(fracture, fill=(20, 30, 42, 255), width=2)
    # Energy crackle leaking from fracture
    draw.line([(32, 23), (35, 21)], fill=(255, 240, 150, 255), width=1)
    draw.line([(30, 30), (33, 33)], fill=(140, 230, 255, 255), width=1)

    img.save(os.path.join(HEART_DIR, "heart_fragment_idle.png"))
    print("Saved heart_fragment_idle.png")


def make_heart_fragment_glow():
    w, h = 64, 64
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    cx, cy = 32, 32
    max_r = 30.0

    for y in range(h):
        for x in range(w):
            d = math.hypot(x - cx, y - cy)
            if d < max_r:
                factor = (1.0 - (d / max_r)) ** 1.8
                r = int(70 * factor + 180 * (factor ** 2))
                g = int(180 * factor + 75 * (factor ** 2))
                b = int(255 * factor)
                a = int(190 * factor)
                arr[y, x] = [min(255, r), min(255, g), min(255, b), a]

    img = Image.fromarray(arr)
    img.save(os.path.join(HEART_DIR, "heart_fragment_glow.png"))
    print("Saved heart_fragment_glow.png")


def make_heart_fragment_pickup():
    w, h = 32, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # 4-pointed radiant sparkle star
    draw.polygon([(16, 2), (18, 14), (30, 16), (18, 18), (16, 30), (14, 18), (2, 16), (14, 14)], fill=(255, 245, 180, 255))
    draw.ellipse([13, 13, 19, 19], fill=(255, 255, 255, 255))
    img.save(os.path.join(HEART_DIR, "heart_fragment_pickup.png"))
    print("Saved heart_fragment_pickup.png")


# -------------------------------------------------------------
# 2. TIME RIFT ASSETS
# -------------------------------------------------------------
def make_time_rift_portal():
    w, h = 128, 192
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = 64, 96
    # Outer spatial distortion vortex (deep void violet & dark teal)
    for rad_y in range(86, 20, -6):
        rad_x = int(rad_y * 0.45)
        step = (86 - rad_y) / 66.0
        r = int(35 + 85 * step)
        g = int(15 + 160 * step)
        b = int(70 + 185 * step)
        a = int(160 + 80 * step)
        draw.ellipse([cx - rad_x, cy - rad_y, cx + rad_x, cy + rad_y], fill=(r, g, b, a))

    # Inner abyssal void slit (nearly black space tear)
    draw.polygon([
        (cx, cy - 82), (cx + 14, cy - 35), (cx + 18, cy + 10),
        (cx + 8, cy + 65), (cx, cy + 85), (cx - 10, cy + 55),
        (cx - 16, cy), (cx - 12, cy - 45)
    ], fill=(8, 4, 14, 255))

    # Violent electric temporal arc tendrils
    arcs = [
        [(cx - 16, cy - 50), (cx - 28, cy - 30), (cx - 14, cy - 10)],
        [(cx + 18, cy - 40), (cx + 32, cy - 20), (cx + 20, cy + 5)],
        [(cx - 14, cy + 30), (cx - 30, cy + 45), (cx - 10, cy + 60)],
        [(cx + 12, cy + 35), (cx + 26, cy + 50), (cx + 6, cy + 70)]
    ]
    for arc in arcs:
        draw.line(arc, fill=(140, 220, 255, 240), width=2)
        draw.line(arc, fill=(230, 250, 255, 255), width=1)

    # Core temporal singularity line
    draw.line([(cx, cy - 70), (cx, cy + 70)], fill=(240, 255, 255, 255), width=2)

    img.save(os.path.join(RIFT_DIR, "time_rift_portal.png"))
    print("Saved time_rift_portal.png")


def make_time_rift_particles():
    w, h = 16, 16
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Swirling violet-cyan temporal spark
    draw.ellipse([3, 3, 13, 13], fill=(130, 90, 230, 200))
    draw.ellipse([5, 5, 11, 11], fill=(120, 220, 255, 240))
    draw.ellipse([7, 7, 9, 9], fill=(255, 255, 255, 255))
    img.save(os.path.join(RIFT_DIR, "time_rift_particles.png"))
    print("Saved time_rift_particles.png")


def make_time_rift_shockwave():
    w, h = 96, 96
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Distortion ripple shockwave ring
    draw.ellipse([6, 6, 90, 90], outline=(160, 220, 255, 180), width=3)
    draw.ellipse([10, 10, 86, 86], outline=(100, 140, 230, 120), width=2)
    img.save(os.path.join(RIFT_DIR, "time_rift_shockwave.png"))
    print("Saved time_rift_shockwave.png")


# -------------------------------------------------------------
# 3. FLASHBACK ASSETS (1462 WALLACHIA & SPECTRAL SWORD VISION)
# -------------------------------------------------------------
def make_flashback_wallachia_camp():
    # 960x540 pixel canvas scaled up for dark, ethereal, memory aesthetic
    w, h = 960, 540
    arr = np.zeros((h, w, 4), dtype=np.uint8)

    # Desaturated cold memory palette (dark sepia & charcoal monochrome)
    n = noise2d(w, h, scale=40.0, seed=1462)
    y_idx = np.arange(h)[:, None]
    t = y_idx / float(h)

    # Sky gradient: dark foggy gothic night
    for y in range(h):
        for x in range(w):
            val = n[y, x] * 0.4
            base_lum = int((20 * (1.0 - t[y, 0]) + 10 * t[y, 0]) + val * 25)
            # Sepia / Memory tint: R slightly higher, B slightly lower
            r = min(255, int(base_lum * 1.15))
            g = min(255, int(base_lum * 1.05))
            b = min(255, int(base_lum * 0.95))
            arr[y, x] = [r, g, b, 255]

    img = Image.fromarray(arr)
    draw = ImageDraw.Draw(img)

    # Distant gothic pine forest silhouettes
    for px in range(0, w, 18):
        ph = int(120 + math.sin(px * 0.02) * 50)
        draw.polygon([(px - 14, 340), (px, 340 - ph), (px + 14, 340)], fill=(12, 10, 11, 255))

    # Ground loam / foggy mud
    draw.polygon([(0, 330), (w, 330), (w, h), (0, h)], fill=(16, 14, 15, 255))

    # Royal Ottoman tents / Wallachian campaign pavilions in fog (left side)
    draw.polygon([(80, 340), (160, 230), (240, 340)], fill=(28, 24, 25, 255))
    draw.line([(160, 230), (160, 205)], fill=(45, 38, 35, 255), width=3) # Banner pole
    draw.polygon([(160, 205), (195, 215), (160, 225)], fill=(75, 45, 40, 255)) # Crescent / crusader banner

    draw.polygon([(220, 340), (280, 250), (340, 340)], fill=(22, 19, 20, 255))

    # Fallen comrade & wooden barricade silhouetted
    draw.line([(380, 330), (450, 345)], fill=(32, 28, 26, 255), width=6)
    draw.ellipse([435, 335, 455, 350], fill=(24, 20, 22, 255)) # Helmet

    # Eerie crimson time rift tearing the sky in the memory center
    draw.polygon([(620, 120), (635, 220), (620, 320), (610, 210)], fill=(85, 18, 22, 210))
    draw.line([(620, 130), (622, 310)], fill=(220, 75, 60, 255), width=3)
    draw.line([(621, 150), (621, 290)], fill=(255, 190, 160, 255), width=1)

    # Vignette shadow overlay
    img.save(os.path.join(FLASH_DIR, "flashback_wallachia_1462_camp.png"))
    print("Saved flashback_wallachia_1462_camp.png")


def make_flashback_sword_soul_vision():
    w, h = 320, 320
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Ethereal spectral blade with imprisoned soul runes glowing in memory
    cx, cy = 160, 160

    # Blade aura
    draw.polygon([(cx - 22, cy + 90), (cx - 14, cy - 90), (cx, cy - 130), (cx + 14, cy - 90), (cx + 22, cy + 90)], fill=(40, 80, 120, 120))

    # Steel blade core
    draw.polygon([(cx - 10, cy + 85), (cx - 7, cy - 85), (cx, cy - 120), (cx + 7, cy - 85), (cx + 10, cy + 85)], fill=(160, 190, 215, 255))
    # Full length center fuller
    draw.line([(cx, cy - 110), (cx, cy + 80)], fill=(220, 240, 255, 255), width=2)

    # Crossguard
    draw.polygon([(cx - 45, cy + 85), (cx + 45, cy + 85), (cx + 40, cy + 98), (cx - 40, cy + 98)], fill=(65, 75, 85, 255))
    # Grip & Pommel
    draw.rectangle([cx - 5, cy + 98, cx + 5, cy + 135], fill=(35, 30, 25, 255))
    draw.ellipse([cx - 10, cy + 135, cx + 10, cy + 152], fill=(85, 95, 105, 255))

    # Glowing soul eye / rune in pommel
    draw.ellipse([cx - 4, cy + 140, cx + 4, cy + 148], fill=(120, 225, 255, 255))

    # Spectral rune sigils floating along blade
    runes_y = [cy - 60, cy - 25, cy + 15, cy + 50]
    for ry in runes_y:
        draw.ellipse([cx - 3, ry - 3, cx + 3, ry + 3], fill=(255, 240, 140, 255))

    img.save(os.path.join(FLASH_DIR, "flashback_sword_soul_vision.png"))
    print("Saved flashback_sword_soul_vision.png")


# -------------------------------------------------------------
# 4. BOSS AFTERMATH ASSETS
# -------------------------------------------------------------
def make_fallen_trex_wreckage():
    w, h = 320, 180
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Slumped, inert Cyber-Rex carcass in background crater:
    # Massive reptilian head resting on earth, jaws parted, severed cyber cables,
    # crushed titanium chest armor where Heart Piece was dislodged.

    # 1. Main body mass / torso resting slumped
    draw.polygon([
        (40, 150), (90, 60), (170, 50), (250, 80),
        (290, 120), (300, 160), (220, 165), (120, 165)
    ], fill=(42, 36, 32, 255)) # Dark primordial hide

    # 2. Cybernetic armored spine & severed plating
    draw.polygon([(90, 60), (170, 50), (180, 75), (85, 85)], fill=(62, 70, 80, 255))
    # Titanium rib cage / armor cowling torn open
    draw.polygon([(110, 85), (170, 80), (160, 125), (100, 120)], fill=(28, 32, 38, 255))
    # Ruptured cavity where the Heart Piece was extracted (faint residual teal embers)
    draw.ellipse([120, 92, 150, 115], fill=(15, 20, 25, 255))
    draw.ellipse([126, 98, 144, 110], fill=(40, 85, 110, 180))

    # 3. Massive theropod skull lying sideways on ground (left)
    draw.polygon([
        (20, 150), (45, 95), (105, 90), (115, 140), (70, 155)
    ], fill=(48, 42, 38, 255))
    # Massive eye socket (dark, extinguished, no glowing red eye anymore)
    draw.ellipse([65, 105, 85, 122], fill=(18, 15, 16, 255))
    # Open jaws resting in soil with serrated teeth
    draw.polygon([(20, 150), (55, 142), (75, 155), (15, 158)], fill=(32, 28, 26, 255))
    for tx in [28, 38, 48, 58]:
        draw.polygon([(tx, 145), (tx + 3, 152), (tx + 6, 145)], fill=(180, 175, 160, 255))

    # 4. Severed mechanical armatures & piston limp in mud
    draw.line([(100, 120), (75, 145), (85, 165)], fill=(55, 65, 75, 255), width=8)
    draw.ellipse([70, 140, 82, 152], fill=(85, 95, 105, 255)) # Elbow servo

    # 5. Trailing severed cables with dormant copper threads
    draw.arc([145, 105, 190, 145], start=0, end=140, fill=(75, 50, 30, 255), width=3)
    draw.arc([155, 115, 210, 160], start=10, end=160, fill=(50, 60, 70, 255), width=3)

    img.save(os.path.join(AFTER_DIR, "fallen_trex_wreckage.png"))
    print("Saved fallen_trex_wreckage.png")


def make_crater_impact_scorch():
    w, h = 256, 80
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Scorched blast mark from boss laser / final collapse
    draw.ellipse([8, 15, w - 8, 70], fill=(18, 14, 12, 240))
    draw.ellipse([30, 25, w - 30, 62], fill=(10, 8, 7, 255))

    # Glassified molten rock veins
    draw.line([(50, 42), (110, 40), (170, 45), (210, 38)], fill=(40, 32, 28, 255), width=3)
    draw.line([(70, 45), (120, 48), (160, 44)], fill=(65, 45, 30, 255), width=1)

    img.save(os.path.join(AFTER_DIR, "crater_impact_scorch.png"))
    print("Saved crater_impact_scorch.png")


def make_shattered_mecha_plates():
    w, h = 120, 60
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Dispersed chunks of shattered cybernetic plate armor
    shards = [
        ([(12, 35), (32, 18), (45, 28), (28, 45)], (65, 75, 85, 255)),
        ([(50, 38), (72, 22), (85, 36), (62, 50)], (50, 60, 70, 255)),
        ([(82, 42), (98, 30), (112, 40), (95, 52)], (75, 85, 95, 255)),
    ]
    for poly, color in shards:
        draw.polygon(poly, fill=color)
        draw.line(poly + [poly[0]], fill=(110, 125, 140, 255), width=1)

    img.save(os.path.join(AFTER_DIR, "shattered_mecha_plates.png"))
    print("Saved shattered_mecha_plates.png")


if __name__ == "__main__":
    print("Generating assets for Level 08: İlk Kalp Parçası...")
    make_heart_fragment_idle()
    make_heart_fragment_glow()
    make_heart_fragment_pickup()
    make_time_rift_portal()
    make_time_rift_particles()
    make_time_rift_shockwave()
    make_flashback_wallachia_camp()
    make_flashback_sword_soul_vision()
    make_fallen_trex_wreckage()
    make_crater_impact_scorch()
    make_shattered_mecha_plates()
    print("All Level 08 assets generated successfully!")
