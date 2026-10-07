extends CharacterBody2D
class_name Player

## Kılıç ve Envanter Sinyalleri
signal sword_state_changed(has_sword: bool)
signal attack_performed(attack_type: String)

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
@export var enable_squash_stretch: bool = false

@export_group("Combat")
@export var has_sword: bool = false
@export var light_attack_lunge: float = 140.0
@export var heavy_attack_lunge: float = 260.0

# Kılıç sahnesi önceden yüklenir (Yere fırlatma için)
const SWORD_PICKUP_SCENE = preload("res://scenes/items/sword_pickup.tscn")

# Durum Değişkenleri
var facing_dir: float = 1.0 # 1.0 = sağ, -1.0 = sol
var is_attacking: bool = false
var is_drawing_sword: bool = false
var current_attack_type: String = ""

# Dahili Sayaçlar (Game Feel)
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false

# Görsel ve Çarpışma Referansları
@onready var visual_node: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var attack_area: Area2D = $Visual/AttackArea

func _ready() -> void:
	_ensure_input_actions()
	if anim_sprite:
		anim_sprite.animation_finished.connect(_on_animation_finished)
	if attack_area:
		attack_area.monitoring = false
	sword_state_changed.emit(has_sword)

func _ensure_input_actions() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var ev = InputEventKey.new()
		ev.physical_keycode = KEY_E
		InputMap.action_add_event("interact", ev)

	if not InputMap.has_action("drop_item"):
		InputMap.add_action("drop_item")
		var ev = InputEventKey.new()
		ev.physical_keycode = KEY_G
		InputMap.action_add_event("drop_item", ev)

	if not InputMap.has_action("attack_light"):
		InputMap.add_action("attack_light")
		var ev_m = InputEventMouseButton.new()
		ev_m.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack_light", ev_m)
		var ev_k = InputEventKey.new()
		ev_k.physical_keycode = KEY_J
		InputMap.action_add_event("attack_light", ev_k)

	if not InputMap.has_action("attack_heavy"):
		InputMap.add_action("attack_heavy")
		var ev_m = InputEventMouseButton.new()
		ev_m.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("attack_heavy", ev_m)
		var ev_k = InputEventKey.new()
		ev_k.physical_keycode = KEY_K
		InputMap.action_add_event("attack_heavy", ev_k)

func _physics_process(delta: float) -> void:
	# 1. Zemin Durumu ve Coyote Time
	if is_on_floor():
		_coyote_timer = coyote_time
		if not _was_on_floor and velocity.y >= 0.0:
			_apply_squash(Vector2(1.1, 0.9))
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		velocity.y += gravity * delta

	_was_on_floor = is_on_floor()

	# 2. Girdileri Dinle
	_handle_combat_and_item_input()

	# 3. Zıplama Mantığı (Saldırı veya Kılıç Çekme anında kısıtlanabilir)
	if not is_attacking and not is_drawing_sword:
		if _is_jump_just_pressed():
			_jump_buffer_timer = jump_buffer_time
		else:
			_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

		if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
			velocity.y = jump_velocity
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0
			_apply_squash(Vector2(0.9, 1.1))

		if _is_jump_just_released() and velocity.y < 0.0:
			velocity.y *= 0.5
	else:
		_jump_buffer_timer = 0.0

	# 4. Yatay Hareket
	var input_x: float = _get_horizontal_axis()

	# Yüz yönünü güncelle
	if input_x != 0.0 and not is_attacking and not is_drawing_sword:
		facing_dir = 1.0 if input_x > 0.0 else -1.0
		if visual_node:
			visual_node.scale.x = facing_dir

	# Saldırı sırasında hafif yavaşlama veya lunge korunumu
	if is_attacking or is_drawing_sword:
		velocity.x = move_toward(velocity.x, 0.0, friction * 1.5 * delta)
	else:
		var current_accel: float = accel if is_on_floor() else air_accel
		var current_friction: float = friction if is_on_floor() else air_friction

		if input_x != 0.0:
			velocity.x = move_toward(velocity.x, input_x * speed, current_accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, current_friction * delta)

	# 5. Hareketi Uygula
	move_and_slide()

	# 6. Animasyon Kontrolü
	_update_animation(input_x)

	# 7. Squash toparlanması
	if enable_squash_stretch:
		_recover_visual(delta)

## Savaş ve Eşya Girdileri
func _handle_combat_and_item_input() -> void:
	# Kılıç Atma (G Tuşu)
	if _is_drop_just_pressed():
		drop_sword()
		return

	# Saldırı Girdileri (Yalnızca kılıç varsa ve başka eylemde değilsek)
	if has_sword and not is_attacking and not is_drawing_sword:
		if _is_light_attack_just_pressed():
			perform_light_attack()
		elif _is_heavy_attack_just_pressed():
			perform_heavy_attack()

## Kılıç Alma (E tuşu ile yerden çağrılır)
func pickup_sword() -> void:
	if has_sword:
		return
	has_sword = true
	sword_state_changed.emit(true)
	
	# Kılıç Çekme Animasyonu
	is_drawing_sword = true
	is_attacking = false
	velocity.x *= 0.2
	_play_animation(&"draw_sword")

## Kılıç Atma (G tuşu)
func drop_sword() -> void:
	if not has_sword or is_attacking:
		return

	is_drawing_sword = false
	has_sword = false
	sword_state_changed.emit(false)

	# Yere fırlatılan kılıç eşyasını oluştur
	var sword_inst = SWORD_PICKUP_SCENE.instantiate()
	var spawn_pos = global_position + Vector2(facing_dir * 20.0, -18.0)
	var throw_velocity = Vector2(facing_dir * 240.0, -200.0)

	get_parent().add_child(sword_inst)
	sword_inst.launch(spawn_pos, throw_velocity, 0.4)

## Sol Tık: Kılıç Savurma (Hafif Saldırı)
func perform_light_attack() -> void:
	is_attacking = true
	current_attack_type = "light"
	attack_performed.emit("light")

	# Hafif öne atılma (Lunge)
	velocity.x = facing_dir * light_attack_lunge

	# Hitbox'ı etkinleştir
	if attack_area:
		attack_area.monitoring = true

	_play_animation(&"attack")

## Sağ Tık: Güçlü Vuruş (Ağır Saldırı)
func perform_heavy_attack() -> void:
	is_attacking = true
	current_attack_type = "heavy"
	attack_performed.emit("heavy")

	# Güçlü ileri atılma
	velocity.x = facing_dir * heavy_attack_lunge

	# Hitbox'ı etkinleştir
	if attack_area:
		attack_area.monitoring = true

	_play_animation(&"heavy_attack")

## Animasyon Bitimi Sinyali
func _on_animation_finished() -> void:
	var anim_name = anim_sprite.animation
	if anim_name == &"attack" or anim_name == &"heavy_attack":
		is_attacking = false
		current_attack_type = ""
		if attack_area:
			attack_area.monitoring = false
	elif anim_name == &"draw_sword":
		is_drawing_sword = false

## Animasyon Seçimi
func _update_animation(input_x: float) -> void:
	if not anim_sprite:
		return

	# Özel eylem animasyonları tamamlanana kadar diğer animasyonlar beklemede kalır
	if is_attacking or is_drawing_sword:
		return

	if is_on_floor():
		if absf(velocity.x) > 10.0:
			_play_animation(&"run")
		else:
			_play_animation(&"idle")
	else:
		if velocity.y < 0.0:
			_play_animation(&"jump")
		else:
			_play_animation(&"fall")

func _play_animation(anim_name: StringName) -> void:
	if anim_sprite and anim_sprite.animation != anim_name:
		anim_sprite.play(anim_name)

## Giriş Kontrolleri (Action ve Tuş fallback destekli)
func _get_horizontal_axis() -> float:
	var axis: float = Input.get_axis("move_left", "move_right")
	if is_zero_approx(axis):
		axis = Input.get_axis("ui_left", "ui_right")
	return axis

func _is_jump_just_pressed() -> bool:
	return Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")

func _is_jump_just_released() -> bool:
	return Input.is_action_just_released("jump") or Input.is_action_just_released("ui_accept") or Input.is_action_just_released("ui_up")

func _is_drop_just_pressed() -> bool:
	return Input.is_action_just_pressed("drop_item")

func _is_light_attack_just_pressed() -> bool:
	return Input.is_action_just_pressed("attack_light")

func _is_heavy_attack_just_pressed() -> bool:
	return Input.is_action_just_pressed("attack_heavy")

## Squash & Stretch
func _apply_squash(scale_mod: Vector2) -> void:
	if enable_squash_stretch and visual_node:
		visual_node.scale = Vector2(scale_mod.x * facing_dir, scale_mod.y)

func _recover_visual(delta: float) -> void:
	if visual_node:
		visual_node.scale.x = move_toward(visual_node.scale.x, facing_dir, 2.0 * delta)
		visual_node.scale.y = move_toward(visual_node.scale.y, 1.0, 2.0 * delta)
