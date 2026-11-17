extends CanvasLayer

## res://scripts/ui/results_screen.gd
## Bölüm/oyun sonu sonuç ekranı ve jenerik (Story 2D-153).
## Kod ile oluşturulur: ResultsScreen.show_for(level) çağrısı ekranı seviyeye ekler.
## İstatistikler /root/PlayStats özetinden, jenerik data/credits.json dosyasından gelir.

signal replay_requested()
signal menu_requested()

const SELF_PATH: String = "res://scripts/ui/results_screen.gd"
const CREDITS_PATH: String = "res://data/credits.json"
const NEW_GAME_SCENE: String = "res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn"

var _stats_label: Label = null
var _credits_label: Label = null
var _replay_button: Button = null
var _menu_button: Button = null
var _continue_button: Button = null
var _busy: bool = false
## Sonraki bölümün ilk sahnesi; boş değilse "Devam Et" düğmesi gösterilir (Epic 2D-143)
var next_scene_path: String = ""


static func show_for(host: Node, next_scene: String = "") -> CanvasLayer:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return null
	var existing: Node = host.get_node_or_null("ResultsScreen")
	if existing:
		return existing as CanvasLayer
	var screen: CanvasLayer = (load(SELF_PATH) as GDScript).new()
	screen.name = "ResultsScreen"
	screen.set("next_scene_path", next_scene)
	host.add_child(screen)
	return screen


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.03, 0.03, 0.06, 0.94)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 48)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title: Label = _label(24, Color(1.0, 0.88, 0.55))
	title.name = "TitleLabel"
	title.text = tr("RESULTS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var split: HBoxContainer = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 40)
	column.add_child(split)
	_stats_label = _label(14, Color(0.92, 0.93, 0.97))
	_stats_label.name = "StatsLabel"
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_stats_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	_credits_label = _label(12, Color(0.78, 0.82, 0.9))
	_credits_label.name = "CreditsLabel"
	_credits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credits_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_credits_label)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	column.add_child(buttons)
	_replay_button = Button.new()
	_replay_button.name = "ReplayButton"
	_replay_button.text = tr("RESULTS_REPLAY")
	_replay_button.pressed.connect(_on_replay_pressed)
	buttons.add_child(_replay_button)
	_menu_button = Button.new()
	_menu_button.name = "MenuButton"
	_menu_button.text = tr("RESULTS_MAIN_MENU")
	_menu_button.pressed.connect(_on_menu_pressed)
	buttons.add_child(_menu_button)
	if not next_scene_path.is_empty():
		_continue_button = Button.new()
		_continue_button.name = "ContinueButton"
		_continue_button.text = tr("RESULTS_CONTINUE")
		_continue_button.pressed.connect(_on_continue_pressed)
		buttons.add_child(_continue_button)
		buttons.move_child(_continue_button, 0)

	refresh()
	(_continue_button if _continue_button else _menu_button).grab_focus.call_deferred()


## İstatistik ve jenerik metinlerini güncel veriyle doldurur
func refresh() -> void:
	var stats: Node = get_node_or_null("/root/PlayStats")
	var summary: Dictionary = stats.get_summary() if stats and stats.has_method("get_summary") else {}
	_stats_label.text = build_stats_text(summary)
	_credits_label.text = build_credits_text(load_credits(), _is_english())


func build_stats_text(summary: Dictionary) -> String:
	var ending_key: String = "RESULTS_ENDING_" + str(summary.get("ending", "")).to_upper()
	var ending_text: String = tr(ending_key) if not str(summary.get("ending", "")).is_empty() else tr("RESULTS_ENDING_NONE")
	var lines: Array[String] = [
		"%s  %s" % [tr("RESULTS_TIME"), str(summary.get("time_text", "00:00:00"))],
		"%s  %d" % [tr("RESULTS_DEATHS"), int(summary.get("deaths", 0))],
		"%s  %d" % [tr("RESULTS_DAMAGE_TAKEN"), int(summary.get("damage_taken", 0))],
		"%s  %d" % [tr("RESULTS_BOSSES"), (summary.get("bosses_defeated", []) as Array).size()],
		"%s  %d" % [tr("RESULTS_ITEMS"), (summary.get("items_collected", []) as Array).size()],
		"%s  %d" % [tr("RESULTS_QUESTS"), int(summary.get("quests_completed", 0))],
		"%s  %d" % [tr("RESULTS_HEART_PIECES"), int(summary.get("heart_pieces", 0))],
		"%s  %d / 100" % [tr("RESULTS_CORRUPTION"), int(summary.get("corruption", 0))],
		"%s  %s" % [tr("RESULTS_ENDING"), ending_text],
	]
	return "\n".join(lines)


static func load_credits() -> Dictionary:
	if not FileAccess.file_exists(CREDITS_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


static func build_credits_text(credits: Dictionary, english: bool) -> String:
	var lines: Array[String] = []
	for section: Variant in credits.get("sections", []) as Array:
		var sec: Dictionary = section as Dictionary
		lines.append(str(sec.get("title_en", sec.get("title", ""))) if english else str(sec.get("title", "")))
		for entry: Variant in sec.get("entries", []) as Array:
			var item: Dictionary = entry as Dictionary
			var role: String = str(item.get("role_en", item.get("role", ""))) if english else str(item.get("role", ""))
			lines.append("   %s — %s" % [str(item.get("name", "")), role])
		lines.append("")
	return "\n".join(lines)


func _on_replay_pressed() -> void:
	if _busy:
		return
	_busy = true
	replay_requested.emit()
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("reset_state"):
		game_state.reset_state()
	var stats: Node = get_node_or_null("/root/PlayStats")
	if stats and stats.has_method("reset"):
		stats.reset()
	_go_to(NEW_GAME_SCENE)


## Sonraki bölüme geçiş: ilerleme korunur (yeni oyun sıfırlaması yapılmaz)
func _on_continue_pressed() -> void:
	if _busy or next_scene_path.is_empty():
		return
	_busy = true
	_go_to(next_scene_path)


func _on_menu_pressed() -> void:
	if _busy:
		return
	_busy = true
	menu_requested.emit()
	_go_to(str(ProjectSettings.get_setting("application/run/main_scene", "res://scenes/ui/main_menu.tscn")))


func _go_to(scene_path: String) -> void:
	var transition: Node = get_node_or_null("/root/SceneTransition")
	if transition and transition.has_method("change_scene"):
		transition.change_scene(scene_path, 0.4)
	else:
		get_tree().change_scene_to_file(scene_path)


func _is_english() -> bool:
	return TranslationServer.get_locale().to_lower().begins_with("en")


func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
