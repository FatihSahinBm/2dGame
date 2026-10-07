extends CharacterBody2D

## Hareket ve Fizik Ayarları
@export_group("Movement")
@export var speed: float = 260.0
@export var accel: float = 1800.0
@export var friction: float = 1600.0
@export var air_accel: float = 1200.0
@export var air_friction: float = 400.0

@export_group("Jump & Feel")
@export var jump_velocity: float = -620.0
@export var gravity: float = 1200.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var enable_squash_stretch: bool = false # Piksel sanatının bozulmaması için varsayılan kapalı

# Dahili Sayaçlar (Game Feel)
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false

# Görsel Referanslar
@onready var visual_node: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# 1. Zemin Durumu ve Coyote Time
	if is_on_floor():
		_coyote_timer = coyote_time
		# Yeni iniş yapıldıysa (Landing Squash)
		if not _was_on_floor and velocity.y >= 0.0:
			_apply_squash(Vector2(1.1, 0.9))
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		# Havada yerçekimi uygula (Godot 4: delta ile çarpılır)
		velocity.y += gravity * delta

	_was_on_floor = is_on_floor()

	# 2. Zıplama Tamponu (Jump Buffering)
	if _is_jump_just_pressed():
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	# 3. Zıplama İcrası (Coyote Time + Jump Buffer)
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_apply_squash(Vector2(0.9, 1.1)) # Jump Stretch

	# 4. Değişken Zıplama Yüksekliği (Variable Jump Height)
	# Tuş erken bırakıldığında yukarı hız kesilerek kısa zıplama sağlanır
	if _is_jump_just_released() and velocity.y < 0.0:
		velocity.y *= 0.5

	# 5. Yatay Hareket (İvmelenme ve Sürtünme)
	var input_x: float = _get_horizontal_axis()
	var current_accel: float = accel if is_on_floor() else air_accel
	var current_friction: float = friction if is_on_floor() else air_friction

	if input_x != 0.0:
		velocity.x = move_toward(velocity.x, input_x * speed, current_accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_friction * delta)

	# 6. Hareketi Uygula (Godot 4: argümansız move_and_slide)
	move_and_slide()

	# 7. Animasyon Güncellemesi (Idle, Run, Jump, Fall, flip_h)
	_update_animation(input_x)

	# 8. Squash & Stretch toparlanması
	if enable_squash_stretch:
		_recover_visual(delta)

# Animasyon Kontrolü
func _update_animation(input_x: float) -> void:
	if not anim_sprite:
		return

	# Sola giderken flip_h = true, sağa giderken false
	if input_x < 0.0:
		anim_sprite.flip_h = true
	elif input_x > 0.0:
		anim_sprite.flip_h = false

	# Durum bazlı animasyon seçimi
	if is_on_floor():
		if absf(velocity.x) > 10.0:
			_play_animation(&"run")
		else:
			_play_animation(&"idle")
	else:
		# Havadayken: yükselirken jump, düşerken fall
		if velocity.y < 0.0:
			_play_animation(&"jump")
		else:
			_play_animation(&"fall")

func _play_animation(anim_name: StringName) -> void:
	if anim_sprite and anim_sprite.animation != anim_name:
		anim_sprite.play(anim_name)

# Giriş Fonksiyonları (Hem özel aksiyonları hem Godot varsayılanlarını destekler)
func _get_horizontal_axis() -> float:
	var axis: float = Input.get_axis("move_left", "move_right")
	if is_zero_approx(axis):
		axis = Input.get_axis("ui_left", "ui_right")
	return axis

func _is_jump_just_pressed() -> bool:
	return Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")

func _is_jump_just_released() -> bool:
	return Input.is_action_just_released("jump") or Input.is_action_just_released("ui_accept") or Input.is_action_just_released("ui_up")

# Squash & Stretch Yardımcıları
func _apply_squash(scale_mod: Vector2) -> void:
	if enable_squash_stretch and visual_node:
		visual_node.scale = scale_mod

func _recover_visual(delta: float) -> void:
	if visual_node:
		visual_node.scale.x = move_toward(visual_node.scale.x, 1.0, 2.0 * delta)
		visual_node.scale.y = move_toward(visual_node.scale.y, 1.0, 2.0 * delta)
