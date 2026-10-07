extends CharacterBody2D

## res://scripts/combat/combat_test_player.gd
## Oyuncu kontrolcüsü. Kılıç çekili (armed) iken kılıç, orijinal animasyonların üzerine
## çalışma zamanında SwordOverlay (Sprite2D) ile kare kare el noktasına yerleştirilir.

signal weapon_state_changed(has_weapon: bool, is_armed: bool)
signal player_damaged(current_hp: int, max_hp: int)
signal player_died()

@export_group("Stats & Movement")
@export var max_health: int = 100
@export var current_health: int = 100
@export var speed: float = 260.0
@export var crouch_speed: float = 120.0
@export var dash_speed: float = 520.0
@export var slide_speed: float = 380.0
@export var roll_speed: float = 340.0
@export var jump_velocity: float = -600.0
@export var wall_jump_velocity: Vector2 = Vector2(280.0, -560.0)
@export var gravity: float = 1200.0

# Silah Durumu
var has_sword: bool = false
var is_armed: bool = false
var facing_dir: float = 1.0

# Durum Bayrakları
var is_dead: bool = false
var is_hurt: bool = false
var is_attacking: bool = false
var is_crouching: bool = false
var is_dashing: bool = false
var is_sliding: bool = false
var is_rolling: bool = false
var is_wall_sliding: bool = false

# Sayaçlar
var can_dash: bool = true
var combo_step: int = 0
var combo_timer: float = 0.0

const SWORD_ITEM_SCENE = preload("res://scenes/combat/sword_item.tscn")

# Çarpışma Boyutları
const NORMAL_COL_SIZE: Vector2 = Vector2(18.0, 38.0)
const NORMAL_COL_POS: Vector2 = Vector2(0.0, -19.0)
const LOW_COL_SIZE: Vector2 = Vector2(18.0, 22.0)
const LOW_COL_POS: Vector2 = Vector2(0.0, -11.0)

@onready var visual_node: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var attack_area: Area2D = $Visual/AttackArea
@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var sword_overlay: Sprite2D = $Visual/AnimatedSprite2D/SwordOverlay

func _ready() -> void:
	if anim_sprite:
		anim_sprite.animation_finished.connect(_on_animation_finished)
	if attack_area:
		attack_area.monitoring = false
	if col_shape and col_shape.shape:
		col_shape.shape = col_shape.shape.duplicate()
	# Silah durumu her değiştiğinde (al, at, [1], saldırıda otomatik çekme) overlay'i senkronla
	weapon_state_changed.connect(_on_weapon_state_changed)
	weapon_state_changed.emit(has_sword, is_armed)

func _on_weapon_state_changed(weapon: bool, armed: bool) -> void:
	if sword_overlay and sword_overlay.has_method("set_drawn"):
		sword_overlay.set_drawn(weapon and armed)

func _physics_process(delta: float) -> void:
	# Kombo zamanlayıcısını güncelle
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_step = 0

	# 1. Ölüm Durumu
	if is_dead:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		move_and_slide()
		return

	# 2. Hasar / Darbe Sersemlemesi
	if is_hurt:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		move_and_slide()
		return

	# 3. Dash (Hızlı Atılma - Shift)
	if is_dashing:
		velocity.x = facing_dir * dash_speed
		velocity.y = 0.0
		move_and_slide()
		return

	# 4. Slide (Zemin Kayması)
	if is_sliding:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 750.0 * delta)
		move_and_slide()
		if absf(velocity.x) < 40.0:
			_stop_slide()
		return

	# 5. Roll (Takla Atma - Alt)
	if is_rolling:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		move_and_slide()
		return

	# 6. Normal Yerçekimi
	if not is_on_floor():
		velocity.y += gravity * delta

	# 7. Duvar Kayması (Wall Slide) ve Duvar Zıplaması
	_check_wall_slide(delta)

	# 8. Zemin ve Tuş Girdileri
	_handle_movement_and_skills(delta)

	move_and_slide()
	_update_animation()

## Duvar Kayması ve Zıplaması Kontrolü
func _check_wall_slide(_delta: float) -> void:
	if is_dead or is_attacking or is_rolling or is_dashing:
		is_wall_sliding = false
		return

	if not is_on_floor() and is_on_wall() and velocity.y > 0.0:
		var wall_normal = get_wall_normal()
		if (wall_normal.x < 0.0 and facing_dir > 0.0) or (wall_normal.x > 0.0 and facing_dir < 0.0):
			is_wall_sliding = true
			velocity.y = minf(velocity.y, 90.0) # Yavaş süzülme

			# Orijinal sprite'ta duvara temas sol taraftadır (scale.x = 1.0 -> sol duvar, scale.x = -1.0 -> sağ duvar)
			if visual_node:
				visual_node.scale.x = 1.0 if wall_normal.x > 0.0 else -1.0

			# Duvardan zıplama (Wall Jump)
			if Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W):
				facing_dir = 1.0 if wall_normal.x > 0.0 else -1.0
				if visual_node:
					visual_node.scale.x = facing_dir
				velocity.x = facing_dir * wall_jump_velocity.x
				velocity.y = wall_jump_velocity.y
				is_wall_sliding = false
				return
			return

	if is_wall_sliding:
		is_wall_sliding = false
		if visual_node:
			visual_node.scale.x = facing_dir

## Hareket ve Beceri Kontrolleri
func _handle_movement_and_skills(delta: float) -> void:
	# Yatay Tuş Girdileri
	var move_x: float = 0.0
	if not is_attacking:
		if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move_x -= 1.0
		if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move_x += 1.0

	# Yüz Yönü
	if move_x != 0.0 and not is_attacking and not is_wall_sliding:
		facing_dir = 1.0 if move_x > 0.0 else -1.0
		if visual_node:
			visual_node.scale.x = facing_dir

	# 1. Dash (Shift tuşu)
	var wants_dash = Input.is_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_action_just_pressed("dash")
	if wants_dash and can_dash and not is_attacking and not is_crouching:
		perform_dash()
		return

	# 2. Dodge Roll (Alt veya C tuşu)
	var wants_roll = (Input.is_key_pressed(KEY_ALT) or Input.is_physical_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_C)) and is_on_floor()
	if wants_roll and not is_attacking and not is_rolling and not is_sliding:
		perform_roll()
		return

	# 3. Slide (Hızlı koşarken Ctrl'e basılırsa)
	var wants_crouch_key = Input.is_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_CTRL) or Input.is_action_pressed("crouch")
	if wants_crouch_key and is_on_floor() and absf(velocity.x) > 170.0 and not is_sliding and not is_attacking:
		perform_slide()
		return

	# 4. Eğilme (Ctrl tuşu)
	var wants_crouch = wants_crouch_key and is_on_floor() and not is_attacking and not is_sliding
	if wants_crouch != is_crouching:
		is_crouching = wants_crouch
		_set_collision_box(LOW_COL_SIZE if is_crouching else NORMAL_COL_SIZE, LOW_COL_POS if is_crouching else NORMAL_COL_POS)

	# 5. Zıplama (Eğilirken zıplanmaz)
	if is_on_floor() and not is_attacking and not is_crouching and not is_sliding:
		if Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W):
			velocity.y = jump_velocity

	# 6. Yatay Hız
	if not is_attacking:
		var current_speed: float = crouch_speed if is_crouching else speed
		if move_x != 0.0:
			velocity.x = move_x * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)

## Dash (Shift)
func perform_dash() -> void:
	is_dashing = true
	can_dash = false
	if anim_sprite and anim_sprite.sprite_frames.has_animation("dash"):
		anim_sprite.play("dash")
	
	get_tree().create_timer(0.18).timeout.connect(func():
		is_dashing = false
	)
	get_tree().create_timer(0.55).timeout.connect(func():
		can_dash = true
	)

## Slide (Koşarken Ctrl)
func perform_slide() -> void:
	is_sliding = true
	_set_collision_box(LOW_COL_SIZE, LOW_COL_POS)
	velocity.x = facing_dir * slide_speed
	if anim_sprite and anim_sprite.sprite_frames.has_animation("slide"):
		anim_sprite.play("slide")

func _stop_slide() -> void:
	if not is_sliding:
		return
	is_sliding = false
	var wants_crouch_key = Input.is_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_CTRL)
	if wants_crouch_key:
		is_crouching = true
		_set_collision_box(LOW_COL_SIZE, LOW_COL_POS)
	else:
		is_crouching = false
		_set_collision_box(NORMAL_COL_SIZE, NORMAL_COL_POS)

## Dodge Roll (Alt veya C)
func perform_roll() -> void:
	is_rolling = true
	_set_collision_box(LOW_COL_SIZE, LOW_COL_POS)
	velocity.x = facing_dir * roll_speed
	if anim_sprite and anim_sprite.sprite_frames.has_animation("roll"):
		anim_sprite.play("roll")

## Girdi Olayları (Kılıç Çekme/Kına Sokma, Saldırı, Fırlatma)
func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return

	# [1] Tuşu: Kılıç Çekme / Kınına Sokma (Draw / Sheathe Toggle)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			toggle_weapon_draw()
			return

	# Kılıcı Atma / Fırlatma (G Tuşu)
	var is_g_pressed = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		is_g_pressed = true
	elif event.is_action_pressed("drop_item"):
		is_g_pressed = true

	if is_g_pressed:
		drop_sword()
		return

	# Saldırı Girdileri (Kılıç varsa çalışır)
	if has_sword and not is_attacking and not is_rolling and not is_dashing and not is_sliding:
		# 1. Sol Tık / J: Hafif Saldırı veya Eğilerek Saldırı
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J) \
				or event.is_action_pressed("attack_light"):
			# Kılıç kındaysa otomatik olarak çekip vur
			if not is_armed:
				is_armed = true
				weapon_state_changed.emit(has_sword, is_armed)

			if is_crouching:
				perform_crouch_attack()
			else:
				if combo_step == 1 and combo_timer > 0.0:
					perform_combo_attack()
				else:
					perform_light_attack()
			return

		# 2. Sağ Tık / K: Güçlü Saldırı
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) \
				or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K) \
				or event.is_action_pressed("attack_heavy"):
			if not is_armed:
				is_armed = true
				weapon_state_changed.emit(has_sword, is_armed)
			perform_heavy_attack()
			return

## [1] Tuşu ile Kılıç Çekme / Kınına Sokma: yalnızca armed durumunu çevirir (overlay aç/kapa)
func toggle_weapon_draw() -> void:
	if not has_sword or is_dead or is_attacking or is_rolling or is_dashing:
		return

	is_armed = not is_armed
	weapon_state_changed.emit(has_sword, is_armed)

## Hafif Saldırı (Vuruş 1)
func perform_light_attack() -> void:
	is_attacking = true
	velocity.x = facing_dir * 110.0
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")
	_apply_attack_damage(25)
	# Kombo penceresini aç
	combo_step = 1
	combo_timer = 0.5
	_start_safety_timer(0.38)

## 2'li Akıcı Kombo Saldırısı (Vuruş 2)
func perform_combo_attack() -> void:
	is_attacking = true
	combo_step = 0
	combo_timer = 0.0
	velocity.x = facing_dir * 180.0
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("attack_combo"):
		anim_sprite.play("attack_combo")
	_apply_attack_damage(40)
	_start_safety_timer(0.65)

## Eğilerek Saldırı (Crouch Attack)
func perform_crouch_attack() -> void:
	is_attacking = true
	velocity.x = facing_dir * 60.0
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("crouch_attack"):
		anim_sprite.play("crouch_attack")
	_apply_attack_damage(30)
	_start_safety_timer(0.35)

## Ağır Saldırı (Sağ Tık)
func perform_heavy_attack() -> void:
	is_attacking = true
	combo_step = 0
	combo_timer = 0.0
	velocity.x = facing_dir * 220.0
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("heavy_attack"):
		anim_sprite.play("heavy_attack")
	_apply_attack_damage(55)
	_start_safety_timer(0.65)

## Hasar Uygulama (Hitbox)
func _apply_attack_damage(damage: int) -> void:
	if not attack_area:
		return
	attack_area.monitoring = true
	var deal_damage = func():
		for body in attack_area.get_overlapping_bodies():
			if body == self:
				continue
			if body.has_method("take_damage"):
				body.take_damage(damage)
			elif body.has_method("hit"):
				body.hit(damage)
	deal_damage.call()
	get_tree().create_timer(0.12).timeout.connect(deal_damage)
	get_tree().create_timer(0.28).timeout.connect(func():
		if attack_area:
			attack_area.monitoring = false
	)

## Oyuncunun Hasar Alması (Take Damage)
func take_damage(amount: int) -> void:
	if is_dead or is_dashing or is_rolling:
		return # Dash ve Roll anında dokunulmazlık (i-frames)

	current_health = clampi(current_health - amount, 0, max_health)
	player_damaged.emit(current_health, max_health)

	if current_health <= 0:
		die()
		return

	# Darbe Tepkisi (Hit / Hurt)
	is_hurt = true
	is_attacking = false
	velocity = Vector2(-facing_dir * 140.0, -180.0)
	if anim_sprite and anim_sprite.sprite_frames.has_animation("hit"):
		anim_sprite.play("hit")

	# Kırmızı yanıp sönme efekti
	var tw = create_tween()
	tw.tween_property(visual_node, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.08)
	tw.tween_property(visual_node, "modulate", Color.WHITE, 0.15)

	get_tree().create_timer(0.25).timeout.connect(func():
		is_hurt = false
	)

## Ölüm Mekaniği (Death)
func die() -> void:
	if is_dead:
		return
	is_dead = true
	is_attacking = false
	is_dashing = false
	is_sliding = false
	is_rolling = false
	velocity = Vector2.ZERO
	if anim_sprite and anim_sprite.sprite_frames.has_animation("death"):
		anim_sprite.play("death")
	player_died.emit()

## Kılıç Alma & Fırlatma
func can_pickup_weapon() -> bool:
	return not has_sword and not is_dead

## [E] ile yerden kılıç alma: Otomatik olarak kılıç elde (Armed) başlar
func pickup_weapon(_item: Node2D = null) -> void:
	if has_sword or is_dead:
		return
	has_sword = true
	is_armed = true
	weapon_state_changed.emit(true, true)

func pickup_sword() -> void:
	pickup_weapon(null)

func drop_sword() -> void:
	if not has_sword or is_attacking or is_dead:
		return
	has_sword = false
	is_armed = false
	weapon_state_changed.emit(false, false)

	var sword_node = SWORD_ITEM_SCENE.instantiate()
	var spawn_pos = global_position + Vector2(facing_dir * 18.0, -16.0)
	var throw_vel = Vector2(facing_dir * 250.0, -220.0)
	get_parent().add_child(sword_node)
	sword_node.launch(spawn_pos, throw_vel, 0.4)

## Çarpışma Kutusu Boyutlandırma
func _set_collision_box(size: Vector2, pos: Vector2) -> void:
	if col_shape and col_shape.shape:
		col_shape.shape.size = size
		col_shape.position = pos

func _start_safety_timer(timeout: float) -> void:
	get_tree().create_timer(timeout).timeout.connect(func():
		if is_attacking:
			is_attacking = false
			if attack_area:
				attack_area.monitoring = false
	)

func _on_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		if attack_area:
			attack_area.monitoring = false
	if is_rolling:
		is_rolling = false
		_set_collision_box(NORMAL_COL_SIZE, NORMAL_COL_POS)
	if is_sliding:
		_stop_slide()

func _play(anim_name: StringName) -> void:
	if anim_sprite.animation != anim_name and anim_sprite.sprite_frames.has_animation(anim_name):
		anim_sprite.play(anim_name)

## Animasyon Durum Kontrolü (kılıç çekili olsa da orijinal animasyonlar oynar)
func _update_animation() -> void:
	if not anim_sprite or is_dead or is_hurt or is_dashing or is_sliding or is_rolling or is_attacking:
		return

	# 1. Duvar Kayması
	if is_wall_sliding:
		_play(&"wall_slide")
		return

	# 2. Zemin Durumu
	if is_on_floor():
		if is_crouching:
			_play(&"crouch_walk" if absf(velocity.x) > 10.0 else &"crouch")
		else:
			_play(&"run" if absf(velocity.x) > 10.0 else &"idle")
	# 3. Hava Durumu (Jump, Apex, Fall)
	else:
		if velocity.y < -40.0:
			_play(&"jump")
		elif absf(velocity.y) <= 40.0:
			_play(&"jump_apex")
		else:
			_play(&"fall")
