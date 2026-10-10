# 🧛 Vlad the Impaler - Multi-Form Boss & Character Roadmap (100% COMPLETE 🎉)

Bu belge, **Vlad the Impaler** karakterinin 4 farklı formu, formlar arası kan dumanı geçişleri, her form için bağımsız hasar tepkileri (hurt states) ve nihai patron yenilgi sekansı (death state) dahil olmak üzere tüm 22 animasyon paketinin [How to Work.md](../How%20to%20Work.md) metodolojisine uygun olarak tamamlandığını belgeler.

---

## 🎭 Karakter Formları ve Referans Dosyaları

| # | Form | Referans Görseli | Tema & Savaş Tarzı | Durum |
|---|---|---|---|---|
| **1** | **Normal Form** (İnsan / Voyvoda) | `master_references/01_vlad_normal_1280x720.png` | Asil Voyvoda zırhı, kürk pelerin, mızrakla taktiksel ve ölümcül vuruşlar | **%100 Tamamlandı** |
| **2** | **Vampir Form** (Vampire Lord) | `master_references/02_vlad_vampire_1280x720.png` | Taç, kanatlı zırh, kan aurası, kan büyüsü ve geniş süpürme darbeleri | **%100 Tamamlandı** |
| **3** | **Kurt Adam Form** (Lycan Beast) | `master_references/03_vlad_werewolf_1280x720.png` | Yırtıcı kurt başı, devasa pençeler, çevik vahşi koşu ve sıçrama saldırıları | **%100 Tamamlandı** |
| **4** | **Yarasa Form** (Monstrous Bat) | `master_references/04_vlad_bat_1280x720.png` | Devasa kanatlı taçlı uçan form, hava dalışları ve ses dalgası çığlığı | **%100 Tamamlandı** |

---

## 🎬 Tüm 22 Animasyonun Detaylı Durum Tablosu

### 🔴 Faz 1: Normal Form (Voyvoda Vlad) - [%100 TAMAMLANDI]
- [x] **`01_normal_idle`**: Ağırbaşlı, asil duruş; göğüs solunumu, hafif pelerin dalgalanması, mızrak dik ve sabit. (56 kare, ping-pong döngü, çıpa `(340, 680)`).
- [x] **`02_normal_walk`**: Ağır, tehditkar ve kararlı yerinde adımlama (37 kare, dikişsiz yürüme döngüsü `diff=1.94`, 6-sütun atlas `7680x5040`).
- [x] **`03_normal_attack_thrust`**: Hızlı ve ölümcül ileri mızrak saplama vuruşu (98 kare, darbe anı F50, 6-sütun atlas `7680x12240`).
- [x] **`04_normal_attack_impale`**: Mızrağı iki elle yukarı kaldırıp zemine sert saplama (115 kare, şok dalgası doruğu F41, 6-sütun atlas `7680x14400`).

### 🩸 Faz 2: Vampir Form (True Vampire Lord) - [%100 TAMAMLANDI]
- [x] **`05_vampire_idle`**: Karanlık kan aurası yayan, hafif süzülen tehditkar duruş (37 kare, dikişsiz aura döngüsü `diff=1.55`, 6-sütun atlas `7680x5040`).
- [x] **`06_vampire_glide`**: Ayakları yere hafif basarak zemin üzerinde kayarak hareket (37 kare, dikişsiz süzülme döngüsü `diff=2.00`, 6-sütun atlas `7680x5040`).
- [x] **`07_vampire_attack_slash`**: Mızrak ve kanatlı pelerinle geniş kan aurası savurma (106 kare, kavis doruğu F49, 6-sütun atlas `7680x12960`).
- [x] **`08_vampire_attack_blood_magic`**: Pençeli elini kaldırıp ileriye doğru kan dalgası fırlatma (106 kare, fırlatma F40, 6-sütun atlas `7680x12960`).

### 🐺 Faz 3: Kurt Adam Form (Beast / Lycan) - [%100 TAMAMLANDI]
- [x] **`09_werewolf_idle`**: Kambur, vahşi hırıltılı nefes alma; pençeler ve kaslar gergin (38 kare, dikişsiz nefes döngüsü `diff=3.98`, 6-sütun atlas `7680x5040`).
- [x] **`10_werewolf_run`**: Yırtıcı, dörtnala / hızlı iki ayaklı avcı koşusu (28 kare, dikişsiz koşu döngüsü `diff=2.07`, 6-sütun atlas `7680x3600`).
- [x] **`11_werewolf_attack_claws`**: Çift pençe seri parçalama kombosu (144 kare, 3 vuruşlu kombo, zirve erişim `x=1266`, 6-sütun atlas `7680x17280`).
- [x] **`12_werewolf_attack_leap`**: İleri fırlayıp yere sert pençe indirme (144 kare, havalanma doruğu F58, zemin darbesi F88, 6-sütun atlas `7680x17280`).

### 🦇 Faz 4: Yarasa Form (Giant Monstrous Bat) - [%100 TAMAMLANDI]
- [x] **`13_bat_idle_fly`**: Havada sabit kanat çırparak süzülme (32 kare, dikişsiz kanat çırpma döngüsü `diff=3.17`, 6-sütun atlas `7680x4320`).
- [x] **`14_bat_attack_dive`**: Havadan aşağı keskin dalış saldırısı (144 kare, dalış doruğu F88, pençe erişim `x=1185`, 6-sütun atlas `7680x17280`).
- [x] **`15_bat_attack_screech`**: Ağzını açıp ileriye doğru ultrasonik kan çığlığı yayma (144 kare, çığlık fırlatma anı F72, 6-sütun atlas `7680x17280`).

### 💨 Faz 5: Formlar Arası Geçiş, Hasar Alma & Nihai Ölüm - [%100 TAMAMLANDI]
- [x] **`16_transform_blood_smoke`**: Form değiştirirken karakterin etrafını kaplayan kırmızı/mor kan dumanı ve patlaması (144 kare, yeşil hareler arındırıldı, 6-sütun atlas `7680x17280`).
- [x] **`vfx_blood_smoke_burst`**: **Modüler Evrensel Kan Dumanı VFX Katmanı** (72 kare, 0 alfadan başlayıp dorukta %100 tam örtücülüğe ulaşan ve yarasalarla dağılan, tüm formlar arası geçişte karakterin üzerine giydirilebilir bağımsız VFX, 6-sütun atlas `7680x8640`).
- [x] **`17_vlad_hurt`**: Normal Form (İnsan) darbe alma / geriye sarsılma (144 kare, 6-sütun atlas `7680x17280`).
- [x] **`18_vlad_death`**: Nihai ölüm sekansı (Mızrağı yere düşürme, göğsünü tutup tek diz üstüne çökme, zırhın akkor küllere ve yarasa sürüsüne dağılması, zeminde yalnızca mızrak ve tacın kalması - 144 kare, 6-sütun atlas `7680x17280`).
- [x] **`19_vampire_hurt`**: Vampir Formu darbe alma / kanatlı pelerinle geriye sarsılıp tekrar dikilme (144 kare, 6-sütun atlas `7680x17280`).
- [x] **`20_werewolf_hurt`**: Kurt Adam Formu darbe alma / vahşi hırıltıyla geriye kayıp savaş çömelmesine geçme (144 kare, 6-sütun atlas `7680x17280`).
- [x] **`21_bat_hurt`**: Yarasa Formu havada darbe alma / kanat bükme, sarsılma ve irtifa toparlama (144 kare, 6-sütun atlas `7680x17280`).

---

## 📌 Oyun Motoru (Godot / Unity) Entegrasyon Kuralları

1. **Evrensel Kanvas ve Çıpa (Universal Alignment):**
   - Tüm kareler `1280x720 px` boyutundadır.
   - Tüm yer tabanlı animasyonlar için evrensel çıpa noktası: **`x = 640, y = 680`**.
   - Godot `AnimatedSprite2D` için `offset = Vector2(-640, -680)` kullanıldığında hiçbir formda veya animasyonda boyut zıplaması ya da zemin kayması yaşanmaz.
2. **Çoklu Form Ölüm Mimarisi (Multi-Form Death Sequence):**
   - Boss hangi formda olursa olsun canı 0'a indiğinde:
     1. Karakterin konumunda üst katmanda (`z_index = 10`) `vfx_blood_smoke_burst` başlatılır.
     2. Dumanın ekranı %100 örttüğü **42. karede**, boss sprite'ı anında **Normal İnsan Formuna** çekilir.
     3. Duman dağılırken doğrudan **`18_vlad_death`** animasyonu oynatılır.
3. **Master İndeks Dosyaları:**
   - **`manifest.json`**: 22 animasyonun süreleri, kare sayıları, atlas boyutları ve çarpışma/evre karelerini içerir.
   - **`lineup_poster.png`**: Karakterin 4 formu, duman VFX'i ve düşmüş voyvoda halini gösteren yüksek çözünürlüklü kadro tablosudur.
