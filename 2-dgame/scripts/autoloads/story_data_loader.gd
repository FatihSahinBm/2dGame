extends Node

## res://scripts/autoloads/story_data_loader.gd
## Hikaye, diyalog ve metin verilerini data/ altındaki JSON dosyalarından yükler.

const CHAPTER_1_PATH: String = "res://data/story/chapter_1_stone_age.json"
const CHAPTER_2_PATH: String = "res://data/story/chapter_2_vlad.json"
const ALL_CHAPTER_PATHS: Array[String] = [CHAPTER_2_PATH, CHAPTER_1_PATH]

static var _cached_chapters: Dictionary = {}
static var _current_loaded_path: String = CHAPTER_2_PATH


func _ready() -> void:
	# Tüm bölümlerin hikaye verilerini önbelleğe al
	load_chapter_data(CHAPTER_2_PATH)
	load_chapter_data(CHAPTER_1_PATH)


## JSON dosyasını okuyup sözlük olarak döndürür
static func load_chapter_data(path: String = "") -> Dictionary:
	var target_path: String = path if not path.is_empty() else (_current_loaded_path if not _current_loaded_path.is_empty() else CHAPTER_2_PATH)

	if _cached_chapters.has(target_path) and not _cached_chapters[target_path].is_empty():
		_current_loaded_path = target_path
		return _cached_chapters[target_path]

	if not FileAccess.file_exists(target_path):
		push_error("Story file not found: " + target_path)
		return {}

	var file: FileAccess = FileAccess.open(target_path, FileAccess.READ)
	if not file:
		push_error("Failed to open story file: " + target_path)
		return {}

	var json_text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_text)
	if error != OK:
		push_error("JSON Parse Error in " + target_path + ": " + json.get_error_message())
		return {}

	if json.data is Dictionary:
		var data_dict: Dictionary = json.data as Dictionary
		_cached_chapters[target_path] = data_dict
		_current_loaded_path = target_path
		return data_dict

	return {}


## Belirli bir diyalog veya metin grubunu döndürür
static func get_dialogue_sequence(key: String, path: String = "") -> Array:
	if not path.is_empty():
		var explicit_data: Dictionary = load_chapter_data(path)
		if explicit_data.has("dialogues") and explicit_data["dialogues"].has(key):
			return explicit_data["dialogues"][key]
		return []

	# 1. Önce aktif yüklü bölümde ara
	var active_path: String = _current_loaded_path if not _current_loaded_path.is_empty() else CHAPTER_2_PATH
	var active_data: Dictionary = load_chapter_data(active_path)
	if active_data.has("dialogues") and active_data["dialogues"].has(key):
		return active_data["dialogues"][key]

	# 2. Bulunamadıysa diğer tüm bilinen bölümlerde ara (fallback)
	for ch_path in ALL_CHAPTER_PATHS:
		if ch_path == active_path:
			continue
		var alt_data: Dictionary = load_chapter_data(ch_path)
		if alt_data.has("dialogues") and alt_data["dialogues"].has(key):
			return alt_data["dialogues"][key]

	push_warning("StoryDataLoader: Dialogue key '%s' not found in any chapter!" % key)
	return []


## Rastgele asker bağırtısı seçer
static func get_random_shout(betrayal: bool = false) -> String:
	var key: String = "soldier_betrayal_shouts" if betrayal else "soldier_ambient_shouts"
	var list: Array = get_dialogue_sequence(key)
	if list.is_empty():
		return "Hücum!" if not betrayal else "Hain!"
	return list.pick_random() as String


## Rastgele kılıç isyanı metni seçer
static func get_random_sword_rebellion_text() -> String:
	var list: Array = get_dialogue_sequence("sword_rebellion_texts")
	if list.is_empty():
		return "*Kılıç darbene direniyor!*"
	return list.pick_random() as String


