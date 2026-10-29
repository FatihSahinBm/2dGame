extends Node

## res://scripts/autoloads/save_manager.gd
## Kalıcı Kayıt ve Yükleme Altyapısı (Save / Load System) — Epic 2D-104
## Çoklu yuva (slot), schema sürümleme, otomatik yedekleme (backup),
## bozuk veriden otomatik kurtarma (self-healing) ve bütünlük (checksum) doğrulaması.

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal save_deleted(slot: int)
signal save_corrupted_recovered(slot: int, from_backup: bool)
signal save_error(slot: int, message: String)

const CURRENT_SCHEMA_VERSION: int = 2
const SAVE_PATH_TEMPLATE: String = "user://savegame_slot_%d.json"
const BACKUP_PATH_TEMPLATE: String = "user://savegame_slot_%d_backup.json"
const TEMP_PATH_TEMPLATE: String = "user://savegame_slot_%d_tmp.json"
const SETTINGS_PATH: String = "user://game_settings.json"
const DEFAULT_SLOT: int = 1
const MAX_SLOTS: int = 3
const INTEGRITY_SALT: String = "ChronosBlade_2DGame_SecuredState_v2"
const DEFAULT_START_SCENE: String = "res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn"

# Bellekte tutulan geçici durum (Seviye yüklendiğinde oyuncuya/HUD'a aktarılır)
var cached_player_stats: Dictionary = {}
var cached_inventory: Dictionary = {}
var cached_checkpoint_id: String = ""
var cached_checkpoint_position: Vector2 = Vector2.ZERO
var cached_checkpoint_stage: String = ""
var recent_logs: Array[Dictionary] = []
var autosave_enabled: bool = true
var active_slot: int = DEFAULT_SLOT
var _last_scene_path: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func _on_scene_changed(new_scene_path: String) -> void:
	if new_scene_path.is_empty():
		return
	# Eğer yeni sahne önceki checkpoint'in ait olduğu sahneden farklıysa,
	# eski checkpoint koordinatını temizle ki yeni haritanın kendi spawn noktasında başlasın!
	if not cached_checkpoint_stage.is_empty() and cached_checkpoint_stage != new_scene_path:
		_log_event("Yeni sahneye geçildi (%s), eski kontrol noktası (%s @ %s) temizlendi." % [
			new_scene_path, cached_checkpoint_id, str(cached_checkpoint_position)
		])
		cached_checkpoint_id = ""
		cached_checkpoint_position = Vector2.ZERO
		cached_checkpoint_stage = new_scene_path


## Kontrol noktasının belirtilen sahne için geçerli olup olmadığını doğrular
func is_checkpoint_valid_for_scene(scene_path: String) -> bool:
	if cached_checkpoint_position == Vector2.ZERO:
		return false
	if cached_checkpoint_stage.is_empty() or scene_path.is_empty():
		return true
	return cached_checkpoint_stage.trim_prefix("res://") == scene_path.trim_prefix("res://")


func clear_checkpoint() -> void:
	cached_checkpoint_id = ""
	cached_checkpoint_position = Vector2.ZERO
	cached_checkpoint_stage = ""


func set_autosave_enabled(enabled: bool) -> void:
	autosave_enabled = enabled
	save_settings()
	_log_event("Otomatik kayıt tercihi güncellendi: %s" % str(enabled))


func is_autosave_enabled() -> bool:
	return autosave_enabled


func save_settings() -> void:
	var settings = {
		"autosave_enabled": autosave_enabled,
		"active_slot": active_slot
	}
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "\t"))
		f.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f:
		var content = f.get_as_text()
		f.close()
		var json = JSON.new()
		if json.parse(content) == OK and json.data is Dictionary:
			autosave_enabled = bool(json.data.get("autosave_enabled", true))
			active_slot = clampi(int(json.data.get("active_slot", DEFAULT_SLOT)), 1, MAX_SLOTS)


func get_friendly_stage_name(stage_path: String) -> String:
	if stage_path.is_empty():
		return tr("STAGE_UNKNOWN")
	if stage_path.contains("stage_1_prehistoric_valley") or stage_path.contains("prehistoric_valley"):
		return tr("STAGE_STONE_AGE_1")
	elif stage_path.contains("stage_2_trex_boss_arena"):
		return tr("STAGE_STONE_AGE_2")
	elif stage_path.contains("stage_1_forest_camp"):
		return tr("STAGE_VLAD_1")
	elif stage_path.contains("stage_1_camp"):
		return tr("STAGE_VLAD_CAMP")
	elif stage_path.contains("stage_1_fatih_tent"):
		return tr("STAGE_VLAD_TENT")
	elif stage_path.contains("stage_1_bridge_assault"):
		return tr("STAGE_VLAD_BRIDGE")
	elif stage_path.contains("stage_2_castle_dungeon"):
		return tr("STAGE_VLAD_DUNGEON")
	elif stage_path.contains("stage_3_throne_room"):
		return tr("STAGE_VLAD_THRONE")
	elif stage_path.contains("stoneage_01"):
		return tr("STAGE_STONE_AGE_1")
	elif stage_path.contains("stoneage_02"):
		return tr("STAGE_STONE_AGE_1")
	elif stage_path.contains("stoneage_07"):
		return tr("STAGE_STONE_AGE_2")

	var basename = stage_path.get_file().get_basename()
	basename = basename.replace("stage_", "Aşama ").replace("_", " ").capitalize()
	return basename


func get_slot_summary(slot: int) -> Dictionary:
	if not has_save(slot):
		return {
			"slot": slot,
			"has_save": false,
			"title": "Yuva %d" % slot,
			"timestamp": "Kayıt Yok",
			"location_name": "Boş Yuva",
			"stage_path": "",
			"checkpoint_position": Vector2.ZERO
		}
	var info = get_save_info(slot)
	var ts = str(info.get("timestamp", "-"))
	var stage_path = ""
	var cp_pos = Vector2.ZERO
	if info.has("stage_data") and info["stage_data"] is Dictionary:
		stage_path = str(info["stage_data"].get("current_stage_path", ""))
		var pos_dict = info["stage_data"].get("checkpoint_position", {})
		if pos_dict is Dictionary:
			cp_pos = Vector2(float(pos_dict.get("x", 0.0)), float(pos_dict.get("y", 0.0)))
	elif info.has("current_stage_path"):
		stage_path = str(info.get("current_stage_path", ""))

	var loc_name = get_friendly_stage_name(stage_path)
	return {
		"slot": slot,
		"has_save": true,
		"title": "Yuva %d" % slot,
		"timestamp": ts,
		"location_name": loc_name,
		"stage_path": stage_path,
		"checkpoint_position": cp_pos
	}


func _is_gameplay_scene(path: String) -> bool:
	if path.is_empty():
		return false
	if path.contains("main_menu.tscn") or path.contains("verify_") or path.contains("test_tree"):
		return false
	return path.begins_with("res://scenes/levels/") or path.begins_with("res://scenes/dev/") or path == "res://scenes/main.tscn"


func _process(_delta: float) -> void:
	# Aktif sahne ağacındaki sahneyi izleyerek GameState.current_stage_path ve checkpoint geçerliliğini güncel tutar
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		var scene_path: String = tree.current_scene.scene_file_path
		if not scene_path.is_empty() and scene_path != _last_scene_path:
			_on_scene_changed(scene_path)
			_last_scene_path = scene_path

		if _is_gameplay_scene(scene_path):
			var gs = _get_game_state()
			if gs and gs.current_stage_path != scene_path:
				gs.current_stage_path = scene_path


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


func _log_event(msg: String, is_error: bool = false, is_warning: bool = false) -> void:
	var entry: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"message": msg,
		"is_error": is_error,
		"is_warning": is_warning
	}
	recent_logs.append(entry)
	if recent_logs.size() > 50:
		recent_logs.pop_front()

	if is_error:
		push_error("SaveManager [ERROR]: " + msg)
	elif is_warning:
		push_warning("SaveManager [WARN]: " + msg)


## Yuva için kayıt dosyası (veya geçerli yedek) var mı kontrol eder
func has_save(slot: int = DEFAULT_SLOT) -> bool:
	var path: String = _get_save_path(slot)
	if _is_file_valid_save(path):
		return true
	var backup_path: String = _get_backup_path(slot)
	return _is_file_valid_save(backup_path)


func _is_file_valid_save(path: String) -> bool:
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


## Mevcut aktif sahne yolunu tespit eder
func _resolve_current_stage_path(game_state: Node) -> String:
	var tree: SceneTree = null
	if is_inside_tree() and get_tree():
		tree = get_tree()
	elif Engine.get_main_loop() is SceneTree:
		tree = Engine.get_main_loop() as SceneTree

	if tree and tree.current_scene:
		var scene_path: String = tree.current_scene.scene_file_path
		if _is_gameplay_scene(scene_path):
			if game_state:
				game_state.current_stage_path = scene_path
			return scene_path

	if game_state and not game_state.current_stage_path.is_empty():
		return game_state.current_stage_path

	return DEFAULT_START_SCENE


## Aktif sahnedeki Player ve FantasyHUD'dan güncel envanter ve statları çeker
func _gather_live_stats() -> Dictionary:
	var tree: SceneTree = null
	if is_inside_tree() and get_tree():
		tree = get_tree()
	elif Engine.get_main_loop() is SceneTree:
		tree = Engine.get_main_loop() as SceneTree

	var health: int = 100
	var max_health: int = 100
	var mana: int = 40
	var max_mana: int = 40
	var coins: int = 0
	var keys: int = 0
	var health_pots: int = 3
	var mana_pots: int = 2
	var has_weapon: bool = true
	var sec_inventory: Dictionary = {"knife": 5, "torch": 3, "holy_water": 2}
	var sec_active: String = "knife"

	if tree:
		var cur = tree.current_scene if tree.current_scene else tree.root
		var player = cur.find_child("Player", true, false)
		if not player:
			player = cur.find_child("CombatPlayer", true, false)
		if player:
			if "current_health" in player:
				health = player.current_health
			if "max_health" in player:
				max_health = player.max_health
			if "has_sword" in player:
				has_weapon = player.has_sword
			if "secondary_inventory" in player and player.secondary_inventory is Dictionary:
				sec_inventory = player.secondary_inventory.duplicate(true)
			if "active_secondary_type" in player:
				sec_active = player.active_secondary_type
			if player is Node2D and not ("is_dead" in player and player.is_dead):
				if cached_checkpoint_position == Vector2.ZERO:
					cached_checkpoint_position = player.global_position

		var hud = cur.find_child("FantasyHUD", true, false)
		if hud:
			if "current_health" in hud:
				health = hud.current_health
			if "max_health" in hud:
				max_health = hud.max_health
			if "current_mana" in hud:
				mana = hud.current_mana
			if "max_mana" in hud:
				max_mana = hud.max_mana
			if "coins" in hud:
				coins = hud.coins
			if "keys" in hud:
				keys = hud.keys
			if "health_potions" in hud:
				health_pots = hud.health_potions
			if "mana_potions" in hud:
				mana_pots = hud.mana_potions
			if "has_weapon" in hud:
				has_weapon = hud.has_weapon

	return {
		"health": health,
		"max_health": max_health,
		"mana": mana,
		"max_mana": max_mana,
		"coins": coins,
		"keys": keys,
		"health_potions": health_pots,
		"mana_potions": mana_pots,
		"has_weapon": has_weapon,
		"secondary_inventory": sec_inventory,
		"active_secondary_type": sec_active
	}


## Bütünlük Checksum'ı hesaplar (Kritik alanlar üzerinden deterministik hash)
func _calculate_checksum(dict_data: Dictionary) -> String:
	var stage: String = ""
	if dict_data.has("stage_data") and dict_data["stage_data"] is Dictionary:
		stage = str(dict_data["stage_data"].get("current_stage_path", ""))
	elif dict_data.has("current_stage_path"):
		stage = str(dict_data.get("current_stage_path", ""))
	var ts = str(dict_data.get("timestamp", ""))
	var ver: String = str(int(dict_data.get("schema_version", dict_data.get("version", 1))))
	var raw_str = "%s|%s|%s|%s" % [ver, stage, ts, INTEGRITY_SALT]
	return raw_str.sha256_text()


## Mevcut oyun durumunu güvenli ve atomik şekilde dosyaya kaydeder
func save_game(slot: int = DEFAULT_SLOT) -> bool:
	active_slot = clampi(slot, 1, MAX_SLOTS)
	save_settings()
	var game_state: Node = _get_game_state()
	var stage_path: String = _resolve_current_stage_path(game_state)
	var live_stats: Dictionary = _gather_live_stats()

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
	var persistent_events: Dictionary = {}

	if game_state:
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
		if "persistent_events" in game_state and game_state.persistent_events is Dictionary:
			persistent_events = game_state.persistent_events.duplicate(true)

	var quests_data: Dictionary = {}
	var quest_mgr = get_node_or_null("/root/QuestManager")
	if quest_mgr and quest_mgr.has_method("export_save_data"):
		quests_data = quest_mgr.export_save_data()

	var codex_data: Dictionary = {}
	var codex_mgr = get_node_or_null("/root/CodexManager")
	if codex_mgr and codex_mgr.has_method("export_save_data"):
		codex_data = codex_mgr.export_save_data()

	var save_data: Dictionary = {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"version": CURRENT_SCHEMA_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"stage_data": {
			"current_stage_path": stage_path,
			"checkpoint_id": cached_checkpoint_id,
			"checkpoint_stage": cached_checkpoint_stage if not cached_checkpoint_stage.is_empty() else stage_path,
			"checkpoint_position": {
				"x": cached_checkpoint_position.x,
				"y": cached_checkpoint_position.y
			}
		},
		"player_stats": {
			"health": live_stats["health"],
			"max_health": live_stats["max_health"],
			"mana": live_stats["mana"],
			"max_mana": live_stats["max_mana"],
			"has_weapon": live_stats["has_weapon"]
		},
		"inventory": {
			"coins": live_stats["coins"],
			"keys": live_stats["keys"],
			"health_potions": live_stats["health_potions"],
			"mana_potions": live_stats["mana_potions"],
			"secondary_inventory": live_stats["secondary_inventory"],
			"active_secondary_type": live_stats["active_secondary_type"]
		},
		"abilities": abilities,
		"corruption_data": {
			"corruption_score": corruption,
			"allies_sacrificed_count": sacrificed,
			"allies_killed_count": killed,
			"current_heart_pieces": hearts
		},
		"quest_states": {
			"completed_chapters": chapters,
			"is_commander_alive": cmd_alive,
			"is_commander_rescued": cmd_rescued,
			"has_commander_orders": cmd_orders,
			"fatih_audience_completed": fatih_done,
			"persistent_events": persistent_events,
			"quests_data": quests_data,
			"codex_data": codex_data
		},
		"codex_data": codex_data,
		# Geriye dönük uyumluluk alanları (v1 flat fields):
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

	save_data["checksum"] = _calculate_checksum(save_data)

	var temp_path: String = _get_temp_path(slot)
	var primary_path: String = _get_save_path(slot)
	var backup_path: String = _get_backup_path(slot)

	# 1. Önce geçici dosyaya yaz (Atomic write preparation)
	var temp_file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if not temp_file:
		_log_event("Geçici kayıt dosyası oluşturulamadı: " + temp_path, true)
		save_error.emit(slot, "Geçici kayıt dosyası oluşturulamadı.")
		return false

	var json_str: String = JSON.stringify(save_data, "\t")
	temp_file.store_string(json_str)
	temp_file.close()

	# 2. Mevcut geçerli bir ana kayıt varsa, onu yedeğe kopyala (Safe Backup rotation)
	if FileAccess.file_exists(primary_path) and _is_file_valid_save(primary_path):
		var src_file: FileAccess = FileAccess.open(primary_path, FileAccess.READ)
		if src_file:
			var prev_content: String = src_file.get_as_text()
			src_file.close()
			var backup_file: FileAccess = FileAccess.open(backup_path, FileAccess.WRITE)
			if backup_file:
				backup_file.store_string(prev_content)
				backup_file.close()

	# 3. Geçici dosyayı ana dosya olarak taşı/yaz
	var final_file: FileAccess = FileAccess.open(primary_path, FileAccess.WRITE)
	if not final_file:
		_log_event("Ana kayıt dosyasına yazılamadı: " + primary_path, true)
		save_error.emit(slot, "Ana kayıt dosyasına yazılamadı.")
		return false
	final_file.store_string(json_str)
	final_file.close()

	# Geçici dosyayı temizle
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)

	_log_event("Oyun başarıyla kaydedildi -> Yuva: %d, Sahne: %s" % [slot, stage_path])
	game_saved.emit(slot)
	return true


## Eski şema sürümlerini güncel şemaya geçirir (Schema Migration)
func _migrate_data(data: Dictionary) -> Dictionary:
	var ver: int = int(data.get("schema_version", data.get("version", 1)))
	if ver < 2:
		_log_event("Eski kayıt biçimi (v%d) güncel v2 şemasına yükseltiliyor..." % ver)
		var migrated: Dictionary = data.duplicate(true)
		migrated["schema_version"] = 2
		migrated["version"] = 2

		var stage_path = str(data.get("current_stage_path", DEFAULT_START_SCENE))
		if not migrated.has("stage_data"):
			migrated["stage_data"] = {
				"current_stage_path": stage_path,
				"checkpoint_id": "",
				"checkpoint_position": {"x": 0.0, "y": 0.0}
			}

		if not migrated.has("player_stats"):
			migrated["player_stats"] = {
				"health": 100,
				"max_health": 100,
				"mana": 40,
				"max_mana": 40,
				"has_weapon": true
			}

		if not migrated.has("inventory"):
			migrated["inventory"] = {
				"coins": 0,
				"keys": 0,
				"health_potions": 3,
				"mana_potions": 2
			}

		if not migrated.has("corruption_data"):
			migrated["corruption_data"] = {
				"corruption_score": int(data.get("corruption_score", 0)),
				"allies_sacrificed_count": int(data.get("allies_sacrificed_count", 0)),
				"allies_killed_count": int(data.get("allies_killed_count", 0)),
				"current_heart_pieces": int(data.get("current_heart_pieces", 0))
			}

		if not migrated.has("quest_states"):
			migrated["quest_states"] = {
				"completed_chapters": data.get("completed_chapters", []),
				"is_commander_alive": bool(data.get("is_commander_alive", true)),
				"is_commander_rescued": bool(data.get("is_commander_rescued", false)),
				"has_commander_orders": bool(data.get("has_commander_orders", false)),
				"fatih_audience_completed": bool(data.get("fatih_audience_completed", false))
			}

		migrated["checksum"] = _calculate_checksum(migrated)
		return migrated

	return data


## Kayıtlı veriyi yükleyip GameState ve önbelleğe aktarır (Self-Healing Recovery destekli)
func load_game(slot: int = DEFAULT_SLOT) -> bool:
	active_slot = clampi(slot, 1, MAX_SLOTS)
	save_settings()
	var primary_path: String = _get_save_path(slot)
	var backup_path: String = _get_backup_path(slot)
	var loaded_data: Dictionary = {}
	var recovered_from_backup: bool = false

	# 1. Ana dosyayı dene
	if _is_file_valid_save(primary_path):
		var file: FileAccess = FileAccess.open(primary_path, FileAccess.READ)
		if file:
			var content: String = file.get_as_text()
			file.close()
			var json: JSON = JSON.new()
			if json.parse(content) == OK and json.data is Dictionary:
				var candidate: Dictionary = json.data
				# Bütünlük (Checksum) doğrulaması
				var expected_sum: String = str(candidate.get("checksum", ""))
				var actual_sum: String = _calculate_checksum(candidate)
				if expected_sum.is_empty() or actual_sum == expected_sum:
					loaded_data = candidate
				else:
					_log_event("Ana kayıt dosyasında checksum uyuşmazlığı tespit edildi!", false, true)

	# 2. Ana dosya bozuk veya geçersizse yedek dosyadan kurtarmayı dene
	if loaded_data.is_empty():
		_log_event("Ana kayıt dosyası açılamadı veya bozuk; yedek kayıt (backup) deneniyor...", false, true)
		if _is_file_valid_save(backup_path):
			var b_file: FileAccess = FileAccess.open(backup_path, FileAccess.READ)
			if b_file:
				var b_content: String = b_file.get_as_text()
				b_file.close()
				var b_json: JSON = JSON.new()
				if b_json.parse(b_content) == OK and b_json.data is Dictionary:
					loaded_data = b_json.data
					recovered_from_backup = true
					_log_event("Yedek kayıt başarıyla okundu! Ana kayıt otomatik restore ediliyor...")
					# Ana kayıt dosyasını yedekten onar
					var fix_file: FileAccess = FileAccess.open(primary_path, FileAccess.WRITE)
					if fix_file:
						fix_file.store_string(b_content)
						fix_file.close()
					save_corrupted_recovered.emit(slot, true)

	# 3. İkisi de başarısızsa hata bildir ve güvenli varsayılan değerlerle çöküşü önle
	if loaded_data.is_empty():
		_log_event("Yuva %d için geçerli veya kurtarılabilir kayıt bulunamadı!" % slot, true)
		save_error.emit(slot, "Kayıt dosyası bulunamadı veya kurtarılamadı.")
		return false

	# Sürüm yükseltme (Migration) uygula
	var final_data: Dictionary = _migrate_data(loaded_data)

	# Verileri GameState içine aktar
	var game_state: Node = _get_game_state()
	var target_stage: String = DEFAULT_START_SCENE

	if final_data.has("stage_data") and final_data["stage_data"] is Dictionary:
		var sd = final_data["stage_data"]
		target_stage = str(sd.get("current_stage_path", DEFAULT_START_SCENE))
		cached_checkpoint_id = str(sd.get("checkpoint_id", ""))
		cached_checkpoint_stage = str(sd.get("checkpoint_stage", target_stage))
		var cp_pos = sd.get("checkpoint_position", {})
		if cp_pos is Dictionary:
			cached_checkpoint_position = Vector2(float(cp_pos.get("x", 0.0)), float(cp_pos.get("y", 0.0)))
	elif final_data.has("current_stage_path"):
		target_stage = str(final_data["current_stage_path"])

	if game_state:
		game_state.current_stage_path = target_stage

		if final_data.has("corruption_data") and final_data["corruption_data"] is Dictionary:
			var cd = final_data["corruption_data"]
			game_state.corruption_score = int(cd.get("corruption_score", 0))
			game_state.allies_sacrificed_count = int(cd.get("allies_sacrificed_count", 0))
			game_state.allies_killed_count = int(cd.get("allies_killed_count", 0))
			game_state.current_heart_pieces = int(cd.get("current_heart_pieces", 0))
		else:
			if final_data.has("corruption_score"):
				game_state.corruption_score = int(final_data["corruption_score"])
			if final_data.has("allies_sacrificed_count"):
				game_state.allies_sacrificed_count = int(final_data["allies_sacrificed_count"])
			if final_data.has("allies_killed_count"):
				game_state.allies_killed_count = int(final_data["allies_killed_count"])
			if final_data.has("current_heart_pieces"):
				game_state.current_heart_pieces = int(final_data["current_heart_pieces"])

		if final_data.has("abilities") and final_data["abilities"] is Array:
			game_state.unlocked_abilities.clear()
			for ab in final_data["abilities"]:
				game_state.unlocked_abilities.append(str(ab))
		elif final_data.has("unlocked_abilities") and final_data["unlocked_abilities"] is Array:
			game_state.unlocked_abilities.clear()
			for ab in final_data["unlocked_abilities"]:
				game_state.unlocked_abilities.append(str(ab))

		if final_data.has("quest_states") and final_data["quest_states"] is Dictionary:
			var qs = final_data["quest_states"]
			if qs.has("completed_chapters") and qs["completed_chapters"] is Array:
				game_state.completed_chapters.clear()
				for ch in qs["completed_chapters"]:
					game_state.completed_chapters.append(str(ch))
			game_state.is_commander_alive = bool(qs.get("is_commander_alive", true))
			game_state.is_commander_rescued = bool(qs.get("is_commander_rescued", false))
			game_state.has_commander_orders = bool(qs.get("has_commander_orders", false))
			game_state.fatih_audience_completed = bool(qs.get("fatih_audience_completed", false))
			if qs.has("persistent_events") and qs["persistent_events"] is Dictionary and "persistent_events" in game_state:
				game_state.persistent_events = qs["persistent_events"].duplicate(true)
			if qs.has("quests_data") and qs["quests_data"] is Dictionary:
				var quest_mgr = get_node_or_null("/root/QuestManager")
				if quest_mgr and quest_mgr.has_method("import_save_data"):
					quest_mgr.import_save_data(qs["quests_data"])
			if qs.has("codex_data") and qs["codex_data"] is Dictionary:
				var codex_mgr = get_node_or_null("/root/CodexManager")
				if codex_mgr and codex_mgr.has_method("import_save_data"):
					codex_mgr.import_save_data(qs["codex_data"])
		else:
			if final_data.has("completed_chapters") and final_data["completed_chapters"] is Array:
				game_state.completed_chapters.clear()
				for ch in final_data["completed_chapters"]:
					game_state.completed_chapters.append(str(ch))
			if final_data.has("is_commander_alive"):
				game_state.is_commander_alive = bool(final_data["is_commander_alive"])
			if final_data.has("is_commander_rescued"):
				game_state.is_commander_rescued = bool(final_data["is_commander_rescued"])
			if final_data.has("has_commander_orders"):
				game_state.has_commander_orders = bool(final_data["has_commander_orders"])
			if final_data.has("fatih_audience_completed"):
				game_state.fatih_audience_completed = bool(final_data["fatih_audience_completed"])

	# Doğrudan kök dizinden de codex_data kontrolü (geriye dönük ve esnek)
	if final_data.has("codex_data") and final_data["codex_data"] is Dictionary:
		var codex_mgr = get_node_or_null("/root/CodexManager")
		if codex_mgr and codex_mgr.has_method("import_save_data"):
			codex_mgr.import_save_data(final_data["codex_data"])

	# İstatistik ve envanter önbelleğe alınır
	if final_data.has("player_stats") and final_data["player_stats"] is Dictionary:
		cached_player_stats = final_data["player_stats"].duplicate(true)
	if final_data.has("inventory") and final_data["inventory"] is Dictionary:
		cached_inventory = final_data["inventory"].duplicate(true)

	_log_event("Kayıt yüklendi -> Yuva: %d, Sahne: %s (Kurtarma: %s)" % [slot, target_stage, str(recovered_from_backup)])
	game_loaded.emit(slot)
	return true


## Yeni sahne yüklendiğinde oyuncu ve HUD değerlerini senkronize eder
func apply_cached_stats_to_scene(target_node: Node = null) -> void:
	if cached_player_stats.is_empty() and cached_inventory.is_empty() and cached_checkpoint_position == Vector2.ZERO:
		return

	var scene = target_node
	if not scene:
		var tree = get_tree()
		if tree:
			scene = tree.current_scene

	if not scene:
		return

	var cur_path: String = scene.scene_file_path if "scene_file_path" in scene else ""
	var can_apply_checkpoint: bool = is_checkpoint_valid_for_scene(cur_path)

	var player = scene.find_child("Player", true, false)
	if not player:
		player = scene.find_child("CombatPlayer", true, false)
	if player:
		if cached_player_stats.has("health") and "current_health" in player:
			player.current_health = int(cached_player_stats["health"])
		if cached_player_stats.has("max_health") and "max_health" in player:
			player.max_health = int(cached_player_stats["max_health"])
		if cached_player_stats.has("has_weapon") and "has_sword" in player:
			player.has_sword = bool(cached_player_stats["has_weapon"])
		if cached_inventory.has("secondary_inventory") and "secondary_inventory" in player:
			player.secondary_inventory = cached_inventory["secondary_inventory"].duplicate(true)
		if cached_inventory.has("active_secondary_type") and "active_secondary_type" in player:
			player.active_secondary_type = str(cached_inventory["active_secondary_type"])
		if player.has_method("_sync_hud_secondary"):
			player._sync_hud_secondary()
		if can_apply_checkpoint and cached_checkpoint_position != Vector2.ZERO:
			player.global_position = cached_checkpoint_position
			var cam = player.get_node_or_null("Camera2D")
			if cam and cam.has_method("reset_smoothing"):
				cam.reset_smoothing()
			_log_event("Oyuncu kayıtlı kontrol noktasına/konumuna yerleştirildi: %s" % str(cached_checkpoint_position))

	var hud = scene.find_child("FantasyHUD", true, false)
	if hud:
		if cached_player_stats.has("health") and "current_health" in hud:
			hud.current_health = int(cached_player_stats["health"])
		if cached_player_stats.has("max_health") and "max_health" in hud:
			hud.max_health = int(cached_player_stats["max_health"])
		if cached_player_stats.has("mana") and "current_mana" in hud:
			hud.current_mana = int(cached_player_stats["mana"])
		if cached_player_stats.has("max_mana") and "max_mana" in hud:
			hud.max_mana = int(cached_player_stats["max_mana"])
		if cached_inventory.has("coins") and "coins" in hud:
			hud.coins = int(cached_inventory["coins"])
		if cached_inventory.has("keys") and "keys" in hud:
			hud.keys = int(cached_inventory["keys"])
		if cached_inventory.has("health_potions") and "health_potions" in hud:
			hud.health_potions = int(cached_inventory["health_potions"])
		if cached_inventory.has("mana_potions") and "mana_potions" in hud:
			hud.mana_potions = int(cached_inventory["mana_potions"])
		if hud.has_method("update_all"):
			hud.update_all()


## Kontrol noktası kaydeder ve otomatik kayıt alır
func set_checkpoint(checkpoint_id: String, position: Vector2, autosave: bool = true, stage_path: String = "") -> void:
	cached_checkpoint_id = checkpoint_id
	cached_checkpoint_position = position
	if not stage_path.is_empty():
		cached_checkpoint_stage = stage_path
	elif is_inside_tree() and get_tree() and get_tree().current_scene:
		cached_checkpoint_stage = get_tree().current_scene.scene_file_path
	_log_event("Kontrol noktası belirlendi: %s @ %s (Sahne: %s)" % [checkpoint_id, str(position), cached_checkpoint_stage])
	if autosave and autosave_enabled:
		save_game(active_slot)


## Kayıt dosyasını ve yedeklerini tamamen siler
func delete_save(slot: int = DEFAULT_SLOT) -> bool:
	var primary = _get_save_path(slot)
	var backup = _get_backup_path(slot)
	var temp = _get_temp_path(slot)
	var success = false

	if FileAccess.file_exists(primary):
		if DirAccess.remove_absolute(primary) == OK:
			success = true
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(temp):
		DirAccess.remove_absolute(temp)

	if success:
		_log_event("Yuva %d kaydı ve yedekleri silindi." % slot)
		save_deleted.emit(slot)
	return success


## Kayıt özet bilgisini döndürür
func get_save_info(slot: int = DEFAULT_SLOT) -> Dictionary:
	if not has_save(slot):
		return {}
	var path: String = _get_save_path(slot)
	if not _is_file_valid_save(path):
		path = _get_backup_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var content: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		return _migrate_data(json.data)
	return {}


## Belirtilen bölüm numarasının kilidinin açık olup olmadığını kontrol eder
func is_chapter_unlocked(chapter_index: int) -> bool:
	if chapter_index <= 1:
		return true
	var game_state: Node = _get_game_state()
	if game_state:
		if game_state.is_chapter_completed("chapter_" + str(chapter_index - 1)):
			return true
		if chapter_index == 2 and "vlad" in game_state.current_stage_path:
			return true
	return false


func _get_save_path(slot: int) -> String:
	return SAVE_PATH_TEMPLATE % slot


func _get_backup_path(slot: int) -> String:
	return BACKUP_PATH_TEMPLATE % slot


func _get_temp_path(slot: int) -> String:
	return TEMP_PATH_TEMPLATE % slot
