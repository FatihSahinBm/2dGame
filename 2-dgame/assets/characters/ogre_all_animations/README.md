# 🟢 Green Ogre Warrior - Complete 2D Animation Asset Pack

Bu paket, **Yeşil Ogre Savaşçısı** karakterinin tüm oyun içi animasyonlarını (Yürüme, Bekleme, Saldırı, Darbe Alma ve Ölüm) piksel-tutarlı, saydam arka planlı ve tüm modern oyun motorlarıyla doğrudan uyumlu formatlarda içerir.

---

## 📁 Klasör Yapısı

```
ogre_all_animations/
│
├── ogre_lineup_preview.png       # 5 temel aksiyonun yan yana dizilim önizlemesi
├── character_manifest.json       # Tüm animasyonların motorlar için JSON indeks manifestosu
├── README.md                     # Bu kılavuz ve entegrasyon rehberi
│
├── master_reference/             # Orijinal karakter referansları
│   ├── ogre_master.png           # Orijinal referans çizim
│   └── ogre_master_cutout.png    # Saydam arka planlı ana karakter şablonu
│
├── 01_walk/                      # 🚶 Yürüme Animasyonu (37 kare, 1.75s loop)
│   ├── preview.gif               # Hızlı önizleme GIF'i (24 FPS)
│   ├── sprite_sheet.png          # Saydam Sprite Sheet Atlası (4944x1460)
│   ├── animation.webm            # Şeffaf VP9 alfa video (Godot, Web, UI için)
│   ├── animation_packed.mp4      # Mobil/genel alfa MP4 videosu
│   ├── animation.json            # Kare süreleri ve koordinat manifestosu
│   └── frames/                   # Sıralı saydam PNG kareleri (walk_00.png ... walk_36.png)
│
├── 02_idle/                      # 🧘 Bekleme / Nefes Animasyonu (54 kare, 2.25s loop)
│   ├── preview.gif
│   ├── sprite_sheet.png          # (3072x1596 atlas)
│   ├── animation.webm
│   ├── animation_packed.mp4
│   ├── animation.json
│   └── frames/                   # (idle_00.png ... idle_53.png)
│
├── 03_attack/                    # ⚔️ Gürz ile Saldırı / Vuruş (78 kare, 3.25s oneshot)
│   ├── preview.gif
│   ├── sprite_sheet.png          # (3056x3040 atlas)
│   ├── animation.webm
│   ├── animation_packed.mp4
│   ├── animation.json            # Hitbox / vuruş anı (1333 ms / 32. kare)
│   └── frames/                   # (attack_00.png ... attack_77.png)
│
├── 04_hurt/                      # 🛡️ Darbe Alma / İrkilme (56 kare, 2.33s oneshot)
│   ├── preview.gif
│   ├── sprite_sheet.png          # (1696x1834 atlas)
│   ├── animation.webm
│   ├── animation_packed.mp4
│   ├── animation.json            # En şiddetli darbe anı (875 ms / 21. kare)
│   └── frames/                   # (hurt_00.png ... hurt_55.png)
│
├── 05_death/                     # 💀 Yere Yığılma / Ölüm (118 kare, 4.92s oneshot terminal)
│   ├── preview.gif
│   ├── sprite_sheet.png          # (3072x3270 atlas)
│   ├── animation.webm
│   ├── animation_packed.mp4
│   ├── animation.json            # Son kare yerde sabit kalır (terminal hold)
│   └── frames/                   # (death_00.png ... death_117.png)
│
└── source_videos/                # Google Veo 3.1 tarafından üretilen ham kaynak videolar
    ├── walk_raw.mp4
    ├── idle_raw.mp4
    ├── attack_raw.mp4
    ├── hurt_raw.mp4
    └── death_raw.mp4
```

---

## 📊 Animasyon Tablosu

| Klasör | Aksiyon | Kare Sayısı | Süre | Oynatma Tipi | Önemli Olay / Hitbox |
|:---|:---|:---:|:---:|:---:|:---|
| `01_walk/` | **Yürüme** | 37 kare | 1.75 s | Döngü (Cycle) | Çift ayaklı tam adım |
| `02_idle/` | **Bekleme** | 54 kare | 2.25 s | Döngü (Cycle) | Göğüs kalkışı / nefes |
| `03_attack/` | **Saldırı** | 78 kare | 3.25 s | Tek Sefer (Oneshot) | Hasar Anı: **1333 ms** (32. kare) |
| `04_hurt/` | **Darbe** | 56 kare | 2.33 s | Tek Sefer (Oneshot) | Sarsılma Tepesi: **875 ms** (21. kare) |
| `05_death/` | **Ölüm** | 118 kare | 4.92 s | Tek Sefer (Terminal) | Yere Düşüş ve Hareketsizlik |

---

## 🎮 Oyun Motorlarına Entegrasyon Rehberi

### 1. Godot Engine (4.x)
* **Yöntem A (Sıralı PNG - En Kolay):**
  1. İlgili animasyonun `frames/` klasöründeki tüm PNG'leri Godot `FileSystem` içine sürükleyin.
  2. Bir `AnimatedSprite2D` düğümü ekleyin.
  3. `SpriteFrames` kaynağı oluşturup yeni bir animasyon (örn. `attack`) ekleyin.
  4. PNG dosyalarını seçip sürükleyerek karelere bırakın. Hızı `24 FPS` yapın.
* **Yöntem B (Sprite Sheet):**
  1. `sprite_sheet.png` dosyasını içe aktarın.
  2. `SpriteFrames` panelinde *Add Frames from Sprite Sheet* seçeneğini seçin. `character_manifest.json` içindeki sütun sayısını girin ve kareleri seçin.

### 2. Unity
1. `sprite_sheet.png` görselini projeye aktarın.
2. `Texture Type` ayarını **Sprite (2D and UI)**, `Sprite Mode` ayarını **Multiple** yapın.
3. `Sprite Editor` açıp **Grid by Cell Size** seçeneğiyle bölün (`character_manifest.json` içindeki `cellSize` değerlerini kullanın).
4. Dilimlenen kareleri sahneye sürükleyerek Animation Clip oluşturun.

### 3. Web / HTML5 Canvas / Phaser / PixiJS
* Saydam WebM desteği olan tarayıcılarda `animation.webm` doğrudan `<video autoplay loop muted playsinline>` etiketiyle sıfır CPU yüküyle render edilir.
* Sprite atlas kullanmak için Phaser'da `this.load.spritesheet('ogre_walk', 'sprite_sheet.png', { frameWidth: ..., frameHeight: ... });` şeklinde yüklenebilir.
