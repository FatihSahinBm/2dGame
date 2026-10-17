class_name FatihNPC
extends CharacterBody2D

## res://scripts/allies/fatih_npc.gd
## 1. Sahnedeki Osmanlı Başkomutanı Fatih Sultan Mehmet NPC'si.
## Oyuncu ile diyalog kurar, kuşatma emrini verir.

signal dialogue_started()
signal dialogue_finished()
signal siege_charge_ordered()

@export var character_name: String = "Fatih Sultan Mehmet"
@export var title: String = "Osmanlı Padişahı"

var _player_nearby: bool = false
var _dialogue_done: bool = false

@onready var visual: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var prompt_label: Label = $UI/PromptLabel


func _ready() -> void:
	_setup_player_collision_exception()
	if prompt_label:
		prompt_label.visible = false
	if anim_sprite and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")
	if visual:
		visual.scale.x = -absf(visual.scale.x)


func _setup_player_collision_exception() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if p is CollisionObject2D:
			add_collision_exception_with(p)
			p.add_collision_exception_with(self)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or _dialogue_done:
		return

	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		start_conversation()


func start_conversation() -> void:
	if _dialogue_done:
		return
	if prompt_label:
		prompt_label.visible = false

	dialogue_started.emit()

	# Sahnedeki DialogueBox'ı bul ve konuşmayı başlat
	var dialogue_box = get_tree().get_first_node_in_group("dialogue_box")
	if dialogue_box and dialogue_box.has_method("start_dialogue_from_data"):
		dialogue_box.start_dialogue_from_data("fatih_intro")
		if not dialogue_box.dialogue_completed.is_connected(_on_dialogue_completed):
			dialogue_box.dialogue_completed.connect(_on_dialogue_completed, CONNECT_ONE_SHOT)
	else:
		_on_dialogue_completed()


func _on_dialogue_completed() -> void:
	_dialogue_done = true
	dialogue_finished.emit()
	siege_charge_ordered.emit()

	# Fatih kılıcını çeker / görsel tepki
	var tw: Tween = create_tween()
	tw.tween_property(visual, "scale:x", 1.2, 0.2)
	tw.tween_property(visual, "scale:x", 1.0, 0.2)

	# Baş üstünde emir metni
	_spawn_command_shout("ORDUM! HÜCUM EDİN! EFLAK SURLARI YIKILACAK!")


func _spawn_command_shout(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 14)
	label.global_position = global_position + Vector2(-110.0, -70.0)

	var parent_scene: Node = get_parent()
	if parent_scene:
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 35.0, 2.5)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 2.5)
		tw.tween_callback(label.queue_free)


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _dialogue_done:
		_player_nearby = true
		if prompt_label:
			prompt_label.visible = true


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		if prompt_label:
			prompt_label.visible = false
