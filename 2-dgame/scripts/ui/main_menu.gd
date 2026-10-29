extends Control

## res://scripts/ui/main_menu.gd
## Ana Menü Kontrolcüsü: Giriş akışı, kayıt yönetimi, bölüm seçimi ve geçişler.

@onready var btn_continue: Button = $UI/MenuCenter/MenuButtons/BtnContinue
@onready var btn_new_game: Button = $UI/MenuCenter/MenuButtons/BtnNewGame
@onready var btn_chapter_select: Button = $UI/MenuCenter/MenuButtons/BtnChapterSelect
@onready var btn_settings: Button = $UI/MenuCenter/MenuButtons/BtnSettings
@onready var btn_exit: Button = $UI/MenuCenter/MenuButtons/BtnExit

@onready var title_label: Label = find_child("TitleLabel", true, false) as Label
@onready var subtitle_label: Label = find_child("SubtitleLabel", true, false) as Label

@onready var confirm_dialog: PanelContainer = $UI/ConfirmDialog
@onready var chapter_dialog: PanelContainer = $UI/ChapterSelectDialog
@onready var settings_dialog: PanelContainer = $UI/SettingsDialog

@onready var parallax_bg: Node2D = $ParallaxBackground
@onready var music_player: AudioStreamPlayer = $MusicPlayer

const NEW_GAME_START_SCENE: String = "res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn"

var _buttons: Array[Button] = []
var _target_mouse_offset: Vector2 = Vector2.ZERO


var _signals_connected: bool = false


func _ready() -> void:
	_resolve_nodes()
	_buttons = [btn_continue, btn_new_game, btn_chapter_select, btn_settings, btn_exit]
	if not _signals_connected:
		_connect_buttons()
		_setup_dialog_signals()
		_signals_connected = true

	var loc_mgr = _get_autoload("LocalizationManager")
	if loc_mgr and loc_mgr.has_signal("locale_changed"):
		if not loc_mgr.locale_changed.is_connected(_on_locale_changed):
			loc_mgr.locale_changed.connect(_on_locale_changed)

	_update_localized_texts()
	_setup_focus_chain()
	_update_continue_state()
	_start_menu_audio()


func _resolve_nodes() -> void:
	if not title_label:
		title_label = find_child("TitleLabel", true, false) as Label
	if not subtitle_label:
		subtitle_label = find_child("SubtitleLabel", true, false) as Label
	if not btn_continue:
		btn_continue = find_child("BtnContinue", true, false) as Button
	if not btn_new_game:
		btn_new_game = find_child("BtnNewGame", true, false) as Button
	if not btn_chapter_select:
		btn_chapter_select = find_child("BtnChapterSelect", true, false) as Button
	if not btn_settings:
		btn_settings = find_child("BtnSettings", true, false) as Button
	if not btn_exit:
		btn_exit = find_child("BtnExit", true, false) as Button

	if not confirm_dialog:
		confirm_dialog = find_child("ConfirmDialog", true, false) as PanelContainer
	if not chapter_dialog:
		chapter_dialog = find_child("ChapterSelectDialog", true, false) as PanelContainer
	if not settings_dialog:
		settings_dialog = find_child("SettingsDialog", true, false) as PanelContainer
	if not parallax_bg:
		parallax_bg = find_child("ParallaxBackground", true, false) as Node2D
	if not music_player:
		music_player = find_child("MusicPlayer", true, false) as AudioStreamPlayer


func _on_locale_changed(_new_locale: String) -> void:
	_update_localized_texts()


func _update_localized_texts() -> void:
	if title_label:
		title_label.text = tr("MENU_MAIN_TITLE")
	if subtitle_label:
		subtitle_label.text = tr("MENU_SUBTITLE_DESC")
	if btn_continue:
		btn_continue.text = tr("BTN_CONTINUE")
	if btn_new_game:
		btn_new_game.text = tr("BTN_NEW_GAME")
	if btn_chapter_select:
		btn_chapter_select.text = tr("BTN_CHAPTER_SELECT")
	if btn_settings:
		btn_settings.text = tr("BTN_SETTINGS")
	if btn_exit:
		btn_exit.text = tr("BTN_EXIT")


func _get_autoload(autoload_name: String) -> Node:
	var root_node: Node = null
	if is_inside_tree() and get_tree():
		root_node = get_tree().root
	elif Engine.get_main_loop() is SceneTree:
		root_node = (Engine.get_main_loop() as SceneTree).root
	elif get_parent():
		var p = get_parent()
		while p.get_parent():
			p = p.get_parent()
		root_node = p

	if root_node:
		return root_node.get_node_or_null(autoload_name)
	return null


func _process(delta: float) -> void:
	if parallax_bg:
		# Fare hareketine duyarlı hafif paralaks kayması
		var vp_center = get_viewport_rect().size * 0.5
		var mouse_pos = get_viewport().get_mouse_position()
		var diff = (mouse_pos - vp_center) / vp_center
		_target_mouse_offset = _target_mouse_offset.lerp(diff * 18.0, delta * 3.0)
		parallax_bg.position = _target_mouse_offset


func _connect_buttons() -> void:
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_chapter_select.pressed.connect(_on_chapter_select_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)

	for btn in _buttons:
		btn.mouse_entered.connect(func(): _on_button_hovered(btn))


func _setup_focus_chain() -> void:
	if not is_inside_tree():
		return
	var active_buttons: Array[Button] = []
	for btn in _buttons:
		if btn and not btn.disabled and btn.is_inside_tree():
			active_buttons.append(btn)

	for i in range(active_buttons.size()):
		var curr = active_buttons[i]
		var prev = active_buttons[(i - 1 + active_buttons.size()) % active_buttons.size()]
		var next = active_buttons[(i + 1) % active_buttons.size()]
		if curr.is_inside_tree() and prev.is_inside_tree() and next.is_inside_tree():
			curr.focus_neighbor_top = prev.get_path()
			curr.focus_neighbor_bottom = next.get_path()


func _update_continue_state() -> void:
	_resolve_nodes()
	var save_mgr = _get_autoload("SaveManager")
	var has_save: bool = false
	if save_mgr and save_mgr.has_method("has_save"):
		has_save = save_mgr.has_save()

	if btn_continue:
		btn_continue.disabled = not has_save
		if has_save:
			btn_continue.modulate = Color.WHITE
			if btn_continue.is_inside_tree():
				btn_continue.grab_focus()
		else:
			btn_continue.modulate = Color(0.6, 0.6, 0.6, 0.6)
			if btn_new_game and btn_new_game.is_inside_tree():
				btn_new_game.grab_focus()

	_setup_focus_chain()


func _setup_dialog_signals() -> void:
	if confirm_dialog:
		confirm_dialog.confirmed.connect(_start_brand_new_game)
		confirm_dialog.cancelled.connect(func(): if btn_new_game and btn_new_game.is_inside_tree(): btn_new_game.grab_focus())
	if chapter_dialog:
		chapter_dialog.chapter_selected.connect(_on_chapter_chosen)
		chapter_dialog.closed.connect(func(): if btn_chapter_select and btn_chapter_select.is_inside_tree(): btn_chapter_select.grab_focus())
	if settings_dialog:
		settings_dialog.closed.connect(func(): if btn_settings and btn_settings.is_inside_tree(): btn_settings.grab_focus())


func _on_button_hovered(btn: Button) -> void:
	if btn and btn.is_inside_tree() and not btn.disabled and not _is_any_modal_open():
		btn.grab_focus()


func _is_any_modal_open() -> bool:
	return (confirm_dialog and confirm_dialog.visible) or \
		(chapter_dialog and chapter_dialog.visible) or \
		(settings_dialog and settings_dialog.visible)


# --- Buton Eylemleri ---

func _on_continue_pressed() -> void:
	if _is_any_modal_open():
		return
	var save_mgr = _get_autoload("SaveManager")
	if not save_mgr or not save_mgr.has_save():
		return

	save_mgr.load_game()
	var target_scene = NEW_GAME_START_SCENE
	var game_state = _get_autoload("GameState")
	if game_state and not game_state.current_stage_path.is_empty():
		target_scene = game_state.current_stage_path
	elif save_mgr.has_method("get_save_info"):
		var info = save_mgr.get_save_info()
		if info.has("stage_data") and info["stage_data"] is Dictionary:
			var sp = str(info["stage_data"].get("current_stage_path", ""))
			if not sp.is_empty():
				target_scene = sp
		elif info.has("current_stage_path"):
			var sp2 = str(info["current_stage_path"])
			if not sp2.is_empty():
				target_scene = sp2

	_transition_to_scene(target_scene)


func _on_new_game_pressed() -> void:
	if _is_any_modal_open():
		return
	var save_mgr = _get_autoload("SaveManager")
	if save_mgr and save_mgr.has_save():
		confirm_dialog.prompt(tr("CONFIRM_NEW_GAME_TITLE"), tr("CONFIRM_NEW_GAME_MSG"))
	else:
		_start_brand_new_game()


func _start_brand_new_game() -> void:
	var game_state = _get_autoload("GameState")
	if game_state and game_state.has_method("reset_state"):
		game_state.reset_state()

	var save_mgr = _get_autoload("SaveManager")
	if save_mgr and save_mgr.has_method("save_game"):
		save_mgr.save_game()

	_transition_to_scene(NEW_GAME_START_SCENE)


func _on_chapter_select_pressed() -> void:
	if _is_any_modal_open():
		return
	chapter_dialog.open()


func _on_chapter_chosen(_chapter_idx: int, scene_path: String) -> void:
	var save_mgr = _get_autoload("SaveManager")
	if save_mgr and save_mgr.has_method("has_save") and save_mgr.has_save():
		save_mgr.load_game()
	var game_state = _get_autoload("GameState")
	if game_state:
		game_state.current_stage_path = scene_path
	_transition_to_scene(scene_path)


func _on_settings_pressed() -> void:
	if _is_any_modal_open():
		return
	settings_dialog.open()


func _on_exit_pressed() -> void:
	if _is_any_modal_open():
		return
	get_tree().quit()


func _transition_to_scene(scene_path: String) -> void:
	for btn in _buttons:
		if btn:
			btn.release_focus()

	var transition = _get_autoload("SceneTransition")
	if transition and transition.has_method("change_scene"):
		transition.change_scene(scene_path, 0.4)
	else:
		get_tree().change_scene_to_file(scene_path)


func _start_menu_audio() -> void:
	if not music_player or not music_player.is_inside_tree():
		return
	# Eğer atanmış bir müzik akışı varsa çal
	if music_player.stream:
		music_player.play()
	else:
		# Prosedürel karanlık ortam tonu (Sessizlik yerine atmosferik uğultu)
		_setup_procedural_ambient_audio()


func _setup_procedural_ambient_audio() -> void:
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	music_player.stream = gen
	music_player.volume_db = -18.0
	music_player.play()
	var playback: AudioStreamGeneratorPlayback = music_player.get_stream_playback()
	if playback:
		var frames: int = int(gen.mix_rate * 0.4)
		for i in range(frames):
			var t: float = float(i) / gen.mix_rate
			var sample: float = sin(t * 110.0 * TAU) * 0.2 + sin(t * 165.0 * TAU) * 0.1
			playback.push_frame(Vector2(sample, sample))
