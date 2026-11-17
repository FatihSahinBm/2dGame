class_name FutureLoreTerminal
extends EgyptInteractable

## res://scripts/objects/future/future_lore_terminal.gd
## İncelenebilir / taranabilir lore nesnesi (Epic 2D-158): şema tarama noktaları (Geçmişe Düşen
## Enkazın Sırrı), Unit-REX-01 telemetri terminali, bozuk hologram arşivi ve yamalı zaman radyosu.
## [E] ile incelenince: Codex kaydı açılır, scan_id varsa FutureChapterState'e taranmış yazılır,
## hikâye anahtarı (story_requested) yayılır, ilk incelemede bonus eşya verilir.
## play_sound: radyo gibi nesneler incelenince bir ses anahtarı çalar.

signal story_requested(dialogue_key: String)
signal scanned(scan_id: String, all_done: bool)
signal reward_granted(item_id: String, amount: int)

const ChapterState = preload("res://scripts/components/future_chapter_state.gd")
const Inventory = preload("res://scripts/components/future_inventory.gd")
const FutureFx = preload("res://scripts/effects/future_fx.gd")

@export var interact_prompt: String = "PROMPT_FUT_INSPECT"
@export var codex_entry_id: String = ""
@export var dialogue_key: String = ""
@export var scan_id: String = ""
@export var reward_item: String = ""
@export var reward_amount: int = 0
@export var play_sound: String = ""

var has_been_read: bool = false


func _interactable_ready() -> void:
	prompt_key = interact_prompt
	has_been_read = is_persisted("read") or (not scan_id.is_empty() and ChapterState.is_scanned(self, scan_id))
	if has_been_read:
		modulate = Color(0.8, 0.85, 0.9)


func _on_interact() -> void:
	if not has_been_read:
		has_been_read = true
		persist("read")
		modulate = Color(0.8, 0.85, 0.9)
		var codex: Node = get_node_or_null("/root/CodexManager")
		if codex and codex.has_method("unlock_entry") and not codex_entry_id.is_empty():
			codex.unlock_entry(codex_entry_id)
		if not reward_item.is_empty() and reward_amount > 0:
			Inventory.add(self, reward_item, reward_amount)
			reward_granted.emit(reward_item, reward_amount)
		if not scan_id.is_empty():
			scanned.emit(scan_id, ChapterState.mark_scanned(self, scan_id))
		FutureFx.play_vfx(get_parent(), FutureFx.VFX_TIME_FRACTURE, global_position + Vector2(0.0, -40.0), 0.4)
	if not play_sound.is_empty():
		FutureFx.sfx(self, play_sound, global_position, -4.0)
	story_requested.emit(dialogue_key)
	interaction_requested.emit(self)
