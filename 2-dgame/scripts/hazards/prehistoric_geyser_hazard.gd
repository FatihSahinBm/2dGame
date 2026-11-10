class_name PrehistoricGeyserHazard
extends Node2D

## res://scripts/hazards/prehistoric_geyser_hazard.gd
## Tarih Öncesi Kanyon Gayzeri (Prehistoric Geyser Hazard).
## - Çevresel tehlike oyuncu tarafından açıkça ve önceden ayırt edilebilir:
##   1. Bekleme: Fissürde hafif turuncu parıltı ve küçük kabarcıklar.
##   2. Telegraf: Yoğunlaşan buhar fısıltısı, titreşen zemin ve uyarı ışığı (1.0 saniye).
##   3. Püskürme: Yüksek basınçlı kaynar buhar ve lav sütunu, oyuncuya hasar ve itiş verir.

signal geyser_erupted()
signal player_burned()

@export var damage: int = 18
@export var dormant_time: float = 3.0
@export var telegraph_time: float = 1.0
@export var eruption_time: float = 0.8
@export var knockback_force: float = 240.0

enum State { DORMANT, TELEGRAPH, ERUPTING }
var current_state: State = State.DORMANT

var _timer: float = 0.0

@onready var damage_area: Area2D = $DamageArea
@onready var telegraph_particles: CPUParticles2D = $TelegraphSteam
@onready var eruption_particles: CPUParticles2D = $EruptionSteam
@onready var fissure_light: PointLight2D = get_node_or_null("FissureLight") as PointLight2D
@onready var fissure_sprite: Sprite2D = $FissureSprite
@onready var warning_sprite: Sprite2D = get_node_or_null("WarningGlow") as Sprite2D


func _ready() -> void:
	if damage_area:
		damage_area.monitoring = false
		damage_area.body_entered.connect(_on_damage_area_body_entered)
	if telegraph_particles:
		telegraph_particles.emitting = false
	if eruption_particles:
		eruption_particles.emitting = false
	if fissure_light:
		fissure_light.energy = 0.4
	if warning_sprite:
		warning_sprite.visible = false

	_timer = dormant_time


func _process(delta: float) -> void:
	_timer -= delta
	match current_state:
		State.DORMANT:
			if _timer <= 0.0:
				_start_telegraph()
		State.TELEGRAPH:
			if _timer <= 0.0:
				_start_eruption()
		State.ERUPTING:
			if _timer <= 0.0:
				_start_dormant()


func _start_telegraph() -> void:
	current_state = State.TELEGRAPH
	_timer = telegraph_time

	if telegraph_particles:
		telegraph_particles.restart()
		telegraph_particles.emitting = true
	if warning_sprite:
		warning_sprite.visible = true

	if fissure_light:
		var tw: Tween = create_tween().set_loops(3)
		tw.tween_property(fissure_light, "energy", 1.8, 0.16)
		tw.tween_property(fissure_light, "energy", 0.6, 0.16)


func _start_eruption() -> void:
	current_state = State.ERUPTING
	_timer = eruption_time

	if telegraph_particles:
		telegraph_particles.emitting = false
	if warning_sprite:
		warning_sprite.visible = false
	if eruption_particles:
		eruption_particles.restart()
		eruption_particles.emitting = true
	if damage_area:
		damage_area.monitoring = true

	if fissure_light:
		fissure_light.energy = 2.4

	geyser_erupted.emit()


func _start_dormant() -> void:
	current_state = State.DORMANT
	_timer = dormant_time

	if damage_area:
		damage_area.monitoring = false
	if eruption_particles:
		eruption_particles.emitting = false
	if fissure_light:
		fissure_light.energy = 0.4


func _on_damage_area_body_entered(body: Node2D) -> void:
	if current_state == State.ERUPTING and body.is_in_group("player"):
		if body.has_method("take_damage"):
			var knock_dir: Vector2 = Vector2(0.2, -1.0).normalized()
			body.take_damage(damage, knock_dir * knockback_force)
			player_burned.emit()

