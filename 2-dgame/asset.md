# 🎮 Ekran Görüntüsünden (SS) Oyun Varlığına (Asset): 2D Ogre Boss Entegrasyon Süreci

Bu belge, tek bir ekran görüntüsü (Screenshot / SS) veya yapay zeka tarafından üretilmiş sprite sheet görseli üzerinden, **Godot 4** motorunda çalışan tam donanımlı, devasa bir **Patron Düşman (Boss)** varlığının sıfırdan nasıl oluşturulduğunu adım adım ve teknik detaylarıyla açıklamaktadır.

---

## 📑 İçindekiler
1. [Gelen Ekran Görüntüsünün (SS) Yapısal Analizi](#1-gelen-ekran-görüntüsünün-ss-yapısal-analizi)
2. [Piksel Çıkarma ve Akıllı Arka Plan Temizleme (Flood-Fill)](#2-piksel-çıkarma-ve-akıllı-arka-plan-temizleme-flood-fill)
3. [Zemin Hizalama (Ground Baseline) ve Izgara Standartlaştırma](#3-zemin-hizalama-ground-baseline-ve-ızgara-standartlaştırma)
4. [Oluşturulan Görsel Dosyaları (Sprite Strips & Sheets)](#4-oluşturulan-görsel-dosyaları-sprite-strips--sheets)
5. [Godot 4 Piksel Netlik Ayarları (Import & Filter Mode)](#5-godot-4-piksel-netlik-ayarları-import--filter-mode)
6. [SpriteFrames Kaynağının Oluşturulması (`ogre_frames.tres`)](#6-spriteframes-kaynağının-oluşturulması-ogre_framestres)
7. [Boss Sahnesi ve Node Mimarisi (`OgreBoss.tscn`)](#7-boss-sahnesi-ve-node-mimarisi-ogrebosstscn)
8. [Patron Yapay Zekası ve Yer Sarsıntısı Mekaniği (`ogre_boss.gd`)](#8-patron-yapay-zekası-ve-yer-sarsıntısı-mekaniği-ogre_bossgd)
9. [Test Arenası ve Doğrulama (`test_boss.tscn`)](#9-test-arenası-ve-doğrulama-test_bosstscn)

---

## 1. Gelen Ekran Görüntüsünün (SS) Yapısal Analizi

Gönderilen görsel `1024 x 572` piksel boyutunda, koyu lacivert/mor tonlarında düz bir arka plana (`#242632`, RGB: `[36, 38, 50]`) ve 3 ana satıra sahipti:

| Satır | Gönderilen Başlık | Animasyonlar | Kare Sayısı | Dikey Koordinat (Y) |
| :--- | :--- | :--- | :---: | :---: |
| **Satır 1** | IDLE & WALK - holding club \| WALK | Duruş (Idle) & Yürüyüş (Walk) | 4 + 4 = 8 | `y = 30` ile `y = 168` |
| **Satır 2** | HEAVY SMASH ATTACK - overhead swing | Kulübü Kaldırıp Yere Vurma & Şok Dalgası | 5 | `y = 200` ile `y = 375` |
| **Satır 3** | HURT & DEATH - recoil and collapse \| DEATH | Hasar Alma (Hit) & Yere Yığılma (Death) | 4 + 4 = 8 | `y = 410` ile `y = 569` |

### SS Üzerindeki Zorluklar:
* Görsel üzerinde satır başlık yazıları vardı (örn. *"IDLE & WALK"*, *"HEAVY SMASH ATTACK"*). Bu yazıların sprite içine karışmaması gerekiyordu.
* Satırlar arasındaki boşluklar eşit değildi.
* Saldırı animasyonundaki toz bulutu ve devasa kulüp savurması diğer karelere göre çok daha genişti (240+ piksel).
* Yere yığılma ölüm karesi yatayda uzanıyordu (~160 piksel).

---

## 2. Piksel Çıkarma ve Akıllı Arka Plan Temizleme (Flood-Fill)

### Neden Düz Renk Silme (Chroma Key) Kullanılmadı?
Piksel sanatında karakterin üzerinde koyu demir pauldron, gölgeler, kemer tokaları ve göz bebekleri bulunur. Eğer *"#242632 rengine yakın tüm pikselleri sil"* denilirse, karakterin gövdesinde ve zırhında delikler açılır (iç saydamlaşma hatası).

### Çözüm: Dıştan İçe Sel Doldurma (Border Flood-Fill)
Python (`PIL` + `numpy`) kullanılarak yalnızca **görselin en dış kenarlarından** başlayan bir arama yapıldı:
1. Görselin sınır pikselleri incelendi.
2. Arka plan rengine yakın olan dış pikseller işaretlenerek bir kuyruğa (`queue`) alındı.
3. Kuyruktaki pikseller dıştan içeri doğru yayıldı ancak karakterin dış sınır çizgilerine (outline) çarptığında durdu.
4. Böylece karakterin **içindeki hiçbir karanlık piksele dokunulmadı**, sadece dış arka plan temizlendi.
5. Dış sınır piksel kenarları yarı saydam yumuşatma ile harmanlandı.

---

## 3. Zemin Hizalama (Ground Baseline) ve Izgara Standartlaştırma

2D platform oyunlarında karakterin farklı animasyonlara geçerken **havada asılı kalması veya zemin içine batması en sık karşılaşılan hatadır**.

### Matematiksel Zemin Analizi:
* **Satır 1:** Karakterin ayak tabanı `y = 168` pikselde bitiyor.
* **Satır 2:** Kulübün yere çarptığı zemin çizgisi `y = 375` pikselde bitiyor.
* **Satır 3:** Yere yatan devin zemin teması `y = 569` pikselde bitiyor.

### Standart 256 x 192 Hücre Yapısı:
Her bir kare için standart bir hücre boyutu belirlendi:
* **Genişlik:** `256 px`
* **Yükseklik:** `192 px`
* **Zemin Taban Çizgisi (Baseline):** Hücre içinde `y = 176 px` (alttan 16 px pay bırakıldı).
* Tüm kareler yatayda merkeze (`x = 128 px`), dikeyde ise ayakları tam olarak `y = 176 px` çizgisine basacak şekilde yerleştirildi.

---

## 4. Oluşturulan Görsel Dosyaları (Sprite Strips & Sheets)

İşlem sonucunda `res://assets/characters/monsters/ogre/` klasörü altına şu optimize edilmiş dosyalar üretildi:

1. **`ogre_sheet.png` (2048 x 576 px):**
   * 8 sütun x 3 satırlık birleşik master sprite sheet.
   * Godot 4'ün yerleşik Sprite Sheet dilimleyicisiyle tam uyumludur.
2. **Animasyon Şeritleri (Horizontal Strips):**
   * `_Idle.png` (1024 x 192 px, 4 kare)
   * `_Walk.png` (1024 x 192 px, 4 kare)
   * `_Attack.png` (1280 x 192 px, 5 kare)
   * `_Hit.png` (1024 x 192 px, 4 kare)
   * `_Death.png` (1024 x 192 px, 4 kare)
3. **`frames/` Klasörü:**
   * İhtiyaç halinde tek tek kullanılabilmesi için tüm karelerin şeffaf tekil PNG dosyaları (`idle_0.png` ... `death_3.png`).

---

## 5. Godot 4 Piksel Netlik Ayarları (Import & Filter Mode)

Piksel sanatının retro 16-bit hissini korumak ve bulanıklaşmasını engellemek için:

* **Filter Mode:** `Nearest` (En Yakın Komşu) olarak ayarlandı (`texture_filter = 1`). Bu sayede kamera yaklaştığında pikseller asla bulanıklaşmaz.
* **Sıkıştırma:** `compress/mode = 0` (`Lossless / Kayıpsız`) seçilerek renk kaybı engellendi.

---

## 6. SpriteFrames Kaynağının Oluşturulması (`ogre_frames.tres`)

Godot 4'ün `AnimatedSprite2D` düğümü için `ogre_frames.tres` kaynağı oluşturuldu ve 5 temel durum tanımlandı:

| Animasyon | Kareler | FPS | Döngü | Davranış |
| :--- | :---: | :---: | :---: | :--- |
| **`idle`** | 4 | 5.0 | Açık | Ağır nefes alma, kulübü iki elle kavrama |
| **`walk`** | 4 | 5.0 | Açık | Ağır adımlarla sarsıcı yürüme döngüsü |
| **`attack`** | 5 | 6.0 | Kapalı | 1-2: Kulübü baş üstüne kaldırma<br>3: Yere vurma ve toz patlaması<br>4: Yerdeki şok dalgası ve kalkış |
| **`hit`** | 4 | 8.0 | Kapalı | Başı geriye atarak sendeleme |
| **`death`** | 4 | 5.0 | Kapalı | Kulübü düşürüp diz çökme ve yere boylu boyunca serilme |

---

## 7. Boss Sahnesi ve Node Mimarisi (`OgreBoss.tscn`)

Dev karakterin oyundaki fiziksel ve görsel varlığı için `CharacterBody2D` tabanlı sahne oluşturuldu:

```text
OgreBoss (CharacterBody2D)
│  Gruplar: ["boss", "enemies", "damageable"]
│  Script: res://scripts/enemies/ogre_boss.gd
│
├── CollisionShape2D
│     Şekil: RectangleShape2D (54 x 106 px) -> Karakterin zemin/duvar çarpışması
│
├── Visual (Node2D)
│   ├── AnimatedSprite2D
│   │     Texture Filter: Nearest
│   │     SpriteFrames: ogre_frames.tres
│   │     Pozisyon: (0, -80) -> Ayaklar tam yer çizgisine oturur
│   │
│   ├── Hitbox (Area2D)
│   │     Collision Layer: 0, Mask: 1 (Oyuncuya hasar verir)
│   │     Şekil: RectangleShape2D (115 x 85 px) -> Devasa balyoz etki alanı
│   │
│   └── LedgeRay (RayCast2D) -> Uçurumlardan aşağı düşmeme sensörü
│
├── Hurtbox (Area2D)
│     Collision Layer: 4, Mask: 2 (Oyuncunun kılıç darbelerini alır)
│     Şekil: RectangleShape2D (68 x 114 px)
│
├── DetectionArea (Area2D)
│     Şekil: CircleShape2D (Yarıçap: 380 px) -> Oyuncuyu uzaktan fark etme alanı
│
└── UI (Node2D)
    ├── HealthBar (ProgressBar) -> Altın/kırmızı karanlık fantezi can barı
    ├── BossTitle (Label) -> "KARA BOYNUZLU DEV OGRE"
    └── DamageNumbers (Node2D) -> Vurulan hasarı havaya uçuran etiketler
```

---

## 8. Patron Yapay Zekası ve Yer Sarsıntısı Mekaniği (`ogre_boss.gd`)

Boss, temel canavar yapay zekasını genişleterek ağır patron mekanikleri sunar:

### Temel İstatistikler:
* **Can (Max HP):** `450` (Normal yaratıkların ~5 katı)
* **Saldırı Gücü:** `40`
* **Savrulma Direnci (Knockback Resistance):** `0.85` (Kılıç darbeleriyle geri itilmez, ağır duruşunu korur)
* **Hareket Hızı:** `45.0` (Ağır adımlar) / Kovalama Hızı: `75.0`

### Yer Sarsıntısı ve Şok Dalgası:
```gdscript
# Kulüp tam yere vurduğunda (Frame 3, ~0.55s)
func _trigger_ground_smash_impact() -> void:
    # 1. Kamerayı sars (Screen Shake)
    if _camera_ref:
        var cam_tween = create_tween()
        cam_tween.tween_property(_camera_ref, "offset:y", screen_shake_intensity, 0.05)
        cam_tween.tween_property(_camera_ref, "offset:y", -screen_shake_intensity * 0.7, 0.06)
        cam_tween.tween_property(_camera_ref, "offset:y", 0.0, 0.08)

    # 2. Yakındaki oyuncuyu geriye ve havaya fırlat
    if _target_node and is_instance_valid(_target_node):
        var dist = global_position.distance_to(_target_node.global_position)
        if dist < attack_range * 1.5:
            _target_node.velocity.y = -180.0
            _target_node.velocity.x += float(direction) * 160.0
```

---

## 9. Test Arenası ve Doğrulama (`test_boss.tscn`)

Boss'u hemen deneyimlemek için özel bir test arenası kuruldu:
* **Sahne Yolu:** `res://scenes/dev/test_boss.tscn`
* **Test Senaryosu:**
  * Oyuncu sahneye başlar, `[E]` ile yerdeki kılıcı kuşanır.
  * Sol Tık ile hafif (25 Hasar), Sağ Tık ile ağır (50 Hasar) savurur.
  * Hızlı test için arayüzde `[T]` (25 Hasar), `[K]` (100 Hasar) ve `[R]` (Sıfırla) butonları yer alır.
* **Otomasyon Doğrulaması:** `verify_ogre.gd` betiği çalıştırılarak tüm düğümler, animasyon kareleri ve hasar alma fonksiyonları **%100 başarıyla doğrulanmıştır**.
