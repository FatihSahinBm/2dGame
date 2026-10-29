extends Node

## res://scripts/autoloads/cinematic_manager.gd
## Story 2D-145: Sinematik / Flashback oturum yöneticisi
## - Sinematik sırasında oyuncu girdilerini kilitler, bittiğinde (normal, atlama, sahne değişimi,
##   yeniden başlatma, zaman aşımı) kontrolleri güvenle geri açar.
## - Birden çok kaynağın (diyalog, flashback) üst üste binmesini referans sayımıyla yönetir.
## - Erişilebilirlik: hareketi azalt (kamera zoom/sarsıntı kapalı), yanıp sönmeyi azalt (flaş kapalı).
## - Sahne değiştiğinde tüm sinematik durumunu sıfırlar.

signal cinematic_started(source: String)
signal cinematic_ended(source: String)
signal cinematic_reset()
signal accessibility_changed()

const SETTINGS_PATH: String = "user://game_settings.json"
## Hiçbir sinematik bu süreden uzun girdileri kilitleyemez (softlock koruması)
const MAX_LOCK_SECONDS: float = 180.0

var reduce_motion: bool = false
var reduce_flashing: bool = false

var _sources: Dictionary = {}              # source:String -> true
var _player_prev_can_move: Dictionary = {} # instance_id:int -> bool
var _lock_elapsed: float = 0.0
var _last_scene: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_accessibility()


func _process(delta: float) -> void:
	var tree := get_tree()
	if not tree:
		return
	# Sahne değişimi / yeniden başlatma: sinematik durumunu sıfırla
	var cur := tree.current_scene
	if cur != _last_scene:
		if _last_scene != null and is_active():
			force_reset("scene_changed")
		_last_scene = cur

	if is_active():
		_lock_elapsed += delta
		if _lock_elapsed >= MAX_LOCK_SECONDS:
			push_warning("CinematicManager: Kilit zaman aşımına uğradı, kontroller zorla açılıyor.")
			force_reset("timeout")
	else:
		_lock_elapsed = 0.0


# ---------------------------------------------------------------------------
# Oturum yönetimi
# ---------------------------------------------------------------------------
func is_active() -> bool:
	return not _sources.is_empty()


func get_active_sources() -> Array:
	return _sources.keys()


func begin_cinematic(source: String) -> void:
	var was_active := is_active()
	_sources[source] = true
	if not was_active:
		_lock_elapsed = 0.0
		_lock_player_input()
		_set_game_state_flag(true)
	cinematic_started.emit(source)


func end_cinematic(source: String) -> void:
	if not _sources.has(source):
		return
	_sources.erase(source)
	if _sources.is_empty():
		_unlock_player_input()
		_set_game_state_flag(false)
	cinematic_ended.emit(source)


## Tüm sinematikleri sonlandırır ve oyuncu kontrollerini kesin olarak geri açar
func force_reset(_reason: String = "") -> void:
	var had := is_active()
	var sources := _sources.keys()
	_sources.clear()
	_unlock_player_input()
	_set_game_state_flag(false)
	_lock_elapsed = 0.0
	if had:
		for s in sources:
			cinematic_ended.emit(str(s))
	cinematic_reset.emit()


func _get_players() -> Array:
	var tree := get_tree()
	if not tree:
		return []
	return tree.get_nodes_in_group("player")


func _lock_player_input() -> void:
	_player_prev_can_move.clear()
	for p in _get_players():
		if is_instance_valid(p) and "can_move" in p:
			_player_prev_can_move[p.get_instance_id()] = p.can_move
			p.can_move = false
			if "velocity" in p:
				p.velocity.x = 0.0
			if "is_attacking" in p:
				p.is_attacking = false


func _unlock_player_input() -> void:
	for p in _get_players():
		if is_instance_valid(p) and "can_move" in p:
			# Daha önce kilitliyse kontrolleri geri aç (kilitli başlamışsa yine de açık bırak:
			# sinematik sonrası oyuncunun donuk kalması softlock'tur)
			p.can_move = true
	_player_prev_can_move.clear()


func _set_game_state_flag(value: bool) -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs and "is_in_cinematic" in gs:
		gs.is_in_cinematic = value


# ---------------------------------------------------------------------------
# Erişilebilirlik
# ---------------------------------------------------------------------------
func set_reduce_motion(value: bool) -> void:
	reduce_motion = value
	_save_accessibility()
	accessibility_changed.emit()


func set_reduce_flashing(value: bool) -> void:
	reduce_flashing = value
	_save_accessibility()
	accessibility_changed.emit()


## Kamera zoom / sarsıntı süresi çarpanı (hareket azaltılmışsa 0)
func get_camera_motion_scale() -> float:
	return 0.0 if reduce_motion else 1.0


## Geçiş süresi çarpanı: hareket azaltılmışsa geçişler daha yumuşak/uzun
func get_transition_duration(base: float) -> float:
	return base * (1.5 if reduce_motion else 1.0)


func load_accessibility() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not f:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		reduce_motion = bool(json.data.get("reduce_motion", false))
		reduce_flashing = bool(json.data.get("reduce_flashing", false))
	f.close()


func _save_accessibility() -> void:
	var existing: Dictionary = {}
	if FileAccess.file_exists(SETTINGS_PATH):
		var rf := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if rf:
			var json := JSON.new()
			if json.parse(rf.get_as_text()) == OK and json.data is Dictionary:
				existing = json.data
			rf.close()
	existing["reduce_motion"] = reduce_motion
	existing["reduce_flashing"] = reduce_flashing
	var wf := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if wf:
		wf.store_string(JSON.stringify(existing, "\t"))
		wf.close()

