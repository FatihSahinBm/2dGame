extends Node

## res://scripts/autoloads/quest_manager.gd
## Story 2D-121: Merkezi Görev Yöneticisi ve Hedef Takip Sistemi (Single Source of Truth).
## Ana ve yan görevleri, hedef aşamalarını, tamamlanma durumlarını ve kalıcılığı yönetir.

const ChapterDataRegistry = preload("res://scripts/components/chapter_data_registry.gd")

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
	var loc_mgr = get_node_or_null("/root/LocalizationManager")
	if loc_mgr and loc_mgr.has_signal("locale_changed"):
		if not loc_mgr.locale_changed.is_connected(_on_locale_changed):
			loc_mgr.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_new_locale: String) -> void:
	var t_q = get_tracked_quest()
	if not t_q.is_empty():
		tracked_quest_changed.emit(t_q)


## Standart hikâye görevlerini ilklendirir
func init_default_quests() -> void:
	_quests.clear()

	# 1. Ana Görev: Fatih'in Otağı
	register_quest({
		"id": "fatih_audience",
		"title": "Otağ-ı Hümayun ve Sefer Meclisi",
		"title_en": "Imperial Pavilion & War Council",
		"category": "main",
		"description": "Vlad Tepeş'in gece baskını sonrası Fatih Sultan Mehmed Han'ın otağına gir ve ortak hedef doğrultusunda huzura çık.",
		"description_en": "After Vlad the Impaler's night assault, enter Sultan Mehmed II's imperial pavilion and stand before the Conqueror for a shared cause.",
		"status": "active",
		"current_stage": 0,
		"stages": [
			{
				"id": "enter_tent",
				"description": "Fatih Sultan Mehmed'in otağına gir",
				"description_en": "Enter Sultan Mehmed's pavilion",
				"completed": false
			}
		],
		"reward_text": "Padişah İttifakı & Taş Köprü Taarruz Emri",
		"reward_text_en": "Imperial Alliance & Bridge Assault Order",
		"repeatable": false,
		"is_tracked": true
	})

	# 2. Yan Görev: Alevli Ok Sadakları (Kemankeş)
	register_quest({
		"id": "archer_quivers",
		"title": "Alevli Ok Sadakları",
		"title_en": "Flaming Arrow Quivers",
		"category": "side",
		"description": "Kemankeş Çavuşu'nun vadideki kırık erzak arabasında kalan alevli ok sadaklarını bul ve teslim et.",
		"description_en": "Find the flaming arrow quivers left in the broken supply cart in the valley and deliver them to the Archer Sergeant.",
		"status": "not_started",
		"current_stage": 0,
		"stages": [
			{
				"id": "find_quiver",
				"description": "Kırık erzak arabasından alevli sadakları topla",
				"description_en": "Collect flaming quivers from the damaged supply cart",
				"completed": false
			},
			{
				"id": "deliver_quiver",
				"description": "Sadakları ordugahtaki Kemankeş'e teslim et",
				"description_en": "Deliver the quivers to the Archer Sergeant at camp",
				"completed": false
			}
		],
		"reward_text": "Alevli Ok Yağmuru Desteği & Yetenek",
		"reward_text_en": "Volley of Fire Support & Ability",
		"repeatable": false,
		"is_tracked": false
	})

	# 3. Ana Görev: Kan Surları ve Taş Köprü Taarruzu
	register_quest({
		"id": "bridge_assault",
		"title": "Kan Surları ve Taş Köprü Taarruzu",
		"title_en": "Walls of Blood & Stone Bridge Assault",
		"category": "main",
		"description": "Vlad'ın kalesine açılan tek geçit olan taş köprüdeki canavar savunmasını ve barikatları aş.",
		"description_en": "Breach the barricades and beast defenses on the stone bridge, the only path into Vlad's stronghold.",
		"status": "not_started",
		"current_stage": 0,
		"stages": [
			{
				"id": "clear_barricades",
				"description": "Köprüdeki ahşap barikatları ve muhafızları aş",
				"description_en": "Breach the wooden barricades and bridge guards",
				"completed": false
			},
			{
				"id": "defeat_blood_knight",
				"description": "Eflak Kan Şövalyesi'ni mağlup et",
				"description_en": "Defeat the Wallachian Blood Knight",
				"completed": false
			},
			{
				"id": "enter_dungeon",
				"description": "Kale kapısını zorlayarak zindana sız",
				"description_en": "Batter down the fortress gate and infiltrate the dungeons",
				"completed": false
			}
		],
		"reward_text": "Kale Zindanlarına Geçiş",
		"reward_text_en": "Access to Castle Dungeons",
		"repeatable": false,
		"is_tracked": false
	})

	# 4. Ana Görev: Vlad Tepeş ile Yüzleşme
	register_quest({
		"id": "vlad_confrontation",
		"title": "Taht Odası ve Vlad Tepeş",
		"title_en": "Throne Room & Vlad the Impaler",
		"category": "main",
		"description": "Zindan zincirlerini çözerek Vlad'ın taht odasına ulaş ve ikinci Kalp Parçası'nı geri al.",
		"description_en": "Solve the dungeon mechanisms, reach Vlad's throne chamber, and reclaim the second Heart Shard.",
		"status": "not_started",
		"current_stage": 0,
		"stages": [
			{
				"id": "reach_throne",
				"description": "Zindan mekanizmasını çözüp taht odasına gir",
				"description_en": "Solve dungeon seals and enter the throne chamber",
				"completed": false
			},
			{
				"id": "defeat_vlad",
				"description": "Dört aşamalı savaşta Vlad Tepeş'i mağlup et",
				"description_en": "Defeat Vlad the Impaler across four combat phases",
				"completed": false
			}
		],
		"reward_text": "İkinci Kalp Parçası & Eflak Bölümü Zaferi",
		"reward_text_en": "Second Heart Shard & Wallachia Chapter Victory",
		"repeatable": false,
		"is_tracked": false
	})

	# 5. Ana Görev (Bölüm 1): İlk Kalp Parçası
	register_quest({
		"id": "stone_age_first_shard",
		"title": "İlk Kalp Parçası",
		"title_en": "The First Heart Shard",
		"category": "main",
		"description": "Tarih öncesi kanyonu geç, Kalp Parçası'nı göğsünde taşıyan Dev Anne T-Rex'i yen ve parçayı al.",
		"description_en": "Cross the prehistoric canyon, defeat the Mother T-Rex that carries the Heart Shard in her chest, and claim it.",
		"status": "not_started",
		"stages": [
			{"id": "cross_canyon", "description": "Kanyonu geçip canavarın inine ulaş", "description_en": "Cross the canyon and reach the beast's lair", "completed": false},
			{"id": "defeat_trex", "description": "Dev Anne T-Rex'i mağlup et", "description_en": "Defeat the Mother T-Rex", "completed": false},
			{"id": "claim_shard", "description": "Kraterdeki ilk Kalp Parçası'nı al", "description_en": "Claim the first Heart Shard in the crater", "completed": false}
		],
		"reward_text": "İlk Kalp Parçası & Kalp Rezonansı",
		"reward_text_en": "First Heart Shard & Heart Resonance"
	})

	# 6. Yan Görev (Bölüm 1): Kabilenin Kutsal Ateşi
	register_quest({
		"id": "orok_wood_cart",
		"title": "Kabilenin Kutsal Ateşi",
		"title_en": "The Tribe's Sacred Fire",
		"category": "side",
		"description": "Kabile Şefi Orok'un odun arabasını yırtıcılardan koruyarak mağara ocağına ulaştır.",
		"description_en": "Escort Chief Orok's wood cart past the predators to the cave hearth.",
		"status": "not_started",
		"stages": [
			{"id": "escort_cart", "description": "Odun arabasını mağaraya ulaştır", "description_en": "Deliver the wood cart to the cave", "completed": false}
		],
		"reward_text": "Kabilenin Kutsaması & Açılan Geçit",
		"reward_text_en": "The Tribe's Blessing & An Open Pass"
	})

	# Veri odaklı bölümlerin görevleri (data/story/chapter_*.json "quests" bloğu)
	ChapterDataRegistry.register_quests(self)

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
		"title_en": quest_dict.get("title_en", ""),
		"category": quest_dict.get("category", "main"),
		"description": quest_dict.get("description", ""),
		"description_en": quest_dict.get("description_en", ""),
		"status": quest_dict.get("status", "not_started"),
		"current_stage": int(quest_dict.get("current_stage", 0)),
		"stages": quest_dict.get("stages", []),
		"reward_text": quest_dict.get("reward_text", ""),
		"reward_text_en": quest_dict.get("reward_text_en", ""),
		"repeatable": bool(quest_dict.get("repeatable", false)),
		"is_tracked": bool(quest_dict.get("is_tracked", false))
	}

	_quests[q_id] = full_quest


func is_english() -> bool:
	var loc_mgr = get_node_or_null("/root/LocalizationManager")
	if loc_mgr and loc_mgr.has_method("get_current_locale"):
		return str(loc_mgr.get_current_locale()).to_lower().begins_with("en")
	if TranslationServer.has_method("get_locale"):
		return str(TranslationServer.get_locale()).to_lower().begins_with("en")
	return false


func get_localized_title(quest: Variant) -> String:
	var q_dict: Dictionary = quest if quest is Dictionary else (_quests.get(str(quest), {}) if _quests.has(str(quest)) else {})
	var q_id: String = str(q_dict.get("id", quest if quest is String else ""))
	if is_english():
		if q_dict.has("title_en") and not str(q_dict["title_en"]).is_empty():
			return str(q_dict["title_en"])
		if not q_id.is_empty() and _quests.has(q_id) and _quests[q_id].has("title_en"):
			return str(_quests[q_id]["title_en"])
	var raw = str(q_dict.get("title", ""))
	var translated = tr(raw)
	return translated if translated != raw else raw


func get_localized_description(quest: Variant) -> String:
	var q_dict: Dictionary = quest if quest is Dictionary else (_quests.get(str(quest), {}) if _quests.has(str(quest)) else {})
	var q_id: String = str(q_dict.get("id", quest if quest is String else ""))
	if is_english():
		if q_dict.has("description_en") and not str(q_dict["description_en"]).is_empty():
			return str(q_dict["description_en"])
		if not q_id.is_empty() and _quests.has(q_id) and _quests[q_id].has("description_en"):
			return str(_quests[q_id]["description_en"])
	var raw = str(q_dict.get("description", ""))
	var translated = tr(raw)
	return translated if translated != raw else raw


func get_localized_reward(quest: Variant) -> String:
	var q_dict: Dictionary = quest if quest is Dictionary else (_quests.get(str(quest), {}) if _quests.has(str(quest)) else {})
	var q_id: String = str(q_dict.get("id", quest if quest is String else ""))
	if is_english():
		if q_dict.has("reward_text_en") and not str(q_dict["reward_text_en"]).is_empty():
			return str(q_dict["reward_text_en"])
		if not q_id.is_empty() and _quests.has(q_id) and _quests[q_id].has("reward_text_en"):
			return str(_quests[q_id]["reward_text_en"])
	var raw = str(q_dict.get("reward_text", ""))
	var translated = tr(raw)
	return translated if translated != raw else raw


func get_localized_stage_description(stage: Dictionary) -> String:
	if is_english():
		if stage.has("description_en") and not str(stage["description_en"]).is_empty():
			return str(stage["description_en"])
		var st_id: String = str(stage.get("id", ""))
		if not st_id.is_empty():
			for q in _quests.values():
				for s in q.get("stages", []):
					if str(s.get("id", "")) == st_id and s.has("description_en"):
						return str(s["description_en"])
	var raw = str(stage.get("description", ""))
	var translated = tr(raw)
	return translated if translated != raw else raw


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
			if _quests.has(q_id):
				var base_q: Dictionary = _quests[q_id]
				var inc_q: Dictionary = incoming_quests[q_id]
				base_q["status"] = inc_q.get("status", base_q["status"])
				base_q["current_stage"] = inc_q.get("current_stage", base_q["current_stage"])
				base_q["is_tracked"] = inc_q.get("is_tracked", base_q["is_tracked"])
				if inc_q.has("stages") and inc_q["stages"] is Array:
					var base_stages: Array = base_q.get("stages", [])
					var inc_stages: Array = inc_q["stages"]
					for s_i in range(mini(base_stages.size(), inc_stages.size())):
						if inc_stages[s_i] is Dictionary and s_i < base_stages.size():
							base_stages[s_i]["completed"] = inc_stages[s_i].get("completed", false)
				_quests[q_id] = base_q
			else:
				_quests[q_id] = incoming_quests[q_id].duplicate(true)

	var t_q = get_tracked_quest()
	tracked_quest_changed.emit(t_q)


func reset_quests() -> void:
	init_default_quests()
