class_name SunBeam
extends Node2D

## res://scripts/hazards/egypt/sun_beam.gd
## Güneş ışını (Epic 2D-143): önce yerde/sütunda kızıl bir telegraph belirir, ardından
## dikey ışın ateşlenir ve içindeki oyuncuya bir kez hasar verir. Tuzak koridorlarında
## periyodik, Firavun'un Güneş Asası saldırısında tek atımlık (one_shot) kullanılır.
## Konum: ışının zemine değdiği nokta (alt orta).

signal telegraph_started()
signal beam_fired()
signal beam_finished()

enum Phase { IDLE, TELEGRAPH, FIRE, COOLDOWN }

const BEAM_TEX: Texture2D = preload("res://assets/effects/egypt/sun_beam.png")
const TELE_TEX: Texture2D = preload("res://assets/effects/egypt/sun_beam_telegraph.png")

@export var damage: int = 22
@export var beam_width: float = 48.0
@export var beam_height: float = 640.0
@export var telegraph_time: float = 0.9
@export var active_time: float = 0.45
@export var interval: float = 2.4
@export var start_delay: float = 0.0
@export var one_shot: bool = false
@export var autostart: bool = true

var phase: Phase = Phase.IDLE
var _timer: float = 0.0
var _hit_bodies: Array[Node2D] = []
var _area: Area2D = null
var _beam: Sprite2D = null
var _tele: Sprite2D = null


func _ready() -> void:
	add_to_group("egypt_hazards")
	_tele = _make_sprite(TELE_TEX, Vector2(beam_width / 8.0 * 0.5, beam_height / 256.0))
	_beam = _make_sprite(BEAM_TEX, Vector2(beam_width / 32.0, beam_height / 256.0))
	_beam.modulate = Color(1.4, 1.2, 0.9, 0.95)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	_area.monitoring = false
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(beam_width * 0.8, beam_height)
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0.0, -beam_height * 0.5)
	_area.add_child(col)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	if autostart:
		_timer = start_delay
		phase = Phase.COOLDOWN if start_delay > 0.0 else Phase.IDLE
		if start_delay <= 0.0:
			fire_sequence()


func _process(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	_timer -= delta
	if phase == Phase.TELEGRAPH:
		var cm: Node = get_node_or_null("/root/CinematicManager")
		var calm: bool = cm != null and "reduce_flashing" in cm and bool(cm.reduce_flashing)
		_tele.modulate.a = 0.85 if calm else 0.45 + 0.4 * absf(sin(_timer * 18.0))
	if _timer > 0.0:
		return
	match phase:
		Phase.TELEGRAPH:
			_fire()
		Phase.FIRE:
			_end_fire()
		Phase.COOLDOWN:
			fire_sequence()


## Telegraph + ateş döngüsünü başlatır
func fire_sequence() -> void:
	phase = Phase.TELEGRAPH
	_timer = telegraph_time
	_tele.visible = true
	_beam.visible = false
	telegraph_started.emit()
	_play("sun_beam_charge", -8.0)


func is_dangerous() -> bool:
	return phase == Phase.FIRE


func _fire() -> void:
	phase = Phase.FIRE
	_timer = active_time
	_tele.visible = false
	_beam.visible = true
	_beam.scale.x = 0.2 * beam_width / 32.0
	create_tween().tween_property(_beam, "scale:x", beam_width / 32.0, 0.08)
	_hit_bodies.clear()
	_area.monitoring = true
	beam_fired.emit()
	_play("sun_beam_fire", -4.0)
	# Işın başladığında zaten içeride olanlar
	for body: Node2D in _area.get_overlapping_bodies():
		_on_body_entered(body)


func _end_fire() -> void:
	_area.set_deferred("monitoring", false)
	_beam.visible = false
	beam_finished.emit()
	if one_shot:
		phase = Phase.IDLE
		queue_free()
		return
	phase = Phase.COOLDOWN
	_timer = interval


## Işın aktifken temas eden oyuncuya bir kez hasar verir
func hit_body(body: Node2D) -> bool:
	if phase != Phase.FIRE or _hit_bodies.has(body) or not body.has_method("take_damage"):
		return false
	_hit_bodies.append(body)
	body.take_damage(damage, global_position)
	return true


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		hit_body(body)


func _make_sprite(tex: Texture2D, scl: Vector2) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = true
	s.scale = scl
	s.position = Vector2(0.0, -beam_height * 0.5)
	s.visible = false
	s.z_index = 20
	add_child(s)
	return s


func _play(key: String, vol: float) -> void:
	var am: Node = get_node_or_null("/root/AudioManager") if is_inside_tree() else null
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d(key, global_position, null, vol, 1000.0)
