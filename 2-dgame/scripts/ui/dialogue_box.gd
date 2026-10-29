class_name DialogueBox
extends CanvasLayer

const StoryDataLoader = preload("res://scripts/autoloads/story_data_loader.gd")

## res://scripts/ui/dialogue_box.gd
## Alt panel RPG tarzı diyalog arayüzü kontrolcüsü.
## data/ altındaki JSON diyalog dizilerini sırayla oynatır.

signal dialogue_started()
signal dialogue_completed()
signal entry_started(entry: Dictionary)
signal choice_selected(action: String)

@export var typewriter_speed: float = 0.025

var _dialogue_queue: Array = []
var _current_index: int = 0
var _is_typing: bool = false
var _full_text: String = ""
var _type_timer: float = 0.0
var _char_index: int = 0
var _current_choices: Array = []
var _has_choices_active: bool = false

const PORTRAIT_FATIH = preload("res://assets/ui/portraits/portrait_fatih.png")
const PORTRAIT_COMMANDER = preload("res://assets/ui/portraits/portrait_commander.png")
const PORTRAIT_PLAYER = preload("res://assets/ui/portraits/portrait_player.png")
const PORTRAIT_VLAD = preload("res://assets/ui/portraits/portrait_vlad.png")
const PORTRAIT_KEMANKES = preload("res://assets/ui/portraits/portrait_kemankes.png")
const PORTRAIT_BLOOD_KNIGHT = preload("res://assets/ui/portraits/portrait_blood_knight.png")

@onready var panel: Control = $Panel
@onready var letterbox_top: ColorRect = get_node_or_null("LetterboxTop") as ColorRect
@onready var letterbox_bottom: ColorRect = get_node_or_null("LetterboxBottom") as ColorRect
@onready var speaker_name_label: Label = $Panel/SpeakerName
@onready var speaker_title_label: Label = $Panel/SpeakerTitle
@onready var content_label: Label = $Panel/ContentLabel
@onready var portrait_texture: TextureRect = get_node_or_null("Panel/PortraitContainer/PortraitTexture") as TextureRect
@onready var continue_prompt: Label = $Panel/ContinuePrompt
@onready var choices_container: HBoxContainer = get_node_or_null("Panel/ChoicesContainer") as HBoxContainer
@onready var choice_btn_1: Button = get_node_or_null("Panel/ChoicesContainer/ChoiceButton1") as Button
@onready var choice_btn_2: Button = get_node_or_null("Panel/ChoicesContainer/ChoiceButton2") as Button

var _active_camera: Camera2D = null
var _original_camera_zoom: Vector2 = Vector2.ONE
var _original_camera_offset: Vector2 = Vector2.ZERO
var _player_ref: CharacterBody2D = null
var _cine_source: String = ""
var _dialogue_active: bool = false
var _echo_label: Label = null


func is_dialogue_active() -> bool:
	return _dialogue_active


## Diyaloğu atlar: kalan satırlar yok sayılır; kontroller ve filtreler sıfırlanır
func skip_dialogue() -> void:
	if not _dialogue_active:
		return
	_is_typing = false
	_has_choices_active = false
	_current_index = _dialogue_queue.size()
	_clear_echo()
	_close_dialogue()


func _exit_tree() -> void:
	# Sahne yeniden başlatma / atlama: asılı kalmış sinematik kilidini serbest bırak
	if _dialogue_active:
		_dialogue_active = false
		var cm = get_node_or_null("/root/CinematicManager")
		if cm:
			cm.end_cinematic(_cine_source)


## "echo": true işaretli satırlarda metnin soluk, hafif kaymış bir yankısını gösterir
func _show_echo(entry: Dictionary) -> void:
	_clear_echo()
	if not bool(entry.get("echo", false)) or not content_label:
		return
	var cm = get_node_or_null("/root/CinematicManager")
	_echo_label = Label.new()
	_echo_label.text = str(entry.get("text", ""))
	_echo_label.autowrap_mode = content_label.autowrap_mode
	_echo_label.size = content_label.size
	_echo_label.position = content_label.position + Vector2(5.0, 3.0)
	_echo_label.modulate = Color(0.55, 0.75, 1.0, 0.28)
	_echo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_label.get_parent().add_child(_echo_label)
	content_label.get_parent().move_child(_echo_label, content_label.get_index())
	# Yanıp sönmeyi azalt açıksa sabit soluk yankı, kapalıysa nabız efekti
	if not (cm and cm.reduce_flashing):
		var tw := _echo_label.create_tween().set_loops(3)
		tw.tween_property(_echo_label, "modulate:a", 0.12, 0.6)
		tw.tween_property(_echo_label, "modulate:a", 0.32, 0.6)


func _clear_echo() -> void:
	if _echo_label and is_instance_valid(_echo_label):
		_echo_label.queue_free()
	_echo_label = null


func _ready() -> void:
	add_to_group("dialogue_box")
	_cine_source = "dialogue_%d" % get_instance_id()
	if panel:
		panel.visible = false
	if choice_btn_1:
		choice_btn_1.pressed.connect(func(): _on_choice_clicked(0))
	if choice_btn_2:
		choice_btn_2.pressed.connect(func(): _on_choice_clicked(1))


func _process(delta: float) -> void:
	if not _is_typing:
		return

	_type_timer += delta
	if _type_timer >= typewriter_speed:
		_type_timer = 0.0
		_char_index += 1
		content_label.text = _full_text.substr(0, _char_index)
		if _char_index >= _full_text.length():
			_on_typing_finished()


func _on_typing_finished() -> void:
	_is_typing = false
	if _current_choices.size() > 0:
		_has_choices_active = true
		if continue_prompt:
			continue_prompt.visible = false
		if choices_container:
			choices_container.visible = true
			if choice_btn_1 and choice_btn_1.is_visible_in_tree():
				choice_btn_1.grab_focus()
	else:
		_has_choices_active = false
		if choices_container:
			choices_container.visible = false
		if continue_prompt:
			continue_prompt.text = "[Sol Tık / Boşluk / E: İlerle | TAB: Atla]"
			continue_prompt.visible = true


func _input(event: InputEvent) -> void:
	if not panel or not panel.visible:
		return

	# TAB: Diyaloğu / sinematiği atla
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		skip_dialogue()
		return

	if _has_choices_active:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_1 and _current_choices.size() > 0:
				get_viewport().set_input_as_handled()
				_on_choice_clicked(0)
				return
			elif event.keycode == KEY_2 and _current_choices.size() > 1:
				get_viewport().set_input_as_handled()
				_on_choice_clicked(1)
				return
		return

	if (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_E)) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		if _is_typing:
			_is_typing = false
			content_label.text = _full_text
			_on_typing_finished()
		else:
			_advance_dialogue()


## StoryDataLoader üzerindeki bir diyalog anahtarıyla başlatır
func start_dialogue_from_data(key: String, focus_speaker: Node2D = null) -> void:
	var list: Array = StoryDataLoader.get_dialogue_sequence(key)
	if list.is_empty():
		push_warning("DialogueBox: Empty dialogue sequence for key: " + key)
		return
	start_dialogue(list, focus_speaker)


## Doğrudan sözlük dizisiyle başlatır (Sinematik 1.35x zoom ve letterbox ile)
func start_dialogue(entries: Array, focus_speaker: Node2D = null) -> void:
	if entries.is_empty():
		return

	_dialogue_queue = entries.duplicate()
	_current_index = 0
	_dialogue_active = true
	if panel:
		panel.visible = true
	_apply_cinematic_mode(true, focus_speaker)
	dialogue_started.emit()
	_show_current_entry()


## Harici sinematik ara sahneler için Letterbox kontrolü
func set_letterbox(enable: bool, bar_height: float = 52.0) -> void:
	var tw_box: Tween = create_tween().set_parallel(true)
	if letterbox_top:
		tw_box.tween_property(letterbox_top, "offset_bottom", bar_height if enable else 0.0, 0.4).set_trans(Tween.TRANS_QUAD)
	if letterbox_bottom:
		tw_box.tween_property(letterbox_bottom, "offset_top", -bar_height if enable else 0.0, 0.4).set_trans(Tween.TRANS_QUAD)


func _apply_cinematic_mode(enable: bool, focus_speaker: Node2D = null) -> void:
	if not is_inside_tree():
		return

	var tree: SceneTree = get_tree()
	if not tree:
		return

	# 0. Global sinematik bayrağını ayarla ve grupları bilgilendir
	var cine_mgr = get_node_or_null("/root/CinematicManager")
	var game_state = get_node_or_null("/root/GameState")
	if cine_mgr:
		# Oyuncu girdi kilidi + GameState.is_in_cinematic CinematicManager tarafından yönetilir
		if enable:
			cine_mgr.begin_cinematic(_cine_source)
		else:
			cine_mgr.end_cinematic(_cine_source)
	elif game_state:
		game_state.is_in_cinematic = enable

	if enable:
		tree.call_group("allies", "on_cinematic_started")
		tree.call_group("enemies", "on_cinematic_started")
	else:
		tree.call_group("allies", "on_cinematic_ended")
		tree.call_group("enemies", "on_cinematic_ended")

	# 1. Oyuncuyu dondur / çöz
	_player_ref = tree.get_first_node_in_group("player") as CharacterBody2D

	if _player_ref and "can_move" in _player_ref:
		if not cine_mgr:
			_player_ref.can_move = not enable
		if enable:
			_player_ref.velocity.x = 0.0
			var sprite = _player_ref.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
			if sprite and not ("is_attacking" in _player_ref and _player_ref.is_attacking):
				sprite.play("idle")

	# 2. Sinematik Letterbox (Üst ve alt siyah barlar)
	set_letterbox(enable, 52.0)

	# 3. HUD Tamamen Gizle / Göster (Diyalog kutusu ve sinematiklerle çakışmayı önle)
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud and _player_ref and _player_ref.get_parent():
		hud = _player_ref.get_parent().get_node_or_null("FantasyHUD")
	if hud and "visible" in hud:
		hud.visible = not enable
	elif hud and hud.has_method("hide_tutorial") and enable:
		hud.hide_tutorial(true)

	# 3. Kamera 1.35x Yumuşak Zoom ve Odaklama
	if not _active_camera or not is_instance_valid(_active_camera):
		if _player_ref:
			_active_camera = _player_ref.get_node_or_null("Camera2D") as Camera2D
		if not _active_camera:
			_active_camera = get_viewport().get_camera_2d()

	if _active_camera and is_instance_valid(_active_camera):
		var motion_ok: bool = not (cine_mgr and cine_mgr.reduce_motion)
		if enable:
			_original_camera_zoom = _active_camera.zoom
			_original_camera_offset = _active_camera.offset
		# Hareketi azalt erişilebilirlik seçeneği açıksa kamera zoom/kayması uygulanmaz
		if enable and not motion_ok:
			pass
		else:
			var tw_cam: Tween = create_tween().set_parallel(true)
			if enable:
				tw_cam.tween_property(_active_camera, "zoom", Vector2(1.35, 1.35), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				if focus_speaker and is_instance_valid(focus_speaker) and _player_ref:
					var mid_x: float = (focus_speaker.global_position.x - _player_ref.global_position.x) * 0.4
					tw_cam.tween_property(_active_camera, "offset:x", mid_x, 0.45)
			else:
				tw_cam.tween_property(_active_camera, "zoom", _original_camera_zoom, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw_cam.tween_property(_active_camera, "offset", _original_camera_offset, 0.45)


func _show_current_entry() -> void:
	if _current_index >= _dialogue_queue.size():
		_close_dialogue()
		return

	var entry: Dictionary = _dialogue_queue[_current_index] as Dictionary
	var loc_mgr = get_node_or_null("/root/LocalizationManager")
	var is_en: bool = (loc_mgr != null and loc_mgr.has_method("get_current_locale") and loc_mgr.get_current_locale() == "en")

	var speaker_str: String = entry.get("speaker_en", "") if (is_en and not str(entry.get("speaker_en", "")).is_empty()) else str(entry.get("speaker", ""))
	var title_str: String = entry.get("title_en", "") if (is_en and not str(entry.get("title_en", "")).is_empty()) else str(entry.get("title", ""))
	var text_str: String = entry.get("text_en", "") if (is_en and not str(entry.get("text_en", "")).is_empty()) else str(entry.get("text", ""))

	if speaker_name_label:
		speaker_name_label.text = speaker_str
	if speaker_title_label:
		speaker_title_label.text = title_str
	_full_text = text_str
	_char_index = 0
	_is_typing = true
	if content_label:
		content_label.text = ""
	if continue_prompt:
		continue_prompt.text = "[Left Click / Space / E: Advance | TAB: Skip]" if is_en else "[Sol Tık / Boşluk / E: İlerle | TAB: Atla]"
		continue_prompt.visible = false

	entry_started.emit(entry)
	_show_echo(entry)

	# Seçenekleri hazırla (varsa)
	_current_choices = entry.get("choices", [])
	_has_choices_active = false
	if choices_container:
		choices_container.visible = false
	if _current_choices.size() > 0:
		if choice_btn_1:
			var default_btn1 := "[1] Yes" if is_en else "[1] Evet"
			var choice1_text := str(_current_choices[0].get("text_en", "")) if (is_en and not str(_current_choices[0].get("text_en", "")).is_empty()) else str(_current_choices[0].get("text", default_btn1))
			choice_btn_1.text = choice1_text
			choice_btn_1.visible = true
		if choice_btn_2:
			if _current_choices.size() > 1:
				var default_btn2 := "[2] No" if is_en else "[2] Hayır"
				var choice2_text := str(_current_choices[1].get("text_en", "")) if (is_en and not str(_current_choices[1].get("text_en", "")).is_empty()) else str(_current_choices[1].get("text", default_btn2))
				choice_btn_2.text = choice2_text
				choice_btn_2.visible = true
			else:
				choice_btn_2.visible = false

	# Portre rengi/stili
	var portrait_type: String = entry.get("portrait", "")
	_apply_portrait_style(portrait_type)


func _on_choice_clicked(index: int) -> void:
	if not _has_choices_active or index < 0 or index >= _current_choices.size():
		return
	var choice_data: Dictionary = _current_choices[index] as Dictionary
	var action: String = choice_data.get("action", "")
	_has_choices_active = false
	if choices_container:
		choices_container.visible = false
	choice_selected.emit(action)
	_advance_dialogue()


func _apply_portrait_style(portrait_type: String) -> void:
	if not portrait_texture:
		return

	var container: Control = portrait_texture.get_parent() as Control

	match portrait_type:
		"fatih":
			if container:
				container.visible = true
			portrait_texture.texture = PORTRAIT_FATIH
		"janissary", "commander":
			if container:
				container.visible = true
			portrait_texture.texture = PORTRAIT_COMMANDER
		"player", "player_dark":
			if container:
				container.visible = true
			portrait_texture.texture = PORTRAIT_PLAYER
		"vlad":
			if container:
				container.visible = true
			portrait_texture.texture = PORTRAIT_VLAD
		"blood_knight", "knight":
			if container:
				container.visible = true
			portrait_texture.texture = PORTRAIT_BLOOD_KNIGHT
		"archer", "kemankes":
			if container:
				container.visible = true
			portrait_texture.texture = PORTRAIT_KEMANKES
		"none", "empty":
			if container:
				container.visible = false
			portrait_texture.texture = null
		_:
			if container:
				container.visible = true
			portrait_texture.texture = PORTRAIT_FATIH


func _advance_dialogue() -> void:
	_current_index += 1
	_show_current_entry()


func _close_dialogue() -> void:
	_dialogue_active = false
	_clear_echo()
	if panel:
		panel.visible = false
	_has_choices_active = false
	if choices_container:
		choices_container.visible = false
	_apply_cinematic_mode(false)
	dialogue_completed.emit()
