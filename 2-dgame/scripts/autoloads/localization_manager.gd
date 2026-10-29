extends Node

## res://scripts/autoloads/localization_manager.gd
## Türkçe ve İngilizce Yerelleştirme ve Dil Yöneticisi — Story 2D-119
## TranslationServer ile tam entegre; anlık dil değişimi, ayar kalıcılığı ve eksik anahtar koruması.

signal locale_changed(new_locale: String)

const DEFAULT_LOCALE: String = "tr"
const SETTINGS_PATH: String = "user://game_settings.json"
const TRANSLATIONS_JSON_PATH: String = "res://data/translations/translations.json"

var current_locale: String = DEFAULT_LOCALE
var _translations_data: Dictionary = {}
var _missing_keys: Array[String] = []
var _is_initialized: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	initialize_translations()
	load_saved_locale()


func initialize_translations() -> void:
	if _is_initialized:
		return

	var file: FileAccess = FileAccess.open(TRANSLATIONS_JSON_PATH, FileAccess.READ)
	if not file:
		push_warning("LocalizationManager: Çeviri dosyası açılamadı: " + TRANSLATIONS_JSON_PATH)
		return

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_err = json.parse(text)
	if parse_err != OK or not (json.data is Dictionary):
		push_error("LocalizationManager: Çeviri JSON formatı geçersiz!")
		return

	var data: Dictionary = json.data
	_translations_data = data

	var tr_res = Translation.new()
	tr_res.locale = "tr"

	var en_res = Translation.new()
	en_res.locale = "en"

	for key in data.keys():
		var entry = data[key]
		if entry is Dictionary:
			var tr_text = str(entry.get("tr", key))
			var en_text = str(entry.get("en", key))
			tr_res.add_message(key, tr_text)
			en_res.add_message(key, en_text)

	TranslationServer.add_translation(tr_res)
	TranslationServer.add_translation(en_res)
	_is_initialized = true


func load_saved_locale() -> void:
	var target = DEFAULT_LOCALE
	if FileAccess.file_exists(SETTINGS_PATH):
		var f = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if f:
			var json = JSON.new()
			if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
				target = str(json.data.get("locale", json.data.get("language", DEFAULT_LOCALE)))
			f.close()

	if target != "tr" and target != "en":
		target = DEFAULT_LOCALE

	current_locale = target
	TranslationServer.set_locale(current_locale)


func set_locale(new_locale: String) -> void:
	var clean = new_locale.to_lower().strip_edges()
	if clean != "tr" and clean != "en":
		clean = DEFAULT_LOCALE

	current_locale = clean
	TranslationServer.set_locale(current_locale)
	_save_locale_preference(current_locale)
	locale_changed.emit(current_locale)


func get_current_locale() -> String:
	return current_locale


func get_supported_locales() -> Array[Dictionary]:
	return [
		{"code": "tr", "name": "Türkçe"},
		{"code": "en", "name": "English"}
	]


func _save_locale_preference(loc: String) -> void:
	var existing: Dictionary = {}
	if FileAccess.file_exists(SETTINGS_PATH):
		var rf = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if rf:
			var json = JSON.new()
			if json.parse(rf.get_as_text()) == OK and json.data is Dictionary:
				existing = json.data
			rf.close()

	existing["locale"] = loc
	existing["language"] = loc
	var wf = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if wf:
		wf.store_string(JSON.stringify(existing, "\t"))
		wf.close()


func has_translation_key(key: String) -> bool:
	return _translations_data.has(key)


## Güvenli çeviri: eksik anahtar varsa fallback döner ve log tutar; oyuncuya ham anahtar göstermez
func translate_safe(key: String, default_text: String = "") -> String:
	if not _translations_data.has(key):
		if not _missing_keys.has(key):
			_missing_keys.append(key)
			push_warning("LocalizationManager: Eksik çeviri anahtarı tespit edildi -> " + key)
		return default_text if not default_text.is_empty() else key
	return tr(key)


func get_missing_keys() -> Array[String]:
	return _missing_keys
