extends RefCounted

## res://tools/future_build_level_kit.gd
## Bölüm 5 seviye iskeleti (Epic 2D-158): kök + script, 4 katmanlı parallax, neon yağmuru,
## sınır duvarları, ölüm bölgesi, oyuncu/HUD/diyalog, çıkış kapısı ve sık kullanılan
## yerleştirme yardımcıları (düşman, tuzak, eşya, tetik). build_future_levels*.gd kullanır.

const C = preload("res://tools/future_build_common.gd")
const BG: String = "res://assets/backgrounds/future/"
const PARALLAX: String = "res://scripts/objects/world_parallax_background.gd"
const EN: String = "res://scenes/enemies/future/"
const OB: String = "res://scenes/objects/future/"
const HZ: String = "res://scenes/hazards/future/"
const GROUND_Y: float = 560.0


static func level(node_name: String, script_path: String, width: float, top: float, next_scene: String,
		tutorial: PackedStringArray, ambient: Color) -> Node2D:
	var root: Node2D = Node2D.new()
	root.name = node_name
	root.set_script(load(script_path))
	root.set("next_scene_path", next_scene)
	root.set("camera_limits", Rect2i(0, int(top), int(width), int(770.0 - top)))
	root.set("tutorial_keys", tutorial)
	var amb: CanvasModulate = CanvasModulate.new()
	amb.name = "Ambient"
	amb.color = ambient
	root.add_child(amb)
	var layers: Array = [["WorldBackdrop", "bg_sky_neon_storm", -60, 0.03, 0.01],
		["FarLayer", "bg_distant_skyscrapers", -58, 0.1, 0.02],
		["MidLayer", "bg_mid_viaduct_monorail", -56, 0.25, 0.03],
		["NearLayer", "bg_fg_cables_debris", -52, 0.45, 0.04]]
	for spec: Array in layers:
		var p: Node2D = Node2D.new()
		p.name = spec[0]
		p.z_index = spec[2]
		p.set_script(load(PARALLAX))
		p.set("background_texture", load(BG + str(spec[1]) + ".png"))
		p.set("ground_y", GROUND_Y)
		p.set("texture_ground_y", 690.0)
		p.set("texture_scale", Vector2(0.9, 0.9))
		p.set("parallax_factor_x", spec[3])
		p.set("parallax_factor_y", spec[4])
		p.set("tile_count", int(ceil(width / 1700.0)) + 2)
		p.set("fog_color", Color(0, 0, 0, 0))
		root.add_child(p)
	var rain: CPUParticles2D = CPUParticles2D.new()
	rain.name = "NeonRain"
	rain.z_index = 20
	rain.position = Vector2(width * 0.5, top - 40.0)
	rain.amount = 260
	rain.lifetime = 2.2
	rain.preprocess = 2.0
	rain.texture = load("res://assets/effects/future/neon_rain_streak.png") as Texture2D
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(width * 0.5, 20.0)
	rain.direction = Vector2(-0.2, 1.0)
	rain.spread = 4.0
	rain.gravity = Vector2(0, 300)
	rain.initial_velocity_min = 380.0
	rain.initial_velocity_max = 460.0
	rain.color = Color(0.6, 0.85, 1.0, 0.55)
	root.add_child(rain)
	var env: Node2D = Node2D.new()
	env.name = "Environment"
	root.add_child(env)
	var lw: StaticBody2D = StaticBody2D.new()
	lw.name = "WallLeft"
	lw.position = Vector2(5, (top + 770.0) * 0.5)
	env.add_child(lw)
	C.shape(lw, C.rect(Vector2(30, 770.0 - top + 200.0)))
	var rw: StaticBody2D = StaticBody2D.new()
	rw.name = "WallRight"
	rw.position = Vector2(width - 5.0, (top + 770.0) * 0.5)
	env.add_child(rw)
	C.shape(rw, C.rect(Vector2(30, 770.0 - top + 200.0)))
	var dz: Node = C.instance(root, "res://scenes/hazards/death_zone.tscn", "DeathZone", Vector2(width * 0.5, 860.0))
	(dz.get_node("CollisionShape2D") as CollisionShape2D).shape = C.rect(Vector2(width + 400.0, 120.0))
	return root


## Oyuncu, HUD ve diyalog kutusu her zaman en sonda (çizim sırası)
static func finish(root: Node2D, player_pos: Vector2, exit_pos: Vector2, exit_size: Vector2 = Vector2(60, 200)) -> void:
	if exit_pos != Vector2.INF:
		C.area(root, "ExitGate", exit_pos, exit_size)
	var p: Node = C.instance(root, "res://scenes/combat/test_player.tscn", "CombatPlayer", player_pos)
	p.set("has_sword", true)
	p.set("is_armed", true)
	C.instance(root, "res://scenes/ui/fantasy_hud.tscn", "FantasyHUD")
	C.instance(root, "res://scenes/ui/dialogue_box.tscn", "DialogueBox")


static func ground(root: Node2D, node_name: String, x0: float, x1: float, tex: String, y: float = GROUND_Y) -> StaticBody2D:
	return C.block(root.get_node("Environment"), node_name, Vector2(x0, y), Vector2(x1 - x0, 220.0), tex)


static func ledge(root: Node2D, node_name: String, cx: float, y: float, w: float, tex: String) -> StaticBody2D:
	return C.block(root.get_node("Environment"), node_name, Vector2(cx - w * 0.5, y), Vector2(w, 22.0), tex)


## Siper bloğu (lazer tarama tuzaklarına karşı): katı, yüksek blok
static func cover(root: Node2D, node_name: String, cx: float, y: float, h: float, tex: String) -> StaticBody2D:
	return C.block(root.get_node("Environment"), node_name, Vector2(cx - 20.0, y - h), Vector2(40.0, h), tex)


static func group(root: Node, node_name: String) -> Node2D:
	var g: Node2D = root.get_node_or_null(node_name) as Node2D
	if g == null:
		g = Node2D.new()
		g.name = node_name
		root.add_child(g)
	return g


static func enemy(root: Node2D, kind: String, node_name: String, pos: Vector2, props: Dictionary = {}) -> Node:
	var e: Node = C.instance(group(root, "Enemies"), EN + kind + ".tscn", node_name, pos)
	apply(e, props)
	return e


static func hazard(root: Node2D, scene: String, node_name: String, pos: Vector2, props: Dictionary = {}) -> Node:
	var h: Node = C.instance(group(root, "Hazards"), HZ + scene + ".tscn", node_name, pos)
	apply(h, props)
	return h


static func object(root: Node2D, scene: String, node_name: String, pos: Vector2, props: Dictionary = {}, parent_name: String = "Objects") -> Node:
	var o: Node = C.instance(group(root, parent_name), OB + scene + ".tscn", node_name, pos)
	apply(o, props)
	return o


## Özellikleri uygular; tipli dizi (Array[NodePath] vb.) özellikleri türü korunarak atanır
static func apply(node: Node, props: Dictionary) -> void:
	for k: String in props:
		var cur: Variant = node.get(k)
		if cur is Array and props[k] is Array:
			var arr: Array = (cur as Array).duplicate()
			arr.assign(props[k])
			node.set(k, arr)
		else:
			node.set(k, props[k])


static func pickup(root: Node2D, node_name: String, pos: Vector2, item: String, amount: int) -> Node:
	return object(root, "future_pickup", node_name, pos, {"item_id": item, "amount": amount}, "Pickups")


static func beacon(root: Node2D, node_name: String, pos: Vector2, checkpoint_id: String) -> Node:
	return object(root, "obj_checkpoint_beacon", node_name, pos, {"checkpoint_id": checkpoint_id, "is_lit": false})


static func prop(root: Node2D, tex: String, node_name: String, pos: Vector2, scale: float = 1.0, z: int = -5) -> Sprite2D:
	return C.sprite(group(root, "Props"), "res://assets/objects/future/" + tex + ".png", pos, Vector2(scale, scale), node_name, z)


static func neon_light(root: Node2D, node_name: String, pos: Vector2, color: Color, energy: float = 0.9) -> void:
	var l: PointLight2D = PointLight2D.new()
	l.name = node_name
	l.position = pos
	l.color = color
	l.energy = energy
	l.texture_scale = 1.6
	l.texture = load("res://assets/effects/lighting/light_radial_falloff.png") as Texture2D
	group(root, "Lights").add_child(l)


static func secret_wall(root: Node2D, node_name: String, pos: Vector2, codex: String) -> Node:
	var w: Node = C.instance(group(root, "Objects"), "res://scenes/objects/secret_breakable_wall.tscn", node_name, pos)
	var types: Array[String] = ["heavy", "plasma", "emp", "plunge"]
	w.set("breaking_attack_types", types)
	w.set("codex_entry_id", codex)
	w.set("wall_color", Color(0.26, 0.24, 0.34, 1.0))
	return w
