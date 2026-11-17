extends RefCounted

## res://scripts/enemies/ww2/commander_boss_attacks.gd
## Cani Komutan saldırı kalıpları (Epic 2D-144). Saldırılar sahneye bağımsız tehlike
## düğümleri olarak eklenir; boss yalnızca ne zaman ve nereye çağıracağına karar verir.
##   sniper_shot   — Line2D nişan çizgisi (telegraph), ardından çizgi boyunca tek atış.
##                   Arada "ww2_cover" (kum torbası bariyeri) varsa mermiyi bariyer yer.
##   shock_waves   — Sıçrayış inişinde iki yöne zeminde ilerleyen şok dalgası (zıplayarak kaçılır)
##   occult_beams  — Çapraz kırmızı-altın enerji ışınları (telegraph → aktif pencere)

const SNIPER_DAMAGE: int = 26
const SNIPER_TELEGRAPH: float = 0.9
const SHOCK_DAMAGE: int = 18
const SHOCK_SPEED: float = 380.0
const BEAM_DAMAGE: int = 20
const BEAM_TELEGRAPH: float = 1.0
const BEAM_ACTIVE: float = 0.8
const BEAM_WIDTH: float = 22.0


## Bir sonraki saldırı: form ve mesafeye göre ağırlıklı seçim
static func choose_attack(form: int, distance: float, alive_minions: int, since_special: float) -> String:
	match form:
		1:
			if distance < 90.0:
				return "bayonet"
			if since_special > 8.0:
				return "radio"
			return "sniper" if randf() < 0.6 else "bayonet"
		2:
			if distance < 80.0:
				return "punch"
			if since_special > 10.0:
				return "turrets"
			return "leap"
		_:
			if alive_minions < 2 and since_special > 9.0:
				return "summon"
			if randf() < 0.25:
				return "shrink"
			return "beams"


## Nişan çizgisi + atış. Atış anında oyuncu çizgiye yakınsa ve siper yoksa hasar alır.
static func sniper_shot(host: Node, muzzle: Vector2, target: Vector2) -> Line2D:
	var line: Line2D = Line2D.new()
	var dir: Vector2 = (target - muzzle).normalized()
	var end: Vector2 = muzzle + dir * 1400.0
	line.points = PackedVector2Array([muzzle, end])
	line.width = 1.5
	line.default_color = Color(1.0, 0.15, 0.1, 0.8)
	line.z_index = 30
	host.add_child(line)
	var tw: Tween = line.create_tween()
	tw.tween_property(line, "width", 3.5, SNIPER_TELEGRAPH)
	tw.tween_callback(func() -> void:
		resolve_sniper(host, muzzle, end)
		line.default_color = Color(1.0, 0.95, 0.7, 1.0)
		line.width = 5.0
	)
	tw.tween_property(line, "modulate:a", 0.0, 0.18)
	tw.tween_callback(line.queue_free)
	return line


## Atışı çözer: önce siper (cover) kontrolü, sonra oyuncu. Vurulan düğümü döndürür.
static func resolve_sniper(host: Node, a: Vector2, b: Vector2) -> Node:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return null
	var tree: SceneTree = host.get_tree()
	var player: Node2D = tree.get_first_node_in_group("player") as Node2D
	_sfx(host, "sniper_shot", a)
	if player == null or distance_to_segment(player.global_position + Vector2(0.0, -24.0), a, b) > 26.0:
		return null
	for cover: Node in tree.get_nodes_in_group("ww2_cover"):
		if not (cover is Node2D) or ("_is_destroyed" in cover and bool(cover._is_destroyed)):
			continue
		var cx: float = (cover as Node2D).global_position.x
		if (cx - a.x) * (cx - player.global_position.x) < 0.0 and absf(cx - player.global_position.x) < 120.0:
			if cover.has_method("take_damage"):
				cover.take_damage(SNIPER_DAMAGE)
			return cover
	if player.has_method("take_damage"):
		player.take_damage(SNIPER_DAMAGE, a)
	return player


## İniş noktasından iki yöne ilerleyen şok dalgaları
static func shock_waves(host: Node, origin: Vector2, arena: Vector2) -> Array[Node2D]:
	var waves: Array[Node2D] = []
	for dir: int in [-1, 1]:
		var wave: Area2D = Area2D.new()
		wave.collision_layer = 0
		wave.collision_mask = 1
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(26.0, 26.0)
		shape.shape = rect
		shape.position = Vector2(0.0, -13.0)
		wave.add_child(shape)
		var poly: Polygon2D = Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-13, 0), Vector2(0, -30), Vector2(13, 0)])
		poly.color = Color(1.0, 0.35, 0.3, 0.85)
		wave.add_child(poly)
		host.add_child(wave)
		wave.global_position = origin
		var hit_once: Array[bool] = [false]
		wave.body_entered.connect(func(b: Node2D) -> void:
			if not hit_once[0] and b.is_in_group("player") and b.has_method("take_damage"):
				hit_once[0] = true
				b.take_damage(SHOCK_DAMAGE, wave.global_position)
		)
		var end_x: float = arena.x if dir < 0 else arena.y
		var tw: Tween = wave.create_tween()
		tw.tween_property(wave, "global_position:x", end_x, absf(end_x - origin.x) / SHOCK_SPEED)
		tw.tween_callback(wave.queue_free)
		waves.append(wave)
	_sfx(host, "shock_wave", origin)
	return waves


## Çapraz enerji ışınları: boss'un çekirdeğinden zemine iki çapraz ışın
static func occult_beams(host: Node, core: Vector2, arena: Vector2, ground_y: float) -> Array[Line2D]:
	var beams: Array[Line2D] = []
	var player: Node2D = host.get_tree().get_first_node_in_group("player") as Node2D if host.is_inside_tree() else null
	var px: float = player.global_position.x if player else core.x
	var ends: Array[Vector2] = [Vector2(clampf(px - 160.0, arena.x, arena.y), ground_y), Vector2(clampf(px + 160.0, arena.x, arena.y), ground_y)]
	for end: Vector2 in ends:
		var line: Line2D = Line2D.new()
		line.points = PackedVector2Array([core, end + (end - core).normalized() * 120.0])
		line.width = 2.0
		line.default_color = Color(1.0, 0.75, 0.25, 0.55)
		line.z_index = 30
		host.add_child(line)
		var a: Vector2 = line.points[0]
		var b: Vector2 = line.points[1]
		var tw: Tween = line.create_tween()
		tw.tween_property(line, "width", 4.0, BEAM_TELEGRAPH)
		tw.tween_callback(func() -> void:
			line.default_color = Color(1.0, 0.25, 0.25, 1.0)
			line.width = BEAM_WIDTH
			_sfx(host, "occult_beam", core)
			beam_hit(host, a, b)
		)
		tw.tween_interval(BEAM_ACTIVE * 0.5)
		tw.tween_callback(func() -> void: beam_hit(host, a, b))
		tw.tween_interval(BEAM_ACTIVE * 0.5)
		tw.tween_property(line, "modulate:a", 0.0, 0.2)
		tw.tween_callback(line.queue_free)
		beams.append(line)
	return beams


## Işın aktifken oyuncu ışına değiyorsa hasar
static func beam_hit(host: Node, a: Vector2, b: Vector2) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return false
	var player: Node2D = host.get_tree().get_first_node_in_group("player") as Node2D
	if player and distance_to_segment(player.global_position + Vector2(0.0, -24.0), a, b) <= BEAM_WIDTH:
		if not ("is_blood_mist_dashing" in player and bool(player.is_blood_mist_dashing)) and player.has_method("take_damage"):
			player.take_damage(BEAM_DAMAGE, a)
			return true
	return false


static func distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


static func _sfx(host: Node, key: String, at: Vector2) -> void:
	var am: Node = host.get_node_or_null("/root/AudioManager") if host.is_inside_tree() else null
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d(key, at, null, -3.0, 1600.0)
