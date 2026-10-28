class_name CommanderOrdersDrop
extends Area2D

## res://scripts/objects/commander_orders_drop.gd
## Kumandan şehit düştüğünde yere düşen "Öncü Kumandanın Fermanı".
## Görevin yumuşak kilitlenmesini (soft-lock) önler; oyuncunun fermanla Fatih'e gitmesini sağlar.

signal collected()

var _is_collected: bool = false
var _player_nearby: bool = false
var _visual_node: Node2D = null
var _prompt_node: Control = null
var _bobbing_tween: Tween = null


func _ready() -> void:
	add_to_group("collectibles")
	collision_layer = 4
	collision_mask = 1

	_setup_components()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_start_bobbing()


func _setup_components() -> void:
	if not get_node_or_null("CollisionShape2D"):
		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 32.0
		col.shape = shape
		add_child(col)

	_visual_node = get_node_or_null("Visual") as Node2D
	if not _visual_node:
		_visual_node = Node2D.new()
		_visual_node.name = "Visual"
		add_child(_visual_node)

		var icon: Label = Label.new()
		icon.name = "IconLabel"
		icon.text = "📜"
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.position = Vector2(-16.0, -20.0)
		icon.add_theme_font_size_override("font_size", 22)
		_visual_node.add_child(icon)

		var prompt: Label = Label.new()
		prompt.name = "PromptLabel"
		prompt.text = "Ferman [E] / Temas"
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
		prompt.add_theme_color_override("font_outline_color", Color.BLACK)
		prompt.add_theme_constant_override("outline_size", 4)
		prompt.add_theme_font_size_override("font_size", 11)
		prompt.position = Vector2(-60.0, -42.0)
		_visual_node.add_child(prompt)


func _start_bobbing() -> void:
	if not _visual_node:
		return
	if _bobbing_tween and _bobbing_tween.is_valid():
		_bobbing_tween.kill()
	_bobbing_tween = create_tween().set_loops()
	_bobbing_tween.tween_property(_visual_node, "position:y", -6.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bobbing_tween.tween_property(_visual_node, "position:y", 2.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return
	if body.is_in_group("player"):
		_player_nearby = true
		_collect()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false


func _unhandled_input(event: InputEvent) -> void:
	if _is_collected or not _player_nearby:
		return
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		get_viewport().set_input_as_handled()
		_collect()


func _collect() -> void:
	if _is_collected:
		return
	_is_collected = true

	var game_state = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if game_state:
		game_state.has_commander_orders = true

	collected.emit()
	_spawn_pickup_feedback()
	queue_free()


func _spawn_pickup_feedback() -> void:
	var label: Label = Label.new()
	label.text = "📜 Öncü Kumandanın Fermanı Alındı!"
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 13)
	label.global_position = global_position + Vector2(-90.0, -35.0)

	var parent_scene: Node = get_parent()
	if parent_scene:
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 25.0, 0.8)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
		tw.tween_callback(label.queue_free)
