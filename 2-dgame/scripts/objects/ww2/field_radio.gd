class_name FieldRadio
extends EgyptInteractable

## res://scripts/objects/ww2/field_radio.gd
## Sahra telsizi (Epic 2D-144), iki modlu:
##   sabotage   — Sessiz Batarya: Şifreli Telsiz Kodları envanterdeyse topçu koordinatları
##                bozulur (ww2_battery_silenced), aksi halde "kod gerekli" ipucu.
##   easter_egg — Kırık Telsiz Frekansı: Orok/Fatih/Vlad çağlarından parazitli yankılar ve
##                kılıçtaki Büyücünün fısıltısı; Codex kaydı açılır.
## Diyaloğu seviye oynatır (story_requested); durum kalıcıdır.

signal story_requested(dialogue_key: String)
signal battery_sabotaged()

const ChapterState = preload("res://scripts/components/ww2_chapter_state.gd")
const Inventory = preload("res://scripts/components/ww2_inventory.gd")
const EASTER_CODEX: String = "ww2_broken_frequency"

@export_enum("sabotage", "easter_egg") var mode: String = "sabotage"

var is_used: bool = false


func _interactable_ready() -> void:
	prompt_key = "PROMPT_WW2_RADIO"
	is_used = is_persisted("used") or (mode == "sabotage" and ChapterState.is_battery_silenced(self))
	if is_used:
		modulate = Color(0.75, 0.75, 0.75)


func _on_interact() -> void:
	_play("radio_static")
	if mode == "easter_egg":
		_listen_easter_egg()
	else:
		_try_sabotage()
	interaction_requested.emit(self)


func _try_sabotage() -> void:
	if is_used:
		story_requested.emit("ww2_battery_sabotaged")
		return
	if not Inventory.has_item(self, "radio_codes"):
		story_requested.emit("ww2_radio_needs_codes")
		return
	is_used = true
	persist("used")
	modulate = Color(0.75, 0.75, 0.75)
	ChapterState.set_flag(self, ChapterState.FLAG_BATTERY_SILENCED, true)
	battery_sabotaged.emit()
	story_requested.emit("ww2_battery_sabotaged")


func _listen_easter_egg() -> void:
	if not is_used:
		is_used = true
		persist("used")
		var codex: Node = get_node_or_null("/root/CodexManager")
		if codex and codex.has_method("unlock_entry"):
			codex.unlock_entry(EASTER_CODEX)
	_play("mage_vengeance_whisper")
	story_requested.emit("ww2_radio_easter_egg")


func _play(key: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d(key, global_position, null, -3.0, 800.0)
