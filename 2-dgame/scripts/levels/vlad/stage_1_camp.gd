class_name Stage1Camp
extends Node2D

## res://scripts/levels/vlad/stage_1_camp.gd
## 2. Harita: Osmanlı Ordugah Meydanı (Vanguard Camp)
## - Ordugah çadırları, kamp ateşi, devriye yeniçeriler.
## - Kırık erzak arabasından alevli ok sadaklarını alıp Kemankeş'e teslim etme (1.35x zoom diyalog).
## - Otağ-ı Hümayun çadır kapısına adım atınca otomatik olarak Çadır İçi Sahnesi'ne geçiş.

@export var next_scene_path: String = "res://scenes/levels/vlad/stage_1_fatih_tent.tscn"

@onready var player: CharacterBody2D = $CombatPlayer
@onready var hud: CanvasLayer = $FantasyHUD
@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var kemankes: CharacterBody2D = get_node_or_null("Allies/KemankesArcher") as CharacterBody2D
@onready var tent_gate: Area2D = $TentEntranceArea
@onready var quiver_item: Area2D = get_node_or_null("Environment/BrokenCart/ArrowQuiverItem") as Area2D
@onready var camp_commander: CharacterBody2D = get_node_or_null("Allies/JanissaryCommander") as CharacterBody2D

var _has_arrow_quiver: bool = false
var _archer_quest_state: String = "NOT_STARTED" # "NOT_STARTED", "ACCEPTED", "DECLINED", "COMPLETED"
var _dialogue_in_progress: bool = false
var _is_transitioning: bool = false


func _ready() -> void:
	if player:
		if "has_sword" in player and not player.has_sword and player.has_method("pickup_sword"):
			player.pickup_sword()
		elif "is_armed" in player and not player.is_armed:
			player.is_armed = true
			if player.has_method("_emit_weapon_state"):
				player._emit_weapon_state()

	_setup_camera()
	_play_fade_in()

	if player and hud:
		_setup_hud()

	var game_state = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if camp_commander and is_instance_valid(camp_commander):
		if game_state and not game_state.is_commander_alive:
			camp_commander.queue_free()

	if quiver_item:
		if quiver_item.has_method("set_quest_active"):
			quiver_item.set_quest_active(false)
		if quiver_item.has_signal("collected"):
			quiver_item.collected.connect(_on_quiver_collected)

	if dialogue_box:
		if dialogue_box.has_signal("choice_selected"):
			dialogue_box.choice_selected.connect(_on_dialogue_choice_selected)
		if dialogue_box.has_signal("dialogue_started"):
			dialogue_box.dialogue_started.connect(func(): _dialogue_in_progress = true)
		if dialogue_box.has_signal("dialogue_completed"):
			dialogue_box.dialogue_completed.connect(func(): _dialogue_in_progress = false)

	if tent_gate:
		tent_gate.body_entered.connect(_on_tent_gate_entered)


func _setup_camera() -> void:
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.limit_left = -220
			cam.limit_right = 1400
			cam.limit_top = -140
			cam.limit_bottom = 630


func _setup_hud() -> void:
	if player.has_signal("weapon_state_changed"):
		player.weapon_state_changed.connect(func(has_w, is_a):
			if hud.has_method("update_weapon_slot"):
				hud.update_weapon_slot(has_w, is_a)
		)
	if "has_sword" in player and hud.has_method("update_weapon_slot"):
		var is_armed = player.is_armed if "is_armed" in player else player.has_sword
		hud.update_weapon_slot(player.has_sword, is_armed)
	if player.has_signal("player_damaged"):
		player.player_damaged.connect(func(hp, max_hp):
			if hud.has_method("update_health"):
				hud.update_health(hp, max_hp)
		)
	if hud.has_method("set_tutorial"):
		var game_state = get_node_or_null("/root/GameState") if is_inside_tree() else null
		if game_state and not game_state.is_commander_alive:
			hud.set_tutorial(
				"2. Harita: Osmanlı Ordugahı",
				"Fermanı Fatih'e Sun",
				"Şehit düşen kumandanın fermanını Fatih Sultan Mehmed Han'ın Otağı'na ulaştır."
			)
		else:
			hud.set_tutorial(
				"2. Harita: Osmanlı Ordugahı",
				"Otağ-ı Hümayun'a İlerle",
				"Ordugah meydanından sağdaki Fatih Sultan Mehmed Han'ın Otağı'na ilerle."
			)


func _physics_process(_delta: float) -> void:
	if _dialogue_in_progress or not kemankes or not player:
		return

	var dist: float = player.global_position.distance_to(kemankes.global_position)

	# 1. Henüz konuşulmadıysa ve oyuncu yaklaştıysa Kemankeş seslenir
	if _archer_quest_state == "NOT_STARTED" and dist < 120.0:
		_start_archer_callout()
	# 2. Sadaklar toplandıysa ve oyuncu teslim için döndüyse
	elif _has_arrow_quiver and _archer_quest_state == "ACCEPTED" and dist < 85.0:
		_deliver_quiver_to_archer()


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_in_progress or not kemankes or not player:
		return

	# Reddedildiyse ve oyuncu [E] basıp tekrar konuşmak isterse
	if _archer_quest_state == "DECLINED" and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		var dist: float = player.global_position.distance_to(kemankes.global_position)
		if dist < 80.0:
			get_viewport().set_input_as_handled()
			_start_archer_callout()


func _start_archer_callout() -> void:
	if not dialogue_box:
		return
	dialogue_box.start_dialogue_from_data("archer_sidequest_callout", kemankes)


func _on_dialogue_choice_selected(action: String) -> void:
	if action == "accept":
		_archer_quest_state = "ACCEPTED"
		var q_mgr = get_node_or_null("/root/QuestManager")
		if q_mgr and q_mgr.has_method("start_quest"):
			q_mgr.start_quest("archer_quivers")
		if quiver_item and quiver_item.has_method("set_quest_active"):
			quiver_item.set_quest_active(true)
		if dialogue_box and dialogue_box.has_method("start_dialogue_from_data"):
			dialogue_box.start_dialogue_from_data("archer_sidequest_accept", kemankes)
		if hud and hud.has_method("set_tutorial"):
			hud.set_tutorial(
				"Görev: Alevli Sadakları Bul",
				"Erzak Arabasına Dön",
				"Vadideki kırık erzak arabasından alevli ok sadaklarını topla."
			)
	elif action == "decline":
		_archer_quest_state = "DECLINED"
		if dialogue_box and dialogue_box.has_method("start_dialogue_from_data"):
			dialogue_box.start_dialogue_from_data("archer_sidequest_decline", kemankes)
		if hud and hud.has_method("set_tutorial"):
			hud.set_tutorial(
				"Otağ-ı Hümayun'a İlerle",
				"Fatih'in Çadırı",
				"Sağdaki Fatih Sultan Mehmed Han'ın Otağı'na ilerle. (Fikrin değişirse Kemankeş ile [E] konuş.)"
			)


func _on_quiver_collected() -> void:
	_has_arrow_quiver = true
	var q_mgr = get_node_or_null("/root/QuestManager")
	if q_mgr and q_mgr.has_method("advance_quest"):
		q_mgr.advance_quest("archer_quivers", "find_quiver")

	if hud and hud.has_method("set_quiver_visible"):
		hud.set_quiver_visible(true, 1)

	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"Sadaklar Alındı!",
			"Kemankeş'e Götür",
			"Alevli ok sadaklarını ordugahtaki Kemankeş Çavuşu'na teslim et."
		)


func _deliver_quiver_to_archer() -> void:
	_archer_quest_state = "COMPLETED"
	_has_arrow_quiver = false

	var q_mgr = get_node_or_null("/root/QuestManager")
	if q_mgr and q_mgr.has_method("advance_quest"):
		q_mgr.advance_quest("archer_quivers", "deliver_quiver")

	if hud and hud.has_method("set_quiver_visible"):
		hud.set_quiver_visible(false)

	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("unlock_ability"):
		game_state.unlock_ability("flaming_arrows")

	if dialogue_box and dialogue_box.has_method("start_dialogue_from_data"):
		dialogue_box.start_dialogue_from_data("archer_sidequest_complete", kemankes)
		dialogue_box.dialogue_completed.connect(func():
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial(
					"Okçu Desteği Sağlandı!",
					"Fatih'in Otağına Gir",
					"Kemankeş köprü hücumunda alevli ok yağdıracak! Sağdaki Otağ-ı Hümayun çadırına gir."
				)
		, CONNECT_ONE_SHOT)


func _on_tent_gate_entered(body: Node2D) -> void:
	if body == player and not _is_transitioning:
		_trigger_tent_transition()


func _trigger_tent_transition() -> void:
	_is_transitioning = true
	var q_mgr = get_node_or_null("/root/QuestManager")
	if q_mgr and q_mgr.has_method("advance_quest"):
		q_mgr.advance_quest("fatih_audience", "enter_tent")

	if player and "can_move" in player:
		player.can_move = false

	var fade_overlay: CanvasLayer = CanvasLayer.new()
	fade_overlay.layer = 100
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = Color.BLACK
	rect.modulate.a = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.add_child(rect)
	add_child(fade_overlay)

	var tw: Tween = create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, 0.5)
	tw.tween_callback(func():
		get_tree().change_scene_to_file(next_scene_path)
	)


func _play_fade_in() -> void:
	var fade_overlay: CanvasLayer = CanvasLayer.new()
	fade_overlay.layer = 100
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = Color.BLACK
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.add_child(rect)
	add_child(fade_overlay)
	var tw: Tween = create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, 0.5)
	tw.tween_callback(fade_overlay.queue_free)
