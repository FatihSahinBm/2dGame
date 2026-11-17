extends Node

## res://scripts/enemies/blood_knight_skills.gd
## Kan Şövalyesi'nin menzilli saldırıları (Story 2D-141): kan dalgası ve zincirle çekme.
## BloodKnight'ın çocuğu olarak çalışır; yakın dövüş BloodKnight'ta kalır.
##
## Kurallar
## - Kan dalgası: orta menzilde (WAVE_MIN_RANGE..WAVE_MAX_RANGE). WAVE_TELEGRAPH süresince şövalye
##   kızıl parlar ve yerde uyarı çizgisi görünür; sonra zeminde ilerleyen dalga çıkar. Dalga oyuncuya
##   en fazla bir kez hasar verir, menzili bitince veya duvara çarpınca kaybolur. Zıplayarak kaçılır.
## - Zincir: uzak menzilde (CHAIN_MIN_RANGE..CHAIN_MAX_RANGE). Hedef konum CHAIN_TELEGRAPH başında
##   kilitlenir ve bir zincir çizgisi gösterilir. Telegraph sonunda oyuncu hâlâ menzildeyse ve arada
##   duvar yoksa yakalanır: yatay olarak (move_and_collide ile, duvar/zemin içine girmeden) şövalyenin
##   önüne çekilir, küçük hasar alır ve CHAIN_STUN boyunca hareket edemez. Geçersiz hedefte zincir boşa
##   döner (hiçbir etki yok).
## - Her saldırıdan sonra RECOVERY süresince şövalye savunmasızdır (oyuncunun karşılık verme penceresi).
## - Şövalye ölür, sinematik başlar ya da düğüm silinirse süren saldırı iptal edilir ve oyuncunun
##   hareket kilidi her durumda geri açılır.

signal skill_started(skill: String)
signal skill_finished(skill: String)
signal chain_caught(player: Node2D)
signal chain_missed(reason: String)

const WAVE_MIN_RANGE: float = 110.0
const WAVE_MAX_RANGE: float = 320.0
const WAVE_TELEGRAPH: float = 0.55
const WAVE_SPEED: float = 380.0
const WAVE_TRAVEL: float = 420.0
const WAVE_DAMAGE: int = 18
const WAVE_HIT_HALF_WIDTH: float = 22.0
const WAVE_HIT_HEIGHT: float = 44.0
const WAVE_COOLDOWN: float = 4.5

const CHAIN_MIN_RANGE: float = 200.0
const CHAIN_MAX_RANGE: float = 380.0
const CHAIN_TELEGRAPH: float = 0.5
const CHAIN_PULL_SPEED: float = 620.0
const CHAIN_STOP_DISTANCE: float = 58.0
const CHAIN_DAMAGE: int = 8
const CHAIN_STUN: float = 0.45
const CHAIN_COOLDOWN: float = 7.0
const CHAIN_MAX_PULL_TIME: float = 1.0

const RECOVERY: float = 0.7

var wave_cooldown: float = 1.5
var chain_cooldown: float = 3.0
var active_skill: String = ""

var _knight: CharacterBody2D = null
var _phase: String = ""          # "telegraph", "pull", "stun", "recovery"
var _phase_timer: float = 0.0
var _locked_target: Vector2 = Vector2.ZERO
var _player: CharacterBody2D = null
var _player_locked: bool = false
var _pull_time: float = 0.0
var _telegraph_line: Line2D = null
var _waves: Array[Node2D] = []


func _ready() -> void:
	_knight = get_parent() as CharacterBody2D
	process_physics_priority = -1


func is_busy() -> bool:
	return not active_skill.is_empty()


## BloodKnight her karede çağırır; uygun bir menzilli saldırı başlatırsa true döner.
func try_use(player: CharacterBody2D, distance: float) -> bool:
	if is_busy() or player == null or not is_instance_valid(player) or _is_blocked():
		return false
	if "is_dead" in player and player.is_dead:
		return false
	if chain_cooldown <= 0.0 and distance >= CHAIN_MIN_RANGE and distance <= CHAIN_MAX_RANGE:
		_start("chain", player)
		return true
	if wave_cooldown <= 0.0 and distance >= WAVE_MIN_RANGE and distance <= WAVE_MAX_RANGE:
		_start("wave", player)
		return true
	return false


func _start(skill: String, player: CharacterBody2D) -> void:
	active_skill = skill
	_player = player
	_phase = "telegraph"
	_phase_timer = WAVE_TELEGRAPH if skill == "wave" else CHAIN_TELEGRAPH
	_locked_target = player.global_position
	_knight.velocity.x = 0.0
	_flash_knight(true)
	_show_telegraph_line(skill)
	skill_started.emit(skill)


func _physics_process(delta: float) -> void:
	wave_cooldown = maxf(wave_cooldown - delta, 0.0)
	chain_cooldown = maxf(chain_cooldown - delta, 0.0)
	_update_waves(delta)
	if not is_busy():
		return
	if _is_blocked():
		cancel()
		return
	match _phase:
		"telegraph":
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_clear_telegraph()
				if active_skill == "wave":
					_release_wave()
					_enter_recovery()
				else:
					_resolve_chain()
		"pull":
			_process_pull(delta)
		"stun":
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_release_player()
				_enter_recovery()
		"recovery":
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_finish()


# --- Kan dalgası ---

func _release_wave() -> void:
	wave_cooldown = WAVE_COOLDOWN
	var wave: Node2D = Node2D.new()
	wave.name = "BloodWave"
	wave.set_meta("dir", signf(_locked_target.x - _knight.global_position.x) if not is_equal_approx(_locked_target.x, _knight.global_position.x) else 1.0)
	wave.set_meta("travelled", 0.0)
	wave.set_meta("hit", false)
	var body: Polygon2D = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-14, 0), Vector2(0, -WAVE_HIT_HEIGHT), Vector2(14, 0)])
	body.color = Color(0.85, 0.05, 0.12, 0.85)
	wave.add_child(body)
	var host: Node = _knight.get_parent() if _knight.get_parent() else _knight
	host.add_child(wave)
	wave.global_position = Vector2(_knight.global_position.x, _find_ground_y())
	_waves.append(wave)


## Dalga zeminde ilerler: şövalyenin altındaki zeminin yüksekliği (bulunamazsa şövalyenin konumu)
func _find_ground_y() -> float:
	var space: PhysicsDirectSpaceState2D = _knight.get_world_2d().direct_space_state
	var from: Vector2 = _knight.global_position
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 240), 1)
	query.exclude = [_knight.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	return float((hit["position"] as Vector2).y) if not hit.is_empty() else from.y


func _update_waves(delta: float) -> void:
	for wave: Node2D in _waves.duplicate():
		if not is_instance_valid(wave):
			_waves.erase(wave)
			continue
		var step: float = WAVE_SPEED * delta
		var dir: float = float(wave.get_meta("dir"))
		if _wave_hits_wall(wave, dir, step):
			_remove_wave(wave)
			continue
		wave.global_position.x += dir * step
		wave.set_meta("travelled", float(wave.get_meta("travelled")) + step)
		_check_wave_hit(wave)
		if float(wave.get_meta("travelled")) >= WAVE_TRAVEL:
			_remove_wave(wave)


func _check_wave_hit(wave: Node2D) -> void:
	if bool(wave.get_meta("hit")):
		return
	var player: Node2D = _player if _player and is_instance_valid(_player) else _knight.get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.has_method("take_damage"):
		return
	var offset: Vector2 = player.global_position - wave.global_position
	# Dalga zeminde ilerler: oyuncu zıplayıp dalganın üstündeyse vurulmaz
	if absf(offset.x) <= WAVE_HIT_HALF_WIDTH and offset.y <= 8.0 and offset.y >= -WAVE_HIT_HEIGHT:
		wave.set_meta("hit", true)
		player.take_damage(WAVE_DAMAGE, wave.global_position)


func _wave_hits_wall(wave: Node2D, dir: float, step: float) -> bool:
	if not wave.is_inside_tree():
		return true
	var space: PhysicsDirectSpaceState2D = wave.get_world_2d().direct_space_state
	var from: Vector2 = wave.global_position + Vector2(0, -12)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, from + Vector2(dir * (step + 4.0), 0), 1)
	query.exclude = [_knight.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	return not hit.is_empty() and not (hit.get("collider") as Node).is_in_group("player")


func _remove_wave(wave: Node2D) -> void:
	_waves.erase(wave)
	if is_instance_valid(wave):
		wave.queue_free()


func get_active_waves() -> Array[Node2D]:
	return _waves


# --- Zincir ---

func _resolve_chain() -> void:
	chain_cooldown = CHAIN_COOLDOWN
	var reason: String = _chain_invalid_reason()
	if not reason.is_empty():
		chain_missed.emit(reason)
		_enter_recovery()
		return
	_phase = "pull"
	_pull_time = 0.0
	_lock_player(true)
	_player.take_damage(CHAIN_DAMAGE, _knight.global_position)
	chain_caught.emit(_player)


func _chain_invalid_reason() -> String:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		return "no_target"
	if "is_dead" in _player and _player.is_dead:
		return "target_dead"
	var distance: float = _knight.global_position.distance_to(_player.global_position)
	if distance > CHAIN_MAX_RANGE + 40.0:
		return "out_of_range"
	if _player.global_position.distance_to(_locked_target) > 90.0:
		return "dodged"
	var space: PhysicsDirectSpaceState2D = _knight.get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(_knight.global_position + Vector2(0, -30), _player.global_position + Vector2(0, -30), 1)
	query.exclude = [_knight.get_rid(), _player.get_rid()]
	if not space.intersect_ray(query).is_empty():
		return "blocked"
	return ""


func _process_pull(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or ("is_dead" in _player and _player.is_dead):
		_release_player()
		_enter_recovery()
		return
	_pull_time += delta
	var dx: float = _knight.global_position.x - _player.global_position.x
	var remaining: float = absf(dx) - CHAIN_STOP_DISTANCE
	if remaining <= 0.0 or _pull_time >= CHAIN_MAX_PULL_TIME:
		_begin_stun()
		return
	var step: float = minf(CHAIN_PULL_SPEED * delta, remaining)
	# Yalnızca yatay çekme: oyuncu zemine gömülmez; duvara çarparsa çekme orada biter
	var collision: KinematicCollision2D = _player.move_and_collide(Vector2(signf(dx) * step, 0.0))
	_player.velocity = Vector2.ZERO
	if collision:
		_begin_stun()


func _begin_stun() -> void:
	_phase = "stun"
	_phase_timer = CHAIN_STUN


func _lock_player(locked: bool) -> void:
	if _player == null or not is_instance_valid(_player) or not "can_move" in _player:
		return
	if locked and not _player_locked:
		_player_locked = true
		_player.can_move = false
		_player.velocity = Vector2.ZERO
	elif not locked and _player_locked:
		_player_locked = false
		var game_state: Node = _knight.get_node_or_null("/root/GameState") if _knight.is_inside_tree() else null
		if not (game_state and game_state.is_in_cinematic):
			_player.can_move = true


func _release_player() -> void:
	_lock_player(false)


# --- Ortak ---

func _enter_recovery() -> void:
	_phase = "recovery"
	_phase_timer = RECOVERY
	_flash_knight(false)


func _finish() -> void:
	var skill: String = active_skill
	active_skill = ""
	_phase = ""
	_flash_knight(false)
	if "_is_attacking" in _knight:
		_knight._is_attacking = false
	skill_finished.emit(skill)


## Süren saldırıyı iptal eder; oyuncunun kilidi her durumda açılır
func cancel() -> void:
	_clear_telegraph()
	_release_player()
	if is_busy():
		_finish()


func _is_blocked() -> bool:
	if _knight == null or not is_instance_valid(_knight) or not _knight.is_inside_tree():
		return true
	if "is_dead" in _knight and _knight.is_dead:
		return true
	var game_state: Node = _knight.get_node_or_null("/root/GameState")
	return game_state != null and game_state.is_in_cinematic


func _exit_tree() -> void:
	_release_player()
	for wave: Node2D in _waves:
		if is_instance_valid(wave):
			wave.queue_free()
	_waves.clear()


func _flash_knight(on: bool) -> void:
	var visual: CanvasItem = _knight.get_node_or_null("Visual") as CanvasItem if _knight else null
	if visual:
		visual.modulate = Color(1.9, 0.45, 0.45, 1.0) if on else Color.WHITE


func _show_telegraph_line(skill: String) -> void:
	_clear_telegraph()
	_telegraph_line = Line2D.new()
	_telegraph_line.name = "SkillTelegraph"
	_telegraph_line.width = 3.0 if skill == "chain" else 6.0
	_telegraph_line.default_color = Color(0.75, 0.75, 0.8, 0.85) if skill == "chain" else Color(1.0, 0.15, 0.2, 0.55)
	_telegraph_line.z_index = 6
	var start: Vector2 = Vector2(0, -30) if skill == "chain" else Vector2(0, 0)
	var end_point: Vector2 = (_locked_target - _knight.global_position) + Vector2(0, -30) if skill == "chain" else Vector2(signf(_locked_target.x - _knight.global_position.x) * WAVE_TRAVEL, 0)
	_telegraph_line.points = PackedVector2Array([start, end_point])
	_knight.add_child(_telegraph_line)


func _clear_telegraph() -> void:
	if _telegraph_line and is_instance_valid(_telegraph_line):
		_telegraph_line.queue_free()
	_telegraph_line = null
