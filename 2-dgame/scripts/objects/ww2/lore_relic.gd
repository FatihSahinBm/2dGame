class_name LoreRelic
extends EgyptInteractable

## res://scripts/objects/ww2/lore_relic.gd
## İncelenebilir lore nesnesi / easter egg (Epic 2D-144): Geleceğin Damgası Planları,
## Sığınak Mahzeni Arması. [E] ile incelenince Codex kaydı açılır, hikâye anahtarı
## (story_requested) yayılır ve ilk incelemede isteğe bağlı bonus ödül (eşya) verilir.

signal story_requested(dialogue_key: String)
signal reward_granted(item_id: String, amount: int)

const Inventory = preload("res://scripts/components/ww2_inventory.gd")

@export var codex_entry_id: String = ""
@export var dialogue_key: String = ""
@export var reward_item: String = ""
@export var reward_amount: int = 0

var has_been_read: bool = false


func _interactable_ready() -> void:
	prompt_key = "PROMPT_WW2_INSPECT"
	has_been_read = is_persisted("read")
	if has_been_read:
		modulate = Color(0.85, 0.85, 0.85)


func _on_interact() -> void:
	if not has_been_read:
		has_been_read = true
		persist("read")
		modulate = Color(0.85, 0.85, 0.85)
		var codex: Node = get_node_or_null("/root/CodexManager")
		if codex and codex.has_method("unlock_entry") and not codex_entry_id.is_empty():
			codex.unlock_entry(codex_entry_id)
		if not reward_item.is_empty() and reward_amount > 0:
			Inventory.add(self, reward_item, reward_amount)
			reward_granted.emit(reward_item, reward_amount)
	story_requested.emit(dialogue_key)
	interaction_requested.emit(self)
