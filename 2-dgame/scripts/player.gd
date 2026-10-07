extends CharacterBody2D
class_name Player

## res://scripts/player.gd
## Evrensel Ana Karakter Kontrolcüsü (Universal Player Controller).
## Tüm sahnelerde (test_boss, test_enemy, main, test_combat) kullanılır.
## İçerik:
## - Temel & İleri Hareket: Koşma, zıplama (coyote/buffer), eğilme (Ctrl), eğilerek yürüme
## - Beceri & Kaçınma: Dash (Shift), Slide (Koşarken Ctrl), Takla / Roll (Alt veya C)
## - Duvar Mekaniği: Duvar kayması (Wall Slide) ve duvardan zıplama (Wall Jump)
## - Dövüş & Kombo: 2'li kombo (Sol Tık / J), ağır saldırı (Sağ Tık / K), eğilerek saldırı
## - Can & Hasar: Darbe tepkisi (Hurt), i-frame dokunulmazlık, can kaybı ve ölüm
## - Çalışma Zamanı Kılıç Overlay'i: [1] tuşuyla çekme/kına sokma, el noktası takibi

# --- Sinyaller ---
signal sword_state_changed(has_sword: bool)
signal weapon_state_changed(has_weapon: bool, is_armed: bool)
signal attack_performed(attack_type: String)
signal player_damaged(current_hp: int, max_hp: int)
signal player_died()

# --- Ayarlar & Değişkenler ---
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
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export_group("Combat")
@export var has_sword: bool = false
@export var is_armed: bool = false
@export var light_attack_lunge: float = 110.0
@export var heavy_attack_lunge: float = 220.0

# Yere kılıç fırlatma sahnesi
const SWORD_PICKUP_SCENE = preload("res://scenes/items/sword_pickup.tscn")

# Durum Değişkenleri
var facing_dir: float = 1.0 # 1.0 = sağ, -1.0 = sol
var is_dead: bool = false
var is_hurt: bool = false
var is_attacking: bool = false
var is_drawing_sword: bool = false
var is_crouching: bool = false
var is_dashing: bool = false
var is_sliding: bool = false
var is_rolling: bool = false
var is_wall_sliding: bool = false
var current_attack_type: String = ""

# Sayaçlar
var can_dash: bool = true
var combo_step: int = 0
var combo_timer: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false

# Çarpışma Kutusu Boyutları
const NORMAL_COL_SIZE: Vector2 = Vector2(18.0, 38.0)
const NORMAL_COL_POS: Vector2 = Vector2(0.0, -19.0)
const LOW_COL_SIZE: Vector2 = Vector2(18.0, 22.0)
const LOW_COL_POS: Vector2 = Vector2(0.0, -11.0)

# Düğüm Referansları
@onready var visual_node: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var attack_area: Area2D = $Visual/AttackArea
@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var sword_overlay: Sprite2D = $Visual/AnimatedSprite2D/SwordOverlay

func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")
	_ensure_input_actions()

	if anim_sprite:
		anim_sprite.animation_finished.connect(_on_animation_finished)
	if attack_area:
		attack_area.monitoring = false
	if col_shape and col_shape.shape:
		col_shape.shape = col_shape.shape.duplicate()

	# Silah durumu dinleyicisi
	weapon_state_changed.connect(_on_weapon_state_changed)
	_emit_weapon_state()

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

func _emit_weapon_state() -> void:
	weapon_state_changed.emit(has_sword, is_armed)
	sword_state_changed.emit(has_sword)

func _on_weapon_state_changed(weapon: bool, armed: bool) -> void:
	if sword_overlay and sword_overlay.has_method("set_drawn"):
		sword_overlay.set_drawn(weapon and armed)

func _physics_process(delta: float) -> void:
	# Kombo zamanlayıcısı
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

	# 2. Darbe Sersemlemesi (Hurt)
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

	# 5. Roll (Takla Atma - Alt / C)
	if is_rolling:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		move_and_slide()
		return

	# 6. Zemin Durumu ve Coyote Time
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		velocity.y += gravity * delta

	# Jump buffer zamanlayıcısı
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta

	# 7. Duvar Kayması ve Zıplaması
	_check_wall_slide(delta)

	# 8. Hareket ve Beceri Girdileri
	_handle_movement_and_skills(delta)

	_was_on_floor = is_on_floor()
	move_and_slide()
	_update_animation()

## Duvar Kayması (Wall Slide) ve Duvar Zıplaması
func _check_wall_slide(_delta: float) -> void:
	if is_dead or is_attacking or is_rolling or is_dashing:
		is_wall_sliding = false
		return

	if not is_on_floor() and is_on_wall() and velocity.y > 0.0:
		var wall_normal = get_wall_normal()
		if (wall_normal.x < 0.0 and facing_dir > 0.0) or (wall_normal.x > 0.0 and facing_dir < 0.0):
			is_wall_sliding = true
			velocity.y = minf(velocity.y, 90.0)

			if visual_node:
				visual_node.scale.x = 1.0 if wall_normal.x > 0.0 else -1.0

			# Duvardan zıplama (Wall Jump)
			var wants_jump = Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W)
			if wants_jump:
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
	# Yatay Girdi
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

	# 1. Dash (Shift)
	var wants_dash = Input.is_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_action_just_pressed("dash")
	if wants_dash and can_dash and not is_attacking and not is_crouching:
		perform_dash()
		return

	# 2. Dodge Roll (Alt veya C)
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

	# 5. Zıplama Girdisi (Coyote Time & Buffer)
	var jump_just_pressed = Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W)
	if jump_just_pressed:
		_jump_buffer_timer = jump_buffer_time

	if (_coyote_timer > 0.0 or is_on_floor()) and _jump_buffer_timer > 0.0 and not is_attacking and not is_crouching and not is_sliding:
		velocity.y = jump_velocity
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0

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
	var wants_crouch_key = Input.is_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_CTRL) or Input.is_action_pressed("crouch")
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

## Girdi Olayları (Kılıç Çekme, Fırlatma, Saldırılar)
func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return

	# [1] Tuşu: Kılıç Çekme / Kınına Sokma (Draw / Sheathe Toggle)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			toggle_weapon_draw()
			return

	# [G] Tuşu: Kılıcı Atma / Fırlatma
	var is_g_pressed = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		is_g_pressed = true
	elif event.is_action_pressed("drop_item"):
		is_g_pressed = true

	if is_g_pressed:
		drop_sword()
		return

	# Saldırı Girdileri (Kılıç varsa)
	if has_sword and not is_attacking and not is_rolling and not is_dashing and not is_sliding:
		# Sol Tık / J: Hafif Saldırı / Kombo / Eğilerek Saldırı
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J) \
				or event.is_action_pressed("attack_light"):
			if not is_armed:
				is_armed = true
				_emit_weapon_state()

			if is_crouching:
				perform_crouch_attack()
			else:
				if combo_step == 1 and combo_timer > 0.0:
					perform_combo_attack()
				else:
					perform_light_attack()
			return

		# Sağ Tık / K: Güçlü Saldırı
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) \
				or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K) \
				or event.is_action_pressed("attack_heavy"):
			if not is_armed:
				is_armed = true
				_emit_weapon_state()
			perform_heavy_attack()
			return

## [1] Tuşu ile Kılıç Çekme / Kınına Sokma
func toggle_weapon_draw() -> void:
	if not has_sword or is_dead or is_attacking or is_rolling or is_dashing:
		return
	is_armed = not is_armed
	_emit_weapon_state()

## Hafif Saldırı (Vuruş 1)
func perform_light_attack() -> void:
	is_attacking = true
	current_attack_type = "light"
	attack_performed.emit("light")
	velocity.x = facing_dir * light_attack_lunge
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")
	_apply_attack_damage(25)
	combo_step = 1
	combo_timer = 0.5
	_start_safety_timer(0.38)

## 2'li Akıcı Kombo Saldırısı (Vuruş 2)
func perform_combo_attack() -> void:
	is_attacking = true
	combo_step = 0
	combo_timer = 0.0
	current_attack_type = "combo"
	attack_performed.emit("combo")
	velocity.x = facing_dir * 180.0
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack_combo"):
		anim_sprite.play("attack_combo")
	_apply_attack_damage(40)
	_start_safety_timer(0.65)

## Eğilerek Saldırı (Crouch Attack)
func perform_crouch_attack() -> void:
	is_attacking = true
	current_attack_type = "crouch"
	attack_performed.emit("crouch")
	velocity.x = facing_dir * 60.0
	if anim_sprite and anim_sprite.sprite_frames.has_animation("crouch_attack"):
		anim_sprite.play("crouch_attack")
	_apply_attack_damage(30)
	_start_safety_timer(0.35)

## Ağır Saldırı (Sağ Tık)
func perform_heavy_attack() -> void:
	is_attacking = true
	combo_step = 0
	combo_timer = 0.0
	current_attack_type = "heavy"
	attack_performed.emit("heavy")
	velocity.x = facing_dir * heavy_attack_lunge
	if anim_sprite and anim_sprite.sprite_frames.has_animation("heavy_attack"):
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
	current_attack_type = ""
	if attack_area:
		attack_area.monitoring = false

	# Geri sekme (Knockback)
	velocity.x = -facing_dir * 140.0
	velocity.y = -180.0

	if anim_sprite and anim_sprite.sprite_frames.has_animation("hit"):
		anim_sprite.play("hit")

	get_tree().create_timer(0.25).timeout.connect(func():
		is_hurt = false
	)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	is_attacking = false
	current_attack_type = ""
	velocity = Vector2.ZERO
	if anim_sprite and anim_sprite.sprite_frames.has_animation("death"):
		anim_sprite.play("death")
	player_died.emit()

## Kılıç Alma & Fırlatma
func can_pickup_weapon() -> bool:
	return not has_sword and not is_dead

func pickup_weapon(_item: Node2D = null) -> void:
	if has_sword or is_dead:
		return
	has_sword = true
	is_armed = true
	_emit_weapon_state()

func pickup_sword() -> void:
	pickup_weapon(null)

func drop_sword() -> void:
	if not has_sword or is_attacking or is_dead:
		return
	has_sword = false
	is_armed = false
	_emit_weapon_state()

	var sword_node = SWORD_PICKUP_SCENE.instantiate()
	var spawn_pos = global_position + Vector2(facing_dir * 18.0, -16.0)
	var throw_vel = Vector2(facing_dir * 250.0, -220.0)
	get_parent().add_child(sword_node)
	if sword_node.has_method("launch"):
		sword_node.launch(spawn_pos, throw_vel, 0.4)
	else:
		sword_node.global_position = spawn_pos

## Çarpışma Kutusu Boyutlandırma
func _set_collision_box(size: Vector2, pos: Vector2) -> void:
	if col_shape and col_shape.shape:
		col_shape.shape.size = size
		col_shape.position = pos

func _start_safety_timer(timeout: float) -> void:
	get_tree().create_timer(timeout).timeout.connect(func():
		if is_attacking:
			is_attacking = false
			current_attack_type = ""
			if attack_area:
				attack_area.monitoring = false
	)

func _on_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		current_attack_type = ""
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

## Animasyon Durum Kontrolü
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
