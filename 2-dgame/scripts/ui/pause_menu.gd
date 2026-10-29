extends Control
class_name PauseMenu

## res://scripts/ui/pause_menu.gd
## Dark Fantasy Duraklatma Menüsü (Pause Menu)
## Oyun duraklatıldığında görünür; Devam Et, Kayıt Yuvaları (3 Yuva), Ayarlar, Yeniden Başlat ve Ana Menü seçenekleri sunar.

signal resumed()
signal restarted()
signal main_menu_requested()
signal saved(slot: int)

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Center/PanelContainer
@onready var pause_title: Label = get_node_or_null("Center/PanelContainer/Margin/VBox/Title") as Label
@onready var pause_subtitle: Label = get_node_or_null("Center/PanelContainer/Margin/VBox/Subtitle") as Label
@onready var btn_resume: Button = $Center/PanelContainer/Margin/VBox/Buttons/BtnResume
@onready var btn_save: Button = $Center/PanelContainer/Margin/VBox/Buttons/BtnSave
@onready var btn_settings: Button = $Center/PanelContainer/Margin/VBox/Buttons/BtnSettings
@onready var btn_restart: Button = $Center/PanelContainer/Margin/VBox/Buttons/BtnRestart
@onready var btn_main_menu: Button = $Center/PanelContainer/Margin/VBox/Buttons/BtnMainMenu

# Kayıt Yuvaları Paneli
@onready var save_slots_panel: PanelContainer = $Center/SaveSlotsPanel
@onready var save_panel_title: Label = get_node_or_null("Center/SaveSlotsPanel/Margin/VBox/Title") as Label
@onready var check_autosave: CheckBox = $Center/SaveSlotsPanel/Margin/VBox/AutoSaveRow/CheckAutoSave
@onready var btn_back_from_save: Button = $Center/SaveSlotsPanel/Margin/VBox/BtnBackFromSave
@onready var feedback_label: Label = $Center/SaveSlotsPanel/Margin/VBox/FeedbackLabel

# Yuva 1, 2, 3 Düğümleri
@onready var lbl_slot1_title: Label = get_node_or_null("Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard1/HBox/InfoVBox/LblSlot1Title") as Label
@onready var lbl_slot1_details: Label = $Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard1/HBox/InfoVBox/LblSlot1Details
@onready var btn_save_slot1: Button = $Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard1/HBox/BtnSaveSlot1
@onready var btn_load_slot1: Button = $Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard1/HBox/BtnLoadSlot1

@onready var lbl_slot2_title: Label = get_node_or_null("Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard2/HBox/InfoVBox/LblSlot2Title") as Label
@onready var lbl_slot2_details: Label = $Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard2/HBox/InfoVBox/LblSlot2Details
@onready var btn_save_slot2: Button = $Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard2/HBox/BtnSaveSlot2
@onready var btn_load_slot2: Button = $Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard2/HBox/BtnLoadSlot2

@onready var lbl_slot3_title: Label = get_node_or_null("Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard3/HBox/InfoVBox/LblSlot3Title") as Label
@onready var lbl_slot3_details: Label = $Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard3/HBox/InfoVBox/LblSlot3Details
@onready var btn_save_slot3: Button = $Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard3/HBox/BtnSaveSlot3
@onready var btn_load_slot3: Button = $Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard3/HBox/BtnLoadSlot3

# Ayarlar Penceresi
@onready var settings_dialog: PanelContainer = get_node_or_null("SettingsDialog") as PanelContainer

var _signals_connected: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_nodes()
	_setup_signals()
	visible = false
	if save_slots_panel:
		save_slots_panel.visible = false
	if settings_dialog:
		settings_dialog.visible = false

	var loc_mgr = _get_autoload("LocalizationManager")
	if loc_mgr and loc_mgr.has_signal("locale_changed"):
		if not loc_mgr.locale_changed.is_connected(_on_locale_changed):
			loc_mgr.locale_changed.connect(_on_locale_changed)
	_update_localized_texts()


func _resolve_nodes() -> void:
	if not backdrop:
		backdrop = find_child("Backdrop", true, false) as ColorRect
	if not panel:
		panel = find_child("PanelContainer", true, false) as PanelContainer
	if not pause_title:
		pause_title = get_node_or_null("Center/PanelContainer/Margin/VBox/Title") as Label
	if not pause_subtitle:
		pause_subtitle = get_node_or_null("Center/PanelContainer/Margin/VBox/Subtitle") as Label
	if not btn_resume:
		btn_resume = find_child("BtnResume", true, false) as Button
	if not btn_save:
		btn_save = find_child("BtnSave", true, false) as Button
	if not btn_settings:
		btn_settings = find_child("BtnSettings", true, false) as Button
	if not btn_restart:
		btn_restart = find_child("BtnRestart", true, false) as Button
	if not btn_main_menu:
		btn_main_menu = find_child("BtnMainMenu", true, false) as Button

	if not save_slots_panel:
		save_slots_panel = find_child("SaveSlotsPanel", true, false) as PanelContainer
	if not save_panel_title:
		save_panel_title = get_node_or_null("Center/SaveSlotsPanel/Margin/VBox/Title") as Label
	if not check_autosave:
		check_autosave = find_child("CheckAutoSave", true, false) as CheckBox
	if not btn_back_from_save:
		btn_back_from_save = find_child("BtnBackFromSave", true, false) as Button
	if not feedback_label:
		feedback_label = find_child("FeedbackLabel", true, false) as Label

	if not lbl_slot1_title:
		lbl_slot1_title = get_node_or_null("Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard1/HBox/InfoVBox/LblSlot1Title") as Label
	if not lbl_slot1_details:
		lbl_slot1_details = find_child("LblSlot1Details", true, false) as Label
	if not btn_save_slot1:
		btn_save_slot1 = find_child("BtnSaveSlot1", true, false) as Button
	if not btn_load_slot1:
		btn_load_slot1 = find_child("BtnLoadSlot1", true, false) as Button

	if not lbl_slot2_title:
		lbl_slot2_title = get_node_or_null("Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard2/HBox/InfoVBox/LblSlot2Title") as Label
	if not lbl_slot2_details:
		lbl_slot2_details = find_child("LblSlot2Details", true, false) as Label
	if not btn_save_slot2:
		btn_save_slot2 = find_child("BtnSaveSlot2", true, false) as Button
	if not btn_load_slot2:
		btn_load_slot2 = find_child("BtnLoadSlot2", true, false) as Button

	if not lbl_slot3_title:
		lbl_slot3_title = get_node_or_null("Center/SaveSlotsPanel/Margin/VBox/SlotsContainer/SlotCard3/HBox/InfoVBox/LblSlot3Title") as Label
	if not lbl_slot3_details:
		lbl_slot3_details = find_child("LblSlot3Details", true, false) as Label
	if not btn_save_slot3:
		btn_save_slot3 = find_child("BtnSaveSlot3", true, false) as Button
	if not btn_load_slot3:
		btn_load_slot3 = find_child("BtnLoadSlot3", true, false) as Button

	if not settings_dialog:
		settings_dialog = find_child("SettingsDialog", true, false) as PanelContainer


func _on_locale_changed(_new_locale: String) -> void:
	_update_localized_texts()
	if save_slots_panel and save_slots_panel.visible:
		_refresh_slot_cards()


func _update_localized_texts() -> void:
	if pause_title:
		pause_title.text = tr("PAUSE_TITLE")
	if pause_subtitle:
		pause_subtitle.text = tr("PAUSE_SUBTITLE")
	if btn_resume:
		btn_resume.text = tr("BTN_PAUSE_RESUME")
	if btn_save:
		btn_save.text = tr("BTN_SAVE_SLOTS")
	if btn_settings:
		btn_settings.text = tr("BTN_SETTINGS")
	if btn_restart:
		btn_restart.text = tr("BTN_RESTART")
	if btn_main_menu:
		btn_main_menu.text = tr("BTN_MAIN_MENU")

	if save_panel_title:
		save_panel_title.text = tr("SAVE_SLOTS_TITLE")
	if check_autosave:
		check_autosave.text = tr("AUTOSAVE_CHECK")
	if btn_back_from_save:
		btn_back_from_save.text = tr("BTN_BACK_TO_PAUSE")

	var slot_title_tmpl: String = tr("SLOT_TITLE")
	if "%" in slot_title_tmpl:
		if lbl_slot1_title:
			lbl_slot1_title.text = slot_title_tmpl % 1
		if lbl_slot2_title:
			lbl_slot2_title.text = slot_title_tmpl % 2
		if lbl_slot3_title:
			lbl_slot3_title.text = slot_title_tmpl % 3
	else:
		if lbl_slot1_title:
			lbl_slot1_title.text = "Yuva 1"
		if lbl_slot2_title:
			lbl_slot2_title.text = "Yuva 2"
		if lbl_slot3_title:
			lbl_slot3_title.text = "Yuva 3"

	if btn_save_slot1:
		btn_save_slot1.text = tr("BTN_SAVE")
	if btn_save_slot2:
		btn_save_slot2.text = tr("BTN_SAVE")
	if btn_save_slot3:
		btn_save_slot3.text = tr("BTN_SAVE")

	if btn_load_slot1:
		btn_load_slot1.text = tr("BTN_LOAD")
	if btn_load_slot2:
		btn_load_slot2.text = tr("BTN_LOAD")
	if btn_load_slot3:
		btn_load_slot3.text = tr("BTN_LOAD")


func _setup_signals() -> void:
	if _signals_connected:
		return
	_resolve_nodes()

	if btn_resume and not btn_resume.pressed.is_connected(resume_game):
		btn_resume.pressed.connect(resume_game)
	if btn_save and not btn_save.pressed.is_connected(open_save_slots):
		btn_save.pressed.connect(open_save_slots)
	if btn_settings and not btn_settings.pressed.is_connected(open_settings):
		btn_settings.pressed.connect(open_settings)
	if btn_restart and not btn_restart.pressed.is_connected(restart_stage):
		btn_restart.pressed.connect(restart_stage)
	if btn_main_menu and not btn_main_menu.pressed.is_connected(go_to_main_menu):
		btn_main_menu.pressed.connect(go_to_main_menu)

	# Kayıt Yuvaları Butonları
	if btn_back_from_save and not btn_back_from_save.pressed.is_connected(close_save_slots):
		btn_back_from_save.pressed.connect(close_save_slots)

	if check_autosave and not check_autosave.toggled.is_connected(_on_autosave_toggled):
		check_autosave.toggled.connect(_on_autosave_toggled)

	if btn_save_slot1 and not btn_save_slot1.pressed.is_connected(func(): _on_slot_save_clicked(1)):
		btn_save_slot1.pressed.connect(func(): _on_slot_save_clicked(1))
	if btn_load_slot1 and not btn_load_slot1.pressed.is_connected(func(): _on_slot_load_clicked(1)):
		btn_load_slot1.pressed.connect(func(): _on_slot_load_clicked(1))

	if btn_save_slot2 and not btn_save_slot2.pressed.is_connected(func(): _on_slot_save_clicked(2)):
		btn_save_slot2.pressed.connect(func(): _on_slot_save_clicked(2))
	if btn_load_slot2 and not btn_load_slot2.pressed.is_connected(func(): _on_slot_load_clicked(2)):
		btn_load_slot2.pressed.connect(func(): _on_slot_load_clicked(2))

	if btn_save_slot3 and not btn_save_slot3.pressed.is_connected(func(): _on_slot_save_clicked(3)):
		btn_save_slot3.pressed.connect(func(): _on_slot_save_clicked(3))
	if btn_load_slot3 and not btn_load_slot3.pressed.is_connected(func(): _on_slot_load_clicked(3)):
		btn_load_slot3.pressed.connect(func(): _on_slot_load_clicked(3))

	if settings_dialog and settings_dialog.has_signal("closed") and not settings_dialog.closed.is_connected(close_settings):
		settings_dialog.closed.connect(close_settings)

	_setup_focus_chain()
	_signals_connected = true


func _setup_focus_chain() -> void:
	if btn_resume and btn_save and btn_settings and btn_restart and btn_main_menu:
		btn_resume.focus_neighbor_top = btn_main_menu.get_path()
		btn_resume.focus_neighbor_bottom = btn_save.get_path()

		btn_save.focus_neighbor_top = btn_resume.get_path()
		btn_save.focus_neighbor_bottom = btn_settings.get_path()

		btn_settings.focus_neighbor_top = btn_save.get_path()
		btn_settings.focus_neighbor_bottom = btn_restart.get_path()

		btn_restart.focus_neighbor_top = btn_settings.get_path()
		btn_restart.focus_neighbor_bottom = btn_main_menu.get_path()

		btn_main_menu.focus_neighbor_top = btn_restart.get_path()
		btn_main_menu.focus_neighbor_bottom = btn_resume.get_path()


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


func _get_scene_tree() -> SceneTree:
	if is_inside_tree() and get_tree():
		return get_tree()
	elif Engine.get_main_loop() is SceneTree:
		return Engine.get_main_loop() as SceneTree
	var p: Node = get_parent()
	while p:
		if p.is_inside_tree() and p.get_tree():
			return p.get_tree()
		if p.has_method("get_tree") and p.get_tree():
			return p.get_tree()
		p = p.get_parent()
	return null


func open() -> void:
	_resolve_nodes()
	_setup_signals()
	visible = true
	if panel:
		panel.visible = true
	if save_slots_panel:
		save_slots_panel.visible = false
	if settings_dialog:
		settings_dialog.visible = false

	var tree = _get_scene_tree()
	if tree:
		tree.paused = true
	if btn_resume and btn_resume.is_inside_tree():
		btn_resume.grab_focus()


func resume_game() -> void:
	visible = false
	if save_slots_panel:
		save_slots_panel.visible = false
	if settings_dialog:
		settings_dialog.visible = false

	var tree = _get_scene_tree()
	if tree:
		tree.paused = false
	resumed.emit()


func restart_stage() -> void:
	visible = false
	var tree = _get_scene_tree()
	if tree:
		tree.paused = false
		tree.reload_current_scene()
	restarted.emit()


func go_to_main_menu() -> void:
	visible = false
	var tree = _get_scene_tree()
	if tree:
		tree.paused = false
	main_menu_requested.emit()

	# Ana menüye dönmeden önce mevcut sahneyi ve durumu kaydet
	var save_mgr = _get_autoload("SaveManager")
	if save_mgr and save_mgr.has_method("save_game"):
		var slot_to_save = save_mgr.get("active_slot") if save_mgr.get("active_slot") != null else 1
		save_mgr.save_game(slot_to_save)

	var transition = _get_autoload("SceneTransition")
	if transition and transition.has_method("change_scene"):
		transition.change_scene("res://scenes/ui/main_menu.tscn", 0.35)
	elif tree:
		tree.change_scene_to_file("res://scenes/ui/main_menu.tscn")


# --- Kayıt Yuvaları Paneli ---

func open_save_slots() -> void:
	_resolve_nodes()
	if panel:
		panel.visible = false
	if save_slots_panel:
		save_slots_panel.visible = true
	if feedback_label:
		feedback_label.text = ""

	var save_mgr = _get_autoload("SaveManager")
	if save_mgr and check_autosave:
		check_autosave.button_pressed = save_mgr.is_autosave_enabled() if save_mgr.has_method("is_autosave_enabled") else true

	_refresh_slot_cards()
	if btn_save_slot1 and btn_save_slot1.is_inside_tree():
		btn_save_slot1.grab_focus()


func close_save_slots() -> void:
	if save_slots_panel:
		save_slots_panel.visible = false
	if panel:
		panel.visible = true
	if btn_save and btn_save.is_inside_tree():
		btn_save.grab_focus()


func _on_autosave_toggled(toggled_on: bool) -> void:
	var save_mgr = _get_autoload("SaveManager")
	if save_mgr and save_mgr.has_method("set_autosave_enabled"):
		save_mgr.set_autosave_enabled(toggled_on)
	if feedback_label:
		feedback_label.text = tr("AUTOSAVE_STATUS_ON") if toggled_on else tr("AUTOSAVE_STATUS_OFF")


func _refresh_slot_cards() -> void:
	var save_mgr = _get_autoload("SaveManager")
	if not save_mgr:
		return

	_update_slot_card_ui(1, lbl_slot1_details, btn_load_slot1, save_mgr)
	_update_slot_card_ui(2, lbl_slot2_details, btn_load_slot2, save_mgr)
	_update_slot_card_ui(3, lbl_slot3_details, btn_load_slot3, save_mgr)


func _update_slot_card_ui(slot: int, details_lbl: Label, load_btn: Button, save_mgr: Node) -> void:
	if not details_lbl:
		return
	var summary: Dictionary = {}
	if save_mgr.has_method("get_slot_summary"):
		summary = save_mgr.get_slot_summary(slot)
	else:
		var has = save_mgr.has_save(slot)
		summary = {
			"has_save": has,
			"timestamp": "-" if not has else "Kayıtlı",
			"location_name": "Boş Yuva" if not has else "Mevcut Bölüm"
		}

	if summary.get("has_save", false):
		var raw_loc = str(summary.get("location_name", "-"))
		var loc_display = tr(raw_loc) if not raw_loc.is_empty() else raw_loc
		details_lbl.text = tr("SLOT_DETAILS") % [str(summary.get("timestamp", "-")), loc_display]
		details_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 1.0))
		if load_btn:
			load_btn.disabled = false
	else:
		details_lbl.text = tr("SLOT_EMPTY")
		details_lbl.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65, 0.8))
		if load_btn:
			load_btn.disabled = true


func _on_slot_save_clicked(slot: int) -> void:
	var save_mgr = _get_autoload("SaveManager")
	if not save_mgr:
		return

	var success: bool = save_mgr.save_game(slot)
	if success:
		if feedback_label:
			feedback_label.text = tr("SAVE_SUCCESS") % slot
			feedback_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55, 1.0))
		_refresh_slot_cards()
		saved.emit(slot)
	else:
		if feedback_label:
			feedback_label.text = tr("SAVE_FAIL")
			feedback_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35, 1.0))


func _on_slot_load_clicked(slot: int) -> void:
	var save_mgr = _get_autoload("SaveManager")
	if not save_mgr or not save_mgr.has_save(slot):
		return

	var ok = save_mgr.load_game(slot)
	if not ok:
		return

	visible = false
	var tree = _get_scene_tree()
	if tree:
		tree.paused = false

	var target_stage: String = "res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn"
	var gs = _get_autoload("GameState")
	if gs and not gs.current_stage_path.is_empty():
		target_stage = gs.current_stage_path

	var transition = _get_autoload("SceneTransition")
	if transition and transition.has_method("change_scene"):
		transition.change_scene(target_stage, 0.35)
	elif tree:
		tree.change_scene_to_file(target_stage)


# --- Ayarlar Paneli ---

func open_settings() -> void:
	_resolve_nodes()
	if settings_dialog:
		settings_dialog.open()


func close_settings() -> void:
	if btn_settings and btn_settings.is_inside_tree():
		btn_settings.grab_focus()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var is_escape: bool = event.keycode == KEY_ESCAPE \
			or event.physical_keycode == KEY_ESCAPE \
			or event.is_action_pressed("ui_cancel") \
			or event.is_action_pressed("pause")
		var is_p: bool = event.keycode == KEY_P or event.physical_keycode == KEY_P

		if is_escape or is_p:
			if settings_dialog and settings_dialog.visible:
				settings_dialog._on_back_pressed()
				get_viewport().set_input_as_handled()
				return
			elif save_slots_panel and save_slots_panel.visible:
				close_save_slots()
				get_viewport().set_input_as_handled()
				return
			else:
				resume_game()
				get_viewport().set_input_as_handled()
				return

	elif event is InputEventJoypadButton and event.pressed and not event.echo:
		if event.button_index == JOY_BUTTON_START:
			if settings_dialog and settings_dialog.visible:
				settings_dialog._on_back_pressed()
			elif save_slots_panel and save_slots_panel.visible:
				close_save_slots()
			else:
				resume_game()
			get_viewport().set_input_as_handled()
