class_name DeathZone
extends Area2D

## res://scripts/hazards/death_zone.gd
## Harita altı boşluk ve ölüm çukuru alanı (Fall Death / Kill Zone).
## Oyuncu veya düşmanlar bu alana girdiğinde anında ölüm fonksiyonu tetiklenir.

signal entity_fell_into_void(entity: Node2D)

@export var instant_kill: bool = true
@export var damage_fallback: int = 9999


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Oyuncu ve karakter gövdeleri
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body):
		return

	entity_fell_into_void.emit(body)

	if body.is_in_group("player"):
		if body.has_method("die"):
			body.die()
		elif body.has_method("take_damage"):
			body.take_damage(damage_fallback)
	elif body.is_in_group("enemies") or body.is_in_group("boss"):
		if body.has_method("_die"):
			body._die()
		elif body.has_method("die"):
			body.die()
		elif body.has_method("take_damage"):
			body.take_damage(damage_fallback)
