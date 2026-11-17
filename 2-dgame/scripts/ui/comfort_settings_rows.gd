extends Node

## res://scripts/ui/comfort_settings_rows.gd
## Ayarlar penceresine erişilebilirlik satırlarını ekler (Story 2D-118):
## diyalog metni boyutu, basılı tutarak saldırı, renk yardımı.
## Değerler /root/ComfortSettings üzerinden uygulanır ve kaydedilir.

const SELF_SCRIPT_PATH: String = "res://scripts/ui/comfort_settings_rows.gd"

var _grid: GridContainer = null
var _text_label: Label = null
var _text_option: OptionButton = null
var _hold_label: Label = null
var _hold_check: CheckBox = null
var _color_label: Label = null
var _color_check: CheckBox = null
var _syncing: bool = false


static func attach(dialog: Control, grid: GridContainer, after_node: Control) -> Node:
	if dialog == null or grid == null:
		return null
	var existing: Node = dialog.get_node_or_null("ComfortSettingsRows")
	if existing:
		return existing
	var rows: Node = (load(SELF_SCRIPT_PATH) as GDScript).new()
	rows.name = "ComfortSettingsRows"
	dialog.add_child(rows)
	rows.call("_build", dialog, grid, after_node)
	return rows


func _build(dialog: Control, grid: GridContainer, after_node: Control) -> void:
	_grid = grid
	var at: int = after_node.get_index() + 1 if after_node and after_node.get_parent() == grid else grid.get_child_count()
	_text_label = _add(Label.new(), "DialogueTextSizeLabel", at) as Label
	_text_option = _add(OptionButton.new(), "DialogueTextSizeOption", at + 1) as OptionButton
	_text_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hold_label = _add(Label.new(), "HoldToAttackLabel", at + 2) as Label
	_hold_check = _add(CheckBox.new(), "HoldToAttackCheck", at + 3) as CheckBox
	_color_label = _add(Label.new(), "ColorAssistLabel", at + 4) as Label
	_color_check = _add(CheckBox.new(), "ColorAssistCheck", at + 5) as CheckBox

	_text_option.item_selected.connect(_on_text_selected)
	_hold_check.toggled.connect(_on_hold_toggled)
	_color_check.toggled.connect(_on_color_toggled)
	dialog.visibility_changed.connect(refresh)
	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager")
	if loc_mgr and loc_mgr.has_signal("locale_changed"):
		loc_mgr.locale_changed.connect(func(_locale: String) -> void: refresh())
	refresh()


func refresh() -> void:
	var comfort: Node = _comfort()
	if comfort == null or _text_option == null:
		return
	_syncing = true
	_text_label.text = tr("SETTINGS_DIALOGUE_TEXT_SIZE")
	_hold_label.text = tr("SETTINGS_HOLD_TO_ATTACK")
	_color_label.text = tr("SETTINGS_COLOR_ASSIST")
	_text_option.clear()
	var keys: Array[String] = ["TEXT_SIZE_NORMAL", "TEXT_SIZE_LARGE", "TEXT_SIZE_XLARGE"]
	var selected: int = 0
	for i: int in range(comfort.TEXT_SCALES.size()):
		_text_option.add_item(tr(keys[mini(i, keys.size() - 1)]))
		if is_equal_approx(comfort.TEXT_SCALES[i], comfort.dialogue_text_scale):
			selected = i
	_text_option.select(selected)
	_hold_check.set_pressed_no_signal(comfort.hold_to_attack)
	_hold_check.text = "✓" if comfort.hold_to_attack else "✕"
	_color_check.set_pressed_no_signal(comfort.color_assist)
	_color_check.text = "✓" if comfort.color_assist else "✕"
	_syncing = false


func _on_text_selected(index: int) -> void:
	var comfort: Node = _comfort()
	if comfort and not _syncing and index >= 0 and index < comfort.TEXT_SCALES.size():
		comfort.set_dialogue_text_scale(comfort.TEXT_SCALES[index])


func _on_hold_toggled(pressed: bool) -> void:
	var comfort: Node = _comfort()
	if comfort and not _syncing:
		comfort.set_hold_to_attack(pressed)
		_hold_check.text = "✓" if pressed else "✕"


func _on_color_toggled(pressed: bool) -> void:
	var comfort: Node = _comfort()
	if comfort and not _syncing:
		comfort.set_color_assist(pressed)
		_color_check.text = "✓" if pressed else "✕"


func _comfort() -> Node:
	return get_node_or_null("/root/ComfortSettings") if is_inside_tree() else null


func _add(control: Control, node_name: String, index: int) -> Control:
	control.name = node_name
	_grid.add_child(control)
	_grid.move_child(control, mini(index, _grid.get_child_count() - 1))
	return control
