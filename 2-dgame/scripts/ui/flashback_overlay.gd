class_name FlashbackOverlay
extends CanvasLayer

const StoryDataLoader = preload("res://scripts/autoloads/story_data_loader.gd")

## res://scripts/ui/flashback_overlay.gd
## Boss yenildiğinde tetiklenen Hafıza Flashback'i,
## Kan Sisi Atılması yetenek kazanımı ve Boyut Yırtığı kesme ara sahnesi.

signal flashback_finished()
signal dimensional_rift_cut()

@export var typewriter_speed: float = 0.03

var _entries: Array = []
var _current_idx: int = 0
var _is_typing: bool = false
var _full_text: String = ""
var _char_index: int = 0
var _type_timer: float = 0.0

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
	if not visible or ability_card.visible or rift_slash.visible:
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


## Flashback sekansını başlatır
func play_vlad_memory_sequence() -> void:
	visible = true
	content_box.visible = true
	if ability_card:
		ability_card.visible = false
	if rift_slash:
		rift_slash.visible = false

	# Sinematik kararış ve desatürasyon efekti
	background.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(background, "modulate:a", 0.92, 1.2)

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


func _advance_memory() -> void:
	_current_idx += 1
	_show_entry()


## Kan Sisi Atılması yeteneği kartını gösterir
func _show_ability_unlock() -> void:
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

	var tw: Tween = create_tween()
	tw.tween_property(ability_card, "modulate:a", 1.0, 0.6)

	get_tree().create_timer(4.0).timeout.connect(func():
		var tw_out: Tween = create_tween()
		tw_out.tween_property(ability_card, "modulate:a", 0.0, 0.5)
		tw_out.tween_callback(_cut_dimensional_rift)
	)


## Kılıcın uzay-zaman yırtığını kesmesi ve boyut geçişi
func _cut_dimensional_rift() -> void:
	if ability_card:
		ability_card.visible = false
	if not rift_slash:
		flashback_finished.emit()
		return

	rift_slash.visible = true
	rift_slash.scale = Vector2(0.01, 1.0)
	rift_slash.rotation_degrees = -35.0

	var tw: Tween = create_tween()
	tw.tween_property(rift_slash, "scale:x", 3.0, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rift_slash, "modulate", Color(2.5, 0.4, 0.6, 1.0), 0.2)
	tw.tween_property(background, "color", Color.WHITE, 0.2)
	tw.tween_callback(func():
		dimensional_rift_cut.emit()
		flashback_finished.emit()
	)
