class_name HieroglyphTablet
extends EgyptInteractable

## res://scripts/objects/egypt/hieroglyph_tablet.gd
## Hiyeroglif lore tableti (Epic 2D-143). [E] ile okunduğunda bağlı Codex girişini açar ve
## read_requested(dialogue_key) yayar; diyalogu seviye oynatır. Okunma durumu kalıcıdır.

signal read_requested(dialogue_key: String)

@export var codex_entry_id: String = ""
@export var dialogue_key: String = ""

var has_been_read: bool = false


func _interactable_ready() -> void:
	prompt_key = "PROMPT_EGYPT_TABLET"
	has_been_read = is_persisted("read")
	if has_been_read:
		modulate = Color(0.8, 0.8, 0.8)


func _on_interact() -> void:
	if not has_been_read:
		has_been_read = true
		persist("read")
		modulate = Color(0.8, 0.8, 0.8)
		var codex: Node = get_node_or_null("/root/CodexManager")
		if codex and codex.has_method("unlock_entry") and not codex_entry_id.is_empty():
			codex.unlock_entry(codex_entry_id)
	read_requested.emit(dialogue_key)
	interaction_requested.emit(self)
