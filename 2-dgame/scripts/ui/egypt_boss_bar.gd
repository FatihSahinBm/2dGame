class_name EgyptBossBar
extends CanvasLayer

## res://scripts/ui/egypt_boss_bar.gd
## Firavun Kral can çubuğu (Epic 2D-143): ekran üstünde boss adı, faz göstergesi ve can barı.

const PHASE_COLORS: Array[Color] = [Color(0.95, 0.75, 0.25), Color(0.95, 0.75, 0.25), Color(1.0, 0.5, 0.15), Color(0.9, 0.2, 0.25)]

var _bar: ProgressBar = null
var _title: Label = null
var _fill: StyleBoxFlat = null


func _ready() -> void:
	layer = 20
	var root: VBoxContainer = VBoxContainer.new()
	root.anchor_left = 0.4
	root.anchor_right = 0.8
	root.anchor_top = 0.0
	root.anchor_bottom = 0.0
	root.offset_top = 14.0
	root.offset_bottom = 58.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 13)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 4)
	root.add_child(_title)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0.0, 12.0)
	_bar.show_percentage = false
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.07, 0.05, 0.9)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.7, 0.55, 0.2)
	_fill = StyleBoxFlat.new()
	_fill.bg_color = PHASE_COLORS[1]
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", _fill)
	root.add_child(_bar)
	visible = false


func setup(title_key: String, max_hp: int) -> void:
	_title.text = tr(title_key)
	_bar.max_value = max_hp
	_bar.value = max_hp
	visible = true


func set_health(current_hp: int, max_hp: int) -> void:
	_bar.max_value = max_hp
	create_tween().tween_property(_bar, "value", float(current_hp), 0.2)
	if current_hp <= 0:
		var tw: Tween = create_tween()
		tw.tween_interval(0.6)
		tw.tween_callback(hide)


func set_phase(phase: int) -> void:
	_fill.bg_color = PHASE_COLORS[clampi(phase, 1, 3)]


func get_value() -> float:
	return _bar.value
