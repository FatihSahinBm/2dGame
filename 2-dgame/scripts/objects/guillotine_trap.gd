class_name GuillotineTrap
extends Node2D

## res://scripts/objects/guillotine_trap.gd
## Târgovişte zindanlarında sarkaç gibi sallanan ya da dikey inen ölümcül giyotin bıçağı.

@export var swing_speed: float = 2.4
@export var max_angle_deg: float = 65.0
@export var damage: int = 25
@export var initial_phase: float = 0.0

var _time_passed: float = 0.0

@onready var arm: Node2D = $Arm
@onready var blade_area: Area2D = $Arm/Blade/HitArea


func _ready() -> void:
	_time_passed = initial_phase
	if blade_area:
		blade_area.body_entered.connect(_on_blade_hit)


func _physics_process(delta: float) -> void:
	_time_passed += delta * swing_speed
	var current_angle: float = deg_to_rad(sin(_time_passed) * max_angle_deg)
	if arm:
		arm.rotation = current_angle


func _on_blade_hit(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	elif body.has_method("hit"):
		body.hit(damage)
