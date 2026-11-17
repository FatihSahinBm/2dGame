extends Control

## res://scripts/ui/loading_overlay.gd
## Yükleme ekranı (Story 2D-152): ilerleme çubuğu, yüzde, ipucu metni ve hata mesajı.
## SceneTransition tarafından kod ile oluşturulur; yüzde gerçek yükleme durumundan beslenir.

const TIP_KEYS: Array[String] = ["LOADING_TIP_1", "LOADING_TIP_2", "LOADING_TIP_3", "LOADING_TIP_4", "LOADING_TIP_5"]

var _title: Label = null
var _bar: ProgressBar = null
var _percent: Label = null
var _tip: Label = null
var _tip_index: int = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(420, 0)
	box.position = Vector2(-210, -60)
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	_title = _make_label(18, Color(1.0, 0.9, 0.65))
	box.add_child(_title)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(420, 14)
	box.add_child(_bar)
	_percent = _make_label(12, Color(0.85, 0.85, 0.9))
	box.add_child(_percent)
	_tip = _make_label(12, Color(0.75, 0.8, 0.9))
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(420, 40)
	box.add_child(_tip)


## Yükleme başlarken çağrılır: yeni bir ipucu seçer ve çubuğu sıfırlar
func begin() -> void:
	_tip_index = (_tip_index + 1) % TIP_KEYS.size()
	_title.text = tr("LOADING_TITLE")
	_title.modulate = Color.WHITE
	_tip.text = tr(TIP_KEYS[_tip_index])
	_bar.visible = true
	set_progress(0.0)
	visible = true


## ratio: 0.0 – 1.0 arası gerçek yükleme oranı
func set_progress(ratio: float) -> void:
	var clamped: float = clampf(ratio, 0.0, 1.0)
	_bar.value = clamped * 100.0
	_percent.text = "%d%%" % int(round(clamped * 100.0))


func get_progress_percent() -> int:
	return int(round(_bar.value))


func show_error(message: String) -> void:
	_title.text = tr("LOADING_FAILED_TITLE")
	_title.modulate = Color(1.0, 0.45, 0.4)
	_bar.visible = false
	_percent.text = ""
	_tip.text = message
	visible = true


func get_tip_text() -> String:
	return _tip.text


func finish() -> void:
	visible = false


func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
