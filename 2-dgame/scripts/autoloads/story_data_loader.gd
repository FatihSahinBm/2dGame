extends Node

## res://scripts/autoloads/story_data_loader.gd
## Hikaye, diyalog ve metin verilerini data/ altındaki JSON dosyalarından yükler.

const CHAPTER_1_PATH: String = "res://data/story/chapter_1_stone_age.json"
const CHAPTER_2_PATH: String = "res://data/story/chapter_2_vlad.json"

static var _cached_data: Dictionary = {}
static var _current_loaded_path: String = ""


func _ready() -> void:
	load_chapter_data(CHAPTER_1_PATH)


## JSON dosyasını okuyup sözlük olarak döndürür
static func load_chapter_data(path: String = CHAPTER_2_PATH) -> Dictionary:
	if _current_loaded_path == path and not _cached_data.is_empty():
		return _cached_data

	if not FileAccess.file_exists(path):
		push_error("Story file not found: " + path)
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open story file: " + path)
		return {}

	var json_text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_text)
	if error != OK:
		push_error("JSON Parse Error in " + path + ": " + json.get_error_message())
		return {}

	if json.data is Dictionary:
		_cached_data = json.data as Dictionary
		_current_loaded_path = path
		return _cached_data

	return {}


## Belirli bir diyalog veya metin grubunu döndürür
static func get_dialogue_sequence(key: String, path: String = "") -> Array:
	var target_path: String = path if not path.is_empty() else (_current_loaded_path if not _current_loaded_path.is_empty() else CHAPTER_2_PATH)
	var data: Dictionary = load_chapter_data(target_path)
	if data.has("dialogues") and data["dialogues"].has(key):
		return data["dialogues"][key]
	return []


## Rastgele asker bağırtısı seçer
static func get_random_shout(betrayal: bool = false) -> String:
	var key: String = "soldier_betrayal_shouts" if betrayal else "soldier_ambient_shouts"
	var list: Array = get_dialogue_sequence(key)
	if list.is_empty():
		return "Hücum!" if not betrayal else "Hain!"
	return list.pick_random() as String
