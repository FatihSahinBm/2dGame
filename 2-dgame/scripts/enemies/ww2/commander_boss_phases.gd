extends RefCounted

## res://scripts/enemies/ww2/commander_boss_phases.gd
## Cani Komutan form tanımları (Epic 2D-144). Her form kendi SpriteFrames sheet'ini,
## VFX aura animasyonunu, hızını, saldırı aralığını ve hareket tipini (yürüme/süzülme) taşır.
## Form geçiş eşikleri can oranına göredir.
##   Form 1 — Demir Komutan:          keskin nişancı, süngü hücumu, telsizle topçu çağrısı
##   Form 2 — Okült Zırhlı Mekanizma: şok dalgası sıçrayışı, ağır yumruk, taret desteği; duruş kalkanı
##   Form 3 — Çöken Çekirdek:         süzülme, çapraz ışınlar, arena daralması, deney çağrısı

const FORM_2_RATIO: float = 0.66
const FORM_3_RATIO: float = 0.33

const FORMS: Dictionary = {
	1: {
		"frames": "res://assets/characters/ww2/commander/commander_form1_frames.tres",
		"aura": &"smoke", "speed": 85.0, "attack_interval": 1.9, "hover": false,
		"attacks": ["sniper", "bayonet", "radio"], "music_phase": 1,
	},
	2: {
		"frames": "res://assets/characters/ww2/commander/commander_form2_frames.tres",
		"aura": &"occult", "speed": 70.0, "attack_interval": 1.7, "hover": false,
		"attacks": ["leap", "punch", "turrets"], "music_phase": 2,
	},
	3: {
		"frames": "res://assets/characters/ww2/commander/commander_form3_frames.tres",
		"aura": &"core", "speed": 95.0, "attack_interval": 1.45, "hover": true,
		"attacks": ["beams", "shrink", "summon"], "music_phase": 3,
	},
}

## Duruş kalkanı (Form 2): saldırı türüne göre kalkan hasarı
const SHIELD_MAX: float = 100.0
const SHIELD_POISE_BY_ATTACK: Dictionary = {
	"light": 8.0, "combo": 10.0, "crouch": 8.0, "heavy": 34.0, "plunge": 45.0, "grenade": 40.0, "parry": 50.0,
}
const SHIELD_DAMAGE_FACTOR: float = 0.2
const GROGGY_TIME: float = 3.5
const GROGGY_DAMAGE_MULT: float = 1.3
const HOVER_HEIGHT: float = 110.0


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


static func shield_poise_for(attack_type: String) -> float:
	return float(SHIELD_POISE_BY_ATTACK.get(attack_type, 8.0))
