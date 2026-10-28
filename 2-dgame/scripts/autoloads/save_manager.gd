extends Node

## res://scripts/autoloads/save_manager.gd
## Kalıcı Kayıt ve Yükleme Yöneticisi (Save / Load System)
## JSON tabanlı, güvenli ve versiyonlanabilir kayıt yapısı.

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal save_deleted(slot: int)

const SAVE_PATH_TEMPLATE: String = "user://savegame_slot_%d.json"
const DEFAULT_SLOT: int = 1
const CURRENT_SAVE_VERSION: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _get_game_state() -> Node:
	var root_node: Node = null
	if is_inside_tree() and get_tree():
		root_node = get_tree().root
	elif Engine.get_main_loop() is SceneTree:
		root_node = (Engine.get_main_loop() as SceneTree).root
	elif get_parent():
		var p = get_parent()
		while p.get_parent():
			p = p.get_parent()
		root_node = p

	if root_node:
		return root_node.get_node_or_null("GameState")
	return null


## Verilen yuvada geçerli kayıt dosyası var mı kontrol eder
func has_save(slot: int = DEFAULT_SLOT) -> bool:
	var path: String = _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var content: String = file.get_as_text()
	file.close()
	if content.strip_edges().is_empty():
		return false
	var json: JSON = JSON.new()
	var parse_err = json.parse(content)
	return parse_err == OK and json.data is Dictionary


## Mevcut oyun durumunu dosyaya kaydeder
func save_game(slot: int = DEFAULT_SLOT) -> bool:
	var game_state: Node = _get_game_state()
	var stage_path: String = "res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn"
	var corruption: int = 0
	var sacrificed: int = 0
	var killed: int = 0
	var hearts: int = 0
	var abilities: Array = []
	var chapters: Array = []
	var cmd_alive: bool = true
	var cmd_rescued: bool = false
	var cmd_orders: bool = false
	var fatih_done: bool = false

	if game_state:
		stage_path = game_state.current_stage_path
		corruption = game_state.corruption_score
		sacrificed = game_state.allies_sacrificed_count
		killed = game_state.allies_killed_count
		hearts = game_state.current_heart_pieces
		abilities = game_state.unlocked_abilities.duplicate()
		chapters = game_state.completed_chapters.duplicate()
		cmd_alive = game_state.is_commander_alive
		cmd_rescued = game_state.is_commander_rescued
		cmd_orders = game_state.has_commander_orders
		fatih_done = game_state.fatih_audience_completed

	var save_data: Dictionary = {
		"version": CURRENT_SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"current_stage_path": stage_path,
		"corruption_score": corruption,
		"allies_sacrificed_count": sacrificed,
		"allies_killed_count": killed,
		"current_heart_pieces": hearts,
		"unlocked_abilities": abilities,
		"completed_chapters": chapters,
		"is_commander_alive": cmd_alive,
		"is_commander_rescued": cmd_rescued,
		"has_commander_orders": cmd_orders,
		"fatih_audience_completed": fatih_done
	}

	var path: String = _get_save_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Kayıt dosyası açılamadı -> " + path)
		return false

	var json_str: String = JSON.stringify(save_data, "\t")
	file.store_string(json_str)
	file.close()

	game_saved.emit(slot)
	return true


## Kayıtlı veriyi yükleyip GameState içine aktarır
func load_game(slot: int = DEFAULT_SLOT) -> bool:
	if not has_save(slot):
		return false

	var path: String = _get_save_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false

	var content: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err = json.parse(content)
	if err != OK or not (json.data is Dictionary):
		push_error("SaveManager: Kayıt verisi bozuk.")
		return false

	var data: Dictionary = json.data
	var game_state: Node = _get_game_state()
	if game_state:
		if data.has("current_stage_path"):
			game_state.current_stage_path = str(data["current_stage_path"])
		if data.has("corruption_score"):
			game_state.corruption_score = int(data["corruption_score"])
		if data.has("allies_sacrificed_count"):
			game_state.allies_sacrificed_count = int(data["allies_sacrificed_count"])
		if data.has("allies_killed_count"):
			game_state.allies_killed_count = int(data["allies_killed_count"])
		if data.has("current_heart_pieces"):
			game_state.current_heart_pieces = int(data["current_heart_pieces"])
		if data.has("unlocked_abilities") and data["unlocked_abilities"] is Array:
			game_state.unlocked_abilities.clear()
			for ab in data["unlocked_abilities"]:
				game_state.unlocked_abilities.append(str(ab))
		if data.has("completed_chapters") and data["completed_chapters"] is Array:
			game_state.completed_chapters.clear()
			for ch in data["completed_chapters"]:
				game_state.completed_chapters.append(str(ch))
		if data.has("is_commander_alive"):
			game_state.is_commander_alive = bool(data["is_commander_alive"])
		if data.has("is_commander_rescued"):
			game_state.is_commander_rescued = bool(data["is_commander_rescued"])
		if data.has("has_commander_orders"):
			game_state.has_commander_orders = bool(data["has_commander_orders"])
		if data.has("fatih_audience_completed"):
			game_state.fatih_audience_completed = bool(data["fatih_audience_completed"])

	game_loaded.emit(slot)
	return true


## Kayıt dosyasını siler
func delete_save(slot: int = DEFAULT_SLOT) -> bool:
	var path: String = _get_save_path(slot)
	if FileAccess.file_exists(path):
		var err = DirAccess.remove_absolute(path)
		if err == OK:
			save_deleted.emit(slot)
			return true
	return false


## Kayıt özet bilgisini döndürür
func get_save_info(slot: int = DEFAULT_SLOT) -> Dictionary:
	if not has_save(slot):
		return {}
	var path: String = _get_save_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var content: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		return json.data
	return {}


## Belirtilen bölüm numarasının kilidinin açık olup olmadığını kontrol eder
func is_chapter_unlocked(chapter_index: int) -> bool:
	if chapter_index <= 1:
		return true
	var game_state: Node = _get_game_state()
	if game_state:
		if game_state.is_chapter_completed("chapter_" + str(chapter_index - 1)):
			return true
		# Ayrıca vlad aşamalarından birindeyse bölüm 2 açıktır
		if chapter_index == 2 and "vlad" in game_state.current_stage_path:
			return true
	return false


func _get_save_path(slot: int) -> String:
	return SAVE_PATH_TEMPLATE % slot
