class_name DungeonChainLever
extends Area2D

## res://scripts/objects/dungeon_chain_lever.gd
## Zindan girişindeki zincirli kapı açma mekanizması.
## Oyuncu [E] veya vuruşla zinciri çeker; kapı parmaklıkları kalıcı açılır.

signal lever_activated()

@export var is_pulled: bool = false

@onready var visual: CanvasItem = get_node_or_null("Visual") as CanvasItem
@onready var prompt: Label = get_node_or_null("PromptLabel") as Label


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("damageable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if is_pulled or not prompt or not prompt.visible:
		return
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		activate_lever()


func take_damage(_amount: int, _attacker: Node2D = null) -> void:
	if not is_pulled:
		activate_lever()


func activate_lever() -> void:
	if is_pulled:
		return
	is_pulled = true
	if prompt:
		prompt.visible = false

	# Zincir çekilme animasyonu ve ses bildirimi
	if visual:
		var tw: Tween = create_tween()
		tw.tween_property(visual, "position:y", visual.position.y + 14.0, 0.25).set_trans(Tween.TRANS_BOUNCE)

	_spawn_lever_label("⛓️ Zincir Çekildi! (Dış Kapı Açıldı)")
	lever_activated.emit()


func _spawn_lever_label(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.global_position = global_position + Vector2(-60.0, -35.0)

	var parent_scene: Node = get_parent()
	if parent_scene:
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 25.0, 0.8)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
		tw.tween_callback(label.queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_pulled:
		if prompt:
			prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if prompt:
			prompt.visible = false
