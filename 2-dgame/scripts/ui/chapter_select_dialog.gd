extends PanelContainer

## res://scripts/ui/chapter_select_dialog.gd
## Bölüm Seçimi ve Tekrar Oynama Menüsü

signal chapter_selected(chapter_index: int, stage_path: String)
signal closed()

@onready var chapter_list: VBoxContainer = $Margin/VBox/Scroll/ChapterList
@onready var back_button: Button = $Margin/VBox/BackButton

const CHAPTERS: Array[Dictionary] = [
	{
		"index": 1,
		"title": "Bölüm 1: İlkel Vadi ve Siber Tyrant",
		"era": "M.Ö. 65 Milyon Yıl — Tarih Öncesi Kanyon",
		"scene": "res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn"
	},
	{
		"index": 2,
		"title": "Bölüm 2: Târgovişte Gece Ormanı ve Kan Kalesi",
		"era": "1462 — Eflak Prensliği & Kazıklı Voyvoda",
		"scene": "res://scenes/levels/vlad/stage_1_forest_camp.tscn"
	}
]

var _first_focus_btn: Button = null


func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	hide()


func open() -> void:
	_populate_chapters()
	show()
	if _first_focus_btn and not _first_focus_btn.disabled and _first_focus_btn.is_inside_tree():
		_first_focus_btn.grab_focus()
	elif back_button and back_button.is_inside_tree():
		back_button.grab_focus()


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


func _populate_chapters() -> void:
	if not chapter_list:
		return

	# Temizle
	for child in chapter_list.get_children():
		child.queue_free()

	_first_focus_btn = null
	var save_mgr = _get_autoload("SaveManager")

	for ch in CHAPTERS:
		var ch_idx: int = int(ch["index"])
		var is_unlocked: bool = true
		if save_mgr and save_mgr.has_method("is_chapter_unlocked"):
			is_unlocked = save_mgr.is_chapter_unlocked(ch_idx)

		var card: PanelContainer = PanelContainer.new()
		var card_box: HBoxContainer = HBoxContainer.new()
		card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var info_box: VBoxContainer = VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var title_lbl: Label = Label.new()
		title_lbl.text = str(ch["title"])
		title_lbl.add_theme_font_size_override("font_size", 16)
		if not is_unlocked:
			title_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
		else:
			title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1.0))

		var era_lbl: Label = Label.new()
		era_lbl.text = str(ch["era"])
		era_lbl.add_theme_font_size_override("font_size", 12)
		era_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1.0))

		info_box.add_child(title_lbl)
		info_box.add_child(era_lbl)

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(120, 38)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		if is_unlocked:
			btn.text = "Oyna"
			var scene_path: String = str(ch["scene"])
			btn.pressed.connect(func(): _on_chapter_clicked(ch_idx, scene_path))
			if not _first_focus_btn:
				_first_focus_btn = btn
		else:
			btn.text = "🔒 Kilitli"
			btn.disabled = true

		card_box.add_child(info_box)
		card_box.add_child(btn)
		card.add_child(card_box)
		chapter_list.add_child(card)

	_setup_focus_chain()


func _setup_focus_chain() -> void:
	if not is_inside_tree():
		return
	var buttons: Array[Button] = []
	for card in chapter_list.get_children():
		var hbox = card.get_child(0) if card.get_child_count() > 0 else null
		if hbox:
			for item in hbox.get_children():
				if item is Button and not item.disabled and item.is_inside_tree():
					buttons.append(item)
	if back_button and back_button.is_inside_tree():
		buttons.append(back_button)

	for i in range(buttons.size()):
		var curr = buttons[i]
		var prev = buttons[(i - 1 + buttons.size()) % buttons.size()]
		var next = buttons[(i + 1) % buttons.size()]
		if curr.is_inside_tree() and prev.is_inside_tree() and next.is_inside_tree():
			curr.focus_neighbor_top = prev.get_path()
			curr.focus_neighbor_bottom = next.get_path()


func _on_chapter_clicked(ch_idx: int, scene_path: String) -> void:
	hide()
	chapter_selected.emit(ch_idx, scene_path)


func _on_back_pressed() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
