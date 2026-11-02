# YAMALI DÜNYA — PIXEL-ART SANAT YÖNETİMİ VE STİL REHBERİ (STYLE GUIDE)

**Versiyon:** 1.0  
**Tarih:** 2026-11-02  
**Oyun:** Yamalı Dünya  
**Motor:** Godot Engine 4.7.2 Forward+ / D3D12  
**Hedef Kapsam:** Taş Devri (Prehistoric Valley) & Vlad (Eflak Kalesi)  

---

## 1. NATIVE ÇÖZÜNÜRLÜK VE EKRAN ÖLÇEKLENDİRME

Yamalı Dünya'nın pixel-art bütünlüğü ve retro estetiği, doğru render ve ölçekleme ayarlarına dayanır:

* **Temel Viewport:** `1280 x 720` (16:9 geniş ekran).
* **Stretch Modu:** `canvas_items` (öğelerin oransal ve pixel tabanlı büyütülmesi).
* **Stretch Aspect:** `expand` (farklı monitör en-boy oranlarında pencerelerin siyah barlar yerine çevresel görüşü genişletmesi).
* **Stretch Scale:** `1.35` (pixel art öğelerin ekranda okunabilir ve dolgun görünmesi).
* **Doku Filtreleme (Texture Filter):** Zorunlu `Nearest` (Godot: `textures/canvas_textures/default_texture_filter = 0`). Kesinlikle `Bilinear` veya `Linear` filtreleme kullanılmaz; pikseller daima keskin ve sert hatlı kalmalıdır.

---

## 2. PİKSEL YOĞUNLUĞU VE MİXEL (MIXED PIXELS) ÖNLEME

Pixel-art projelerindeki en büyük kalite kusuru **"Mixel"** (farklı çözünürlükteki piksellerin yan yana gelmesi) ve **"Sub-pixel Jitter"** (pikseller arası titreme) durumudur.

1. **1:1 Texel Oranı:** Karakterler, düşmanlar ve çevre karoları aynı piksel ölçeğine (`scale = Vector2(1, 1)`) sadık kalmalıdır.
2. **Dönüş (Rotation) Kısıtlaması:** Pixel karakterler oyun içinde serbest açılarla döndürülmemeli; dönüş gerekiyorsa özel rotasyon frame'leri çizilmeli veya `90° / 180°` dik açılar kullanılmalıdır.
3. **Kamera Yuvarlama (Pixel Snapping):** Kameranın ve karakterlerin hareketleri alt-piksel (float) koordinatlarda yumuşatılırken, render aşamasında `snap_2d_transforms_to_pixel` ve `snap_2d_vertices_to_pixel` ilkeleri gözetilir.

---

## 3. TİLE VE SPRITE GRİD MİMARİSİ

* **Standart Karo (Tile) Boyutu:** `16x16` ve `32x32` piksel grid.
* **Karakter Boyutları:**
  * Ana Karakter (Player): `32x32` / `48x48` bounding box (Canvas 64x64 alan içinde merkezlenmiş).
  * Standart Düşmanlar (İskelet, Nekromansör, Yarasa): `32x32` - `48x48`.
  * Boss Varlıkları (T-Rex, Vlad Tepeş): `128x128` - `256x256` çoklu grid alanı.
* **Pivot Noktası (Anchor Point):** Tüm karakter ve düşman sprite'larında zemin pivot noktası sprite'ın **alt-orta (bottom-center)** koordinatına sabitlenmiştir. Animasyon geçişlerinde (Idle -> Run -> Jump -> Land) karakterin ayak hizası kesinlikle oynamaz.

---

## 4. KONTUR (OUTLINE) VE SİLÜET İLKELERİ

1. **Ön Plan / Etkileşimli Varlıklar (Karakter, Düşman, Eşyalar):**
   * 1 piksellik belirgin dış kontur.
   * Sert siyah yerine sahne tonuna uyumlu koyulaştırılmış gölge rengi (Selective Outlining - Selout).
   * Oyuncunun karakteri ve tehditleri anında arka plandan ayırt edebilmesi için yüksek kontrastlı silüet.
2. **Arka Plan ve Çevre Karoları (Background & Environment):**
   * Dış kontur kullanılmaz veya yumuşak tonlu dikişsiz geçişler tercih edilir.
   * Parallaks katmanlarında derinlik hissi için renk doygunluğu azaltılır (atmospheric perspective).

---

## 5. DÖNEM VE BÖLÜM PALET DİLİ

### 5.1. Taş Devri (Prehistoric Valley)
* **Atmosfer:** İlkel, vahşi, sıcak ve güneşli vadi.
* **Ana Tonlar:**
  * Toprak & Kil: `#8B5A2B`, `#A0522D`, `#D2B48C`
  * Vadi Yeşili & Yosun: `#3B5323`, `#556B2F`, `#6B8E23`
  * Kaya Grisi & Bazalt: `#4F4F4F`, `#696969`, `#808080`
  * Dinozor Pulları (T-Rex): `#3B5336`, `#2E4F28`, `#7A3E26`
* **Sentetik Renk Yasağı:** Neon mavi, elektrik moru ve sentetik pembe tonlar Taş Devri doğasında kesinlikle yer almaz.

### 5.2. Vlad / Eflak Kalesi (Bridge, Dungeon, Throne Room)
* **Atmosfer:** Gotik, karanlık, tekinsiz, kanlı ve tarihi.
* **Ana Tonlar:**
  * Taş Zindan & Arduvaz: `#1A1B24`, `#2A2D34`, `#3B3F4A`
  * Kan Kırmızısı (Altar & Pelerin): `#4A0000`, `#8B0000`, `#B22222`
  * Kemik & Parşömen Beyazı: `#DCD7C9`, `#EAE6DF`
  * Meşale & Mangal Ateşi: `#FF4500`, `#FF8C00`, `#FFA500`
  * Paslı Demir & Zincir: `#4A3C31`, `#5D4037`

---

## 6. OTOMATİK DENETİM VE QA BULGULARI

`qa/art_direction/audit_pixel_art.py` aracıyla projedeki **637 görsel varlık (PNG)** taranmıştır:

* **Taranan Varlık Sayısı:** 637
* **PASS (Tam Uyumlu):** 181 (%28.4) — Temel sprite'lar, karakter frame'leri ve pixel-grid karoları.
* **REVIEW (İnceleme / Stil Notu):** 456 (%71.6) — Arka plan illüstrasyonları ve bazı efektler yüksek renk derinliği ve degrade içermektedir. Bu varlıklar pixel-art sahnenin arkasında zengin bir derinlik sunduğu için motor tarafında bozulmaya yol açmamakta ancak stil olarak modern-retro hibrit kategorisindedir.
* **FAIL (Bozuk / Hatalı Dosya):** 0 (%0.0) — Projede bozuk PNG, okunamayan header veya kayıp sprite tespit edilmemiştir.
* **Görsel Rapor:** `qa/art_direction/audit_overview.png` dosyasında pasta ve dağılım grafiği olarak belgelenmiştir.
