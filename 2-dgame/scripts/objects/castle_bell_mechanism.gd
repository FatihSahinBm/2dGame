class_name CastleBellMechanism
extends Area2D

## Great Bell Mechanism for Stage 3 Arena 4 (Bell Tower & Courtyard)
## Striking or interacting with this chain rings the Great Bell of Targoviste.
## The acoustic shockwave forces Bat Vlad out of aerial dive and causes a temporary groggy/stun state.

signal bell_rung(ringer: Node2D)

@export var cooldown_seconds: float = 6.0
@export var stun_duration: float = 4.0

var _is_on_cooldown: bool = false
var _cooldown_timer: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var bell_sprite: Node2D = (get_node_or_null("BellVisual") if has_node("BellVisual") else get_node_or_null("BellSprite")) as Node2D
@onready var sfx: AudioStreamPlayer2D = get_node_or_null("BellSFX")

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Detect player melee attacks / bodies
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	if _is_on_cooldown:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_is_on_cooldown = false
			modulate = Color(1, 1, 1, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		ring_bell(body)

func _on_area_entered(area: Area2D) -> void:
	# Also trigger if player weapon hitbox overlaps
	if area.is_in_group("player_hitbox") or area.name.contains("Attack") or area.name.contains("Sword"):
		ring_bell(area.owner)

func take_damage(_amount: int, source: Node2D = null) -> void:
	ring_bell(source)

func ring_bell(source: Node2D = null) -> void:
	if _is_on_cooldown:
		return
	
	_is_on_cooldown = true
	_cooldown_timer = cooldown_seconds
	modulate = Color(0.6, 0.6, 0.8, 0.7)
	
	bell_rung.emit(source)
	
	# Visual bell swing tween
	if bell_sprite:
		var tw: Tween = create_tween()
		tw.tween_property(bell_sprite, "rotation_degrees", 15.0, 0.1)
		tw.tween_property(bell_sprite, "rotation_degrees", -15.0, 0.15)
		tw.tween_property(bell_sprite, "rotation_degrees", 8.0, 0.15)
		tw.tween_property(bell_sprite, "rotation_degrees", 0.0, 0.2)
	
	if sfx and sfx.stream:
		sfx.play()
