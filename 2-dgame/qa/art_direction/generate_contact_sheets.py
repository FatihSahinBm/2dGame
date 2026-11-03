#!/usr/bin/env python3
"""
Yamalı Dünya — Sanatsal İnceleme ve Contact Sheet Oluşturucu (Aşama 4)
Oyunun görsel varlıklarını kategorilere ayırarak contact sheet'ler oluşturur ve
uzman pixel-art kriterlerine göre (lenkraster & pixel-art skill) analiz eder.
"""

import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
ASSETS_DIR = PROJECT_ROOT / "assets"
OUT_DIR = PROJECT_ROOT / "qa" / "art_direction" / "contact_sheets"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def create_contact_sheet(image_paths, out_path, title, cell_size=(96, 96), cols=6):
    valid_images = []
    for p in image_paths:
        if p.exists() and p.suffix.lower() == ".png":
            try:
                with Image.open(p) as img:
                    valid_images.append((p.stem, img.convert("RGBA")))
            except Exception:
                pass

    if not valid_images:
        print(f"Uyarı: {title} için geçerli görsel bulunamadı.")
        return None

    # Thumbnail oluştur
    thumbnails = []
    for name, img in valid_images:
        # Aspect ratio koruyarak fit et
        img_thumb = img.copy()
        img_thumb.thumbnail(cell_size, Image.Resampling.NEAREST)
        thumbnails.append((name, img_thumb))

    n = len(thumbnails)
    rows = (n + cols - 1) // cols

    pad = 12
    label_h = 18
    sheet_w = cols * (cell_size[0] + pad) + pad
    sheet_h = 40 + rows * (cell_size[1] + label_h + pad) + pad

    sheet = Image.new("RGBA", (sheet_w, sheet_h), (24, 26, 32, 255))
    draw = ImageDraw.Draw(sheet)

    # Başlık
    draw.text((pad, 10), title, fill=(220, 220, 240, 255))

    for idx, (name, thumb) in enumerate(thumbnails):
        r = idx // cols
        c = idx % cols
        x = pad + c * (cell_size[0] + pad)
        y = 40 + pad + r * (cell_size[1] + label_h + pad)

        # Arka plan karo (dama tahtası)
        bg_box = Image.new("RGBA", cell_size, (36, 40, 48, 255))
        sheet.paste(bg_box, (x, y))

        # Sprite merkezle
        ox = x + (cell_size[0] - thumb.width) // 2
        oy = y + (cell_size[1] - thumb.height) // 2
        sheet.paste(thumb, (ox, oy), thumb)

        # Etiket
        short_name = name[:14]
        draw.text((x, y + cell_size[1] + 2), short_name, fill=(160, 170, 190, 255))

    sheet.save(out_path)
    print(f"Contact sheet kaydedildi: {out_path} ({len(thumbnails)} görsel)")
    return out_path


def main():
    print("Yamalı Dünya Sanatsal Contact Sheet Üretimi Başlatılıyor...")

    # 1. Ana Karakter & Müttefikler
    knight_files = sorted(list((ASSETS_DIR / "characters" / "knight").glob("*.png")))
    allies_files = sorted(list((ASSETS_DIR / "characters" / "allies").rglob("*.png")))
    create_contact_sheet(
        knight_files[:12] + allies_files[:12],
        OUT_DIR / "sheet_characters_player_allies.png",
        "Karakterler: Oyuncu (Knight) ve Osmanli Muttefikleri",
        cell_size=(110, 110), cols=6
    )

    # 2. Düşmanlar (İskelet, Nekromansör, Yarasa, vb.)
    enemies_files = sorted(list((ASSETS_DIR / "characters" / "enemies").rglob("*.png")))
    monsters_files = sorted(list((ASSETS_DIR / "characters" / "monsters").rglob("*.png")))
    create_contact_sheet(
        enemies_files[:18] + monsters_files[:12],
        OUT_DIR / "sheet_enemies_monsters.png",
        "Dusmanlar: Mahzen, Iskeletler ve Canavarlar",
        cell_size=(100, 100), cols=6
    )

    # 3. T-Rex Boss Varlıkları
    trex_dir = ASSETS_DIR / "characters" / "trex_boss"
    trex_frames = sorted(list((trex_dir / "idle_frames").glob("*.png")))[:6] + \
                  sorted(list((trex_dir / "attack_bite_frames").glob("*.png")))[:6] + \
                  sorted(list((trex_dir / "attack_laser_frames").glob("*.png")))[:6]
    create_contact_sheet(
        trex_frames,
        OUT_DIR / "sheet_trex_boss_frames.png",
        "Boss: Cyber/Prehistoric T-Rex Animasyon Kareleri",
        cell_size=(128, 128), cols=6
    )

    # 4. Taş Devri Çevre, Bitki, Kaya, Dekor
    stone_env = sorted(list((ASSETS_DIR / "environment" / "stoneage").rglob("*.png")) +
                       list((ASSETS_DIR / "environment" / "stone_age").rglob("*.png")))
    create_contact_sheet(
        stone_env[:24],
        OUT_DIR / "sheet_stoneage_environment.png",
        "Tas Devri: Cevre, Bitkiler, Kayalar ve Yikintilar",
        cell_size=(96, 96), cols=6
    )

    # 5. Vlad / Eflak Kalesi Çevre, Zindan, Kapı, Mangal
    vlad_env = sorted(list((ASSETS_DIR / "environment" / "dungeon").rglob("*.png")) +
                      list((ASSETS_DIR / "props").rglob("*.png")) +
                      list((ASSETS_DIR / "mechanical").rglob("*.png")))
    create_contact_sheet(
        vlad_env[:24],
        OUT_DIR / "sheet_vlad_dungeon_props.png",
        "Vlad Kalesi & Mahzen: Zindan, Tuzaklar, Mangallar, Giyotinler",
        cell_size=(96, 96), cols=6
    )

    # 6. Silahlar ve Nesneler
    items_files = sorted(list((ASSETS_DIR / "items").rglob("*.png")) +
                         list((ASSETS_DIR / "objects").rglob("*.png")))
    create_contact_sheet(
        items_files[:20],
        OUT_DIR / "sheet_items_weapons.png",
        "Esyalar, Silahlar ve Etkilesimli Nesneler",
        cell_size=(80, 80), cols=5
    )

    # 7. VFX ve Parçacıklar
    vfx_files = sorted(list((ASSETS_DIR / "effects").rglob("*.png")))
    create_contact_sheet(
        vfx_files[:20],
        OUT_DIR / "sheet_vfx_particles.png",
        "VFX: Patlama, Kilic Isiltisi, Kan, Buyu Efektleri",
        cell_size=(80, 80), cols=5
    )

    print("Tüm contact sheet'ler başarıyla oluşturuldu!")


if __name__ == "__main__":
    main()

