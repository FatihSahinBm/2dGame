extends SceneTree

## res://tools/build_future_actors.gd
## Bölüm 5 karakter / nesne / tuzak sahnelerini üretir (Epic 2D-158). Sprite hizası
## extract_future_sprites.py manifestlerinden (frame_size, feet_y) okunur.
## Çalıştırma (2-dgame klasöründen):
##   & $g --headless --path . --script res://tools/build_future_actors.gd

const C = preload("res://tools/future_build_common.gd")
const EN: String = "res://scenes/enemies/future/"
const OB: String = "res://scenes/objects/future/"
const HZ: String = "res://scenes/hazards/future/"
const AL: String = "res://scenes/allies/"


func _init() -> void:
	var ok: bool = true
	ok = _enemy("cyber_enforcer", "shield", 0.62, 110, 18, 46.0, 230.0, 60.0, 110.0, false, Vector2(22, 52)) and ok
	ok = _enemy("chrono_drone", "pulse", 0.7, 60, 12, 40.0, 280.0, 55.0, 90.0, true, Vector2(30, 30)) and ok
	ok = _enemy("hydraulic_juggernaut", "heavy", 0.72, 260, 26, 62.0, 220.0, 40.0, 70.0, false, Vector2(40, 70)) and ok
	ok = _enemy("cyber_hound", "pounce", 0.85, 75, 14, 44.0, 260.0, 90.0, 160.0, false, Vector2(40, 30)) and ok
	ok = _bug_prime() and ok
	ok = _boss("chrono_warden_mech", "ChronoWarden", "res://scripts/enemies/future/chrono_warden.gd", 0.8, 600, "chrono_warden_mech", "mini_boss", Vector2(48, 104), {"move_speed": 55.0}) and ok
	ok = _boss("aegis_core", "AegisCore", "res://scripts/enemies/future/aegis_core.gd", 0.9, 500, "aegis_core", "mini_boss", Vector2(46, 46), {}) and ok
	ok = _boss("aegis_drone", "AegisDrone", "res://scripts/enemies/future/aegis_drone.gd", 0.55, 90, "aegis_core", "aegis_drone_unit", Vector2(30, 40), {}) and ok
	ok = _boss("ai_lord_sovereign", "AiLordBoss", "res://scripts/enemies/future/ai_lord_boss.gd", 0.75, 1500, "ai_lord", "boss", Vector2(46, 120), {}, "ai_lord") and ok
	ok = _ally("resistance_fighter", "survivor_a") and ok
	ok = _ally("resistance_engineer", "engineer_a") and ok
	ok = _rescue("rescue_survivor", "resistance_fighter", "survivor", "nano_repair_kit") and ok
	ok = _rescue("rescue_engineer", "resistance_engineer", "engineer", "emp_grenade") and ok
	ok = _objects() and ok
	ok = _hazards() and ok
	print("BUILD_FUTURE_ACTORS ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)


func _enemy(entity: String, behavior: String, scale: float, hp: int, dmg: int, attack_range: float,
		detect: float, speed: float, chase: float, flying: bool, body: Vector2) -> bool:
	var root: CharacterBody2D = CharacterBody2D.new()
	root.name = entity.to_pascal_case()
	root.collision_layer = 2
	root.collision_mask = 1
	root.floor_snap_length = 4.0
	root.set_script(load("res://scripts/enemies/future/future_enemy.gd"))
	root.set("monster_name", entity.capitalize())
	root.set("codex_id", entity)
	root.set("max_health", hp)
	root.set("current_health", hp)
	root.set("attack_damage", dmg)
	root.set("attack_range", attack_range)
	root.set("detection_range", detect)
	root.set("speed", speed)
	root.set("chase_speed", chase)
	root.set("is_flying", flying)
	root.set("behavior", behavior)
	root.set("max_poise", 200.0 if behavior == "heavy" else 55.0)
	root.add_to_group("damageable", true)
	root.add_to_group("enemies", true)
	var center: Vector2 = Vector2(0.0, 0.0 if flying else -body.y * 0.5)
	C.shape(root, C.rect(body), center)
	var visual: Node2D = Node2D.new()
	visual.name = "Visual"
	root.add_child(visual)
	C.animated_sprite(visual, entity, scale)
	var hit: Area2D = Area2D.new()
	hit.name = "Hitbox"
	hit.position = Vector2(body.x * 0.5 + 14.0, center.y)
	hit.collision_layer = 0
	hit.collision_mask = 1
	hit.monitoring = false
	visual.add_child(hit)
	C.shape(hit, C.rect(Vector2(attack_range * 0.8, body.y * 0.8)))
	var ledge: RayCast2D = RayCast2D.new()
	ledge.name = "LedgeRay"
	ledge.position = Vector2(body.x * 0.5 + 6.0, 0.0)
	ledge.target_position = Vector2(0.0, 24.0)
	ledge.collision_mask = 1
	visual.add_child(ledge)
	var hurt: Area2D = Area2D.new()
	hurt.name = "Hurtbox"
	hurt.position = center
	hurt.collision_layer = 4
	hurt.collision_mask = 2
	root.add_child(hurt)
	C.shape(hurt, C.rect(body + Vector2(4, 4)))
	var det: Area2D = Area2D.new()
	det.name = "DetectionArea"
	det.collision_layer = 0
	det.collision_mask = 1
	root.add_child(det)
	C.shape(det, C.circle(detect))
	_health_ui(root, -body.y - 18.0 if not flying else -body.y)
	return C.save(root, EN + entity + ".tscn")


func _health_ui(root: Node, top: float) -> void:
	var ui: Node2D = Node2D.new()
	ui.name = "UI"
	root.add_child(ui)
	var bar: ProgressBar = ProgressBar.new()
	bar.name = "HealthBar"
	bar.offset_left = -22.0
	bar.offset_right = 22.0
	bar.offset_top = top
	bar.offset_bottom = top + 6.0
	bar.show_percentage = false
	bar.value = 100.0
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.1, 0.16, 0.88)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.85, 1.0, 1.0)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	ui.add_child(bar)
	var nums: Node2D = Node2D.new()
	nums.name = "DamageNumbers"
	ui.add_child(nums)


## Gelişmiş Siber Uçan Böcek: Bölüm 1 CyberFlyingBug yapay zekâsı + yeni neon zırhlı kareler
func _bug_prime() -> bool:
	var root: Node = (load("res://scenes/enemies/cyber_flying_bug.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED)
	root.name = "CyberFlyingBugPrime"
	root.set("monster_name", "Gelişmiş Siber Uçan Böcek")
	root.set("max_health", 70)
	root.set("current_health", 70)
	root.set("projectile_damage", 16)
	root.add_to_group("mechanical", true)
	root.add_to_group("future_enemies", true)
	var spr: AnimatedSprite2D = root.get_node("Visual/AnimatedSprite2D") as AnimatedSprite2D
	var m: Dictionary = C.manifest("cyber_flying_bug_prime")
	var size: Array = m.get("frame_size", [72, 56])
	spr.sprite_frames = C.frames("cyber_flying_bug_prime")
	spr.scale = Vector2(0.9, 0.9)
	spr.position = Vector2(0.0, (float(size[1]) * 0.5 - float(m.get("feet_y", 28))) * 0.9 - 6.0)
	spr.animation = &"idle"
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	var err: int = ResourceSaver.save(packed, EN + "cyber_flying_bug_prime.tscn")
	root.free()
	print("OK  ", EN + "cyber_flying_bug_prime.tscn" if err == OK else "FAIL bug prime")
	return err == OK


func _boss(entity: String, node_name: String, script_path: String, scale: float, hp: int, codex: String,
		group: String, body: Vector2, extra: Dictionary, out_name: String = "") -> bool:
	var root: CharacterBody2D = CharacterBody2D.new()
	root.name = node_name
	root.collision_layer = 2
	root.collision_mask = 1
	root.set_script(load(script_path))
	root.set("max_health", hp)
	root.set("codex_id", codex)
	root.set("boss_group", group)
	for k: String in extra:
		root.set(k, extra[k])
	root.add_to_group("damageable", true)
	root.add_to_group("enemies", true)
	var hovering: bool = entity.begins_with("aegis")
	C.shape(root, C.rect(body), Vector2(0.0, 0.0 if hovering else -body.y * 0.5))
	var visual: Node2D = Node2D.new()
	visual.name = "Visual"
	root.add_child(visual)
	var first: StringName = &"core_idle" if entity == "aegis_core" else (&"drone_idle" if entity == "aegis_drone" else &"idle")
	C.animated_sprite(visual, entity, scale, first)
	if entity == "aegis_core":
		var shield: Sprite2D = C.sprite(visual, "res://assets/effects/future/shield_orb.png", Vector2.ZERO, Vector2(1.1, 1.1), "Shield", 2)
		shield.modulate = Color(0.6, 0.9, 1.0, 0.55)
	var glow: Sprite2D = C.sprite(visual, "res://assets/effects/lighting/light_radial_falloff.png", Vector2(0.0, -body.y * 0.5), Vector2(0.6, 0.6), "Glow", -1)
	glow.modulate = Color(0.4, 0.8, 1.0, 0.35)
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	return C.save(root, EN + (out_name if not out_name.is_empty() else entity) + ".tscn")


func _ally(entity: String, slave_id: String) -> bool:
	var root: CharacterBody2D = CharacterBody2D.new()
	root.name = entity.to_pascal_case()
	root.collision_layer = 8
	root.collision_mask = 1
	root.set_script(load("res://scripts/allies/egypt_slave.gd"))
	root.set("slave_id", slave_id)
	C.shape(root, C.rect(Vector2(16, 40)), Vector2(0, -20))
	C.animated_sprite(root, entity, 0.72, &"cower")
	return C.save(root, AL + entity + ".tscn")


func _rescue(scene_name: String, ally: String, kind: String, reward: String) -> bool:
	var root: Area2D = Area2D.new()
	root.name = "FutureRescueSpot"
	root.set_script(load("res://scripts/objects/future/future_rescue_spot.gd"))
	root.set("kind", kind)
	root.set("reward_item", reward)
	root.set("reward_amount", 2)
	C.shape(root, C.rect(Vector2(140, 100)), Vector2(0, -50))
	C.sprite(root, "res://assets/objects/future/prop_evac_capsule.png", Vector2(64, -62), Vector2(0.75, 0.75), "Capsule", -1)
	C.instance(root, AL + ally + ".tscn", "Npc")
	return C.save(root, OB + scene_name + ".tscn")


func _objects() -> bool:
	var ok: bool = true
	var term: Area2D = Area2D.new()
	term.name = "EmpTerminal"
	term.set_script(load("res://scripts/objects/future/emp_terminal.gd"))
	C.shape(term, C.rect(Vector2(70, 80)), Vector2(0, -40))
	C.sprite(term, "res://assets/objects/future/obj_emp_terminal.png", Vector2(0, -36))
	ok = C.save(term, OB + "obj_emp_terminal.tscn") and ok
	var belt: StaticBody2D = StaticBody2D.new()
	belt.name = "ConveyorBelt"
	belt.set_script(load("res://scripts/hazards/future/conveyor_belt.gd"))
	ok = C.save(belt, OB + "obj_conveyor_belt.tscn") and ok
	var field: Area2D = Area2D.new()
	field.name = "TimeSlowField"
	field.set_script(load("res://scripts/hazards/future/time_slow_field.gd"))
	ok = C.save(field, OB + "obj_time_slow_field.tscn") and ok
	var server: StaticBody2D = StaticBody2D.new()
	server.name = "ServerNode"
	server.set_script(load("res://scripts/objects/future/server_node.gd"))
	ok = C.save(server, OB + "obj_server_node.tscn") and ok
	var lore: Area2D = Area2D.new()
	lore.name = "FutureLoreTerminal"
	lore.set_script(load("res://scripts/objects/future/future_lore_terminal.gd"))
	C.shape(lore, C.rect(Vector2(80, 90)), Vector2(0, -45))
	C.sprite(lore, "res://assets/objects/future/prop_broken_hologram.png", Vector2(0, -60), Vector2(0.8, 0.8))
	ok = C.save(lore, OB + "lore_terminal.tscn") and ok
	var door: Area2D = Area2D.new()
	door.name = "FutureResonanceDoor"
	door.set_script(load("res://scripts/objects/future/future_resonance_door.gd"))
	C.shape(door, C.rect(Vector2(90, 120)), Vector2(-40, -60))
	ok = C.save(door, OB + "resonance_door.tscn") and ok
	var pickup: Area2D = Area2D.new()
	pickup.name = "FuturePickup"
	pickup.set_script(load("res://scripts/objects/future/future_pickup.gd"))
	ok = C.save(pickup, OB + "future_pickup.tscn") and ok
	ok = _beacon() and ok
	return ok


func _beacon() -> bool:
	var root: Area2D = Area2D.new()
	root.name = "CheckpointBeacon"
	root.set_script(load("res://scripts/objects/future/future_checkpoint_beacon.gd"))
	root.collision_layer = 0
	root.collision_mask = 1
	C.shape(root, C.circle(48.0))
	var visual: Node2D = Node2D.new()
	visual.name = "Visual"
	root.add_child(visual)
	var unlit: Node2D = Node2D.new()
	unlit.name = "UnlitVisual"
	visual.add_child(unlit)
	C.sprite(unlit, "res://assets/objects/future/obj_checkpoint_beacon_off.png", Vector2(0, -48), Vector2.ONE, "HearthSprite")
	var lit: Node2D = Node2D.new()
	lit.name = "FireVisual"
	visual.add_child(lit)
	C.sprite(lit, "res://assets/objects/future/obj_checkpoint_beacon.png", Vector2(0, -48), Vector2.ONE, "BeaconSprite")
	var glow: Sprite2D = C.sprite(lit, "res://assets/effects/future/neon_spark.png", Vector2(0, -80), Vector2(5, 5), "LightGlow")
	glow.modulate = Color(0.4, 0.9, 1.0, 0.6)
	var embers: CPUParticles2D = CPUParticles2D.new()
	embers.name = "EmbersParticles"
	embers.texture = load("res://assets/effects/future/neon_spark.png") as Texture2D
	embers.amount = 16
	embers.lifetime = 1.4
	embers.position = Vector2(0, -88)
	embers.gravity = Vector2(0, -20)
	embers.color = Color(0.4, 0.9, 1.0, 0.8)
	embers.emitting = false
	visual.add_child(embers)
	var label: Label = Label.new()
	label.name = "PromptLabel"
	label.position = Vector2(-80, -130)
	label.add_theme_font_size_override("font_size", 11)
	label.visible = false
	visual.add_child(label)
	return C.save(root, OB + "obj_checkpoint_beacon.tscn")


func _hazards() -> bool:
	var ok: bool = true
	for spec: Array in [["trap_laser_gate", "res://scripts/hazards/future/laser_gate.gd", "LaserGate"],
			["trap_hydraulic_press", "res://scripts/hazards/future/hydraulic_press.gd", "HydraulicPress"],
			["laser_scan_trap", "res://scripts/hazards/future/future_laser_trap.gd", "FutureLaserTrap"]]:
		var n: Node2D = Node2D.new()
		n.name = spec[2]
		n.set_script(load(spec[1]))
		ok = C.save(n, HZ + spec[0] + ".tscn") and ok
	var plasma: Area2D = Area2D.new()
	plasma.name = "PlasmaChannel"
	plasma.set_script(load("res://scripts/hazards/future/plasma_channel.gd"))
	ok = C.save(plasma, HZ + "trap_plasma_channel.tscn") and ok
	return ok
