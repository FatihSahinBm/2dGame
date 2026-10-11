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
@export var ground_dust_scene: PackedScene = preload("res://scenes/effects/vlad_ground_dust.tscn")

@export_group("Form Combat Stats")
@export var normal_thrust_damage: int = 35
@export var normal_impale_damage: int = 50
@export var vampire_slash_damage: int = 40
@export var vampire_magic_damage: int = 45
@export var werewolf_claw_damage: int = 30
@export var werewolf_leap_damage: int = 55
@export var bat_dive_damage: int = 42
@export var bat_screech_damage: int = 35

signal groggy_started()
signal groggy_recovered()

@export_group("Stun & Groggy Mechanics")
@export var groggy_damage_threshold: int = 160
@export var groggy_duration: float = 1.4
@export var groggy_vulnerability_multiplier: float = 1.35

# Taktiksel Durum Değişkenleri
var _camera_ref: Camera2D = null
var _is_transforming: bool = false
var _is_leaping: bool = false
var _leap_start_pos: Vector2 = Vector2.ZERO
var _leap_target_pos: Vector2 = Vector2.ZERO
var _leap_elapsed: float = 0.0
var _leap_duration: float = 1.15
var _bypass_target_side: int = 0
var _mist_dash_cooldown: float = 0.0
var _hover_altitude_timer: float = 0.0
var _preferred_flight_height: float = 135.0
var _bat_standoff_dir: int = 1
var _bat_standoff_dist: float = 210.0
var _bat_flank_timer: float = 4.0
var _bat_dive_dir: Vector2 = Vector2.ZERO
var _hit_targets_this_attack: Array[Node2D] = []
var _atk_hit_from: int = -1
var _atk_hit_to: int = -1
var _atk_hit_on: bool = false
var _atk_event_frame: int = -1
var _atk_event_done: bool = false
var _atk_event: Callable
var _atk_cooldown_bonus: float = 0.0

# Sersemleme (Groggy) Değişkenleri
var _stagger_damage: int = 0
var _stagger_decay_timer: float = 0.0
var _groggy_timer: float = 0.0
var _groggy_flash_tween: Tween = null

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

	# Stagger hasarı zamanla kendiliğinden sönümlenir (decay)
	if current_state != State.GROGGY and _stagger_damage > 0:
		if _stagger_decay_timer > 0.0:
			_stagger_decay_timer -= delta
		else:
			_stagger_damage = maxi(0, _stagger_damage - int(45.0 * delta))

	# Yarasa Uçuş Mekaniği (Gravity bypass)
	if current_form == VladForm.BAT and current_state != State.GROGGY:
		_process_bat_flight(delta)

	super._physics_process(delta)

	# Yürüme/koşma animasyon hızını yatay hızla birebir senkronize et (ayak kaymasını ve sürüklenmeyi önler)
	if anim_sprite and current_state != State.ATTACK and current_state != State.GROGGY:
		if anim_sprite.animation == &"walk" or anim_sprite.animation == &"normal_walk":
			# 18 karelik animasyon, 52px adım mesafesi: tam adımlama oranı
			var target_scale: float = clampf(absf(velocity.x) / 44.0, 0.7, 1.3)
			anim_sprite.speed_scale = target_scale if absf(velocity.x) > 3.0 else 1.0
		elif anim_sprite.animation == &"vampire_glide":
			var target_scale: float = clampf(absf(velocity.x) / 90.0, 0.75, 1.25)
			anim_sprite.speed_scale = target_scale if absf(velocity.x) > 3.0 else 1.0
		elif anim_sprite.animation == &"werewolf_run":
			var target_scale: float = clampf(absf(velocity.x) / 145.0, 0.8, 1.35)
			anim_sprite.speed_scale = target_scale if absf(velocity.x) > 5.0 else 1.0
		else:
			anim_sprite.speed_scale = 1.0

func _process_attack(delta: float) -> void:
	if anim_sprite and anim_sprite.animation == &"werewolf_attack_leap":
		var f: int = anim_sprite.frame
		if f < 6:
			# 1. Yerde sıçrama hazırlığı (crouch charge - f 0..5):
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			_leap_start_pos = global_position
			_leap_elapsed = 0.0
			if _target_node and is_instance_valid(_target_node):
				var tgt_x: float = _target_node.global_position.x
				var max_dist: float = 480.0
				var diff_x: float = tgt_x - _leap_start_pos.x
				if absf(diff_x) > max_dist:
					tgt_x = _leap_start_pos.x + signf(diff_x) * max_dist
				_leap_target_pos = Vector2(tgt_x, _target_node.global_position.y)
		elif f >= 6 and f < 15:
			# 2. Havada tam parabolik uçuş (Airborne Parabolic Leap - f 6..14):
			_is_leaping = true
			floor_snap_length = 0.0
			var progress_f: float = float(f - 6) + anim_sprite.frame_progress
			var t: float = clampf(progress_f / 9.0, 0.0, 1.0)

			var dx: float = absf(_leap_target_pos.x - _leap_start_pos.x)
			var dy_target: float = _leap_target_pos.y - _leap_start_pos.y
			var base_arc: float = clampf(dx * 0.45, 140.0, 240.0)
			if dy_target < -20.0:
				base_arc = maxf(base_arc, 0.5 * absf(dy_target) + 90.0)

			# Parabol eğrisi: t=0 -> 0, t=0.5 (apex) -> -base_arc, t=1.0 -> 0
			var arc_y: float = -4.0 * base_arc * t * (1.0 - t)

			var desired_x: float = lerp(_leap_start_pos.x, _leap_target_pos.x, t)
			var desired_y: float = lerp(_leap_start_pos.y, _leap_target_pos.y, t) + arc_y
			var target_point := Vector2(desired_x, desired_y)

			velocity = (target_point - global_position) / delta
		else:
			# 3. Yere iniş ve darbe sonrası toparlanma (Impact slam & Recovery - f 15..23):
			_is_leaping = false
			floor_snap_length = 4.0
			velocity.x = move_toward(velocity.x, 0.0, 950.0 * delta)
		return
	elif anim_sprite and anim_sprite.animation == &"bat_attack_dive":
		var f: int = anim_sprite.frame
		if f < 8:
			# 1. Rüzgar toplama & Görsel Telgraf Hazırlığı (f 0..7 - Oyuncunun net görmesi için sakin hazırlık):
			velocity.x = move_toward(velocity.x, -float(direction) * 55.0, 400.0 * delta)
			velocity.y = move_toward(velocity.y, -110.0, 450.0 * delta)
		elif f >= 8 and f < 17:
			# 2. Okunaklı ve yırtıcı pike dalışı (f 8..16 - Dengeli ve net 380 px/sn):
			velocity = _bat_dive_dir * 380.0
		else:
			# 3. Teğet geçip karşı tarafa yükselme (f 17..23):
			if velocity.y > -60.0:
				velocity.y = -200.0
			velocity.x = move_toward(velocity.x, float(direction) * 260.0, 600.0 * delta)
			velocity.y = move_toward(velocity.y, -260.0, 750.0 * delta)
		return
	elif anim_sprite and anim_sprite.animation == &"bat_attack_screech":
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		velocity.y = move_toward(velocity.y, 0.0, 600.0 * delta)
		return

	super._process_attack(delta)

## -----------------------------------------------------------------------------
## Akıllı Platform & Tavan Engeli Yönetimi (Etrafından Dolanma / Flanking)
## -----------------------------------------------------------------------------
## Her form için geçerli engeli etrafından dolanma ve açık gökyüzü tespit sistemi
func _get_obstacle_bypass_data() -> Dictionary:
	var result = {
		"is_blocked": false,
		"is_horizontally_clear": true,
		"bypass_x": global_position.x,
		"bypass_dir": direction,
		"obstacle_top_y": global_position.y - 120.0,
		"obstacle_bottom_y": global_position.y - 40.0,
		"obstacle_left_x": global_position.x,
		"obstacle_right_x": global_position.x
	}

	if not _target_node or not is_instance_valid(_target_node) or not is_inside_tree() or not get_world_2d():
		_bypass_target_side = 0
		return result

	# Duvara veya köşeye temas kontrolü: Duvardan daima açık alana doğru kaç
	if is_on_wall():
		var wall_norm: Vector2 = get_wall_normal()
		if wall_norm.x != 0.0:
			_bypass_target_side = int(signf(wall_norm.x))
			result["is_blocked"] = true
			result["is_horizontally_clear"] = false
			result["bypass_x"] = global_position.x + float(_bypass_target_side) * 120.0
			result["bypass_dir"] = _bypass_target_side
			return result

	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var my_pos: Vector2 = global_position
	var target_pos: Vector2 = _target_node.global_position
	var dy: float = target_pos.y - my_pos.y

	# 1. Doğrudan hedefe giden görüş hattında engel var mı?
	var direct_query := PhysicsRayQueryParameters2D.create(
		my_pos + Vector2(0.0, -25.0),
		target_pos + Vector2(0.0, -10.0),
		1,
		[self.get_rid()]
	)
	var direct_hit: Dictionary = space_state.intersect_ray(direct_query)

	# 2. Ayrıca oyuncu bizden yukarıdaysa doğrudan başımızın üstünde platform/tavan var mı?
	var up_hit: Dictionary = {}
	if dy < -30.0:
		var up_query := PhysicsRayQueryParameters2D.create(
			my_pos + Vector2(0.0, -10.0),
			Vector2(my_pos.x, target_pos.y - 20.0),
			1,
			[self.get_rid()]
		)
		up_hit = space_state.intersect_ray(up_query)

	var hit: Dictionary = up_hit if not up_hit.is_empty() else direct_hit
	if hit.is_empty():
		_bypass_target_side = 0
		return result

	var col_node = hit.collider

	# Engelin geometrik sınırlarını tespit et
	var obs_center_x: float = hit.position.x
	var obs_half_w: float = 120.0
	var obs_top_y: float = hit.position.y
	var obs_bottom_y: float = hit.position.y

	if col_node:
		for child in col_node.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				obs_center_x = child.global_position.x
				obs_half_w = child.shape.size.x * 0.5
				obs_top_y = child.global_position.y - child.shape.size.y * 0.5
				obs_bottom_y = child.global_position.y + child.shape.size.y * 0.5
				break

	var obs_left: float = obs_center_x - obs_half_w
	var obs_right: float = obs_center_x + obs_half_w

	result["obstacle_top_y"] = obs_top_y
	result["obstacle_bottom_y"] = obs_bottom_y
	result["obstacle_left_x"] = obs_left
	result["obstacle_right_x"] = obs_right

	# Eğer Vlad zaten bu platformun üst seviyesindeyse (veya üstündeyse) engel sayılmaz:
	if my_pos.y <= obs_top_y + 15.0:
		_bypass_target_side = 0
		result["is_blocked"] = false
		result["is_horizontally_clear"] = true
		return result

	# Platform kenarlarından 50 px dışarıdaki açık alan koordinatları (sahne sınırları 55 - 1090)
	var left_clear_x: float = clampf(obs_left - 50.0, 55.0, 1090.0)
	var right_clear_x: float = clampf(obs_right + 50.0, 55.0, 1090.0)

	# Vlad yatayda platformun dışında mı? (Açık gökyüzü sütunu)
	var is_clear_left: bool = my_pos.x <= obs_left - 20.0
	var is_clear_right: bool = my_pos.x >= obs_right + 20.0
	var is_horizontally_clear: bool = is_clear_left or is_clear_right

	result["is_blocked"] = true
	result["is_horizontally_clear"] = is_horizontally_clear

	if is_horizontally_clear:
		# Vlad zaten platformun dışında açık alanda!
		# İçeri platforma doğru ASLA geri dönmemeli!
		if is_clear_left:
			_bypass_target_side = -1
			result["bypass_x"] = left_clear_x
			result["bypass_dir"] = -1
		else:
			_bypass_target_side = 1
			result["bypass_x"] = right_clear_x
			result["bypass_dir"] = 1
		return result

	# Vlad platformun altında (dikey izdüşümünde):
	# Kararlı yön seçimi (Jitter önleme): açık alana çıkana kadar yönü kilitle
	var chosen_x: float = left_clear_x
	if _bypass_target_side == 1:
		chosen_x = right_clear_x
	elif _bypass_target_side == -1:
		chosen_x = left_clear_x
	else:
		var d_left: float = absf(my_pos.x - left_clear_x)
		var d_right: float = absf(my_pos.x - right_clear_x)
		if d_right < d_left:
			chosen_x = right_clear_x
			_bypass_target_side = 1
		else:
			chosen_x = left_clear_x
			_bypass_target_side = -1

	result["bypass_x"] = chosen_x
	result["bypass_dir"] = _bypass_target_side
	return result

## Geriye dönük uyumluluk için yön sorgusu
func _find_platform_bypass_direction() -> int:
	var bypass: Dictionary = _get_obstacle_bypass_data()
	return bypass.bypass_dir

## -----------------------------------------------------------------------------
## Yarasa Formu Özel 2D Uçuş Fiziği (Hızlı, Çevik ve Akıllı Dolanma)
## -----------------------------------------------------------------------------
func _process_bat_flight(delta: float) -> void:
	if current_state == State.ATTACK:
		return

	# Duvara ve Köşeye Sıkışma Çözümü (Corner Escape Flight):
	if is_on_wall():
		var wall_norm: Vector2 = get_wall_normal()
		if wall_norm.x != 0.0:
			_bat_standoff_dir = int(signf(wall_norm.x))
			_bypass_target_side = _bat_standoff_dir
			direction = _bat_standoff_dir
			_update_facing_direction()
			# Duvardan yukarı doğru güçlü kanat çırparak ve açık alana fırlayarak köşeden kurtul:
			velocity.y = move_toward(velocity.y, -340.0, 1100.0 * delta)
			velocity.x = move_toward(velocity.x, wall_norm.x * chase_speed * 1.5, 1100.0 * delta)
			return

	_hover_altitude_timer += delta * 3.5
	var bobbing: float = sin(_hover_altitude_timer) * 12.0

	var bypass: Dictionary = _get_obstacle_bypass_data()
	if bypass.is_blocked:
		var bypass_dir: int = bypass.bypass_dir
		var is_clear: bool = bypass.is_horizontally_clear

		if not is_clear:
			# Platform altındayız: Platform kenarındaki açık gökyüzüne doğru HIZLA uç!
			velocity.x = move_toward(velocity.x, float(bypass_dir) * chase_speed * 1.45, 1100.0 * delta)
			if bypass_dir != direction:
				direction = bypass_dir
				_update_facing_direction()

			# Dikey kontrol: Tavana çok yakınsak güvenli mesafede dur, uzaktaysak tavana doğru yaklaş
			var safe_ceiling_y: float = bypass.obstacle_bottom_y + 40.0
			var dy_to_safe: float = safe_ceiling_y - global_position.y
			if global_position.y > safe_ceiling_y:
				velocity.y = move_toward(velocity.y, clampf(dy_to_safe * 4.0, -280.0, 0.0), 800.0 * delta)
			else:
				velocity.y = move_toward(velocity.y, bobbing * 2.0, 600.0 * delta)
		else:
			# Platform kenarını geçtik: AÇIK GÖKYÜZÜ!
			# Platform köşesine çarpmamak için dışarıda kalmayı sürdürerek HIZLA YUKARI YÜKSEL!
			if global_position.y > bypass.obstacle_top_y - 25.0:
				velocity.y = move_toward(velocity.y, -360.0, 1100.0 * delta)
				# Açık alanda güvenli mesafede kal
				velocity.x = move_toward(velocity.x, float(bypass_dir) * 60.0, 700.0 * delta)
			else:
				# Platformun üstündeyiz! Artık doğrudan hedefe doğru uçabiliriz
				_bypass_target_side = 0
		return

	# Platform engeli yok: Çevik ve taktiksel hava süzülmesi (Kafaya konmayı kesinlikle önler)
	_bypass_target_side = 0
	if _target_node and is_instance_valid(_target_node):
		var target_pos: Vector2 = _target_node.global_position

		# 1. Taktiksel Çapraz Hava Konumu (Diagonal Air Standoff - 210px yana, 135px yukarı)
		var desired_x: float = target_pos.x + float(_bat_standoff_dir) * _bat_standoff_dist
		var target_y: float = target_pos.y - _preferred_flight_height + bobbing

		# 2. Anti-Head-Hover: Oyuncu yarasanın hemen altına veya dibine girerse açı alarak geri/yukarı süzül
		var dx_to_player: float = absf(global_position.x - target_pos.x)
		if dx_to_player < 85.0 and global_position.y < target_pos.y:
			desired_x = target_pos.x + float(_bat_standoff_dir) * maxf(_bat_standoff_dist, 175.0)
			target_y = minf(target_y, target_pos.y - 150.0)

		var diff_x: float = desired_x - global_position.x
		var diff_y: float = target_y - global_position.y

		velocity.x = move_toward(velocity.x, clampf(diff_x * 3.8, -chase_speed * 1.35, chase_speed * 1.35), 950.0 * delta)
		velocity.y = move_toward(velocity.y, clampf(diff_y * 3.8, -290.0, 290.0), 850.0 * delta)

		# Havada oyuncuya doğru dönük ol
		var look_dir: int = 1 if target_pos.x > global_position.x else -1
		if look_dir != direction and current_state != State.ATTACK:
			direction = look_dir
			_update_facing_direction()
	else:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
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

## 1. Normal Form Taktiği (Mızrak Menzili Yönetimi & Akıllı Konumlanma)
func _chase_normal_form(delta: float, dist: float, dist_x: float, diff_y: float) -> void:
	var bypass: Dictionary = _get_obstacle_bypass_data()

	# Eğer oyuncu yukarıdaki platformdaysa ve başımızın üstü kapalıysa kenara doğru dolan
	if bypass.is_blocked and diff_y < -40.0:
		if not bypass.is_horizontally_clear:
			velocity.x = move_toward(velocity.x, float(bypass.bypass_dir) * chase_speed, 450.0 * delta)
			_play_form_anim(&"walk")
			return
		else:
			# Açık alana çıktı: oyuncu platform kenarına yakınsa zemin impale şoku yapar
			if dist_x <= 95.0 and _attack_timer <= 0.0:
				_execute_normal_attack(false) # Impale
				return

	# A) Oyuncu yakınsa (<= 45px) ve aynı zemin seviyesindeyse -> IMPALE ŞOKU!
	# (Veya duvara sıkışmışsak oyuncuyu geri savurmak için impale patlaması yap)
	if (dist_x <= 45.0 and absf(diff_y) <= 35.0) or (is_on_wall() and dist_x <= 110.0):
		if _attack_timer <= 0.0:
			_execute_normal_attack(false) # Impale
			return

	# B) Oyuncu gerçek mızrak menzilindeyse (<= 75px) ve aynı düzlemdeyse -> SPEAR THRUST!
	if dist_x <= 75.0 and absf(diff_y) <= 35.0:
		if _attack_timer <= 0.0:
			_execute_normal_attack(true) # Thrust
			return
		else:
			# Yakın temastayken bekleme süresinde sakin bekle/dur
			velocity.x = move_toward(velocity.x, 0.0, 450.0 * delta)
			_play_form_anim(&"idle")
			return

	# C) Mesafeyi kapatmak için kararlı yürü!
	velocity.x = move_toward(velocity.x, float(direction) * chase_speed, 450.0 * delta)
	_play_form_anim(&"walk")

## 2. Vampir Formu Taktiği (Süzülme, Kan Büyüsü, Sis Kaçışı)
func _chase_vampire_form(delta: float, dist: float, dist_x: float, diff_y: float) -> void:
	var bypass: Dictionary = _get_obstacle_bypass_data()

	# Duvara sıkışmışsa sis olarak oyuncunun arkasına kay
	if is_on_wall() and dist_x <= 130.0 and _mist_dash_cooldown <= 0.0:
		_execute_vampire_mist_dash()
		return

	# Eğer başımızın üstü kapalıysa kenara doğru süzül
	if bypass.is_blocked and diff_y < -40.0:
		if not bypass.is_horizontally_clear:
			velocity.x = move_toward(velocity.x, float(bypass.bypass_dir) * chase_speed * 1.2, 500.0 * delta)
			_play_form_anim(&"vampire_glide")
			return
		else:
			# Açık alana çıktı: Oyuncuya takip eden Kan Büyüsü fırlat!
			if _attack_timer <= 0.0:
				_execute_vampire_magic()
				return

	# Oyuncu yukarıdaysa veya orta/uzak menzildeyse: Takip eden Kan Büyüsü fırlat!
	if (dist >= 120.0 and dist <= 550.0) or diff_y < -40.0:
		if _attack_timer <= 0.0:
			_execute_vampire_magic()
			return

	# Yakın menzil (<= 110px) -> Kan savurması (Slash)
	if dist_x <= 110.0 and absf(diff_y) <= 45.0:
		if _attack_timer <= 0.0:
			_execute_vampire_slash()
			return
		else:
			velocity.x = move_toward(velocity.x, 0.0, 450.0 * delta)
			_play_form_anim(&"vampire_idle")
			return

	# Süzülerek yaklaş (Vampir lordu süzülüşü / yürüyüşü)
	velocity.x = move_toward(velocity.x, float(direction) * chase_speed, 450.0 * delta)
	_play_form_anim(&"vampire_glide")

## 3. Kurt Adam Formu Taktiği (Yırtıcı Kovalamaca & Parabolik Sıçrama)
func _chase_werewolf_form(delta: float, dist: float, dist_x: float, diff_y: float) -> void:
	var bypass: Dictionary = _get_obstacle_bypass_data()

	# 1. Eğer oyuncu üst platformdaysa ve doğrudan tavan altındaysak kenara doğru koş
	if bypass.is_blocked and diff_y < -35.0:
		if not bypass.is_horizontally_clear:
			velocity.x = move_toward(velocity.x, float(bypass.bypass_dir) * chase_speed * 1.35, 650.0 * delta)
			_play_form_anim(&"werewolf_run")
			return
		else:
			# Platform kenarındaki açık alandayız! Doğrudan oyuncunun platformuna PARABOLİK ZIPLA!
			if _attack_timer <= 0.0:
				_execute_werewolf_leap()
				return

	# 2. Yakın pençe menzili (aynı düzlemde)
	if dist_x <= 85.0 and absf(diff_y) <= 45.0 and not is_on_wall():
		if _attack_timer <= 0.0:
			_execute_werewolf_claws()
			return
		else:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			_play_form_anim(&"werewolf_idle")
			return

	# 3. YIRTICI PARABOLİK SIÇRAMA:
	# Oyuncu ister aynı hizada (75-550px), ister yüksek platformda olsun ya da duvara sıkışmış olalım:
	# Doğrudan oyuncunun üstüne havada devasa bir parabol çizerek atla!
	if (dist_x >= 75.0 and dist_x <= 550.0) or diff_y < -35.0 or (is_on_wall() and dist_x < 130.0):
		if _attack_timer <= 0.0:
			_execute_werewolf_leap()
			return

	# 4. Yüksek hızda depar
	velocity.x = move_toward(velocity.x, float(direction) * chase_speed, 650.0 * delta)
	_play_form_anim(&"werewolf_run")

## 4. Yarasa Formu Taktiği (Hava Dalışı & Sonik Çığlık - Hızlı & Kararlı)
func _chase_bat_form(delta: float, dist: float, dist_x: float, diff_y: float) -> void:
	# Eğer platformun altındaysa uçuş fiziği zaten kenardan açık gökyüzüne doğru yönlendirir
	var bypass: Dictionary = _get_obstacle_bypass_data()
	if bypass.is_blocked:
		_play_form_anim(&"bat_idle_fly")
		return

	# Taraf değiştirme zamanlayıcısı (Havada tek noktada sabit kalmaz, süzülerek taraf değiştirir)
	_bat_flank_timer -= delta
	if _bat_flank_timer <= 0.0:
		_bat_flank_timer = randf_range(3.2, 5.5)
		_bat_standoff_dir = -_bat_standoff_dir

	# Saldırı bekleme süresi bittiğinde taktiksel hava saldırısı:
	if _attack_timer <= 0.0:
		# Oyuncunun tam tepesindeyken (kafasında) dikey çırpınmak yerine kanada açıl veya çığlık at
		if dist_x < 80.0:
			if randf() < 0.6:
				_execute_bat_screech()
				return
			# Aksi halde açı kazanmak için kanada süzülmeye devam eder
			_play_form_anim(&"bat_idle_fly")
			return

		# 1. Uzak/Orta Mesafe (180..450px): Ultrasonik Çığlık (Screech)
		if dist >= 180.0 and dist <= 450.0 and randf() < 0.4:
			_execute_bat_screech()
			return

		# 2. Çapraz Pike Dalışı (Predatory Swoop Dive): Taktiksel çapraz menzildeyse oyuncuya hızla dalar
		if dist <= 400.0:
			_execute_bat_dive()
			return

	_play_form_anim(&"bat_idle_fly")

## -----------------------------------------------------------------------------
## Saldırı Fonksiyonları (Forma Özel Eylemler)
## -----------------------------------------------------------------------------
## -----------------------------------------------------------------------------
## Saldiri Sistemi: hitbox/olay zamanlamasi animasyon karelerine baglidir,
## saldiri animasyon bitince sona erer (yarida kesilmez).
## -----------------------------------------------------------------------------
func _begin_attack(anim: StringName, damage: int, hit_from: int, hit_to: int, event_frame: int = -1, event: Callable = Callable(), cooldown_bonus: float = 0.0, anim_speed: float = 1.0) -> void:
	current_state = State.ATTACK
	attack_damage = damage
	_atk_hit_from = hit_from
	_atk_hit_to = hit_to
	_atk_event_frame = event_frame
	_atk_event = event
	_atk_cooldown_bonus = cooldown_bonus
	_atk_hit_on = false
	_atk_event_done = false
	_hit_targets_this_attack.clear()
	if anim_sprite:
		anim_sprite.play(anim)
		anim_sprite.speed_scale = anim_speed

func _activate_hitbox() -> void:
	super._activate_hitbox()
	if hitbox_area and not is_dead:
		for b in hitbox_area.get_overlapping_bodies():
			if b != self and (b.is_in_group("player") or b.has_method("take_damage")):
				_on_hitbox_body_entered(b)

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
	_is_leaping = false
	floor_snap_length = 4.0
	if anim_sprite:
		anim_sprite.speed_scale = 1.0
	_atk_hit_on = false
	_deactivate_hitbox()
	_reset_hitbox()
	_attack_timer = attack_cooldown + _atk_cooldown_bonus
	current_state = State.CHASE if _target_node else State.PATROL
	# Dalış saldırısı sonrasında yarasa yukarı çekilerek irtifa kazanır ve karşı kanada geçer
	if current_form == VladForm.BAT:
		velocity.y = -260.0
		velocity.x = float(direction) * 150.0
		_bat_standoff_dir = -_bat_standoff_dir

func _set_attack_hitbox(shape_size: Vector2, local_pos: Vector2) -> void:
	if hitbox_area:
		hitbox_area.position = local_pos
		var col = hitbox_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col and col.shape is RectangleShape2D:
			if not col.shape.resource_local_to_scene:
				col.shape = col.shape.duplicate()
			(col.shape as RectangleShape2D).size = shape_size

func _reset_hitbox() -> void:
	if current_form == VladForm.BAT:
		_set_attack_hitbox(Vector2(80, 65), Vector2(10.0 * float(direction), -20.0))
	else:
		_set_attack_hitbox(Vector2(55, 48), Vector2(50.0 * float(direction), -34.0))

func _spawn_ground_impact_dust(offset_x: float) -> void:
	if not ground_dust_scene:
		return
	var dust = ground_dust_scene.instantiate()
	if not dust:
		return

	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(dust)
		dust.global_position = Vector2(global_position.x + offset_x, global_position.y)

	_trigger_screen_shake(5.2)

func _execute_normal_attack(is_thrust: bool) -> void:
	velocity.x = 0.0
	if is_thrust:
		_set_attack_hitbox(Vector2(55, 48), Vector2(50.0 * float(direction), -34.0))
		# 20 karelik thrust animasyonunda f 9..12 aralığı vuruş anı
		_begin_attack(&"attack_thrust", normal_thrust_damage, 9, 12)
	else:
		# Yere saplama / impale şoku: geniş zemin etki alanı (AoE) ve yerden kalkan toz bulutu (f 8..11, olay: f 8)
		_set_attack_hitbox(Vector2(88, 48), Vector2(54.0 * float(direction), -24.0))
		_begin_attack(&"attack_impale", normal_impale_damage, 8, 11, 8, func():
			_spawn_ground_impact_dust(54.0 * float(direction))
		)

func _execute_vampire_slash() -> void:
	velocity.x = 0.0
	# 21 karelik slash animasyonunda f 9..13 vuruş anı
	_begin_attack(&"vampire_attack_slash", vampire_slash_damage, 9, 13)

func _execute_vampire_magic() -> void:
	velocity.x = 0.0
	# 21 karelik kan büyüsü fırlatma anı: f 8
	_begin_attack(&"vampire_attack_blood_magic", vampire_magic_damage, -1, -1, 8, func():
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
	# 24 karelik pençe kombosu: f 6..18 aktif hasar
	_begin_attack(&"werewolf_attack_claws", werewolf_claw_damage, 6, 18)
	velocity.x = float(direction) * 60.0

func _execute_werewolf_leap() -> void:
	velocity = Vector2.ZERO
	_is_leaping = false
	_leap_start_pos = global_position

	if _target_node and is_instance_valid(_target_node):
		var tgt_x: float = _target_node.global_position.x
		var max_dist: float = 480.0
		var diff_x: float = tgt_x - global_position.x
		if absf(diff_x) > max_dist:
			tgt_x = global_position.x + signf(diff_x) * max_dist
		_leap_target_pos = Vector2(tgt_x, _target_node.global_position.y)
		var to_tgt_x: float = _leap_target_pos.x - global_position.x
		var jump_dir: int = 1 if to_tgt_x > 0 else -1
		if jump_dir != direction:
			direction = jump_dir
			_update_facing_direction()
	else:
		_leap_target_pos = global_position + Vector2(float(direction) * 260.0, 0.0)

	if anim_sprite:
		# 24 karelik parabolik sıçrama hızını daha dengeli, sakin ve okunabilir seviyeye çekiyoruz (0.82x)
		anim_sprite.speed_scale = 0.82

	_set_attack_hitbox(Vector2(65, 50), Vector2(40.0 * float(direction), -30.0))

	# Saldırı başlat:
	# f 0..5: crouch_charge (yerde yaylanma)
	# f 6..14: havada tam parabolik uçuş
	# f 15: impact_slam (zemine çarpış darbesi), ekran sarsıntısı ve zemin toz bulutu
	# f 15..18: darbe şoku ve hasar alanı aktif
	_begin_attack(&"werewolf_attack_leap", werewolf_leap_damage, 15, 18, 15, func():
		_trigger_screen_shake(6.5)
		_spawn_ground_impact_dust(20.0 * float(direction))
		_set_attack_hitbox(Vector2(120, 65), Vector2(25.0 * float(direction), -25.0))
	, 0.45, 0.82)

func _execute_bat_dive() -> void:
	velocity = Vector2.ZERO
	if anim_sprite:
		# Animasyon hızını sakin ve sinematik 0.85x seviyesine alıyoruz ki hareket net okunsun
		anim_sprite.speed_scale = 0.85

	# Hedefe dönük olmayı garantile
	if _target_node and is_instance_valid(_target_node):
		var to_tgt_x: float = _target_node.global_position.x - global_position.x
		var face_dir: int = 1 if to_tgt_x > 0.0 else -1
		if face_dir != direction:
			direction = face_dir
			_update_facing_direction()

	# Yırtıcı çapraz dalış vektörü
	_bat_dive_dir = Vector2(float(direction), 0.65).normalized()
	if _target_node and is_instance_valid(_target_node):
		var target_aim: Vector2 = _target_node.global_position + Vector2(0.0, -12.0)
		_bat_dive_dir = (target_aim - global_position).normalized()
		if _bat_dive_dir.y < 0.25:
			_bat_dive_dir.y = 0.38
			_bat_dive_dir = _bat_dive_dir.normalized()

	# Geniş ve ölümcül pike dalışı hitbox'ı (Yarasanın tüm gövdesi ve pençeleri)
	_set_attack_hitbox(Vector2(115, 85), Vector2(15.0 * float(direction), -15.0))

	# 24 karelik dalış (0.85x hız ile dengeli):
	# f 0..7: telgraf hazırlığı (oyuncuya tepki ve kaçma fırsatı verir)
	# f 8..17: dalış ve hasar alanı aktif (380 px/sn hız)
	# f 8: yüksek hızlı dalış itkisi ve ekran sarsıntısı
	_begin_attack(&"bat_attack_dive", bat_dive_damage, 8, 17, 8, func():
		if _target_node and is_instance_valid(_target_node):
			var target_aim: Vector2 = _target_node.global_position + Vector2(0.0, -12.0)
			_bat_dive_dir = (target_aim - global_position).normalized()
			if _bat_dive_dir.y < 0.25:
				_bat_dive_dir.y = 0.38
				_bat_dive_dir = _bat_dive_dir.normalized()
		velocity = _bat_dive_dir * 380.0
		_trigger_screen_shake(4.5)
	, 0.6, 0.85)

func _execute_bat_screech() -> void:
	velocity = Vector2.ZERO
	if anim_sprite:
		anim_sprite.speed_scale = 0.85

	if _target_node and is_instance_valid(_target_node):
		var to_tgt_x: float = _target_node.global_position.x - global_position.x
		var face_dir: int = 1 if to_tgt_x > 0.0 else -1
		if face_dir != direction:
			direction = face_dir
			_update_facing_direction()

	# Geniş konik ultrasonik ses dalgası etki alanı
	_set_attack_hitbox(Vector2(165, 95), Vector2(75.0 * float(direction), -25.0))

	# 24 karelik screech (0.85x hız): f 9..18 hasar alanı, f 9 çığlık şoku
	_begin_attack(&"bat_attack_screech", bat_screech_damage, 9, 18, 9, func():
		_trigger_screen_shake(5.5)
		if _target_node and is_instance_valid(_target_node) and "velocity" in _target_node:
			var push_x: float = signf(_target_node.global_position.x - global_position.x)
			if is_zero_approx(push_x):
				push_x = float(direction)
			_target_node.velocity.x += push_x * 320.0
			_target_node.velocity.y = -180.0
	, 0.6, 0.85)

## -----------------------------------------------------------------------------
## Hasar Alma, Sis Kaçışı & Faz Dönüşümleri & Sersemleme (Groggy)
## -----------------------------------------------------------------------------
func take_damage(amount: int) -> void:
	# Dönüşüm esnasında veya ölü durumdayken hasar alamaz (Sinematik Faz Dokunulmazlığı)
	if is_dead or _is_transforming:
		return

	# Faz Hasar Eşiği / Kapısı (Phase Damage Gating):
	# Boss, o fazın can eşiğinin altına inemez ve erken ölemez!
	var min_allowed_hp: int = 0
	match current_form:
		VladForm.NORMAL:
			min_allowed_hp = int(float(max_health) * form_phase_health_thresholds[0]) # 75% -> 450
		VladForm.VAMPIRE:
			min_allowed_hp = int(float(max_health) * form_phase_health_thresholds[1]) # 50% -> 300
		VladForm.WEREWOLF:
			min_allowed_hp = int(float(max_health) * form_phase_health_thresholds[2]) # 25% -> 150
		VladForm.BAT:
			min_allowed_hp = 0 # Yalnızca son fazda (yarasa) 0 HP'ye inebilir

	# Eğer bu formdaki can zaten tükenmişse doğrudan sonraki forma geç
	if current_health <= min_allowed_hp and current_form != VladForm.BAT:
		match current_form:
			VladForm.NORMAL: set_form(VladForm.VAMPIRE, true)
			VladForm.VAMPIRE: set_form(VladForm.WEREWOLF, true)
			VladForm.WEREWOLF: set_form(VladForm.BAT, true)
		return

	# Groggy / Sersemleme durumunda %35 artırılmış savunmasızlık hasarı (vulnerability bonus):
	if current_state == State.GROGGY:
		var vuln_damage: int = int(float(amount) * groggy_vulnerability_multiplier)
		_trigger_screen_shake(4.5)
		var max_vuln_allowed: int = maxi(0, current_health - min_allowed_hp)
		var actual_damage: int = mini(maxi(1, vuln_damage), max_vuln_allowed)
		if actual_damage > 0:
			current_health = clampi(current_health - actual_damage, min_allowed_hp, max_health)
			_update_health_bar()
			_spawn_damage_number(actual_damage)
			_play_hit_feedback()

		if current_health <= min_allowed_hp:
			if current_form != VladForm.BAT:
				match current_form:
					VladForm.NORMAL: set_form(VladForm.VAMPIRE, true)
					VladForm.VAMPIRE: set_form(VladForm.WEREWOLF, true)
					VladForm.WEREWOLF: set_form(VladForm.BAT, true)
			elif current_health <= 0:
				_die()
		return

	# Vampir formunda taktiksel Sis Kaçışı (%35 şans)
	if current_form == VladForm.VAMPIRE and current_state != State.ATTACK and _mist_dash_cooldown <= 0.0 and randf() < 0.35:
		_execute_vampire_mist_dash()
		return

	# Faz sınırına göre hasarı kelepçele (Faz atlamayı ve anında ölmeyi engeller)
	var max_damage_allowed: int = maxi(0, current_health - min_allowed_hp)
	var gated_amount: int = mini(amount, max_damage_allowed)

	if gated_amount <= 0:
		# Bu faz için hasar limiti doldu, doğrudan sonraki fazı başlat
		match current_form:
			VladForm.NORMAL: set_form(VladForm.VAMPIRE, true)
			VladForm.VAMPIRE: set_form(VladForm.WEREWOLF, true)
			VladForm.WEREWOLF: set_form(VladForm.BAT, true)
		return

	# Duruş kırılması ve Sersemleme birikimi (Stagger Accumulation)
	_stagger_damage += gated_amount
	_stagger_decay_timer = 3.5
	var should_groggy: bool = not _is_transforming and _stagger_damage >= groggy_damage_threshold

	var was_attacking: bool = current_state == State.ATTACK
	super.take_damage(gated_amount)

	if is_dead:
		return

	# Can faz eşiğine ulaştıysa form dönüşümünü başlat
	if current_health <= min_allowed_hp and current_form != VladForm.BAT:
		match current_form:
			VladForm.NORMAL: set_form(VladForm.VAMPIRE, true)
			VladForm.VAMPIRE: set_form(VladForm.WEREWOLF, true)
			VladForm.WEREWOLF: set_form(VladForm.BAT, true)
		return

	if should_groggy:
		_trigger_groggy_stun()
		return

	if was_attacking:
		current_state = State.ATTACK

func _play_hit_feedback() -> void:
	if _groggy_flash_tween and _groggy_flash_tween.is_valid():
		_groggy_flash_tween.kill()
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	if anim_sprite:
		anim_sprite.modulate = Color(2.5, 0.4, 0.4, 1.0)
		_hit_flash_tween = create_tween()
		_hit_flash_tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.18)

	# Saldırı veya Sersemleme (Groggy) sırasında animasyon kesilmez
	if current_state == State.ATTACK or current_state == State.GROGGY:
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

## -----------------------------------------------------------------------------
## Boss Sersemleme / Duruş Kırılması (Groggy / Stun State)
## -----------------------------------------------------------------------------
func _trigger_groggy_stun() -> void:
	current_state = State.GROGGY
	_stagger_damage = 0
	_groggy_timer = groggy_duration
	_is_leaping = false
	floor_snap_length = 4.0
	_atk_hit_on = false
	_deactivate_hitbox()
	_reset_hitbox()
	_trigger_screen_shake(7.5)

	# Form bazlı sersemleme/hasar animasyonu oynat (24 kareye yayılır, akıcı durur)
	if not anim_sprite:
		anim_sprite = get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D

	if anim_sprite and anim_sprite.sprite_frames:
		var stun_anim: StringName = &"hurt"
		match current_form:
			VladForm.NORMAL:
				stun_anim = &"hurt" if anim_sprite.sprite_frames.has_animation(&"hurt") else &"normal_hurt"
			VladForm.VAMPIRE:
				stun_anim = &"vampire_hurt"
			VladForm.WEREWOLF:
				stun_anim = &"werewolf_hurt"
			VladForm.BAT:
				stun_anim = &"bat_hurt"
		anim_sprite.play(stun_anim)
		anim_sprite.speed_scale = 0.85

	# Kısa ve tek seferlik sersemleme parıltısı (Asla sonsuz sarı döngü yapmaz)
	if _groggy_flash_tween and _groggy_flash_tween.is_valid():
		_groggy_flash_tween.kill()
	if anim_sprite:
		_groggy_flash_tween = create_tween()
		_groggy_flash_tween.tween_property(anim_sprite, "modulate", Color(1.8, 1.6, 0.6, 1.0), 0.10)
		_groggy_flash_tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.16)

	groggy_started.emit()

func _process_groggy(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 650.0 * delta)
	if is_flying:
		velocity.y = move_toward(velocity.y, 0.0, 650.0 * delta)
	else:
		if not is_on_floor():
			velocity.y += gravity * delta

	_groggy_timer -= delta
	if _groggy_timer <= 0.0:
		_recover_from_groggy()

func _recover_from_groggy() -> void:
	if _groggy_flash_tween and _groggy_flash_tween.is_valid():
		_groggy_flash_tween.kill()
	if anim_sprite:
		anim_sprite.modulate = Color.WHITE
		anim_sprite.speed_scale = 1.0
	_stagger_damage = 0
	_attack_timer = 0.85
	_trigger_screen_shake(3.5)
	current_state = State.CHASE if _target_node else State.PATROL
	groggy_recovered.emit()

func _execute_vampire_mist_dash() -> void:
	_mist_dash_cooldown = 3.5
	if smoke_vfx:
		smoke_vfx.visible = true
		smoke_vfx.speed_scale = 1.8
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

	if not smoke_vfx:
		smoke_vfx = get_node_or_null("Visual/SmokeVFX") as AnimatedSprite2D
	if not anim_sprite:
		anim_sprite = get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D

	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	if _groggy_flash_tween and _groggy_flash_tween.is_valid():
		_groggy_flash_tween.kill()

	# Kan dumanı görsel efektini başlat (8.0 FPS @ 16 kare = tam 2.0s sinematik dönüşüm ritüeli)
	if smoke_vfx:
		smoke_vfx.visible = true
		smoke_vfx.speed_scale = 1.0
		smoke_vfx.play(&"vfx_blood_smoke_burst")

	_trigger_screen_shake(5.0)

	# 1. Aşama (0.0s -> 0.70s): Duman zeminden fışkırırken eski form kızıl kan aurasıyla dumana çözülür/erir
	var trans_tween: Tween = create_tween()
	if anim_sprite:
		trans_tween.tween_property(anim_sprite, "modulate", Color(2.4, 0.4, 0.4, 0.05), 0.70).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		trans_tween.tween_interval(0.70)

	# 2. Aşama (0.70s -> 0.95s): Dumanın %100 tam örtücülüğe ulaştığı tepe anda (peak cloud) form dönüşür
	trans_tween.tween_interval(0.25)
	trans_tween.tween_callback(func():
		current_form = new_form
		_apply_form_visuals()
		if anim_sprite:
			# Yeni form dumanın kalbinde kızıl silüet olarak başlar
			anim_sprite.modulate = Color(2.2, 0.5, 0.5, 0.15)
	)

	# 3. Aşama (0.95s -> 1.80s): Duman seyrelerken ve yarasalar dağılırken yeni form dumanın içinden organik olarak belirir
	trans_tween.tween_interval(0.10)
	if anim_sprite:
		trans_tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	else:
		trans_tween.tween_interval(0.75)

	# 4. Aşama (2.0s): Duman tamamen dağılır, boss savaş pozisyonunda hazır olarak aksiyona girer
	trans_tween.tween_interval(0.20)
	trans_tween.tween_callback(func():
		if smoke_vfx:
			smoke_vfx.visible = false
		if anim_sprite:
			anim_sprite.modulate = Color.WHITE
		_is_transforming = false
		_trigger_screen_shake(3.0)
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
			speed = 95.0
			chase_speed = 160.0
			attack_range = 140.0
			attack_damage = bat_dive_damage
			_play_form_anim(&"bat_idle_fly")
			_reset_hitbox()
			if _target_node and is_instance_valid(_target_node):
				_bat_standoff_dir = 1 if global_position.x >= _target_node.global_position.x else -1
			velocity.y = -180.0

func _play_form_anim(anim_name: StringName) -> void:
	if current_state == State.GROGGY:
		return
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
		anim_sprite.play(anim_name)

func _update_facing_direction() -> void:
	if not is_inside_tree():
		return
	if anim_sprite:
		anim_sprite.flip_h = (direction < 0)
	if smoke_vfx:
		smoke_vfx.flip_h = (direction < 0)
	if hitbox_area and current_state != State.ATTACK:
		if current_form == VladForm.BAT:
			hitbox_area.position.x = 10.0 * float(direction)
		else:
			hitbox_area.position.x = 50.0 * float(direction)
	if ledge_ray:
		ledge_ray.position.x = 25.0 * float(direction)
		ledge_ray.force_raycast_update()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body in _hit_targets_this_attack:
		return
	_hit_targets_this_attack.append(body)
	super._on_hitbox_body_entered(body)
	if body != self and body.is_in_group("player") and anim_sprite:
		if anim_sprite.animation == &"attack_impale":
			# Yere vurma darbesi oyuncuyu hafifçe havaya ve geriye savurur (Ground Shockwave Pop)
			if "velocity" in body:
				body.velocity.y = -180.0
				body.velocity.x += float(direction) * 110.0
		elif anim_sprite.animation == &"bat_attack_dive":
			# Yırtıcı pike dalışı oyuncuya çarptığında kuvvetli sarsıntı ve fırlatma darbesi
			if "velocity" in body:
				body.velocity.x += float(direction) * 260.0
				body.velocity.y = -160.0
			_trigger_screen_shake(6.0)
		elif anim_sprite.animation == &"bat_attack_screech":
			if "velocity" in body:
				var push_x: float = signf(body.global_position.x - global_position.x)
				if is_zero_approx(push_x):
					push_x = float(direction)
				body.velocity.x += push_x * 340.0
				body.velocity.y = -190.0
			_trigger_screen_shake(5.5)

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

	if not anim_sprite:
		anim_sprite = get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	if anim_sprite:
		anim_sprite.speed_scale = 1.0

	# Form hangisi olursa olsun duman patlar ve insana döner
	if current_form != VladForm.NORMAL:
		if not smoke_vfx:
			smoke_vfx = get_node_or_null("Visual/SmokeVFX") as AnimatedSprite2D

		if smoke_vfx:
			smoke_vfx.visible = true
			smoke_vfx.speed_scale = 1.25
			smoke_vfx.play(&"vfx_blood_smoke_burst")

		var death_tween: Tween = create_tween()
		if anim_sprite:
			death_tween.tween_property(anim_sprite, "modulate", Color(2.4, 0.4, 0.4, 0.05), 0.45)
		else:
			death_tween.tween_interval(0.45)

		death_tween.tween_interval(0.15) # Tepe örtücülük (t = 0.60s)
		death_tween.tween_callback(func():
			current_form = VladForm.NORMAL
			is_flying = false
			if anim_sprite:
				anim_sprite.speed_scale = 1.0
				anim_sprite.modulate = Color.WHITE
				anim_sprite.play(&"death")
		)

		death_tween.tween_interval(0.10)
		if anim_sprite:
			death_tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.45)
		else:
			death_tween.tween_interval(0.45)

		death_tween.tween_interval(0.15)
		death_tween.tween_callback(func():
			if smoke_vfx:
				smoke_vfx.visible = false
		)
	else:
		if anim_sprite:
			anim_sprite.speed_scale = 1.0
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
