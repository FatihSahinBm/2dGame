extends Node2D

## res://scripts/effects/ground_impact_dust.gd
## Vlad'ın zemin mızrak saplama (impale) saldırısında yerden kalkan toz,
## taş kırıntıları ve zemin şok dalgası etki alanı (AoE) görselleştiricisi.

@export var aoe_radius: float = 44.0
@export var duration: float = 0.65

@onready var dust_particles: CPUParticles2D = get_node_or_null("DustParticles") as CPUParticles2D
@onready var debris_particles: CPUParticles2D = get_node_or_null("DebrisParticles") as CPUParticles2D
@onready var crimson_sparks: CPUParticles2D = get_node_or_null("CrimsonSparks") as CPUParticles2D

var _shockwave_time: float = 0.0
var _shockwave_duration: float = 0.35
var _active_shockwave: bool = true

func _ready() -> void:
	if dust_particles:
		dust_particles.restart()
		dust_particles.emitting = true
	if debris_particles:
		debris_particles.restart()
		debris_particles.emitting = true
	if crimson_sparks:
		crimson_sparks.restart()
		crimson_sparks.emitting = true
	
	# Efekt tamamlandığında otomatik bellekten sil
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(queue_free)

func _process(delta: float) -> void:
	if _active_shockwave:
		_shockwave_time += delta
		queue_redraw()
		if _shockwave_time >= _shockwave_duration:
			_active_shockwave = false
			queue_redraw()

func _draw() -> void:
	if not _active_shockwave:
		return
	
	var progress: float = clampf(_shockwave_time / _shockwave_duration, 0.0, 1.0)
	var ease_progress: float = 1.0 - pow(1.0 - progress, 3.0) # Ease out cubic
	var current_radius: float = aoe_radius * ease_progress
	var alpha: float = (1.0 - progress) * 0.9
	
	# Zeminde yatay şok dalgası halkası ve toz çizgisi (AoE etki alanı sınırını gösterir)
	var line_color: Color = Color(0.92, 0.88, 0.82, alpha)
	var shadow_color: Color = Color(0.25, 0.22, 0.20, alpha * 0.75)
	var inner_crimson: Color = Color(0.85, 0.15, 0.15, alpha * 0.45)
	
	# 1. Koyu zemin tabanı (çatlak hissi)
	draw_line(Vector2(-current_radius, 1.0), Vector2(current_radius, 1.0), shadow_color, 2.5)
	# 2. Orta kırmızımsı voyvoda şok halkası
	draw_line(Vector2(-current_radius * 0.85, 0.0), Vector2(current_radius * 0.85, 0.0), inner_crimson, 3.0)
	# 3. Üst parlak toz çizgisi (zeminden kalkan toz hattı)
	draw_line(Vector2(-current_radius, -1.0), Vector2(current_radius, -1.0), line_color, 2.0)
	
	# Uç noktalarda toz patlama odak noktaları
	if progress < 0.6:
		var edge_alpha: float = (1.0 - progress / 0.6) * 0.95
		var edge_col: Color = Color(1.0, 0.95, 0.85, edge_alpha)
		var edge_r: float = 3.0 * (1.0 - progress)
		draw_circle(Vector2(-current_radius, -1.0), edge_r, edge_col)
		draw_circle(Vector2(current_radius, -1.0), edge_r, edge_col)
