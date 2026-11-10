class_name CyberLaserSystem
extends Node2D

## res://scripts/enemies/cyber_laser_system.gd
## T-Rex Siber Lazer Silah Sistemi (Cyber Laser Weapon System).
## - İki aşamalı saldırı döngüsü:
##   1. Telegraph (Uyarı): Kırmızı nişan ışını ve şarj parçacıkları (0.85s).
##      Oyuncuya kaçınma (platforma zıplama veya siper arkasına geçme) fırsatı sunar.
##   2. Lazer Işını: Yüksek enerjili delici enerji patlaması (0.8s).
##      RayCast2D ile siper kayalarını ve engelleri algılar; engelin arkasına geçmez (tutarlı engel kuralı).
##   3. Toparlanma: 1.2s soğuma buharı ve savunmasızlık penceresi.

signal telegraph_started(direction: int, target_range: float)
signal laser_fired(direction: int, actual_range: float)
signal laser_completed()
signal player_damaged(damage: int)

@export var max_range: float = 520.0
@export var base_damage: int = 48
@export var telegraph_duration: float = 0.85
@export var blast_duration: float = 0.8
@export var recovery_duration: float = 1.2

var is_active: bool = false
var is_telegraphing: bool = false
var current_direction: int = 1
var current_actual_range: float = 520.0

@onready var obstacle_ray: RayCast2D = $ObstacleRay
@onready var laser_area: Area2D = $LaserHitbox
@onready var laser_shape_node: CollisionShape2D = $LaserHitbox/CollisionShape2D
@onready var telegraph_line: Line2D = $TelegraphLine
@onready var laser_beam: Line2D = $LaserBeam
@onready var laser_core: Line2D = $LaserCore
@onready var laser_light: PointLight2D = $LaserLight
@onready var charge_particles: CPUParticles2D = $ChargeParticles
@onready var impact_particles: CPUParticles2D = $ImpactParticles
@onready var exhaust_steam: CPUParticles2D = $ExhaustSteam

var _telegraph_tween: Tween = null


func _ready() -> void:
	_ensure_nodes()
	_reset_all()
	if laser_area and not laser_area.body_entered.is_connected(_on_laser_body_entered):
		laser_area.body_entered.connect(_on_laser_body_entered)


func _ensure_nodes() -> void:
	if not obstacle_ray:
		obstacle_ray = get_node_or_null("ObstacleRay") as RayCast2D
	if not laser_area:
		laser_area = get_node_or_null("LaserHitbox") as Area2D
	if not laser_shape_node and laser_area:
		laser_shape_node = laser_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not telegraph_line:
		telegraph_line = get_node_or_null("TelegraphLine") as Line2D
	if not laser_beam:
		laser_beam = get_node_or_null("LaserBeam") as Line2D
	if not laser_core:
		laser_core = get_node_or_null("LaserCore") as Line2D
	if not laser_light:
		laser_light = get_node_or_null("LaserLight") as PointLight2D
	if not charge_particles:
		charge_particles = get_node_or_null("ChargeParticles") as CPUParticles2D
	if not impact_particles:
		impact_particles = get_node_or_null("ImpactParticles") as CPUParticles2D
	if not exhaust_steam:
		exhaust_steam = get_node_or_null("ExhaustSteam") as CPUParticles2D


func _reset_all() -> void:
	_ensure_nodes()
	is_active = false
	is_telegraphing = false
	if telegraph_line:
		telegraph_line.visible = false
	if laser_beam:
		laser_beam.visible = false
	if laser_core:
		laser_core.visible = false
	if laser_area:
		laser_area.monitoring = false
	if laser_light:
		laser_light.enabled = false
	if charge_particles:
		charge_particles.emitting = false
	if impact_particles:
		impact_particles.emitting = false
	if exhaust_steam:
		exhaust_steam.emitting = false


## 1. Aşama: Telegraph Uyarısı Başlat
func start_telegraph(dir: int) -> void:
	_ensure_nodes()
	_reset_all()
	is_telegraphing = true
	current_direction = dir

	# Engellere göre hedef menzili kontrol et
	_calculate_range(dir)

	if telegraph_line:
		var end_pt: Vector2 = Vector2(current_actual_range * float(dir), 0.0)
		telegraph_line.points = PackedVector2Array([Vector2.ZERO, end_pt])
		telegraph_line.visible = true
		telegraph_line.width = 2.0

		if _telegraph_tween and _telegraph_tween.is_valid():
			_telegraph_tween.kill()
		_telegraph_tween = create_tween().set_loops(4)
		_telegraph_tween.tween_property(telegraph_line, "width", 5.5, 0.1)
		_telegraph_tween.tween_property(telegraph_line, "width", 1.5, 0.1)

	if charge_particles:
		charge_particles.restart()
		charge_particles.emitting = true

	if laser_light:
		laser_light.enabled = true
		laser_light.energy = 0.5
		var tw_l = create_tween()
		tw_l.tween_property(laser_light, "energy", 1.8, telegraph_duration)

	telegraph_started.emit(dir, current_actual_range)


## 2. Aşama: Lazer Işınını Ateşle
func fire_laser(dir: int, damage_override: int = -1) -> void:
	_ensure_nodes()
	is_telegraphing = false
	is_active = true
	current_direction = dir
	if damage_override > 0:
		base_damage = damage_override

	if _telegraph_tween and _telegraph_tween.is_valid():
		_telegraph_tween.kill()
	if telegraph_line:
		telegraph_line.visible = false
	if charge_particles:
		charge_particles.emitting = false

	# Atış anında engel mesafesini yeniden doğrula
	_calculate_range(dir)

	var end_pt: Vector2 = Vector2(current_actual_range * float(dir), 0.0)

	if laser_beam and laser_core:
		laser_beam.points = PackedVector2Array([Vector2.ZERO, end_pt])
		laser_core.points = PackedVector2Array([Vector2.ZERO, end_pt])
		laser_beam.visible = true
		laser_core.visible = true

	# Hitbox'ı gerçek menzile göre boyutlandır
	if laser_area and laser_shape_node and laser_shape_node.shape is RectangleShape2D:
		var rect: RectangleShape2D = laser_shape_node.shape as RectangleShape2D
		rect.size = Vector2(current_actual_range, 68.0)
		laser_shape_node.position = Vector2((current_actual_range * 0.5) * float(dir), 0.0)
		laser_area.monitoring = true
		# Bölgede halihazırda bulunan gövdeleri anında denetle
		for body in laser_area.get_overlapping_bodies():
			_on_laser_body_entered(body)

	if laser_light:
		laser_light.enabled = true
		laser_light.energy = 3.2

	# Engel çarpışma noktası varsa parçacık çıkar
	if obstacle_ray and obstacle_ray.is_colliding() and impact_particles:
		impact_particles.global_position = obstacle_ray.get_collision_point()
		impact_particles.restart()
		impact_particles.emitting = true

	laser_fired.emit(dir, current_actual_range)

	# blast_duration sonra lazeri kes ve toparlanma aşamasına geç
	var tw: Tween = create_tween()
	tw.tween_interval(blast_duration)
	tw.tween_callback(_on_blast_finished)


func _on_blast_finished() -> void:
	stop_laser()
	play_recovery_steam()
	laser_completed.emit()


## Lazer akışını keser
func stop_laser() -> void:
	is_active = false
	is_telegraphing = false
	if laser_beam:
		laser_beam.visible = false
	if laser_core:
		laser_core.visible = false
	if laser_area:
		laser_area.monitoring = false
	if laser_light:
		laser_light.enabled = false
	if impact_particles:
		impact_particles.emitting = false


## 3. Aşama: Saldırı Sonrası Toparlanma Buharı (Savunmasızlık Penceresi)
func play_recovery_steam() -> void:
	if exhaust_steam:
		exhaust_steam.restart()
		exhaust_steam.emitting = true
		var tw: Tween = create_tween()
		tw.tween_interval(recovery_duration)
		tw.tween_callback(func():
			if exhaust_steam:
				exhaust_steam.emitting = false
		)


func _calculate_range(dir: int) -> void:
	current_actual_range = max_range
	if obstacle_ray and obstacle_ray.is_inside_tree():
		obstacle_ray.target_position = Vector2(max_range * float(dir), 0.0)
		obstacle_ray.force_raycast_update()
		if obstacle_ray.is_colliding():
			var hit_pt: Vector2 = obstacle_ray.get_collision_point()
			var dist: float = obstacle_ray.global_position.distance_to(hit_pt)
			current_actual_range = clampf(dist, 40.0, max_range)
			return

	if is_inside_tree() and get_world_2d():
		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		if space_state:
			var ray_params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
				global_position,
				global_position + Vector2(max_range * float(dir), 0.0),
				1
			)
			var hit: Dictionary = space_state.intersect_ray(ray_params)
			if not hit.is_empty():
				var dist: float = global_position.distance_to(hit.position)
				current_actual_range = clampf(dist, 40.0, max_range)


func _on_laser_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		var knock_dir: Vector2 = Vector2(float(current_direction), -0.35).normalized()
		body.take_damage(base_damage, knock_dir * 320.0)
		player_damaged.emit(base_damage)
