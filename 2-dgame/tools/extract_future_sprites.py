# -*- coding: utf-8 -*-
"""Bölüm 5 (Distopik Gelecek) sprite hattı — Epic 2D-158.

Kullanıcının yüklediği AI (Gemini) sprite sheet'lerinden (output/future_sources/) oyun asset'i üretir:
  1) future_sheet_mask: yerel arka plan tahmini + taşma dolgusu ile temiz RGBA alfa.
  2) future_sheet_layout: satır etiketlerine göre kareler bağlı bileşenlerle bulunur
     (ya da düzensiz sheet'lerde elle kutulanır).
  3) Her varlığın tüm kareleri ortak ölçeğe indirilir (gövde yüksekliği hedefi), ortak hücreye
     yerleştirilir ve gövdenin taban çizgisi ortak FEET_Y zemin çıpasına hizalanır (ayak kayması yok).
     Uçan birimler gövde merkezine göre hizalanır.
  4) Her animasyon 16 kareye zaman örneklemesiyle genişletilir (subsample_boss_sprites.py ile aynı
     tekdüze indeksleme, bu kez yukarı yönde), sheet PNG + Godot .tres (SpriteFrames) + JSON manifest yazılır.
  5) Sheet'lerdeki HEAD ICONS kutularından portreler, EFFECTS kutularından VFX dokuları çıkarılır.

Çalıştırma (repo kökünden):  py -3.10 2-dgame/tools/extract_future_sprites.py [--preview]
Gereksinim: numpy, scipy, Pillow.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import future_sheet_mask as mask  # noqa: E402
from future_sheet_layout import ANIMS, ENTITIES, HUE_SHIFT, PORTRAITS, SHEETS, SRC_ROOT, TARGET_FRAMES, VFX_CROPS  # noqa: E402

GAME_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_CHAR = os.path.join(GAME_ROOT, "assets", "characters", "future")
OUT_PORTRAIT = os.path.join(GAME_ROOT, "assets", "ui", "portraits")
OUT_VFX = os.path.join(GAME_ROOT, "assets", "effects", "future")
CACHE = os.path.join(GAME_ROOT, "scratch", "future_sheet_cache")
DILATE = 7
MIN_AREA = 500
PAD = 6


def sheet_rgba(name):
    os.makedirs(CACHE, exist_ok=True)
    cache = os.path.join(CACHE, name + ".npy")
    if os.path.exists(cache):
        return np.load(cache)
    folder = os.path.join(SRC_ROOT, SHEETS[name]["src"])
    files = [f for f in os.listdir(folder) if f.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))]
    arr, _ = mask.extract_alpha(mask.load_rgba(os.path.join(folder, sorted(files)[0])))
    arr = arr.astype(np.uint8)
    np.save(cache, arr)
    return arr


def _crop_component(arr, labels, ids, box):
    x0, y0, x1, y1 = box
    sub = arr[y0:y1, x0:x1].copy()
    keep = np.isin(labels[y0:y1, x0:x1], ids)
    sub[..., 3] = np.where(keep, sub[..., 3], 0)
    return sub


def detect_rows(name):
    """Satır etiketine göre kareleri (orijinal çözünürlükte RGBA dizileri) döndürür."""
    cfg = SHEETS[name]
    arr = sheet_rgba(name)
    s = cfg["scale"]
    if "boxes" in cfg:
        out = {}
        for label, boxes in cfg["boxes"].items():
            frames = []
            for b in boxes:
                x0, y0, x1, y1 = [int(round(v * s)) for v in b]
                frames.append(arr[y0:y1, x0:x1].copy())
            out[label] = frames
        return out
    solid = arr[..., 3] > 80
    rows = sorted(cfg["rows"].items(), key=lambda kv: kv[1][0])
    max_y = int(cfg["max_y"] * s)
    out = {}
    for idx, (label, (yc, count)) in enumerate(rows):
        y_top = 0 if idx == 0 else int((rows[idx - 1][1][0] + yc) / 2.0 * s)
        y_bot = max_y if idx == len(rows) - 1 else int((rows[idx + 1][1][0] + yc) / 2.0 * s)
        x_min = int((cfg["special_x0"] if label == "SPECIAL" else cfg["x0"]) * s)
        # Profil bandın orta %70'inden alınır: komşu satırlardan taşan efekt yayları kesimi bozmasın
        core_top = y_top + int((y_bot - y_top) * 0.15)
        core_bot = y_bot - int((y_bot - y_top) * 0.15)
        band = solid[core_top:core_bot, x_min:]
        segs = _segment_columns(band.sum(axis=0).astype(np.float32), count)
        frames = []
        for a, b in segs:
            sub = arr[y_top:y_bot, x_min + a:x_min + b].copy()
            frames.append(_trim(_keep_main(sub)))
        out[label] = frames
    return out


def _segment_columns(profile, count):
    """Sütun yoğunluk profilini tam olarak `count` kareye böler (boşluklardan; gerekirse en seyrek sütundan)."""
    prof = ndimage.uniform_filter1d(profile, 5)
    on = prof > max(2.0, float(prof.max()) * 0.03)
    segs = []
    x = 0
    while x < len(on):
        if on[x]:
            s0 = x
            while x < len(on) and on[x]:
                x += 1
            if x - s0 > 6:
                segs.append([s0, x])
        x += 1
    if not segs:
        return []
    # komşu satırdan sızan ince efekt yayları: kütlesi medyanın %12'sinden az parçalar atılır
    mass = [float(profile[a:b].sum()) for a, b in segs]
    med_mass = float(np.median(mass))
    segs = [sg for sg, m in zip(segs, mass) if m >= med_mass * 0.12]
    while len(segs) > count:
        gaps = [segs[i + 1][0] - segs[i][1] for i in range(len(segs) - 1)]
        widths = [b - a for a, b in segs]
        med = float(np.median(widths))
        # önce çok dar parçaları (kopuk kıvılcım) komşusuna kat; yoksa en dar boşluğu birleştir
        narrow = [i for i, w in enumerate(widths) if w < med * 0.35]
        if narrow:
            i = narrow[0]
            j = i - 1 if i == len(segs) - 1 or (i > 0 and gaps[i - 1] < gaps[i]) else i + 1
            lo, hi = min(i, j), max(i, j)
        else:
            lo = int(np.argmin(gaps))
            hi = lo + 1
        segs[lo] = [segs[lo][0], segs[hi][1]]
        segs.pop(hi)
    while len(segs) < count:
        widths = [b - a for a, b in segs]
        i = int(np.argmax(widths))
        a, b = segs[i]
        lo, hi = a + int((b - a) * 0.2), a + int((b - a) * 0.8)
        cut = lo + int(np.argmin(prof[lo:hi]))
        segs[i] = [a, cut]
        segs.insert(i + 1, [cut, b])
    return [(a, b) for a, b in segs]


def _keep_main(sub):
    """Kareye komşu satırlardan taşan parçaları atar: gövdeye bağlı olmayan ve kenara değen bileşenler silinir."""
    solid = sub[..., 3] > 60
    lab, n = ndimage.label(ndimage.binary_dilation(solid, iterations=3))
    if n <= 1:
        return sub
    sizes = ndimage.sum(solid, lab, range(1, n + 1))
    main = int(np.argmax(sizes)) + 1
    h = sub.shape[0]
    drop = np.zeros_like(solid)
    for i in range(1, n + 1):
        if i == main:
            continue
        ys = np.nonzero(lab == i)[0]
        if ys.min() <= 1 or ys.max() >= h - 2 or sizes[i - 1] < 30:
            drop |= lab == i
    sub[..., 3] = np.where(drop, 0, sub[..., 3])
    return sub


def _trim(sub):
    ys, xs = np.nonzero(sub[..., 3] > 20)
    if len(ys) == 0:
        return sub
    return sub[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


# ---------------------------------------------------------------------------
# Normalizasyon
# ---------------------------------------------------------------------------
def body_metrics(frame):
    """Gövde (en büyük opak bileşen) sınırları: alt kenar, merkez x/y, yükseklik."""
    a = frame[..., 3] > 140
    lab, n = ndimage.label(ndimage.binary_closing(a, iterations=2))
    if n == 0:
        h, w = a.shape
        return {"bottom": h, "cx": w / 2.0, "cy": h / 2.0, "height": h}
    sizes = ndimage.sum(a, lab, range(1, n + 1))
    big = lab == (int(np.argmax(sizes)) + 1)
    ys, xs = np.nonzero(big)
    return {"bottom": int(ys.max()) + 1, "cx": float(xs.mean()), "cy": float(ys.mean()), "height": int(ys.max() - ys.min() + 1)}


def resize_rgba(frame, factor):
    img = Image.fromarray(frame, "RGBA").convert("RGBa")
    w, h = img.size
    nw, nh = max(1, int(round(w * factor))), max(1, int(round(h * factor)))
    return np.asarray(img.resize((nw, nh), Image.LANCZOS).convert("RGBA"))


def hue_shift(frame, degrees):
    if not degrees:
        return frame
    img = Image.fromarray(frame, "RGBA")
    hsv = np.asarray(img.convert("RGB").convert("HSV")).copy()
    hsv[..., 0] = ((hsv[..., 0].astype(np.int32) + int(degrees / 360.0 * 255)) % 256).astype(np.uint8)
    hsv[..., 1] = np.clip(hsv[..., 1].astype(np.int32) * 1.15, 0, 255).astype(np.uint8)
    rgb = np.asarray(Image.fromarray(hsv, "HSV").convert("RGB"))
    return np.dstack([rgb, frame[..., 3]])


def expand_indices(n, k, loop):
    """n kaynak kareyi k kareye tekdüze zaman örneklemesiyle yayar (kare tutma)."""
    if n <= 0:
        return []
    return [min(n - 1, int(math.floor(i * n / float(k)))) for i in range(k)]


def build_entity(entity, rows_cache, preview_dir=None):
    sheet, body_h, flying = ENTITIES[entity]
    rows = rows_cache.setdefault(sheet, detect_rows(sheet))
    anims = ANIMS[entity]
    ref_row = rows.get(SHEETS[sheet].get("ref", anims[next(iter(anims))][0]), [])
    if not ref_row:
        raise RuntimeError("%s: referans satır boş" % entity)
    ref_h = float(np.median([body_metrics(f)["height"] for f in ref_row]))
    factor = body_h / ref_h
    sources = {}
    for anim, (row, sel, _loop, _fps) in anims.items():
        frames = rows.get(row, [])
        if not frames:
            raise RuntimeError("%s/%s: '%s' satırında kare yok" % (entity, anim, row))
        picks = frames if sel is None else [frames[i] for i in sel if -len(frames) <= i < len(frames)]
        row_factor = factor * float(SHEETS[sheet].get("row_scale", {}).get(row, 1.0))
        sources[anim] = [hue_shift(resize_rgba(f, row_factor), HUE_SHIFT.get(entity, 0.0)) for f in picks]
    # Ortak hücre: en geniş sol/sağ ve yukarı/aşağı uzanım
    left = right = up = down = 0.0
    for frames in sources.values():
        for f in frames:
            m = body_metrics(f)
            h, w = f.shape[:2]
            anchor_y = m["cy"] if flying else m["bottom"]
            left, right = max(left, m["cx"]), max(right, w - m["cx"])
            up, down = max(up, anchor_y), max(down, h - anchor_y)
    half_w = int(math.ceil(max(left, right))) + PAD
    cell_w = int(math.ceil(half_w * 2 / 8.0) * 8)
    cell_h = int(math.ceil((up + down + PAD * 2) / 8.0) * 8)
    feet_y = int(round(up + PAD)) if flying else cell_h - PAD
    if not flying:
        cell_h = int(math.ceil((up + PAD * 2 + max(0.0, down)) / 8.0) * 8)
        feet_y = int(round(up + PAD))
    out_dir = os.path.join(OUT_CHAR, entity)
    os.makedirs(out_dir, exist_ok=True)
    manifest = {"character": entity, "source": "output/future_sources/" + SHEETS[sheet]["src"],
                "frame_size": [cell_w, cell_h], "feet_y": feet_y, "anchor": "center" if flying else "feet",
                "background": "transparent_rgba", "animations": []}
    order = list(anims.keys())
    sheet_img = Image.new("RGBA", (cell_w * TARGET_FRAMES, cell_h * len(order)), (0, 0, 0, 0))
    for r, anim in enumerate(order):
        frames = sources[anim]
        cells = []
        for f in frames:
            m = body_metrics(f)
            anchor_y = m["cy"] if flying else m["bottom"]
            cell = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
            ox = int(round(cell_w / 2.0 - m["cx"]))
            oy = int(round(feet_y - anchor_y))
            fimg = Image.fromarray(f, "RGBA")
            cell.paste(fimg, (ox, oy), fimg)
            cells.append(cell)
        _, _, loop, fps = anims[anim]
        for i, src_idx in enumerate(expand_indices(len(cells), TARGET_FRAMES, loop)):
            sheet_img.paste(cells[src_idx], (i * cell_w, r * cell_h))
        manifest["animations"].append({"name": anim, "row": r, "frames": TARGET_FRAMES, "source_frames": len(cells),
                                       "loop": bool(loop), "fps": float(fps)})
    sheet_path = os.path.join(out_dir, entity + "_sheet.png")
    sheet_img.save(sheet_path, optimize=True)
    with open(os.path.join(out_dir, entity + "_manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=1, ensure_ascii=False)
    write_tres(entity, manifest, out_dir)
    if preview_dir:
        bg = Image.new("RGBA", sheet_img.size, (60, 64, 80, 255))
        bg.alpha_composite(sheet_img)
        d = ImageDraw.Draw(bg)
        for r in range(len(order)):
            d.line([(0, r * cell_h + feet_y), (bg.width, r * cell_h + feet_y)], fill=(255, 80, 80, 255))
            d.text((2, r * cell_h + 2), order[r], fill=(255, 255, 0, 255))
        keep = bg.crop((0, 0, cell_w * 8, bg.height))
        keep.convert("RGB").save(os.path.join(preview_dir, entity + "_preview.png"))
    return manifest


def write_tres(entity, manifest, out_dir):
    res_dir = "res://assets/characters/future/%s/" % entity
    cw, ch = manifest["frame_size"]
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (2 + len(manifest["animations"]) * TARGET_FRAMES), "",
             '[ext_resource type="Texture2D" path="%s%s_sheet.png" id="1_sheet"]' % (res_dir, entity), ""]
    anim_blocks = []
    for a in manifest["animations"]:
        frames = []
        for i in range(a["frames"]):
            sid = "A_%s_%d" % (a["name"], i)
            lines += ['[sub_resource type="AtlasTexture" id="%s"]' % sid, 'atlas = ExtResource("1_sheet")',
                      "region = Rect2(%d, %d, %d, %d)" % (i * cw, a["row"] * ch, cw, ch), ""]
            frames.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
        anim_blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                           % (", ".join(frames), "true" if a["loop"] else "false", a["name"], a["fps"]))
    lines += ["[resource]", "animations = [%s]" % ", ".join(anim_blocks), ""]
    with open(os.path.join(out_dir, entity + "_frames.tres"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))


def crop_display_box(sheet, box):
    arr = sheet_rgba(sheet)
    s = SHEETS[sheet]["scale"]
    x0, y0, x1, y1 = [int(round(v * s)) for v in box]
    return arr[y0:y1, x0:x1]


def export_portraits():
    os.makedirs(OUT_PORTRAIT, exist_ok=True)
    for name, (sheet, box) in PORTRAITS.items():
        folder = os.path.join(SRC_ROOT, SHEETS[sheet]["src"])
        files = sorted(f for f in os.listdir(folder) if f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")))
        raw = Image.open(os.path.join(folder, files[0])).convert("RGBA")
        s = SHEETS[sheet]["scale"]
        x0, y0, x1, y1 = [int(round(v * s)) for v in box]
        side = max(x1 - x0, y1 - y0)
        img = raw.crop((x0, y0, x0 + side, y0 + side)).resize((128, 128), Image.LANCZOS)
        img.save(os.path.join(OUT_PORTRAIT, name + ".png"))


def export_frame_portraits():
    """HEAD ICONS kutusu olmayan / ayrı portresi gerekmeyen düşmanlar için ilk idle karesinden Codex portresi."""
    for entity in ("cyber_flying_bug_prime", "cyber_hound", "hydraulic_juggernaut", "chrono_drone"):
        folder = os.path.join(OUT_CHAR, entity)
        with open(os.path.join(folder, entity + "_manifest.json"), encoding="utf-8") as fh:
            cw, ch = json.load(fh)["frame_size"]
        cell = Image.open(os.path.join(folder, entity + "_sheet.png")).crop((0, 0, cw, ch))
        bbox = cell.getbbox() or (0, 0, cw, ch)
        cell = cell.crop(bbox)
        side = max(cell.size) + 8
        canvas = Image.new("RGBA", (side, side), (16, 18, 32, 255))
        canvas.alpha_composite(cell, ((side - cell.width) // 2, (side - cell.height) // 2))
        canvas.resize((128, 128), Image.NEAREST).save(os.path.join(OUT_PORTRAIT, "portrait_%s.png" % entity))


def export_vfx():
    os.makedirs(OUT_VFX, exist_ok=True)
    for name, (sheet, box) in VFX_CROPS.items():
        arr = crop_display_box(sheet, box)
        img = Image.fromarray(arr, "RGBA")
        bbox = img.getbbox()
        if bbox:
            img = img.crop(bbox)
        if max(img.size) > 160:
            f = 160.0 / max(img.size)
            img = Image.fromarray(resize_rgba(np.asarray(img), f), "RGBA")
        img.save(os.path.join(OUT_VFX, name + ".png"))


def main():
    preview_dir = None
    if "--preview" in sys.argv:
        preview_dir = os.path.join(GAME_ROOT, "scratch", "future_previews")
        os.makedirs(preview_dir, exist_ok=True)
    rows_cache = {}
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    for entity in ENTITIES:
        if only and entity not in only:
            continue
        m = build_entity(entity, rows_cache, preview_dir)
        print("%-22s %s feet_y=%d %s" % (entity, m["frame_size"], m["feet_y"],
              " ".join("%s:%d" % (a["name"], a["source_frames"]) for a in m["animations"])))
    if not only:
        export_portraits()
        export_frame_portraits()
        export_vfx()


if __name__ == "__main__":
    main()
