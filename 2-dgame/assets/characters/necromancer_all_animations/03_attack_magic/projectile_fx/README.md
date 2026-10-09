# Dark Magic Projectile & Impact FX (Kara Büyü Füzesi)

Bu klasör, Necromancer'ın büyü saldırısında fırlattığı **mor karanlık büyü küresi ve enerji dalgasının** bağımsız oyun assetlerini içerir.

## 🎮 Oyun Motoru Entegrasyonu (Unity / Godot / Unreal / Custom Engine)

1. **Büyücü Ateşleme Zamanlaması:**
   - Necromancer `03_attack_magic` animasyonunu oynatır.
   - **Kare 34**'e gelindiğinde (büyücünün elindeki sihirli çemberin açıldığı an), bu bağımsız mermi objesi (`Projectile`) sahnede instantiate edilir.
   - **Doğma Noktası (Spawn Offset):** Büyücünün ayak merkezine (anchor) göre `X: +95 px`, `Y: -148 px`.

2. **Mermi Uçuşu (`travel_frames/`):**
   - Mermi oyuncuya veya hedefe doğru `velocity.x * speed * dt` hızıyla ilerler.
   - `travel_preview.gif` ve `travel_strip.png` uçuş sırasındaki dalgalı mor karanlık aurasını gösterir.

3. **Çarpışma & Patlama (`burst_frames/`):**
   - Mermi hedefe veya duvara çarptığında yok olmak yerine `burst_frames/` oynatılır.
   - Mor enerji kıvılcımlara ve kara dumana ayrılarak söner.

## 📁 Klasör İçeriği
- `travel_frames/`: Uçuş kareleri (hem 1x oyun boyutu hem de `_hd` yüksek çözünürlük)
- `burst_frames/`: Çarpma/patlama kareleri (`burst_00` .. `burst_06`)
- `travel_preview.gif`: Uçuş önizlemesi
- `burst_preview.gif`: Çarpışma patlama önizlemesi
- `travel_strip.png`: Mermi sprite şeridi
