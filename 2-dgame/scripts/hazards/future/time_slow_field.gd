class_name TimeSlowField
extends Area2D

## res://scripts/hazards/future/time_slow_field.gd
## Zaman anomalisi alanı (Epic 2D-158). "slow" (mavi): içindeki oyuncunun hareket hızı ve
## animasyonu yavaşlar, mermiler yavaşlar. "fast" (kırmızı): her şey hızlanır.
## Oyuncu hızı meta ile saklanır ve alandan çıkınca geri yüklenir (birden çok alan üst üste
## binerse son çıkışta temel hıza döner). AI Lord Form 3 zaman dondurma alanı bu sınıfı kullanır.

signal player_entered(field: TimeSlowField)

const FutureFx = preload("res://scripts/effects/future_fx.gd")
const META_BASE_SPEED: StringName = &"future_time_base_speed"
const META_FIELDS: StringName = &"future_time_fields"
const PROJECTILE_GROUPS: Array[StringName] = [&"reflectable_projectile", &"enemy_projectiles", &"player_projectiles"]

@export_enum("slow", "fast") var mode: String = "slow"
@export var size: Vector2 = Vector2(220.0, 160.0)
@export var factor: float = 0.45
@export var lifetime: float = 0.0
@export var show_visual: bool = true

var _bodies: Array[Node2D] = []
var _scaled_projectiles: Dictionary = {}


func _ready() -> void:
	add_to_group("future_time_fields")
	collision_layer = 0
	collision_mask = 1 | 2
	monitoring = true
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = Vector2(0.0, -size.y * 0.5)
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	if show_visual:
		call_deferred("_build_visual") # konum, ekleyen tarafından ayarlandıktan sonra
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(dispose)


func get_multiplier() -> float:
	return factor if mode == "slow" else 1.0 / maxf(0.2, factor)


func affects(body: Node) -> bool:
	return _bodies.has(body)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _bodies.has(body):
		return
	_bodies.append(body)
	var fields: int = int(body.get_meta(META_FIELDS, 0))
	if fields == 0 and "speed" in body:
		body.set_meta(META_BASE_SPEED, float(body.speed))
	body.set_meta(META_FIELDS, fields + 1)
	if body.has_meta(META_BASE_SPEED):
		body.speed = float(body.get_meta(META_BASE_SPEED)) * get_multiplier()
	var sprite: AnimatedSprite2D = body.get("anim_sprite") as AnimatedSprite2D if "anim_sprite" in body else null
	if sprite:
		sprite.speed_scale = get_multiplier()
	FutureFx.sfx(self, "sfx_time_slow_warp", body.global_position, -8.0)
	player_entered.emit(self)


func _on_body_exited(body: Node2D) -> void:
	if not _bodies.has(body):
		return
	_bodies.erase(body)
	_release(body)


func _release(body: Node2D) -> void:
	if not is_instance_valid(body):
		return
	var fields: int = maxi(0, int(body.get_meta(META_FIELDS, 1)) - 1)
	body.set_meta(META_FIELDS, fields)
	if fields == 0 and body.has_meta(META_BASE_SPEED):
		body.speed = float(body.get_meta(META_BASE_SPEED))
		body.remove_meta(META_BASE_SPEED)
		var sprite: AnimatedSprite2D = body.get("anim_sprite") as AnimatedSprite2D if "anim_sprite" in body else null
		if sprite:
			sprite.speed_scale = 1.0


## Alana giren mermilerin hızı ölçeklenir (bir kez)
func _on_area_entered(area: Area2D) -> void:
	var proj: Node = area if _is_projectile(area) else area.get_parent()
	if proj == null or not _is_projectile(proj) or _scaled_projectiles.has(proj.get_instance_id()):
		return
	_scaled_projectiles[proj.get_instance_id()] = true
	if "velocity" in proj and proj.velocity is Vector2:
		proj.velocity = (proj.velocity as Vector2) * get_multiplier()
	elif "speed" in proj:
		proj.speed = float(proj.speed) * get_multiplier()


func _is_projectile(node: Node) -> bool:
	for g: StringName in PROJECTILE_GROUPS:
		if node.is_in_group(g):
			return true
	return false


func dispose() -> void:
	for body: Node2D in _bodies.duplicate():
		_release(body)
	_bodies.clear()
	queue_free()


func _exit_tree() -> void:
	for body: Node2D in _bodies:
		_release(body)
	_bodies.clear()


func _build_visual() -> void:
	var tex_path: String = "res://assets/effects/future/slow_field_floor.png"
	var col: Color = Color(0.4, 0.8, 1.0, 0.55) if mode == "slow" else Color(1.0, 0.35, 0.4, 0.55)
	var fill: ColorRect = ColorRect.new()
	fill.color = Color(col, 0.12)
	fill.size = size
	fill.position = Vector2(-size.x * 0.5, -size.y)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	if ResourceLoader.exists(tex_path):
		var floor_spr: Sprite2D = Sprite2D.new()
		floor_spr.texture = load(tex_path) as Texture2D
		floor_spr.modulate = col
		floor_spr.scale = Vector2(size.x / 160.0, 0.5)
		floor_spr.position = Vector2(0.0, -8.0)
		add_child(floor_spr)
	FutureFx.play_vfx(self, FutureFx.VFX_TIME_FRACTURE, global_position + Vector2(0.0, -size.y * 0.5), size.y / 160.0, 5)
