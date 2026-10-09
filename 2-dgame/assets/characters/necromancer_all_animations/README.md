# 🧙‍♂️ Necromancer (Ölüm Büyücüsü) - Complete 2D Game Animation Pack

A professional, game-ready 2D pixel-art sprite animation package created for the **Necromancer** character. Built with deterministic green-chroma registration, scale normalization, and baseline alignment.

---

## 📊 Karakter ve Grid Standardizasyonu

Tüm 6 animasyon, oyun motorlarına (Unity, Godot, Unreal Engine, Phaser, Pygame vb.) sorunsuz ve doğrudan aktarılabilmesi için **birebir aynı hücre boyutu ve çıpa noktasına** eşitlenmiştir:

- **Sabit Hücre Boyutu (Cell Size):** `360 x 320 px` *(Tüm 6 animasyon için standart ve eşittir)*
- **Sabit Ayak/Zemin Çıpası (Anchor):** `(X: 160 px, Y: 300 px)`
- **Zemin Taban Çizgisi (Ground Baseline):** `y = 300 px`
- **Karakter Gövde Yüksekliği:** ~`256-258 px` *(Karakter ölçeği tüm aksiyonlarda %100 sabittir)*
- **Kare Hızı (Framerate):** 24.0 FPS

---

## 📁 Paket Klasör Yapısı

```text
necromancer_all_animations/
├── 01_idle/                 # Durma / Soluk alma döngüsü (63 kare, 360x320)
├── 02_walk/                 # Kusursuz yürüme döngüsü (30 kare, 360x320)
├── 03_attack_magic/         # Uzak büyü atışı (60 kare, 360x320)
│   ├── frames/              # Büyücü atış kareleri
│   ├── projectile_fx/       # Ayrık uçan büyü & çarpma patlaması paketi
│   └── full_composite/      # Geniş sinematik kompozit
├── 04_attack_melee/         # Yakın asa savurma vuruşu (65 kare, 360x320)
├── 05_hurt/                 # Hasar alma ve toparlanma (48 kare, 360x320)
├── 06_death/                # Ölüm ve yere yığılma (65 kare, 360x320)
├── master_references/       # Master referans kesiti
├── raw_videos/              # Orijinal kaynak videolar
├── manifest.json            # Tüm animasyonların ortak metadata dosyası
├── necromancer_lineup_poster.png # 6 aksiyonlu karakter vitrin posteri
└── necromancer_all_actions_showcase.gif # Eşzamanlı animasyonlu önizleme
```

---

## 🎮 Aksiyon Detayları & Kod Entegrasyon Rehberi

| # | Aksiyon | Kare | Hücre Boyutu | Çıpa (Pivot) | Döngü (Loop) | Tetikleyici / Notlar |
|---|---|:---:|:---:|:---:|:---:|---|
| **1** | `01_idle` | 63 | `360 x 320` | `(160, 300)` | Evet (Ping-pong) | Göğüs solunumu, dalgalanan cübbe, nabız atan mor büyü küresi. |
| **2** | `02_walk` | 30 | `360 x 320` | `(160, 300)` | Evet (Treadmill) | 1.25s kusursuz adımlama; ayaklar zeminden kopmaz, asa sallanır. |
| **3** | `03_attack_magic` | 60 | `360 x 320` | `(160, 300)` | Hayır | **Kare 34:** Büyü mermisinin elden çıktığı an (`spawnOffset: [X: +138, Y: -147]`). |
| **4** | `04_attack_melee` | 65 | `360 x 320` | `(160, 300)` | Hayır | **Kare 42:** Kemik asanın yukarı kalkıp öne hızla indiği vuruş anı (Hitbox). |
| **5** | `05_hurt` | 48 | `360 x 320` | `(160, 300)` | Hayır | **Kare 23:** Tepe geriye savrulma anı; asayla yere tutunup toparlanır. |
| **6** | `06_death` | 65 | `360 x 320` | `(160, 300)` | Hayır | **Kare 64:** Küre söner, asa düşer, diz çöküp yere yığılır (ceset son karede kalır). |

---

## 🔮 Ayrık Mermi Paketi (`03_attack_magic/projectile_fx`)

Uzak büyü saldırısında merminin düşmana kadar uçabilmesi için büyü efekti ayrık paket olarak sunulmuştur:
- **`travel_frames/` (8 kare):** Havada dönerek uçan mor elektrik çekirdekli büyü topu (Kesintisiz döngü / loop).
- **`burst_frames/` (8 kare):** Hedefe vardığında mor büyü çemberi patlaması (Tek seferlik / one-shot).
- **Spawn Konumu:** Büyücü duruşuna göre `(X: +138 px, Y: -147 px)` noktasında yaratılır.

---

## 🛠️ Her Klasörün Standart İçeriği

Her animasyon klasöründe şunlar yer alır:
- `frames/`: Şeffaf PNG formatında tekil kareler (`cast_00.png` ... `cast_59.png` gibi).
- `preview.gif`: Web/dokümantasyon için temiz önizleme GIF'i (`disposal=2`).
- `preview_strip.png`: 8 kilit kareyi yan yana gösteren şerit görsel.
- `sprite_sheet.png`: Oyun motorları için 8 sütunlu atlas görseli.
- `animation.json`: Çıpa, hücre ve süre parametreleri.
