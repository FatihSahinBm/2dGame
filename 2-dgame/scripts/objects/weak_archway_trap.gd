class_name WeakArchwayTrap
extends Node2D

## Weak Archway Trap for Stage 3 Arena 3 (Crumbling Ramparts)
## An ancient stone archway damaged by siege weaponry.
## When struck by the player or when Werewolf Vlad charges near it,
## the keystone shatters, dropping rubble that stuns and damages Vlad.

signal archway_collapsed(trap: Node2D)

@export var damage_amount: int = 40
@export var stun_seconds: float = 3.5

var _collapsed: bool = false

@onready var trigger_area: Area2D = get_node_or_null("TriggerArea")
@onready var arch_sprite: CanvasItem = get_node_or_null("ArchSprite") as CanvasItem
@onready var rubble_particles: CPUParticles2D = get_node_or_null("RubbleParticles")
@onready var debris_collider: CollisionShape2D = get_node_or_null("DebrisStaticBody/CollisionShape2D")

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)
		trigger_area.area_entered.connect(_on_trigger_area_entered)

func _on_trigger_body_entered(body: Node2D) -> void:
	if _collapsed:
		return
	if body.is_in_group("boss") or body.name.to_lower().contains("vlad"):
		collapse(body)

func _on_trigger_area_entered(area: Area2D) -> void:
	if _collapsed:
		return
	if area.is_in_group("player_hitbox") or area.is_in_group("boss_hitbox"):
		collapse(area.owner)

func take_damage(_amount: int, source: Node2D = null) -> void:
	collapse(source)

func collapse(source: Node2D = null) -> void:
	if _collapsed:
		return
	_collapsed = true
	
	archway_collapsed.emit(self)
	
	# Visual collapse
	if rubble_particles:
		rubble_particles.emitting = true
	
	if arch_sprite:
		var tw: Tween = create_tween()
		tw.tween_property(arch_sprite, "position:y", arch_sprite.position.y + 40.0, 0.4).set_trans(Tween.TRANS_BOUNCE)
		tw.parallel().tween_property(arch_sprite, "modulate:a", 0.4, 0.5)
	
	if debris_collider:
		debris_collider.set_deferred("disabled", false)
