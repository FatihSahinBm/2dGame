class_name CeilingLurkerBat
extends CharacterBody2D

## res://scripts/enemies/ceiling_lurker_bat.gd
## Tavanda pusuya yatan ve altından geçildiğinde hızla dalış yapan vampir yaratığı.

signal ambushed()

@export var max_health: int = 40
@export var current_health: int = 40
@export var dive_speed: float = 380.0
@export var chase_speed: float = 120.0
@export var damage: int = 15

var _is_dormant: bool = true
var _is_diving: bool = false
var _is_dead: bool = false
var _target_player: Node2D = null

@onready var visual: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var ambush_zone: Area2D = $AmbushZone
@onready var hitbox: Area2D = $Visual/Hitbox
@onready var health_bar: ProgressBar = get_node_or_null("UI/HealthBar") as ProgressBar


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false

	if ambush_zone:
		ambush_zone.body_entered.connect(_on_ambush_triggered)

	# Tavanda asılı başlangıç modu
	visual.scale.y = -1.0
	visual.modulate = Color(0.5, 0.45, 0.6, 0.85)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _is_dormant:
		velocity = Vector2.ZERO
		return

	if _is_diving:
		velocity.y = dive_speed
		if is_on_floor() or global_position.y >= 520.0:
			_is_diving = false
			velocity.y = 0.0
			visual.scale.y = 1.0
			visual.modulate = Color.WHITE
	else:
		_chase_player(delta)

	move_and_slide()


func _on_ambush_triggered(body: Node2D) -> void:
	if not _is_dormant or _is_dead:
		return
	if body.is_in_group("player"):
		_is_dormant = false
		_is_diving = true
		_target_player = body
		ambushed.emit()
		if health_bar:
			health_bar.visible = true

		if anim_sprite and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")


func _chase_player(_delta: float) -> void:
	if not _target_player or not is_instance_valid(_target_player):
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			_target_player = players[0] as Node2D

	if _target_player and is_instance_valid(_target_player):
		var dir: Vector2 = (_target_player.global_position - global_position).normalized()
		velocity = dir * chase_speed
		if dir.x != 0.0:
			visual.scale.x = absf(visual.scale.x) * signf(dir.x)


func take_damage(amount: int, attacker: Node2D = null) -> void:
	if _is_dead:
		return

	if _is_dormant:
		_is_dormant = false
		_is_diving = false
		visual.scale.y = 1.0
		visual.modulate = Color.WHITE

	current_health -= amount
	if health_bar:
		health_bar.visible = true
		health_bar.value = current_health

	var codex_mgr = get_node_or_null("/root/CodexManager")
	if codex_mgr and codex_mgr.has_method("record_encounter"):
		codex_mgr.record_encounter("ceiling_lurker_bat")

	var tw: Tween = create_tween()
	tw.tween_property(visual, "modulate", Color.RED, 0.06)
	tw.tween_property(visual, "modulate", Color.WHITE, 0.1)

	if attacker and attacker.is_in_group("player"):
		_target_player = attacker

	if current_health <= 0:
		_die()


func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO

	var codex_mgr = get_node_or_null("/root/CodexManager")
	if codex_mgr and codex_mgr.has_method("record_kill"):
		codex_mgr.record_kill("ceiling_lurker_bat")
	if anim_sprite and anim_sprite.sprite_frames.has_animation("death"):
		anim_sprite.play("death")
	queue_free()
