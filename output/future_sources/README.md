# Bölüm 5 (Distopik Gelecek) — Kaynak Görsel Klasörü (2D-158)

Bu klasör `res://` dışındadır; ham kaynaklar buraya, işlenmiş çıktılar
`2-dgame/assets/.../future/` altına (extract + FEET_Y hizalama + .tres) gider.

## Sprite sheet kuralları (Blood Knight / Vlad hattıyla aynı)

- **Her animasyon ayrı bir PNG** olsun: `<klasör>/<animasyon>.png` (örn. `boss/ai_lord_titan/heavy_walk.png`).
  Tek büyük sheet de olur, ama o zaman her satır bir animasyon olmalı ve satır sırası aşağıdaki listeyle aynı olmalı.
- Kareler **yatay tek satırda**, eşit aralıklı; kare sayısı serbest (4–24). Az kare gelirse ara kareler üretilir/tekrarlanır.
- **Düz, tek renk arka plan** (tercihen şeffaf PNG; değilse saf yeşil `#00FF00` ya da düz gri). Gölge/zemin çizgisi olmasın.
- Karakter **sağa baksın**, tüm karelerde aynı ölçek, ayaklar aynı yükseklikte.
- Yan görünüş (2D platformer), Vlad / Blood Knight ile uyumlu karanlık, detaylı piksel-art/boyalı stil; neon camgöbeği/magenta vurgular.

## İstenen dosyalar

| Klasör | Animasyonlar |
| --- | --- |
| `boss/ai_lord_sovereign` | idle, hover_move, telegraph_grid, laser_lattice_attack, drone_summon, hurt, phase_transition |
| `boss/ai_lord_titan` | idle, heavy_walk, telegraph_slam, shoulder_cannon_blast, shield_block, groggy, hurt, phase_transition |
| `boss/ai_lord_singularity` | idle, time_blink, echo_slash_combo, core_overdrive_beam, hurt, collapse_death |
| `boss/vfx` | ai_lord_teleport_vfx (kare dizisi), ai_lord_time_ripple |
| `miniboss/chrono_warden_mech` | idle, walk, charge_ram, arm_laser_sweep, temporal_stomp, groggy, hurt, death |
| `miniboss/aegis_core_twins` | core_idle, shield_pulse, overheat_exposed, drone_idle, drone_beam_lock, drone_death |
| `enemies/cyber_flying_bug_prime` | idle, hover, telegraph, shoot, hurt, death |
| `enemies/cyber_enforcer` | idle, walk, slash_combo, block, hurt, death |
| `enemies/chrono_drone` | idle, pulse_cast, hurt, death |
| `enemies/hydraulic_juggernaut` | idle, stomp_walk, piston_smash, hurt, death |
| `enemies/cyber_hound` | idle, run, pounce, hurt, death |
| `allies/resistance_fighter` | idle, injured_kneel, follow_walk, shoot_cover, evacuate, drained_death |
| `allies/resistance_engineer` | idle, hacking, talk, drained_death |
| `portraits` | portrait_ai_lord, portrait_chrono_warden, portrait_aegis_core, portrait_resistance_leader (kare, ~256×256) |
| `parallax` | bg_sky_neon_storm, bg_distant_skyscrapers, bg_mid_viaduct_monorail, bg_fg_cables_debris (yatay döşenebilir, ≥1920 px genişlik) |
| `tilesets` | tileset_neon_ruins, tileset_cyber_factory, tileset_core_citadel (32×32 ya da 64×64 grid) |
| `props` | prop_stamped_armature_mold, prop_trex_cyber_harness, prop_broken_hologram, prop_cryo_pod, prop_evac_capsule |
| `traps` | trap_laser_gate, trap_hydraulic_press, trap_plasma_channel, conveyor_belt, emp_terminal, time_slow_field, checkpoint_beacon |
| `items_vfx` | 7 eşya ikonu (nano_repair_kit, chrono_injector, phase_shield, emp_grenade, plasma_flare, core_access_chip, resistance_tag), stamped_prototype_part, heart_fragment_5, vfx_emp_blast, vfx_time_fracture, vfx_sword_shell_shatter, sixth_core_aura |
| `audio/music` | bgm_future_neon_ruins, bgm_future_assembly_tension, bgm_ai_lord_boss (.ogg) |
| `audio/sfx` | sfx_cyber_laser_charge, sfx_cyber_laser_fire, sfx_time_slow_warp, sfx_emp_detonate, sfx_hydraulic_stomp, sfx_ai_lord_glitch_voice, sfx_sword_shell_crack, sfx_sword_shatter_wizard_laugh (.wav) |

Dosya adları tam olarak tablodaki gibi olmalı (uzantı `.png`, ses için `.ogg`/`.wav`).
