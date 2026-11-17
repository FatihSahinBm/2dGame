extends SceneTree

## res://tools/build_future_levels_2.gd
## Bölüm 5 sekans 3-5 sahnelerini üretir (Epic 2D-158).
## Çalıştırma (2-dgame klasöründen, önce build_future_actors.gd):
##   & $g --headless --path . --script res://tools/build_future_levels_2.gd

const C = preload("res://tools/future_build_common.gd")
const K = preload("res://tools/future_build_level_kit.gd")
const LV: String = "res://scenes/levels/future/"
const SC: String = "res://scripts/levels/future/"
const CITADEL: String = "res://assets/environment/future/ground_core_citadel.png"
const RUINS: String = "res://assets/environment/future/ground_neon_ruins.png"
const THRONE_Y: float = -1340.0


func _init() -> void:
	var ok: bool = _stage_3() and _stage_4() and _stage_5()
	print("BUILD_FUTURE_LEVELS_2 ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)


## Sekans 3 — Direniş Yeraltı Ağı ve Veri Kalesi (5600 px)
func _stage_3() -> bool:
	var root: Node2D = K.level("FutureStage3ResistanceCitadel", SC + "stage_3_resistance_citadel.gd", 5600.0, -200.0,
		LV + "stage_4_ai_lord_citadel.tscn", PackedStringArray(["FUT_TUT_03_TITLE", "FUT_TUT_03_SUB", "FUT_TUT_03_DESC"]),
		Color(0.7, 0.82, 1.0, 1.0))
	K.ground(root, "Floor", 0, 5600, CITADEL)
	# Güç yönlendirme 1: terminal A lazer kapısı koridorunu söndürür
	for i: int in 3:
		K.hazard(root, "trap_laser_gate", "CorridorGate%d" % i, Vector2(1100 + i * 200, 380), {"beam_length": 190.0, "cycle_off": 0.0})
	K.object(root, "obj_emp_terminal", "TerminalA", Vector2(900, 560), {"mode": "power_off",
		"linked_paths": [NodePath("../../Hazards/CorridorGate0"), NodePath("../../Hazards/CorridorGate1"), NodePath("../../Hazards/CorridorGate2")]})
	# Zaman yavaşlatma odası + sunucu düğümü A
	C.area(root, "SlowRoomTrigger", Vector2(1760, 500), Vector2(60, 200))
	K.object(root, "obj_time_slow_field", "SlowRoomA", Vector2(1950, 560), {"mode": "slow", "size": Vector2(240, 180)}, "TimeRifts")
	K.object(root, "obj_time_slow_field", "FastRoomB", Vector2(2300, 560), {"mode": "fast", "size": Vector2(200, 180), "factor": 0.7}, "TimeRifts")
	K.object(root, "obj_server_node", "ServerA", Vector2(2120, 560), {"node_id": "node_a"}, "ServerNodes")
	K.enemy(root, "chrono_drone", "SlowDrone", Vector2(2000, 420))
	K.enemy(root, "cyber_enforcer", "RoomGuard", Vector2(2420, 560), {"direction": -1})
	# Güç yönlendirme 2 (terminal A'ya bağlı): plazma kanalları + tarama lazeri
	K.hazard(root, "trap_plasma_channel", "PlasmaA", Vector2(2820, 560), {"width": 110.0})
	K.hazard(root, "trap_plasma_channel", "PlasmaB", Vector2(3020, 560), {"width": 110.0, "start_offset": 0.9})
	K.hazard(root, "laser_scan_trap", "VaultLaser", Vector2(3420, 524), {"direction": -1, "max_range": 560.0})
	K.cover(root, "VaultCover", 3150, 560, 60, CITADEL)
	K.object(root, "obj_emp_terminal", "TerminalB", Vector2(2620, 560), {"mode": "power_off",
		"requires_terminals": [NodePath("../TerminalA")],
		"linked_paths": [NodePath("../../Hazards/PlasmaA"), NodePath("../../Hazards/PlasmaB"), NodePath("../../Hazards/VaultLaser")]})
	# Son İnsanlık Sığınağı (B): mühendisler
	K.enemy(root, "cyber_enforcer", "EngineerGuardA", Vector2(2900, 560), {"direction": -1})
	K.enemy(root, "cyber_hound", "EngineerGuardB", Vector2(3260, 560), {"direction": -1})
	K.object(root, "rescue_engineer", "RescueEngineerA", Vector2(2720, 560),
		{"spot_id": "engineer_a", "guard_paths": [NodePath("../../Enemies/EngineerGuardA")]})
	K.object(root, "rescue_engineer", "RescueEngineerB", Vector2(3320, 560),
		{"spot_id": "engineer_b", "guard_paths": [NodePath("../../Enemies/EngineerGuardB")]})
	K.object(root, "obj_server_node", "ServerB", Vector2(3500, 560), {"node_id": "node_b"}, "ServerNodes")
	# Zaman mühürlü kapı (heart_resonance) -> Kılıç Damgasının Kökeni hologramı (üst oda)
	K.ledge(root, "SealStep", 3560, 490, 80, CITADEL)
	K.ledge(root, "SealRoom", 3760, 400, 300, CITADEL)
	var barrier: StaticBody2D = C.block(root, "SealBarrier", Vector2(3640, 250), Vector2(30, 150), "res://assets/objects/future/obj_resonance_door.png")
	barrier.modulate = Color(1.0, 0.85, 0.5)
	K.object(root, "resonance_door", "ResonanceDoor", Vector2(3610, 400), {"barrier_path": NodePath("../../SealBarrier")})
	K.object(root, "lore_terminal", "SigilHologram", Vector2(3840, 400), {"codex_entry_id": "future_lore_sigil_origin",
		"dialogue_key": "fut_sigil_hologram"})
	# Gizli sığınak (kırılabilir duvar) -> Yamalı Zaman Radyosu (bonus ödül)
	K.ledge(root, "ShelterStep", 4000, 490, 80, CITADEL)
	K.ledge(root, "HiddenShelter", 4220, 420, 320, CITADEL)
	K.secret_wall(root, "ShelterWall", Vector2(4110, 420), "")
	K.object(root, "lore_terminal", "PatchworkRadio", Vector2(4300, 420), {"codex_entry_id": "future_lore_patchwork_radio",
		"dialogue_key": "fut_radio_easter_egg", "reward_item": "phase_shield_capsule", "reward_amount": 2, "play_sound": "sfx_time_slow_warp"})
	K.object(root, "obj_server_node", "ServerC", Vector2(4420, 560), {"node_id": "node_c"}, "ServerNodes")
	K.beacon(root, "Beacon", Vector2(4520, 560), "future_citadel_beacon")
	# Mini-Boss 2: AEGIS-09 veri çekirdeği odası
	C.area(root, "AegisTrigger", Vector2(4680, 500), Vector2(60, 200))
	var core: Node = C.instance(root, "res://scenes/enemies/future/aegis_core.tscn", "AegisCore", Vector2(5080, 430))
	core.set("arena_bounds", Vector2(4620, 5560))
	core.set("ground_y", 560.0)
	for i: int in 2:
		var d: Node = C.instance(root, "res://scenes/enemies/future/aegis_drone.tscn", "AegisDrone%d" % i, Vector2(4920 + i * 320, 380))
		d.set("phase_offset", PI * float(i))
		d.set("arena_bounds", Vector2(4620, 5560))
		d.set("ground_y", 560.0)
	for i: int in 5:
		K.neon_light(root, "Neon%d" % i, Vector2(500 + i * 1150, 380), Color(0.4, 0.8, 1.0) if i % 2 else Color(0.8, 0.4, 1.0))
	K.pickup(root, "EmpPack", Vector2(1800, 560), "emp_grenade", 2)
	K.pickup(root, "NanoKit", Vector2(3080, 560), "nano_repair_kit", 1)
	K.pickup(root, "Plasma", Vector2(4440, 420), "plasma_cutter_flare", 2)
	K.pickup(root, "PhaseShield", Vector2(4560, 560), "phase_shield_capsule", 1)
	K.finish(root, Vector2(300, 500), Vector2(5560, 480))
	return C.save(root, LV + "stage_3_resistance_citadel.tscn")


## Sekans 4 — AI Lord Ana Çekirdek Kulesi: dikey tırmanış + taht odası (1800 px, 1900 px yükseklik)
func _stage_4() -> bool:
	var root: Node2D = K.level("FutureStage4AiLordCitadel", SC + "stage_4_ai_lord_citadel.gd", 1800.0, -1800.0,
		LV + "stage_5_sword_shattering.tscn", PackedStringArray(["FUT_TUT_04_TITLE", "FUT_TUT_04_SUB", "FUT_TUT_04_DESC"]),
		Color(0.72, 0.7, 1.0, 1.0))
	K.ground(root, "TowerBase", 0, 1800, CITADEL)
	# Zikzak tırmanış: her 95 px'te bir platform; bazıları kırılan lazer köprüsü
	var xs: Array[float] = [520.0, 860.0, 1200.0, 1500.0, 1200.0, 860.0, 520.0, 220.0]
	var y: float = 470.0
	var i: int = 0
	while y > THRONE_Y + 60.0:
		var x: float = xs[i % xs.size()]
		if i % 5 == 3:
			var plat: Node = C.instance(K.group(root, "LaserBridges"), "res://scenes/objects/collapsing_platform.tscn", "LaserBridge%d" % i, Vector2(x, y))
			plat.set("collapse_delay", 0.7)
			plat.set("restore_delay", 2.5)
		else:
			K.ledge(root, "Climb%d" % i, x, y, 200.0, CITADEL)
		if i % 4 == 2:
			K.hazard(root, "trap_laser_gate", "Grid%d" % i, Vector2(x + 120.0, y - 150.0), {"beam_length": 150.0, "cycle_off": 0.0})
		y -= 95.0
		i += 1
	# Dron dalgaları (tetik alanı metası: kind / count; Points çocukları doğma noktaları)
	var waves: Array = [[Vector2(900, 250), "chrono_drone", 2], [Vector2(900, -350), "cyber_flying_bug_prime", 2], [Vector2(900, -900), "chrono_drone", 3]]
	for w: int in waves.size():
		var spec: Array = waves[w]
		var trig: Area2D = C.area(root, "WaveTrigger%d" % w, spec[0], Vector2(1600, 40))
		trig.set_meta("kind", spec[1])
		trig.set_meta("count", spec[2])
		var pts: Node2D = Node2D.new()
		pts.name = "Points"
		trig.add_child(pts)
		for p: int in 3:
			var m: Marker2D = Marker2D.new()
			m.name = "P%d" % p
			m.position = Vector2(-500 + p * 500, -220)
			pts.add_child(m)
	# Çekirdek Taht Odası (zeminde tırmanış deliği x 120-330)
	K.ground(root, "ThroneFloorL", 0, 120, CITADEL, THRONE_Y)
	K.ground(root, "ThroneFloorR", 330, 1800, CITADEL, THRONE_Y)
	K.cover(root, "ThroneCoverA", 700, THRONE_Y, 64, CITADEL)
	K.cover(root, "ThroneCoverB", 1150, THRONE_Y, 64, CITADEL)
	C.area(root, "ThroneTrigger", Vector2(560, THRONE_Y - 60), Vector2(60, 160))
	var boss: Node = C.instance(root, "res://scenes/enemies/future/ai_lord.tscn", "AiLordBoss", Vector2(1400, THRONE_Y))
	boss.set("arena_bounds", Vector2(380, 1760))
	boss.set("ground_y", THRONE_Y)
	var turrets: Node2D = K.group(root, "ArenaTurrets")
	for t: int in 4:
		var left: bool = t % 2 == 0
		var tur: Node = C.instance(turrets, "res://scenes/hazards/future/laser_scan_trap.tscn", "Turret%d" % t,
			Vector2(400 if left else 1760, THRONE_Y - 36 - (t / 2) * 70))
		tur.set("direction", 1 if left else -1)
		tur.set("max_range", 1300.0)
		tur.set("powered", false)
	var drones: Node2D = K.group(root, "DronePoints")
	for d: int in 4:
		var m: Marker2D = Marker2D.new()
		m.name = "D%d" % d
		m.position = Vector2(500 + d * 350, THRONE_Y - 230)
		drones.add_child(m)
	K.beacon(root, "Beacon", Vector2(520, THRONE_Y), "future_throne_beacon")
	K.pickup(root, "NanoKit", Vector2(1500, 470 - 95 * 3), "nano_repair_kit", 1)
	K.pickup(root, "EmpPack", Vector2(220, 470 - 95 * 7), "emp_grenade", 2)
	K.pickup(root, "PhaseShield", Vector2(450, THRONE_Y), "phase_shield_capsule", 1)
	for n: int in 6:
		K.neon_light(root, "Neon%d" % n, Vector2(900, 400 - n * 320), Color(0.5, 0.6, 1.0))
	K.finish(root, Vector2(200, 500), Vector2.INF)
	return C.save(root, LV + "stage_4_ai_lord_citadel.tscn")


## Sekans 5 — 5. Kalp Parçası, Mührün Çatlaması ve Kılıcın Kırılışı (1800 px)
func _stage_5() -> bool:
	var root: Node2D = K.level("FutureStage5SwordShattering", SC + "stage_5_sword_shattering.gd", 1800.0, -140.0,
		"", PackedStringArray(["FUT_TUT_05_TITLE", "FUT_TUT_05_SUB", "FUT_TUT_05_DESC"]), Color(0.75, 0.68, 1.0, 1.0))
	K.ground(root, "ThroneRuins", 0, 1800, CITADEL)
	var remains: Node2D = Node2D.new()
	remains.name = "AiLordRemains"
	remains.position = Vector2(1150, 560)
	root.add_child(remains)
	var spr: AnimatedSprite2D = C.animated_sprite(remains, "ai_lord_singularity", 0.75, &"collapse_death")
	spr.frame = 15
	spr.autoplay = ""
	var heart: Sprite2D = C.sprite(root, "res://assets/items/future/heart_piece_5.png", Vector2(1150, 500), Vector2(1.4, 1.4), "HeartPieceVisual", 30)
	heart.visible = false
	var shadow: Node2D = Node2D.new()
	shadow.name = "WizardShadow"
	shadow.position = Vector2(1450, 330)
	root.add_child(shadow)
	var vortex: Sprite2D = C.sprite(shadow, "res://assets/effects/future/time_vortex.png", Vector2.ZERO, Vector2(1.8, 2.4), "Silhouette", 25)
	vortex.modulate = Color(0.12, 0.02, 0.18, 0.9)
	var smoke: CPUParticles2D = CPUParticles2D.new()
	smoke.name = "Smoke"
	smoke.texture = load("res://assets/effects/future/neon_spark.png") as Texture2D
	smoke.amount = 40
	smoke.lifetime = 2.0
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 70.0
	smoke.gravity = Vector2(0, -20)
	smoke.scale_amount_min = 2.0
	smoke.scale_amount_max = 4.0
	smoke.color = Color(0.25, 0.05, 0.3, 0.6)
	shadow.add_child(smoke)
	C.instance(root, "res://scenes/objects/dimensional_time_rift.tscn", "VoidRift", Vector2(1600, 420))
	C.instance(root, "res://scenes/ui/flashback_overlay.tscn", "FlashbackOverlay")
	K.neon_light(root, "CoreGlow", Vector2(1150, 480), Color(0.4, 0.6, 1.0), 1.2)
	K.finish(root, Vector2(420, 500), Vector2.INF)
	return C.save(root, LV + "stage_5_sword_shattering.tscn")
