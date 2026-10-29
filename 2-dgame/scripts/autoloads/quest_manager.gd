extends Node

## res://scripts/autoloads/quest_manager.gd
## Story 2D-121: Merkezi Görev Yöneticisi ve Hedef Takip Sistemi (Single Source of Truth).
## Ana ve yan görevleri, hedef aşamalarını, tamamlanma durumlarını ve kalıcılığı yönetir.

signal quest_started(quest_id: String, quest: Dictionary)
signal quest_updated(quest_id: String, quest: Dictionary)
signal objective_completed(quest_id: String, stage_id: String, stage_desc: String)
signal quest_completed(quest_id: String, quest: Dictionary)
signal quest_failed(quest_id: String, quest: Dictionary)
signal tracked_quest_changed(quest: Dictionary)

static var instance: Node = null

var _quests: Dictionary = {} # quest_id -> Dictionary
var tracked_quest_id: String = ""


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	instance = self
	init_default_quests()


## Standart hikâye görevlerini ilklendirir
func init_default_quests() -> void:
	_quests.clear()

	# 1. Ana Görev: Fatih'in Otağı
	register_quest({
		"id": "fatih_audience",
		"title": "Otağ-ı Hümayun ve Sefer Meclisi",
		"category": "main",
		"description": "Vlad Tepeş'in gece baskını sonrası Fatih Sultan Mehmed Han'ın otağına gir ve ortak hedef doğrultusunda huzura çık.",
		"status": "active",
		"current_stage": 0,
		"stages": [
			{
				"id": "enter_tent",
				"description": "Fatih Sultan Mehmed'in otağına gir",
				"completed": false
			}
		],
		"reward_text": "Padişah İttifakı & Taş Köprü Taarruz Emri",
		"repeatable": false,
		"is_tracked": true
	})

	# 2. Yan Görev: Alevli Ok Sadakları (Kemankeş)
	register_quest({
		"id": "archer_quivers",
		"title": "Alevli Ok Sadakları",
		"category": "side",
		"description": "Kemankeş Çavuşu'nun vadideki kırık erzak arabasında kalan alevli ok sadaklarını bul ve teslim et.",
		"status": "not_started",
		"current_stage": 0,
		"stages": [
			{
				"id": "find_quiver",
				"description": "Kırık erzak arabasından alevli sadakları topla",
				"completed": false
			},
			{
				"id": "deliver_quiver",
				"description": "Sadakları ordugahtaki Kemankeş'e teslim et",
				"completed": false
			}
		],
		"reward_text": "Alevli Ok Yağmuru Desteği & Yetenek",
		"repeatable": false,
		"is_tracked": false
	})

	# 3. Ana Görev: Kan Surları ve Taş Köprü Taarruzu
	register_quest({
		"id": "bridge_assault",
		"title": "Kan Surları ve Taş Köprü Taarruzu",
		"category": "main",
		"description": "Vlad'ın kalesine açılan tek geçit olan taş köprüdeki canavar savunmasını ve barikatları aş.",
		"status": "not_started",
		"current_stage": 0,
		"stages": [
			{
				"id": "clear_barricades",
				"description": "Köprüdeki ahşap barikatları ve muhafızları aş",
				"completed": false
			},
			{
				"id": "defeat_blood_knight",
				"description": "Eflak Kan Şövalyesi'ni mağlup et",
				"completed": false
			},
			{
				"id": "enter_dungeon",
				"description": "Kale kapısını zorlayarak zindana sız",
				"completed": false
			}
		],
		"reward_text": "Kale Zindanlarına Geçiş",
		"repeatable": false,
		"is_tracked": false
	})

	# 4. Ana Görev: Vlad Tepeş ile Yüzleşme
	register_quest({
		"id": "vlad_confrontation",
		"title": "Taht Odası ve Vlad Tepeş",
		"category": "main",
		"description": "Zindan zincirlerini çözerek Vlad'ın taht odasına ulaş ve ikinci Kalp Parçası'nı geri al.",
		"status": "not_started",
		"current_stage": 0,
		"stages": [
			{
				"id": "reach_throne",
				"description": "Zindan mekanizmasını çözüp taht odasına gir",
				"completed": false
			},
			{
				"id": "defeat_vlad",
				"description": "Dört aşamalı savaşta Vlad Tepeş'i mağlup et",
				"completed": false
			}
		],
		"reward_text": "İkinci Kalp Parçası & Eflak Bölümü Zaferi",
		"repeatable": false,
		"is_tracked": false
	})

	# Varsayılan takip edilen görev
	tracked_quest_id = "fatih_audience"
	var t_q = get_tracked_quest()
	if not t_q.is_empty():
		tracked_quest_changed.emit(t_q)


## Yeni bir görev kaydeder veya günceller
func register_quest(quest_dict: Dictionary) -> void:
	if not quest_dict.has("id"):
		return
	var q_id: String = str(quest_dict["id"])

	# Eksik alanları varsayılanlarla doldur
	var full_quest: Dictionary = {
		"id": q_id,
		"title": quest_dict.get("title", q_id.capitalize()),
		"category": quest_dict.get("category", "main"),
		"description": quest_dict.get("description", ""),
		"status": quest_dict.get("status", "not_started"),
		"current_stage": int(quest_dict.get("current_stage", 0)),
		"stages": quest_dict.get("stages", []),
		"reward_text": quest_dict.get("reward_text", ""),
		"repeatable": bool(quest_dict.get("repeatable", false)),
		"is_tracked": bool(quest_dict.get("is_tracked", false))
	}

	_quests[q_id] = full_quest


## Görevi başlatır
func start_quest(quest_id: String) -> bool:
	if not _quests.has(quest_id):
		return false

	var q: Dictionary = _quests[quest_id]
	if q["status"] == "completed" and not q["repeatable"]:
		return false

	q["status"] = "active"
	q["current_stage"] = 0
	for st in q["stages"]:
		st["completed"] = false

	# Eğer takip edilen aktif görev yoksa bunu otomatik takip et
	if tracked_quest_id.is_empty() or not is_quest_active(tracked_quest_id):
		set_tracked_quest(quest_id)

	quest_started.emit(quest_id, q)
	quest_updated.emit(quest_id, q)
	return true


## Görevde bir hedef aşamasını tamamlar ve sıradakine geçer
func advance_quest(quest_id: String, stage_id_or_idx = null) -> bool:
	if not _quests.has(quest_id):
		return false

	var q: Dictionary = _quests[quest_id]
	if q["status"] != "active":
		return false

	var stages: Array = q["stages"]
	if stages.is_empty():
		return complete_quest(quest_id)

	var target_stage_idx: int = q["current_stage"]
	if stage_id_or_idx != null:
		if stage_id_or_idx is int:
			target_stage_idx = stage_id_or_idx
		elif stage_id_or_idx is String:
			for i in range(stages.size()):
				if stages[i].get("id") == stage_id_or_idx:
					target_stage_idx = i
					break

	if target_stage_idx >= 0 and target_stage_idx < stages.size():
		var current_stage_data: Dictionary = stages[target_stage_idx]
		current_stage_data["completed"] = true
		var s_id: String = str(current_stage_data.get("id", str(target_stage_idx)))
		var s_desc: String = str(current_stage_data.get("description", ""))

		# Ses geri bildirimi
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("objective_complete", -1.0)

		objective_completed.emit(quest_id, s_id, s_desc)

		# Sonraki tamamlanmamış aşamayı bul
		var next_incomplete: int = -1
		for i in range(stages.size()):
			if not stages[i].get("completed", false):
				next_incomplete = i
				break

		if next_incomplete == -1:
			# Tüm aşamalar bitti!
			return complete_quest(quest_id)
		else:
			q["current_stage"] = next_incomplete
			quest_updated.emit(quest_id, q)
			if tracked_quest_id == quest_id:
				tracked_quest_changed.emit(q)
			return true

	return false


## Görevi başarıyla tamamlar
func complete_quest(quest_id: String) -> bool:
	if not _quests.has(quest_id):
		return false

	var q: Dictionary = _quests[quest_id]
	q["status"] = "completed"
	for st in q["stages"]:
		st["completed"] = true

	# Tamamlanma sesi
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("quest_complete", 0.0)

	quest_completed.emit(quest_id, q)
	quest_updated.emit(quest_id, q)

	# Takip edilen görev bittiyse sıradaki aktif göreve geç
	if tracked_quest_id == quest_id:
		var active_list: Array[Dictionary] = get_active_quests()
		if not active_list.is_empty():
			set_tracked_quest(active_list[0]["id"])
		else:
			tracked_quest_id = ""
			tracked_quest_changed.emit({})

	return true


## Görevi başarısız olarak işaretler
func fail_quest(quest_id: String) -> bool:
	if not _quests.has(quest_id):
		return false

	var q: Dictionary = _quests[quest_id]
	q["status"] = "failed"
	quest_failed.emit(quest_id, q)
	quest_updated.emit(quest_id, q)

	if tracked_quest_id == quest_id:
		var active_list = get_active_quests()
		if not active_list.is_empty():
			set_tracked_quest(active_list[0]["id"])
		else:
			tracked_quest_id = ""
			tracked_quest_changed.emit({})
	return true


## Belirli bir görevi getirir
func get_quest(quest_id: String) -> Dictionary:
	return _quests.get(quest_id, {})


## Aktif görevlerin listesini döndürür
func get_active_quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for q in _quests.values():
		if q.get("status") == "active":
			result.append(q)
	return result


## Tamamlanan görevlerin listesini döndürür
func get_completed_quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for q in _quests.values():
		if q.get("status") == "completed":
			result.append(q)
	return result


## Şu anda HUD'da izlenen aktif görevi döndürür
func get_tracked_quest() -> Dictionary:
	if not tracked_quest_id.is_empty() and _quests.has(tracked_quest_id):
		var q = _quests[tracked_quest_id]
		if q.get("status") == "active":
			return q

	# Eğer belirlenen yoksa ilk aktif görevi getir
	var active_list = get_active_quests()
	if not active_list.is_empty():
		tracked_quest_id = str(active_list[0]["id"])
		return active_list[0]

	return {}


## İzlenecek aktif görevi seçer
func set_tracked_quest(quest_id: String) -> bool:
	if not _quests.has(quest_id):
		return false
	tracked_quest_id = quest_id
	var q = _quests[quest_id]
	for k in _quests.keys():
		_quests[k]["is_tracked"] = (k == quest_id)
	tracked_quest_changed.emit(q)
	return true


func is_quest_active(quest_id: String) -> bool:
	return _quests.has(quest_id) and _quests[quest_id].get("status") == "active"


func is_quest_completed(quest_id: String) -> bool:
	return _quests.has(quest_id) and _quests[quest_id].get("status") == "completed"


## SaveManager için dışa aktarma
func export_save_data() -> Dictionary:
	var quests_data: Dictionary = {}
	for q_id in _quests.keys():
		quests_data[q_id] = _quests[q_id].duplicate(true)

	return {
		"tracked_quest_id": tracked_quest_id,
		"quests": quests_data
	}


## SaveManager'dan içe aktarma
func import_save_data(data: Dictionary) -> void:
	if not data is Dictionary:
		return

	if data.has("tracked_quest_id"):
		tracked_quest_id = str(data["tracked_quest_id"])

	if data.has("quests") and data["quests"] is Dictionary:
		var incoming_quests: Dictionary = data["quests"]
		for q_id in incoming_quests.keys():
			_quests[q_id] = incoming_quests[q_id].duplicate(true)

	var t_q = get_tracked_quest()
	tracked_quest_changed.emit(t_q)


func reset_quests() -> void:
	init_default_quests()
