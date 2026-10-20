class_name FallingRockHazard
extends Node2D

## res://scripts/levels/stoneage/falling_rock_hazard.gd
## Kırık Geçit Çevresel Tehlikesi: Düşen Kaya (Falling Rock Hazard)
## - Oyuncu tetikleme bölgesine girdiğinde tavanda küçük toz ve çakıl uyarısı başlar (0.4s)
## - Ardından ağır kaya yerçekimiyle aşağı düşer
## - Zemine çarptığında çarpma tozu çıkarır ve güvenli biçimde sıfırlanır

signal rock_triggered()
signal rock_impacted(impact_pos: Vector2)

@export var fall_speed: float = 0.0
@export var gravity: float = 1100.0
@export var warning_time: float = 0.4
@export var ground_y: float = 580.0
@export var reset_delay: float = 4.0

@onready var trigger_zone: Area2D = $TriggerArea
@onready var rock_sprite: Sprite2D = $RockSprite
@onready var warning_particles: CPUParticles2D = $WarningDust
@onready var impact_particles: CPUParticles2D = $ImpactDust

var _is_falling: bool = false
var _is_triggered: bool = false
var _initial_rock_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	if rock_sprite:
		_initial_rock_pos = rock_sprite.position
	if trigger_zone and not trigger_zone.body_entered.is_connected(_on_trigger_body_entered):
		trigger_zone.body_entered.connect(_on_trigger_body_entered)


func _on_trigger_body_entered(body: Node2D) -> void:
	if _is_triggered:
		return
	if body is CharacterBody2D or body.name == "CombatPlayer":
		trigger_hazard()


func trigger_hazard() -> void:
	if _is_triggered:
		return
	_is_triggered = true
	rock_triggered.emit()

	# 1. Görsel uyarı: Tavandan dökülen toz ve küçük taş parçacıkları
	if warning_particles:
		warning_particles.emitting = true

	# 2. 0.4 saniye sonra kaya yerçekimiyle düşmeye başlar
	if is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_interval(warning_time)
		tw.tween_callback(_start_falling)


func _start_falling() -> void:
	_is_falling = true
	fall_speed = 60.0


func _physics_process(delta: float) -> void:
	if not _is_falling or not rock_sprite:
		return

	fall_speed += gravity * delta
	rock_sprite.position.y += fall_speed * delta

	# Zemin seviyesine çarpma kontrolü
	if rock_sprite.global_position.y >= ground_y:
		_on_rock_impact()


func _on_rock_impact() -> void:
	_is_falling = false
	rock_impacted.emit(rock_sprite.global_position)

	if impact_particles:
		impact_particles.global_position = rock_sprite.global_position
		impact_particles.emitting = true

	# Kayayı gizle ve reset zamanlayıcısını başlat
	rock_sprite.visible = false

	if is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_interval(reset_delay)
		tw.tween_callback(_reset_hazard)


func _reset_hazard() -> void:
	if rock_sprite:
		rock_sprite.position = _initial_rock_pos
		rock_sprite.visible = true
	fall_speed = 0.0
	_is_falling = false
	_is_triggered = false
