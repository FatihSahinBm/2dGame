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
var _atk_hit_from: int = -1
var _atk_hit_to: int = -1
var _atk_hit_on: bool = false
var _atk_event_frame: int = -1
var _atk_event_done: bool = false
var _atk_event: Callable
var _atk_cooldown_bonus: float = 0.0

@onready var smoke_vfx: AnimatedSprite2D = $Visual/SmokeVFX

func _ready() -> void:
	monster_name = "Kazıklı Voyvoda Vlad"
	max_health = 600
	current_health = 600
	speed = 46.0
	chase_speed = 52.0
	knockback_resistance = 0.85
	detection_range = 750.0
	attack_range = 70.0
	attack_cooldown = 1.4
	
	super._ready()
	
	if not is_in_group("boss"):
		add_to_group("boss")
		
	_find_camera()
	_apply_form_visuals()
	if anim_sprite:
		anim_sprite.frame_changed.connect(_on_attack_frame_changed)
		anim_sprite.animation_finished.connect(_on_attack_animation_finished)

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

	# Yürüme/koşma animasyon hızını yatay hızla birebir senkronize et (ayak kaymasını önler)
	if anim_sprite and current_state != State.ATTACK:
		if anim_sprite.animation == &"walk" or anim_sprite.animation == &"normal_walk":
			var target_scale: float = clampf(absf(velocity.x) / 48.0, 0.75, 1.25)
			anim_sprite.speed_scale = target_scale if absf(velocity.x) > 5.0 else 1.0
		elif anim_sprite.animation == &"werewolf_run":
			var target_scale: float = clampf(absf(velocity.x) / 140.0, 0.8, 1.25)
			anim_sprite.speed_scale = target_scale if absf(velocity.x) > 5.0 else 1.0
		else:
			anim_sprite.speed_scale = 1.0

func _process_attack(delta: float) -> void:
	if anim_sprite and anim_sprite.animation == &"werewolf_attack_leap":
		# Havadayken ileri momentumu koru; yalnızca yere inip darbeyi vurduktan sonra yavaşla
		if is_on_floor() and anim_sprite.frame > 50:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		return
	elif anim_sprite and anim_sprite.animation == &"bat_attack_dive":
		# Havadan dalış pike hızını koru
		velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)
		return

	super._process_attack(delta)

## -----------------------------------------------------------------------------
## Akıllı Platform & Tavan Engeli Yönetimi (Etrafından Dolanma / Flanking)
## -----------------------------------------------------------------------------
## Yukarıdaki oyuncuya ulaşırken başımızın üstünde platform engeli var mı?
func _is_blocked_by_platform_above() -> bool:
	if not _target_node or not is_instance_valid(_target_node):
		return false
	var dy: float = _target_node.global_position.y - global_position.y
	# Oyuncu bizden dikeyde belirgin şekilde yukarıda mı?
	if dy > -30.0:
		return false

	if is_on_ceiling():
		return true

	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0.0, -20.0),
		_target_node.global_position,
		1,
		[self.get_rid()]
	)
	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position.y < global_position.y or is_on_ceiling()
	return false

## Platformun altından açık gökyüzüne çıkmak için en yakın kenar yönünü bul
func _find_platform_bypass_direction() -> int:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var check_dist: float = 120.0
	var check_h: float = 130.0

	var right_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position + Vector2(check_dist, 0.0),
		global_position + Vector2(check_dist, -check_h),
		1,
		[self.get_rid()]
	)
	var left_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position + Vector2(-check_dist, 0.0),
		global_position + Vector2(-check_dist, -check_h),
		1,
		[self.get_rid()]
	)

	var right_hit: Dictionary = space_state.intersect_ray(right_query)
	var left_hit: Dictionary = space_state.intersect_ray(left_query)

	if right_hit.is_empty() and not left_hit.is_empty():
		return 1
	elif left_hit.is_empty() and not right_hit.is_empty():
		return -1

	if _target_node and is_instance_valid(_target_node):
		var target_dx: float = _target_node.global_position.x - global_position.x
		if absf(target_dx) > 10.0:
			return 1 if target_dx > 0.0 else -1

	return direction if direction != 0 else 1

## -----------------------------------------------------------------------------
## Yarasa Formu Özel 2D Uçuş Fiziği (Hızlı, Çevik ve Akıllı)
## -----------------------------------------------------------------------------
func _process_bat_flight(delta: float) -> void:
	if current_state == State.ATTACK:
		return

	_hover_altitude_timer += delta * 3.5
	var bobbing: float = sin(_hover_altitude_timer) * 16.0

	# Platform altındaysa tavanı zorlama; platformun kenarından açık havaya süzül
	if _is_blocked_by_platform_above():
		velocity.y = move_toward(velocity.y, 50.0, 600.0 * delta)
		var bypass_dir: int = _find_platform_bypass_direction()
		velocity.x = move_toward(velocity.x, float(bypass_dir) * chase_speed * 1.3, 900.0 * delta)
		if bypass_dir != direction:
			direction = bypass_dir
			_update_facing_direction()
		return

	if _target_node and is_instance_valid(_target_node):
		var target_y: float = _target_node.global_position.y - _preferred_flight_height + bobbing
		var dy: float = target_y - global_position.y
		var desired_vy: float = clampf(dy * 4.0, -260.0, 260.0)
		velocity.y = move_toward(velocity.y, desired_vy, 750.0 * delta)
	else:
		velocity.y = move_toward(velocity.y, bobbing * 2.5, 300.0 * delta)

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

	# Formuna uygun devriye animasyonunu garantiye al
	if current_form != VladForm.NORMAL:
		if _turn_pause_timer > 0.0:
			match current_form:
				VladForm.VAMPIRE: _play_form_anim(&"vampire_idle")
				VladForm.WEREWOLF: _play_form_anim(&"werewolf_idle")
				VladForm.BAT: _play_form_anim(&"bat_idle_fly")
		else:
			match current_form:
				VladForm.VAMPIRE: _play_form_anim(&"vampire_glide")
				VladForm.WEREWOLF: _play_form_anim(&"werewolf_run")
				VladForm.BAT: _play_form_anim(&"bat_idle_fly")

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
	# A) Oyuncu çok yakınsa (<= 42px) veya oyuncu havadan geliyorsa -> IMPALE ŞOKU!
	if (dist_x <= 42.0 and absf(diff_y) <= 35.0) or (dist_x <= 55.0 and diff_y < -30.0):
		if _attack_timer <= 0.0:
			_execute_normal_attack(false) # Impale
			return

	# B) Oyuncu gerçek mızrak menzilindeyse (<= 70px) -> SPEAR THRUST!
	if dist_x <= 70.0 and absf(diff_y) <= 35.0:
		if _attack_timer <= 0.0:
			_execute_normal_attack(true) # Thrust
			return
		else:
			# Yakın temastayken bekleme süresinde sakin bekle/dur
			velocity.x = move_toward(velocity.x, 0.0, 450.0 * delta)
			_play_form_anim(&"idle")
			return

	# C) Oyuncu uzaktaysa (> 70px) ASLA boşluğa vurma; mesafeyi kapatmak için kararlı yürü!
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
	# Eğer oyuncu yukarıdaki bir platformdaysa ve tam altındaysak kenara doğru koş
	if _is_blocked_by_platform_above():
		var bypass_dir: int = _find_platform_bypass_direction()
		velocity.x = float(bypass_dir) * chase_speed * 1.2
		_play_form_anim(&"werewolf_run")
		return

	# Yakın menzil (<= 80px) -> Seri Çift Pençe Kombosu
	if dist_x <= 80.0 and absf(diff_y) <= 45.0:
		if _attack_timer <= 0.0:
			_execute_werewolf_claws()
			return
		else:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			_play_form_anim(&"werewolf_idle")
			return

	# Sıçrama Menzili (90 - 360px): Oyuncu ister aynı hizada, ister yüksek platformda olsun fırla!
	if dist_x >= 90.0 and dist_x <= 360.0 and diff_y >= -160.0 and diff_y <= 60.0:
		if _attack_timer <= 0.0:
			_execute_werewolf_leap()
			return

	# Yüksek hızda depar
	velocity.x = float(direction) * chase_speed
	_play_form_anim(&"werewolf_run")

## 4. Yarasa Formu Taktiği (Hava Dalışı & Sonik Çığlık - Hızlı & Kararlı)
func _chase_bat_form(delta: float, dist: float, dist_x: float, diff_y: float) -> void:
	# Eğer platformun altındaysa uçuş mantığı kenardan dolanmayı yürütür
	if _is_blocked_by_platform_above():
		_play_form_anim(&"bat_idle_fly")
		return

	# Saldırı bekleme süresi bittiğinde hızlı ve kararlı saldırı kararı:
	if _attack_timer <= 0.0:
		# 1. Havadan Dalış (Dive): Menzildeyse doğrudan oyuncuya pike yap
		if dist <= 190.0 and diff_y >= -25.0:
			_execute_bat_dive()
			return

		# 2. Ultrasonik Çığlık (Screech): Orta menzilde oyuncuyu sersemletmek için çığlık at
		if dist >= 90.0 and dist <= 330.0:
			_execute_bat_screech()
			return

	# Havada oyuncuya doğru hızlı süzül
	velocity.x = move_toward(velocity.x, float(direction) * chase_speed, 900.0 * delta)
	_play_form_anim(&"bat_idle_fly")

## -----------------------------------------------------------------------------
## Saldırı Fonksiyonları (Forma Özel Eylemler)
## -----------------------------------------------------------------------------
## -----------------------------------------------------------------------------
## Saldiri Sistemi: hitbox/olay zamanlamasi animasyon karelerine baglidir,
## saldiri animasyon bitince sona erer (yarida kesilmez).
## -----------------------------------------------------------------------------
func _begin_attack(anim: StringName, damage: int, hit_from: int, hit_to: int, event_frame: int = -1, event: Callable = Callable(), cooldown_bonus: float = 0.0) -> void:
	current_state = State.ATTACK
	attack_damage = damage
	_atk_hit_from = hit_from
	_atk_hit_to = hit_to
	_atk_event_frame = event_frame
	_atk_event = event
	_atk_cooldown_bonus = cooldown_bonus
	_atk_hit_on = false
	_atk_event_done = false
	if anim_sprite:
		anim_sprite.play(anim)

func _on_attack_frame_changed() -> void:
	if current_state != State.ATTACK or is_dead or _is_transforming:
		return
	var f: int = anim_sprite.frame
	if _atk_hit_from >= 0 and not _atk_hit_on and f >= _atk_hit_from and f < _atk_hit_to:
		_atk_hit_on = true
		_activate_hitbox()
		_trigger_screen_shake(3.5)
	elif _atk_hit_on and f >= _atk_hit_to:
		_atk_hit_on = false
		_deactivate_hitbox()
	if _atk_event.is_valid() and not _atk_event_done and f >= _atk_event_frame:
		_atk_event_done = true
		_atk_event.call()

func _on_attack_animation_finished() -> void:
	if current_state != State.ATTACK or is_dead or _is_transforming:
		return
	if anim_sprite:
		anim_sprite.speed_scale = 1.0
	_atk_hit_on = false
	_deactivate_hitbox()
	_attack_timer = attack_cooldown + _atk_cooldown_bonus
	current_state = State.CHASE if _target_node else State.PATROL
	# Dalış saldırısı sonrasında yarasa yukarı çekilerek irtifa kazanır
	if current_form == VladForm.BAT:
		velocity.y = -220.0

func _execute_normal_attack(is_thrust: bool) -> void:
	velocity.x = 0.0
	if is_thrust:
		_begin_attack(&"attack_thrust", normal_thrust_damage, 46, 60)
	else:
		_begin_attack(&"attack_impale", normal_impale_damage, 38, 58)

func _execute_vampire_slash() -> void:
	velocity.x = 0.0
	_begin_attack(&"vampire_attack_slash", vampire_slash_damage, 44, 64)

func _execute_vampire_magic() -> void:
	velocity.x = 0.0
	_begin_attack(&"vampire_attack_blood_magic", vampire_magic_damage, -1, -1, 40, func():
		_spawn_blood_magic_projectile()
		_trigger_screen_shake(2.5)
	, 0.4)

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
		proj.modulate = Color(1.0, 0.25, 0.25, 1.0)
		proj.setup(spawn_pos, shoot_dir, self, vampire_magic_damage, _target_node)

func _execute_werewolf_claws() -> void:
	_begin_attack(&"werewolf_attack_claws", werewolf_claw_damage, 36, 108)
	velocity.x = float(direction) * 60.0

func _execute_werewolf_leap() -> void:
	velocity = Vector2.ZERO
	# Kurt adam sıçramasını çevik ve yırtıcı hale getirmek için animasyon hızını artır
	if anim_sprite:
		anim_sprite.speed_scale = 1.6

	# Hedefin yönü ve mesafesi
	var target_dx: float = float(direction) * 220.0
	var target_dy: float = 0.0
	if _target_node and is_instance_valid(_target_node):
		var to_tgt: Vector2 = _target_node.global_position - global_position
		target_dx = to_tgt.x
		target_dy = to_tgt.y
		var jump_dir: int = 1 if target_dx > 0 else -1
		if jump_dir != direction:
			direction = jump_dir
			_update_facing_direction()

	# Oyuncu platformdaysa (yukarıdaysa) çok daha güçlü sıçra (-560 vy)
	var jump_vy: float = -460.0
	if target_dy < -30.0:
		jump_vy = -560.0

	var jump_vx: float = clampf(target_dx * 1.4, -380.0, 380.0)
	if absf(jump_vx) < 160.0:
		jump_vx = float(direction) * 180.0

	# 22. karede yaylanıp fırlar, 65-105 arasında pençelerle yere çarpar
	_begin_attack(&"werewolf_attack_leap", werewolf_leap_damage, 65, 105, 22, func():
		velocity = Vector2(jump_vx, jump_vy)
		_trigger_screen_shake(3.0)
	, 0.3)

func _execute_bat_dive() -> void:
	velocity = Vector2.ZERO
	# Hedefe doğru açılı pike dalışı vektörü
	var dive_dir: Vector2 = Vector2(float(direction), 0.7).normalized()
	if _target_node and is_instance_valid(_target_node):
		dive_dir = (_target_node.global_position - global_position).normalized()
		if dive_dir.y < 0.2:
			dive_dir.y = 0.35
		dive_dir = dive_dir.normalized()

	_begin_attack(&"bat_attack_dive", bat_dive_damage, 35, 80, 20, func():
		velocity = dive_dir * 360.0
		_trigger_screen_shake(4.0)
	, 0.4)

func _execute_bat_screech() -> void:
	velocity = Vector2.ZERO
	_begin_attack(&"bat_attack_screech", bat_screech_damage, 65, 95, 55, func():
		_trigger_screen_shake(5.5)
		if _target_node and is_instance_valid(_target_node) and "velocity" in _target_node:
			var push_x: float = signf(_target_node.global_position.x - global_position.x)
			if is_zero_approx(push_x):
				push_x = float(direction)
			_target_node.velocity.x += push_x * 320.0
			_target_node.velocity.y = -180.0
	)

## -----------------------------------------------------------------------------
## Hasar Alma, Sis Kaçışı & Faz Dönüşümleri
## -----------------------------------------------------------------------------
func take_damage(amount: int) -> void:
	if is_dead:
		return

	# Vampir formunda taktiksel Sis Kaçışı (%35 şans)
	if current_form == VladForm.VAMPIRE and current_state != State.ATTACK and _mist_dash_cooldown <= 0.0 and randf() < 0.35:
		_execute_vampire_mist_dash()
		return

	var was_attacking: bool = current_state == State.ATTACK
	super.take_damage(amount)

	if is_dead:
		return

	if was_attacking:
		current_state = State.ATTACK

	# Can eşiklerine göre otomatik form dönüşümü
	var health_ratio: float = float(current_health) / float(max_health)
	if health_ratio <= form_phase_health_thresholds[2] and current_form != VladForm.BAT:
		set_form(VladForm.BAT, true)
	elif health_ratio <= form_phase_health_thresholds[1] and health_ratio > form_phase_health_thresholds[2] and current_form != VladForm.WEREWOLF:
		set_form(VladForm.WEREWOLF, true)
	elif health_ratio <= form_phase_health_thresholds[0] and health_ratio > form_phase_health_thresholds[1] and current_form != VladForm.VAMPIRE:
		set_form(VladForm.VAMPIRE, true)

func _play_hit_feedback() -> void:
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	if anim_sprite:
		anim_sprite.modulate = Color(2.5, 0.4, 0.4, 1.0)
		_hit_flash_tween = create_tween()
		_hit_flash_tween.tween_property(anim_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)

	# Saldırı sırasında animasyon kesilmez (hyper-armor), sadece kırmızı flaş
	if current_state == State.ATTACK:
		return

	if anim_sprite and anim_sprite.sprite_frames:
		match current_form:
			VladForm.NORMAL:
				if anim_sprite.sprite_frames.has_animation(&"hurt"):
					anim_sprite.play(&"hurt")
			VladForm.VAMPIRE:
				if anim_sprite.sprite_frames.has_animation(&"vampire_hurt"):
					anim_sprite.play(&"vampire_hurt")
			VladForm.WEREWOLF:
				if anim_sprite.sprite_frames.has_animation(&"werewolf_hurt"):
					anim_sprite.play(&"werewolf_hurt")
			VladForm.BAT:
				if anim_sprite.sprite_frames.has_animation(&"bat_hurt"):
					anim_sprite.play(&"bat_hurt")

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
	_atk_hit_on = false

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
			speed = 46.0
			chase_speed = 52.0
			attack_range = 70.0
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
			chase_speed = 160.0
			attack_range = 85.0
			attack_damage = werewolf_claw_damage
			_play_form_anim(&"werewolf_idle")
		VladForm.BAT:
			is_flying = true
			speed = 110.0
			chase_speed = 210.0
			attack_range = 140.0
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

	var ui_node: Node2D = get_node_or_null("UI") as Node2D
	if ui_node:
		var ui_tween: Tween = create_tween()
		ui_tween.tween_property(ui_node, "modulate:a", 0.0, 0.4)
	elif health_bar:
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
		death_tween.tween_interval(1.25)
		death_tween.tween_callback(func():
			if smoke_vfx:
				smoke_vfx.visible = false
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
