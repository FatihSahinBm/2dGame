class_name FutureLevelCore
extends Node2D

## res://scripts/levels/future/future_level_core.gd
## Bölüm 5 seviye çekirdeği (Epic 2D-158): kurulum, kamera sınırları, kararma geçişleri, HUD,
## görev ilerletme, hikâye oynatma ve sonraki sahneye geçiş. Eşya kısayolları, kılıç durumu ve
## ahlaki seçim yönlendirmesi FutureLevelBase (future_level_base.gd) içindedir.

signal level_exit_requested(next_path: String)

const LevelStory = preload("res://scripts/components/level_story.gd")
const FutureFx = preload("res://scripts/effects/future_fx.gd")
const BossBarScript = preload("res://scripts/ui/egypt_boss_bar.gd")
const CHAPTER_PATH: String = "res://data/story/chapter_5_future.json"
const MAIN_QUEST: String = "future_processor_heart"


@export var next_scene_path: String = ""
@export var camera_limits: Rect2i = Rect2i(0, -140, 2400, 770)
@export var tutorial_keys: PackedStringArray = PackedStringArray()

@onready var player: CharacterBody2D = get_node_or_null("CombatPlayer") as CharacterBody2D
@onready var hud: CanvasLayer = get_node_or_null("FantasyHUD") as CanvasLayer
@onready var dialogue_box: CanvasLayer = get_node_or_null("DialogueBox") as CanvasLayer
@onready var exit_gate: Area2D = get_node_or_null("ExitGate") as Area2D

var is_transitioning: bool = false
var _exit_story_played: bool = false


func _ready() -> void:
	var gs: Node = game_state()
	if gs and "current_stage_path" in gs and not scene_file_path.is_empty():
		gs.current_stage_path = scene_file_path
	_arm_player()
	_apply_camera_limits()
	_play_fade(true)
	_setup_hud()
	_core_ready()
	if exit_gate:
		exit_gate.body_entered.connect(_on_exit_gate_body_entered)
	ensure_quest_started(MAIN_QUEST, true)
	_level_ready()


## Taban sınıf kancası (kılıç durumu, seçim bağlantısı)
func _core_ready() -> void:
	pass


func _level_ready() -> void:
	pass


func can_exit() -> bool:
	return true


func _on_exit_blocked() -> void:
	pass


# ---------------------------------------------------------------------------
# Autoload erişimi (yolla; test harness'lerinde de çalışır)
# ---------------------------------------------------------------------------
func game_state() -> Node:
	return get_node_or_null("/root/GameState") if is_inside_tree() else null


func quest_manager() -> Node:
	return get_node_or_null("/root/QuestManager") if is_inside_tree() else null


func audio() -> Node:
	return get_node_or_null("/root/AudioManager") if is_inside_tree() else null


func ensure_quest_started(quest_id: String, track: bool = false) -> void:
	var q_mgr: Node = quest_manager()
	if q_mgr == null or not q_mgr.has_method("start_quest"):
		return
	if not q_mgr.is_quest_active(quest_id) and not q_mgr.is_quest_completed(quest_id):
		var q: Dictionary = q_mgr.get_quest(quest_id)
		if not q.is_empty() and str(q.get("status", "")) != "failed":
			q_mgr.start_quest(quest_id)
	if track and q_mgr.is_quest_active(quest_id):
		q_mgr.set_tracked_quest(quest_id)


func advance_quest(stage_id: String, quest_id: String = MAIN_QUEST) -> void:
	var q_mgr: Node = quest_manager()
	if q_mgr and q_mgr.has_method("advance_quest"):
		q_mgr.advance_quest(quest_id, stage_id)


func fail_quest(quest_id: String) -> void:
	var q_mgr: Node = quest_manager()
	if q_mgr and q_mgr.has_method("fail_quest") and q_mgr.is_quest_active(quest_id):
		q_mgr.fail_quest(quest_id)


func play_sfx(key: String, pos: Vector2 = Vector2.INF, volume_db: float = 0.0) -> void:
	FutureFx.sfx(self, key, pos, volume_db)


# ---------------------------------------------------------------------------
# Hikâye, HUD, boss barı
# ---------------------------------------------------------------------------
func play_story(keys: Array[String], focus: Node2D = null) -> bool:
	return LevelStory.play(self, keys, focus)


func play_story_once(keys: Array[String], delay: float = 0.6, focus: Node2D = null) -> void:
	LevelStory.play_delayed(self, keys, delay, focus)


func queue_story(key: String, delay: float = 0.15) -> void:
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if is_inside_tree():
			play_story([key] as Array[String])
	)


func set_tutorial_keys(keys: PackedStringArray) -> void:
	if hud and hud.has_method("set_tutorial") and keys.size() >= 3:
		hud.set_tutorial(tr(keys[0]), tr(keys[1]), tr(keys[2]))


func make_boss_bar(title_key: String, max_hp: int) -> EgyptBossBar:
	var bar: EgyptBossBar = BossBarScript.new() as EgyptBossBar
	add_child(bar)
	bar.setup(title_key, max_hp)
	# HUD'un "Hedef Tamamlandı" bandı ekranın üst ortasında; çubuk onun altına alınır (UI çakışma denetimi)
	var box: Control = bar.get_child(0) as Control if bar.get_child_count() > 0 else null
	if box:
		box.offset_top = 88.0
		box.offset_bottom = 132.0
	return bar


func float_text(text: String, world_pos: Vector2, color: Color = Color(0.5, 0.9, 1.0)) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.z_index = 50
	add_child(label)
	label.global_position = world_pos + Vector2(-70.0, -40.0)
	var tw: Tween = label.create_tween()
	tw.tween_property(label, "global_position:y", label.global_position.y - 28.0, 2.2)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 2.2)
	tw.tween_callback(label.queue_free)


# ---------------------------------------------------------------------------
# Kurulum ve geçişler
# ---------------------------------------------------------------------------
func _arm_player() -> void:
	if not player:
		return
	if "has_sword" in player and not player.has_sword and player.has_method("pickup_sword"):
		player.pickup_sword()
	elif "is_armed" in player and not player.is_armed:
		player.is_armed = true
		if player.has_method("_emit_weapon_state"):
			player._emit_weapon_state()


func _apply_camera_limits() -> void:
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D if player else null
	if cam:
		cam.limit_left = camera_limits.position.x
		cam.limit_top = camera_limits.position.y
		cam.limit_right = camera_limits.position.x + camera_limits.size.x
		cam.limit_bottom = camera_limits.position.y + camera_limits.size.y


func _setup_hud() -> void:
	if not player or not hud:
		return
	if player.has_signal("weapon_state_changed") and hud.has_method("update_weapon_slot"):
		player.weapon_state_changed.connect(func(has_w: bool, is_a: bool) -> void: hud.update_weapon_slot(has_w, is_a))
		if "has_sword" in player:
			hud.update_weapon_slot(player.has_sword, player.is_armed if "is_armed" in player else player.has_sword)
	if player.has_signal("player_damaged") and hud.has_method("update_health"):
		player.player_damaged.connect(func(hp: int, max_hp: int) -> void: hud.update_health(hp, max_hp))
	set_tutorial_keys(tutorial_keys)


func _on_exit_gate_body_entered(body: Node2D) -> void:
	if body != player or is_transitioning:
		return
	if not can_exit():
		_on_exit_blocked()
		return
	transition_to_next()


func get_exit_story_key() -> String:
	return ""


func _on_exit_started() -> void:
	pass


func transition_to_next(path: String = "") -> void:
	if is_transitioning:
		return
	if not _exit_story_played:
		_exit_story_played = true
		_on_exit_started()
		var key: String = get_exit_story_key()
		if not key.is_empty() and dialogue_box and play_story([key] as Array[String], player):
			dialogue_box.dialogue_completed.connect(_do_transition.bind(path), CONNECT_ONE_SHOT)
			return
	_do_transition(path)


func _do_transition(path: String) -> void:
	if is_transitioning:
		return
	var target: String = path if not path.is_empty() else next_scene_path
	if target.is_empty():
		return
	is_transitioning = true
	if player and "can_move" in player:
		player.can_move = false
	level_exit_requested.emit(target)
	var rect: ColorRect = _play_fade(false)
	var tw: Tween = create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, 0.6)
	tw.tween_callback(func() -> void:
		if is_inside_tree():
			get_tree().change_scene_to_file(target)
	)


func _play_fade(fade_in: bool) -> ColorRect:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = Color.BLACK
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 1.0 if fade_in else 0.0
	layer.add_child(rect)
	add_child(layer)
	if fade_in:
		var tw: Tween = create_tween()
		tw.tween_property(rect, "modulate:a", 0.0, 0.5)
		tw.tween_callback(layer.queue_free)
	return rect
