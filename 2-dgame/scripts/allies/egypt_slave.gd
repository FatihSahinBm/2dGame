class_name EgyptSlave
extends CharacterBody2D

## res://scripts/allies/egypt_slave.gd
## Mazlum köle NPC'si (Epic 2D-143). "allies" grubundadır: kılıçla vurulursa ölür ve
## GameState.register_ally_kill (+12 Yozlaşma) işler. Kurtarılınca sevinip kaçar,
## sömürülünce ruhu çekilir ve solar.

signal killed(slave: EgyptSlave)
signal freed(slave: EgyptSlave)

enum State { CAGED, FREED, DRAINED, DEAD }

@export var slave_id: String = "slave"
@export var max_health: int = 30
@export var flee_direction: int = -1
@export var flee_speed: float = 70.0
@export var gravity: float = 1200.0

var current_health: int = 30
var state: State = State.CAGED
var is_dead: bool = false
var _flee_timer: float = 0.0

@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _ready() -> void:
	add_to_group("allies")
	add_to_group("damageable")
	add_to_group("egypt_slaves")
	current_health = max_health
	_play(&"cower")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	if state == State.FREED:
		_flee_timer -= delta
		velocity.x = float(flee_direction) * flee_speed if _flee_timer <= 0.0 else 0.0
		if _flee_timer <= 0.0:
			_play(&"walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	move_and_slide()


func take_damage(amount: int, _attacker: Variant = null) -> void:
	if is_dead or state == State.DRAINED:
		return
	current_health = maxi(0, current_health - maxi(1, amount))
	if anim_sprite:
		anim_sprite.modulate = Color(2.0, 0.5, 0.5)
		create_tween().tween_property(anim_sprite, "modulate", Color.WHITE, 0.2)
	if current_health <= 0:
		_die()


## Zincirler kırıldı: sevinç, ardından kaçış
func set_freed() -> void:
	if state != State.CAGED:
		return
	state = State.FREED
	_flee_timer = 1.2
	_play(&"cheer")
	freed.emit(self)
	var tw: Tween = create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(hide)


## Ruh enerjisi çekildi: soluklaşır ve çöker
func set_drained() -> void:
	if state != State.CAGED:
		return
	state = State.DRAINED
	is_dead = true
	remove_from_group("allies")
	remove_from_group("damageable")
	_play(&"drained")
	var tw: Tween = create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(hide)


## Kayıttan yüklenen sonuç: animasyonsuz uygulanır
func apply_resolved(outcome: String) -> void:
	state = State.FREED if outcome == "freed" else State.DEAD
	is_dead = outcome != "freed"
	remove_from_group("allies")
	remove_from_group("damageable")
	hide()
	set_physics_process(false)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	state = State.DEAD
	remove_from_group("allies")
	remove_from_group("damageable")
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and gs.has_method("register_ally_kill"):
		gs.register_ally_kill("slave")
	_play(&"death")
	killed.emit(self)
	var tw: Tween = create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(hide)


func _play(anim: StringName) -> void:
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim):
		anim_sprite.play(anim)
