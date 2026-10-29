extends Node

## res://scripts/autoloads/story_data_loader.gd
## Hikaye, diyalog ve metin verilerini data/ altındaki JSON dosyalarından yükler.
## Yerelleştirme (i18n) desteğiyle TR ve EN dillerine anlık uyum sağlar — Story 2D-119

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


## Belirli bir diyalog veya metin grubunu yerelleştirilmiş olarak döndürür
static func get_dialogue_sequence(key: String, path: String = "") -> Array:
	var raw_list: Array = []
	if not path.is_empty():
		var explicit_data: Dictionary = load_chapter_data(path)
		if explicit_data.has("dialogues") and explicit_data["dialogues"].has(key):
			raw_list = explicit_data["dialogues"][key]
	else:
		# 1. Önce aktif yüklü bölümde ara
		var active_path: String = _current_loaded_path if not _current_loaded_path.is_empty() else CHAPTER_2_PATH
		var active_data: Dictionary = load_chapter_data(active_path)
		if active_data.has("dialogues") and active_data["dialogues"].has(key):
			raw_list = active_data["dialogues"][key]
		else:
			# 2. Bulunamadıysa diğer tüm bilinen bölümlerde ara (fallback)
			for ch_path in ALL_CHAPTER_PATHS:
				if ch_path == active_path:
					continue
				var alt_data: Dictionary = load_chapter_data(ch_path)
				if alt_data.has("dialogues") and alt_data["dialogues"].has(key):
					raw_list = alt_data["dialogues"][key]
					break

	if raw_list.is_empty():
		push_warning("StoryDataLoader: Dialogue key '%s' not found in any chapter!" % key)
		return []

	return _localize_dialogue_sequence(raw_list)


static func _localize_dialogue_sequence(raw_list: Array) -> Array:
	var loc: String = "tr"
	var eng_tree = Engine.get_main_loop() as SceneTree
	if eng_tree and eng_tree.root and eng_tree.root.has_node("LocalizationManager"):
		loc = eng_tree.root.get_node("LocalizationManager").get_current_locale()
	if loc != "en":
		var godot_loc = TranslationServer.get_locale().to_lower()
		if godot_loc.begins_with("en"):
			loc = "en"

	var localized: Array = []
	for item in raw_list:
		if item is Dictionary:
			var d: Dictionary = (item as Dictionary).duplicate(true)
			# Metin alanı
			if loc == "en" and d.has("text_en") and not str(d["text_en"]).is_empty():
				d["text"] = str(d["text_en"])
			elif d.get("text") is Dictionary:
				d["text"] = (d["text"] as Dictionary).get(loc, (d["text"] as Dictionary).get("tr", ""))
			else:
				var translated = TranslationServer.translate(str(d.get("text", "")))
				if translated != str(d.get("text", "")):
					d["text"] = translated

			# Konuşmacı adı
			if loc == "en" and d.has("speaker_en") and not str(d["speaker_en"]).is_empty():
				d["speaker"] = str(d["speaker_en"])
			else:
				var tr_sp = TranslationServer.translate(str(d.get("speaker", "")))
				if tr_sp != str(d.get("speaker", "")):
					d["speaker"] = tr_sp

			# Başlık
			if loc == "en" and d.has("title_en") and not str(d["title_en"]).is_empty():
				d["title"] = str(d["title_en"])
			else:
				var tr_ti = TranslationServer.translate(str(d.get("title", "")))
				if tr_ti != str(d.get("title", "")):
					d["title"] = tr_ti

			# Seçenekler (varsa)
			if d.has("choices") and d["choices"] is Array:
				var choices_arr: Array = []
				for choice in d["choices"]:
					if choice is Dictionary:
						var c_dict: Dictionary = (choice as Dictionary).duplicate()
						if loc == "en" and c_dict.has("text_en"):
							c_dict["text"] = str(c_dict["text_en"])
						else:
							var tr_c = TranslationServer.translate(str(c_dict.get("text", "")))
							if tr_c != str(c_dict.get("text", "")):
								c_dict["text"] = tr_c
						choices_arr.append(c_dict)
					else:
						choices_arr.append(choice)
				d["choices"] = choices_arr

			localized.append(d)
		elif item is String:
			var tr_str = TranslationServer.translate(str(item))
			localized.append(tr_str)
		else:
			localized.append(item)

	return localized


## Rastgele asker bağırtısı seçer
static func get_random_shout(betrayal: bool = false) -> String:
	var key: String = "soldier_betrayal_shouts" if betrayal else "soldier_ambient_shouts"
	var list: Array = get_dialogue_sequence(key)
	if list.is_empty():
		return TranslationServer.translate("SHOUT_ATTACK") if not betrayal else TranslationServer.translate("SHOUT_TRAITOR")
	var pick = list.pick_random()
	if pick is Dictionary:
		return str(pick.get("text", "Hücum!"))
	return str(pick)


## Rastgele kılıç isyanı metni seçer
static func get_random_sword_rebellion_text() -> String:
	var list: Array = get_dialogue_sequence("sword_rebellion_texts")
	if list.is_empty():
		var hints = [
			TranslationServer.translate("SWORD_REBELLION_HINT_1"),
			TranslationServer.translate("SWORD_REBELLION_HINT_2"),
			TranslationServer.translate("SWORD_REBELLION_HINT_3")
		]
		return hints.pick_random() as String
	var pick = list.pick_random()
	if pick is Dictionary:
		return str(pick.get("text", "*Kılıç darbene direniyor!*"))
	return str(pick)
