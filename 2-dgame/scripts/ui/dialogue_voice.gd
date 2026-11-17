extends RefCounted

## res://scripts/ui/dialogue_voice.gd
## Diyalog yazı efekti için karaktere özel kısa "konuşma tıkı" sesleri (Story 2D-120).
## Her karakter aynı kısa sesi farklı perdeyle kullanır; anlatım satırları (portre "none") sessizdir.
## Sesler tek atımlıktır: yazma bitince veya diyalog atlanınca çalan uzun bir ses kalmaz.

const BLIP_SOUND_KEY: String = "ui_click"
const BLIP_BUS: String = "Dialogue"
const BLIP_VOLUME_DB: float = -16.0
## Kaç görünür karakterde bir ses çalınacağı
const CHARS_PER_BLIP: int = 3
const DEFAULT_PITCH: float = 1.0

## Portre anahtarı -> perde. 0.0 = sessiz.
const PITCH_BY_PORTRAIT: Dictionary = {
	"player": 1.0,
	"player_dark": 0.72,
	"friend_memory": 1.25,
	"fatih": 0.8,
	"janissary": 0.92,
	"archer": 1.1,
	"caveman": 0.68,
	"blood_knight": 0.58,
	"vlad": 0.62,
	"none": 0.0,
}


static func get_pitch(portrait: String) -> float:
	return float(PITCH_BY_PORTRAIT.get(portrait, DEFAULT_PITCH))


## Bu karakter yazıldığında ses çalınmalı mı? (boşluk ve noktalama sessizdir)
static func should_blip(portrait: String, char_index: int, character: String) -> bool:
	if get_pitch(portrait) <= 0.0 or char_index % CHARS_PER_BLIP != 0:
		return false
	return not character.strip_edges().is_empty() and not ".,;:!?…*'\"-—".contains(character)


## Yazı efekti her yeni karakter gösterdiğinde çağrılır
static func on_char_typed(host: Node, portrait: String, char_index: int, character: String) -> void:
	if not should_blip(portrait, char_index, character) or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var audio_mgr: Node = host.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx") and audio_mgr.has_method("has_sound") and audio_mgr.has_sound(BLIP_SOUND_KEY):
		audio_mgr.play_sfx(BLIP_SOUND_KEY, BLIP_VOLUME_DB, get_pitch(portrait), BLIP_BUS)
