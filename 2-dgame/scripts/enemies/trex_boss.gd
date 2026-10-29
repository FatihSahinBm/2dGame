extends "res://scripts/enemies/monster_enemy.gd"

## ==============================================================================
## CYBER T-REX BOSS (SİBER MECHA-TYRANT)
## ==============================================================================
## Devasa Mecha-Dinozor Boss Sınıfı.
## - intro_taunt: Giriş kükremesi ve sarsıntı
## - idle / walk / run: Mesafeye göre dinamik yaklaşma ve hücum
## - attack_bite: Yıkıcı yakın dövüş çift çene ısırığı
## - attack_platform_slam: Yer sarsıcı platform / zemin darbesi
## - attack_laser: Ağızdan yıkıcı siber enerji ışını
## - grab_counter: Karşı saldırı / kapma manevrası
## - stunned_groggy: Duruş kırılması (Stagger) sersemleme
## - hurt / death: Siber patlamalar ve epik yıkılış
## ==============================================================================

signal phase_changed(new_phase: int)
signal boss_staggered()

@export_group("Cyber Boss Features")
@export var screen_shake_intensity: float = 8.5
@export var boss_phase: int = 1 # 1: Standart, 2: Overdrive, 3: Meltdown
@export var stagger_threshold: int = 150
@export var groggy_duration: float = 2.4

# Hitbox referansları
@onready var laser_hitbox: Area2D = get_node_or_null("Visual/LaserHitbox")
@onready var slam_hitbox: Area2D = get_node_or_null("Visual/SlamHitbox")
@onready var phase_label: Label = get_node_or_null("UI/PhaseLabel")

var _camera_ref: Camera2D = null
var _current_stagger: int = 0
var _stagger_reset_timer: float = 0.0
var _intro_played: bool = false
var _is_performing_special: bool = false
var _laser_cooldown: float = 4.0
var _slam_cooldown: float = 3.0
var _special_attack_type: String = ""

func _ready() -> void:
	super._ready()
	_find_camera()
	_init_extra_hitboxes()
	
	# Boss özellikleri
	monster_name = "SİBER T-REX: MECHA-TYRANT"
	turn_at_ledges = false
	knockback_resistance = 0.95 # Devasa boss neredeyse itilmez

func _init_extra_hitboxes() -> void:
	if laser_hitbox:
		laser_hitbox.monitoring = false
		if not laser_hitbox.body_entered.is_connected(_on_laser_hitbox_body_entered):
			laser_hitbox.body_entered.connect(_on_laser_hitbox_body_entered)
	if slam_hitbox:
		slam_hitbox.monitoring = false
		if not slam_hitbox.body_entered.is_connected(_on_slam_hitbox_body_entered):
			slam_hitbox.body_entered.connect(_on_slam_hitbox_body_entered)

func _find_camera() -> void:
	var viewport = get_viewport()
	if viewport:
		_camera_ref = viewport.get_camera_2d()

func _update_facing_direction() -> void:
	super._update_facing_direction()
	if hitbox_area:
		hitbox_area.position.x = 140.0 * float(direction)
	if laser_hitbox:
		laser_hitbox.position.x = 260.0 * float(direction)
	if slam_hitbox:
		slam_hitbox.position.x = 70.0 * float(direction)
	if ledge_ray and is_inside_tree():
		ledge_ray.position.x = 60.0 * float(direction)
		ledge_ray.force_raycast_update()

func _physics_process(delta: float) -> void:
	if is_dead:
		super._physics_process(delta)
		return

	# Cooldown sayaçları
	if _laser_cooldown > 0.0:
		_laser_cooldown -= delta
	if _slam_cooldown > 0.0:
		_slam_cooldown -= delta
	if _stagger_reset_timer > 0.0:
		_stagger_reset_timer -= delta
		if _stagger_reset_timer <= 0.0:
			_current_stagger = 0

	# Intro Taunt kontrolü
	if not _intro_played and _can_see_target():
		_play_intro_taunt()
		return

	super._physics_process(delta)

## Devriye durumunda yürüme ve bekleme animasyonları
func _process_patrol(delta: float) -> void:
	if _can_see_target():
		current_state = State.CHASE
		return

	# Dönüş duraklaması
	if _turn_pause_timer > 0.0:
		_turn_pause_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		if anim_sprite and current_state == State.PATROL:
			anim_sprite.play(&"idle")
		return

	# Duvar kontrolü
	if turn_at_walls and is_on_wall():
		_turn_around()
		return

	# Platform uçurum kontrolü
	if not is_flying and turn_at_ledges and is_on_floor():
		if ledge_ray and not ledge_ray.is_colliding():
			_turn_around()
			return

	velocity.x = move_toward(velocity.x, float(direction) * speed, 400.0 * delta)
	if anim_sprite and current_state == State.PATROL:
		anim_sprite.play(&"walk")

## Oyuncuyu takip ederken hız ve animasyon seçimi (Yürüme vs Koşma)
func _process_chase(delta: float) -> void:
	if not _target_node or not is_instance_valid(_target_node):
		_target_node = null
		current_state = State.PATROL
		return

	var to_target: Vector2 = _target_node.global_position - global_position
	var dist: float = to_target.length()

	# Menzilden çıkma kontrolü
	if dist > detection_range * 1.5:
		_target_node = null
		current_state = State.PATROL
		return

	# Yön güncelle
	var target_dir: int = 1 if to_target.x > 0 else -1
	if target_dir != direction:
		direction = target_dir
		_update_facing_direction()

	# Saldırı menzili kontrolü
	if dist <= attack_range:
		if _attack_timer <= 0.0:
			_start_attack()
		else:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if anim_sprite and current_state == State.CHASE:
				anim_sprite.play(&"idle")
		return

	# Uzaksa koş (run), orta mesafede yürü (walk)
	var active_speed = chase_speed
	var anim_name = &"walk"

	if dist > 220.0 or boss_phase >= 3:
		active_speed = chase_speed * 1.35
		anim_name = &"run"

	velocity.x = move_toward(velocity.x, float(direction) * active_speed, 500.0 * delta)

	if anim_sprite and current_state == State.CHASE:
		anim_sprite.play(anim_name)

## Saldırı kararı: Mesafe ve faza göre en uygun saldırıyı seçer
func _start_attack() -> void:
	current_state = State.ATTACK
	velocity.x = 0.0

	var dist: float = 0.0
	if _target_node and is_instance_valid(_target_node):
		dist = global_position.distance_to(_target_node.global_position)

	# Faza ve mesafeye göre saldırı seçimi
	if boss_phase >= 2 and dist > 200.0 and _laser_cooldown <= 0.0:
		_start_laser_attack()
	elif dist > 110.0 and _slam_cooldown <= 0.0:
		_start_platform_slam_attack()
	elif randf() < 0.25 and boss_phase >= 2:
		_start_grab_counter_attack()
	else:
		_start_bite_attack()

## 1. YAKIN DÖVÜŞ: ÇİFT ISIRIK KOMBO (attack_bite)
func _start_bite_attack() -> void:
	_special_attack_type = "bite"
	if anim_sprite:
		anim_sprite.play(&"attack_bite")

	var tween: Tween = create_tween()
	# Frame 6-8: İlk kapma hamlesi (0.6s)
	tween.tween_interval(0.6)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_activate_hitbox()
			_shake_camera(3.0)
	)
	# Frame 12: İkinci ısırık darbesi (0.4s)
	tween.tween_interval(0.4)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_shake_camera(4.5)
	)
	tween.tween_interval(0.4)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_deactivate_hitbox()
	)
	# Toplam 2.0s toparlanma
	tween.tween_interval(0.6)
	tween.tween_callback(_finish_attack)

## 2. ZEMİN VE PLATFORM SARSINTISI: YER DARBESİ (attack_platform_slam)
func _start_platform_slam_attack() -> void:
	_special_attack_type = "slam"
	_slam_cooldown = 4.5 if boss_phase == 1 else 3.0
	if anim_sprite:
		anim_sprite.play(&"attack_platform_slam")

	var tween: Tween = create_tween()
	# Frame 0-9: Zıplama / havaya kalkma (0.9s)
	tween.tween_interval(0.9)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			if slam_hitbox:
				slam_hitbox.monitoring = true
			_trigger_ground_slam_impact()
	)
	tween.tween_interval(0.4)
	tween.tween_callback(func():
		if slam_hitbox:
			slam_hitbox.monitoring = false
	)
	tween.tween_interval(0.7)
	tween.tween_callback(_finish_attack)

## 3. SİBER AĞIZ LAZERİ: ENERJİ IŞINI (attack_laser)
func _start_laser_attack() -> void:
	_special_attack_type = "laser"
	_laser_cooldown = 6.0 if boss_phase == 2 else 4.0
	if anim_sprite:
		anim_sprite.play(&"attack_laser")

	# Şarj aşaması ve hafif parıldama
	var charge_tween = create_tween()
	charge_tween.tween_property(anim_sprite, "modulate", Color(1.2, 2.0, 2.5, 1.0), 0.5)
	charge_tween.tween_property(anim_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

	var tween: Tween = create_tween()
	# Frame 6: Lazer ateşleme anı (0.6s)
	tween.tween_interval(0.6)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			if laser_hitbox:
				laser_hitbox.monitoring = true
			_shake_camera(screen_shake_intensity * 0.9)
	)
	# Lazer akışı süresi (0.9s)
	tween.tween_interval(0.9)
	tween.tween_callback(func():
		if laser_hitbox:
			laser_hitbox.monitoring = false
	)
	tween.tween_interval(0.5)
	tween.tween_callback(_finish_attack)

## 4. KAPMA VE KARŞI SALDIRI (grab_counter)
func _start_grab_counter_attack() -> void:
	_special_attack_type = "grab"
	if anim_sprite:
		anim_sprite.play(&"grab_counter")

	var tween: Tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_activate_hitbox()
			_shake_camera(4.0)
	)
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		_deactivate_hitbox()
	)
	tween.tween_interval(1.0)
	tween.tween_callback(_finish_attack)

func _finish_attack() -> void:
	if current_state == State.ATTACK and not is_dead:
		_deactivate_hitbox()
		if laser_hitbox:
			laser_hitbox.monitoring = false
		if slam_hitbox:
			slam_hitbox.monitoring = false

		_attack_timer = attack_cooldown * (0.8 if boss_phase >= 2 else 1.0)
		current_state = State.CHASE if _target_node else State.PATROL

## Giriş Gösterisi (Intro Taunt)
func _play_intro_taunt() -> void:
	_intro_played = true
	current_state = State.ATTACK
	velocity.x = 0.0

	if anim_sprite:
		anim_sprite.play(&"intro_taunt")

	# Kükreme anında ekran sarsıntısı
	var tween: Tween = create_tween()
	tween.tween_interval(0.7)
	tween.tween_callback(func():
		_shake_camera(screen_shake_intensity * 1.2)
	)
	tween.tween_interval(1.3)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			current_state = State.CHASE if _target_node else State.PATROL
	)

## Hasar Alma ve Stagger Sistemi
func take_damage(amount: int) -> void:
	if is_dead:
		return

	super.take_damage(amount)

	# Stagger (Duruş Bozulması) birikimi
	_current_stagger += amount
	_stagger_reset_timer = 3.5

	if _current_stagger >= stagger_threshold and current_state != State.GROGGY and not is_dead:
		_enter_groggy_state()

	# Faz kontrolü
	_check_phase_transition()

func _enter_groggy_state() -> void:
	_current_stagger = 0
	current_state = State.GROGGY
	velocity.x = 0.0
	_deactivate_hitbox()
	if laser_hitbox:
		laser_hitbox.monitoring = false
	if slam_hitbox:
		slam_hitbox.monitoring = false

	boss_staggered.emit()

	if anim_sprite:
		anim_sprite.play(&"stunned_groggy")

	# Groggy süresi
	var tween: Tween = create_tween()
	tween.tween_interval(groggy_duration)
	tween.tween_callback(func():
		if current_state == State.GROGGY and not is_dead:
			current_state = State.CHASE if _target_node else State.PATROL
			_attack_timer = 0.5
	)

func _check_phase_transition() -> void:
	var hp_ratio = float(current_health) / float(max_health)
	var new_phase = 1

	if hp_ratio <= 0.30:
		new_phase = 3
	elif hp_ratio <= 0.60:
		new_phase = 2

	if new_phase != boss_phase:
		boss_phase = new_phase
		phase_changed.emit(boss_phase)
		_on_phase_changed(boss_phase)

func _on_phase_changed(phase: int) -> void:
	if phase_label:
		if phase == 2:
			phase_label.text = "[ FAZ 2: OVERDRIVE ]"
			phase_label.modulate = Color(1.0, 0.6, 0.1, 1.0)
		elif phase == 3:
			phase_label.text = "[ FAZ 3: SİBER ERİME ]"
			phase_label.modulate = Color(1.0, 0.1, 0.1, 1.0)

	# Faz geçişinde görsel parıltı ve şok
	_shake_camera(7.0)
	if anim_sprite:
		var ft = create_tween()
		var aura_col = Color(1.5, 0.5, 0.2, 1.0) if phase == 2 else Color(2.5, 0.2, 0.2, 1.0)
		ft.tween_property(anim_sprite, "modulate", aura_col, 0.2)
		ft.tween_property(anim_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

## Çevre Etkileri ve Sarsıntı
func _trigger_ground_slam_impact() -> void:
	_shake_camera(screen_shake_intensity)

	# Yakındaki oyuncuyu fırlat
	if _target_node and is_instance_valid(_target_node):
		var dist = global_position.distance_to(_target_node.global_position)
		if dist < attack_range * 2.5 and "velocity" in _target_node:
			var push_dir = signf(_target_node.global_position.x - global_position.x)
			if is_zero_approx(push_dir):
				push_dir = float(direction)
			_target_node.velocity.y = -220.0
			_target_node.velocity.x += push_dir * 200.0

func _shake_camera(intensity: float) -> void:
	if not _camera_ref:
		_find_camera()
	if _camera_ref:
		if _camera_ref.has_method("apply_shake"):
			_camera_ref.apply_shake(intensity, 2, 0.25, 25.0, "trex_action")
		else:
			var ct: Tween = create_tween()
			var orig = _camera_ref.offset
			ct.tween_property(_camera_ref, "offset", orig + Vector2(0, intensity), 0.05)
			ct.tween_property(_camera_ref, "offset", orig + Vector2(0, -intensity * 0.7), 0.05)
			ct.tween_property(_camera_ref, "offset", orig + Vector2(intensity * 0.4, 0), 0.05)
			ct.tween_property(_camera_ref, "offset", orig, 0.08)

## Özel Hitbox Vuruş Olayları
func _on_laser_hitbox_body_entered(body: Node2D) -> void:
	if is_dead or body == self:
		return
	if body.has_method("take_damage"):
		body.take_damage(int(attack_damage * 1.4))
		attack_hit.emit(body)

	if "velocity" in body:
		body.velocity += Vector2(float(direction) * 350.0, -160.0)

func _on_slam_hitbox_body_entered(body: Node2D) -> void:
	if is_dead or body == self:
		return
	if body.has_method("take_damage"):
		body.take_damage(int(attack_damage * 1.2))
		attack_hit.emit(body)

	if "velocity" in body:
		body.velocity += Vector2(float(direction) * 260.0, -280.0)

## Ölüm (Death)
func _die() -> void:
	if is_dead:
		return
	is_dead = true
	current_state = State.DEAD
	_deactivate_hitbox()
	if laser_hitbox:
		laser_hitbox.monitoring = false
	if slam_hitbox:
		slam_hitbox.monitoring = false

	enemy_died.emit(self)

	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)

	if hurtbox_area:
		hurtbox_area.monitoring = false
		hurtbox_area.monitorable = false

	if health_bar:
		var bar_tween: Tween = create_tween()
		bar_tween.tween_property(health_bar, "modulate:a", 0.0, 0.3)
	if phase_label:
		phase_label.visible = false

	_shake_camera(9.0)

	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(&"death"):
		anim_sprite.play(&"death")
		get_tree().create_timer(3.2).timeout.connect(_fade_and_free)
	else:
		_fade_and_free()
