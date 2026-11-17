extends RefCounted

## res://scripts/enemies/future/ai_lord_phases.gd
## AI Lord form tanımları (Epic 2D-158). Her form kendi SpriteFrames paketini, hızını,
## saldırı aralığını, hareket tipini ve saldırı listesini taşır. Geçiş eşikleri can oranına göredir.
##   Form 1 — Algoritmik Hükümdar (ai_lord_sovereign): lazer ağı, zaman-bükücü dron çağrısı, blink
##   Form 2 — Ağır Sibernetik Titan (ai_lord_titan):   omuz lazer topu, hidrolik sıçrayış, enerji kalkanı, taret desteği
##   Form 3 — Çekirdek Tekilliği (ai_lord_singularity): zaman dondurma alanı, dijital yankı klonu, çapraz çekirdek ışınları

const FORM_2_RATIO: float = 0.66
const FORM_3_RATIO: float = 0.33

const FORMS: Dictionary = {
	1: {
		"frames": "res://assets/characters/future/ai_lord_sovereign/ai_lord_sovereign_frames.tres",
		"move_anim": &"hover_move", "telegraph_anim": &"telegraph_grid",
		"speed": 80.0, "attack_interval": 2.0, "hover": true,
		"attacks": ["lattice", "drones", "blink"], "music_phase": 1,
	},
	2: {
		"frames": "res://assets/characters/future/ai_lord_titan/ai_lord_titan_frames.tres",
		"move_anim": &"heavy_walk", "telegraph_anim": &"telegraph_slam",
		"speed": 65.0, "attack_interval": 1.8, "hover": false,
		"attacks": ["cannon", "leap", "turrets"], "music_phase": 2,
	},
	3: {
		"frames": "res://assets/characters/future/ai_lord_singularity/ai_lord_singularity_frames.tres",
		"move_anim": &"move", "telegraph_anim": &"time_blink",
		"speed": 95.0, "attack_interval": 1.5, "hover": false,
		"attacks": ["freeze", "echo", "cross"], "music_phase": 3,
	},
}

## Form 1 dron çağrısı ve Form 2 taret desteği taban değerleri (Siber-Ağ Kesintisi %50 azaltır)
const BASE_DRONES: int = 4
const BASE_TURRETS: int = 4
const TURRET_TIME: float = 8.0

## Form 2 enerji kalkanı: saldırı türüne göre kalkan aşınması (savuşturma/ağır saldırı kırar)
const SHIELD_MAX: float = 100.0
const SHIELD_POISE_BY_ATTACK: Dictionary = {
	"light": 6.0, "combo": 8.0, "crouch": 6.0, "heavy": 34.0, "plunge": 40.0, "parry": 55.0, "emp": 60.0, "plasma": 20.0,
}
const SHIELD_DAMAGE_FACTOR: float = 0.2
const GROGGY_TIME: float = 3.5
const GROGGY_DAMAGE_MULT: float = 1.3
const HOVER_HEIGHT: float = 90.0
const DEATH_SEQUENCE_TIME: float = 2.4


static func form_for_ratio(ratio: float) -> int:
	if ratio <= FORM_3_RATIO:
		return 3
	if ratio <= FORM_2_RATIO:
		return 2
	return 1


static func get_form(form: int) -> Dictionary:
	return FORMS.get(clampi(form, 1, 3), FORMS[1]) as Dictionary


static func load_frames(form: int) -> SpriteFrames:
	var path: String = str(get_form(form).get("frames", ""))
	return load(path) as SpriteFrames if ResourceLoader.exists(path) else null


## Formun manifestinden sprite ofseti: ayak çıpası (ya da süzülen formda gövde merkezi) orijine gelir
static func sprite_offset_y(form: int, scale_y: float) -> float:
	var path: String = str(get_form(form).get("frames", "")).replace("_frames.tres", "_manifest.json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not (parsed is Dictionary):
		return 0.0
	var size: Array = (parsed as Dictionary).get("frame_size", [0, 0])
	return (float(size[1]) * 0.5 - float((parsed as Dictionary).get("feet_y", size[1]))) * scale_y


static func shield_poise_for(attack_type: String) -> float:
	return float(SHIELD_POISE_BY_ATTACK.get(attack_type, 6.0))


## Forma göre saldırı seçimi (sırayla döner; mesafeye göre öncelik)
static func choose_attack(form: int, distance: float, turn: int) -> String:
	var list: Array = get_form(form).get("attacks", []) as Array
	if list.is_empty():
		return ""
	if form == 2 and distance < 150.0:
		return "leap" if turn % 2 == 0 else "cannon"
	if form == 3 and distance < 110.0:
		return "echo" if turn % 3 == 0 else "freeze"
	return str(list[turn % list.size()])
