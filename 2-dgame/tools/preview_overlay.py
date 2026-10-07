"""tools/preview/overlay_check.png üretir.

Her animasyonun tüm kareleri + kılıç overlay'i, 6x nearest-neighbor, el noktası
artı işaretiyle. Overlay oyundaki ile aynı formülle yerleştirilir:
  sol_üst = (hand_x - pivot_x, hand_y - pivot_y)
Orijinal karakter pikselleri değiştirilmez (yalnızca önizleme görseli üretilir).
"""
import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from knight_frames_lib import parse_tres, load_frame, OVERLAY_ANIMS, PROJECT_DIR  # noqa: E402

SCALE = 6
CROP = (20, 28, 100, 80)  # kare içinde gösterilecek bölge (karakter + kılıç)
BG = (24, 26, 38, 255)
GROUND = (52, 62, 80, 255)


def main():
    # isteğe bağlı: "run" veya "run:2-6" biçiminde animasyon/kare aralığı
    args = sys.argv[1:]
    ranges = {}
    for a in args:
        name, _, rng = a.partition(":")
        ranges[name] = tuple(int(v) for v in rng.split("-")) if rng else None
    only = list(ranges)
    anchors = json.load(open(os.path.join(PROJECT_DIR, "tools", "knight_hand_anchors.json"), encoding="utf-8"))
    meta = anchors["sword_meta"]
    sword_dir = os.path.join(PROJECT_DIR, "assets", "items", "sword_overlay")
    swords = {k: Image.open(os.path.join(sword_dir, v["file"])).convert("RGBA") for k, v in meta.items()}
    anims = parse_tres()
    names = [a for a in OVERLAY_ANIMS if not only or a in only]

    def frame_ids(a):
        r = ranges.get(a)
        n = len(anims[a])
        return list(range(r[0], min(r[1], n - 1) + 1)) if r else list(range(n))

    cw, ch = CROP[2] - CROP[0], CROP[3] - CROP[1]
    max_frames = max(len(frame_ids(a)) for a in names)
    label_w = 110
    cell_w, cell_h = cw * SCALE, ch * SCALE
    sheet = Image.new("RGBA", (label_w + max_frames * (cell_w + 4), len(names) * (cell_h + 18)), (12, 12, 18, 255))
    d = ImageDraw.Draw(sheet)
    for row, anim in enumerate(names):
        y0 = row * (cell_h + 18)
        d.text((4, y0 + cell_h // 2), anim, fill=(230, 230, 230, 255))
        for col, i in enumerate(frame_ids(anim)):
            png, rect = anims[anim][i]
            fr = anchors["animations"][anim][i]
            frame = load_frame(png, rect)
            canvas = Image.new("RGBA", frame.size, BG)
            canvas.alpha_composite(frame)
            if fr["visible"]:
                m = meta[str(fr["angle"])]
                canvas.alpha_composite(swords[str(fr["angle"])],
                                       (fr["hand_x"] - m["pivot"][0], fr["hand_y"] - m["pivot"][1]))
            cell = canvas.crop(CROP).resize((cell_w, cell_h), Image.NEAREST)
            cd = ImageDraw.Draw(cell)
            hx = (fr["hand_x"] - CROP[0]) * SCALE + SCALE // 2
            hy = (fr["hand_y"] - CROP[1]) * SCALE + SCALE // 2
            cd.line((hx - 5, hy, hx + 5, hy), fill=(255, 40, 200, 255))
            cd.line((hx, hy - 5, hx, hy + 5), fill=(255, 40, 200, 255))
            x0 = label_w + col * (cell_w + 4)
            sheet.paste(cell, (x0, y0))
            d.text((x0 + 3, y0 + cell_h + 2),
                   f"{i} ({fr['hand_x']},{fr['hand_y']}) {fr['angle']}" + ("" if fr["visible"] else " GIZLI"),
                   fill=(180, 180, 180, 255))
    out_dir = os.path.join(PROJECT_DIR, "tools", "preview")
    os.makedirs(out_dir, exist_ok=True)
    tag = "_".join(a.replace(":", "").replace("-", "to") for a in args)
    out = os.path.join(out_dir, "overlay_check.png" if not args else f"overlay_check_{tag}.png")
    sheet.convert("RGB").save(out)
    print("Önizleme:", out, sheet.size)


if __name__ == "__main__":
    main()
