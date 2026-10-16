class_name ThroneBloodSigil
extends Area2D

## res://scripts/objects/throne_blood_sigil.gd
## 2. Arena Kan Salonu'nda Vlad'ın kan kalkanını besleyen mühür küresi.
## Oyuncu kılıç darbesiyle mührü parçalayabilir; ikisi de kırılınca kalkan çöker.

signal sigil_destroyed()

@export var max_health: int = 50
var current_health: int = 50
var _is_destroyed: bool = false

@onready var visual: CanvasItem = get_node_or_null("Visual") as CanvasItem


func _ready() -> void:
	add_to_group("blood_sigils")
	add_to_group("damageable")


func take_damage(amount: int, _attacker: Node2D = null) -> void:
	if _is_destroyed:
		return
	current_health -= amount
	if visual:
		var tw: Tween = create_tween()
		tw.tween_property(visual, "modulate", Color(2.5, 0.5, 0.5, 1.0), 0.08)
		tw.tween_property(visual, "modulate", Color.WHITE, 0.12)

	if current_health <= 0:
		_destroy()


func _destroy() -> void:
	_is_destroyed = true
	sigil_destroyed.emit()

	var label: Label = Label.new()
	label.text = "💥 Kan Mührü Parçalandı!"
	label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.3, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.global_position = global_position + Vector2(-60.0, -35.0)

	var parent_scene: Node = get_parent()
	if parent_scene:
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 25.0, 0.7)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
		tw.tween_callback(label.queue_free)

	queue_free()
