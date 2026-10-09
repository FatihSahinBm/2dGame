extends Node2D

## res://scripts/dev/boss_arena.gd
## Ogre Boss Arena - test_combat zemin ve sistemleri tabanlı Boss Savaşı Sahnesi
## FantasyHUD + Ogre Boss + Boss Can Barı + Geliştirici Test Kontrolleri

# ── Düğüm Referansları ───────────────────────────────────────────────────────
@onready var player: CharacterBody2D           = $TestPlayer
@onready var hud: CanvasLayer                  = $FantasyHUD
@onready var boss_node: CharacterBody2D        = $OgreBoss

# Boss HUD
@onready var boss_hp_bar: ProgressBar          = $BossHUD/BossHealthPanel/VBox/HealthBar
@onready var boss_name_label: Label            = $BossHUD/BossHealthPanel/VBox/BossName
@onready var boss_subtitle_label: Label        = $BossHUD/BossHealthPanel/VBox/BossSubtitle
@onready var boss_hp_text: Label               = $BossHUD/BossHealthPanel/VBox/HPText
@onready var notification_label: Label         = $BossHUD/BossEnterLabel

# ── _ready ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Oyuncu ve FantasyHUD bağlantıları
	if player and hud:
		if not player.is_in_group("player"):
			player.add_to_group("player")

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

	# Boss bağlantıları
	if boss_node:
		if boss_node.has_signal("health_changed"):
			boss_node.health_changed.connect(_on_boss_health_changed)
		if boss_node.has_signal("enemy_died"):
			boss_node.enemy_died.connect(_on_boss_died)
		_init_boss_hud()

	# Boss giriş bildirimi
	_show_boss_intro()

# ── HUD Tutorial ─────────────────────────────────────────────────────────────
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

# ── Boss HUD ─────────────────────────────────────────────────────────────────
func _init_boss_hud() -> void:
	if not boss_node or not boss_hp_bar:
		return
	var max_hp: int = boss_node.get("max_health") if "max_health" in boss_node else 450
	var cur_hp: int = boss_node.get("current_health") if "current_health" in boss_node else max_hp
	boss_hp_bar.max_value = max_hp
	boss_hp_bar.value     = cur_hp
	if boss_name_label:
		boss_name_label.text = "GOR'GATH, THE OGRE GIANT"
	if boss_subtitle_label:
		boss_subtitle_label.text = "DEV BOSS"
	if boss_hp_text:
		boss_hp_text.text = "%d / %d HP" % [cur_hp, max_hp]

func _on_boss_health_changed(new_hp: int, max_hp: int) -> void:
	if boss_hp_bar:
		boss_hp_bar.max_value = max_hp
		var tw: Tween = create_tween()
		tw.tween_property(boss_hp_bar, "value", float(new_hp), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if boss_hp_text:
		boss_hp_text.text = "%d / %d HP" % [maxi(0, new_hp), max_hp]

func _on_boss_died(_node) -> void:
	if boss_name_label:
		boss_name_label.text = "GOR'GATH - YENİK DÜŞTÜ"
		boss_name_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60, 1.0))
	if boss_hp_text:
		boss_hp_text.text = "0 / %d HP" % int(boss_hp_bar.max_value if boss_hp_bar else 450)

# ── Boss Giriş Animasyonu ────────────────────────────────────────────────────
func _show_boss_intro() -> void:
	if not notification_label:
		return
	notification_label.modulate.a = 0.0
	notification_label.visible    = true
	var tw: Tween = create_tween()
	tw.tween_property(notification_label, "modulate:a", 1.0, 0.5)
	tw.tween_interval(2.0)
	tw.tween_property(notification_label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): notification_label.visible = false)

# ── Klavye Kısayolları ve Test Kontrolleri ──────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_T:
			# Boss'a 25 hasar ver
			_damage_boss(25)
		KEY_K:
			# Boss'u tek vuruşta öldür
			_damage_boss(450)
		KEY_R:
			# Sahneyi sıfırla
			get_tree().reload_current_scene()
		KEY_H:
			# [H] Oyuncuya hasar testi (-20 Can)
			if player and player.has_method("take_damage"):
				player.take_damage(20)
			elif hud and "current_health" in hud:
				hud.update_health(hud.current_health - 20)
		KEY_M:
			# [M] Mana harcama testi (-10 Mana)
			if hud and "current_mana" in hud:
				hud.update_mana(hud.current_mana - 10)
		KEY_C:
			# [C] Altın testi (+1 Sikke)
			if hud and "coins" in hud:
				hud.update_coins(hud.coins + 1)
		KEY_Y:
			# [Y] Anahtar testi (+1 Anahtar)
			if hud and "keys" in hud:
				hud.update_keys(hud.keys + 1)

func _damage_boss(amount: int) -> void:
	if boss_node and is_instance_valid(boss_node) and boss_node.has_method("take_damage"):
		if not (boss_node.get("is_dead") == true):
			boss_node.take_damage(amount)
