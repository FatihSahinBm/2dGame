#!/usr/bin/env python3
"""Görsel üretim aracından çıkan animasyon sayfalarını oyun içi sprite şeritlerine dönüştürür.

Her animasyon sayfası (şeffaf zeminli, ızgara dizilimli kareler) şu adımlardan geçer:
  1. Kareler satır/sütun boşluklarından otomatik ayrılır.
  2. Oyun içi gerçek boyuta küçültülür (1:1 texel; sahnede ölçek kullanılmaz). Ölçek,
     "scale_reference" animasyonunun boyuna göre belirlenir; diğer sayfalar siluet alanı
     eşitlenerek aynı ölçeğe getirilir (üretim aracı her sayfayı farklı boyda çizebilir).
  3. Kareler hizalanır: "ground" -> ayaklar ortak zemin çizgisinde, "center" -> uçan
     karakterler için gövde ağırlık merkezi hücre ortasında.
  4. Tüm animasyonlar aynı hücre boyutunda yatay şerit ve tek SpriteFrames kaynağı olur.

Kullanım:
  py -3.13 tools/build_minion_sprites.py tools/minion_sprites/raptor.json
"""
from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image

ALPHA_CUT = 128     # Bu değerin altındaki alfa tamamen şeffaf sayılır (sert piksel kenarı)
MIN_GAP_PX = 8      # İki kareyi ayıran en dar boşluk
MIN_RUN_PX = 12     # Bundan dar parçalar başıboş piksel sayılıp atılır
CELL_PAD_PX = 2     # Hücre kenar payı
PREVIEW_ZOOM = 3
PREVIEW_BG = (58, 62, 74, 255)


@dataclass
class RawFrame:
    crop: Image.Image    # Sayfadan kesilmiş, ölçeklenmemiş kare
    lift_px: int         # Satırın zemin çizgisinden yükseklik (ham piksel)
    area: int            # Siluet alanı (ham piksel)


@dataclass
class Frame:
    image: Image.Image   # Küçültülmüş, sert alfalı kare
    anchor: tuple[float, float]  # Gövde ağırlık merkezi (kare içi x, y)
    lift: int            # Zemin çizgisinden yükseklik (px); 0 = ayak yerde


def _runs(mask_1d: np.ndarray) -> list[tuple[int, int]]:
    """True bölgelerini (başlangıç, bitiş) olarak döndürür; dar boşlukları birleştirir."""
    idx = np.flatnonzero(mask_1d)
    if idx.size == 0:
        return []
    breaks = np.flatnonzero(np.diff(idx) > MIN_GAP_PX)
    starts = np.concatenate(([idx[0]], idx[breaks + 1]))
    ends = np.concatenate((idx[breaks], [idx[-1]])) + 1
    return [(int(s), int(e)) for s, e in zip(starts, ends) if e - s >= MIN_RUN_PX]


def cut_frames(sheet_path: Path, expected: int) -> list[RawFrame]:
    """Sayfadaki kareleri okuma sırasıyla (soldan sağa, yukarıdan aşağıya) keser."""
    sheet = Image.open(sheet_path).convert("RGBA")
    mask = np.array(sheet)[..., 3] >= ALPHA_CUT
    frames: list[RawFrame] = []
    for row_y0, row_y1 in _runs(mask.any(axis=1)):
        band = mask[row_y0:row_y1]
        boxes = []
        for x0, x1 in _runs(band.any(axis=0)):
            ys = np.flatnonzero(band[:, x0:x1].any(axis=1))
            boxes.append((x0, row_y0 + int(ys[0]), x1, row_y0 + int(ys[-1]) + 1))
        ground_y = max(b[3] for b in boxes)
        for x0, y0, x1, y1 in boxes:
            frames.append(RawFrame(sheet.crop((x0, y0, x1, y1)), ground_y - y1,
                                   int(mask[y0:y1, x0:x1].sum())))
    if len(frames) != expected:
        raise ValueError(f"{sheet_path.name}: {expected} kare bekleniyordu, {len(frames)} bulundu")
    return frames


def scale_frame(raw: RawFrame, scale: float, grounded: bool) -> Frame:
    """Önceden çarpılmış alfayla küçültür (koyu kenar saçağı oluşmaz), alfayı sertleştirir."""
    size = (max(1, round(raw.crop.width * scale)), max(1, round(raw.crop.height * scale)))
    small = np.array(raw.crop.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA"))
    opaque = small[..., 3] >= ALPHA_CUT
    small[..., 3] = np.where(opaque, 255, 0)
    small[~opaque, :3] = 0
    ys, xs = np.nonzero(opaque)
    lift = 0 if grounded else round(raw.lift_px * scale)
    return Frame(Image.fromarray(small, "RGBA"), (float(xs.mean()), float(ys.mean())), lift)


def quantize_strip(strip: Image.Image, colors: int) -> Image.Image:
    """Küçültmenin ürettiği ara tonları sınırlı palete indirir (piksel-art görünümü)."""
    if colors <= 0:
        return strip
    alpha = strip.getchannel("A")
    out = strip.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT,
                                        dither=Image.Dither.NONE).convert("RGBA")
    out.putalpha(alpha)
    return out


def build_strip(frames: list[Frame], cell: tuple[int, int], centered: bool, colors: int) -> Image.Image:
    cell_w, cell_h = cell
    strip = Image.new("RGBA", (cell_w * len(frames), cell_h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        x = i * cell_w + round(cell_w / 2 - f.anchor[0])
        y = round(cell_h / 2 - f.anchor[1]) if centered else cell_h - CELL_PAD_PX - f.lift - f.image.height
        strip.alpha_composite(f.image, (x, y))
    return quantize_strip(strip, colors)


def save_preview(strip: Image.Image, cell_w: int, fps: float, out_base: Path) -> None:
    """3x büyütülmüş kontrol görseli ve GIF (oyuna girmez, yalnızca gözle kontrol için)."""
    big = strip.resize((strip.width * PREVIEW_ZOOM, strip.height * PREVIEW_ZOOM), Image.Resampling.NEAREST)
    sheet = Image.new("RGBA", big.size, PREVIEW_BG)
    sheet.alpha_composite(big)
    sheet.convert("RGB").save(out_base.with_suffix(".png"))
    step = cell_w * PREVIEW_ZOOM
    cells = [sheet.crop((i * step, 0, (i + 1) * step, sheet.height)).convert("RGB")
             for i in range(strip.width // cell_w)]
    cells[0].save(out_base.with_suffix(".gif"), save_all=True, append_images=cells[1:],
                  duration=round(1000 / fps), loop=0)


def write_sprite_frames(path: Path, res_dir: str, cell: tuple[int, int], animations: list[dict]) -> None:
    """Şeritleri AtlasTexture bölgeleriyle kullanan Godot 4 SpriteFrames (.tres) kaynağını yazar."""
    ext, sub, anims = [], [], []
    for n, anim in enumerate(animations, start=1):
        name = anim["name"]
        ext.append(f'[ext_resource type="Texture2D" path="{res_dir}/{name}.png" id="{n}_{name}"]')
        entries = []
        for i in range(anim["frames"]):
            sub.append(f'[sub_resource type="AtlasTexture" id="Atlas_{name}_{i}"]\n'
                       f'atlas = ExtResource("{n}_{name}")\n'
                       f'region = Rect2({i * cell[0]}, 0, {cell[0]}, {cell[1]})\n')
            entries.append(f'{{\n"duration": 1.0,\n"texture": SubResource("Atlas_{name}_{i}")\n}}')
        anims.append('{\n"frames": [' + ", ".join(entries) + '],\n'
                     f'"loop": {"true" if anim["loop"] else "false"},\n'
                     f'"name": &"{name}",\n"speed": {float(anim["fps"])}\n}}')
    text = ('[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(ext) + "\n\n"
            + "\n".join(sub) + "\n[resource]\nanimations = [" + ", ".join(anims) + "]\n")
    path.write_text(text, encoding="utf-8", newline="\n")


def main(config_path: Path) -> None:
    cfg = json.loads(config_path.read_text(encoding="utf-8"))
    base = config_path.parent
    out_dir = (base / cfg["out_dir"]).resolve()
    preview_dir = (base / cfg.get("preview_dir", cfg["out_dir"] + "/preview")).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    preview_dir.mkdir(parents=True, exist_ok=True)
    centered = cfg.get("align", "ground") == "center"
    animations = cfg["animations"]

    raw = {a["name"]: cut_frames((base / a["sheet"]).resolve(), a["frames"]) for a in animations}
    ref = raw[cfg["scale_reference"]]
    ref_scale = cfg["target_height"] / float(np.median([f.crop.height for f in ref]))
    ref_area = float(np.median([f.area for f in ref])) * ref_scale ** 2

    loaded: dict[str, list[Frame]] = {}
    for anim in animations:
        frames = raw[anim["name"]]
        # "scale_frames": yere yığılma gibi siluetin küçüldüğü animasyonlarda ölçeği yalnızca
        # ayaktaki karelerden hesaplar; yoksa animasyon başlarken karakter büyümüş görünür.
        measured = [frames[i] for i in anim.get("scale_frames", range(len(frames)))]
        scale = float(np.sqrt(ref_area / np.median([f.area for f in measured])))
        loaded[anim["name"]] = [scale_frame(f, scale, anim.get("grounded", True)) for f in frames]
        print(f"{anim['name']}: {anim['frames']} kare, ölçek {scale:.3f}")

    every = [f for frames in loaded.values() for f in frames]
    half_w = max(max(f.anchor[0], f.image.width - f.anchor[0]) for f in every)
    cell_w = 2 * (int(np.ceil(half_w)) + CELL_PAD_PX)
    if centered:
        half_h = max(max(f.anchor[1], f.image.height - f.anchor[1]) for f in every)
        cell_h = 2 * (int(np.ceil(half_h)) + CELL_PAD_PX)
    else:
        cell_h = max(f.image.height + f.lift for f in every) + 2 * CELL_PAD_PX
    cell = (cell_w, cell_h)

    for anim in animations:
        strip = build_strip(loaded[anim["name"]], cell, centered, cfg.get("colors", 0))
        strip.save(out_dir / f"{anim['name']}.png")
        save_preview(strip, cell_w, anim["fps"], preview_dir / anim["name"])
    if "res_dir" in cfg:
        write_sprite_frames(out_dir / f"{cfg['character']}_frames.tres", cfg["res_dir"], cell, animations)
    meta = {"character": cfg["character"], "cell_size": list(cell), "align": cfg.get("align", "ground"),
            "baseline_y": None if centered else cell_h - CELL_PAD_PX,
            "animations": {a["name"]: {k: a[k] for k in ("frames", "fps", "loop")} for a in animations}}
    (out_dir / "sprite_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(f"hücre: {cell_w}x{cell_h} -> {out_dir}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(Path(sys.argv[1]))
