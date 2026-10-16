class_name DialogueBox
extends CanvasLayer

const StoryDataLoader = preload("res://scripts/autoloads/story_data_loader.gd")

## res://scripts/ui/dialogue_box.gd
## Alt panel RPG tarzı diyalog arayüzü kontrolcüsü.
## data/ altındaki JSON diyalog dizilerini sırayla oynatır.

signal dialogue_started()
signal dialogue_completed()

@export var typewriter_speed: float = 0.025

var _dialogue_queue: Array = []
var _current_index: int = 0
var _is_typing: bool = false
var _full_text: String = ""
var _type_timer: float = 0.0
var _char_index: int = 0

@onready var panel: Control = $Panel
@onready var speaker_name_label: Label = $Panel/SpeakerName
@onready var speaker_title_label: Label = $Panel/SpeakerTitle
@onready var content_label: Label = $Panel/ContentLabel
@onready var portrait_rect: ColorRect = $Panel/PortraitContainer/PortraitColor
@onready var continue_prompt: Label = $Panel/ContinuePrompt


func _ready() -> void:
	add_to_group("dialogue_box")
	if panel:
		panel.visible = false


func _process(delta: float) -> void:
	if not _is_typing:
		return

	_type_timer += delta
	if _type_timer >= typewriter_speed:
		_type_timer = 0.0
		_char_index += 1
		content_label.text = _full_text.substr(0, _char_index)
		if _char_index >= _full_text.length():
			_is_typing = false
			if continue_prompt:
				continue_prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return

	if (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_E)) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		if _is_typing:
			# Daktilo efektini atla, metnin tamamını göster
			_is_typing = false
			content_label.text = _full_text
			if continue_prompt:
				continue_prompt.visible = true
		else:
			_advance_dialogue()


## StoryDataLoader üzerindeki bir diyalog anahtarıyla başlatır
func start_dialogue_from_data(key: String) -> void:
	var list: Array = StoryDataLoader.get_dialogue_sequence(key)
	if list.is_empty():
		return
	start_dialogue(list)


## Doğrudan sözlük dizisiyle başlatır
func start_dialogue(entries: Array) -> void:
	if entries.is_empty():
		return

	_dialogue_queue = entries.duplicate()
	_current_index = 0
	panel.visible = true
	dialogue_started.emit()
	_show_current_entry()


func _show_current_entry() -> void:
	if _current_index >= _dialogue_queue.size():
		_close_dialogue()
		return

	var entry: Dictionary = _dialogue_queue[_current_index] as Dictionary
	speaker_name_label.text = entry.get("speaker", "Bilinmeyen")
	speaker_title_label.text = entry.get("title", "")
	_full_text = entry.get("text", "")
	_char_index = 0
	_is_typing = true
	content_label.text = ""
	if continue_prompt:
		continue_prompt.visible = false

	# Portre rengi/stili
	var portrait_type: String = entry.get("portrait", "")
	_apply_portrait_style(portrait_type)


func _apply_portrait_style(portrait_type: String) -> void:
	if not portrait_rect:
		return

	match portrait_type:
		"fatih":
			portrait_rect.color = Color(0.85, 0.65, 0.2, 1.0) # Osmanlı altını
		"janissary":
			portrait_rect.color = Color(0.8, 0.25, 0.25, 1.0) # Yeniçeri kırmızısı
		"player":
			portrait_rect.color = Color(0.35, 0.45, 0.65, 1.0) # Savaşçı çeliği
		"player_dark":
			portrait_rect.color = Color(0.4, 0.1, 0.2, 1.0) # Karanlık ego
		"vlad":
			portrait_rect.color = Color(0.75, 0.1, 0.15, 1.0) # Kan kırmızısı
		"friend_memory":
			portrait_rect.color = Color(0.2, 0.8, 0.9, 1.0) # Saf ruh mavisi
		_:
			portrait_rect.color = Color(0.3, 0.3, 0.35, 1.0)


func _advance_dialogue() -> void:
	_current_index += 1
	_show_current_entry()


func _close_dialogue() -> void:
	panel.visible = false
	dialogue_completed.emit()
