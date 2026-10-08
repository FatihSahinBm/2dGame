extends Node2D
## res://scripts/dev/boss_arena.gd
## GOR'GATH Boss Arena - Epik Boss Savaşı Sahnesi
## Görseldeki tasarıma göre: Platformlar, HUD, Boss Health Bar, FPS overlay

# ── Düğüm referansları ──────────────────────────────────────────────────────
@onready var player_node: CharacterBody2D       = $Player
@onready var boss_node: CharacterBody2D         = $OgreBoss

# Boss Health Bar (üst merkez)
@onready var boss_hp_bar: ProgressBar           = $BossHUD/BossHealthPanel/VBox/HealthBar
@onready var boss_name_label: Label             = $BossHUD/BossHealthPanel/VBox/BossName
@onready var boss_subtitle_label: Label         = $BossHUD/BossHealthPanel/VBox/BossSubtitle
@onready var boss_hp_fill_style: StyleBoxFlat   = null

# Oyuncu HUD (üst sol)
@onready var player_hp_bar: ProgressBar         = $PlayerHUD/PlayerPanel/MarginContainer/VBox/HBoxBars/HPRow/HPBar
@onready var player_mp_bar: ProgressBar         = $PlayerHUD/PlayerPanel/MarginContainer/VBox/HBoxBars/MPRow/MPBar
@onready var player_hp_label: Label             = $PlayerHUD/PlayerPanel/MarginContainer/VBox/HBoxBars/HPRow/HPLabel
@onready var player_mp_label: Label             = $PlayerHUD/PlayerPanel/MarginContainer/VBox/HBoxBars/MPRow/MPLabel

# Debug Overlay (üst sağ)
@onready var fps_label: Label                   = $DebugOverlay/VBox/FPSLabel
@onready var godot_label: Label                 = $DebugOverlay/VBox/GodotLabel

# Bildirim
@onready var notification_label: Label          = $BossHUD/BossEnterLabel

# ── Sabitler ────────────────────────────────────────────────────────────────
const PLAYER_MAX_HP: int = 100
const PLAYER_MAX_MP: int = 40

var player_hp: int = 100
var player_mp: int = 40
var boss_entered: bool = false

# ── _ready ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Oyuncuyu gruba ekle
	if player_node and not player_node.is_in_group("player"):
		player_node.add_to_group("player")

	# Oyuncunun kılıçla başlamasını sağla
	if player_node and player_node.has_method("pickup_sword"):
		player_node.call_deferred("pickup_sword")

	# Boss sinyalini bağla (can değişikliği için)
	if boss_node:
		if boss_node.has_signal("health_changed"):
			boss_node.health_changed.connect(_on_boss_health_changed)
		if boss_node.has_signal("enemy_died"):
			boss_node.enemy_died.connect(_on_boss_died)
		# Boss HUD'ı ayarla
		_init_boss_hud()

	# Oyuncu HUD'ı ayarla
	_init_player_hud()

	# Boss giriş bildirimi
	_show_boss_intro()

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
		boss_subtitle_label.text = "DEV BOS"

func _on_boss_health_changed(new_hp: int, max_hp: int) -> void:
	if boss_hp_bar:
		boss_hp_bar.max_value = max_hp
		var tw: Tween = create_tween()
		tw.tween_property(boss_hp_bar, "value", float(new_hp), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_boss_died(_node) -> void:
	if boss_name_label:
		boss_name_label.text = "GOR'GATH - YENIK DÜŞTÜ"
		boss_name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))

# ── Oyuncu HUD ───────────────────────────────────────────────────────────────
func _init_player_hud() -> void:
	if player_hp_bar:
		player_hp_bar.max_value = PLAYER_MAX_HP
		player_hp_bar.value     = player_hp
	if player_mp_bar:
		player_mp_bar.max_value = PLAYER_MAX_MP
		player_mp_bar.value     = player_mp
	_refresh_player_labels()

func _refresh_player_labels() -> void:
	if player_hp_label:
		player_hp_label.text = "%d / %d" % [player_hp, PLAYER_MAX_HP]
	if player_mp_label:
		player_mp_label.text = "%d / %d" % [player_mp, PLAYER_MAX_MP]

# ── Boss Giriş Animasyonu ─────────────────────────────────────────────────────
func _show_boss_intro() -> void:
	if not notification_label:
		return
	notification_label.modulate.a = 0.0
	notification_label.visible    = true
	var tw: Tween = create_tween()
	tw.tween_property(notification_label, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.5)
	tw.tween_property(notification_label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func(): notification_label.visible = false)

# ── _process ─────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	# FPS göster
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	# Canlı boss HP güncelleme (signal yoksa polling)
	if boss_node and is_instance_valid(boss_node) and boss_hp_bar:
		var cur_hp = boss_node.get("current_health")
		if cur_hp != null:
			boss_hp_bar.value = float(cur_hp)

# ── Klavye girişleri ──────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_T:
			_damage_boss(25)
		KEY_K:
			_damage_boss(450)
		KEY_R:
			get_tree().reload_current_scene()
		KEY_Q:
			# Demo: Oyuncuya hasar ver
			player_hp = maxi(0, player_hp - 15)
			if player_hp_bar:
				var tw: Tween = create_tween()
				tw.tween_property(player_hp_bar, "value", float(player_hp), 0.2)
			_refresh_player_labels()

func _damage_boss(amount: int) -> void:
	if boss_node and is_instance_valid(boss_node) and boss_node.has_method("take_damage"):
		if not (boss_node.get("is_dead") == true):
			boss_node.take_damage(amount)
