# 👹 Ogre Boss: Piksel Çizimden Godot 4'e Entegrasyon Rehberi

Bu belge, tek parça bir konsept/sprite sheet görselinden yola çıkarak, retro 16-bit tarzı devasa bir patron düşmanın (Boss) Godot 4 oyun motoruna nasıl sıfırdan entegre edildiğini adım adım anlatır.

---

## 📌 1. Aşama: Görsel Analizi ve Kare Koordinatları

Yapay zeka veya sanatçıdan gelen ham sprite sheet görsellerinde yazılar, arka plan rengi ve değişken boşluklar bulunabilir.

* **Orijinal Görsel Boyutu:** `1024 x 572` piksel
* **Arka Plan Rengi:** Yaklaşık `#242632` (RGB: `[36, 38, 50]`)
* **Satır Dağılımı:**
  1. **Satır 1 (y: 30 - 168):** Idle (4 kare) + Walk (4 kare) — *Zemin Hizası: y=168*
  2. **Satır 2 (y: 200 - 375):** Smash Attack (5 kare) — *Zemin Hizası: y=375*
  3. **Satır 3 (y: 410 - 569):** Hurt / Recoil (4 kare) + Death / Collapse (4 kare) — *Zemin Hizası: y=569*

> [!IMPORTANT]
> **2D Platformer Altın Kuralı (Ground Baseline):** Karakterin zıplamaması veya yürürken yere batmaması için her satırın ayak temas noktası (baseline) tespit edildi ve tüm karelerin ayakları aynı dikey piksele sabitlendi.

---

## 🎨 2. Aşama: Akıllı Arka Plan Temizleme (Flood-Fill Çözümü)

Düz renk silme araçları karakterin üzerindeki koyu renkli zırhı, kemerleri veya göz bebeklerini de saydamlaştırarak karakterde delikler açabilir. 

Bunu önlemek için **Sınırdan Dışa Doğru Sel Doldurma (Border Flood-Fill)** algoritması kullanıldı:
1. Yalnızca görselin dış kenarlarından başlayarak arka plan rengine benzeyen pikseller işaretlendi.
2. Karakterin içindeki koyu piksellere asla dokunulmadı.
3. Karakter dış hatlarındaki kenar geçişleri için yarı saydam yumuşatma uygulandı.

---

## 📏 3. Aşama: Standart Izgara ve Strip Üretimi

Godot 4'ün `SpriteFrames` editöründe rahat çalışabilmek için her kare standart **256 x 192 piksel** hücre içerisine yerleştirildi:
* **Hücre Genişliği:** 256 px
* **Hücre Yüksekliği:** 192 px
* **Ayak Taban Hizası:** Hücre içi y = 176 px (tabandan 16 px güvenlik payı)

### Üretilen Dosyalar:
* `ogre_sheet.png`: 8 sütun x 3 satır (2048 x 576 px) tam şeffaf ızgara.
* `_Idle.png`: 4 kare (1024 x 192 px)
* `_Walk.png`: 4 kare (1024 x 192 px)
* `_Attack.png`: 5 kare (1280 x 192 px)
* `_Hit.png`: 4 kare (1024 x 192 px)
* `_Death.png`: 4 kare (1024 x 192 px)
* `frames/`: Tekil kullanım için tüm karelerin ayrı PNG dosyaları.

---

## ⚙️ 4. Aşama: Godot 4 İçe Aktarma (Import) ve Netlik Ayarları

Retro piksel grafiklerin bulanıklaşmasını önlemek için iki kritik ayar yapıldı:

1. **Doku Filtresi (Nearest Filter):**
   * Sahnedeki `AnimatedSprite2D` düğümünde `texture_filter = 1` (`Nearest / En Yakın Komşu`) seçildi.
   * Bu ayar, kamera yakınlaşsa veya boss büyütülse dahi piksellerin cam gibi keskin kalmasını sağlar.
2. **Kayıpsız Sıkıştırma (Lossless):**
   * `.import` ayarlarında `compress/mode = 0` (Lossless) kullanılarak piksel bozulmaları engellendi.

---

## 🎬 5. Aşama: SpriteFrames (`ogre_frames.tres`) Kurulumu

Godot 4'te `SpriteFrames` kaynağı oluşturularak her animasyon için kareler ve oynatma hızları belirlendi:

| Animasyon | Kare Sayısı | Hız (FPS) | Döngü (Loop) | Açıklama |
| :--- | :---: | :---: | :---: | :--- |
| **`idle`** | 4 | 5.0 | Evet | Ağır nefes alıp verme ve kulübü hazır tutma |
| **`walk`** | 4 | 5.0 | Evet | Ağır adımlarla sarsıcı yürüyüş |
| **`attack`** | 5 | 6.0 | Hayır | Kulübü kaldırma (0-2), yere vurma (3), toparlanma (4) |
| **`hit`** | 4 | 8.0 | Hayır | Darbe anında kafasını tutup sendeleme |
| **`death`** | 4 | 5.0 | Hayır | Kulübü düşürüp diz üstü yere yığılma ve yerde kalma |

---

## 🛡️ 6. Aşama: Sahne Düğüm Hiyerarşisi (`OgreBoss.tscn`)

Devin oyundaki varlığı için `CharacterBody2D` tabanlı bağımsız sahne kuruldu:

```text
OgreBoss (CharacterBody2D)  [Gruplar: boss, enemies, damageable]
├── CollisionShape2D (Gövde fiziği: 54x106 px)
├── Visual (Node2D)
│   ├── AnimatedSprite2D (ogre_frames.tres, Nearest Filter, pozisyon: y=-80)
│   ├── Hitbox (Area2D - Kulüp darbe alanı: 115x85 px)
│   └── LedgeRay (RayCast2D - Uçurumlardan düşmeme sensörü)
├── Hurtbox (Area2D - Oyuncunun kılıç vuruşlarını algılayan alan: 68x114 px)
├── DetectionArea (Area2D - 380 px daire algılama menzili)
└── UI (Node2D)
    ├── HealthBar (ProgressBar - Altın işlemeli karanlık fantezi boss can barı)
    ├── BossTitle (Label - "KARA BOYNUZLU DEV OGRE")
    └── DamageNumbers (Node2D - Kayan hasar sayıları)
```

---

## 🧠 7. Aşama: Patron Yapay Zekası (`ogre_boss.gd`)

Sıradan yaratıklardan farklı olarak devasa patron hissi veren mekanikler eklendi:

1. **Ağır Saldırı ve Yer Sarsıntısı (`Screen Shake`):**
   * Kulüp yere çarptığı anda (`ground_smash_delay = 0.55s`) `Camera2D` sarsılır.
   * Şok dalgası menzilindeki oyuncu geriye ve havaya doğru fırlatılır.
2. **Yüksek Direnç (`Knockback Resistance: 0.85`):**
   * Oyuncunun normal vuruşları devi savuramaz, sadece hafifçe sarsar.
3. **Stat Dağılımı:**
   * **Can:** 450 HP (Normal yaratıkların ~5 katı)
   * **Saldırı Gücü:** 40 Hasar
   * **Yürüyüş Hızı:** 45 px/s (Ağır siklet) / Koşma: 75 px/s

---

## 🎮 8. Aşama: Test Arenası (`test_boss.tscn`)

Geliştiricinin patronu tek başına deneyebilmesi için özel arena oluşturuldu:
* **Çalıştırma:** Godot'ta `res://scenes/dev/test_boss.tscn` sahnesini açıp `F6` tuşuna basın.
* **Kontroller:**
  * `[A] / [D]` : Sağa / Sola Koşma
  * `[Space]` : Zıplama
  * `[E]` : Yerden Kılıcı Kuşanma
  * `[Sol Tık]` : Hafif Kılıç Savurma (25 Hasar)
  * `[Sağ Tık]` : Ağır Kılıç Saldırısı (50 Hasar)
  * `[T]` : Hızlı Test 25 Hasar Ver
  * `[K]` : Hızlı Test 100 Hasar Ver
  * `[R]` : Arenayı Sıfırla
