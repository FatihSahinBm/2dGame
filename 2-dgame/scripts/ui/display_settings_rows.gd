extends Node

## res://scripts/ui/display_settings_rows.gd
## Ayarlar penceresinin ızgarasına görüntü satırlarını ekler (Story 2D-114):
## ekran modu, çözünürlük, VSync ve FPS sınırı. Değerler /root/DisplaySettings üzerinden
## uygulanır ve kaydedilir. settings_dialog.gd'yi büyütmemek için ayrı bileşendir.
## Kullanım: DisplaySettingsRows.attach(dialog, grid, after_node)

const SELF_SCRIPT_PATH: String = "res://scripts/ui/display_settings_rows.gd"

var _grid: GridContainer = null
var _mode_label: Label = null
var _mode_option: OptionButton = null
var _resolution_label: Label = null
var _resolution_option: OptionButton = null
var _vsync_label: Label = null
var _vsync_check: CheckBox = null
var _fps_label: Label = null
var _fps_option: OptionButton = null
var _resolutions: Array[Vector2i] = []
var _syncing: bool = false


## Satırları ızgarada after_node'un hemen ardına ekler ve bileşeni döndürür
static func attach(dialog: Control, grid: GridContainer, after_node: Control) -> Node:
	if dialog == null or grid == null:
		return null
	var existing: Node = dialog.get_node_or_null("DisplaySettingsRows")
	if existing:
		return existing
	var rows: Node = (load(SELF_SCRIPT_PATH) as GDScript).new()
	rows.name = "DisplaySettingsRows"
	dialog.add_child(rows)
	rows.call("_build", dialog, grid, after_node)
	return rows


func _build(dialog: Control, grid: GridContainer, after_node: Control) -> void:
	_grid = grid
	var insert_at: int = after_node.get_index() + 1 if after_node and after_node.get_parent() == grid else grid.get_child_count()

	_mode_label = _add_label("DisplayModeLabel", insert_at)
	_mode_option = _add_option("DisplayModeOption", insert_at + 1)
	_resolution_label = _add_label("ResolutionLabel", insert_at + 2)
	_resolution_option = _add_option("ResolutionOption", insert_at + 3)
	_vsync_label = _add_label("VsyncLabel", insert_at + 4)
	_vsync_check = CheckBox.new()
	_vsync_check.name = "VsyncCheck"
	_place(_vsync_check, insert_at + 5)
	_fps_label = _add_label("FpsLimitLabel", insert_at + 6)
	_fps_option = _add_option("FpsLimitOption", insert_at + 7)

	_mode_option.item_selected.connect(_on_mode_selected)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_vsync_check.toggled.connect(_on_vsync_toggled)
	_fps_option.item_selected.connect(_on_fps_selected)

	dialog.visibility_changed.connect(refresh)
	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager")
	if loc_mgr and loc_mgr.has_signal("locale_changed"):
		loc_mgr.locale_changed.connect(func(_locale: String) -> void: refresh())
	var display: Node = _display()
	if display and display.has_signal("settings_changed"):
		display.settings_changed.connect(refresh)
	refresh()


## Metinleri ve seçili değerleri güncel dil ve ayarlarla yeniler
func refresh() -> void:
	var display: Node = _display()
	if display == null or _mode_option == null:
		return
	_syncing = true
	_mode_label.text = tr("SETTINGS_DISPLAY_MODE")
	_resolution_label.text = tr("SETTINGS_RESOLUTION")
	_vsync_label.text = tr("SETTINGS_VSYNC")
	_fps_label.text = tr("SETTINGS_FPS_LIMIT")

	_mode_option.clear()
	for mode: String in display.WINDOW_MODES:
		_mode_option.add_item(tr("DISPLAY_MODE_" + mode.to_upper()))
	_mode_option.select(maxi(display.WINDOW_MODES.find(display.window_mode), 0))

	_resolutions = display.get_supported_resolutions()
	_resolution_option.clear()
	for size: Vector2i in _resolutions:
		_resolution_option.add_item("%d × %d" % [size.x, size.y])
	_resolution_option.select(maxi(_resolutions.find(display.resolution), 0))
	# Çözünürlük yalnızca pencereli modda pencere boyutunu belirler
	_resolution_option.disabled = display.is_fullscreen()

	_vsync_check.set_pressed_no_signal(display.vsync_enabled)
	_vsync_check.text = "✓" if display.vsync_enabled else "✕"

	_fps_option.clear()
	for limit: int in display.FPS_LIMITS:
		_fps_option.add_item(tr("FPS_UNLIMITED") if limit == 0 else "%d FPS" % limit)
	_fps_option.select(maxi(display.FPS_LIMITS.find(display.fps_limit), 0))
	_syncing = false


func _on_mode_selected(index: int) -> void:
	var display: Node = _display()
	if display and not _syncing and index >= 0 and index < display.WINDOW_MODES.size():
		display.set_window_mode(display.WINDOW_MODES[index])


func _on_resolution_selected(index: int) -> void:
	var display: Node = _display()
	if display and not _syncing and index >= 0 and index < _resolutions.size():
		display.set_resolution(_resolutions[index])


func _on_vsync_toggled(pressed: bool) -> void:
	var display: Node = _display()
	if display and not _syncing:
		display.set_vsync_enabled(pressed)


func _on_fps_selected(index: int) -> void:
	var display: Node = _display()
	if display and not _syncing and index >= 0 and index < display.FPS_LIMITS.size():
		display.set_fps_limit(display.FPS_LIMITS[index])


func _display() -> Node:
	return get_node_or_null("/root/DisplaySettings") if is_inside_tree() else null


func _add_label(node_name: String, index: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	_place(label, index)
	return label


func _add_option(node_name: String, index: int) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.name = node_name
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_place(option, index)
	return option


func _place(control: Control, index: int) -> void:
	_grid.add_child(control)
	_grid.move_child(control, mini(index, _grid.get_child_count() - 1))
