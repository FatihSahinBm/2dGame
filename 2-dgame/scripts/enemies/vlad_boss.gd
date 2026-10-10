extends "res://scripts/enemies/monster_enemy.gd"

## =============================================================================
## Vlad the Impaler - Üst Düzey Bağımsız Boss Yapay Zekası (Autonomous Boss AI)
## =============================================================================
## Bu script, Vlad karakterini oyuncu tarafından kontrol EDİLMEYEN, tamamen kendi
## taktiksel kararlarını veren, 4 farklı forma sahip efsanevi bir boss haline getirir.
##
## Formlar:
## 1. Normal Form (Voivode): Mızrak itişi, ağır impale şok dalgası, zemin tutuşu.
## 2. Vampir Formu (Vampire Lord): Süzülme, geniş kan savurması, takip eden kan büyüsü, sis kaçışı.
## 3. Kurt Adam Formu (Lycan Beast): Seri 3 vuruşlu pençe kombosu, yüksek hız, havadan sıçrama.
## 4. Yarasa Formu (Monstrous Bat): 2D havada süzülme, hava dalış saldırısı, ultrasonik kan çığlığı.
##
## Mimari Kurallar:
## - 18_vlad_death/README.md: Herhangi bir formda can 0 olunca duman patlar, 42. karede
##   Voyvoda formuna döner ve 18_vlad_death ile küllere ve yarasalara dağılır.
## - Evrensel Çıpa: (640, 680) zemin çizgisi y=680; scale 0.25x ile zemin kusursuz oturur.
## =============================================================================

enum VladForm { NORMAL, VAMPIRE, WEREWOLF, BAT }

@export_group("Vlad Boss Profile")
@export var current_form: VladForm = VladForm.NORMAL
@export var form_phase_health_thresholds: Array[float] = [0.75, 0.50, 0.25]
@export var screen_shake_intensity: float = 6.0
@export var projectile_scene: PackedScene = preload("res://scenes/projectiles/dark_magic_projectile.tscn")

@export_group("Form Combat Stats")
@export var normal_thrust_damage: int = 35
@export var normal_impale_damage: int = 50
@export var vampire_slash_damage: int = 40
@export var vampire_magic_damage: int = 45
@export var werewolf_claw_damage: int = 30
@export var werewolf_leap_damage: int = 55
@export var bat_dive_damage: int = 42
@export var bat_screech_damage: int = 35

# Taktiksel Durum Değişkenleri
var _camera_ref: Camera2D = null
var _is_transforming: bool = false
var _is_leaping: bool = false
var _leap_target_x: float = 0.0
var _mist_dash_cooldown: float = 0.0
var _hover_altitude_timer: float = 0.0
var _preferred_flight_height: float = 90.0

@onready var smoke_vfx: AnimatedSprite2D = $Visual/SmokeVFX

func _ready() -> void:
	monster_name = "Kazıklı Voyvoda Vlad"
	max_health = 600
	current_health = 600
	speed = 50.0
	chase_speed = 85.0
	knockback_resistance = 0.85
	detection_range = 750.0
	attack_range = 95.0
	attack_cooldown = 1.4
	
	super._ready()
	
	if not is_in_group("boss"):
		add_to_group("boss")
		
	_find_camera()
	_apply_form_visuals()

func _find_camera() -> void:
	var viewport = get_viewport()
	if viewport:
		_camera_ref = viewport.get_camera_2d()

## -----------------------------------------------------------------------------
## Fizik ve Yapay Zeka Döngüsü (_physics_process)
## -----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if is_dead:
		if not is_flying and not is_on_floor():
			velocity.y += gravity * delta
			move_and_slide()
		return

	if _is_transforming:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		if not is_flying:
			velocity.y += gravity * delta
		move_and_slide()
		return

	if _mist_dash_cooldown > 0.0:
		_mist_dash_cooldown -= delta

	# Yarasa Uçuş Mekaniği (Gravity bypass)
	if current_form == VladForm.BAT:
		_process_bat_flight(delta)
	else:
		# Yer formları için standart yerçekimi
		if not is_on_floor():
			velocity.y += gravity * delta

	super._physics_process(delta)

## -----------------------------------------------------------------------------
## Yarasa Formu Özel 2D Uçuş Fiziği
## -----------------------------------------------------------------------------
func _process_bat_flight(delta: float) -> void:
	if current_state == State.ATTACK:
		return

	_hover_altitude_timer += delta * 2.5
	var bobbing: float = sin(_hover_altitude_timer) * 15.0

	if _target_node and is_instance_valid(_target_node):
		var target_y: float = _target_node.global_position.y - _preferred_flight_height + bobbing
		velocity.y = move_toward(velocity.y, (target_y - global_position.y) * 2.5, 300.0 * delta)
	else:
		velocity.y = move_toward(velocity.y, bobbing * 2.0, 150.0 * delta)

## -----------------------------------------------------------------------------
## -----------------------------------------------------------------------------
## Proaktif Hedef Arama (Oyuncu menzildeyse doğrudan hedefle)
## -----------------------------------------------------------------------------
func _acquire_target() -> Node2D:
	if _target_node and is_instance_valid(_target_node):
		return _target_node

	if detection_area:
		var bodies = detection_area.get_overlapping_bodies()
		for b in bodies:
			if b != self and b.is_in_group("player"):
				_target_node = b
				return _target_node

	var players = get_tree().get_nodes_in_group("player")
	var closest_player: Node2D = null
	var closest_dist: float = INF
	for p in players:
		if p is Node2D and is_instance_valid(p):
			var d = global_position.distance_to(p.global_position)
			if d < closest_dist and d <= detection_range:
				closest_dist = d
				closest_player = p
	if closest_player:
		_target_node = closest_player
		return _target_node
	return null

## -----------------------------------------------------------------------------
## Devriye Süreci (_process_patrol)
## -----------------------------------------------------------------------------
func _process_patrol(delta: float) -> void:
	if not _target_node or not is_instance_valid(_target_node):
		_acquire_target()

	if _target_node and is_instance_valid(_target_node):
		var dist = global_position.distance_to(_target_node.global_position)
		if dist <= detection_range:
			current_state = State.CHASE
			return

	super._process_patrol(delta)

## -----------------------------------------------------------------------------
## Hedef Takibi & Gelişmiş Taktiksel Kovalama (_process_chase)
## -----------------------------------------------------------------------------
func _process_chase(delta: float) -> void:
	if not _target_node or not is_instance_valid(_target_node):
		_target_node = _acquire_target()
		if not _target_node:
			current_state = State.PATROL
			return

	var to_target: Vector2 = _target_node.global_position - global_position
	var dist: float = to_target.length()
	var dist_x: float = absf(to_target.x)
	var diff_y: float = to_target.y

	# Oyuncu çok uzaklaşırsa devriyeye dön
	if dist > detection_range * 1.5:
		_target_node = null
		current_state = State.PATROL
		return

	# Hedefe dön
	var target_dir: int = 1 if to_target.x > 0 else -1
	if target_dir != direction and current_state != State.ATTACK:
		direction = target_dir
		_update_facing_direction()

	# --- FORMA ÖZEL TAKTİKSEL KARAR MEKANİZMASI ---
	match current_form:
		VladForm.NORMAL:
			_chase_normal_form(delta, dist, dist_x, diff_y)
		VladForm.VAMPIRE:
			_chase_vampire_form(delta, dist, dist_x, diff_y)
		VladForm.WEREWOLF:
			_chase_werewolf_form(delta, dist, dist_x, diff_y)
		VladForm.BAT:
			_chase_bat_form(delta, dist, dist_x, diff_y)

## 1. Normal Form Taktiği (Mızrak Menzili Yönetimi)
func _chase_normal_form(delta: float, dist: float, dist_x: float, diff_y: float) -> void:
	# Oyuncu çok yakınsa (< 75px) veya oyuncu havadan geliyorsa -> IMPALE ŞOKU!
	if (dist_x <= 75.0 and absf(diff_y) <= 45.0) or (dist_x <= 95.0 and diff_y < -35.0):
		if _attack_timer <= 0.0:
			_execute_normal_attack(false) # Impale
			return

	# Oyuncu orta mızrak menzilindeyse (75 - 150px) -> SPEAR THRUST!
	if dist_x <= 150.0 and absf(diff_y) <= 45.0:
		if _attack_timer <= 0.0:
			_execute_normal_attack(true) # Thrust
			return
		else:
			# Mızrak bekleme süresindeyken sakin adım
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			_play_form_anim(&"idle")
			return

	# Mesafeyi kapatmak için kararlı yürüyüş
	velocity.x = float(direction) * chase_speed
	_play_form_anim(&"walk")

## 2. Vampir Formu Taktiği (Süzülme, Kan Büyüsü, Sis Kaçışı)
func _chase_vampire_form(delta: float, dist: float, dist_x: float, diff_y: float) -> void:
	# Yakın menzil (<= 110px) -> Kan savurması (Slash)
	if dist_x <= 110.0 and absf(diff_y) <= 50.0:
		if _attack_timer <= 0.0:
			_execute_vampire_slash()
			return
		else:
			velocity.x = move_toward(velocity.x, 0.0, 450.0 * delta)
			_play_form_anim(&"vampire_idle")
			return

	# Uzak/Orta Menzil (150 - 450px) -> Kan Büyüsü Dalgası
	if dist >= 150.0 and dist <= 450.0:
		if _attack_timer <= 0.0:
			_execute_vampire_magic()
			return

	# Süzülerek yaklaş
	velocity.x = float(direction) * chase_speed
	_play_form_anim(&"vampire_glide")

## 3. Kurt Adam Formu Taktiği (Yırtıcı Kovalamaca & Sıçrama)
func _chase_werewolf_form(delta: float, dist: float, dist_x: float, diff_y: float) -> void:
	# Yakın menzil (<= 85px) -> Seri Çift Pençe Kombosu
	if dist_x <= 85.0 and absf(diff_y) <= 45.0:
		if _attack_timer <= 0.0:
			_execute_werewolf_claws()
			return

	# Uzak menzil (140 - 320px) -> Havadan Pençe Sıçraması (Leap)
	if dist_x >= 140.0 and dist_x <= 320.0 and absf(diff_y) <= 80.0:
		if _attack_timer <= 0.0 and randf() > 0.4:
			_execute_werewolf_leap()
			return

	# Yüksek hızda depar
	velocity.x = float(direction) * chase_speed
	_play_form_anim(&"werewolf_run")

## 4. Yarasa Formu Taktiği (Hava Dalışı & Sonik Çığlık)
func _chase_bat_form(delta: float, dist: float, dist_x: float, diff_y: float) -> void:
	# Yatayda hizalanmışsa ve menzildeyse (<= 130px) -> Havadan Dalış (Dive)
	if dist_x <= 130.0 and diff_y > 40.0:
		if _attack_timer <= 0.0:
			_execute_bat_dive()
			return

	# Orta menzilde (120 - 350px) -> Ultrasonik Kan Çığlığı (Screech)
	if dist >= 120.0 and dist <= 350.0:
		if _attack_timer <= 0.0 and randf() > 0.5:
			_execute_bat_screech()
			return

	# Havada oyuncunun üstüne doğru süzül
	velocity.x = float(direction) * chase_speed
	_play_form_anim(&"bat_idle_fly")

## -----------------------------------------------------------------------------
## Saldırı Fonksiyonları (Forma Özel Eylemler)
## -----------------------------------------------------------------------------
func _execute_normal_attack(is_thrust: bool) -> void:
	current_state = State.ATTACK
	velocity.x = 0.0
	
	var anim_name: StringName = &"attack_thrust" if is_thrust else &"attack_impale"
	attack_damage = normal_thrust_damage if is_thrust else normal_impale_damage
	var windup: float = 0.60 if is_thrust else 0.95
	var active: float = 0.35 if is_thrust else 0.45
	var recovery: float = 0.45 if is_thrust else 0.65

	if anim_sprite: anim_sprite.play(anim_name)

	var tween: Tween = create_tween()
	tween.tween_interval(windup)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_activate_hitbox()
			_trigger_screen_shake(2.5 if is_thrust else 5.0)
	)
	tween.tween_interval(active)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_deactivate_hitbox()
	)
	tween.tween_interval(recovery)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_attack_timer = attack_cooldown
			current_state = State.CHASE if _target_node else State.PATROL
	)

func _execute_vampire_slash() -> void:
	current_state = State.ATTACK
	velocity.x = 0.0
	attack_damage = vampire_slash_damage
	if anim_sprite: anim_sprite.play(&"vampire_attack_slash")

	var tween: Tween = create_tween()
	tween.tween_interval(0.70)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_activate_hitbox()
			_trigger_screen_shake(3.5)
	)
	tween.tween_interval(0.35)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_deactivate_hitbox()
	)
	tween.tween_interval(0.50)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_attack_timer = attack_cooldown
			current_state = State.CHASE if _target_node else State.PATROL
	)

func _execute_vampire_magic() -> void:
	current_state = State.ATTACK
	velocity.x = 0.0
	if anim_sprite: anim_sprite.play(&"vampire_attack_blood_magic")

	var tween: Tween = create_tween()
	tween.tween_interval(0.80)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_spawn_blood_magic_projectile()
			_trigger_screen_shake(2.5)
	)
	tween.tween_interval(0.70)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_attack_timer = attack_cooldown + 0.4
			current_state = State.CHASE if _target_node else State.PATROL
	)

func _spawn_blood_magic_projectile() -> void:
	if not projectile_scene:
		return
	var proj = projectile_scene.instantiate()
	if not proj:
		return
		
	var spawn_pos: Vector2 = global_position + Vector2(35.0 * float(direction), -55.0)
	var shoot_dir: Vector2 = Vector2(float(direction), 0.0)
	
	if _target_node and is_instance_valid(_target_node):
		shoot_dir = (_target_node.global_position + Vector2(0, -20.0) - spawn_pos).normalized()

	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(proj)
		# Kan büyüsü için kızıl renk tonu ver
		proj.modulate = Color(1.0, 0.25, 0.25, 1.0)
		proj.setup(spawn_pos, shoot_dir, self, vampire_magic_damage, _target_node)

func _execute_werewolf_claws() -> void:
	current_state = State.ATTACK
	attack_damage = werewolf_claw_damage
	if anim_sprite: anim_sprite.play(&"werewolf_attack_claws")

	# İleri doğru kısa adım atarak parçalar
	velocity.x = float(direction) * 60.0

	var tween: Tween = create_tween()
	tween.tween_interval(0.40)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_activate_hitbox()
			_trigger_screen_shake(2.5)
	)
	tween.tween_interval(0.55)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_deactivate_hitbox()
	)
	tween.tween_interval(0.35)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_attack_timer = attack_cooldown * 0.7
			current_state = State.CHASE if _target_node else State.PATROL
	)

func _execute_werewolf_leap() -> void:
	current_state = State.ATTACK
	attack_damage = werewolf_leap_damage
	if anim_sprite: anim_sprite.play(&"werewolf_attack_leap")

	# Havaya fırla
	velocity.y = -350.0
	velocity.x = float(direction) * 220.0

	var tween: Tween = create_tween()
	tween.tween_interval(0.65) # Havalanma zirvesi
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_activate_hitbox()
			_trigger_screen_shake(6.0)
	)
	tween.tween_interval(0.40)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_deactivate_hitbox()
	)
	tween.tween_interval(0.45)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_attack_timer = attack_cooldown + 0.3
			current_state = State.CHASE if _target_node else State.PATROL
	)

func _execute_bat_dive() -> void:
	current_state = State.ATTACK
	attack_damage = bat_dive_damage
	if anim_sprite: anim_sprite.play(&"bat_attack_dive")

	# Aşağı oyuncuya doğru pike yap
	velocity = Vector2(float(direction) * 240.0, 200.0)

	var tween: Tween = create_tween()
	tween.tween_interval(0.55)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_activate_hitbox()
			_trigger_screen_shake(4.0)
	)
	tween.tween_interval(0.35)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_deactivate_hitbox()
			# Dalıştan sonra yukarı çekil
			velocity.y = -220.0
	)
	tween.tween_interval(0.50)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_attack_timer = attack_cooldown
			current_state = State.CHASE if _target_node else State.PATROL
	)

func _execute_bat_screech() -> void:
	current_state = State.ATTACK
	velocity = Vector2.ZERO
	attack_damage = bat_screech_damage
	if anim_sprite: anim_sprite.play(&"bat_attack_screech")

	var tween: Tween = create_tween()
	tween.tween_interval(0.70)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_activate_hitbox()
			_trigger_screen_shake(5.5)
			# Yakındaki oyuncuyu geriye savur
			if _target_node and is_instance_valid(_target_node):
				var push_dir = signf(_target_node.global_position.x - global_position.x)
				if "velocity" in _target_node:
					_target_node.velocity.x += push_dir * 300.0
					_target_node.velocity.y = -180.0
	)
	tween.tween_interval(0.40)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_deactivate_hitbox()
	)
	tween.tween_interval(0.40)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_attack_timer = attack_cooldown
			current_state = State.CHASE if _target_node else State.PATROL
	)

## -----------------------------------------------------------------------------
## Hasar Alma, Sis Kaçışı & Faz Dönüşümleri
## -----------------------------------------------------------------------------
func take_damage(amount: int) -> void:
	if is_dead:
		return

	# Vampir formunda taktiksel Sis Kaçışı (%35 şans)
	if current_form == VladForm.VAMPIRE and _mist_dash_cooldown <= 0.0 and randf() < 0.35:
		_execute_vampire_mist_dash()
		return

	super.take_damage(amount)

	if is_dead:
		return

	# Can eşiklerine göre otomatik form dönüşümü
	var health_ratio: float = float(current_health) / float(max_health)
	if health_ratio <= form_phase_health_thresholds[2] and current_form != VladForm.BAT:
		set_form(VladForm.BAT, true)
	elif health_ratio <= form_phase_health_thresholds[1] and health_ratio > form_phase_health_thresholds[2] and current_form != VladForm.WEREWOLF:
		set_form(VladForm.WEREWOLF, true)
	elif health_ratio <= form_phase_health_thresholds[0] and health_ratio > form_phase_health_thresholds[1] and current_form != VladForm.VAMPIRE:
		set_form(VladForm.VAMPIRE, true)

func _execute_vampire_mist_dash() -> void:
	_mist_dash_cooldown = 3.5
	if smoke_vfx:
		smoke_vfx.visible = true
		smoke_vfx.play(&"vfx_blood_smoke_burst")
	
	# Oyuncunun arkasına veya geriye sis olarak kay
	var dash_dir: float = -float(direction)
	if _target_node and is_instance_valid(_target_node):
		dash_dir = signf(global_position.x - _target_node.global_position.x)
	velocity.x = dash_dir * 320.0
	
	var tween: Tween = create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(func():
		if smoke_vfx: smoke_vfx.visible = false
	)

## -----------------------------------------------------------------------------
## Form Yönetimi & 18_vlad_death Multi-Form Ölüm Mimarisi
## -----------------------------------------------------------------------------
func set_form(new_form: VladForm, play_smoke: bool = true) -> void:
	if current_form == new_form and not play_smoke:
		return

	if play_smoke:
		_perform_form_transformation(new_form)
	else:
		current_form = new_form
		_apply_form_visuals()

func _perform_form_transformation(new_form: VladForm) -> void:
	if _is_transforming or is_dead:
		return

	_is_transforming = true
	velocity = Vector2.ZERO
	_deactivate_hitbox()

	if smoke_vfx:
		smoke_vfx.visible = true
		smoke_vfx.play(&"vfx_blood_smoke_burst")

	_trigger_screen_shake(4.5)

	# 72 kare @ 24 fps = 3.0s. 42. karede (%100 tam örtücülük) form değişir.
	var tween: Tween = create_tween()
	tween.tween_interval(1.75)
	tween.tween_callback(func():
		current_form = new_form
		_apply_form_visuals()
	)
	tween.tween_interval(1.25)
	tween.tween_callback(func():
		if smoke_vfx:
			smoke_vfx.visible = false
		_is_transforming = false
		current_state = State.CHASE if _target_node else State.PATROL
	)

func _apply_form_visuals() -> void:
	match current_form:
		VladForm.NORMAL:
			is_flying = false
			speed = 50.0
			chase_speed = 85.0
			attack_range = 95.0
			attack_damage = normal_thrust_damage
			_play_form_anim(&"idle")
		VladForm.VAMPIRE:
			is_flying = false
			speed = 65.0
			chase_speed = 105.0
			attack_range = 110.0
			attack_damage = vampire_slash_damage
			_play_form_anim(&"vampire_idle")
		VladForm.WEREWOLF:
			is_flying = false
			speed = 95.0
			chase_speed = 150.0
			attack_range = 85.0
			attack_damage = werewolf_claw_damage
			_play_form_anim(&"werewolf_idle")
		VladForm.BAT:
			is_flying = true
			speed = 85.0
			chase_speed = 130.0
			attack_range = 120.0
			attack_damage = bat_dive_damage
			_play_form_anim(&"bat_idle_fly")

func _play_form_anim(anim_name: StringName) -> void:
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
		anim_sprite.play(anim_name)

func _update_facing_direction() -> void:
	if not is_inside_tree():
		return
	if anim_sprite:
		anim_sprite.flip_h = (direction < 0)
	if smoke_vfx:
		smoke_vfx.flip_h = (direction < 0)
	if hitbox_area:
		hitbox_area.position.x = 50.0 * float(direction)
	if ledge_ray:
		ledge_ray.position.x = 25.0 * float(direction)
		ledge_ray.force_raycast_update()

## 💀 18_vlad_death Multi-Form Defeat Mimarisi
func _die() -> void:
	if is_dead:
		return

	is_dead = true
	current_state = State.DEAD
	velocity = Vector2.ZERO
	_deactivate_hitbox()

	enemy_died.emit(self)

	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, true)

	if hurtbox_area:
		hurtbox_area.monitoring = false
		hurtbox_area.monitorable = false

	if health_bar:
		var bar_tween: Tween = create_tween()
		bar_tween.tween_property(health_bar, "modulate:a", 0.0, 0.3)

	_trigger_screen_shake(7.0)

	# Form hangisi olursa olsun duman patlar ve insana döner
	if current_form != VladForm.NORMAL:
		if smoke_vfx:
			smoke_vfx.visible = true
			smoke_vfx.play(&"vfx_blood_smoke_burst")

		var death_tween: Tween = create_tween()
		death_tween.tween_interval(1.75) # 42. karede (%100 örtücülük) normal voyvodaya dönüş
		death_tween.tween_callback(func():
			current_form = VladForm.NORMAL
			is_flying = false
			if anim_sprite:
				anim_sprite.play(&"death")
		)
	else:
		if anim_sprite:
			anim_sprite.play(&"death")

func _trigger_screen_shake(intensity: float) -> void:
	if not _camera_ref:
		_find_camera()
	if _camera_ref:
		var cam_tween: Tween = create_tween()
		var orig = _camera_ref.offset
		cam_tween.tween_property(_camera_ref, "offset", orig + Vector2(0, intensity), 0.05)
		cam_tween.tween_property(_camera_ref, "offset", orig + Vector2(0, -intensity * 0.7), 0.06)
		cam_tween.tween_property(_camera_ref, "offset", orig, 0.08)

func debug_set_form(form_idx: int) -> void:
	set_form(form_idx as VladForm, true)
