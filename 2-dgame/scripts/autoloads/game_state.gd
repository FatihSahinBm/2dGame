extends Node

## res://scripts/autoloads/game_state.gd
## Küresel Oyun Durumu, Ahlak Sistemi ve Yetenek Yönetimi Autoload'u.

signal corruption_changed(new_score: int)
signal ally_betrayed(soldier_type: String, is_drained: bool)
signal ability_unlocked(ability_id: String)
signal sword_rebellion_triggered()

# --- Ahlak ve Yozlaşma Durumu ---
var corruption_score: int = 0:
	set(val):
		corruption_score = clampi(val, 0, 100)
		corruption_changed.emit(corruption_score)

var allies_sacrificed_count: int = 0
var allies_killed_count: int = 0
var current_heart_pieces: int = 1 # 1. Parça (T-Rex) tamamlandı varsayılır

# --- Kazanılan Yetenekler ---
var unlocked_abilities: Array[String] = []

# --- Bölüm Durumu ---
var current_stage_path: String = "res://scenes/levels/vlad/stage_1_forest_camp.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Yozlaşma puanı ekler ve kılıç isyanı sinyalini tetikler
func add_corruption(amount: int) -> void:
	corruption_score += amount
	sword_rebellion_triggered.emit()


## Müttefik askeri kurban etme (Aktif Sömürü)
## Geriye kazanılan can miktarını döndürür
func register_ally_sacrifice(soldier_type: String = "janissary") -> int:
	allies_sacrificed_count += 1
	add_corruption(20) # Aktif sömürü ciddi yozlaşma puanı verir
	ally_betrayed.emit(soldier_type, true)
	return 40 # +40 Can yenileme


## Dost ateşi ile müttefik askeri öldürme (Pasif kaza veya acımasız katletme)
func register_ally_kill(soldier_type: String = "janissary") -> void:
	allies_killed_count += 1
	add_corruption(12)
	ally_betrayed.emit(soldier_type, false)


## Yetenek kontrolü
func has_ability(ability_id: String) -> bool:
	return unlocked_abilities.has(ability_id)


## Yeni yetenek kilidi açma
func unlock_ability(ability_id: String) -> void:
	if not unlocked_abilities.has(ability_id):
		unlocked_abilities.append(ability_id)
		ability_unlocked.emit(ability_id)


## Oyun sonu eğilimini döndürür ("redemption" veya "god_king")
func get_ending_alignment() -> String:
	# Eğer müttefik sömürüsü ve katliamı yüksekse Tanrı-Kral yozlaşmasına gider
	if corruption_score >= 50 or allies_sacrificed_count >= 3:
		return "god_king"
	return "redemption"


## Yeni oyun / sıfırlama
func reset_state() -> void:
	corruption_score = 0
	allies_sacrificed_count = 0
	allies_killed_count = 0
	unlocked_abilities.clear()
	current_heart_pieces = 1
