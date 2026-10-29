class_name BarricadeHurtbox
extends Area2D

## res://scripts/objects/barricade_hurtbox.gd
## Barikatın hurtbox alanına gelen tüm hasarları ana barikat nesnesine iletir.

func _ready() -> void:
	if not is_in_group("burnable"):
		add_to_group("burnable")


func take_damage(amount: int, attacker = null) -> void:
	var parent_node = get_parent()
	if parent_node and parent_node.has_method("take_damage"):
		parent_node.take_damage(amount, attacker)


func ignite(amount: int = 30) -> void:
	var parent_node = get_parent()
	if parent_node and parent_node.has_method("ignite"):
		parent_node.ignite(amount)
	elif parent_node and parent_node.has_method("take_damage"):
		parent_node.take_damage(amount)


func hit(amount: int) -> void:
	take_damage(amount)
