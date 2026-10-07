extends Node2D

## res://scripts/combat/test_combat_scene.gd
## test_combat.tscn sahnesi için ana kontrolcü

@onready var player: Node2D = $TestPlayer
@onready var hud: CanvasLayer = $FantasyHUD

func _ready() -> void:
	if player and hud:
		# Kılıç kuşanma durumunu HUD elmas slotuna bağla
		if player.has_signal("weapon_state_changed"):
			player.weapon_state_changed.connect(_on_weapon_state_changed)
		if "has_sword" in player and hud.has_method("update_weapon_slot"):
			hud.update_weapon_slot(player.has_sword)

func _on_weapon_state_changed(has_weapon: bool) -> void:
	if hud and hud.has_method("update_weapon_slot"):
		hud.update_weapon_slot(has_weapon)

func _unhandled_input(event: InputEvent) -> void:
	if not hud:
		return

	# HUD Test Kısayolları (Geliştirici testi için)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_H:
				# [H] Hasar testi (-20 Can)
				if "current_health" in hud:
					hud.update_health(hud.current_health - 20)
			KEY_M:
				# [M] Mana harcama testi (-10 Mana)
				if "current_mana" in hud:
					hud.update_mana(hud.current_mana - 10)
			KEY_C:
				# [C] Altın toplama testi (+1 Sikke)
				if "coins" in hud:
					hud.update_coins(hud.coins + 1)
			KEY_K:
				# [K] Anahtar toplama testi (+1 Anahtar)
				if "keys" in hud:
					hud.update_keys(hud.keys + 1)
