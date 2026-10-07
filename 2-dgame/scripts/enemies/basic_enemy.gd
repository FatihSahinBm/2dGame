extends CharacterBody2D

## Sinyaller (Tam Ayrık Mimari Standartları)
signal health_changed(current_hp: int, max_hp: int)
signal enemy_died(enemy_instance: Node2D)
signal damaged(amount: int, current_hp: int)
signal died()

## Yapılandırma
@export_group("Stats")
@export var max_health: int = 100
@export var current_health: int = 100

@export_group("Movement & Patrol")
@export var speed: float = 75.0
@export var gravity: float = 1200.0
@export var direction: int = 1 # 1: Sağ, -1: Sol
@export var turn_at_ledges: bool = true
@export var turn_at_walls: bool = true
@export var turn_pause_duration: float = 0.35 # Dönüşlerde duraklama süresi

# Durum Değişkenleri
var is_dead: bool = false
var _turn_pause_timer: float = 0.0
var _hit_flash_tween: Tween
var _hp_bar_tween: Tween

# Düğüm Referansları
@onready var visual_node: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var ledge_ray: RayCast2D = $Visual/LedgeRay
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var damage_numbers_container: Node2D = $UI/DamageNumbers

func _ready() -> void:
	# İstenen gruplara kayıt ol
	if not is_in_group("damageable"):
		add_to_group("damageable")
	if not is_in_group("enemies"):
		add_to_group("enemies")

	current_health = max_health
	_init_health_bar()
	_update_facing_direction()

func _physics_process(delta: float) -> void:
	# 1. Yerçekimi uygulama
	if not is_on_floor():
		velocity.y += gravity * delta

	# 2. Ölüm durumunda hareket etme
	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		return

	# 3. Dönüş duraklaması
	if _turn_pause_timer > 0.0:
		_turn_pause_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		if anim_sprite and anim_sprite.animation != &"hit":
			anim_sprite.play(&"idle")
		move_and_slide()
		return

	# 4. Engel/Duvar Tespiti (is_on_wall)
	if turn_at_walls and is_on_wall():
		_turn_around()
		move_and_slide()
		return

	# 5. Uçurum/Platform Kenarı Tespiti (Ledge Detection)
	if turn_at_ledges and is_on_floor():
		# Raycast zemini görmüyorsa uçurum kenarındayız demektir
		if not ledge_ray.is_colliding():
			_turn_around()
			move_and_slide()
			return

	# 6. Devriye Hareketi (Godot 4: argümansız move_and_slide)
	velocity.x = float(direction) * speed
	move_and_slide()

	# 7. Animasyon Güncellemesi
	if is_on_floor() and anim_sprite and anim_sprite.animation != &"hit":
		if absf(velocity.x) > 5.0:
			if anim_sprite.animation != &"walk":
				anim_sprite.play(&"walk")
		else:
			if anim_sprite.animation != &"idle":
				anim_sprite.play(&"idle")

## Dışarıdan çağrılabilen hasar fonksiyonu
func take_damage(amount: int) -> void:
	if is_dead:
		return

	var actual_damage: int = maxi(1, amount)
	current_health = clampi(current_health - actual_damage, 0, max_health)

	# Sağlık çubuğunu güncelle
	_update_health_bar()

	# Hasar sayısı efekti
	_spawn_damage_number(actual_damage)

	# Hasar görsel geri bildirimi (Flash effect & animasyon)
	_play_hit_feedback()

	damaged.emit(actual_damage, current_health)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		_die()

func _turn_around() -> void:
	direction = -direction
	_turn_pause_timer = turn_pause_duration
	_update_facing_direction()

func _update_facing_direction() -> void:
	if not is_inside_tree():
		return

	# Sprite yönünü ayarla
	if anim_sprite:
		anim_sprite.flip_h = (direction < 0)

	# Uçurum kontrol raycast'ini hareket yönünün önüne yerleştir
	if ledge_ray:
		ledge_ray.position.x = 16.0 * float(direction)
		# Zemin tespitini yenile
		ledge_ray.force_raycast_update()

func _init_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = true

func _update_health_bar() -> void:
	if not health_bar:
		return

	if _hp_bar_tween and _hp_bar_tween.is_valid():
		_hp_bar_tween.kill()

	_hp_bar_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hp_bar_tween.tween_property(health_bar, "value", float(current_health), 0.25)

func _play_hit_feedback() -> void:
	# Beyaz/Kırmızı parıldama (Hit Flash)
	if anim_sprite:
		if _hit_flash_tween and _hit_flash_tween.is_valid():
			_hit_flash_tween.kill()

		anim_sprite.modulate = Color(2.5, 0.4, 0.4, 1.0)
		_hit_flash_tween = create_tween()
		_hit_flash_tween.tween_property(anim_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)

		# Kısa süreli hit animasyonu
		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(&"hit"):
			anim_sprite.play(&"hit")
			# 0.2 saniye sonra normale dön
			get_tree().create_timer(0.2).timeout.connect(func():
				if not is_dead and anim_sprite:
					anim_sprite.play(&"walk" if absf(velocity.x) > 5.0 else &"idle")
			)

func _spawn_damage_number(amount: int) -> void:
	if not damage_numbers_container:
		return

	var label: Label = Label.new()
	label.text = "-%d" % amount
	label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 14)
	label.position = Vector2(randf_range(-10.0, 10.0), -60.0)

	damage_numbers_container.add_child(label)

	# Uçuşarak kaybolma animasyonu (Juice)
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(label, "position:y", label.position.y - 28.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	t.chain().tween_callback(label.queue_free)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()
	enemy_died.emit(self)

	# Çarpışmayı devre dışı bırak
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	# Can barını gizle
	if health_bar:
		var bar_tween: Tween = create_tween()
		bar_tween.tween_property(health_bar, "modulate:a", 0.0, 0.2)

	# Ölüm animasyonu oynat
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(&"death"):
		anim_sprite.play(&"death")
		# Animasyon bitince veya 1 saniye sonra yok ol
		get_tree().create_timer(1.1).timeout.connect(_fade_and_free)
	else:
		_fade_and_free()

func _fade_and_free() -> void:
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	fade_tween.tween_callback(queue_free)
