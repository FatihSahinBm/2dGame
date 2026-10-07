extends CharacterBody2D

## Sinyaller (Tam Ayrık Mimari Standartları)
signal health_changed(current_hp: int, max_hp: int)
signal enemy_died(enemy_instance: Node2D)
signal damaged(amount: int, current_hp: int)
signal attack_hit(target: Node2D)

## Canavar Ayarları
@export_group("Monster Profile")
@export var monster_name: String = "Monster"
@export var max_health: int = 80
@export var current_health: int = 80
@export var is_flying: bool = false

@export_group("Combat & AI")
@export var attack_damage: int = 15
@export var attack_range: float = 44.0
@export var detection_range: float = 200.0
@export var attack_cooldown: float = 1.3
@export var knockback_resistance: float = 0.5 # 0.0: tam itilir, 1.0: itilmez

@export_group("Movement")
@export var speed: float = 75.0
@export var chase_speed: float = 110.0
@export var gravity: float = 1200.0
@export var direction: int = 1
@export var turn_at_ledges: bool = true
@export var turn_at_walls: bool = true

# Durum Değişkenleri
enum State { PATROL, CHASE, ATTACK, HURT, DEAD }
var current_state: State = State.PATROL
var is_dead: bool = false
var _attack_timer: float = 0.0
var _hurt_timer: float = 0.0
var _turn_pause_timer: float = 0.0
var _target_node: Node2D = null

# Tween Referansları
var _hit_flash_tween: Tween
var _hp_bar_tween: Tween

# Düğüm Referansları
@onready var visual_node: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var ledge_ray: RayCast2D = $Visual/LedgeRay
@onready var hitbox_area: Area2D = $Visual/Hitbox
@onready var hurtbox_area: Area2D = $Hurtbox
@onready var detection_area: Area2D = $DetectionArea
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var damage_numbers: Node2D = $UI/DamageNumbers

func _ready() -> void:
	# 1. Standart gruplara kayıt
	if not is_in_group("damageable"):
		add_to_group("damageable")
	if not is_in_group("enemies"):
		add_to_group("enemies")

	current_health = max_health

	if is_flying:
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	else:
		motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED

	# 2. Can barı ilklendirme
	_init_health_bar()
	_update_facing_direction()

	# 3. Alan sinyalleri
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

	if hurtbox_area:
		hurtbox_area.area_entered.connect(_on_hurtbox_area_entered)

	if hitbox_area:
		hitbox_area.monitoring = false
		hitbox_area.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	if is_dead:
		if not is_flying and not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		return

	# Saldırı bekleme süresi
	if _attack_timer > 0.0:
		_attack_timer -= delta

	# Yerçekimi (uçan canavarlar hariç)
	if not is_flying and not is_on_floor():
		velocity.y += gravity * delta

	# Durum makinesi yürütümü
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HURT:
			_process_hurt(delta)

	move_and_slide()

## --- AI Durum Fonksiyonları ---

func _process_patrol(delta: float) -> void:
	# Eğer hedef yakınsa kovalamaya geç
	if _can_see_target():
		current_state = State.CHASE
		return

	# Dönüş duraklaması
	if _turn_pause_timer > 0.0:
		_turn_pause_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		if anim_sprite and anim_sprite.animation != &"hit":
			anim_sprite.play(&"idle")
		return

	# Duvar kontrolü
	if turn_at_walls and is_on_wall():
		_turn_around()
		return

	# Platform uçurum kontrolü (uçmayanlar için)
	if not is_flying and turn_at_ledges and is_on_floor():
		if ledge_ray and not ledge_ray.is_colliding():
			_turn_around()
			return

	velocity.x = float(direction) * speed
	if anim_sprite and anim_sprite.animation != &"hit":
		anim_sprite.play(&"walk")

func _process_chase(delta: float) -> void:
	if not _target_node or not is_instance_valid(_target_node):
		_target_node = null
		current_state = State.PATROL
		return

	var to_target: Vector2 = _target_node.global_position - global_position
	var dist: float = to_target.length()

	# Hedef menzilden çıktıysa devriyeye dön
	if dist > detection_range * 1.3:
		_target_node = null
		current_state = State.PATROL
		return

	# Hedefe yönel
	var target_dir: int = 1 if to_target.x > 0 else -1
	if target_dir != direction:
		direction = target_dir
		_update_facing_direction()

	# Saldırı menzilinde miyiz?
	if dist <= attack_range:
		if _attack_timer <= 0.0:
			_start_attack()
		else:
			# Cooldown beklerken hafifçe yavaşla
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if anim_sprite:
				anim_sprite.play(&"idle")
		return

	# Platform canavarı uçurumdan düşmesin
	if not is_flying and turn_at_ledges and is_on_floor():
		if ledge_ray and not ledge_ray.is_colliding():
			velocity.x = 0.0
			if anim_sprite:
				anim_sprite.play(&"idle")
			return

	# Hedefe doğru ilerle
	velocity.x = float(direction) * chase_speed

	if is_flying:
		# Uçan yaratıklar Y ekseninde de süzülür
		velocity.y = move_toward(velocity.y, signf(to_target.y) * chase_speed * 0.7, 500.0 * delta)

	if anim_sprite and anim_sprite.animation != &"hit":
		anim_sprite.play(&"walk")

func _start_attack() -> void:
	current_state = State.ATTACK
	velocity.x = 0.0
	if is_flying:
		velocity.y = 0.0

	if anim_sprite:
		anim_sprite.play(&"attack")

	# Vuruş anı zamanlaması (animasyon ortasında hitbox açılır)
	var tween: Tween = create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_activate_hitbox()
	)
	tween.tween_interval(0.35)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_deactivate_hitbox()
			_attack_timer = attack_cooldown
			current_state = State.CHASE
	)

func _activate_hitbox() -> void:
	if hitbox_area and not is_dead:
		hitbox_area.monitoring = true

func _deactivate_hitbox() -> void:
	if hitbox_area:
		hitbox_area.monitoring = false

func _process_attack(delta: float) -> void:
	# Saldırı esnasında hareket durdurulur
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	if is_flying:
		velocity.y = move_toward(velocity.y, 0.0, 600.0 * delta)

func _process_hurt(delta: float) -> void:
	_hurt_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	if _hurt_timer <= 0.0:
		current_state = State.CHASE if _target_node else State.PATROL

## --- Hasar ve Savaş Fonksiyonları ---

## Standart hasar alma arayüzü
func take_damage(amount: int) -> void:
	if is_dead:
		return

	var actual_damage: int = maxi(1, amount)
	current_health = clampi(current_health - actual_damage, 0, max_health)

	_update_health_bar()
	_spawn_damage_number(actual_damage)
	_play_hit_feedback()

	# Sinyalleri yayınla
	damaged.emit(actual_damage, current_health)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		_die()
	else:
		# Sendeleme durumu
		current_state = State.HURT
		_hurt_timer = 0.22

## Oyuncu Kılıç Hitbox Algılama (Kılıçla karşılık verildiğinde)
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_dead:
		return

	# Oyuncunun kılıç vuruş alanı mı kontrol et
	if area.name == "AttackArea" or area.is_in_group("player_attack"):
		var damage_amount: int = 25
		var attacker_node = area.get_parent() # Visual
		if attacker_node and attacker_node.get_parent():
			var attacker = attacker_node.get_parent()
			# Ağır saldırı kontrolü
			if "current_attack_type" in attacker and attacker.current_attack_type == "heavy":
				damage_amount = 50

			# Geri itme (Recoil / Knockback)
			var push_dir: float = signf(global_position.x - attacker.global_position.x)
			if is_zero_approx(push_dir):
				push_dir = -float(direction)
			velocity.x = push_dir * (220.0 * (1.0 - knockback_resistance))
			if not is_flying:
				velocity.y = -140.0

		take_damage(damage_amount)

## Canavarın Oyuncuya Vurması (Bana saldırsınlar)
func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead or body == self:
		return

	# Tip kısıtı olmadan hasar arayüzü kontrolü (Decoupled architecture)
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)
		attack_hit.emit(body)

	# Geri itme ve görsel tepki
	var push_dir: Vector2 = (body.global_position - global_position).normalized()
	if push_dir.length_squared() < 0.01:
		push_dir = Vector2(float(direction), -0.5).normalized()

	if "velocity" in body:
		body.velocity += Vector2(push_dir.x * 280.0, -200.0)

	# Hedefe kısa kırmızı parıldama ver
	if "modulate" in body:
		var prev_mod: Color = body.modulate
		body.modulate = Color(2.0, 0.4, 0.4, 1.0)
		get_tree().create_timer(0.15).timeout.connect(func():
			if is_instance_valid(body):
				body.modulate = prev_mod
		)

	attack_hit.emit(body)

## --- Algılama & Yön Fonksiyonları ---

func _on_detection_body_entered(body: Node2D) -> void:
	if body == self:
		return
	# Sadece oyuncu grubundaki gövdeleri hedef al
	if body.is_in_group("player"):
		_target_node = body

func _on_detection_body_exited(body: Node2D) -> void:
	if body == _target_node:
		# Hedef ayrıldığında bir süre sonra takibi bırakır
		get_tree().create_timer(1.5).timeout.connect(func():
			if _target_node == body and not _can_see_target():
				_target_node = null
				if current_state != State.DEAD:
					current_state = State.PATROL
		)

func _can_see_target() -> bool:
	if _target_node and is_instance_valid(_target_node):
		var dist = global_position.distance_to(_target_node.global_position)
		return dist <= detection_range
	return false

func _turn_around() -> void:
	direction = -direction
	_turn_pause_timer = 0.3
	_update_facing_direction()

func _update_facing_direction() -> void:
	if not is_inside_tree():
		return

	if anim_sprite:
		# Monster_Creatures_Fantasy sprite'ları varsayılan olarak sağa bakar
		anim_sprite.flip_h = (direction < 0)

	if ledge_ray:
		ledge_ray.position.x = 18.0 * float(direction)
		ledge_ray.force_raycast_update()

	if hitbox_area:
		hitbox_area.position.x = 22.0 * float(direction)

## --- Görsel & Geri Bildirim Fonksiyonları ---

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
	if anim_sprite:
		if _hit_flash_tween and _hit_flash_tween.is_valid():
			_hit_flash_tween.kill()

		anim_sprite.modulate = Color(2.5, 0.4, 0.4, 1.0)
		_hit_flash_tween = create_tween()
		_hit_flash_tween.tween_property(anim_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)

		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(&"hit"):
			anim_sprite.play(&"hit")

func _spawn_damage_number(amount: int) -> void:
	if not damage_numbers:
		return

	var label: Label = Label.new()
	label.text = "-%d" % amount
	label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 14)
	label.position = Vector2(randf_range(-10.0, 10.0), -64.0)

	damage_numbers.add_child(label)

	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(label, "position:y", label.position.y - 28.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	t.chain().tween_callback(label.queue_free)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	current_state = State.DEAD
	_deactivate_hitbox()

	enemy_died.emit(self)

	# Çarpışmayı devre dışı bırak
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)

	if hurtbox_area:
		hurtbox_area.monitoring = false
		hurtbox_area.monitorable = false

	if health_bar:
		var bar_tween: Tween = create_tween()
		bar_tween.tween_property(health_bar, "modulate:a", 0.0, 0.2)

	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(&"death"):
		anim_sprite.play(&"death")
		get_tree().create_timer(1.1).timeout.connect(_fade_and_free)
	else:
		_fade_and_free()

func _fade_and_free() -> void:
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	fade_tween.tween_callback(queue_free)
