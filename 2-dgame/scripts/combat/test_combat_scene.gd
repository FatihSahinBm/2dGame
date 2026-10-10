extends Node2D

## res://scripts/combat/test_combat_scene.gd
## test_combat.tscn sahnesi için ana kontrolcü

@onready var player: Node2D = $TestPlayer
@onready var hud: CanvasLayer = $FantasyHUD
@onready var vlad: Node2D = get_node_or_null("VladBoss")


func _ready() -> void:
	if player and hud:
		# Kılıç kuşanma durumunu HUD elmas slotuna bağla
		if player.has_signal("weapon_state_changed"):
			player.weapon_state_changed.connect(_on_weapon_state_changed)
		if player.has_signal("player_damaged"):
			player.player_damaged.connect(func(hp, max_hp):
				if hud.has_method("update_health"):
					hud.update_health(hp, max_hp)
			)
		if "has_sword" in player and hud.has_method("update_weapon_slot"):
			var is_armed = player.is_armed if "is_armed" in player else player.has_sword
			hud.update_weapon_slot(player.has_sword, is_armed)
		_update_hud_tutorial(player.has_sword if "has_sword" in player else false, player.is_armed if "is_armed" in player else false)

func _on_weapon_state_changed(has_weapon: bool, is_armed: bool = true) -> void:
	if hud and hud.has_method("update_weapon_slot"):
		hud.update_weapon_slot(has_weapon, is_armed)
	_update_hud_tutorial(has_weapon, is_armed)

func _update_hud_tutorial(has_weapon: bool, is_armed: bool = false) -> void:
	if not hud or not hud.has_method("set_tutorial"):
		return
	if has_weapon:
		if is_armed:
			hud.set_tutorial("Kılıç Çekili (Armed)", "[1] Kınına Sok", "Sol/Sağ Tık: Saldır | [1]: Kına Sok | [G]: Kılıcı At")
		else:
			hud.set_tutorial("Kılıç Kında (Sheathed)", "[1] Kılıcı Çek", "[1]: Kılıcı Çek | Sol Tık: Hızlı Çek & Saldır")
	else:
		hud.set_tutorial("Çeviklik & Keşif", "E", "[E] ile kılıcı kuşan | Shift: Dash | Ctrl: Eğil | Alt: Roll")

func _unhandled_input(event: InputEvent) -> void:
	if not hud:
		return

	# HUD Test Kısayolları (Geliştirici testi için)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_H:
				# [H] Hasar testi (-20 Can)
				if player and player.has_method("take_damage"):
					player.take_damage(20)
				elif "current_health" in hud:
					hud.update_health(hud.current_health - 20)
			KEY_M:
				# [M] Mana harcama testi (-10 Mana)
				if "current_mana" in hud:
					hud.update_mana(hud.current_mana - 10)
			KEY_C:
				# [C] Altın toplama testi (+1 Sikke)
				if "coins" in hud:
					hud.update_coins(hud.coins + 1)
			KEY_Y:
				# [Y] Anahtar toplama testi (+1 Anahtar)
				if "keys" in hud:
					hud.update_keys(hud.keys + 1)
			KEY_B:
				# [B] Vlad Form Değişimi (Normal -> Vampir -> Kurt Adam -> Yarasa)
				if vlad and vlad.has_method("set_form"):
					var next_form = (vlad.current_form + 1) % 4
					vlad.set_form(next_form, true)
			KEY_V:
				# [V] Vlad Hasar Testi (-75 HP)
				if vlad and vlad.has_method("take_damage"):
					vlad.take_damage(75)
			KEY_X:
				# [X] Vlad Nihai Ölüm Sekansı Testi
				if vlad and vlad.has_method("take_damage"):
					vlad.take_damage(999)
			KEY_R:
				# [R] Sahneyi yeniden başlat
				get_tree().reload_current_scene()
