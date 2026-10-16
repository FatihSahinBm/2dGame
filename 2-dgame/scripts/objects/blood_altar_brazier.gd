class_name BloodAltarBrazier
extends Area2D

## res://scripts/objects/blood_altar_brazier.gd
## 2. Sahne Kan Sunağı Kapısı için 3 Noktalı Çevresel Bulmaca Mangalı.
## Oyuncu kılıç darbesi veya [E] ile mangalı yakar; 3'ü de yandığında taht odası kapısı açılır.

signal brazier_ignited()

@export var is_ignited: bool = false

@onready var fire_visual: CanvasItem = get_node_or_null("FireVisual") as CanvasItem
@onready var prompt: Label = get_node_or_null("PromptLabel") as Label


func _ready() -> void:
	add_to_group("braziers")
	add_to_group("damageable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if fire_visual:
		fire_visual.visible = is_ignited
	if prompt:
		prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if is_ignited or not prompt or not prompt.visible:
		return
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		ignite_brazier()


func take_damage(_amount: int, _attacker: Node2D = null) -> void:
	if not is_ignited:
		ignite_brazier()


func ignite_brazier() -> void:
	if is_ignited:
		return
	is_ignited = true
	if prompt:
		prompt.visible = false
	if fire_visual:
		fire_visual.visible = true
		var tw: Tween = create_tween()
		tw.tween_property(fire_visual, "scale:y", 1.4, 0.15)
		tw.tween_property(fire_visual, "scale:y", 1.0, 0.2)

	_spawn_ignite_label("🔥 Kan Mangalı Yandı!")
	brazier_ignited.emit()


func _spawn_ignite_label(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.35, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.global_position = global_position + Vector2(-45.0, -35.0)

	var parent_scene: Node = get_parent()
	if parent_scene:
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 25.0, 0.8)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
		tw.tween_callback(label.queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_ignited:
		if prompt:
			prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if prompt:
			prompt.visible = false
