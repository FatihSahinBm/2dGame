extends Node2D

## res://scripts/dev/test_hayalet_adam.gd
## FreeKnight_v1 vs Hayalet Adam Dövüş Arenası

@onready var player: Player = $TestPlayer
@onready var ghost: CharacterBody2D = $HayaletAdamEnemy
@onready var hud: CanvasLayer = $FantasyHUD

const GHOST_SCENE: PackedScene = preload("res://scenes/enemies/hayalet_adam.tscn")
var ghost_spawn_pos: Vector2 = Vector2(620, 520)

func _ready() -> void:
	if ghost:
		ghost_spawn_pos = ghost.global_position
		_connect_ghost_signals(ghost)

	if player:
		# Oyuncuyu kılıç kuşanmış şekilde başlat
		player.has_sword = true
		player.is_armed = true
		if player.has_method("_emit_weapon_state"):
			player._emit_weapon_state()

		if hud:
			if player.has_signal("weapon_state_changed"):
				player.weapon_state_changed.connect(_on_weapon_state_changed)
			if player.has_signal("player_damaged"):
				player.player_damaged.connect(func(hp, max_hp):
					if hud.has_method("update_health"):
						hud.update_health(hp, max_hp)
				)
			if hud.has_method("update_weapon_slot"):
				hud.update_weapon_slot(true, true)
			if hud.has_method("set_tutorial"):
				hud.set_tutorial("Hayalet Adam ile Dövüş!", "Sol Tık / J: Saldır", "Sol Tık: Hafif Vuruş | Sağ Tık: Güçlü Darbe | Shift: Dash | [R]: Canavarı Yeniden Doğur")

func _connect_ghost_signals(g: Node2D) -> void:
	if not g:
		return
	if g.has_signal("enemy_died"):
		g.enemy_died.connect(func(_inst):
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial("Zafer!", "Hayalet Adam Yenildi", "[R] tuşuna basarak canavarı tekrar çağırabilirsin!")
		)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_respawn_ghost()
			KEY_H:
				if player and player.has_method("take_damage"):
					player.take_damage(20)

func _respawn_ghost() -> void:
	# Mevcut olanı temizle
	var existing = get_node_or_null("HayaletAdamEnemy")
	if existing and is_instance_valid(existing):
		existing.queue_free()

	await get_tree().process_frame

	var new_ghost = GHOST_SCENE.instantiate()
	new_ghost.name = "HayaletAdamEnemy"
	new_ghost.global_position = ghost_spawn_pos
	add_child(new_ghost)
	ghost = new_ghost
	_connect_ghost_signals(new_ghost)

	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial("Hayalet Adam ile Dövüş!", "Sol Tık / J: Saldır", "Sol Tık: Hafif Vuruş | Sağ Tık: Güçlü Darbe | Shift: Dash | [R]: Yeniden Doğur")

func _on_weapon_state_changed(has_weapon: bool, is_armed: bool = true) -> void:
	if hud and hud.has_method("update_weapon_slot"):
		hud.update_weapon_slot(has_weapon, is_armed)
