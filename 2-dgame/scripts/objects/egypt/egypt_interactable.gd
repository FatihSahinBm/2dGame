class_name EgyptInteractable
extends Area2D

## res://scripts/objects/egypt/egypt_interactable.gd
## Bölüm 3 etkileşimli nesneleri için ortak taban (Epic 2D-143): oyuncu menzil takibi,
## [E]/interact girdisi ve yerelleştirilmiş istem etiketi. Alt sınıflar _on_interact() yazar.

signal interaction_requested(source: Node)

const WorldObjectState = preload("res://scripts/components/world_object_state.gd")

@export var prompt_key: String = "PROMPT_EGYPT_INSPECT"
@export var prompt_offset: Vector2 = Vector2(-60.0, -90.0)

var player_in_range: bool = false
var interaction_enabled: bool = true
var _prompt: Label = null


func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 4
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt = Label.new()
	_prompt.name = "PromptLabel"
	_prompt.position = prompt_offset
	_prompt.add_theme_font_size_override("font_size", 11)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.visible = false
	add_child(_prompt)
	_interactable_ready()


## Alt sınıf kurulum kancası
func _interactable_ready() -> void:
	pass


## Alt sınıf etkileşim davranışı
func _on_interact() -> void:
	interaction_requested.emit(self)


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	_refresh_prompt()


func is_prompt_visible() -> bool:
	return _prompt != null and _prompt.visible


func interact() -> void:
	if interaction_enabled:
		_on_interact()


func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range or not interaction_enabled:
		return
	var pressed: bool = InputMap.has_action("interact") and event.is_action_pressed("interact")
	if pressed or (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_E):
		get_viewport().set_input_as_handled()
		interact()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_refresh_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		_refresh_prompt()


func _refresh_prompt() -> void:
	if _prompt:
		_prompt.text = tr(prompt_key)
		_prompt.visible = player_in_range and interaction_enabled


func persist(state: String) -> void:
	WorldObjectState.mark(self, state)


func is_persisted(state: String) -> bool:
	return WorldObjectState.is_set(self, state)
