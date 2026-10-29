class_name CollapsingPlatform
extends StaticBody2D

## res://scripts/objects/collapsing_platform.gd
## Story 2D-132: Dinamik Çöken Platform (Collapsing Platform)
##
## Başarı Kriterleri:
## 1. Oyuncu (veya düşman) üzerine bastığında sarsılıp çöker.
## 2. Belirlenen süre sonunda güvenle geri gelir veya tek kullanımlık (one_shot) olarak kalır.
## 3. Katman ayrımı: Player ve Düşman tetikleme tercihi.
## 4. Çöküş ve yenilenme sinyalleri ve ses efektleri.
## 5. Çökme anında çarpışma kutusu (CollisionShape2D) güvenle devre dışı kalır.

signal shake_started()
signal collapsed()
signal restored()

enum PlatformState {
	IDLE = 0,
	SHAKING = 1,
	COLLAPSED = 2,
	RESTORING = 3
}

@export var collapse_delay: float = 1.2
@export var restore_delay: float = 2.5
@export var shake_intensity: float = 3.5
@export var one_shot: bool = false
@export var trigger_on_enemies: bool = false
@export var affects_player: bool = true

var state: PlatformState = PlatformState.IDLE
var _is_triggered: bool = false
var _is_fallen: bool = false
var _initial_pos: Vector2 = Vector2.ZERO
var _shake_tween: Tween = null
var _restore_timer: SceneTreeTimer = null

# Düğüm Referansları
var collision_shape: CollisionShape2D = null
var trigger_area: Area2D = null
var visual: Node2D = null


func _ready() -> void:
	add_to_group("platforms")
	add_to_group("collapsing_platforms")
	_initial_pos = position

	_setup_internal_nodes()


func _setup_internal_nodes() -> void:
	# Solid Collision Shape
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(160.0, 20.0)
		collision_shape.shape = rect
		collision_shape.one_way_collision = true
		add_child(collision_shape)

	collision_layer = 1
	collision_mask = 0

	# Trigger Area
	trigger_area = get_node_or_null("TriggerArea") as Area2D
	if not trigger_area:
		trigger_area = Area2D.new()
		trigger_area.name = "TriggerArea"
		trigger_area.position = Vector2(0.0, -12.0)
		var trigger_shape := CollisionShape2D.new()
		trigger_shape.name = "CollisionShape2D"
		var t_rect := RectangleShape2D.new()
		t_rect.size = Vector2(150.0, 10.0)
		trigger_shape.shape = t_rect
		trigger_area.add_child(trigger_shape)
		add_child(trigger_area)

	trigger_area.collision_layer = 0
	var mask: int = 0
	if affects_player:
		mask |= 1
	if trigger_on_enemies:
		mask |= 2
	trigger_area.collision_mask = mask if mask > 0 else 1

	if not trigger_area.body_entered.is_connected(_on_trigger_body_entered):
		trigger_area.body_entered.connect(_on_trigger_body_entered)

	# Visual
	visual = get_node_or_null("Visual") as Node2D
	if not visual:
		visual = Node2D.new()
		visual.name = "Visual"
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-80, -10), Vector2(80, -10), Vector2(80, 10), Vector2(-80, 10)
		])
		poly.color = Color(0.42, 0.38, 0.34, 1.0)
		visual.add_child(poly)
		add_child(visual)


func _on_trigger_body_entered(body: Node2D) -> void:
	if not _can_trigger(body):
		return
	trigger_collapse()


func _can_trigger(body: Node) -> bool:
	if not body or not is_instance_valid(body) or body.is_queued_for_deletion():
		return false

	var is_player: bool = body.is_in_group("player") or body.name.to_lower().contains("player")
	var is_enemy: bool = body.is_in_group("enemies") and not is_player

	if is_player and affects_player:
		return true
	if is_enemy and trigger_on_enemies:
		return true

	return false


## Platformun çöküş dizilimini başlatır
func trigger_collapse() -> void:
	if state != PlatformState.IDLE or _is_triggered or _is_fallen:
		return

	_is_triggered = true
	state = PlatformState.SHAKING
	shake_started.emit()

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("platform_crumble", -3.0)

	_start_collapse_sequence()


func _start_collapse_sequence() -> void:
	var total_time: float = maxf(0.2, collapse_delay)
	var shake_time: float = total_time - 0.05
	var step_duration: float = 0.05
	var steps: int = maxi(2, int(shake_time / (step_duration * 2.0)))
	var actual_step: float = shake_time / (float(steps) * 2.0)

	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	_shake_tween = create_tween()
	for i in range(steps):
		var progress: float = float(i) / float(steps)
		var shake_mag_x: float = lerpf(1.2, shake_intensity, progress)
		var shake_mag_y: float = lerpf(0.8, shake_intensity * 0.6, progress)
		_shake_tween.tween_property(visual, "position:x", randf_range(-shake_mag_x, shake_mag_x), actual_step)
		_shake_tween.tween_property(visual, "position:y", randf_range(-shake_mag_y, shake_mag_y), actual_step)

	_shake_tween.tween_property(visual, "position", Vector2.ZERO, 0.05)
	_shake_tween.tween_callback(_collapse)


func _collapse(animate: bool = true) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	state = PlatformState.COLLAPSED
	_is_fallen = true
	collapsed.emit()

	if collision_shape:
		collision_shape.disabled = true

	if not animate:
		if visual:
			visual.visible = false
			visual.position.y = 220.0
			visual.modulate.a = 0.0
		return

	var drop_tw := create_tween()
	drop_tw.tween_property(visual, "position:y", 220.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop_tw.parallel().tween_property(visual, "modulate:a", 0.0, 0.45)
	drop_tw.tween_callback(func():
		if not is_inside_tree():
			return
		if visual:
			visual.visible = false
		if not one_shot:
			_restore_timer = get_tree().create_timer(restore_delay)
			_restore_timer.timeout.connect(func():
				if is_inside_tree() and state == PlatformState.COLLAPSED:
					_restore()
			)
	)


func _restore(animate: bool = true) -> void:
	if not animate:
		force_restore()
		return

	state = PlatformState.RESTORING
	if visual:
		visual.position = Vector2.ZERO
		visual.modulate.a = 0.0
		visual.visible = true

		var restore_tw := create_tween()
		restore_tw.tween_property(visual, "modulate:a", 1.0, 0.35)
		restore_tw.tween_callback(func():
			if not is_inside_tree():
				return
			if collision_shape:
				collision_shape.disabled = false
			_is_triggered = false
			_is_fallen = false
			state = PlatformState.IDLE

			var audio_mgr = get_node_or_null("/root/AudioManager")
			if audio_mgr and audio_mgr.has_method("play_sfx"):
				audio_mgr.play_sfx("platform_restore", -4.0)

			restored.emit()
		)


## Platformu anında sağlam durumuna döndürür
func force_restore() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	state = PlatformState.IDLE
	_is_triggered = false
	_is_fallen = false

	if visual:
		visual.position = Vector2.ZERO
		visual.modulate.a = 1.0
		visual.visible = true

	if collision_shape:
		collision_shape.disabled = false

	restored.emit()
