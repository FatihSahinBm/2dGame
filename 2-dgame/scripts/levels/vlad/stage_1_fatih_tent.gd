class_name Stage1FatihTent
extends Node2D

## res://scripts/levels/vlad/stage_1_fatih_tent.gd
## Otağ-ı Hümayun İçi (Fatih Sultan Mehmet'in Çadırı)
## - 16:9 zengin pixel-art iç mekan görseli (kilimler, şamdanlar, sefer haritası masası).
## - 1.35x sinematik zoom ve letterbox ile Fatih ile tarihi-felsefi yüzleşme diyaloğu.
## - Fatih'in kılıç çekerek 'Kuşatma başlasın!' emri vermesi ve 3. Harita'ya (Köprü Kuşatması) geçiş.

@export var next_scene_path: String = "res://scenes/levels/vlad/stage_1_bridge_assault.tscn"

@onready var player: CharacterBody2D = $CombatPlayer
@onready var hud: CanvasLayer = $FantasyHUD
@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var fatih_npc: CharacterBody2D = get_node_or_null("FatihNPC") as CharacterBody2D
@onready var commander: CharacterBody2D = get_node_or_null("JanissaryCommander") as CharacterBody2D

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

	var guards = get_node_or_null("Guards")
	if guards:
		for g in guards.get_children():
			var g_vis = g.get_node_or_null("Visual")
			if g_vis:
				g_vis.scale.x = -absf(g_vis.scale.x)

	var game_state = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if commander and is_instance_valid(commander):
		if game_state and not game_state.is_commander_alive:
			commander.queue_free()

	# Sahne açıldıktan kısa süre sonra Fatih ile sinematik diyaloğu otomatik başlat
	get_tree().create_timer(0.6).timeout.connect(_start_fatih_audience)


func _setup_camera() -> void:
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.limit_left = 0
			cam.limit_right = 1280
			cam.limit_top = 0
			cam.limit_bottom = 720


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
			"Otağ-ı Hümayun",
			"Hünkarın Huzuru",
			"Fatih Sultan Mehmed Han sefer haritası başında..."
		)


func _start_fatih_audience() -> void:
	if not dialogue_box:
		return

	if dialogue_box.has_signal("entry_started"):
		dialogue_box.entry_started.connect(_on_dialogue_entry_started)

	var game_state = get_node_or_null("/root/GameState") if is_inside_tree() else null
	var dialogue_key: String = "fatih_intro"
	if game_state and not game_state.is_commander_alive:
		dialogue_key = "fatih_commander_fallen"

	dialogue_box.start_dialogue_from_data(dialogue_key, fatih_npc)
	dialogue_box.dialogue_completed.connect(_on_audience_completed, CONNECT_ONE_SHOT)


func _on_dialogue_entry_started(entry: Dictionary) -> void:
	var speaker: String = entry.get("speaker", "")
	if fatih_npc and is_instance_valid(fatih_npc):
		if speaker == "Fatih Sultan Mehmet":
			var sprite = fatih_npc.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
			if sprite and sprite.sprite_frames:
				if sprite.sprite_frames.has_animation("draw_sword") and sprite.animation != "command" and sprite.animation != "draw_sword":
					sprite.play("draw_sword")
					var on_draw_finished: Callable = func():
						if fatih_npc and is_instance_valid(fatih_npc) and fatih_npc.has_method("play_command_animation"):
							fatih_npc.play_command_animation()
					if not sprite.animation_finished.is_connected(on_draw_finished):
						sprite.animation_finished.connect(on_draw_finished, CONNECT_ONE_SHOT)



func _on_audience_completed() -> void:
	# Fatih kılıcını çeker ve orduya kuşatma emri verir
	var game_state = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if game_state:
		game_state.fatih_audience_completed = true

	if fatih_npc and is_instance_valid(fatih_npc):
		var sprite = fatih_npc.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
		if sprite and sprite.sprite_frames.has_animation("command"):
			sprite.play("command")

	_show_shout_label("FATİH: 'YENİÇERİLERİM! KUŞATMA BAŞLASIN! BARİKATLARI YIKIN!'", Color(1.0, 0.85, 0.3, 1.0))

	# Mehter / taarruz havası ve 3. Harita'ya geçiş
	get_tree().create_timer(1.2).timeout.connect(_transition_to_bridge_assault)


func _show_shout_label(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 14)
	label.global_position = Vector2(260.0, 320.0)
	add_child(label)
	var tw: Tween = label.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.4)
	tw.tween_property(label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(label.queue_free)


func _transition_to_bridge_assault() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

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
