class_name DimensionalTimeRift
extends Node2D

## res://scripts/objects/dimensional_time_rift.gd
## Zaman & Boyut Yırtığı (Dimensional Time Rift).
## Oyuncunun geçmişe (1462 Târgovişte Ormanı'na) düştüğü kararsız uzay-zaman yarığı.

signal rift_opened()
signal spawn_completed()

@onready var sprite: Sprite2D = $Sprite2D
@onready var particles: CPUParticles2D = $Particles
@onready var burst_particles: CPUParticles2D = $BurstParticles

var _base_scale: Vector2 = Vector2(0.5, 0.5)
var _pulse_timer: float = 0.0


func _ready() -> void:
	z_index = -5 # Karakterin hemen arkasında durur
	if sprite:
		_base_scale = sprite.scale


func _process(delta: float) -> void:
	_pulse_timer += delta * 2.5
	if sprite:
		# Doğal uzay-zaman nefes alma ve hafif titreme efekti
		var scale_offset = sin(_pulse_timer) * 0.025
		sprite.scale = Vector2(_base_scale.x + scale_offset, _base_scale.y - scale_offset)
		var glow_val = 1.0 + (sin(_pulse_timer * 1.5) * 0.2)
		sprite.modulate = Color(glow_val * 1.15, glow_val * 0.9, glow_val * 0.9, 1.0)


## Bölüm başlangıcında oyuncunun yırtıktan fırlayarak çıkış sekansı
func play_player_emerge_sequence(player: CharacterBody2D) -> void:
	if not player:
		return

	# 1. Başlangıçta oyuncu yırtığın içinde saklıdır
	player.visible = false
	if "can_move" in player:
		player.can_move = false
	player.global_position = global_position + Vector2(0.0, 20.0)

	# 2. Yırtık şiddetle titrer ve yoğunlaşır (0.6s)
	if sprite:
		var tw_shake: Tween = create_tween()
		tw_shake.tween_property(sprite, "scale", Vector2(0.12, 0.65), 0.3).set_trans(Tween.TRANS_QUAD)
		tw_shake.tween_property(sprite, "scale", Vector2(0.68, 0.68), 0.15).set_trans(Tween.TRANS_BACK)

	await get_tree().create_timer(0.45).timeout

	# 3. Yırtık patlaması: Kıvılcımlar ve enerji püskürmesi
	if burst_particles:
		burst_particles.restart()
		burst_particles.emitting = true
	rift_opened.emit()

	# 4. Oyuncu yırtıktan ileri ve aşağıya doğru fırlar
	player.visible = true
	player.modulate = Color(2.5, 1.2, 0.6, 0.0)
	var target_land_pos: Vector2 = Vector2(global_position.x + 90.0, 560.0)

	var tw_player: Tween = create_tween()
	tw_player.parallel().tween_property(player, "modulate", Color.WHITE, 0.35)
	# Yay şeklinde iniş (parabolic arc)
	tw_player.parallel().tween_property(player, "global_position:x", target_land_pos.x, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_player.parallel().tween_property(player, "global_position:y", target_land_pos.y, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 5. Yere çarpma anında kılıç sürtünmesi ve toz kıvılcımı
	tw_player.tween_callback(func():
		if "velocity" in player:
			player.velocity = Vector2(60.0, 0.0)
		_spawn_ground_impact_fx(target_land_pos)
		spawn_completed.emit()
	)

	# 6. Oyuncunun ayağa kalkıp savaşa hazır olması (0.2s sonra kontroller açılır)
	await get_tree().create_timer(0.65).timeout
	if "can_move" in player:
		player.can_move = true


func _spawn_ground_impact_fx(pos: Vector2) -> void:
	var vfx: CPUParticles2D = CPUParticles2D.new()
	vfx.emitting = true
	vfx.one_shot = true
	vfx.explosiveness = 0.95
	vfx.amount = 18
	vfx.lifetime = 0.5
	vfx.direction = Vector2(-0.8, -0.4)
	vfx.spread = 35.0
	vfx.initial_velocity_min = 90.0
	vfx.initial_velocity_max = 160.0
	vfx.gravity = Vector2(0, 400)
	vfx.color = Color(1.0, 0.6, 0.2, 1.0) # Madeni kıvılcım
	vfx.global_position = pos + Vector2(0, -5.0)
	get_parent().add_child(vfx)
	vfx.finished.connect(vfx.queue_free)
