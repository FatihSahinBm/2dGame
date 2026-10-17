class_name Stage2CastleDungeon
extends Node2D

## res://scripts/levels/vlad/stage_2_castle_dungeon.gd
## 2. Sahne: Târgovişte Kale Mahzenleri & Ölümcül Geçit
## - 5.1 Dış Kapı ve Zincir Odası (Kaldırılabilir kapı mekanizması)
## - 5.2 Zincirli Koridor ve Pusu Yarasaları
## - 5.3 Giyotin Galerisi ve Platforming
## - 5.4 Kazık Çukuru & Çöken Platformlar
## - 5.5 Kemik Arşivi (Parçalanmış Kalp rölyefi & kılıç titremesi)
## - 5.6 Nekromansör Mührü
## - 5.7 Kan Sunağı Kapısı (3 Mangallı Çevresel Bulmaca)
## - 5.8 Taht Odasına Yükseliş Checkpoint'i

@export var next_scene_path: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

@onready var player: CharacterBody2D = $CombatPlayer
@onready var hud: CanvasLayer = $FantasyHUD
@onready var dungeon_gate: Area2D = $BloodAltarGate
@onready var pit_hazard: Area2D = get_node_or_null("Environment/SpikePitHazard") as Area2D
@onready var chain_lever: Area2D = get_node_or_null("EntranceMechanism/ChainLever") as Area2D
@onready var outer_portcullis: ColorRect = get_node_or_null("EntranceMechanism/OuterPortcullis") as ColorRect
@onready var outer_gate_col: CollisionShape2D = get_node_or_null("EntranceMechanism/OuterGateStatic/CollisionShape2D") as CollisionShape2D
@onready var bone_mural_area: Area2D = get_node_or_null("Environment/BoneArchiveMural") as Area2D
@onready var world_backdrop: WorldParallaxBackground = get_node_or_null("WorldBackdrop") as WorldParallaxBackground

const TEX_STAGE2_CHAIN = preload("res://assets/backgrounds/stage_2_zone_1_chain_room.png")
const TEX_STAGE2_GUILLOTINE = preload("res://assets/backgrounds/stage_2_zone_2_guillotine.png")
const TEX_STAGE2_BONE = preload("res://assets/backgrounds/stage_2_zone_3_bone_archive.png")
const TEX_STAGE2_ALTAR = preload("res://assets/backgrounds/stage_2_zone_4_blood_altar.png")
var _current_bg_zone: int = 1

var _is_transitioning: bool = false
var _braziers_lit: int = 0
var _gate_unlocked: bool = false
var _mural_reaction_done: bool = false
var _pit_hazard_triggered: bool = false


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
	if player and hud:
		_setup_hud()

	if dungeon_gate:
		dungeon_gate.body_entered.connect(_on_dungeon_gate_entered)

	if pit_hazard:
		pit_hazard.body_entered.connect(_on_pit_hazard_entered)

	if chain_lever and chain_lever.has_signal("lever_activated"):
		chain_lever.lever_activated.connect(_on_outer_lever_activated)

	if bone_mural_area:
		bone_mural_area.body_entered.connect(_on_bone_mural_entered)

	_setup_braziers()


func _setup_camera() -> void:
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.limit_left = 0
			cam.limit_right = 2300
			cam.limit_top = -140
			cam.limit_bottom = 630


func _setup_braziers() -> void:
	var braziers: Array[Node] = get_tree().get_nodes_in_group("braziers")
	for b in braziers:
		if b.has_signal("brazier_ignited"):
			b.brazier_ignited.connect(_on_brazier_ignited)


func _on_outer_lever_activated() -> void:
	if outer_portcullis:
		var tw: Tween = create_tween()
		tw.tween_property(outer_portcullis, "position:y", outer_portcullis.position.y - 70.0, 0.6).set_trans(Tween.TRANS_QUAD)
	if outer_gate_col:
		outer_gate_col.set_deferred("disabled", true)

	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial("Dış Kapı Açıldı", "Zindana İlerle", "Karanlık mahzenlere adım at. Pusu kuran yarasalara ve giyotinlere dikkat et!")


func _on_bone_mural_entered(body: Node2D) -> void:
	if _mural_reaction_done or not body.is_in_group("player"):
		return
	_mural_reaction_done = true

	# Kılıç taş duvardaki parçalanmış kalp kabartmasını sezer
	if player and "visual_node" in player and player.visual_node:
		var tw: Tween = create_tween()
		tw.tween_property(player.visual_node, "modulate", Color(0.4, 0.2, 0.8, 1.0), 0.15)
		tw.tween_property(player.visual_node, "modulate", Color.WHITE, 0.3)

	var label: Label = Label.new()
	label.text = "*Duvardaki kadim taş kabartma... Parçalanmış bir kalp... Kılıç derinden titriyor...*"
	label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.global_position = bone_mural_area.global_position + Vector2(-150.0, -45.0)
	add_child(label)

	var tw2: Tween = label.create_tween()
	tw2.tween_property(label, "global_position:y", label.global_position.y - 25.0, 3.2)
	tw2.parallel().tween_property(label, "modulate:a", 0.0, 3.2)
	tw2.tween_callback(label.queue_free)


func _on_brazier_ignited() -> void:
	_braziers_lit += 1
	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"Kan Sunağı Mührü (%d/3)" % _braziers_lit,
			"Mangalları Yak",
			"3 kan mangalını yakarak taht odasına açılan mühürlü kapıyı serbest bırak."
		)

	if _braziers_lit >= 3 and not _gate_unlocked:
		_unlock_throne_gate()


func _unlock_throne_gate() -> void:
	_gate_unlocked = true
	var gate_bars = get_node_or_null("BloodAltarGate/PortcullisBars")
	if gate_bars:
		var tw: Tween = create_tween()
		tw.tween_property(gate_bars, "position:y", gate_bars.position.y - 80.0, 0.8).set_trans(Tween.TRANS_QUAD)

	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"Mühür Kırıldı!",
			"Taht Odasına Yüksel",
			"Kan Sunağı Kapısı açıldı! Vlad Tepeş'in taht salonuna adım at."
		)


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
			"2. Sahne: Târgovişte Mahzenleri",
			"Giriş Kapısını Aç [E]",
			"Demir zinciri çekerek mahzen kapısını arala."
		)


func _on_pit_hazard_entered(body: Node2D) -> void:
	if _pit_hazard_triggered or body != player:
		return
	if "is_dead" in player and player.is_dead:
		return

	_pit_hazard_triggered = true
	if player.has_method("take_damage"):
		var fatal_damage: int = player.current_health if "current_health" in player else 100
		var hazard_pos: Vector2 = pit_hazard.global_position if pit_hazard else Vector2.INF
		player.take_damage(fatal_damage, hazard_pos)
	elif player.has_method("die"):
		player.die()


func _physics_process(_delta: float) -> void:
	if player and world_backdrop:
		var px: float = player.global_position.x
		if px < 550.0 and _current_bg_zone != 1:
			_current_bg_zone = 1
			world_backdrop.set_background_texture(TEX_STAGE2_CHAIN, Color(0.04, 0.02, 0.05, 0.22))
		elif px >= 550.0 and px < 1250.0 and _current_bg_zone != 2:
			_current_bg_zone = 2
			world_backdrop.set_background_texture(TEX_STAGE2_GUILLOTINE, Color(0.06, 0.01, 0.03, 0.20))
		elif px >= 1250.0 and px < 1700.0 and _current_bg_zone != 3:
			_current_bg_zone = 3
			world_backdrop.set_background_texture(TEX_STAGE2_BONE, Color(0.02, 0.04, 0.08, 0.18))
		elif px >= 1700.0 and _current_bg_zone != 4:
			_current_bg_zone = 4
			world_backdrop.set_background_texture(TEX_STAGE2_ALTAR, Color(0.18, 0.02, 0.04, 0.22))


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


func _on_dungeon_gate_entered(body: Node2D) -> void:
	if not _gate_unlocked:
		return
	if body == player and not _is_transitioning:
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
