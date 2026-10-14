extends Node2D

## ==============================================================================
## CYBER T-REX BOSS TEST ARENASI KONTROLCÜSÜ (test_trex_boss.gd)
## ==============================================================================
## Tüm 11 animasyonun gerçek zamanlı testi, oyuncu dövüş entegrasyonu,
## FantasyHUD, dinamik faz yönetimi ve hata ayıklama arayüzü.
## ==============================================================================

@onready var player: CharacterBody2D       = $TestPlayer
@onready var boss: CharacterBody2D         = $TrexBoss
@onready var hud: CanvasLayer              = get_node_or_null("FantasyHUD")

# Boss HUD Elemanları
@onready var boss_hp_bar: ProgressBar      = get_node_or_null("UI/BossHealthPanel/VBox/HealthBar")
@onready var boss_name_label: Label        = get_node_or_null("UI/BossHealthPanel/VBox/BossName")
@onready var boss_phase_label: Label       = get_node_or_null("UI/BossHealthPanel/VBox/PhaseLabel")
@onready var boss_hp_text: Label           = get_node_or_null("UI/BossHealthPanel/VBox/HPText")
@onready var anim_status_label: Label      = get_node_or_null("UI/AnimStatusLabel")
@onready var btn_damage_50: Button         = get_node_or_null("UI/ControlPanel/VBox/HBoxButtons/BtnDamage50")
@onready var btn_phase2: Button            = get_node_or_null("UI/ControlPanel/VBox/HBoxButtons/BtnPhase2")
@onready var btn_stagger: Button           = get_node_or_null("UI/ControlPanel/VBox/HBoxButtons/BtnStagger")
@onready var btn_reset: Button             = get_node_or_null("UI/ControlPanel/VBox/HBoxButtons/BtnReset")

func _ready() -> void:
	# 1. Oyuncu ve HUD Kurulumu
	if player:
		if not player.is_in_group("player"):
			player.add_to_group("player")
		
		if hud:
			if player.has_signal("weapon_state_changed"):
				player.weapon_state_changed.connect(_on_weapon_state_changed)
			if player.has_signal("player_damaged"):
				player.player_damaged.connect(func(hp, max_hp):
					if hud.has_method("update_health"):
						hud.update_health(hp, max_hp)
				)
			if player.has_signal("shield_state_changed"):
				player.shield_state_changed.connect(func(is_holding: bool):
					_update_hud_tutorial(player.has_sword if "has_sword" in player else false, player.is_armed if "is_armed" in player else false, is_holding)
				)
			if "has_sword" in player and hud.has_method("update_weapon_slot"):
				var is_armed = player.is_armed if "is_armed" in player else player.has_sword
				hud.update_weapon_slot(player.has_sword, is_armed)
			_update_hud_tutorial(player.has_sword if "has_sword" in player else false, player.is_armed if "is_armed" in player else false, player.is_holding_shield if "is_holding_shield" in player else false)
		
		# Test kolaylığı için kılıç kuşan
		if player.has_method("pickup_sword"):
			player.call_deferred("pickup_sword")

	# 2. Boss Sinyalleri ve HUD Bağlantısı
	if boss:
		if boss.has_signal("health_changed"):
			boss.health_changed.connect(_on_boss_health_changed)
		if boss.has_signal("phase_changed"):
			boss.phase_changed.connect(_on_boss_phase_changed)
		if boss.has_signal("boss_staggered"):
			boss.boss_staggered.connect(_on_boss_staggered)
		if boss.has_signal("enemy_died"):
			boss.enemy_died.connect(_on_boss_died)
		_init_boss_hud()

	# 3. Buton Bağlantıları
	if btn_damage_50:
		btn_damage_50.pressed.connect(func(): _damage_boss(50))
	if btn_phase2:
		btn_phase2.pressed.connect(func(): _damage_boss(350))
	if btn_stagger:
		btn_stagger.pressed.connect(func():
			if boss and boss.has_method("_enter_groggy_state"):
				boss._enter_groggy_state()
		)
	if btn_reset:
		btn_reset.pressed.connect(func(): get_tree().reload_current_scene())

func _process(_delta: float) -> void:
	_update_live_debug_status()

func _update_live_debug_status() -> void:
	if not anim_status_label or not boss:
		return
	
	var anim_name = "N/A"
	var anim_sprite = boss.get_node_or_null("Visual/AnimatedSprite2D")
	if anim_sprite:
		anim_name = str(anim_sprite.animation)
		if not anim_sprite.is_playing():
			anim_name += " [DURDU]"

	var dist: float = 0.0
	if player:
		dist = boss.global_position.distance_to(player.global_position)

	var state_str: String = "Bilinmiyor"
	match boss.current_state:
		0: state_str = "Devriye (Patrol - Walk)"
		1: state_str = "Kovalamaca (Chase - %s)" % ("Run" if dist > 220.0 or boss.boss_phase >= 3 else "Walk")
		2: state_str = "SALDIRI (Attack - %s)" % boss._special_attack_type
		3: state_str = "Hasar Alma (Hurt)"
		4: state_str = "ÖLÜ (Dead)"
		5: state_str = "SERSEMLEDİ (Groggy / Stun)"

	anim_status_label.text = "SİBER T-REX CANLI DURUM:\n• Animasyon: %s (Kare: %d)\n• Durum: %s\n• Mesafe: %.1f px | Faz: %d\n• Stagger Birikimi: %d/%d" % [
		anim_name,
		anim_sprite.frame if anim_sprite else 0,
		state_str,
		dist,
		boss.boss_phase,
		boss._current_stagger,
		boss.stagger_threshold
	]

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		# Animasyon Hızlı Önizleme / Manuel Tetikleme Kısayolları (1-0)
		KEY_1:
			_preview_anim(&"idle")
		KEY_2:
			_preview_anim(&"walk")
		KEY_3:
			_preview_anim(&"run")
		KEY_4:
			_preview_anim(&"attack_bite")
		KEY_5:
			_preview_anim(&"attack_laser")
		KEY_6:
			_preview_anim(&"attack_platform_slam")
		KEY_7:
			_preview_anim(&"grab_counter")
		KEY_8:
			_preview_anim(&"stunned_groggy")
		KEY_9:
			_preview_anim(&"hurt")
		KEY_0:
			_preview_anim(&"intro_taunt")
		
		# Boss Dövüş Test Kısayolları
		KEY_T:
			_damage_boss(50)
		KEY_K:
			_damage_boss(750)
		KEY_P:
			# Faz döngüsü (1 -> 2 -> 3)
			if boss:
				var next_p = (boss.boss_phase % 3) + 1
				boss._on_phase_changed(next_p)
		KEY_R:
			get_tree().reload_current_scene()
		KEY_H:
			# Oyuncuya hasar testi
			if player and player.has_method("take_damage"):
				player.take_damage(25)
			elif hud and "current_health" in hud:
				hud.update_health(hud.current_health - 25)

func _preview_anim(anim_name: StringName) -> void:
	if not boss:
		return
	var anim_sprite = boss.get_node_or_null("Visual/AnimatedSprite2D")
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
		anim_sprite.play(anim_name)
		print("MANUEL ANİMASYON ÖNİZLEMESİ: ", anim_name)

func _damage_boss(amount: int) -> void:
	if boss and is_instance_valid(boss) and boss.has_method("take_damage"):
		if not boss.is_dead:
			boss.take_damage(amount)

func _init_boss_hud() -> void:
	if not boss or not boss_hp_bar:
		return
	boss_hp_bar.max_value = boss.max_health
	boss_hp_bar.value     = boss.current_health
	if boss_hp_text:
		boss_hp_text.text = "%d / %d HP" % [boss.current_health, boss.max_health]
	if boss_phase_label:
		boss_phase_label.text = "[ FAZ 1: STANDART ]"

func _on_boss_health_changed(cur_hp: int, max_hp: int) -> void:
	if boss_hp_bar:
		boss_hp_bar.max_value = max_hp
		var tw = create_tween()
		tw.tween_property(boss_hp_bar, "value", float(cur_hp), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if boss_hp_text:
		boss_hp_text.text = "%d / %d HP" % [maxi(0, cur_hp), max_hp]

func _on_boss_phase_changed(phase: int) -> void:
	if boss_phase_label:
		if phase == 2:
			boss_phase_label.text = "[ FAZ 2: OVERDRIVE ]"
			boss_phase_label.modulate = Color(1.0, 0.6, 0.1, 1.0)
		elif phase == 3:
			boss_phase_label.text = "[ FAZ 3: SİBER ERİME ]"
			boss_phase_label.modulate = Color(1.0, 0.1, 0.1, 1.0)

func _on_boss_staggered() -> void:
	if boss_phase_label:
		var orig = boss_phase_label.text
		boss_phase_label.text = "⚡ STAGGER: DURUŞ KIRILDI! ⚡"
		get_tree().create_timer(2.4).timeout.connect(func():
			if is_instance_valid(boss_phase_label) and boss:
				_on_boss_phase_changed(boss.boss_phase)
		)

func _on_boss_died(_node) -> void:
	if boss_name_label:
		boss_name_label.text = "SİBER T-REX - ETKİSİZ HALE GETİRİLDİ"
		boss_name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1.0))
	if boss_hp_text:
		boss_hp_text.text = "0 / %d HP" % int(boss_hp_bar.max_value if boss_hp_bar else 750)

func _on_weapon_state_changed(has_weapon: bool, is_armed: bool = true) -> void:
	if hud and hud.has_method("update_weapon_slot"):
		hud.update_weapon_slot(has_weapon, is_armed)
	_update_hud_tutorial(has_weapon, is_armed, player.is_holding_shield if player and "is_holding_shield" in player else false)

func _update_hud_tutorial(has_weapon: bool, is_armed: bool = false, is_holding_shield: bool = false) -> void:
	if not hud or not hud.has_method("set_tutorial"):
		return
	if is_holding_shield:
		hud.set_tutorial("Kalkan Elde (Shield)", "[3] İndir", "Sağ Tık: Kalkanı Aç/Savun | [3]: Kalkanı İndir")
	elif has_weapon:
		if is_armed:
			hud.set_tutorial("Kılıç Çekili (Armed)", "[1] Kınına Sok", "Sol Tık: Saldır | Sağ Tık: Ağır Saldırı | [Shift]: Dash | [F]: Parry")
		else:
			hud.set_tutorial("Kılıç Kında (Sheathed)", "[1] Kılıcı Çek", "[1]: Kılıcı Çek | [3]: Kalkan Al | Sol Tık: Hızlı Saldırı")
	else:
		hud.set_tutorial("Çeviklik & Keşif", "E", "[E]: Kılıcı Kuşan | [3]: Kalkan Al | Shift: Dash | Ctrl: Eğil")
