extends Node

## res://scripts/autoloads/play_stats.gd
## Oyun içi süre ve sonuç istatistikleri (Story 2D-153).
##
## Süre kuralı: sayaç yalnızca oynanış sırasında ilerler. Şu durumlarda DURUR:
##   - oyun duraklatılmışken (SceneTree.paused),
##   - sinematik/diyalog sırasında (GameState.is_in_cinematic),
##   - sahne yüklenirken (SceneTransition.is_transitioning),
##   - seviye dışı sahnelerde (ana menü vb.; sahne yolu "/levels/" içermiyorsa).
## Sayaç aynı oturumda geriye gitmez: kayıt yüklenince süre, mevcut değerle kayıttaki değerin
## büyüğü olur.
## Kalıcılık: istatistikler GameState.persistent_events["play_stats"] içinde tutulur; SaveManager
## bu sözlüğü kayıt yuvasına yazdığı için sonuçlar yuvaya bağlıdır ve yeniden açıldığında korunur.

signal stats_changed()

const STATS_KEY: String = "play_stats"
const SYNC_INTERVAL: float = 1.0

var play_time: float = 0.0
var deaths: int = 0
var damage_taken: int = 0
var bosses_defeated: Array[String] = []
var items_collected: Array[String] = []

var _sync_wait: float = 0.0
var _player_hp: Dictionary = {} # instance_id -> son bilinen can


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_signal("game_loaded"):
		save_mgr.game_loaded.connect(func(_slot: int) -> void: load_from_game_state())


func _process(delta: float) -> void:
	if not is_time_running():
		return
	advance_time(delta)


## Sayacın şu an ilerleyip ilerlemediği (kurallar dosya başlığında)
func is_time_running() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null or tree.paused:
		return false
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and game_state.is_in_cinematic:
		return false
	var transition: Node = get_node_or_null("/root/SceneTransition")
	if transition and "is_transitioning" in transition and transition.is_transitioning:
		return false
	var scene: Node = tree.current_scene
	return scene != null and scene.scene_file_path.contains("/levels/")


func advance_time(delta: float) -> void:
	if delta <= 0.0:
		return
	play_time += delta
	_sync_wait += delta
	if _sync_wait >= SYNC_INTERVAL:
		_sync_wait = 0.0
		sync_to_game_state()


func record_death() -> void:
	deaths += 1
	_changed()


func record_damage(amount: int) -> void:
	if amount > 0:
		damage_taken += amount
		_changed()


## Aynı boss iki kez sayılmaz
func record_boss_defeated(boss_id: String) -> void:
	if not boss_id.is_empty() and not bosses_defeated.has(boss_id):
		bosses_defeated.append(boss_id)
		_changed()


## Aynı öğe iki kez sayılmaz
func record_item_collected(item_id: String) -> void:
	if not item_id.is_empty() and not items_collected.has(item_id):
		items_collected.append(item_id)
		_changed()


func reset() -> void:
	play_time = 0.0
	deaths = 0
	damage_taken = 0
	bosses_defeated.clear()
	items_collected.clear()
	_player_hp.clear()
	_changed()


func to_dictionary() -> Dictionary:
	return {
		"play_time": play_time,
		"deaths": deaths,
		"damage_taken": damage_taken,
		"bosses_defeated": bosses_defeated.duplicate(),
		"items_collected": items_collected.duplicate(),
	}


func apply_dictionary(data: Dictionary) -> void:
	# Süre aynı oturumda geriye gitmez
	play_time = maxf(play_time, maxf(float(data.get("play_time", 0.0)), 0.0))
	deaths = maxi(int(data.get("deaths", 0)), 0)
	damage_taken = maxi(int(data.get("damage_taken", 0)), 0)
	bosses_defeated.clear()
	for boss: Variant in data.get("bosses_defeated", []) as Array:
		bosses_defeated.append(str(boss))
	items_collected.clear()
	for item: Variant in data.get("items_collected", []) as Array:
		items_collected.append(str(item))


func sync_to_game_state() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and "persistent_events" in game_state:
		game_state.persistent_events[STATS_KEY] = to_dictionary()


func load_from_game_state() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and "persistent_events" in game_state:
		var stored: Variant = game_state.persistent_events.get(STATS_KEY, null)
		if stored is Dictionary:
			apply_dictionary(stored as Dictionary)
			stats_changed.emit()


## Sonuç ekranı için özet: sayaçlar + görev ve bitiş bilgisi
func get_summary() -> Dictionary:
	var summary: Dictionary = to_dictionary()
	summary["time_text"] = format_time(play_time)
	var quests_completed: int = 0
	var quest_mgr: Node = get_node_or_null("/root/QuestManager")
	if quest_mgr and quest_mgr.has_method("is_quest_completed") and "_quests" in quest_mgr:
		for quest_id: Variant in (quest_mgr._quests as Dictionary).keys():
			if quest_mgr.is_quest_completed(str(quest_id)):
				quests_completed += 1
	summary["quests_completed"] = quests_completed
	var game_state: Node = get_node_or_null("/root/GameState")
	summary["ending"] = str(game_state.get_recorded_ending()) if game_state and game_state.has_method("get_recorded_ending") else ""
	summary["corruption"] = int(game_state.corruption_score) if game_state else 0
	summary["heart_pieces"] = int(game_state.current_heart_pieces) if game_state else 0
	return summary


static func format_time(seconds: float) -> String:
	var total: int = int(maxf(seconds, 0.0))
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


func _changed() -> void:
	sync_to_game_state()
	stats_changed.emit()


# --- Oyuncu olaylarını dinleme ---

func _on_node_added(node: Node) -> void:
	if node is CharacterBody2D and node.has_signal("player_died") and node.has_signal("player_damaged"):
		_track_player.call_deferred(node)


func _track_player(player: Node) -> void:
	if not is_instance_valid(player) or player.player_died.is_connected(record_death):
		return
	player.player_died.connect(record_death)
	var player_id: int = player.get_instance_id()
	if "current_health" in player:
		_player_hp[player_id] = int(player.current_health)
	player.player_damaged.connect(func(current_hp: int, _max_hp: int) -> void:
		var previous: int = int(_player_hp.get(player_id, current_hp))
		if current_hp < previous:
			record_damage(previous - current_hp)
		_player_hp[player_id] = current_hp
	)
