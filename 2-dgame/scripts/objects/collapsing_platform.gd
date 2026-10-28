class_name CollapsingPlatform
extends StaticBody2D

## res://scripts/objects/collapsing_platform.gd
## Oyuncu üzerine bastığında sallanıp çöken ve belirli süre sonra yenilenen zindan platformu.

signal collapsed()
signal restored()

@export var collapse_delay: float = 1.6
@export var restore_delay: float = 3.0

var _is_triggered: bool = false
var _is_fallen: bool = false
var _initial_pos: Vector2 = Vector2.ZERO

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var trigger_area: Area2D = $TriggerArea
@onready var visual: Node2D = $Visual


func _ready() -> void:
	_initial_pos = position
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)


func _on_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		trigger_collapse()


func trigger_collapse() -> void:
	if _is_triggered or _is_fallen:
		return
	_is_triggered = true
	_start_collapse_sequence()


func _start_collapse_sequence() -> void:
	var total_time: float = maxf(0.2, collapse_delay)
	var shake_time: float = total_time - 0.05
	var step_duration: float = 0.05
	var steps: int = maxi(2, int(shake_time / (step_duration * 2.0)))
	var actual_step: float = shake_time / (float(steps) * 2.0)

	var tw: Tween = create_tween()
	for i in range(steps):
		var progress: float = float(i) / float(steps)
		var shake_mag_x: float = lerpf(1.5, 4.0, progress)
		var shake_mag_y: float = lerpf(1.0, 2.5, progress)
		tw.tween_property(visual, "position:x", randf_range(-shake_mag_x, shake_mag_x), actual_step)
		tw.tween_property(visual, "position:y", randf_range(-shake_mag_y, shake_mag_y), actual_step)
	tw.tween_property(visual, "position", Vector2.ZERO, 0.05)
	tw.tween_callback(_collapse)


func _collapse() -> void:
	_is_fallen = true
	collapsed.emit()

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	var drop_tw: Tween = create_tween()
	drop_tw.tween_property(visual, "position:y", 220.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop_tw.parallel().tween_property(visual, "modulate:a", 0.0, 0.45)
	drop_tw.tween_callback(func():
		visual.visible = false
		get_tree().create_timer(restore_delay).timeout.connect(_restore)
	)


func _restore() -> void:
	visual.position = Vector2.ZERO
	visual.modulate.a = 0.0
	visual.visible = true

	var restore_tw: Tween = create_tween()
	restore_tw.tween_property(visual, "modulate:a", 1.0, 0.4)
	restore_tw.tween_callback(func():
		if collision_shape:
			collision_shape.set_deferred("disabled", false)
		_is_triggered = false
		_is_fallen = false
		restored.emit()
	)
