class_name FlashbackOverlay
extends CanvasLayer

const StoryDataLoader = preload("res://scripts/autoloads/story_data_loader.gd")

## res://scripts/ui/flashback_overlay.gd
## Boss yenildiğinde tetiklenen Hafıza Flashback'i,
## Kan Sisi Atılması yetenek kazanımı ve Boyut Yırtığı kesme ara sahnesi.
## Story 2D-145: Görsel filtre (desatürasyon/soğuk ton), letterbox, geçiş animasyonları,
## diyalog yankı efekti, girdi kilidi, atlama (TAB), sahne atlama/yeniden başlatma güvenliği
## ve erişilebilirlik (hareketi azalt / yanıp sönmeyi azalt) desteği.

signal flashback_finished()
signal dimensional_rift_cut()
signal flashback_skipped()

enum Stage { IDLE, MEMORY, ABILITY, RIFT, DONE }

const FILTER_SHADER_CODE: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint = vec3(0.62, 0.72, 1.0);
void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 mem = vec3(g) * tint;
	COLOR = vec4(mix(c.rgb, mem, amount), 1.0);
}
"""

@export var typewriter_speed: float = 0.03
@export var letterbox_height: float = 64.0
@export var background_target_alpha: float = 0.86

var _entries: Array = []
var _current_idx: int = 0
var _is_typing: bool = false
var _full_text: String = ""
var _char_index: int = 0
var _type_timer: float = 0.0
var _stage: Stage = Stage.IDLE
var _finished_emitted: bool = false
var _ability_timer: SceneTreeTimer = null
var _tweens: Array[Tween] = []

var _filter_rect: ColorRect = null
var _filter_mat: ShaderMaterial = null
var _letterbox_top: ColorRect = null
var _letterbox_bottom: ColorRect = null
var _echo_label: Label = null

@onready var background: ColorRect = $Background
@onready var vignette: ColorRect = $Vignette
@onready var content_box: Control = $ContentBox
@onready var speaker_label: Label = $ContentBox/Speaker
@onready var text_label: Label = $ContentBox/Text
@onready var prompt_label: Label = $ContentBox/Prompt
@onready var ability_card: Panel = $AbilityCard
@onready var ability_title: Label = $AbilityCard/Title
@onready var ability_desc: Label = $AbilityCard/Desc
@onready var rift_slash: ColorRect = $RiftSlash


func _ready() -> void:
	visible = false
	if ability_card:
		ability_card.visible = false
	if rift_slash:
		rift_slash.visible = false
	_build_filter_and_letterbox()


func _exit_tree() -> void:
	# Sahne yeniden başlatma / değiştirme: girdi kilidini ve tween'leri serbest bırak
	_kill_tweens()
	if _stage != Stage.IDLE and _stage != Stage.DONE:
		_stage = Stage.IDLE
		var cm = get_node_or_null("/root/CinematicManager")
		if cm:
			cm.end_cinematic("flashback")


func is_playing() -> bool:
	return _stage != Stage.IDLE and _stage != Stage.DONE


func get_stage_name() -> String:
	return Stage.keys()[_stage]


# ---------------------------------------------------------------------------
# Filtre ve letterbox kurulumu
# ---------------------------------------------------------------------------
func _build_filter_and_letterbox() -> void:
	var shader := Shader.new()
	shader.code = FILTER_SHADER_CODE
	_filter_mat = ShaderMaterial.new()
	_filter_mat.shader = shader
	_filter_mat.set_shader_parameter("amount", 0.0)

	_filter_rect = ColorRect.new()
	_filter_rect.name = "MemoryFilter"
	_filter_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter_rect.material = _filter_mat
	add_child(_filter_rect)
	move_child(_filter_rect, 0)

	_letterbox_top = _make_bar("LetterboxTop", true)
	_letterbox_bottom = _make_bar("LetterboxBottom", false)


func _make_bar(bar_name: String, is_top: bool) -> ColorRect:
	var bar := ColorRect.new()
	bar.name = bar_name
	bar.color = Color.BLACK
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	if is_top:
		bar.anchor_top = 0.0
		bar.anchor_bottom = 0.0
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
	else:
		bar.anchor_top = 1.0
		bar.anchor_bottom = 1.0
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
	add_child(bar)
	return bar


func get_letterbox_amount() -> float:
	return _letterbox_top.offset_bottom if _letterbox_top else 0.0


func get_filter_amount() -> float:
	return float(_filter_mat.get_shader_parameter("amount")) if _filter_mat else 0.0


func _cm() -> Node:
	return get_node_or_null("/root/CinematicManager")


func _add_tween() -> Tween:
	var tw := create_tween()
	_tweens.append(tw)
	return tw


func _kill_tweens() -> void:
	for t in _tweens:
		if t and t.is_valid():
			t.kill()
	_tweens.clear()


func _set_letterbox(enable: bool, duration: float = 0.5) -> void:
	if not _letterbox_top or not _letterbox_bottom:
		return
	var h := letterbox_height if enable else 0.0
	var cm := _cm()
	if cm and cm.reduce_motion:
		duration = 0.0
	if duration <= 0.0:
		_letterbox_top.offset_bottom = h
		_letterbox_bottom.offset_top = -h
		return
	var tw := _add_tween().set_parallel(true)
	tw.tween_property(_letterbox_top, "offset_bottom", h, duration)
	tw.tween_property(_letterbox_bottom, "offset_top", -h, duration)


func _set_filter(amount: float, duration: float = 0.8) -> void:
	if not _filter_mat:
		return
	if duration <= 0.0:
		_filter_mat.set_shader_parameter("amount", amount)
		return
	var tw := _add_tween()
	var from := float(_filter_mat.get_shader_parameter("amount"))
	tw.tween_method(func(v: float): _filter_mat.set_shader_parameter("amount", v), from, amount, duration)


# ---------------------------------------------------------------------------
# Girdi
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not _is_typing:
		return

	_type_timer += delta
	if _type_timer >= typewriter_speed:
		_type_timer = 0.0
		_char_index += 1
		text_label.text = _full_text.substr(0, _char_index)
		if _char_index >= _full_text.length():
			_is_typing = false
			prompt_label.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_playing():
		return

	# TAB: Flashback'i atla (yetenek verilir, kontroller ve filtreler sıfırlanır)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		skip_flashback()
		return

	if _stage != Stage.MEMORY:
		return

	if (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_E)) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		if _is_typing:
			_is_typing = false
			text_label.text = _full_text
			prompt_label.visible = true
		else:
			_advance_memory()


# ---------------------------------------------------------------------------
# Akış
# ---------------------------------------------------------------------------
## Flashback sekansını başlatır
func play_vlad_memory_sequence() -> void:
	if is_playing():
		return
	_kill_tweens()
	_finished_emitted = false
	_stage = Stage.MEMORY
	visible = true
	content_box.visible = true
	if ability_card:
		ability_card.visible = false
	if rift_slash:
		rift_slash.visible = false

	# Oyuncu girdilerini kilitle (flashback süresince)
	var cm := _cm()
	if cm:
		cm.begin_cinematic("flashback")

	# Sinematik kararış, görsel filtre ve letterbox
	var fade_time: float = 1.2
	if cm:
		fade_time = cm.get_transition_duration(fade_time)
	background.color = Color(0.02, 0.02, 0.04, 1.0)
	background.modulate.a = 0.0
	var tw := _add_tween()
	tw.tween_property(background, "modulate:a", background_target_alpha, fade_time)
	_set_filter(1.0, fade_time)
	_set_letterbox(true, 0.6)

	prompt_label.text = tr("FLASHBACK_PROMPT")

	_entries = StoryDataLoader.get_dialogue_sequence("memory_flashback")
	_current_idx = 0
	_show_entry()


func _show_entry() -> void:
	if _current_idx >= _entries.size():
		_show_ability_unlock()
		return

	var item: Dictionary = _entries[_current_idx] as Dictionary
	speaker_label.text = item.get("speaker", "Kayıp Anı")
	_full_text = item.get("text", "")
	_char_index = 0
	_is_typing = true
	text_label.text = ""
	prompt_label.visible = false
	_show_echo(_full_text)


func _show_echo(text: String) -> void:
	# Hafıza yankısı: metnin soluk, kaymış kopyası (yanıp sönmeyi azalt açıksa nabız yok)
	if _echo_label and is_instance_valid(_echo_label):
		_echo_label.queue_free()
	_echo_label = Label.new()
	_echo_label.text = text
	_echo_label.position = text_label.position + Vector2(5.0, 3.0)
	_echo_label.size = text_label.size
	_echo_label.autowrap_mode = text_label.autowrap_mode
	_echo_label.label_settings = text_label.label_settings
	_echo_label.modulate = Color(0.55, 0.7, 1.0, 0.25)
	_echo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_box.add_child(_echo_label)
	content_box.move_child(_echo_label, text_label.get_index())
	var cm := _cm()
	if not (cm and cm.reduce_flashing):
		var tw := _echo_label.create_tween().set_loops(3)
		tw.tween_property(_echo_label, "modulate:a", 0.1, 0.7)
		tw.tween_property(_echo_label, "modulate:a", 0.28, 0.7)


func _clear_echo() -> void:
	if _echo_label and is_instance_valid(_echo_label):
		_echo_label.queue_free()
	_echo_label = null


func _advance_memory() -> void:
	_current_idx += 1
	_show_entry()


## Kan Sisi Atılması yeteneği kartını gösterir
func _show_ability_unlock() -> void:
	_stage = Stage.ABILITY
	_is_typing = false
	_clear_echo()
	content_box.visible = false
	if not ability_card:
		_cut_dimensional_rift()
		return

	# Autoload yeteneği aç
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("unlock_ability"):
		game_state.unlock_ability("blood_mist_dash")

	var data: Dictionary = StoryDataLoader.load_chapter_data()
	var ability_info: Dictionary = {}
	if data.has("dialogues") and data["dialogues"].has("ability_unlock"):
		ability_info = data["dialogues"]["ability_unlock"]

	ability_title.text = ability_info.get("name", "Kan Sisi Atılması (Blood Mist Dash)")
	ability_desc.text = ability_info.get("description", "Vampirik güç kılıcın yozlaşmış kabuğuna işlendi.")
	ability_card.visible = true
	ability_card.modulate.a = 0.0

	var tw := _add_tween()
	tw.tween_property(ability_card, "modulate:a", 1.0, 0.6)

	_ability_timer = get_tree().create_timer(4.0)
	_ability_timer.timeout.connect(_on_ability_timer)


func _on_ability_timer() -> void:
	if _stage != Stage.ABILITY or not is_instance_valid(self):
		return
	var tw_out := _add_tween()
	tw_out.tween_property(ability_card, "modulate:a", 0.0, 0.5)
	tw_out.tween_callback(_cut_dimensional_rift)


## Kılıcın uzay-zaman yırtığını kesmesi ve boyut geçişi
func _cut_dimensional_rift() -> void:
	if _stage == Stage.RIFT or _stage == Stage.DONE or _stage == Stage.IDLE:
		return
	_stage = Stage.RIFT
	if ability_card:
		ability_card.visible = false
	if not rift_slash:
		_finish()
		return

	var cm := _cm()
	var calm: bool = cm != null and (cm.reduce_motion or cm.reduce_flashing)

	if calm:
		# Erişilebilir sürüm: parlak flaş / hızlı kesik yerine yumuşak karartma
		rift_slash.visible = false
		var tw_calm := _add_tween()
		tw_calm.tween_property(background, "modulate:a", 1.0, 0.6)
		tw_calm.tween_callback(func():
			dimensional_rift_cut.emit()
			_finish()
		)
		return

	rift_slash.visible = true
	rift_slash.scale = Vector2(0.01, 1.0)
	rift_slash.rotation_degrees = -35.0

	var tw := _add_tween()
	tw.tween_property(rift_slash, "scale:x", 3.0, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rift_slash, "modulate", Color(2.5, 0.4, 0.6, 1.0), 0.2)
	tw.tween_property(background, "color", Color.WHITE, 0.2)
	tw.tween_callback(func():
		dimensional_rift_cut.emit()
		_finish()
	)


## Flashback'i atlar: kalan hafıza satırları geçilir, yetenek yine verilir
func skip_flashback() -> void:
	if not is_playing():
		return
	flashback_skipped.emit()
	_is_typing = false
	_clear_echo()
	if _stage == Stage.MEMORY:
		# Yetenek ödülünü kaybetme: unlock yap, kartı/yırtığı atla
		var game_state: Node = get_node_or_null("/root/GameState")
		if game_state and game_state.has_method("unlock_ability"):
			game_state.unlock_ability("blood_mist_dash")
		dimensional_rift_cut.emit()
	elif _stage == Stage.ABILITY or _stage == Stage.RIFT:
		dimensional_rift_cut.emit()
	_finish(true)


## Tüm filtreleri, letterbox'ı ve girdi kilidini sıfırlar; ardından flashback_finished yayar
func _finish(immediate: bool = false) -> void:
	if _stage == Stage.DONE or _stage == Stage.IDLE:
		return
	_stage = Stage.DONE
	_is_typing = false
	_ability_timer = null
	_kill_tweens()
	_clear_echo()

	# Görsel durumu sıfırla
	if ability_card:
		ability_card.visible = false
	if rift_slash:
		rift_slash.visible = false
		rift_slash.scale = Vector2(0.01, 1.0)
		rift_slash.modulate = Color.WHITE
	content_box.visible = false
	_set_filter(0.0, 0.0)
	_set_letterbox(false, 0.0)

	var cm := _cm()
	var fade: float = 0.0 if immediate else 0.4
	if cm and cm.reduce_motion:
		fade = 0.0
	if fade > 0.0:
		# Beyaz/karanlık ekrandan oyuna ani sıçrama yerine yumuşak çıkış
		var tw := _add_tween()
		tw.tween_property(background, "modulate:a", 0.0, fade)
		tw.tween_callback(_hide_and_reset_background)
	else:
		_hide_and_reset_background()

	# Kontrolleri geri aç
	if cm:
		cm.end_cinematic("flashback")

	if not _finished_emitted:
		_finished_emitted = true
		flashback_finished.emit()


func _hide_and_reset_background() -> void:
	background.modulate.a = 1.0
	background.color = Color(0.02, 0.02, 0.04, 1.0)
	visible = false
