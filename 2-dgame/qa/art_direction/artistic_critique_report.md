# YAMALI DÜNYA — SANATSAL PİKSEL-ART İNCELEME VE EKSPER RAPORU

**Tarih:** 2026-11-03  
**Kullanılan Uzman Araçlar:**
- `lenkraster` (v0.1.1 — Python Sanal Ortamı: `c:\Projects\tools\lenkraster\.venv`)
- `pixel-art` (Antigravity Config Skill: `batch_audit.py`, `quality_audit.py`, `palette_remap.py`)
- `create-game-assets` (Antigravity Config Skill: `art-direction-brief.md`, `asset-manifest.json`)
- `game-art-2d` (Antigravity Config Skill: `pixel_art_process.py`)
- Multimodal Görsel Temas Tabloları (Contact Sheets)

---

## 1. KATEGORİK CONTACT SHEET ANALİZİ

Oyunun 637 görsel varlığı 7 ana aileye ayrılarak [`qa/art_direction/contact_sheets/`](file:///c:/Projects/2dgame/2-dgame/qa/art_direction/contact_sheets/) altında incelenmiştir:

| Contact Sheet | İçerik | Görsel Sayısı | Genel Uyum Skoru |
|---|---|:---:|:---:|
| [`sheet_characters_player_allies.png`](file:///c:/Projects/2dgame/2-dgame/qa/art_direction/contact_sheets/sheet_characters_player_allies.png) | Oyuncu Şövalye & Osmanlı Müttefikleri (Fatih, Yeniçeri, Kemankeş) | 24 | **0.91 / 1.0 (Mükemmel)** |
| [`sheet_enemies_monsters.png`](file:///c:/Projects/2dgame/2-dgame/qa/art_direction/contact_sheets/sheet_enemies_monsters.png) | Kan Şövalyesi, İskeletler, Nekromansör, Yarasalar | 22 | **0.88 / 1.0 (Yüksek)** |
| [`sheet_trex_boss_frames.png`](file:///c:/Projects/2dgame/2-dgame/qa/art_direction/contact_sheets/sheet_trex_boss_frames.png) | Siber / Prehistorik T-Rex Animasyon Kareleri | 18 | **0.42 / 1.0 (Kritik Stil Uyuşmazlığı)** |
| [`sheet_stoneage_environment.png`](file:///c:/Projects/2dgame/2-dgame/qa/art_direction/contact_sheets/sheet_stoneage_environment.png) | Taş Devri Karoları, Yosunlu Kayalar, Siber Enkaz | 6 | **0.75 / 1.0 (Orta-İyi)** |
| [`sheet_vlad_dungeon_props.png`](file:///c:/Projects/2dgame/2-dgame/qa/art_direction/contact_sheets/sheet_vlad_dungeon_props.png) | Mahzen, Mangallar, Giyotinler, Kapılar, Jenaratörler | 24 | **0.82 / 1.0 (İyi)** |
| [`sheet_items_weapons.png`](file:///c:/Projects/2dgame/2-dgame/qa/art_direction/contact_sheets/sheet_items_weapons.png) | Kılıçlar, Otağ Çadırı, Zaman Yarıkları, Kalp Parçaları | 17 | **0.90 / 1.0 (Mükemmel)** |
| [`sheet_vfx_particles.png`](file:///c:/Projects/2dgame/2-dgame/qa/art_direction/contact_sheets/sheet_vfx_particles.png) | Toz, Kıvılcım, Boyut Dalgası, Büyü Parçacıkları | 13 | **0.86 / 1.0 (İyi)** |

---

## 2. DETAYLI SANATSAL BULGULAR VE STİL ÇATIŞMALARI

### 2.1. Ana Karakter ve Müttefikler (`lenkraster` Skoru: 0.912)
* **Piksel Yoğunluğu (Density):** Karakter sprite'ları ~32-48 piksel boyunda olup 1:1 ekran oranına kusursuz uymaktadır.
* **Kontur (Outline):** 1 piksellik koyu tonlu silüet çizgileri arka plandan ayrışmayı mükemmel sağlar.
* **Renk Paleti:** Şövalye çelik gri, altın detaylar ve deri kahverengisiyle 14 renkle sınırlandırılmıştır. Osmanlı müttefikleri (Fatih ve Yeniçeri) zengin yakut kırmızısı ve sarık beyazıyla hem dönemi yansıtmakta hem de görsel okunabilirliği korumaktadır.

### 2.2. T-Rex Boss'u ve "Farklı Oyundan Alınmış Hissi" (Kritik Hata Analizi)
`lenkraster critique` aracı `assets/characters/trex_boss/idle_frames/idle_00.png` üzerinde çalıştırıldığında şu tespitleri yapmıştır:
* **Hata 1: `palette_bloat`:** Tek bir T-Rex karesinde **90.357 tekil renk** bulunmaktadır! Geleneksel piksel sanatı 16-32 renk kısıtına dayanırken, T-Rex 24-bit yüksek çözünürlüklü 3D render veya AI görseli formatındadır.
* **Hata 2: `near_duplicate_colors`:** 256'dan fazla birbirine aşırı yakın kirli renk tonu mevcuttur.
* **Hata 3: `Mixel` (Piksel Boyutu Çatışması):** Oyuncunun kılıcı ve kolu 2x2 piksel bloklardan oluşurken, T-Rex'in pulları ve dişleri mikro piksellerle çizilmiştir. İkisi yan yana geldiğinde T-Rex başka bir 3D/HD oyundan kesilip yapıştırılmış gibi durmaktadır.
* **Hata 4: Mor Artefaktlar (Chroma Keying Kalıntısı):** Ayak ve tırnak diplerinde `[970, 292]` ve `[98, 417]` koordinatlarında yeşil/mor yapay kenar pikselleri (`orphan_pixels`) bulunmaktadır.

### 2.3. Taş Devri ve Gotik Çevredeki Siber Enkazlar
* **Hikaye / Sanat Uyumu:** "Yamalı Dünya" hikayesinde zaman yarıklarıyla boyutlar karıştığı için Taş Devri'nde siber enkazların (`cyber_rex_debris.png`) ve mahzende mekanik bobinlerin (`domain_cracked.png`) bulunması anlatısal olarak doğrudur.
* **Görsel Problem:** Mekanik parçaların çizim tekniği (fotorealistik gürültülü doku), zemin karolarının sade ve temiz 16-bit piksel çizgileriyle çatışmaktadır.

---

## 3. İYİLEŞTİRME VE ARMONİ REÇETESİ

1. **T-Rex İçin Palet İndeksleme (Quantization):**
   `lenkraster quantize` veya `pixel-art/scripts/palette_remap.py` kullanılarak T-Rex sprite'ları Taş Devri paletine (32 renge) sabitlenmeli, dither filtrelenerek miksel yoğunluğu 2x piksel ölçeğine çekilmelidir.
2. **Kromatik Kenar Temizliği:**
   T-Rex tırnaklarındaki mor specks pikselleri `scripts/outline_generator.py` ile temizlenerek gövde rengine uyumlu koyu zeytin yeşili kontur eklenmelidir.
