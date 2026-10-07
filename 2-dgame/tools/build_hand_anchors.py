"""El noktası tablosu üretir: tools/knight_hand_anchors.json

1) Eldiven rengi otomatik tespit: koşu karelerinde ağırlık merkezi en çok
   salınan palet rengi (kol sallanması) = ön kol eldiveni.
2) Her karede eldiven maskesi (eldiven rengi + ona bitişik koyu bronz detay)
   içinden gövde merkezine en uzak küme = yumruk; yumruğun ortası = el noktası.
3) Kılıç açısı ANGLE_TABLE'dan gelir (yalnızca 0, 45, 90, 135, -45, -90).
   Otomatik tespitin yetersiz kaldığı kareler HAND_OVERRIDES ile düzeltilir
   (önizleme incelenerek belirlenmiştir) ve JSON'da "source": "manual" olarak işaretlenir.
"""
import json
import os
import statistics
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from knight_frames_lib import parse_tres, load_frame, OVERLAY_ANIMS, PROJECT_DIR  # noqa: E402

OUT_PATH = os.path.join(PROJECT_DIR, "tools", "knight_hand_anchors.json")
OUTLINE = (26, 14, 19)
ALLOWED = {0, 45, 90, 135, -45, -90}

# Animasyon başına kare kare kılıç açısı (liste tek elemanlıysa tüm karelere uygulanır)
ANGLE_TABLE = {
    "idle": [45],
    "run": [45, 45, 45, 135, 135, 135, 135, 135, 45, 45],
    "jump": [45],
    "jump_apex": [45],
    "fall": [45],
    "crouch": [0],
    "crouch_walk": [0],
    "wall_slide": [90],
    "roll": [45, 45, 45, 45, 45, 0, 45, 45, 45, 45, 45, 45],
    "slide": [0],
    "dash": [135],
}

# (anim, kare) -> (x, y) elle düzeltilmiş el noktaları
HAND_OVERRIDES = {}
# (anim, kare) -> False : o karede overlay gizli (önizleme incelenerek seçildi)
#  - slide 0-2: kılıç eli yere dayalı; izinli açılarla kılıç ya zemine ya gövdeye giriyor
#  - roll 6-10: takla sırasında el ters/gövde içinde; 180/-135 açı olmadan temiz tutuş yok
VISIBLE_OVERRIDES = {
    ("slide", 0): False, ("slide", 1): False, ("slide", 2): False,
    ("roll", 6): False, ("roll", 7): False, ("roll", 8): False, ("roll", 9): False, ("roll", 10): False,
}


def detect_glove_color(anims):
    per_color = defaultdict(list)
    for png, rect in anims["run"]:
        f = load_frame(png, rect)
        pts = defaultdict(list)
        for y in range(f.height):
            for x in range(f.width):
                p = f.getpixel((x, y))
                if p[3] and p[:3] != OUTLINE:
                    pts[p[:3]].append(x)
        for c, xs in pts.items():
            per_color[c].append(sum(xs) / len(xs))
    scores = {c: statistics.pstdev(v) for c, v in per_color.items() if len(v) == len(anims["run"])}
    ranked = sorted(scores.items(), key=lambda kv: -kv[1])
    return ranked[0][0], ranked


def neighbors4(x, y):
    return ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))


def find_hand(frame, glove, accent):
    W, H = frame.size
    opaque = [(x, y) for y in range(H) for x in range(W) if frame.getpixel((x, y))[3]]
    if not opaque:
        return None
    cx = sum(p[0] for p in opaque) / len(opaque)
    cy = sum(p[1] for p in opaque) / len(opaque)
    mask = {(x, y) for (x, y) in opaque if frame.getpixel((x, y))[:3] == glove}
    if not mask:
        return None
    # eldivene bitişik koyu bronz (eldiven detayı) piksellerini ekle
    grow = True
    while grow:
        grow = False
        for (x, y) in list(mask):
            for n in neighbors4(x, y):
                if n not in mask and 0 <= n[0] < W and 0 <= n[1] < H:
                    p = frame.getpixel(n)
                    if p[3] and p[:3] == accent:
                        mask.add(n)
                        grow = True
    far = max(mask, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)
    near = [p for p in mask if abs(p[0] - far[0]) <= 2 and abs(p[1] - far[1]) <= 2]
    hx = round(sum(p[0] for p in near) / len(near))
    hy = round(sum(p[1] for p in near) / len(near))
    return hx, hy


def main():
    anims = parse_tres()
    glove, ranked = detect_glove_color(anims)
    accent = (105, 85, 42)
    print("Eldiven rengi (otomatik):", glove)
    for c, s in ranked[:4]:
        print("   ", c, round(s, 2))
    data = {
        "_doc": "Kare yerel koordinatı (120x80 kare, sol üst 0,0). Karakter sağa bakar. "
                "angle: Godot rotation derecesi (0 ileri, 90 aşağı, -90 yukarı, 45 ileri-aşağı, "
                "135 geri-aşağı, -45 ileri-yukarı). Kılıç sapının t=0 pikseli (hand_x, hand_y)'ye oturur.",
        "frame_size": [120, 80],
        "glove_color": list(glove),
        "sword_meta": json.load(open(os.path.join(PROJECT_DIR, "assets", "items", "sword_overlay",
                                                  "sword_overlay_meta.json"), encoding="utf-8")),
        "animations": {},
    }
    for anim in OVERLAY_ANIMS:
        frames = []
        angles = ANGLE_TABLE[anim]
        for i, (png, rect) in enumerate(anims[anim]):
            f = load_frame(png, rect)
            src = "auto"
            hand = find_hand(f, glove, accent)
            if (anim, i) in HAND_OVERRIDES:
                hand = HAND_OVERRIDES[(anim, i)]
                src = "manual"
            angle = angles[i] if len(angles) > 1 else angles[0]
            assert angle in ALLOWED, (anim, i, angle)
            visible = VISIBLE_OVERRIDES.get((anim, i), hand is not None)
            frames.append({"frame": i, "hand_x": hand[0] if hand else 0, "hand_y": hand[1] if hand else 0,
                           "angle": angle, "visible": visible, "source": src})
        data["animations"][anim] = frames
        print(anim, [(fr["hand_x"], fr["hand_y"], fr["angle"]) for fr in frames])
    with open(OUT_PATH, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=1)
    print("Yazıldı:", OUT_PATH)


if __name__ == "__main__":
    main()
