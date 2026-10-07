extends CanvasLayer
class_name FantasyHUD

## res://scripts/ui/fantasy_hud.gd
## Dark Fantasy Temalı Kapsamlı Oyuncu Arayüzü (HUD)

signal pause_toggled(is_paused: bool)
signal potion_used(potion_type: String)

@export_group("Stats")
@export var max_health: int = 100
@export var current_health: int = 100
@export var max_mana: int = 40
@export var current_mana: int = 40

@export_group("Inventory")
@export var coins: int = 0
@export var keys: int = 0
@export var health_potions: int = 3
@export var mana_potions: int = 2
@export var has_weapon: bool = false

# Düğüm Referansları
@onready var health_bar: ProgressBar = $TopLeft/HBoxContainer/BarsVBox/HealthContainer/HealthBar
@onready var health_label: Label = $TopLeft/HBoxContainer/BarsVBox/HealthContainer/HealthLabel
@onready var mana_bar: ProgressBar = $TopLeft/HBoxContainer/BarsVBox/ManaContainer/ManaBar
@onready var mana_label: Label = $TopLeft/HBoxContainer/BarsVBox/ManaContainer/ManaLabel

@onready var coin_label: Label = $TopRight/HBoxContainer/CoinPanel/HBox/CoinLabel
@onready var key_label: Label = $TopRight/HBoxContainer/KeyPanel/HBox/KeyLabel
@onready var pause_button: TextureButton = $TopRight/HBoxContainer/PauseButton

@onready var sword_slot: TextureRect = $BottomLeft/DiamondContainer/SlotBottom/Icon
@onready var sword_glow: Control = $BottomLeft/DiamondContainer/SlotBottom/ActiveGlow
@onready var potion_red_count: Label = $BottomLeft/DiamondContainer/SlotLeft/CountBadge
@onready var potion_blue_count: Label = $BottomLeft/DiamondContainer/SlotRight/CountBadge

@onready var tutorial_title: Label = $BottomRight/TutorialBox/HBox/VBox/TitleLabel
@onready var tutorial_key: Label = $BottomRight/TutorialBox/HBox/VBox/KeyContainer/KeyBadge/Label
@onready var tutorial_desc: Label = $BottomRight/TutorialBox/HBox/VBox/KeyContainer/DescLabel

var _health_tween: Tween
var _mana_tween: Tween

func _ready() -> void:
	if pause_button:
		pause_button.pressed.connect(_on_pause_button_pressed)
	update_all()

func update_all() -> void:
	update_health(current_health, max_health, false)
	update_mana(current_mana, max_mana, false)
	update_coins(coins)
	update_keys(keys)
	update_weapon_slot(has_weapon)
	update_potion_counts()

## Can Değerini Güncelle
func update_health(new_health: int, new_max: int = -1, animate: bool = true) -> void:
	if new_max > 0:
		max_health = new_max
	current_health = clampi(new_health, 0, max_health)

	if health_bar:
		health_bar.max_value = max_health
		if animate:
			if _health_tween and _health_tween.is_valid():
				_health_tween.kill()
			_health_tween = create_tween()
			_health_tween.tween_property(health_bar, "value", float(current_health), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			health_bar.value = current_health

	if health_label:
		health_label.text = "%d / %d" % [current_health, max_health]

## Mana Değerini Güncelle
func update_mana(new_mana: int, new_max: int = -1, animate: bool = true) -> void:
	if new_max > 0:
		max_mana = new_max
	current_mana = clampi(new_mana, 0, max_mana)

	if mana_bar:
		mana_bar.max_value = max_mana
		if animate:
			if _mana_tween and _mana_tween.is_valid():
				_mana_tween.kill()
			_mana_tween = create_tween()
			_mana_tween.tween_property(mana_bar, "value", float(current_mana), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			mana_bar.value = current_mana

	if mana_label:
		mana_label.text = "%d / %d" % [current_mana, max_mana]

## Altın Sayısını Güncelle
func update_coins(new_coins: int) -> void:
	coins = maxi(0, new_coins)
	if coin_label:
		coin_label.text = "x %d" % coins

## Anahtar Sayısını Güncelle
func update_keys(new_keys: int) -> void:
	keys = maxi(0, new_keys)
	if key_label:
		key_label.text = "x %d" % keys

## Kılıç / Silah Slotunu Güncelle
func update_weapon_slot(equipped: bool) -> void:
	has_weapon = equipped
	if sword_slot:
		sword_slot.modulate = Color(1, 1, 1, 1) if equipped else Color(0.4, 0.45, 0.55, 0.6)
	if sword_glow:
		sword_glow.visible = equipped

## İksir Miktarlarını Güncelle
func update_potion_counts() -> void:
	if potion_red_count:
		potion_red_count.text = str(health_potions)
	if potion_blue_count:
		potion_blue_count.text = str(mana_potions)

## İpucu / Görev Kutusunu Güncelle
func set_tutorial(title: String, key_badge: String, desc: String) -> void:
	if tutorial_title:
		tutorial_title.text = title
	if tutorial_key:
		tutorial_key.text = key_badge
	if tutorial_desc:
		tutorial_desc.text = desc

## Can İksiri Kullan
func use_health_potion() -> void:
	if health_potions > 0 and current_health < max_health:
		health_potions -= 1
		update_health(current_health + 35)
		update_potion_counts()
		potion_used.emit("health")

## Mana İksiri Kullan
func use_mana_potion() -> void:
	if mana_potions > 0 and current_mana < max_mana:
		mana_potions -= 1
		update_mana(current_mana + 20)
		update_potion_counts()
		potion_used.emit("mana")

func _unhandled_input(event: InputEvent) -> void:
	# [2] Tuşu ile Can İksiri
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_2:
			use_health_potion()
		elif event.keycode == KEY_3:
			use_mana_potion()

func _on_pause_button_pressed() -> void:
	var paused = get_tree().paused
	get_tree().paused = not paused
	pause_toggled.emit(not paused)
