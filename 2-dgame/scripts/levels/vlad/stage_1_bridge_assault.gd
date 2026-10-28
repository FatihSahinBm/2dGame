class_name Stage1BridgeAssault
extends Node2D

## res://scripts/levels/vlad/stage_1_bridge_assault.gd
## 3. Harita: Kazıklı Köprü & Barikat Kuşatması
## - 3 Barikat Hattı ve Dalga Kuşatması (Yeniçerilerle birlikte taarruz).
## - Kemankeş'in alevli ok desteği (Sadak yan görevi yapıldıysa otomatik bombardıman).
## - Kapı önünde Eflak Kan Şövalyesi mini-boss savaşı (1.35x zoom intro).
## - Kan Şövalyesi öldükten sonra yeniçerilerin koçbaşı vurmasıyla kapının parçalanması
##   ve Stage 2 (Târgovişte Mahzenleri) sahnesine geçiş.

@export var next_scene_path: String = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"

@onready var player: CharacterBody2D = $CombatPlayer
@onready var hud: CanvasLayer = $FantasyHUD
@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var blood_knight: CharacterBody2D = get_node_or_null("BossEncounter/BloodKnight") as CharacterBody2D
@onready var vanguard_allies: Node2D = get_node_or_null("VanguardAllies") as Node2D
@onready var exit_gate: Area2D = $ExitGate
@onready var portcullis_bars = get_node_or_null("ExitGate/PortcullisBars") as CanvasItem
@onready var world_backdrop: WorldParallaxBackground = get_node_or_null("WorldBackdrop") as WorldParallaxBackground
@onready var battering_ram_crew: BatteringRamCrew = get_node_or_null("BatteringRamCrew") as BatteringRamCrew

var _has_arrow_support: bool = false
var _knight_intro_done: bool = false
var _knight_defeated: bool = false
var _gate_breached: bool = false
var _is_transitioning: bool = false


func _ready() -> void:
	if player:
		if not player.has_sword and player.has_method("pickup_sword"):
			player.pickup_sword()
		elif not player.is_armed:
			player.is_armed = true
			if player.has_method("_emit_weapon_state"):
				player._emit_weapon_state()

	_setup_camera()
	_play_fade_in()

	if player and hud:
		_setup_hud()

	# Kemankeş alevli ok desteği kontrolü
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("has_ability") and game_state.has_ability("flaming_arrows"):
		_has_arrow_support = true
		_start_archer_bombardment()

	# Öncü kumandan hayatta kalma kontrolü
	var bridge_commander = get_node_or_null("VanguardAllies/Commander")
	if bridge_commander and is_instance_valid(bridge_commander):
		if game_state and not game_state.is_commander_alive:
			bridge_commander.queue_free()

	if blood_knight:
		blood_knight.died.connect(_on_blood_knight_died)

	if exit_gate:
		exit_gate.body_entered.connect(_on_exit_gate_entered)

	_start_vanguard_charge()


func _setup_camera() -> void:
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.limit_left = 0
			cam.limit_right = 2400
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
		var arrow_text = " (Alevli Ok Desteği Devrede!)" if _has_arrow_support else ""
		hud.set_tutorial(
			"3. Harita: Köprü Kuşatması",
			"Barikatları Parçala",
			"Yeniçerilerle birlikte kazıklı barikatları parçala ve kale kapısına hücum et!" + arrow_text
		)


func _start_vanguard_charge() -> void:
	if vanguard_allies:
		for child in vanguard_allies.get_children():
			if "speed" in child:
				child.speed = 150.0


func _physics_process(_delta: float) -> void:
	# Kan Şövalyesi karşılaşma tetikleyicisi
	if player and blood_knight and is_instance_valid(blood_knight) and not _knight_intro_done:
		if player.global_position.distance_to(blood_knight.global_position) < 260.0:
			_trigger_blood_knight_intro()


func _trigger_blood_knight_intro() -> void:
	_knight_intro_done = true
	if dialogue_box:
		dialogue_box.start_dialogue_from_data("blood_knight_intro", blood_knight)
		dialogue_box.dialogue_completed.connect(func():
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial(
					"Elit Muhafız!",
					"Kan Şövalyesini Yen",
					"Vlad Tepeş'in kale kapısını koruyan Kan Şövalyesini alt et!"
				)
		, CONNECT_ONE_SHOT)


func _start_archer_bombardment() -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = 2.2
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(func():
		if not is_inside_tree() or _is_transitioning:
			timer.stop()
			timer.queue_free()
			return

		var game_state = get_node_or_null("/root/GameState")
		if game_state and game_state.is_in_cinematic:
			return

		# Oyuncunun önündeki barikat veya düşmana hedefli alevli ok
		var target_node: Node2D = null
		var barricades = get_tree().get_nodes_in_group("barricades")
		for b in barricades:
			if b and is_instance_valid(b) and player and b.global_position.x > player.global_position.x - 50.0:
				target_node = b as Node2D
				break

		if not target_node:
			var enemies = get_tree().get_nodes_in_group("enemies")
			# Önce mini-boss OLMAYAN standart düşmanları hedefle
			for e in enemies:
				if e and is_instance_valid(e) and not ("is_dead" in e and e.is_dead) and not e.is_in_group("mini_boss") and player and e.global_position.x > player.global_position.x - 50.0:
					target_node = e as Node2D
					break

		if target_node and is_instance_valid(target_node) and target_node.has_method("take_damage"):
			target_node.take_damage(25)
			_spawn_burning_hit_vfx(target_node.global_position)
	)


func _spawn_burning_hit_vfx(pos: Vector2) -> void:
	var label: Label = Label.new()
	label.text = "🔥 -25 (Kemankeş Oku)"
	label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 11)
	label.global_position = pos + Vector2(-30.0, -45.0)
	add_child(label)
	var tw: Tween = label.create_tween()
	tw.tween_property(label, "global_position:y", label.global_position.y - 25.0, 0.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(label.queue_free)


func _on_blood_knight_died() -> void:
	_knight_defeated = true

	var game_state = get_node_or_null("/root/GameState") if is_inside_tree() else null
	var victory_key = "battering_ram_victory"
	if game_state and not game_state.is_commander_alive:
		victory_key = "battering_ram_victory_sergeant"

	# Koçbaşı zafer diyaloğu ve kapının parçalanması
	if dialogue_box:
		dialogue_box.start_dialogue_from_data(victory_key)
		dialogue_box.dialogue_completed.connect(func():
			_break_castle_gate()
		, CONNECT_ONE_SHOT)
	else:
		_break_castle_gate()


func _break_castle_gate() -> void:
	if battering_ram_crew and is_instance_valid(battering_ram_crew):
		battering_ram_crew.play_assault_sequence(exit_gate, player, dialogue_box)
		battering_ram_crew.sequence_completed.connect(func():
			_gate_breached = true
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial(
					"Kapı Parçalandı!",
					"Mahzenlere Adım At",
					"Yeniçeriler koçbaşıyla kapıyı paramparça etti! Târgovişte mahzenlerine girerek Vlad'ın izini sür."
				)
			if exit_gate and exit_gate.overlaps_body(player) and not _is_transitioning:
				_trigger_dungeon_transition()
		, CONNECT_ONE_SHOT)
	else:
		_gate_breached = true
		if portcullis_bars:
			var tw_gate: Tween = create_tween()
			tw_gate.tween_property(portcullis_bars, "position:y", portcullis_bars.position.y - 90.0, 0.7).set_trans(Tween.TRANS_QUAD)


func _on_exit_gate_entered(body: Node2D) -> void:
	if body == player and _gate_breached and not _is_transitioning:
		_trigger_dungeon_transition()


func _trigger_dungeon_transition() -> void:
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
	tw.tween_property(rect, "modulate:a", 1.0, 0.7)
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
