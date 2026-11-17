class_name Ww2LevelBase
extends Node2D

## res://scripts/levels/ww2/ww2_level_base.gd
## Bölüm 4 (2. Dünya Savaşı) seviyelerinin ortak tabanı — Epic 2D-144.
## Kılıç kuşanma, kamera sınırları, kararma geçişleri, HUD bağlama, görev ilerletme,
## hikâye oynatma, eşya kısayolları ve sonraki sahneye geçiş burada; seviyeye özgü akış
## alt sınıflardadır. Metinler data/story/chapter_4_ww2.json ve data/translations altındadır.
## Eşya kısayolları (G/B dolu): [T] El Bombası, [H] Sargı Bezi, [V] Gaz Filtresi.

signal level_exit_requested(next_path: String)

const LevelStory = preload("res://scripts/components/level_story.gd")
const ChapterState = preload("res://scripts/components/ww2_chapter_state.gd")
const Inventory = preload("res://scripts/components/ww2_inventory.gd")
const VowAura = preload("res://scripts/effects/sword_vow_aura_vfx.gd")
const SealLeakVfx = preload("res://scripts/effects/sword_seal_leak_vfx.gd")
const CHAPTER_PATH: String = "res://data/story/chapter_4_ww2.json"
const MAIN_QUEST: String = "ww2_iron_heart"
const PREV_SEAL_ABILITY: String = "sun_seal_fracture"
const VOW_ABILITY: String = "vengeance_vow_aura"
const ITEM_KEYS: Dictionary = { KEY_T: "stick_grenade", KEY_H: "field_bandage", KEY_V: "gas_filter" }

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
	refresh_sword_state()
	if exit_gate:
		exit_gate.body_entered.connect(_on_exit_gate_body_entered)
	ensure_quest_started(MAIN_QUEST, true)
	_level_ready()


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
		if str(q.get("status", "")) != "failed":
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
	var am: Node = audio()
	if am == null:
		return
	if pos != Vector2.INF and am.has_method("play_sound_2d"):
		am.play_sound_2d(key, pos, null, volume_db, 1200.0)
	elif am.has_method("play_sfx"):
		am.play_sfx(key, volume_db)


# ---------------------------------------------------------------------------
# Hikâye ve HUD
# ---------------------------------------------------------------------------
func play_story(keys: Array[String], focus: Node2D = null) -> bool:
	return LevelStory.play(self, keys, focus)


func play_story_once(keys: Array[String], delay: float = 0.6, focus: Node2D = null) -> void:
	LevelStory.play_delayed(self, keys, delay, focus)


## Seçim diyaloğu kapanırken yeni diyalog açmak için kısa bekleme
func queue_story(key: String, delay: float = 0.15) -> void:
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if is_inside_tree():
			play_story([key] as Array[String])
	)


func set_tutorial_keys(keys: PackedStringArray) -> void:
	if hud and hud.has_method("set_tutorial") and keys.size() >= 3:
		hud.set_tutorial(tr(keys[0]), tr(keys[1]), tr(keys[2]))


func float_text(text: String, world_pos: Vector2, color: Color = Color(1.0, 0.82, 0.4)) -> void:
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


## Ruhsuzlaşan kılıcın çığlığı: SFX + rastgele çığlık metni + intikamcı fısıltı
func sword_scream() -> void:
	if not player:
		return
	play_sfx("steel_scream", player.global_position, -4.0)
	play_sfx("mage_vengeance_whisper", player.global_position, -10.0)
	var lines: Array = LevelStory.StoryLoader.get_dialogue_sequence("ww2_sword_scream_texts")
	if not lines.is_empty():
		var pick: Variant = lines.pick_random()
		var text: String = str((pick as Dictionary).get("text", "")) if pick is Dictionary else str(pick)
		float_text(text, player.global_position, Color(0.95, 0.35, 0.4))


## Önceki bölümlerden gelen kılıç durumu: mühür sızıntısı ve (Bölüm 4 sonrası) intikam aurası
func refresh_sword_state() -> void:
	var gs: Node = game_state()
	if not player or gs == null or not gs.has_method("has_ability"):
		return
	if gs.has_ability(VOW_ABILITY):
		VowAura.attach_to(player, hud)
	elif gs.has_ability(PREV_SEAL_ABILITY):
		SealLeakVfx.attach_to(player, hud)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or not player or is_transitioning:
		return
	var item_id: String = str(ITEM_KEYS.get((event as InputEventKey).keycode, ""))
	if item_id.is_empty():
		return
	get_viewport().set_input_as_handled()
	use_item(item_id)


func use_item(item_id: String) -> bool:
	var ok: bool = Inventory.use(self, item_id, player)
	if player:
		var def: Dictionary = Inventory.get_definition(item_id)
		var title: String = str(def.get("title_en" if TranslationServer.get_locale().begins_with("en") else "title", item_id))
		float_text(("%s (%d)" % [title, Inventory.count(self, item_id)]) if ok else tr("WW2_FLOAT_NO_ITEM") % title, player.global_position,
			Color(0.6, 1.0, 0.6) if ok else Color(0.8, 0.8, 0.8))
	return ok


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
	if not player:
		return
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
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


## Çıkışta oynatılacak hikâye anahtarı (boş = doğrudan geçiş)
func get_exit_story_key() -> String:
	return ""


## Çıkış başlarken bir kez çağrılır (görev ilerletme)
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
