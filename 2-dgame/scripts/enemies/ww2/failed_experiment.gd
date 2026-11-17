class_name FailedExperiment
extends Ww2BossBase

## res://scripts/enemies/ww2/failed_experiment.gd
## Mini-Boss 2b — Başarısız Deney / Deney Kırk Dört (Epic 2D-144). Oyuncuyu kovalar;
## kükreme telegraph'ından sonra yere vurur (alan hasarı) ve slam_landed yayar —
## seviye her vuruşta okült arena duvarlarını içeri çekerek alanı daraltır.
## Başhekim ölürse öfkelenir (daha hızlı, daha kısa telegraph).

signal slam_landed(at: Vector2)

enum State { CHASE, ROAR, SLAM, RECOVER }

@export var slam_damage: int = 22
@export var slam_radius: float = 110.0
@export var roar_time: float = 0.75
@export var slam_interval: float = 3.2

var state: State = State.CHASE
var enraged: bool = false
var slam_count: int = 0
var _timer: float = 0.0
var _slam_cd: float = 2.0


func set_enraged() -> void:
	enraged = true
	move_speed *= 1.4
	roar_time *= 0.7


func _think(delta: float) -> void:
	_timer -= delta
	match state:
		State.CHASE:
			face_target()
			var dist: float = distance_to_target()
			var desired: float = float(facing) * move_speed if dist > 70.0 else 0.0
			velocity.x = move_toward(velocity.x, desired, 500.0 * delta)
			play_anim(&"walk" if absf(velocity.x) > 5.0 else &"idle")
			_slam_cd -= delta
			if _slam_cd <= 0.0 and dist < 180.0:
				state = State.ROAR
				_timer = roar_time
				velocity.x = 0.0
				play_anim(&"roar", true)
				sfx("mummy_groan" if not enraged else "shock_wave", -4.0)
		State.ROAR:
			velocity.x = 0.0
			if _timer <= 0.0:
				slam()
		State.SLAM, State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if _timer <= 0.0:
				state = State.CHASE


## Yere vuruş: yarıçap içindeki oyuncuya hasar, arena daralma sinyali
func slam() -> bool:
	state = State.RECOVER
	_timer = 1.2
	_slam_cd = slam_interval * (0.7 if enraged else 1.0)
	slam_count += 1
	play_anim(&"slam", true)
	sfx("shock_wave")
	var cam: Node = get_node_or_null("/root/CameraManager")
	if cam and cam.has_method("apply_shake"):
		cam.apply_shake(7.0, 1, 0.35, 25.0, "ww2_experiment_slam")
	var hit: bool = false
	var player: Node2D = find_player()
	# Havadaki (zıplayan) oyuncu yere vuruştan kaçar
	if player and player.global_position.distance_to(global_position) <= slam_radius:
		var grounded: bool = not (player is CharacterBody2D) or (player as CharacterBody2D).is_on_floor()
		if grounded:
			hit = hurt_player(slam_damage)
	slam_landed.emit(global_position)
	return hit
