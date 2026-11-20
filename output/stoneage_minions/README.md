# Taş Devri minyon sprite kaynakları (2D-101, 2D-136)

Raptor, siber uçan böcek ve mağara adamının ham üretim sayfaları. Oyuna giren kareler
`2-dgame/assets/characters/{raptor,cyber_bug,caveman}/` altındadır ve bu sayfalardan üretilir.

## Nasıl üretildi

- Araç: Higgsfield üzerinden GPT Image 2.6, 1k çözünürlük, şeffaf arka plan.
- Her karakter için önce `reference.png` (kalite: high) üretildi. Stil referansı olarak
  `assets/characters/trex_boss/idle_frames/idle_00.png`, mağara adamı için ayrıca
  `assets/ui/portraits/portrait_caveman.png` verildi.
- Her animasyon, o `reference.png` referans verilerek tek sayfa (`<animasyon>_raw.png`,
  kalite: medium) olarak üretildi: 4 kare için 2x2, 6 kare için 3x2 ızgara, sağa bakan yan görünüş,
  kareler arasında boşluk, efektsiz (ışın, toz, kan, gölge yok).

## Oyun karelerini yeniden üretmek

`2-dgame/` klasöründe (Python 3.13, Pillow ve numpy gerekir):

    py -3.13 tools/build_minion_sprites.py tools/minion_sprites/raptor.json
    py -3.13 tools/build_minion_sprites.py tools/minion_sprites/cyber_bug.json
    py -3.13 tools/build_minion_sprites.py tools/minion_sprites/caveman.json

Boyut (`target_height`), kare hızı (`fps`) ve palet (`colors`) bu JSON dosyalarından değişir;
yeniden görsel üretmek gerekmez. Araç kareleri keser, ölçekleri eşitler, ayakları zemine hizalar,
şeritleri ve `*_frames.tres` kaynağını yazar. Önizlemeler `<karakter>/preview/` altına çıkar.

## Oyun içi boyutlar

| Karakter | Yükseklik | Hücre | Hizalama |
|---|---|---|---|
| Raptor | 72 px | 190x98 | zemin |
| Siber böcek | 44 px | 94x68 | merkez (uçan) |
| Mağara adamı | 58 px | 72x67 | zemin |

`lineup.png` üçünü şövalyeyle aynı ölçekte, `ingame_overview.png` oyun içinde gösterir
(`tools/capture_stoneage_minions.gd` ile alınır).
