class_name CursedSarcophagus
extends EgyptInteractable

## res://scripts/objects/egypt/cursed_sarcophagus.gd
## Lanetli Lahit (Epic 2D-143): içinde Firavun'a akıtılmış ruh enerjisi taşır.
## [E] ile seçim diyaloğu açılır (seviye yönetir): Sömür (+20 Yozlaşma, kurban sayacı, can)
## veya Kır (ruhlar serbest kalır). Kılıçla vurmak da lahdi kırar. Durum kalıcıdır.

signal drained(heal_amount: int)
signal shattered(at: Vector2)

enum State { CLOSED, DRAINED, BROKEN }

const TEX_CLOSED: Texture2D = preload("res://assets/objects/egypt/sarcophagus_closed.png")
const TEX_DRAINED: Texture2D = preload("res://assets/objects/egypt/sarcophagus_drained.png")
const TEX_BROKEN: Texture2D = preload("res://assets/objects/egypt/sarcophagus_broken.png")
const WISP_TEX: Texture2D = preload("res://assets/effects/egypt/soul_wisp.png")

@export var sacrifice_type: String = "sarcophagus_souls"

var state: State = State.CLOSED
var _sprite: Sprite2D = null
var _glow: CPUParticles2D = null


func _interactable_ready() -> void:
	add_to_group("damageable")
	add_to_group("cursed_sarcophagi")
	prompt_key = "PROMPT_EGYPT_SARCOPHAGUS"
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.offset = Vector2(0.0, -80.0)
		add_child(_sprite)
	_glow = _make_glow()
	add_child(_glow)
	if is_persisted("drained"):
		_set_state(State.DRAINED)
	elif is_persisted("broken"):
		_set_state(State.BROKEN)
	else:
		_set_state(State.CLOSED)


func is_closed() -> bool:
	return state == State.CLOSED


## Ruhları kılıca çeker: GameState kurban + yozlaşma işler, oyuncuyu iyileştirir
func drain(target: Node2D) -> int:
	if state != State.CLOSED:
		return 0
	var heal: int = 0
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and gs.has_method("register_ally_sacrifice"):
		heal = int(gs.register_ally_sacrifice(sacrifice_type))
	if is_instance_valid(target) and target.has_method("heal"):
		target.heal(heal)
	_spawn_soul_stream(target, true)
	_play("soul_drain")
	_set_state(State.DRAINED)
	persist("drained")
	drained.emit(heal)
	return heal


## Lahdi kırar ve ruhları serbest bırakır (yozlaşma yok)
func shatter() -> void:
	if state != State.CLOSED:
		return
	_spawn_soul_stream(null, false)
	_play("sarcophagus_break")
	_set_state(State.BROKEN)
	persist("broken")
	shattered.emit(global_position)


## Kılıç darbesi lahdi kırar
func take_damage(_amount: int, _attacker: Variant = null) -> void:
	shatter()


func _set_state(new_state: State) -> void:
	state = new_state
	if _sprite:
		match state:
			State.CLOSED:
				_sprite.texture = TEX_CLOSED
			State.DRAINED:
				_sprite.texture = TEX_DRAINED
			State.BROKEN:
				_sprite.texture = TEX_BROKEN
	if _glow:
		_glow.emitting = state == State.CLOSED
	set_interaction_enabled(state == State.CLOSED)


func _make_glow() -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.texture = WISP_TEX
	p.amount = 8
	p.lifetime = 1.6
	p.position = Vector2(0.0, -80.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(20.0, 50.0)
	p.direction = Vector2(0.0, -1.0)
	p.gravity = Vector2(0.0, -20.0)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 12.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.8
	p.color = Color(0.6, 0.8, 1.0, 0.8)
	return p


## Ruh enerjisi akışı: sömürüde oyuncuya, kırılınca göğe süzülür
func _spawn_soul_stream(target: Node2D, toward_target: bool) -> void:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.texture = WISP_TEX
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 28
	p.lifetime = 1.1
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 18.0
	p.color = Color(0.55, 0.75, 1.0, 1.0) if toward_target else Color(0.9, 0.95, 1.0, 1.0)
	var dir: Vector2 = Vector2(0.0, -1.0)
	if toward_target and is_instance_valid(target):
		dir = (target.global_position - global_position).normalized()
	p.direction = dir
	p.spread = 12.0 if toward_target else 40.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 140.0 if toward_target else 40.0
	p.initial_velocity_max = 220.0 if toward_target else 90.0
	p.emitting = true
	var host: Node = get_parent() if get_parent() else self
	host.add_child(p)
	p.global_position = global_position + Vector2(0.0, -70.0)
	p.finished.connect(p.queue_free)


func _play(key: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d(key, global_position, null, -2.0, 900.0)
