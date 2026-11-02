#!/usr/bin/env python3
"""
Yamalı Dünya — Profesyonel Pixel Art Kalite Denetim Aracı (Aşama 4)
Tarar:
 - assets/ içindeki tüm PNG dosyalarını
 - Boyut / Grid uyumu (16x16, 32x32, 24x24 veya standart güçleri)
 - Şeffaflık (1-bit alpha vs blur/anti-alias alpha bozulması)
 - Renk paleti sayısı ve renk harmonisi
 - Taş Devri (Prehistoric) vs Vlad (Eflak) tema ayrımı
Sonuç: PASS, REVIEW, FAIL puanlama ve qa/art_direction/audit_results.json raporu.
"""

import os
import sys
import json
from pathlib import Path
from PIL import Image
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
ASSETS_DIR = PROJECT_ROOT / "assets"
OUT_DIR = PROJECT_ROOT / "qa" / "art_direction"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def analyze_image(path: Path) -> dict:
    rel_path = str(path.relative_to(PROJECT_ROOT)).replace("\\", "/")
    try:
        with Image.open(path) as img:
            img_rgba = img.convert("RGBA")
            w, h = img_rgba.size
            arr = np.array(img_rgba)
    except Exception as e:
        return {
            "path": rel_path,
            "status": "FAIL",
            "reasons": [f"Dosya okunamadı: {e}"],
            "width": 0, "height": 0
        }

    reasons = []
    status = "PASS"

    # 1. Grid & Boyut Denetimi
    is_power_of_two = (w & (w - 1) == 0) and (h & (h - 1) == 0)
    is_tile_grid = (w % 8 == 0 or w % 16 == 0 or w % 24 == 0 or w % 32 == 0) and (h % 8 == 0 or h % 16 == 0 or h % 24 == 0 or h % 32 == 0)

    # 2. Şeffaflık Denetimi (Alpha channel)
    alpha = arr[:, :, 3]
    total_pixels = w * h
    translucent_mask = (alpha > 5) & (alpha < 250)
    translucent_count = int(np.sum(translucent_mask))
    translucent_ratio = translucent_count / total_pixels if total_pixels > 0 else 0.0

    # UI, background, efekt veya sis değilse yarı şeffaflık pixel art'ta bulanıklığa (anti-aliasing) işaret eder
    is_ui_or_bg = any(k in rel_path.lower() for k in ["background", "ui", "effect", "fog", "light", "glow", "vfx", "particle"])
    if not is_ui_or_bg and translucent_ratio > 0.08:
        reasons.append(f"Yüksek yarı-şeffaflık oranı (%{translucent_ratio*100:.1f}) - sert pixel kenarı yerine anti-alias şüphesi")
        status = "REVIEW"

    # 3. Hızlı Renk Sayımı (1D integer hashing ile 100x daha hızlı)
    opaque_mask = alpha > 10
    opaque_r = arr[:, :, 0][opaque_mask]
    opaque_g = arr[:, :, 1][opaque_mask]
    opaque_b = arr[:, :, 2][opaque_mask]

    if len(opaque_r) > 0:
        # Subsample if massive
        if len(opaque_r) > 100000:
            step = len(opaque_r) // 50000
            opaque_r = opaque_r[::step]
            opaque_g = opaque_g[::step]
            opaque_b = opaque_b[::step]
        rgb_int = (opaque_r.astype(np.int32) << 16) | (opaque_g.astype(np.int32) << 8) | opaque_b.astype(np.int32)
        unique_colors = len(np.unique(rgb_int))
    else:
        unique_colors = 0

    if not is_ui_or_bg and unique_colors > 256:
        reasons.append(f"Yüksek tekil renk sayısı ({unique_colors}) - pixel-art palet kısıtı aşımı")
        if status != "FAIL":
            status = "REVIEW"

    # 4. Bölüm Teması / Palet Sınıflandırması
    if len(opaque_r) > 0:
        r_mean = float(np.mean(opaque_r))
        g_mean = float(np.mean(opaque_g))
        b_mean = float(np.mean(opaque_b))
        if any(k in rel_path.lower() for k in ["stone_age", "prehistoric", "dino", "rex", "bone"]):
            theme = "Prehistoric"
            if r_mean > 180 and b_mean > 180 and g_mean < 100:
                reasons.append("Taş devri palet uyumsuzluğu (fazla sentetik mor)")
                status = "REVIEW"
        elif any(k in rel_path.lower() for k in ["vlad", "dungeon", "castle", "gothic", "blood", "vampire"]):
            theme = "Vlad_Gothic"
        else:
            theme = "General"
    else:
        theme = "Empty"

    return {
        "path": rel_path,
        "width": w,
        "height": h,
        "grid_aligned": is_tile_grid or is_power_of_two,
        "translucent_ratio": round(translucent_ratio, 4),
        "unique_colors": unique_colors,
        "theme": theme,
        "status": status,
        "reasons": reasons
    }


def main():
    print("Yamalı Dünya Pixel Art Audit Başlatılıyor...", flush=True)
    png_files = list(ASSETS_DIR.rglob("*.png"))
    print(f"Toplam taranan PNG sayısı: {len(png_files)}", flush=True)

    results = []
    status_counts = {"PASS": 0, "REVIEW": 0, "FAIL": 0}

    for idx, p in enumerate(png_files):
        info = analyze_image(p)
        results.append(info)
        status_counts[info["status"]] = status_counts.get(info["status"], 0) + 1
        if (idx + 1) % 100 == 0:
            print(f"  Taranan: {idx + 1}/{len(png_files)}...", flush=True)

    summary = {
        "total_assets_scanned": len(png_files),
        "status_distribution": status_counts,
        "pass_rate_pct": round(status_counts["PASS"] / len(png_files) * 100, 2) if png_files else 0.0,
        "assets": results
    }

    json_path = OUT_DIR / "audit_results.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
    print(f"Sonuçlar kaydedildi: {json_path}", flush=True)
    print(f"Özet: PASS={status_counts['PASS']}, REVIEW={status_counts['REVIEW']}, FAIL={status_counts['FAIL']} (Başarı: %{summary['pass_rate_pct']})", flush=True)

    # Matplotlib Görsel Raporu
    try:
        fig, axes = plt.subplots(1, 2, figsize=(12, 5))
        # 1. Pasta Grafik
        labels = list(status_counts.keys())
        sizes = [status_counts[k] for k in labels]
        colors = ["#4CAF50", "#FFC107", "#F44336"]
        axes[0].pie(sizes, labels=labels, autopct="%1.1f%%", colors=colors, startangle=140)
        axes[0].set_title(f"Pixel Art Denetim Durumu (Toplam: {len(png_files)})")

        # 2. Boyut Dağılımı
        dims = [(r["width"], r["height"]) for r in results if 0 < r["width"] <= 512 and 0 < r["height"] <= 512]
        widths = [d[0] for d in dims]
        heights = [d[1] for d in dims]
        axes[1].scatter(widths, heights, alpha=0.5, c="#2196F3", edgecolors="none", s=20)
        axes[1].set_xlabel("Genişlik (px)")
        axes[1].set_ylabel("Yükseklik (px)")
        axes[1].set_title(f"Asset Boyut Dağılımı (<=512px, {len(dims)} adet)")
        axes[1].grid(True, linestyle="--", alpha=0.5)

        plt.tight_layout()
        plot_path = OUT_DIR / "audit_overview.png"
        plt.savefig(plot_path, dpi=150)
        plt.close()
        print(f"Görsel grafik kaydedildi: {plot_path}", flush=True)
    except Exception as e:
        print(f"Grafik oluşturulamadı: {e}", flush=True)


if __name__ == "__main__":
    main()
