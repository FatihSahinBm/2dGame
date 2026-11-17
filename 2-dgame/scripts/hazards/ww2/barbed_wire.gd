class_name BarbedWire
extends Area2D

## res://scripts/hazards/ww2/barbed_wire.gd
## Dikenli tel engeli (Epic 2D-144): içindeki oyuncuyu yavaşlatır ve aralıklarla yaralar.
## Kan Sisi Atılması (blood_mist_dash) sırasında telden zarar görmeden geçilir.

signal player_snagged()

@export var damage_per_tick: int = 5
@export var tick_interval: float = 0.6
@export var slow_factor: float = 0.45

var _player: Node2D = null
var _tick: float = 0.0
var _base_speed: float = -1.0


func _ready() -> void:
	add_to_group("ww2_hazards")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	if is_mist_passing(_player):
		_restore_speed()
		return
	_apply_slow()
	_tick -= delta
	if _tick <= 0.0:
		_tick = tick_interval
		apply_tick(_player)


static func is_mist_passing(body: Node) -> bool:
	return "is_blood_mist_dashing" in body and bool(body.is_blood_mist_dashing)


## Tek hasar tıkı (testler doğrudan çağırır). Kan sisindeki hedefe hasar vermez.
func apply_tick(target: Node) -> bool:
	if not is_instance_valid(target) or is_mist_passing(target) or not target.has_method("take_damage"):
		return false
	target.take_damage(damage_per_tick, global_position)
	player_snagged.emit()
	return true


func _apply_slow() -> void:
	if "speed" in _player and _base_speed < 0.0:
		_base_speed = float(_player.speed)
		_player.speed = _base_speed * slow_factor


func _restore_speed() -> void:
	if is_instance_valid(_player) and _base_speed >= 0.0 and "speed" in _player:
		_player.speed = _base_speed
	_base_speed = -1.0


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body
		_tick = 0.15


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_restore_speed()
		_player = null


func _exit_tree() -> void:
	_restore_speed()
