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
signal defense_state_changed(is_defending: bool)
signal shield_state_changed(is_holding: bool)
signal attack_blocked(reduced_damage: int, original_damage: int)
signal parry_performed()

# --- Ayarlar & Değişkenler ---
@export_group("Stats & Movement")
@export var can_move: bool = true
@export var max_health: int = 100
@export var current_health: int = 100
@export var speed: float = 260.0
@export var crouch_speed: float = 120.0
@export var dash_speed: float = 680.0
@export var slide_speed: float = 380.0
@export var roll_speed: float = 340.0
@export var jump_velocity: float = -600.0
@export var wall_jump_velocity: Vector2 = Vector2(340.0, -560.0)
@export var gravity: float = 1200.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export_group("Upgrades & Skills")
@export var double_jump_unlocked: bool = true
@export var dash_iframes_unlocked: bool = true
@export var slide_iframes_unlocked: bool = true
@export var max_air_jumps: int = 1
var _air_jumps_left: int = 1
var _wall_jump_push_timer: float = 0.0

@export_group("Combat")
@export var has_sword: bool = false
@export var is_armed: bool = false
@export var light_attack_lunge: float = 110.0
@export var heavy_attack_lunge: float = 220.0

@export_group("Defense & Parry")
@export var defend_damage_reduction: float = 0.8 # Savunmadayken hasarın %80'ini engelle (%20 hasar al)
@export var parry_window: float = 0.2 # Tuşa basıldıktan sonraki ilk 0.2 saniye Perfect Block / Parry
@export var defend_speed_multiplier: float = 0.5 # Savunmadayken hareket hızı %50 azalır

# Yere kılıç fırlatma sahnesi
const SWORD_PICKUP_SCENE = preload("res://scenes/items/sword_pickup.tscn")

# Durum Değişkenleri
var facing_dir: float = 1.0 # 1.0 = sağ, -1.0 = sol
var is_dead: bool = false
var is_hurt: bool = false
var is_attacking: bool = false
var is_defending: bool = false
var is_holding_shield: bool = false
var is_drawing_sword: bool = false
var is_crouching: bool = false
var is_dashing: bool = false
var is_sliding: bool = false
var is_rolling: bool = false
var is_wall_sliding: bool = false
var current_attack_type: String = ""
var block_timer: float = 0.0

# Sayaçlar
var can_dash: bool = true
var combo_step: int = 0
var combo_timer: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false

# Sıkı Savuşturma (Parry) Ayarları - Ustalık ve Zamanlama Gerektiren Mekanik
var is_parry_active: bool = false
const PARRY_WINDOW_DURATION: float = 0.12 # Vuruşun ilk 0.12 saniyesi (yaklaşık 7-8 kare)
const PARRY_MIN_FORWARD_DIST: float = 14.0 # Karakterin çok dibinde veya arkasında olamaz
const PARRY_MAX_FORWARD_DIST: float = 55.0 # Kılıç savurma menzili (dar ve hassas sweet-spot)
const PARRY_MAX_Y_DIFF: float = 26.0 # Göğüs/kılıç yatay hizası

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
var parabolic_shield: Area2D = null

func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")
	_ensure_input_actions()

	# Düşman katmanıyla (Layer 2) fiziksel çarpışmayı aç (içlerine yürümeyi/geçmeyi önler)
	set_collision_mask_value(2, true)

	if anim_sprite:
		anim_sprite.animation_finished.connect(_on_animation_finished)
	if attack_area:
		attack_area.monitoring = false
	if col_shape and col_shape.shape:
		col_shape.shape = col_shape.shape.duplicate()

	# Parabolik Kalkan İlklendirme
	if not parabolic_shield and visual_node:
		if visual_node.has_node("ParabolicShield"):
			parabolic_shield = visual_node.get_node("ParabolicShield")
		else:
			var shield_res = load("res://scenes/combat/parabolic_shield.tscn")
			if shield_res:
				parabolic_shield = shield_res.instantiate()
				visual_node.add_child(parabolic_shield)

	# Silah durumu dinleyicisi
	weapon_state_changed.connect(_on_weapon_state_changed)
	_emit_weapon_state()

	# Dost birliklerin (allies) bizi bloklamasını önle - içlerinden geçilebilsin
	_setup_ally_collision_exceptions()


func _setup_ally_collision_exceptions() -> void:
	for ally in get_tree().get_nodes_in_group("allies"):
		if ally is CollisionObject2D:
			add_collision_exception_with(ally)
			ally.add_collision_exception_with(self)
	get_tree().node_added.connect(func(node: Node):
		if node.is_in_group("allies") and node is CollisionObject2D:
			add_collision_exception_with(node)
			node.add_collision_exception_with(self)
	)


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

	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		var ev = InputEventKey.new()
		ev.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("dash", ev)

	if not InputMap.has_action("crouch"):
		InputMap.add_action("crouch")
		var ev = InputEventKey.new()
		ev.physical_keycode = KEY_CTRL
		InputMap.action_add_event("crouch", ev)

	if not InputMap.has_action("roll"):
		InputMap.add_action("roll")
		var ev_alt = InputEventKey.new()
		ev_alt.physical_keycode = KEY_ALT
		InputMap.action_add_event("roll", ev_alt)
		var ev_c = InputEventKey.new()
		ev_c.physical_keycode = KEY_C
		InputMap.action_add_event("roll", ev_c)

	if not InputMap.has_action("toggle_weapon"):
		InputMap.add_action("toggle_weapon")
		var ev = InputEventKey.new()
		ev.physical_keycode = KEY_1
		InputMap.action_add_event("toggle_weapon", ev)

	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
		var ev_space = InputEventKey.new()
		ev_space.physical_keycode = KEY_SPACE
		InputMap.action_add_event("jump", ev_space)
		var ev_w = InputEventKey.new()
		ev_w.physical_keycode = KEY_W
		InputMap.action_add_event("jump", ev_w)

	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
		var ev_a = InputEventKey.new()
		ev_a.physical_keycode = KEY_A
		InputMap.action_add_event("move_left", ev_a)
		var ev_left = InputEventKey.new()
		ev_left.physical_keycode = KEY_LEFT
		InputMap.action_add_event("move_left", ev_left)

	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")
		var ev_d = InputEventKey.new()
		ev_d.physical_keycode = KEY_D
		InputMap.action_add_event("move_right", ev_d)
		var ev_right = InputEventKey.new()
		ev_right.physical_keycode = KEY_RIGHT
		InputMap.action_add_event("move_right", ev_right)

	if InputMap.has_action("ui_defend"):
		InputMap.erase_action("ui_defend")
	if InputMap.has_action("defend"):
		InputMap.erase_action("defend")

	if not InputMap.has_action("toggle_shield"):
		InputMap.add_action("toggle_shield")
		var ev_3 = InputEventKey.new()
		ev_3.physical_keycode = KEY_3
		InputMap.action_add_event("toggle_shield", ev_3)
		var ev_kp3 = InputEventKey.new()
		ev_kp3.physical_keycode = KEY_KP_3
		InputMap.action_add_event("toggle_shield", ev_kp3)

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
		_air_jumps_left = max_air_jumps
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		velocity.y += gravity * delta

	# Jump buffer zamanlayıcısı
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta

	if _wall_jump_push_timer > 0.0:
		_wall_jump_push_timer -= delta

	# 7. Duvar Kayması ve Zıplaması
	_check_wall_slide(delta)

	# 7.5. Savunma / Parabolik Kalkan Kontrolü (Yalnızca elde kalkan varken Sağ Tık)
	var wants_defend: bool = false
	if not is_dead and not is_hurt and not is_dashing and not is_rolling and not is_sliding:
		if is_holding_shield and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			wants_defend = true
		# Eğer kalkan kırılmışsa açılamaz
		if parabolic_shield and parabolic_shield.is_broken:
			wants_defend = false

	if wants_defend:
		if not is_defending:
			is_defending = true
			block_timer = 0.0
			is_attacking = false
			if attack_area:
				attack_area.monitoring = false
			if parabolic_shield:
				parabolic_shield.activate()
			if visual_node:
				visual_node.rotation_degrees = -3.5 * facing_dir
			defense_state_changed.emit(true)
		else:
			block_timer += delta
	else:
		if is_defending:
			is_defending = false
			block_timer = 0.0
			if parabolic_shield:
				parabolic_shield.deactivate()
			if visual_node:
				visual_node.rotation_degrees = 0.0
			defense_state_changed.emit(false)

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

	if not is_on_floor() and is_on_wall():
		var wall_normal = get_wall_normal()
		if wall_normal.x != 0.0:
			is_wall_sliding = true
			_air_jumps_left = max_air_jumps # Duvara tutunmak double jump'ı tazeler

			if velocity.y > 0.0:
				velocity.y = minf(velocity.y, 85.0)

			if visual_node:
				visual_node.scale.x = signf(wall_normal.x)

			# Duvardan zıplama (Wall Jump)
			var wants_jump = Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W)
			if wants_jump:
				facing_dir = signf(wall_normal.x)
				if visual_node:
					visual_node.scale.x = facing_dir
				velocity.x = facing_dir * wall_jump_velocity.x
				velocity.y = wall_jump_velocity.y
				_wall_jump_push_timer = 0.18
				is_wall_sliding = false
				_spawn_jump_puff()
				return
			return

	if is_wall_sliding:
		is_wall_sliding = false
		if visual_node:
			visual_node.scale.x = facing_dir

## Hareket ve Beceri Kontrolleri
func _handle_movement_and_skills(delta: float) -> void:
	if not can_move:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		if is_on_floor() and anim_sprite and not is_attacking:
			anim_sprite.play("idle")
		return

	# Yatay Girdi (Vururken de serbestçe hareket edebilme)
	var move_x: float = 0.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_x += 1.0

	# Yüz Yönü
	if move_x != 0.0 and not is_wall_sliding and _wall_jump_push_timer <= 0.0:
		facing_dir = 1.0 if move_x > 0.0 else -1.0
		if visual_node:
			visual_node.scale.x = facing_dir

	# 1. Dash (Shift)
	var wants_dash = (Input.is_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_action_just_pressed("dash")) and not is_defending
	if wants_dash and can_dash and not is_attacking and not is_crouching:
		perform_dash()
		return

	# 2. Dodge Roll (Alt veya C)
	var wants_roll = (Input.is_key_pressed(KEY_ALT) or Input.is_physical_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_C)) and is_on_floor() and not is_defending
	if wants_roll and not is_attacking and not is_rolling and not is_sliding:
		perform_roll()
		return

	# 3. Slide (Hızlı koşarken Ctrl'e basılırsa)
	var wants_crouch_key = (Input.is_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_CTRL) or Input.is_action_pressed("crouch")) and not is_defending
	if wants_crouch_key and is_on_floor() and absf(velocity.x) > 170.0 and not is_sliding and not is_attacking:
		perform_slide()
		return

	# 4. Eğilme (Ctrl tuşu)
	var wants_crouch = wants_crouch_key and is_on_floor() and not is_attacking and not is_sliding and not is_defending
	if wants_crouch != is_crouching:
		is_crouching = wants_crouch
		_set_collision_box(LOW_COL_SIZE if is_crouching else NORMAL_COL_SIZE, LOW_COL_POS if is_crouching else NORMAL_COL_POS)

	# 5. Zıplama Girdisi (Coyote Time, Buffer & Double Jump)
	var jump_just_pressed = Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W)
	if jump_just_pressed:
		_jump_buffer_timer = jump_buffer_time

	if (_coyote_timer > 0.0 or is_on_floor()) and _jump_buffer_timer > 0.0 and not is_attacking and not is_crouching and not is_sliding and not is_defending:
		velocity.y = jump_velocity
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
	elif jump_just_pressed and double_jump_unlocked and _air_jumps_left > 0 and not is_on_floor() and not is_wall_sliding and not is_attacking and not is_defending:
		# Çift Zıplama (Double Jump)
		_air_jumps_left -= 1
		velocity.y = jump_velocity * 0.88
		_jump_buffer_timer = 0.0
		_spawn_jump_puff()
		if anim_sprite and anim_sprite.sprite_frames.has_animation("jump"):
			anim_sprite.play("jump")

	# 6. Yatay Hız (Vururken de adımlama ve koşma korunur)
	if _wall_jump_push_timer <= 0.0:
		var current_speed: float = crouch_speed if is_crouching else speed
		if is_defending:
			current_speed *= defend_speed_multiplier
		if move_x != 0.0:
			# Doğal adımlama ivmelenmesi
			velocity.x = move_toward(velocity.x, move_x * current_speed, 2200.0 * delta)
		else:
			# Zemin sürtünmesi / adımlama freni: Tuş bırakıldığında buzda kayar gibi sürüklenmek yerine zemine sağlam basıp durur
			velocity.x = move_toward(velocity.x, 0.0, 2800.0 * delta)

## Dash (Shift - Geliştirilmiş Çevik İleri Atılma & Düşmanların İçinden Geçme)
func perform_dash() -> void:
	is_dashing = true
	can_dash = false
	set_collision_mask_value(2, false) # Düşmanların içinden geç
	velocity.x = facing_dir * dash_speed
	velocity.y = 0.0
	if anim_sprite and anim_sprite.sprite_frames.has_animation("dash"):
		anim_sprite.play("dash")

	_spawn_dash_ghost()
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_dashing: _spawn_dash_ghost()
	)

	get_tree().create_timer(0.22).timeout.connect(func():
		is_dashing = false
		set_collision_mask_value(2, true) # Düşman çarpışmasını geri aç
	)
	get_tree().create_timer(0.48).timeout.connect(func():
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

## Girdi Olayları (Kılıç Çekme, Fırlatma, Saldırılar, Yeniden Doğma)
func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_R or event.physical_keycode == KEY_R:
				respawn()
		return

	if not can_move:
		return

	# [1] Tuşu: Kılıç Çekme / Kınına Sokma (Draw / Sheathe Toggle)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			toggle_weapon_draw()
			return

	# [3] Tuşu: Kalkanı Eline Alma / İndirme (Shield Equip / Stow Toggle)
	if event.is_action_pressed("toggle_shield") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_3 or event.keycode == KEY_KP_3)):
		toggle_shield_in_hand()
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

	# Saldırı Girdileri (Kılıç varsa ve savunmada DEĞİLKEN)
	if has_sword and not is_attacking and not is_rolling and not is_dashing and not is_sliding and not is_defending:
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
			# Elde kalkan varken sağ tık savunma (kalkan) içindir; ağır saldırı yapılmaz
			if is_holding_shield and (event is InputEventMouseButton or not (event is InputEventKey and event.keycode == KEY_K)):
				return
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

## [3] Tuşu ile Kalkanı Eline Alma / İndirme
func toggle_shield_in_hand() -> void:
	if is_dead:
		return
	is_holding_shield = not is_holding_shield
	if not is_holding_shield and is_defending:
		is_defending = false
		block_timer = 0.0
		if parabolic_shield:
			parabolic_shield.deactivate()
		defense_state_changed.emit(false)
	shield_state_changed.emit(is_holding_shield)

	# Görsel bildirim metni
	var parent_scene: Node = get_parent()
	if parent_scene:
		var label: Label = Label.new()
		label.text = "🛡️ KALKAN ELDE (Sağ Tık: Savun)" if is_holding_shield else "⚔️ KALKAN İNDİRİLDİ (Sağ Tık: Ağır Saldırı)"
		label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1.0) if is_holding_shield else Color(1.0, 0.8, 0.3, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1, 1.0))
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_font_size_override("font_size", 12)
		label.global_position = global_position + Vector2(-60.0, -48.0)
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		if tw:
			tw.tween_property(label, "global_position:y", label.global_position.y - 25.0, 0.5)
			tw.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
			tw.tween_callback(label.queue_free)

## Hafif Saldırı (Vuruş 1)
func perform_light_attack() -> void:
	is_attacking = true
	current_attack_type = "light"
	attack_performed.emit("light")
	if absf(velocity.x) < light_attack_lunge:
		velocity.x = facing_dir * light_attack_lunge
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")
	_apply_attack_damage(25)
	_open_parry_window()
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
	if absf(velocity.x) < 180.0:
		velocity.x = facing_dir * 180.0
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack_combo"):
		anim_sprite.play("attack_combo")
	_apply_attack_damage(40)
	_open_parry_window()
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
	_open_parry_window()
	_start_safety_timer(0.35)

## Parry Penceresi ve Durumu (Kılıçla zamanında karşılama)
func can_parry_projectile() -> bool:
	return has_sword and is_parry_active and not is_dead and not is_hurt

func _open_parry_window() -> void:
	if not has_sword or is_dead or is_hurt:
		return
	is_parry_active = true
	_check_projectile_parry()
	get_tree().create_timer(PARRY_WINDOW_DURATION).timeout.connect(func():
		is_parry_active = false
	)

## Kara Büyü ve Mermi Yansıtma Kontrolü (Hassas Zamanlama ve Dar Menzil)
func _check_projectile_parry() -> bool:
	if not can_parry_projectile():
		return false

	var projectiles = get_tree().get_nodes_in_group("reflectable_projectile")
	var parried_any: bool = false

	for proj in projectiles:
		if not is_instance_valid(proj) or proj.get("is_reflected") == true:
			continue

		var player_chest: Vector2 = global_position + Vector2(0.0, -20.0)
		var to_proj: Vector2 = proj.global_position - player_chest
		var forward_dist: float = to_proj.x * facing_dir
		var y_diff: float = absf(to_proj.y)

		# Sıkı zamanlama ve dar mesafe kontrolü:
		# 1. Büyü kesinlikle oyuncunun baktığı yönde ve kılıcın dar vuruş menzilinde olmalı (14px - 55px)
		# 2. Göğüs / kılıç yatay hizasında olmalı (<= 26px)
		if forward_dist >= PARRY_MIN_FORWARD_DIST and forward_dist <= PARRY_MAX_FORWARD_DIST and y_diff <= PARRY_MAX_Y_DIFF:
			if proj.has_method("reflect"):
				proj.reflect(self)
				_play_parry_feedback(proj.global_position)
				parried_any = true

	return parried_any

## Yansıtma / Parry Görsel ve Hissiyat Geribildirimi (Juice)
func _play_parry_feedback(impact_pos: Vector2) -> void:
	# 1. Hit-Stop (Mikro donma efekti - 0.06s)
	Engine.time_scale = 0.08
	get_tree().create_timer(0.06, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
	)

	# 2. Karakter Parlaması (Altın/Mavi Yansıma Parıltısı)
	if visual_node:
		var tw = create_tween()
		tw.tween_property(visual_node, "modulate", Color(2.2, 2.2, 1.2, 1.0), 0.04)
		tw.tween_property(visual_node, "modulate", Color.WHITE, 0.12)

	# 3. Kamera Titremesi (Screen Shake)
	var cam = get_node_or_null("Camera2D")
	if cam and cam.has_method("apply_shake"):
		cam.apply_shake(6.0)

	# 4. Yansıtma Metni (Floating Feedback)
	var parent_scene = get_parent()
	if parent_scene:
		var label = Label.new()
		label.text = "⚔️ PARRY!"
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.22, 1.0))
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_font_size_override("font_size", 14)
		label.global_position = impact_pos + Vector2(-30, -35)
		parent_scene.add_child(label)

		var tw = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 30.0, 0.55)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
		tw.tween_callback(label.queue_free)

## Ağır Saldırı (Sağ Tık)
func perform_heavy_attack() -> void:
	is_attacking = true
	combo_step = 0
	combo_timer = 0.0
	current_attack_type = "heavy"
	attack_performed.emit("heavy")
	if absf(velocity.x) < heavy_attack_lunge:
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
	var hit_objects: Array[Object] = []
	var deal_damage = func():
		# 1. Overlapping bodies (Düşmanlar & Static Barikatlar)
		for body in attack_area.get_overlapping_bodies():
			if body == self or body in hit_objects:
				continue
			hit_objects.append(body)
			if body.has_method("take_damage"):
				body.take_damage(damage)
			elif body.has_method("hit"):
				body.hit(damage)

		# 2. Overlapping areas (Hurtbox'lar)
		for area in attack_area.get_overlapping_areas():
			var target = area.get_parent() if area.get_parent() != self else area
			if target == self or target in hit_objects:
				continue
			hit_objects.append(target)
			if target.has_method("take_damage"):
				target.take_damage(damage)
			elif target.has_method("hit"):
				target.hit(damage)

		# 3. Doğrudan Fizik Alanı Sorgusu (Anında ve kesin vuruş garantisi)
		var space_state = get_world_2d().direct_space_state
		if space_state:
			var query = PhysicsShapeQueryParameters2D.new()
			var shape = CircleShape2D.new()
			shape.radius = 56.0
			query.shape = shape
			query.transform = Transform2D(0.0, global_position + Vector2(facing_dir * 38.0, -18.0))
			query.collision_mask = 31 # Tüm katmanlar (Dünya, Düşmanlar, Barikatlar)
			query.exclude = [self]
			query.collide_with_bodies = true
			query.collide_with_areas = true
			var results = space_state.intersect_shape(query, 16)
			for r in results:
				var col = r.get("collider")
				if col and is_instance_valid(col) and col != self:
					var target = col
					if target is Area2D and target.get_parent() and target.get_parent() != self:
						target = target.get_parent()
					if target in hit_objects:
						continue
					hit_objects.append(target)
					if target.has_method("take_damage"):
						target.take_damage(damage)
					elif target.has_method("hit"):
						target.hit(damage)

	deal_damage.call()
	get_tree().create_timer(0.12).timeout.connect(deal_damage)
	get_tree().create_timer(0.28).timeout.connect(func():
		if attack_area:
			attack_area.monitoring = false
	)

## Oyuncunun Hasar Alması (Take Damage)
func take_damage(amount: int, attacker_source: Variant = Vector2.INF) -> void:
	if is_dead:
		return

	var attacker_pos: Vector2 = Vector2.INF
	if attacker_source is Vector2:
		attacker_pos = attacker_source
	elif attacker_source is Node2D and is_instance_valid(attacker_source):
		attacker_pos = attacker_source.global_position

	# Dash ve Slide Dokunulmazlık Özelliği (i-Frames - Açılabilir Yetenek)
	if is_dashing and dash_iframes_unlocked:
		_spawn_dodge_text("⚡ DASH DODGE!")
		return
	if is_sliding and slide_iframes_unlocked:
		_spawn_dodge_text("⚡ SLIDE EVADE!")
		return
	if is_rolling:
		return

	# Saldırgan konumu verilmediyse ve yakınlarda bir düşman varsa tespit et
	if attacker_pos == Vector2.INF and is_defending and is_inside_tree() and get_tree():
		var enemies = get_tree().get_nodes_in_group("enemies")
		for e in enemies:
			if is_instance_valid(e) and global_position.distance_to(e.global_position) < 240.0:
				attacker_pos = e.global_position
				break

	# 1. Parabolik Kalkan Kontrolü (180° Ön Koruma)
	if parabolic_shield and parabolic_shield.is_active:
		if attacker_pos != Vector2.INF:
			if parabolic_shield.is_blocking_attack(attacker_pos):
				# Önden gelen darbe kalkan tarafından %100 absorbe edildi!
				return
			else:
				# Saldırı ARKADAN geldi! Parabolik kalkan sadece önü korur, arkadan tam hasar alınır!
				pass
		else:
			# Doğrudan / Konumsuz hasar (örn. test tuşları)
			if block_timer <= parry_window:
				_trigger_perfect_parry(amount)
				return
			else:
				var blocked_damage: int = int(round(float(amount) * (1.0 - defend_damage_reduction)))
				if amount > 0:
					blocked_damage = maxi(1, blocked_damage)
				parabolic_shield.consume_stamina(float(amount) * 0.5)
				_trigger_block_hit(amount, blocked_damage)
				amount = blocked_damage
	elif is_defending:
		# Standart Blok / Parry (Kalkan kapalıyken veya kalkan yokken)
		if block_timer <= parry_window:
			_trigger_perfect_parry(amount)
			return
		else:
			var blocked_damage: int = int(round(float(amount) * (1.0 - defend_damage_reduction)))
			if amount > 0:
				blocked_damage = maxi(1, blocked_damage)
			_trigger_block_hit(amount, blocked_damage)
			amount = blocked_damage

	current_health = clampi(current_health - amount, 0, max_health)
	player_damaged.emit(current_health, max_health)

	if current_health <= 0:
		die()
		return

	# Eğer savunmada değilken darbe alındıysa tam sersemleme (Hurt / Knockback)
	if not is_defending:
		is_hurt = true
		is_attacking = false
		is_parry_active = false
		current_attack_type = ""
		if attack_area:
			attack_area.monitoring = false

		# Geri sekme (Knockback)
		velocity.x = -facing_dir * 140.0
		velocity.y = -180.0

		if anim_sprite:
			if anim_sprite.sprite_frames.has_animation("take_damage"):
				anim_sprite.play("take_damage")
			elif anim_sprite.sprite_frames.has_animation("hit"):
				anim_sprite.play("hit")

		if is_inside_tree() and get_tree():
			get_tree().create_timer(0.25).timeout.connect(func():
				is_hurt = false
			)
		else:
			is_hurt = false

## Perfect Block / Parry Efekti ve Geri Bildirimi (%100 Hasar Engelleme)
func _trigger_perfect_parry(_incoming_amount: int) -> void:
	parry_performed.emit()

	# 1. Hit-stop (Mikro donma hissi - 0.06s)
	if is_inside_tree() and get_tree():
		Engine.time_scale = 0.08
		get_tree().create_timer(0.06, true, false, true).timeout.connect(func():
			Engine.time_scale = 1.0
		)

	# 2. Karakter Parlaması (Altın Sarı Parıltı)
	if visual_node:
		var orig_mod: Color = visual_node.modulate
		visual_node.modulate = Color(2.6, 2.3, 0.7, 1.0)
		if is_inside_tree() and get_tree():
			get_tree().create_timer(0.16, true, false, true).timeout.connect(func():
				if is_instance_valid(visual_node):
					visual_node.modulate = orig_mod
			)

	# 3. Kamera Titremesi (Screen Shake)
	var cam = get_node_or_null("Camera2D")
	if cam and cam.has_method("apply_shake"):
		cam.apply_shake(5.0)

	# 4. Uçan Görsel Metin (Floating Feedback)
	var parent_scene = get_parent()
	if parent_scene:
		var label = Label.new()
		label.text = "⚡ PERFECT BLOCK / PARRY! (0 Hasar)"
		label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.02, 1.0))
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_font_size_override("font_size", 13)
		label.global_position = global_position + Vector2(-95.0, -50.0)
		parent_scene.add_child(label)

		var tw = label.create_tween()
		if tw:
			tw.tween_property(label, "global_position:y", label.global_position.y - 30.0, 0.6)
			tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
			tw.tween_callback(label.queue_free)

## Başarılı Savunma Efekti (%80 Hasar Azaltımı)
func _trigger_block_hit(original_amount: int, reduced_amount: int) -> void:
	attack_blocked.emit(reduced_amount, original_amount)

	# Hafif gard geri itilme tepkisi
	velocity.x = -facing_dir * 70.0

	# Mavi Kalkan Parıltısı
	if visual_node:
		var orig_mod: Color = visual_node.modulate
		visual_node.modulate = Color(0.7, 1.4, 2.5, 1.0)
		if is_inside_tree() and get_tree():
			get_tree().create_timer(0.12, true, false, true).timeout.connect(func():
				if is_instance_valid(visual_node):
					visual_node.modulate = orig_mod
			)

	# Uçan Metin Bildirimi
	var parent_scene = get_parent()
	if parent_scene:
		var label = Label.new()
		label.text = "🛡️ BLOKLANDI! (-%%80) [-%d HP]" % reduced_amount
		label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.25, 1.0))
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_font_size_override("font_size", 12)
		label.global_position = global_position + Vector2(-75.0, -45.0)
		parent_scene.add_child(label)

		var tw = label.create_tween()
		if tw:
			tw.tween_property(label, "global_position:y", label.global_position.y - 26.0, 0.55)
			tw.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
			tw.tween_callback(label.queue_free)

func respawn() -> void:
	get_tree().reload_current_scene()


func _show_death_screen() -> void:
	var death_layer: CanvasLayer = CanvasLayer.new()
	death_layer.layer = 120
	add_child(death_layer)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.2, 0.02, 0.04, 0.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_layer.add_child(bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.add_theme_constant_override("separation", 8)
	vbox.modulate.a = 0.0
	death_layer.add_child(vbox)

	var title: Label = Label.new()
	title.text = "💀 YENİLDİN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.15, 0.2, 1.0))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var prompt: Label = Label.new()
	prompt.text = "[R] Tuşuna Basarak Bölümün Başından Yeniden Doğ"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.add_theme_font_size_override("font_size", 14)
	vbox.add_child(prompt)

	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(bg, "color:a", 0.45, 0.8)
	tw.tween_property(vbox, "modulate:a", 1.0, 0.6)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	is_attacking = false
	is_parry_active = false
	current_attack_type = ""
	velocity = Vector2.ZERO
	if anim_sprite and anim_sprite.sprite_frames.has_animation("death"):
		anim_sprite.play("death")
	player_died.emit()
	_show_death_screen()

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
			is_parry_active = false
			current_attack_type = ""
			if attack_area:
				attack_area.monitoring = false
	)

func _on_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		is_parry_active = false
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

	anim_sprite.speed_scale = 1.0

	# 0. Savunma / Blok Durumu (block_start -> block_loop veya gard duruşu)
	if is_defending:
		if anim_sprite.sprite_frames.has_animation("block_start") and block_timer < 0.15:
			_play(&"block_start")
		elif anim_sprite.sprite_frames.has_animation("block_loop"):
			_play(&"block_loop")
		else:
			_play(&"crouch")
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

## Görsel Efekt ve Geribildirim Fonksiyonları (VFX & Feedback)
func _spawn_dash_ghost() -> void:
	if not anim_sprite or not anim_sprite.sprite_frames:
		return
	var ghost := Sprite2D.new()
	if anim_sprite.sprite_frames.has_animation(anim_sprite.animation):
		ghost.texture = anim_sprite.sprite_frames.get_frame_texture(anim_sprite.animation, anim_sprite.frame)
	if not ghost.texture:
		ghost.queue_free()
		return
	ghost.global_position = anim_sprite.global_position
	ghost.scale = visual_node.scale * anim_sprite.scale
	ghost.modulate = Color(0.4, 0.85, 1.0, 0.65)
	ghost.z_index = z_index - 1
	var parent_scene: Node = get_parent()
	if parent_scene:
		parent_scene.add_child(ghost)
		var tw: Tween = ghost.create_tween()
		if tw:
			tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
			tw.tween_callback(ghost.queue_free)

func _spawn_jump_puff() -> void:
	var parent_scene: Node = get_parent()
	if not parent_scene:
		return
	var puff := Node2D.new()
	puff.global_position = global_position + Vector2(0.0, -4.0)
	parent_scene.add_child(puff)
	var circle := Line2D.new()
	circle.width = 2.0
	circle.default_color = Color(0.85, 0.95, 1.0, 0.8)
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(13):
		var a: float = float(i) * TAU / 12.0
		pts.append(Vector2(cos(a) * 14.0, sin(a) * 6.0))
	circle.points = pts
	puff.add_child(circle)
	var tw: Tween = puff.create_tween()
	if tw:
		tw.tween_property(puff, "scale", Vector2(1.8, 1.8), 0.22)
		tw.parallel().tween_property(circle, "modulate:a", 0.0, 0.22)
		tw.tween_callback(puff.queue_free)

func _spawn_dodge_text(text: String) -> void:
	var parent_scene: Node = get_parent()
	if not parent_scene:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.4, 0.95, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.25, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.global_position = global_position + Vector2(-40.0, -45.0)
	parent_scene.add_child(label)
	var tw: Tween = label.create_tween()
	if tw:
		tw.tween_property(label, "global_position:y", label.global_position.y - 25.0, 0.45)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 0.45)
		tw.tween_callback(label.queue_free)
