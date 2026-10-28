class_name AncientHeartRelief
extends Area2D

## res://scripts/objects/ancient_heart_relief.gd
## Târgovişte Mahzenleri - Kemik Arşivi'ndeki Kadim Kalp Kabartması.
## Oyuncu [E] ile incelediğinde taş çatlakları morumsu bir yankıyla parlar,
## kılıç istemsizce titreyerek dilsiz bir madeni tepki verir ve
## çevresel anlatım diyaloğu ("ancient_heart_relief") tetiklenir.

signal relief_examined()

@export var is_examined: bool = false

@onready var stone_slab: Sprite2D = get_node_or_null("StoneSlab") as Sprite2D
@onready var glow_overlay: Sprite2D = get_node_or_null("GlowOverlay") as Sprite2D
@onready var prompt_label: Label = get_node_or_null("PromptLabel") as Label
@onready var dust_particles: CPUParticles2D = get_node_or_null("DustParticles") as CPUParticles2D

var _player_nearby: bool = false
var _player_ref: CharacterBody2D = null
var _glow_tween: Tween = null


func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 4
	collision_mask = 1

	if prompt_label:
		prompt_label.visible = false

	if glow_overlay:
		glow_overlay.modulate.a = 0.0

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if is_examined or not _player_nearby:
		return

	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		examine_relief()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") and not body.name == "CombatPlayer":
		return

	_player_ref = body as CharacterBody2D
	_player_nearby = true

	if not is_examined and prompt_label:
		prompt_label.visible = true
		prompt_label.modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.tween_property(prompt_label, "modulate:a", 1.0, 0.2)


func _on_body_exited(body: Node2D) -> void:
	if body == _player_ref:
		_player_nearby = false
		if prompt_label:
			prompt_label.visible = false


## Kabartmayı inceler: çatlaklar parlar, kılıç titrer ve anlatım diyaloğu açılır
func examine_relief() -> void:
	if is_examined:
		return
	is_examined = true

	if prompt_label:
		prompt_label.visible = false

	# 1. Taş çatlaklarının morumsu yankıyla parıldaması
	_trigger_relief_glow()

	# 2. Kılıcın dilsiz istemsiz tepkisi (micro-jitter ve ametist ışıltı)
	_trigger_sword_reaction()

	# 3. Kameranın çok hafif odaklanması / titreşimi
	_trigger_camera_pulse()

	# 4. Çevresel Anlatım Diyaloğunu Başlat
	_trigger_environmental_dialogue()


func _trigger_relief_glow() -> void:
	if not glow_overlay:
		return

	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()

	_glow_tween = create_tween()
	# Parlak morumsu alevlenme
	_glow_tween.tween_property(glow_overlay, "modulate:a", 0.9, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_glow_tween.tween_property(glow_overlay, "modulate:a", 0.35, 0.5).set_trans(Tween.TRANS_SINE)


func _trigger_sword_reaction() -> void:
	if not _player_ref or not is_instance_valid(_player_ref):
		return

	var visual: Node2D = _player_ref.get_node_or_null("Visual") as Node2D
	if not visual:
		return

	# Kılıcın eldeki hafif istemsiz titremesi (micro-jitter)
	var tw_sword: Tween = create_tween()
	var orig_x: float = visual.position.x
	tw_sword.tween_property(visual, "position:x", orig_x + 3.0, 0.04)
	tw_sword.tween_property(visual, "position:x", orig_x - 3.0, 0.04)
	tw_sword.tween_property(visual, "position:x", orig_x + 1.5, 0.04)
	tw_sword.tween_property(visual, "position:x", orig_x, 0.04)

	# Soğuk ametist/mor ışık dalgası (boğuk yankı hissi)
	var tw_col: Tween = create_tween()
	tw_col.tween_property(visual, "modulate", Color(0.55, 0.28, 0.78, 1.0), 0.12)
	tw_col.tween_property(visual, "modulate", Color.WHITE, 0.32)


func _trigger_camera_pulse() -> void:
	if not _player_ref:
		return
	var cam: Camera2D = _player_ref.get_node_or_null("Camera2D") as Camera2D
	if not cam:
		return
	var orig_offset: Vector2 = cam.offset
	var tw: Tween = create_tween()
	tw.tween_property(cam, "offset", orig_offset + Vector2(randf_range(-2.0, 2.0), randf_range(-1.5, 1.5)), 0.05)
	tw.tween_property(cam, "offset", orig_offset, 0.08)


func _trigger_environmental_dialogue() -> void:
	var parent_scene: Node = get_parent()
	while parent_scene and not (parent_scene is Stage2CastleDungeon or parent_scene.has_node("DialogueBox")):
		parent_scene = parent_scene.get_parent()

	var dialogue_box = null
	if parent_scene:
		dialogue_box = parent_scene.get_node_or_null("DialogueBox")
	if not dialogue_box:
		dialogue_box = get_tree().get_first_node_in_group("dialogue_box")

	if dialogue_box and dialogue_box.has_method("start_dialogue_from_data"):
		dialogue_box.start_dialogue_from_data("ancient_heart_relief", self)
		dialogue_box.dialogue_completed.connect(func():
			_finish_examination()
		, CONNECT_ONE_SHOT)
	else:
		_finish_examination()


func _finish_examination() -> void:
	if glow_overlay:
		var tw: Tween = create_tween()
		tw.tween_property(glow_overlay, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)

	relief_examined.emit()
