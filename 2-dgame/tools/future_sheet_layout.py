# -*- coding: utf-8 -*-
"""Bölüm 5 (2D-158) kaynak sheet yerleşimleri ve animasyon eşlemeleri.

Kaynak sheet'ler output/future_sources/ altındadır (Gemini ile üretilmiş, kullanıcı tarafından yüklenmiş).
Her sheet'te satır etiketleri (IDLE, RUN, ...) sol sütunda, kareler sağda yatay dizilidir.
`rows`: etiket -> (display koordinatında satır merkezi y, sheet'te görünen kare sayısı); `scale` ile
orijinal piksele çevrilir. Kareler satır bandında sütun yoğunluğu profiliyle ayrılır.
`ref`: gövde ölçeği için referans satır (varsayılan: ilk animasyonun satırı; hale/aura içeren IDLE için WALK).
`row_scale`: sheet'te farklı ölçekte çizilmiş satırlar (ör. büyük SPECIAL kareleri) için düzeltme çarpanı.
`boxes`: düzensiz sheet'ler için elle verilmiş kare kutuları (display koordinatı x0, y0, x1, y1).

ANIMS: oyundaki animasyon adı -> (kaynak satır, kare seçimi, döngü, fps).
Kare seçimi: None = tümü, liste = indeksler (negatif destekli). Her animasyon 16 kareye
zaman örneklemesiyle (kare tutma) genişletilir — 16–24 kare / 10–16 FPS standardı.
"""

SRC_ROOT = r"C:\Projects\2dgame\output\future_sources"

_STD = {"IDLE": 0, "RUN": 0, "WALK": 0, "JUMP": 0, "ATTACK": 0, "HURT": 0, "DIE": 0, "SPECIAL": 0}

SHEETS = {
    "ai_lord_titan": {
        "src": "boss/ai_lord_titan", "scale": 1.264, "ref": "WALK", "row_scale": {"SPECIAL": 0.57}, "x0": 885, "special_x0": 140, "max_y": 1334,
        "rows": {"IDLE": (95, 4), "RUN": (262, 6), "WALK": (400, 4), "JUMP": (540, 5), "ATTACK": (700, 6), "HURT": (845, 3),
                 "DIE": (965, 6), "SPECIAL": (1185, 7)},
    },
    "ai_lord_sovereign": {
        "src": "boss/ai_lord_sovereign", "scale": 1.0, "row_scale": {"SPECIAL": 0.66}, "x0": 680, "special_x0": 100, "max_y": 1024,
        "rows": {"IDLE": (80, 4), "RUN": (197, 6), "WALK": (307, 4), "JUMP": (415, 5), "ATTACK": (535, 6), "HURT": (640, 3),
                 "DIE": (740, 6), "SPECIAL": (905, 7)},
    },
    "ai_lord_singularity": {
        "src": "boss/ai_lord_singularity", "scale": 1.0, "x0": 555, "special_x0": 555, "max_y": 880,
        "rows": {"IDLE": (70, 4), "RUN": (185, 6), "WALK": (290, 4), "JUMP": (390, 6), "ATTACK": (505, 8), "HURT": (612, 3),
                 "DIE": (702, 7), "SPECIAL": (815, 8)},
    },
    "chrono_warden_mech": {
        "src": "miniboss/chrono_warden_mech", "scale": 1.2, "x0": 950, "special_x0": 140, "max_y": 1493,
        "rows": {"IDLE": (120, 4), "WALK": (295, 6), "DASH": (465, 5), "JUMP": (625, 5), "ATTACK": (795, 6), "HURT": (955, 3),
                 "DIE": (1100, 5), "SPECIAL": (1330, 6)},
    },
    "cyber_enforcer": {
        "src": "enemies/cyber_enforcer", "scale": 1.2, "x0": 950, "special_x0": 150, "max_y": 1493,
        "rows": {"IDLE": (120, 3), "RUN": (290, 6), "WALK": (455, 4), "JUMP": (625, 5), "ATTACK": (795, 6), "HURT": (950, 3),
                 "DIE": (1110, 6), "SPECIAL": (1340, 7)},
    },
    "chrono_drone": {
        "src": "enemies/chrono_drone", "scale": 1.2, "row_scale": {"SPECIAL": 0.84}, "x0": 950, "special_x0": 140, "max_y": 1493,
        "rows": {"IDLE": (115, 4), "FLY": (290, 6), "WALK": (455, 4), "DASH": (620, 5), "ATTACK": (795, 6), "HURT": (945, 3),
                 "DIE": (1105, 6), "SPECIAL": (1330, 7)},
    },
    "cyber_hound": {
        "src": "enemies/cyber_hound", "scale": 1.376, "x0": 985, "special_x0": 135, "max_y": 1116,
        "rows": {"IDLE": (95, 3), "RUN": (225, 6), "WALK": (355, 4), "JUMP": (475, 5), "ATTACK": (605, 6), "HURT": (725, 3),
                 "DIE": (855, 6), "SPECIAL": (1010, 6)},
    },
    "hydraulic_juggernaut": {
        "src": "enemies/hydraulic_juggernaut", "scale": 1.376, "row_scale": {"SPECIAL": 0.66}, "x0": 985, "special_x0": 135, "max_y": 1116,
        "rows": {"IDLE": (80, 3), "RUN": (220, 6), "WALK": (345, 4), "JUMP": (470, 5), "ATTACK": (605, 6), "HURT": (725, 3),
                 "DIE": (855, 6), "SPECIAL": (1010, 6)},
    },
    "resistance_fighter": {
        "src": "allies/resistance_fighter", "scale": 1.248, "x0": 990, "special_x0": 990, "max_y": 1359,
        "rows": {"IDLE": (110, 4), "RUN": (275, 6), "WALK": (435, 4), "JUMP": (600, 5), "ATTACK": (765, 5), "HURT": (915, 3),
                 "DIE": (1065, 5), "SPECIAL": (1245, 4)},
    },
    "resistance_engineer": {
        "src": "allies/resistance_engineer", "scale": 1.248, "x0": 990, "special_x0": 990, "max_y": 1359,
        "rows": {"IDLE": (110, 4), "RUN": (275, 6), "WALK": (435, 4), "JUMP": (600, 5), "ATTACK": (765, 5), "HURT": (915, 3),
                 "DIE": (1065, 5), "SPECIAL": (1245, 3)},
    },
    # Düzensiz yerleşim: kareler elle kutulanır (display koordinatı, ölçek 1.376)
    "aegis_core_twins": {
        "src": "miniboss/aegis_core_twins", "scale": 1.376,
        "boxes": {
            "CORE": [(1050, 100, 1160, 225)],
            "IDLE_PAIR": [(920, 75, 1290, 262)],
            "WALK": [(900, 350, 1020, 505), (1025, 350, 1130, 505), (1135, 350, 1245, 505), (1250, 350, 1372, 505)],
            "FLY": [(1410, 80, 1610, 275), (1600, 80, 1770, 275), (1760, 80, 1945, 275)],
            "DASH_RING": [(1585, 335, 1790, 500)],
            "ATTACK": [(900, 595, 1100, 752), (1100, 595, 1260, 752), (1240, 585, 1510, 760)],
            "HURT": [(1545, 585, 1680, 752), (1680, 585, 1820, 752), (1820, 585, 1960, 752)],
            "DIE": [(900, 860, 1010, 1045), (1015, 860, 1200, 1045), (1210, 845, 1375, 1045)],
            "SPECIAL": [(1420, 840, 1960, 1075)],
            "HEAD": [(398, 760, 505, 875)],
        },
    },
}

# Portreler: (sheet, kutu display koordinatı) — sheet'lerdeki "HEAD ICONS" kareleri
PORTRAITS = {
    "portrait_ai_lord": ("ai_lord_titan", (420, 722, 528, 818)),
    "portrait_ai_lord_sovereign": ("ai_lord_sovereign", (227, 552, 309, 622)),
    "portrait_ai_lord_singularity": ("ai_lord_singularity", (318, 648, 440, 742)),
    "portrait_chrono_warden": ("chrono_warden_mech", (315, 818, 431, 922)),
    "portrait_aegis_core": ("aegis_core_twins", (282, 760, 378, 870)),
    "portrait_resistance_leader": ("resistance_engineer", (608, 915, 730, 1036)),
    "portrait_resistance_fighter": ("resistance_fighter", (40, 915, 162, 1036)),
    "portrait_cyber_enforcer": ("cyber_enforcer", (452, 818, 568, 922)),
}

# Efekt kareleri (sheet'lerdeki "EFFECTS" / "SPECIAL" bölümleri) -> VFX
VFX_CROPS = {
    # AI Lord ışınlanma: titan special 1-2 ve efekt halkaları
    "ai_lord_time_ripple": ("ai_lord_titan", (395, 955, 500, 1030)),
    "emp_ring": ("aegis_core_twins", (425, 950, 530, 1060)),
    "shield_orb": ("aegis_core_twins", (50, 950, 160, 1065)),
    "time_clock_ring": ("chrono_drone", (1090, 1215, 1340, 1460)),
    "time_vortex": ("chrono_drone", (140, 1215, 385, 1460)),
    "slow_field_floor": ("chrono_drone", (1610, 1280, 1985, 1420)),
    "laser_beam_tip": ("aegis_core_twins", (680, 960, 835, 1050)),
    "spark_burst": ("chrono_warden_mech", (668, 1080, 765, 1170)),
    "cube_shards": ("aegis_core_twins", (550, 950, 665, 1065)),
    "data_glitch": ("ai_lord_titan", (520, 965, 715, 1030)),
}

# Oyundaki animasyon -> (kaynak satır, kare seçimi, döngü, fps)
ANIMS = {
    "ai_lord_sovereign": {
        "idle": ("IDLE", None, True, 10), "hover_move": ("RUN", None, True, 12),
        "telegraph_grid": ("SPECIAL", [0, 1, 2], False, 12), "laser_lattice_attack": ("ATTACK", None, False, 14),
        "drone_summon": ("SPECIAL", [3, 4, 5, 6, 7], False, 12), "hurt": ("HURT", None, False, 16),
        "phase_transition": ("SPECIAL", [5, 6, 7, 7], False, 10), "blink": ("JUMP", None, False, 14),
        "death": ("DIE", None, False, 12),
    },
    "ai_lord_titan": {
        "idle": ("IDLE", None, True, 10), "heavy_walk": ("WALK", None, True, 10),
        "telegraph_slam": ("SPECIAL", [0, 1], False, 12), "shoulder_cannon_blast": ("ATTACK", None, False, 14),
        "shield_block": ("SPECIAL", [3, 4, 4], True, 12), "groggy": ("HURT", [0, 1, 2, 1], True, 10),
        "hurt": ("HURT", None, False, 16), "phase_transition": ("SPECIAL", [4, 5, 6], False, 10),
        "leap": ("JUMP", None, False, 12), "death": ("DIE", None, False, 12),
    },
    "ai_lord_singularity": {
        "idle": ("IDLE", None, True, 10), "time_blink": ("JUMP", None, False, 14),
        "echo_slash_combo": ("ATTACK", None, False, 16), "core_overdrive_beam": ("SPECIAL", None, False, 12),
        "hurt": ("HURT", None, False, 16), "collapse_death": ("DIE", None, False, 10),
        "move": ("WALK", None, True, 12),
    },
    "chrono_warden_mech": {
        "idle": ("IDLE", None, True, 10), "walk": ("WALK", None, True, 12), "charge_ram": ("DASH", None, False, 14),
        "arm_laser_sweep": ("ATTACK", None, False, 14), "temporal_stomp": ("JUMP", None, False, 12),
        "groggy": ("HURT", [0, 1, 2, 1], True, 10), "hurt": ("HURT", None, False, 16), "death": ("DIE", None, False, 12),
    },
    "cyber_enforcer": {
        "idle": ("IDLE", None, True, 10), "walk": ("WALK", None, True, 12), "run": ("WALK", None, True, 16),
        "attack": ("ATTACK", [0, 1, 2, 3], False, 14), "slash_combo": ("ATTACK", None, False, 14),
        "block": ("IDLE", [0, 1], True, 10), "hurt": ("HURT", None, False, 16), "hit": ("HURT", None, False, 16),
        "death": ("DIE", None, False, 12),
    },
    "chrono_drone": {
        "idle": ("IDLE", None, True, 10), "walk": ("WALK", None, True, 12), "run": ("FLY", None, True, 14),
        "attack": ("ATTACK", None, False, 14), "pulse_cast": ("SPECIAL", [0, 2, 4, 6], False, 12),
        "hurt": ("HURT", None, False, 16), "hit": ("HURT", None, False, 16), "death": ("DIE", None, False, 12),
    },
    "cyber_hound": {
        "idle": ("IDLE", None, True, 10), "walk": ("WALK", None, True, 12), "run": ("RUN", None, True, 16),
        "pounce": ("JUMP", None, False, 14), "attack": ("ATTACK", [0, 1, 2], False, 14),
        "hurt": ("HURT", None, False, 16), "hit": ("HURT", None, False, 16), "death": ("DIE", None, False, 12),
    },
    "hydraulic_juggernaut": {
        "idle": ("IDLE", None, True, 10), "stomp_walk": ("WALK", None, True, 10), "walk": ("WALK", None, True, 10),
        "run": ("WALK", None, True, 12), "piston_smash": ("SPECIAL", None, False, 14), "attack": ("SPECIAL", None, False, 14),
        "hurt": ("HURT", None, False, 16), "hit": ("HURT", None, False, 16), "death": ("DIE", None, False, 12),
    },
    "resistance_fighter": {
        "idle": ("IDLE", None, True, 10), "injured_kneel": ("DIE", [0], True, 10), "follow_walk": ("WALK", None, True, 12),
        "walk": ("WALK", None, True, 12), "shoot_cover": ("ATTACK", [0, 4], True, 12), "evacuate": ("RUN", None, True, 14),
        "drained_death": ("DIE", None, False, 10), "hurt": ("HURT", None, False, 16),
        # EgyptSlave (kurtarma NPC) uyumlu adlar
        "cower": ("DIE", [0], True, 10), "cheer": ("IDLE", None, True, 10), "drained": ("DIE", None, False, 10),
        "death": ("DIE", None, False, 10),
    },
    "resistance_engineer": {
        "idle": ("IDLE", None, True, 10), "hacking": ("SPECIAL", [0, 1], True, 10), "talk": ("IDLE", [0, 2], True, 10),
        "walk": ("WALK", None, True, 12), "evacuate": ("RUN", None, True, 14), "injured_kneel": ("DIE", [0], True, 10),
        "drained_death": ("DIE", None, False, 10), "hurt": ("HURT", None, False, 16),
        "cower": ("DIE", [0], True, 10), "cheer": ("IDLE", None, True, 10), "drained": ("DIE", None, False, 10),
        "death": ("DIE", None, False, 10),
    },
    # Gelişmiş Siber Uçan Böcek: ayrı sheet yüklenmedi (cyber_flying_bug_prime klasöründeki dosya
    # cyber_enforcer sheet'inin kopyası). Zaman-Bükücü Dron sheet'indeki böcek-mekanik FLY/DASH
    # satırlarından, neon-magenta renk kaydırmasıyla üretilir. Adlar CyberFlyingBug ile uyumludur.
    "cyber_flying_bug_prime": {
        "idle": ("FLY", None, True, 12), "hover": ("FLY", None, True, 14), "walk": ("FLY", None, True, 14),
        "telegraph": ("DASH", [0, 0, 1], False, 12), "shoot": ("DASH", [1, 2, 4], False, 14),
        "attack": ("DASH", [0, 1, 2, 4], False, 14), "hurt": ("HURT", [1, 2], False, 16),
        "hit": ("HURT", [1, 2], False, 16), "death": ("DIE", None, False, 12),
    },
    "aegis_core": {
        "core_idle": ("CORE", None, True, 10), "shield_pulse": ("DASH_RING", None, True, 12),
        "overheat_exposed": ("HURT", [1], True, 10), "death": ("DIE", [1, 2], False, 10),
    },
    "aegis_drone": {
        "drone_idle": ("WALK", None, True, 10), "drone_fly": ("FLY", None, True, 12),
        "drone_beam_lock": ("ATTACK", [0, 1], False, 12), "hurt": ("HURT", [0, 2], False, 16),
        "drone_death": ("DIE", None, False, 12),
    },
}

# Varlık -> (kaynak sheet, hedef gövde yüksekliği px, uçan mı)
ENTITIES = {
    "ai_lord_sovereign": ("ai_lord_sovereign", 150, True),
    "ai_lord_titan": ("ai_lord_titan", 170, False),
    "ai_lord_singularity": ("ai_lord_singularity", 150, False),
    "chrono_warden_mech": ("chrono_warden_mech", 124, False),
    "cyber_enforcer": ("cyber_enforcer", 76, False),
    "chrono_drone": ("chrono_drone", 52, True),
    "cyber_hound": ("cyber_hound", 56, False),
    "hydraulic_juggernaut": ("hydraulic_juggernaut", 98, False),
    "resistance_fighter": ("resistance_fighter", 60, False),
    "resistance_engineer": ("resistance_engineer", 60, False),
    "aegis_core": ("aegis_core_twins", 64, True),
    "cyber_flying_bug_prime": ("chrono_drone", 40, True),
    "aegis_drone": ("aegis_core_twins", 78, True),
}

# Renk kaydırma (derece) — aynı kaynak sheet'ten türeyen varlıkları görsel olarak ayırır
HUE_SHIFT = {"cyber_flying_bug_prime": 105.0}

TARGET_FRAMES = 16
