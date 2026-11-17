extends Node

## res://scripts/autoloads/comfort_settings.gd
## Erişilebilirlik ve oynanış konforu seçenekleri (Story 2D-118).
## - dialogue_text_scale: diyalog metni boyutu çarpanı (yalnızca tanımlı kademeler).
## - hold_to_attack: saldırı tuşu basılı tutulduğunda saldırı kendiliğinden tekrarlanır.
## - color_assist: yalnızca renkle verilen bilgilere simge/yazı eşlik eder (ör. yozlaşma kademesi).
## Ekran sarsıntısı yoğunluğu CameraManager'da, hareketi/yanıp sönmeyi azaltma CinematicManager'dadır.
## Ayarlar ortak user://game_settings.json içine "comfort_settings" anahtarıyla oku-birleştir-yaz
## yöntemiyle kaydedilir. Bu seçenekler yalnızca sunumu ve girdiyi etkiler; oynanış verisini değiştirmez.

signal settings_changed()

const SETTINGS_PATH: String = "user://game_settings.json"
const SETTINGS_KEY: String = "comfort_settings"
const TEXT_SCALES: Array[float] = [1.0, 1.15, 1.3]
const DEFAULT_TEXT_SCALE: float = 1.0
## Basılı tutarken iki saldırı denemesi arasındaki en kısa süre (sn)
const HOLD_ATTACK_INTERVAL: float = 0.12

## Yozlaşma kademesi simgeleri (color_assist açıkken renge ek olarak gösterilir)
const TIER_SYMBOLS: Dictionary = {"pure": "○", "tainted": "◔", "corrupted": "◑", "dark": "●"}

var dialogue_text_scale: float = DEFAULT_TEXT_SCALE
var hold_to_attack: bool = false
var color_assist: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func sanitize_text_scale(value: float) -> float:
	for allowed: float in TEXT_SCALES:
		if is_equal_approx(allowed, value):
			return allowed
	return DEFAULT_TEXT_SCALE


func apply_dictionary(data: Dictionary) -> void:
	dialogue_text_scale = sanitize_text_scale(float(data.get("dialogue_text_scale", DEFAULT_TEXT_SCALE)) if typeof(data.get("dialogue_text_scale", 1.0)) in [TYPE_FLOAT, TYPE_INT] else DEFAULT_TEXT_SCALE)
	hold_to_attack = bool(data.get("hold_to_attack", false))
	color_assist = bool(data.get("color_assist", false))


func to_dictionary() -> Dictionary:
	return {
		"dialogue_text_scale": dialogue_text_scale,
		"hold_to_attack": hold_to_attack,
		"color_assist": color_assist,
	}


func set_dialogue_text_scale(value: float) -> void:
	dialogue_text_scale = sanitize_text_scale(value)
	_commit()


func set_hold_to_attack(enabled: bool) -> void:
	hold_to_attack = enabled
	_commit()


func set_color_assist(enabled: bool) -> void:
	color_assist = enabled
	_commit()


func get_tier_symbol(tier: String) -> String:
	return str(TIER_SYMBOLS.get(tier, "")) if color_assist else ""


func load_settings() -> bool:
	var stored: Variant = _read_file().get(SETTINGS_KEY, null)
	if not stored is Dictionary:
		return false
	apply_dictionary(stored as Dictionary)
	return true


func save_settings() -> void:
	var existing: Dictionary = _read_file()
	existing[SETTINGS_KEY] = to_dictionary()
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(existing, "\t"))
		file.close()


func _commit() -> void:
	save_settings()
	settings_changed.emit()


func _read_file() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}
