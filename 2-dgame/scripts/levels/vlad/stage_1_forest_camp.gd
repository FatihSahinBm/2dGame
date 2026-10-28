class_name Stage1ForestCamp
extends Node2D

## res://scripts/levels/vlad/stage_1_forest_camp.gd
## 1. Harita: 1462 Târgovişte Gece Ormanı & Boyut Yırtığı Pususu
## - Zaman yırtığından ormana düşüş ve kılıcın madeni feryadı.
## - Pusuya düşen Osmanlı Öncü Kumandanı'nı yaratıklardan (2 İskelet + 1 Yarasa) kurtarma.
## - Sinematik 1.35x zoom ile kurtarma diyaloğu.
## - Kumandan ile birlikte ordugah sınırına varış ve 2. Harita'ya (Ordugah) otomatik geçiş.

@export var next_scene_path: String = "res://scenes/levels/vlad/stage_1_camp.tscn"

@onready var player: CharacterBody2D = $CombatPlayer
@onready var hud: CanvasLayer = $FantasyHUD
@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var commander: CharacterBody2D = get_node_or_null("AmbushZone/JanissaryCommander") as CharacterBody2D
@onready var ambush_enemies: Node2D = get_node_or_null("AmbushZone/Enemies") as Node2D
@onready var exit_gate: Area2D = $ExitGate
@onready var world_backdrop: WorldParallaxBackground = get_node_or_null("WorldBackdrop") as WorldParallaxBackground
@onready var dimensional_rift: DimensionalTimeRift = get_node_or_null("DimensionalTimeRift") as DimensionalTimeRift

const ORDERS_DROP_SCENE = preload("res://scenes/objects/commander_orders_drop.tscn")

var _ambush_cleared: bool = false
var _is_transitioning: bool = false
var _dialogue_played: bool = false
var _orders_spawned: bool = false


func _ready() -> void:
	# Vlad bölümünde karakter kılıç kuşanmış olarak başlar
	if player:
		if not player.has_sword and player.has_method("pickup_sword"):
			player.pickup_sword()
		elif not player.is_armed:
			player.is_armed = true
			if player.has_method("_emit_weapon_state"):
				player._emit_weapon_state()

	_setup_camera()
	_play_fade_in()
	_play_time_rift_intro()

	if player and hud:
		_setup_hud()

	if commander:
		if commander.has_signal("died"):
			commander.died.connect(_on_commander_died)

	if exit_gate:
		exit_gate.body_entered.connect(_on_exit_gate_entered)


func _setup_camera() -> void:
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.limit_left = 0
			cam.limit_right = 1600
			cam.limit_top = -140
			cam.limit_bottom = 630


func _play_time_rift_intro() -> void:
	if dimensional_rift and player:
		dimensional_rift.play_player_emerge_sequence(player)
		dimensional_rift.spawn_completed.connect(func():
			_show_sword_scrape_text()
		, CONNECT_ONE_SHOT)
	else:
		_show_sword_scrape_text()


func _show_sword_scrape_text() -> void:
	var label: Label = Label.new()
	label.text = "*Kılıç zemine sürtünerek tiz bir madeni feryat koparır...*"
	label.add_theme_color_override("font_color", Color(0.85, 0.25, 0.25, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.global_position = Vector2(160.0, 500.0)
	add_child(label)

	var tw2: Tween = label.create_tween()
	tw2.tween_property(label, "global_position:y", label.global_position.y - 25.0, 3.0)
	tw2.parallel().tween_property(label, "modulate:a", 0.0, 3.0)
	tw2.tween_callback(label.queue_free)


func _process(_delta: float) -> void:
	if not _ambush_cleared and ambush_enemies:
		var alive_count: int = 0
		for enemy in ambush_enemies.get_children():
			if enemy is Node2D and not ("is_dead" in enemy and enemy.is_dead):
				alive_count += 1
		if alive_count == 0:
			_ambush_cleared = true
			_on_ambush_cleared()

	# Kumandan oyuncuyu bekler; oyuncu sağ sınıra yaklaştığında otomatik geçiş
	if _ambush_cleared and player and not _is_transitioning:
		if player.global_position.x >= 1480.0:
			var game_state = get_node_or_null("/root/GameState") if is_inside_tree() else null
			if game_state and not game_state.is_commander_alive and not game_state.has_commander_orders:
				return
			_trigger_stage_transition()


func _on_ambush_cleared() -> void:
	var game_state = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if game_state and not game_state.is_commander_alive:
		return

	if commander and is_instance_valid(commander) and not commander._is_dead:
		if game_state:
			game_state.is_commander_alive = true
			game_state.is_commander_rescued = true
		if commander.has_method("mark_rescued"):
			commander.mark_rescued()

	# 1.35x Sinematik Zoom ile kurtarma diyaloğunu otomatik başlat
	if not _dialogue_played and dialogue_box:
		_dialogue_played = true
		dialogue_box.start_dialogue_from_data("commander_rescue", commander)
		dialogue_box.dialogue_completed.connect(func():
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial(
					"Ordugaha İlerle",
					"Kumandanla Birlikte İlerle",
					"Kumandan seni Fatih Sultan Mehmed'in ordugahına götürüyor. Sağ tarafa doğru ilerle."
				)
			if commander and "speed" in commander:
				commander.speed = 120.0
		, CONNECT_ONE_SHOT)


func _on_commander_died(death_pos: Vector2) -> void:
	var game_state = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if game_state:
		game_state.is_commander_alive = false
		game_state.is_commander_rescued = false

	_ambush_cleared = true

	if not _orders_spawned:
		_orders_spawned = true
		_spawn_commander_orders(death_pos)

	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"Kumandan Şehit Düştü!",
			"Fermanı Al ve İlerle",
			"Kumandan şehit düştü! Yere düşen fermanı alıp Fatih Sultan Mehmed'in ordugahına ulaşmalısın."
		)


func _spawn_commander_orders(pos: Vector2) -> void:
	var orders_node: Area2D = null
	if ORDERS_DROP_SCENE:
		orders_node = ORDERS_DROP_SCENE.instantiate() as Area2D
	if not orders_node:
		orders_node = CommanderOrdersDrop.new()

	orders_node.global_position = pos + Vector2(0.0, -12.0)
	if orders_node.has_signal("collected"):
		orders_node.collected.connect(_on_commander_orders_collected, CONNECT_ONE_SHOT)
	add_child(orders_node)


func _on_commander_orders_collected() -> void:
	var game_state = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if game_state:
		game_state.has_commander_orders = true

	if dialogue_box:
		dialogue_box.start_dialogue_from_data("commander_orders_note")
		dialogue_box.dialogue_completed.connect(func():
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial(
					"Ordugaha İlerle",
					"Fermanı Fatih'e Götür",
					"Şehit kumandanın fermanını aldın. Ormandan çıkıp Fatih Sultan Mehmed Han'ın ordugahına ilerle."
				)
		, CONNECT_ONE_SHOT)


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
		hud.set_tutorial(
			"1. Harita: Orman Pususu",
			"Osmanlı Birliğini Kurtar",
			"[A/D] Koş | [Space] Zıpla | [Sol Tık] Saldır. İleride pusuya düşen Osmanlı birliğini kurtar!"
		)


func _on_exit_gate_entered(body: Node2D) -> void:
	if body == player and not _is_transitioning:
		var game_state = get_node_or_null("/root/GameState") if is_inside_tree() else null
		if game_state and not game_state.is_commander_alive and not game_state.has_commander_orders:
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial("Önce Fermanı Al!", "Şehit Kumandan", "Yerdeki fermanı almadan ordugaha gidemezsin!")
			return
		_trigger_stage_transition()


func _trigger_stage_transition() -> void:
	_is_transitioning = true
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
	tw.tween_property(rect, "modulate:a", 1.0, 0.6)
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
