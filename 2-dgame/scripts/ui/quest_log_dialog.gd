class_name QuestLogDialog
extends Control

## res://scripts/ui/quest_log_dialog.gd
## Story 2D-121: Görev Günlüğü Penceresi (Quest Log UI Dialog).
## Aktif ve tamamlanan görevleri, aşama kontrol listesini ve ödülleri listeler.

signal opened()
signal closed()
signal quest_selected(quest: Dictionary)
signal tracked_quest_requested(quest_id: String)

@onready var tabs_container: HBoxContainer = get_node_or_null("Panel/VBox/TabsContainer")
@onready var btn_active_tab: Button = get_node_or_null("Panel/VBox/TabsContainer/BtnActive")
@onready var btn_completed_tab: Button = get_node_or_null("Panel/VBox/TabsContainer/BtnCompleted")
@onready var quest_list_container: VBoxContainer = get_node_or_null("Panel/VBox/MainSplit/LeftPane/Scroll/QuestList")
@onready var title_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/Header/TitleLabel")
@onready var category_badge: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/Header/CategoryBadge")
@onready var desc_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/DescScroll/DescLabel")
@onready var stages_container: VBoxContainer = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/StagesContainer")
@onready var reward_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/RewardContainer/RewardLabel")
@onready var btn_track: Button = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/TrackContainer/BtnTrack")
@onready var btn_close: Button = get_node_or_null("Panel/VBox/Footer/BtnClose")

var _current_tab: String = "active" # "active" or "completed"
var _selected_quest_id: String = ""
var _was_paused_before_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if btn_active_tab:
		btn_active_tab.pressed.connect(func(): _switch_tab("active"))
	if btn_completed_tab:
		btn_completed_tab.pressed.connect(func(): _switch_tab("completed"))
	if btn_close:
		btn_close.pressed.connect(close)
	if btn_track:
		btn_track.pressed.connect(_on_track_pressed)

	# QuestManager sinyallerine bağlan
	var q_mgr = _get_quest_manager()
	if q_mgr:
		q_mgr.quest_updated.connect(_on_quest_data_changed)
		q_mgr.quest_completed.connect(_on_quest_data_changed)
		q_mgr.tracked_quest_changed.connect(_on_quest_data_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		# [J] veya [L] tuşu ile Günlüğü Aç
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_J or event.physical_keycode == KEY_J \
					or event.keycode == KEY_L or event.physical_keycode == KEY_L:
				open()
				get_viewport().set_input_as_handled()
		return

	# Günlük açıkken: Kapatma kontrolleri ([ESC], [J], [L], Gamepad B/Start)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE \
				or event.keycode == KEY_J or event.physical_keycode == KEY_J \
				or event.keycode == KEY_L or event.physical_keycode == KEY_L:
			close()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB:
			# Tab tuşu ile sekmeler arası geçiş
			_switch_tab("completed" if _current_tab == "active" else "active")
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventJoypadButton and event.pressed and not event.echo:
		if event.button_index == JOY_BUTTON_B or event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_BACK:
			close()
			get_viewport().set_input_as_handled()
			return


func open() -> void:
	_was_paused_before_open = get_tree().paused
	get_tree().paused = true
	visible = true

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("quest_log_open", -1.0)

	_refresh_ui()
	opened.emit()


func close() -> void:
	if not _was_paused_before_open:
		get_tree().paused = false
	visible = false

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("quest_log_close", -1.0)

	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _switch_tab(tab_name: String) -> void:
	_current_tab = tab_name

	if btn_active_tab:
		btn_active_tab.modulate = Color(1.2, 1.2, 1.2, 1.0) if _current_tab == "active" else Color(0.65, 0.65, 0.7, 0.8)
	if btn_completed_tab:
		btn_completed_tab.modulate = Color(1.2, 1.2, 1.2, 1.0) if _current_tab == "completed" else Color(0.65, 0.65, 0.7, 0.8)

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", -3.0)

	_refresh_ui()


func _refresh_ui() -> void:
	if not quest_list_container:
		return

	# Önceki butonları temizle
	for ch in quest_list_container.get_children():
		ch.queue_free()

	var q_mgr = _get_quest_manager()
	if not q_mgr:
		return

	var quest_list: Array[Dictionary] = q_mgr.get_active_quests() if _current_tab == "active" else q_mgr.get_completed_quests()

	if quest_list.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Bu sekmede görev bulunmuyor." if _current_tab == "active" else "Henüz tamamlanan görev yok."
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7, 0.8))
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		quest_list_container.add_child(empty_lbl)
		_show_quest_detail({})
		return

	# Seçili görev hala listede mi kontrol et
	var found_selected: bool = false
	for q in quest_list:
		if q["id"] == _selected_quest_id:
			found_selected = true
			break
	if not found_selected:
		_selected_quest_id = str(quest_list[0]["id"])

	# Butonları oluştur
	for q in quest_list:
		var btn = Button.new()
		var is_main = q.get("category", "main") == "main"
		var prefix = "👑 [ANA] " if is_main else "🏹 [YAN] "
		var is_tracked = (q["id"] == q_mgr.tracked_quest_id and q.get("status") == "active")
		var track_mark = " 🎯" if is_tracked else ""

		btn.text = prefix + str(q.get("title", "")) + track_mark
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11)

		if q["id"] == _selected_quest_id:
			btn.modulate = Color(1.2, 1.1, 0.6, 1.0)
		else:
			btn.modulate = Color(0.9, 0.9, 0.95, 0.9)

		var q_id = q["id"]
		btn.pressed.connect(func():
			_selected_quest_id = q_id
			_refresh_ui()
		)
		quest_list_container.add_child(btn)

	# Seçili detayı göster
	var current_q = q_mgr.get_quest(_selected_quest_id)
	_show_quest_detail(current_q)


func select_quest(quest_id: String) -> void:
	_selected_quest_id = quest_id
	_refresh_ui()


func get_selected_quest_id() -> String:
	return _selected_quest_id


func _show_quest_detail(q: Dictionary) -> void:
	if q.is_empty():
		if title_label: title_label.text = "Görev Seçilmedi"
		if category_badge: category_badge.visible = false
		if desc_label: desc_label.text = ""
		if reward_label: reward_label.text = ""
		if btn_track: btn_track.visible = false
		_clear_stages()
		return

	if title_label:
		title_label.text = str(q.get("title", ""))

	var is_main = q.get("category", "main") == "main"
	if category_badge:
		category_badge.visible = true
		category_badge.text = "👑 ANA GÖREV" if is_main else "🏹 YAN GÖREV"
		category_badge.modulate = Color(1.0, 0.8, 0.2, 1.0) if is_main else Color(0.4, 0.85, 1.0, 1.0)

	if desc_label:
		desc_label.text = str(q.get("description", ""))

	if reward_label:
		var rew = str(q.get("reward_text", ""))
		reward_label.text = "🎁 Ödül: %s" % rew if not rew.is_empty() else ""

	# Hedef aşamaları kontrol listesi
	_clear_stages()
	var stages = q.get("stages", [])
	if stages_container:
		for i in range(stages.size()):
			var st = stages[i]
			var is_done = bool(st.get("completed", false))
			var is_current = (i == int(q.get("current_stage", 0)) and q.get("status") == "active")

			var lbl = Label.new()
			var check = "✔ " if is_done else ("➤ " if is_current else "○ ")
			lbl.text = check + str(st.get("description", ""))
			lbl.add_theme_font_size_override("font_size", 11)

			if is_done:
				lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5, 0.85))
			elif is_current:
				lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
			else:
				lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 0.7))

			stages_container.add_child(lbl)

	# Takip etme butonu
	if btn_track:
		var q_mgr = _get_quest_manager()
		var is_active = (q.get("status") == "active")
		var is_already_tracked = (q_mgr and q_mgr.tracked_quest_id == q["id"])

		btn_track.visible = is_active
		if is_already_tracked:
			btn_track.text = "🎯 Takip Ediliyor"
			btn_track.disabled = true
			btn_track.modulate = Color(0.7, 0.9, 0.7, 0.8)
		else:
			btn_track.text = "Takip Et"
			btn_track.disabled = false
			btn_track.modulate = Color.WHITE

	quest_selected.emit(q)


func _clear_stages() -> void:
	if stages_container:
		for ch in stages_container.get_children():
			ch.queue_free()


func _on_track_pressed() -> void:
	var q_mgr = _get_quest_manager()
	if q_mgr and not _selected_quest_id.is_empty():
		q_mgr.set_tracked_quest(_selected_quest_id)
		tracked_quest_requested.emit(_selected_quest_id)
		_refresh_ui()


func _on_quest_data_changed(_a = null, _b = null, _c = null) -> void:
	if visible:
		_refresh_ui()


func _get_quest_manager() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		var node = get_tree().root.get_node_or_null("QuestManager")
		if node:
			return node
	var fallback = get_node_or_null("/root/QuestManager")
	if fallback:
		return fallback
	return null
