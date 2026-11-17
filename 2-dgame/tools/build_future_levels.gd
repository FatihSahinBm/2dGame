extends SceneTree

## res://tools/build_future_levels.gd
## Bölüm 5 sekans 1-2 sahnelerini üretir (Epic 2D-158). Sekans 3-5: build_future_levels_2.gd.
## Çalıştırma (2-dgame klasöründen, önce build_future_actors.gd):
##   & $g --headless --path . --script res://tools/build_future_levels.gd

const C = preload("res://tools/future_build_common.gd")
const K = preload("res://tools/future_build_level_kit.gd")
const LV: String = "res://scenes/levels/future/"
const SC: String = "res://scripts/levels/future/"
const RUINS: String = "res://assets/environment/future/ground_neon_ruins.png"
const FACTORY: String = "res://assets/environment/future/ground_cyber_factory.png"


func _init() -> void:
	var ok: bool = _stage_1() and _stage_2()
	print("BUILD_FUTURE_LEVELS_1 ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)


## Sekans 1 — Neon Enkazı ve Gökdelen Yıkıntıları (5200 px)
func _stage_1() -> bool:
	var root: Node2D = K.level("FutureStage1NeonRuins", SC + "stage_1_neon_ruins.gd", 5200.0, -260.0,
		LV + "stage_2_temporal_assembly.tscn", PackedStringArray(["FUT_TUT_01_TITLE", "FUT_TUT_01_SUB", "FUT_TUT_01_DESC"]),
		Color(0.78, 0.72, 0.98, 1.0))
	C.instance(root, "res://scenes/objects/dimensional_time_rift.tscn", "DimensionalTimeRift", Vector2(260, 300))
	# Sokak + çatı yolları (aralarında boşluk: ölüm bölgesi)
	K.ground(root, "Street", 0, 700, RUINS)
	K.ground(root, "RooftopA", 780, 1500, RUINS, 480.0)
	K.ground(root, "RooftopB", 1640, 2300, RUINS, 430.0)
	K.ground(root, "RooftopC", 2860, 3420, RUINS, 470.0)
	K.ground(root, "MetroShelter", 3420, 5200, RUINS)
	K.ledge(root, "StepA", 730, 520, 70, RUINS)
	K.ledge(root, "AntennaLedge", 1240, 380, 120, RUINS)
	K.ledge(root, "SignLedge", 2060, 330, 110, RUINS)
	# Çöken gökdelen köprüsü
	for i: int in 3:
		var plat: Node = C.instance(K.group(root, "CollapsingBridge"), "res://scenes/objects/collapsing_platform.tscn", "Bridge%d" % i, Vector2(2400 + i * 150, 450))
		plat.set("collapse_delay", 0.8)
		plat.set("restore_delay", 3.0)
	# Lazer tarama tuzakları + siper blokları (CyberLaserSystem siper kuralı)
	K.hazard(root, "laser_scan_trap", "ScanLaserA", Vector2(800, 444), {"direction": 1, "max_range": 680.0, "idle_time": 1.8})
	K.cover(root, "CoverA1", 1020, 480, 64, RUINS)
	K.cover(root, "CoverA2", 1300, 480, 64, RUINS)
	K.hazard(root, "laser_scan_trap", "ScanLaserB", Vector2(2280, 394), {"direction": -1, "max_range": 620.0, "idle_time": 1.6, "start_delay": 0.8})
	K.cover(root, "CoverB1", 1880, 430, 64, RUINS)
	K.cover(root, "CoverB2", 2100, 430, 64, RUINS)
	K.hazard(root, "trap_laser_gate", "RoofGate", Vector2(3120, 300), {"beam_length": 170.0, "cycle_on": 1.4, "cycle_off": 1.4})
	K.hazard(root, "trap_laser_gate", "MetroGate", Vector2(3700, 380), {"beam_length": 180.0, "cycle_on": 1.2, "cycle_off": 1.6, "start_offset": 0.6})
	# Düşmanlar
	K.enemy(root, "cyber_enforcer", "EnforcerRoof", Vector2(1380, 480), {"direction": -1})
	K.enemy(root, "cyber_flying_bug_prime", "BugA", Vector2(1150, 330))
	K.enemy(root, "cyber_hound", "HoundB1", Vector2(1800, 430), {"direction": -1})
	K.enemy(root, "cyber_hound", "HoundB2", Vector2(2180, 430), {"direction": -1})
	K.enemy(root, "cyber_flying_bug_prime", "BugC", Vector2(3000, 330))
	K.enemy(root, "cyber_enforcer", "EnforcerC", Vector2(3300, 470), {"direction": -1})
	K.enemy(root, "cyber_enforcer", "ShelterGuardA", Vector2(4020, 560), {"direction": -1})
	K.enemy(root, "cyber_hound", "ShelterGuardB", Vector2(4480, 560), {"direction": -1})
	K.enemy(root, "chrono_drone", "ShelterDrone", Vector2(4800, 420))
	# Metro sığınağı: Son İnsanlık Sığınağı (A)
	C.area(root, "ShelterTrigger", Vector2(3560, 500), Vector2(60, 200))
	K.object(root, "rescue_survivor", "RescueSurvivorA", Vector2(4180, 560),
		{"spot_id": "survivor_a", "guard_paths": [NodePath("../../Enemies/ShelterGuardA")]})
	K.object(root, "rescue_survivor", "RescueSurvivorB", Vector2(4660, 560),
		{"spot_id": "survivor_b", "guard_paths": [NodePath("../../Enemies/ShelterGuardB"), NodePath("../../Enemies/ShelterDrone")]})
	K.beacon(root, "Beacon", Vector2(2950, 470), "future_rooftop_beacon")
	# Prop'lar, ışıklar, eşyalar
	K.prop(root, "prop_broken_hologram", "HoloRuin", Vector2(560, 500))
	K.prop(root, "prop_cryo_pod", "CryoPodA", Vector2(3900, 490))
	K.prop(root, "prop_cryo_pod", "CryoPodB", Vector2(4960, 490))
	for i: int in 6:
		K.neon_light(root, "Neon%d" % i, Vector2(500 + i * 850, 380), Color(1.0, 0.3, 0.8) if i % 2 else Color(0.3, 0.9, 1.0))
	K.pickup(root, "NanoKit", Vector2(1120, 480), "nano_repair_kit", 1)
	K.pickup(root, "EmpPack", Vector2(1700, 430), "emp_grenade", 2)
	K.pickup(root, "PlasmaFlare", Vector2(3300, 470), "plasma_cutter_flare", 2)
	K.pickup(root, "PhaseShield", Vector2(3880, 560), "phase_shield_capsule", 1)
	K.finish(root, Vector2(260, 500), Vector2(5150, 480))
	return C.save(root, LV + "stage_1_neon_ruins.tscn")


## Sekans 2 — Zaman Fırtınası Viyadüğü ve Sibernetik Montaj Hattı (5600 px)
func _stage_2() -> bool:
	var root: Node2D = K.level("FutureStage2TemporalAssembly", SC + "stage_2_temporal_assembly.gd", 5600.0, -200.0,
		LV + "stage_3_resistance_citadel.tscn", PackedStringArray(["FUT_TUT_02_TITLE", "FUT_TUT_02_SUB", "FUT_TUT_02_DESC"]),
		Color(0.92, 0.8, 0.72, 1.0))
	K.ground(root, "Entrance", 0, 980, FACTORY)
	K.ground(root, "PressHall", 2280, 5600, FACTORY)
	K.ledge(root, "MidBelt", 1550, 520, 80, FACTORY)
	K.ledge(root, "EmpLedge", 2200, 430, 90, FACTORY)
	# Gizli Unit-REX-01 telemetri odası (başlangıcın solunda, kırılabilir duvarın ardında)
	K.secret_wall(root, "RexSecretWall", Vector2(320, 560), "")
	K.object(root, "lore_terminal", "RexTelemetry", Vector2(150, 560), {"interact_prompt": "PROMPT_FUT_INSPECT",
		"codex_entry_id": "future_lore_rex_telemetry", "dialogue_key": "fut_rex_telemetry", "reward_item": "chrono_injector", "reward_amount": 1})
	# Konveyör bantları (çukur üstü köprü) + yön terminali
	var b1: Node = K.object(root, "obj_conveyor_belt", "BeltA", Vector2(1260, 540), {"length": 520.0, "direction": 1, "belt_speed": 80.0}, "Conveyors")
	var b2: Node = K.object(root, "obj_conveyor_belt", "BeltB", Vector2(1930, 500), {"length": 520.0, "direction": -1, "belt_speed": 95.0}, "Conveyors")
	K.object(root, "obj_emp_terminal", "BeltTerminal", Vector2(900, 560),
		{"mode": "reverse", "linked_paths": [NodePath("../../Conveyors/BeltA"), NodePath("../../Conveyors/BeltB")]})
	assert(b1 != null and b2 != null)
	# Hidrolik pres koridoru, plazma kanalları, zaman yarıkları
	for i: int in 4:
		K.hazard(root, "trap_hydraulic_press", "Press%d" % i, Vector2(2600 + i * 300, 400), {"travel": 135.0, "start_offset": float(i) * 0.45})
	K.hazard(root, "trap_plasma_channel", "PlasmaA", Vector2(2750, 560), {"width": 120.0})
	K.hazard(root, "trap_plasma_channel", "PlasmaB", Vector2(3350, 560), {"width": 120.0, "start_offset": 1.0})
	K.object(root, "obj_time_slow_field", "RiftSlow", Vector2(3060, 560), {"mode": "slow", "size": Vector2(200, 170)}, "TimeRifts")
	K.object(root, "obj_time_slow_field", "RiftFast", Vector2(3700, 560), {"mode": "fast", "size": Vector2(180, 170), "factor": 0.7}, "TimeRifts")
	K.enemy(root, "cyber_enforcer", "LineGuard", Vector2(2450, 560), {"direction": -1})
	K.enemy(root, "cyber_hound", "LineHound", Vector2(2850, 560), {"direction": -1})
	K.enemy(root, "chrono_drone", "LineDrone", Vector2(3100, 420))
	K.enemy(root, "hydraulic_juggernaut", "JuggernautA", Vector2(3650, 560), {"direction": -1})
	K.enemy(root, "hydraulic_juggernaut", "JuggernautB", Vector2(4500, 560), {"direction": -1})
	# Büyük Keşif Anı: damgalı kalıp + T-Rex zırhı; şema tarama noktaları
	K.prop(root, "prop_stamped_armature_mold", "StampedMold", Vector2(4120, 470), 1.1)
	K.prop(root, "prop_trex_cyber_harness", "TrexHarness", Vector2(4420, 485), 0.9)
	C.area(root, "MoldTrigger", Vector2(3960, 500), Vector2(60, 200))
	K.object(root, "lore_terminal", "ScanSocket", Vector2(4170, 560), {"interact_prompt": "PROMPT_FUT_SCAN", "scan_id": "socket",
		"dialogue_key": "fut_schematic_scanned_socket"})
	K.object(root, "lore_terminal", "ScanHarness", Vector2(4470, 560), {"interact_prompt": "PROMPT_FUT_SCAN", "scan_id": "harness",
		"dialogue_key": "fut_schematic_scanned_harness"})
	K.beacon(root, "Beacon", Vector2(4640, 560), "future_assembly_beacon")
	# Mini-Boss 1 kapı kilidi arenası
	C.area(root, "WardenTrigger", Vector2(4820, 500), Vector2(60, 200))
	var warden: Node = C.instance(root, "res://scenes/enemies/future/chrono_warden_mech.tscn", "ChronoWarden", Vector2(5200, 560))
	warden.set("arena_bounds", Vector2(4700, 5420))
	warden.set("ground_y", 560.0)
	var gate: StaticBody2D = C.block(root, "GateLock", Vector2(5440, 260), Vector2(40, 300), "res://assets/environment/future/ground_core_citadel.png")
	gate.modulate = Color(0.7, 0.9, 1.2)
	for i: int in 5:
		K.neon_light(root, "Neon%d" % i, Vector2(600 + i * 1150, 400), Color(1.0, 0.65, 0.3) if i % 2 else Color(0.3, 0.9, 1.0))
	K.pickup(root, "EmpPack", Vector2(2200, 430), "emp_grenade", 2)
	K.pickup(root, "NanoKit", Vector2(3820, 560), "nano_repair_kit", 1)
	K.pickup(root, "PhaseShield", Vector2(4300, 560), "phase_shield_capsule", 1)
	K.finish(root, Vector2(520, 500), Vector2(5560, 480))
	return C.save(root, LV + "stage_2_temporal_assembly.tscn")
