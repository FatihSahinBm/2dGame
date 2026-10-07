extends Node2D

## res://scripts/combat/test_combat_scene.gd
## test_combat.tscn sahnesi için ana kontrolcü

@onready var player: Node2D = $TestPlayer
@onready var hud: CanvasLayer = $CombatHUD

func _ready() -> void:
	if player and hud:
		if player.has_signal("weapon_state_changed"):
			player.weapon_state_changed.connect(hud.update_weapon_status)
		if "has_sword" in player:
			hud.update_weapon_status(player.has_sword)
