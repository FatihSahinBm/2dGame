extends CharacterBody2D

## res://scripts/combat/combat_test_player.gd
## Test sahnesi için bağımsız ve hafif oyuncu kontrolcüsü

signal weapon_state_changed(has_weapon: bool)

@export var speed: float = 260.0
@export var jump_velocity: float = -600.0
@export var gravity: float = 1200.0

var has_sword: bool = false
var facing_dir: float = 1.0
var is_attacking: bool = false

const SWORD_ITEM_SCENE = preload("res://scenes/combat/sword_item.tscn")

@onready var visual_node: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var weapon_indicator: Sprite2D = $Visual/WeaponIndicator

func _ready() -> void:
	if anim_sprite:
		anim_sprite.animation_finished.connect(_on_animation_finished)
	_update_weapon_visual()
	weapon_state_changed.emit(has_sword)

func _physics_process(delta: float) -> void:
	# Yerçekimi
	if not is_on_floor():
		velocity.y += gravity * delta

	# Zıplama (Space, W, Yukarı Ok)
	if is_on_floor() and not is_attacking:
		if Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W):
			velocity.y = jump_velocity

	# Yatay Hareket (A/D, Sol/Sağ Ok)
	var move_x: float = 0.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_x += 1.0

	if move_x != 0.0 and not is_attacking:
		facing_dir = 1.0 if move_x > 0.0 else -1.0
		if visual_node:
			visual_node.scale.x = facing_dir
		velocity.x = move_x * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)

	move_and_slide()
	_update_animation()

func _unhandled_input(event: InputEvent) -> void:
	# Kılıcı Atma / Fırlatma (G Tuşu)
	var is_g_pressed = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		is_g_pressed = true
	elif event.is_action_pressed("drop_item"):
		is_g_pressed = true

	if is_g_pressed:
		drop_sword()
		return

	# Saldırı Girdileri (Sadece kılıç varsa)
	if has_sword and not is_attacking:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("attack_light"):
			perform_light_attack()
		elif (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) or event.is_action_pressed("attack_heavy"):
			perform_heavy_attack()

## Duck Typing: Kılıç alınabilir mi?
func can_pickup_weapon() -> bool:
	return not has_sword

## Kılıç Alma Metodu
func pickup_weapon(_item: Node2D = null) -> void:
	if has_sword:
		return
	has_sword = true
	_update_weapon_visual()
	weapon_state_changed.emit(true)
	
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("draw_sword"):
		is_attacking = true
		anim_sprite.play("draw_sword")

func pickup_sword() -> void:
	pickup_weapon(null)

## Kılıç Fırlatma / Bırakma Metodu (G tuşu)
func drop_sword() -> void:
	if not has_sword or is_attacking:
		return

	has_sword = false
	_update_weapon_visual()
	weapon_state_changed.emit(false)

	# Sahneye yeni kılıç eşyası spawn et ve ileri fırlat
	var sword_node = SWORD_ITEM_SCENE.instantiate()
	var spawn_pos = global_position + Vector2(facing_dir * 18.0, -16.0)
	var throw_vel = Vector2(facing_dir * 250.0, -220.0)

	get_parent().add_child(sword_node)
	sword_node.launch(spawn_pos, throw_vel, 0.4)

## Saldırılar
func perform_light_attack() -> void:
	is_attacking = true
	velocity.x = facing_dir * 120.0
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")
	else:
		# Yedek saldırı zamanlayıcısı
		await get_tree().create_timer(0.25).timeout
		is_attacking = false

func perform_heavy_attack() -> void:
	is_attacking = true
	velocity.x = facing_dir * 240.0
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("heavy_attack"):
		anim_sprite.play("heavy_attack")
	else:
		await get_tree().create_timer(0.4).timeout
		is_attacking = false

func _on_animation_finished() -> void:
	is_attacking = false

func _update_weapon_visual() -> void:
	if weapon_indicator:
		weapon_indicator.visible = has_sword

func _update_animation() -> void:
	if not anim_sprite or is_attacking:
		return

	if is_on_floor():
		if absf(velocity.x) > 10.0:
			if anim_sprite.sprite_frames.has_animation("run"):
				anim_sprite.play("run")
		else:
			if anim_sprite.sprite_frames.has_animation("idle"):
				anim_sprite.play("idle")
	else:
		if velocity.y < 0.0:
			if anim_sprite.sprite_frames.has_animation("jump"):
				anim_sprite.play("jump")
		else:
			if anim_sprite.sprite_frames.has_animation("fall"):
				anim_sprite.play("fall")
