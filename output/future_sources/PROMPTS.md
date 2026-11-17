# Bölüm 5 — Eksik asset'ler için AI (Gemini) promptları (2D-158)

Yüklediğin sheet'ler kullanıldı: AI Lord'un 3 formu, Krono-Muhafız, AEGIS ikizleri, Devriye Androidi, Zaman-Bükücü Dron,
Mekanik Tazı, Hidrolik Yıkıcı, Direniş Askeri ve Mühendisi. Portreler sheet'lerdeki HEAD ICONS kutularından,
VFX'ler EFFECTS/SPECIAL kutularından kesildi.

**Eksik kalanlar** şu an `2-dgame/tools/generate_future_assets.py` ile katmanlı doku hattında üretiliyor.
Aşağıdaki promptlarla üretip dosyayı **tam bu adla** ilgili klasöre koyarsan, üreticiyi yeniden çalıştırınca
prosedürel sürüm otomatik olarak seninkiyle değişir:

```
py -3.10 2-dgame/tools/generate_future_assets.py     # parallax / tileset / prop / tuzak / eşya
py -3.10 2-dgame/tools/extract_future_sprites.py     # karakter sheet'leri (Siber Böcek dahil)
```

Ortak stil eki (her promptun sonuna ekle):
> 2D side-view pixel art, dark cyberpunk dystopia, deep navy and violet base with neon cyan and magenta accents,
> crisp 1px dark outline, painterly shading, consistent with a dark-fantasy pixel game (Vlad / Blood Knight style),
> no text, no watermark, flat pure transparent background.

## 1. Gelişmiş Siber Uçan Böcek (karakter sheet'i) — `enemies/cyber_flying_bug_prime/`
`cyber_flying_bug_prime` klasörüne yüklenen dosya Cyber Enforcer sheet'inin birebir kopyasıydı. Şu an bu birim
Zaman-Bükücü Dron sheet'indeki böcek-mekanik FLY/DASH satırlarından, magenta renk kaydırmasıyla üretiliyor.
> Sprite sheet of a flying cybernetic insect drone "Cyber Flying Bug Prime": armored beetle body, two thruster wings,
> glowing magenta optic, underslung energy cannon. Rows labeled IDLE (4), HOVER (6), TELEGRAPH (4, body glows red),
> SHOOT (6, energy bolt), HURT (3), DIE (6, sparks and falling debris). Facing right, same scale every frame,
> same layout as the other enemy sheets (title + head icons + effects on the left, animation rows on the right).

## 2. Parallax (1920×720, yatay döşenebilir) — `parallax/`
- `bg_sky_neon_storm.png`: violet storm sky over a dead megacity, magenta horizon glow, lightning, acid rain streaks.
- `bg_distant_skyscrapers.png`: silhouettes of broken skyscrapers with sparse cyan/magenta window grids and red antenna lights, transparent sky.
- `bg_mid_viaduct_monorail.png`: collapsed monorail viaduct with arches, broken gap in the middle, flickering neon signs, transparent background.
- `bg_fg_cables_debris.png`: foreground hanging cables, rebar and rubble silhouettes, drifting hologram fragments, neon rain, mostly transparent.

## 3. Tileset'ler (256×256, 4×4 adet 64 px karo; üst sıra kaplamalı kenar) — `tilesets/`
- `tileset_neon_ruins.png`: cracked skyscraper concrete and steel blocks with exposed rebar, magenta neon trim.
- `tileset_cyber_factory.png`: riveted conveyor / assembly floor plates with amber hazard stripes.
- `tileset_core_citadel.png`: glossy black AI tower panels with glowing cyan circuitry.

## 4. Hikâye prop'ları — `props/`
- `prop_stamped_armature_mold.png` (220×170): industrial casting mold holding the giant mechanical shoulder socket from the Stone Age chapter, stamped with an ancient seal (circle, triangle, central eye line).
- `prop_trex_cyber_harness.png` (260×150): T-Rex cybernetic armour harness with laser module on a launch sled, label "UNIT-REX-01".
- `prop_broken_hologram.png` (96×128), `prop_cryo_pod.png` (72×140), `prop_evac_capsule.png` (120×150).

## 5. Tuzak / etkileşim — `traps/`
`trap_laser_gate.png` (24×140 emitter post), `trap_hydraulic_press.png` (110×220 piston + head),
`trap_plasma_channel.png` (128×32 floor trough), `obj_emp_terminal.png` (48×72), `obj_server_node.png` (56×96),
`obj_resonance_door.png` (64×200, ancient seal), `obj_checkpoint_beacon.png` (32×96).

## 6. Eşya ikonları (32×32; 5. Kalp Parçası 40×48) — `items_vfx/`
`nano_repair_kit`, `chrono_injector`, `phase_shield_capsule`, `emp_grenade`, `plasma_cutter_flare`,
`core_access_chip`, `resistance_tag`, `stamped_prototype_part`, `heart_piece_5` (cyber-mechanical heart, cables, white core).
