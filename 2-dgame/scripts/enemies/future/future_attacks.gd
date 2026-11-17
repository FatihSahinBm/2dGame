extends RefCounted

## res://scripts/enemies/future/future_attacks.gd
## Bölüm 5 ortak saldırı tehlikeleri (Epic 2D-158) — düşmanlar, mini-bosslar ve AI Lord kullanır.
##   aim_beam:     kırmızı Line2D nişan çizgisi (telegraph) -> enerji ışını; ışın yolunda dünya
##                 engeli varsa (RayCast kuralı) ışın orada kesilir — siper arkası güvenlidir.
##   shock_waves:  zemin boyunca iki yöne ilerleyen zaman şok dalgası (Kan Sisi ile hasarsız geçilir).
##   slow_field:   geçici TimeSlowField (zaman yavaşlatma / dondurma alanı).
## Tüm enerji hasarları FutureInventory.apply_energy_damage ile verilir (Faz Kalkanı, Kan Sisi).

const FutureInventory = preload("res://scripts/components/future_inventory.gd")
const FutureFx = preload("res://scripts/effects/future_fx.gd")
const SlowFieldScript = preload("res://scripts/hazards/future/time_slow_field.gd")

const SHOCK_SPEED: float = 300.0
const BEAM_HALF_WIDTH: float = 14.0


## Engel kuralı: a'dan b'ye ilk dünya (katman 1, StaticBody) çarpışma noktası; yoksa b
static func clip_to_cover(host: Node2D, a: Vector2, b: Vector2) -> Vector2:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return b
	var space: PhysicsDirectSpaceState2D = host.get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(a, b, 1)
	query.collide_with_bodies = true
	var excluded: Array[RID] = []
	for _i: int in 6:
		query.exclude = excluded
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return b
		var col: Object = hit.get("collider")
		if col is StaticBody2D or col is TileMapLayer:
			return hit["position"]
		excluded.append(hit.get("rid"))
	return b


## Telegraph + ışın. Işın oluşturulduğu anda bir kez hasar kontrolü yapar. Line2D döndürür.
static func aim_beam(host: Node2D, a: Vector2, b: Vector2, telegraph: float, damage: int,
		color: Color = Color(1.0, 0.15, 0.25, 1.0), width: float = 9.0) -> Line2D:
	var parent: Node = host.get_parent() if host.get_parent() else host
	var line: Line2D = Line2D.new()
	line.width = 2.0
	line.default_color = Color(1.0, 0.1, 0.15, 0.85)
	line.z_index = 30
	parent.add_child(line)
	line.points = PackedVector2Array([a, b])
	FutureFx.sfx(host, "sfx_cyber_laser_charge", a, -8.0)
	var tw: Tween = line.create_tween()
	tw.tween_interval(telegraph)
	# host weakref ile taşınır: boss/dron ışın sürerken yok olursa geri çağrı güvenle boşa düşer
	tw.tween_callback(_fire_beam.bind(weakref(host), line, a, b, damage, color, width))
	tw.tween_property(line, "modulate:a", 0.0, 0.35)
	tw.tween_callback(line.queue_free)
	return line


static func _fire_beam(host_ref: WeakRef, line: Line2D, a: Vector2, b: Vector2, damage: int, color: Color, width: float) -> void:
	var host: Node2D = host_ref.get_ref() as Node2D
	if host == null or not is_instance_valid(line):
		return
	var end: Vector2 = clip_to_cover(host, a, b)
	line.points = PackedVector2Array([a, end])
	line.width = width
	line.default_color = color
	resolve_beam(host, a, end, damage)
	FutureFx.sfx(host, "sfx_cyber_laser_fire", a, -6.0)


static func resolve_beam(host: Node, a: Vector2, b: Vector2, damage: int) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return false
	var player: Node2D = host.get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var p: Vector2 = player.global_position + Vector2(0.0, -20.0)
	if distance_to_segment(p, a, b) > BEAM_HALF_WIDTH + 12.0:
		return false
	return FutureInventory.apply_energy_damage(player, damage, a)


static func distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


## Zemin boyunca iki yöne zaman şok dalgası
static func shock_waves(host: Node, origin: Vector2, arena: Vector2, damage: int = 20,
		color: Color = Color(0.4, 0.9, 1.0, 0.9)) -> Array[Node2D]:
	var waves: Array[Node2D] = []
	var parent: Node = host.get_parent() if host.get_parent() else host
	for dir: int in [-1, 1]:
		var wave: Area2D = Area2D.new()
		wave.collision_layer = 0
		wave.collision_mask = 1
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(26.0, 30.0)
		shape.shape = rect
		shape.position = Vector2(0.0, -15.0)
		wave.add_child(shape)
		var poly: Polygon2D = Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-14, 0), Vector2(-4, -34), Vector2(4, -22), Vector2(14, 0)])
		poly.color = color
		wave.add_child(poly)
		parent.add_child(wave)
		wave.add_to_group("future_shock_waves")
		wave.global_position = origin
		var hit_once: Array[bool] = [false]
		wave.body_entered.connect(func(body: Node2D) -> void:
			if not hit_once[0] and body.is_in_group("player") and body.has_method("take_damage"):
				if "is_blood_mist_dashing" in body and bool(body.is_blood_mist_dashing):
					return
				hit_once[0] = true
				body.take_damage(damage, wave.global_position)
		)
		var end_x: float = arena.x if dir < 0 else arena.y
		var tw: Tween = wave.create_tween()
		tw.tween_property(wave, "global_position:x", end_x, maxf(0.05, absf(end_x - origin.x) / SHOCK_SPEED))
		tw.tween_callback(wave.queue_free)
		waves.append(wave)
	FutureFx.sfx(host, "sfx_hydraulic_stomp", origin)
	FutureFx.shake(host, 5.0, 0.25, "future_shock")
	return waves


## Geçici zaman alanı; alanı döndürür
static func slow_field(host: Node, pos: Vector2, mode: String, size: Vector2, lifetime: float, factor: float = 0.45) -> Area2D:
	var parent: Node = host.get_parent() if host.get_parent() else host
	var field: Area2D = SlowFieldScript.new() as Area2D
	field.set("mode", mode)
	field.set("size", size)
	field.set("lifetime", lifetime)
	field.set("factor", factor)
	parent.add_child(field)
	field.global_position = pos
	return field
