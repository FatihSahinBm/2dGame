extends "res://scripts/enemies/monster_enemy.gd"

## Necromancer (Ölüm Büyücüsü)
## Gelişmiş Taktiksel Yapay Zeka:
## - Engel ve Görüş Hattı (Line-of-Sight) Farkındalığı: Duvarın arkasına saklanıldığında büyüyü boşa harcamaz, açı arar.
## - Platform / Yükseklik Farkındalığı: Oyuncu üst platforma çıktığında altından çekilip çapraz atış açısı bulur.
## - Kavisli Kara Büyü Küresi: Engellerin arkasına kıvrılan takip eden büyü mermisi fırlatır.
## - Yakın Dövüş Savunması: Oyuncu dibine girdiğinde asayla ani yakın vuruş savurur.
## - Mesafe Yönetimi (Kiting): Cooldown süresindeyken çok yaklaşan oyuncudan geriye adım atar.

@export_group("Necromancer Magic & Combat")
@export var magic_damage: int = 30
@export var melee_damage: int = 25
@export var cast_range: float = 500.0
@export var melee_range: float = 75.0
@export var projectile_scene: PackedScene = preload("res://scenes/projectiles/dark_magic_projectile.tscn")
@export var magic_cast_delay: float = 1.200 # Hızlandırılmış büyü hazırlığı
@export var melee_impact_delay: float = 0.850 # Hızlandırılmış sopa vuruşu
@export var melee_cooldown: float = 0.200 # İki sopa vuruşu arasındaki çok kısa mikro bekleme süresi
@export var projectile_spawn_offset: Vector2 = Vector2(20.0, -35.0)
@export var melee_hitbox_offset_x: float = 35.0

# Taktiksel AI Durumları
enum AttackType { MELEE, MAGIC }
var current_attack_mode: AttackType = AttackType.MAGIC
var _reposition_timer: float = 0.0
var _reposition_dir: int = 0

func _ready() -> void:
	super._ready()
	if monster_name == "Monster":
		monster_name = "Ölüm Büyücüsü"
	if detection_range < 650.0:
		detection_range = 650.0
	attack_range = melee_range

func _update_facing_direction() -> void:
	super._update_facing_direction()
	if hitbox_area:
		hitbox_area.position.x = melee_hitbox_offset_x * float(direction)
	if ledge_ray:
		ledge_ray.position.x = 14.0 * float(direction)
		ledge_ray.force_raycast_update()

## Proaktif Hedef Arama (Oyuncu menzildeyse doğrudan hedefle)
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

func _process_patrol(delta: float) -> void:
	if not _target_node or not is_instance_valid(_target_node):
		_acquire_target()

	if _target_node and is_instance_valid(_target_node):
		var dist = global_position.distance_to(_target_node.global_position)
		if dist <= detection_range:
			current_state = State.CHASE
			return

	super._process_patrol(delta)



## Tavan / Platform altında mıyız kontrolü
func is_under_ceiling() -> bool:
	var space_state = get_world_2d().direct_space_state
	var from_pos: Vector2 = global_position + Vector2(0, -35.0)
	var to_pos: Vector2 = from_pos + Vector2(0, -180.0)
	var exclude_rids: Array[RID] = [get_rid()]
	if _target_node is CollisionObject2D:
		exclude_rids.append(_target_node.get_rid())
	var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos, 1, exclude_rids)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result = space_state.intersect_ray(query)
	return not result.is_empty()

## Görüş Hattı Kontrolü (Line of Sight - Engel arkasında mıyız?)
func has_line_of_sight_to_target() -> bool:
	if not _target_node or not is_instance_valid(_target_node):
		return false

	# Büyücünün tam üstünde tavan/platform varsa yukarı ateş edemez, açık alana çıkmalı
	if is_under_ceiling():
		return false

	var space_state = get_world_2d().direct_space_state
	var spawn_pos: Vector2 = global_position + Vector2(projectile_spawn_offset.x * float(direction), projectile_spawn_offset.y)
	var target_center: Vector2 = _target_node.global_position + Vector2(0, -18.0)
	var target_head: Vector2 = _target_node.global_position + Vector2(0, -36.0)

	var exclude_rids: Array[RID] = [get_rid()]
	if _target_node is CollisionObject2D:
		exclude_rids.append(_target_node.get_rid())

	# 1. Gövde merkezine doğrudan ışın
	var q_center = PhysicsRayQueryParameters2D.create(spawn_pos, target_center, 1, exclude_rids)
	q_center.collide_with_areas = false
	q_center.collide_with_bodies = true
	var res_center = space_state.intersect_ray(q_center)
	if res_center.is_empty() or res_center.collider == _target_node:
		return true

	# 2. Baş seviyesine doğrudan ışın (Platform kenarından başı görünüyorsa)
	var q_head = PhysicsRayQueryParameters2D.create(spawn_pos, target_head, 1, exclude_rids)
	q_head.collide_with_areas = false
	q_head.collide_with_bodies = true
	var res_head = space_state.intersect_ray(q_head)
	if res_head.is_empty() or res_head.collider == _target_node:
		return true

	# 3. Kavisli Atış / Hava Boşluğu Kontrolü (Hedef üst platformdaysa ve aradaki gökyüzü açıksa)
	if _target_node.global_position.y < global_position.y - 35.0:
		var apex_y: float = minf(spawn_pos.y, target_center.y) - 70.0
		var apex_pos: Vector2 = Vector2((spawn_pos.x + target_center.x) * 0.5, apex_y)
		var q_arc1 = PhysicsRayQueryParameters2D.create(spawn_pos, apex_pos, 1, exclude_rids)
		q_arc1.collide_with_areas = false
		q_arc1.collide_with_bodies = true
		var res_arc1 = space_state.intersect_ray(q_arc1)
		if res_arc1.is_empty():
			var q_arc2 = PhysicsRayQueryParameters2D.create(apex_pos, target_head, 1, exclude_rids)
			q_arc2.collide_with_areas = false
			q_arc2.collide_with_bodies = true
			var res_arc2 = space_state.intersect_ray(q_arc2)
			if res_arc2.is_empty() or res_arc2.collider == _target_node:
				return true

	return false

## Taktiksel Açı Arama ve Manevra (Tavan altından ve engellerden kurtulma)
func _process_repositioning(delta: float, to_target: Vector2) -> void:
	if _reposition_timer > 0.0:
		_reposition_timer -= delta

	# Duvara tosladıysak anında ters yöne manevra yap
	if is_on_wall():
		_reposition_dir = -direction
		_reposition_timer = 1.6

	# Tavan veya platform altındaysak en yakın açık alana doğru çık
	if is_under_ceiling():
		if _reposition_timer <= 0.0 or _reposition_dir == 0:
			var space_state = get_world_2d().direct_space_state
			var exclude_rids: Array[RID] = [get_rid()]
			if _target_node is CollisionObject2D:
				exclude_rids.append(_target_node.get_rid())

			var q_right = PhysicsRayQueryParameters2D.create(global_position + Vector2(100, -35), global_position + Vector2(100, -180), 1, exclude_rids)
			var q_left = PhysicsRayQueryParameters2D.create(global_position + Vector2(-100, -35), global_position + Vector2(-100, -180), 1, exclude_rids)
			var right_open = space_state.intersect_ray(q_right).is_empty()
			var left_open = space_state.intersect_ray(q_left).is_empty()

			if right_open and not left_open:
				_reposition_dir = 1
			elif left_open and not right_open:
				_reposition_dir = -1
			else:
				# İki taraf da kapalıysa platformun dışına doğru açıyı genişlet
				_reposition_dir = -direction if absf(to_target.x) < 220.0 else direction

			_reposition_timer = 2.0
	else:
		# Açık alandayız ama görüş hattı kapalıysa (siper arkası)
		if _reposition_timer <= 0.0 or _reposition_dir == 0:
			_reposition_dir = direction
			_reposition_timer = 1.5

	# Kararlı hızda ilerle (Titremeden)
	velocity.x = float(_reposition_dir) * chase_speed
	if _reposition_dir != 0 and _reposition_dir != direction:
		direction = _reposition_dir
		_update_facing_direction()

func _process_chase(delta: float) -> void:
	if not _target_node or not is_instance_valid(_target_node):
		_target_node = _acquire_target()
		if not _target_node:
			current_state = State.PATROL
			return

	var to_target: Vector2 = _target_node.global_position - global_position
	var dist: float = to_target.length()
	var has_los: bool = has_line_of_sight_to_target()

	# Hedef menzilden çok çıktıysa devriyeye dön
	if dist > detection_range * 1.3:
		_target_node = null
		current_state = State.PATROL
		return

	# Hedefe yönel
	var target_dir: int = 1 if to_target.x > 0 else -1

	# 1. HIZLI VE MANTIKLI SALDIRI TÜRÜ KARARI:
	# - Sopa Menzili Kontrolü: Oyuncu yakın menzildeyse (<= 75px) VE aynı zemin seviyesindeyse -> SOPA!
	var is_in_melee_zone: bool = (dist <= melee_range and absf(to_target.y) <= 45.0)

	if is_in_melee_zone:
		# İki sopa vuruşu arasındaki kısa bekleme süresi dolduysa sopa vur
		if _attack_timer <= 0.0:
			current_attack_mode = AttackType.MELEE
			_start_attack()
			return
		else:
			# Vuruşlar arasındaki o kısa bekleme aralığında oyuncuya dönük sakin duruşta bekler
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if anim_sprite and anim_sprite.animation != &"hit" and anim_sprite.animation != &"hurt":
				anim_sprite.play(&"idle")
			return

	# 2. ENGEL / GÖRÜŞ HATTI YÖNETİMİ:
	# Eğer görüş hattı kapalıysa veya tavan altındaysak kararlı şekilde açı ara
	if not has_los:
		_process_repositioning(delta, to_target)
		if anim_sprite and anim_sprite.animation != &"hit" and anim_sprite.animation != &"hurt":
			anim_sprite.play(&"walk")
		return

	# Görüş açısı açıldıysa repositioning durumunu sıfırla
	_reposition_dir = 0
	_reposition_timer = 0.0

	if target_dir != direction:
		direction = target_dir
		_update_facing_direction()

	# 3. GÖRÜŞ HATTI AÇIK & BÜYÜ MENZİLİNDE (Uzak / Orta Mesafe):
	# (Oyuncu sopa menzilinin dışındaysa veya yukarı platformdaysa mantıklı seçim: BÜYÜ!)
	if dist <= cast_range:
		if _attack_timer <= 0.0:
			current_attack_mode = AttackType.MAGIC
			_start_attack()
			return
		else:
			# Cooldown beklerken kiting: Oyuncu üzerine koşuyorsa geri adım atıp mesafe korur
			if dist < 160.0:
				velocity.x = -float(direction) * speed * 0.8
				if anim_sprite and anim_sprite.animation != &"hit" and anim_sprite.animation != &"hurt":
					anim_sprite.play(&"walk")
				return
			else:
				# İdeal atış mesafesinde sakin bekle
				velocity.x = move_toward(velocity.x, 0.0, 450.0 * delta)
				if anim_sprite and anim_sprite.animation != &"hit" and anim_sprite.animation != &"hurt":
					anim_sprite.play(&"idle")
				return

	# 4. Platform uçurum kontrolü
	if not is_flying and turn_at_ledges and is_on_floor():
		if ledge_ray and not ledge_ray.is_colliding():
			velocity.x = 0.0
			if anim_sprite:
				anim_sprite.play(&"idle")
			return

	# 5. Görüş alanına girmek için hedefe doğru ilerle
	velocity.x = float(direction) * chase_speed
	if anim_sprite and anim_sprite.animation != &"hit" and anim_sprite.animation != &"hurt":
		anim_sprite.play(&"walk")

func _start_attack() -> void:
	current_state = State.ATTACK
	velocity.x = 0.0

	# Saldırıya başlarken hedefe doğru dön
	if _target_node and is_instance_valid(_target_node):
		var target_dir: int = 1 if _target_node.global_position.x > global_position.x else -1
		if target_dir != direction:
			direction = target_dir
			_update_facing_direction()

	if current_attack_mode == AttackType.MAGIC:
		_execute_magic_cast()
	else:
		_execute_melee_swing()

## Uzaktan Kara Büyü Atışı
func _execute_magic_cast() -> void:
	if anim_sprite:
		anim_sprite.speed_scale = 1.15
		anim_sprite.play(&"attack_magic")

	var tween: Tween = create_tween()
	# Büyü çemberi oluşturma ve odaklanma süresi (1.20s)
	tween.tween_interval(magic_cast_delay)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_spawn_dark_magic_projectile()
	)
	# Büyü sonlandırma ve toparlanma süresi (0.80s)
	tween.tween_interval(0.80)
	tween.tween_callback(func():
		if anim_sprite:
			anim_sprite.speed_scale = 1.0
		if current_state == State.ATTACK and not is_dead:
			_attack_timer = 1.0
			current_state = State.CHASE if _target_node else State.PATROL
	)

## Büyü Mermisini Ateşle (Homing destekli)
func _spawn_dark_magic_projectile() -> void:
	if not projectile_scene:
		return

	var proj = projectile_scene.instantiate()
	if not proj:
		return

	var spawn_pos: Vector2 = global_position + Vector2(projectile_spawn_offset.x * float(direction), projectile_spawn_offset.y)
	var shoot_dir: Vector2 = Vector2(float(direction), 0.0)

	if _target_node and is_instance_valid(_target_node):
		var target_aim = _target_node.global_position + Vector2(0, -20.0)
		var direct_vec = (target_aim - spawn_pos).normalized()
		# Eğer hedef yukarıdaki bir platformdaysa, mermiyi yukarı kavisli fırlat
		if _target_node.global_position.y < global_position.y - 35.0:
			shoot_dir = Vector2(direct_vec.x * 0.75, minf(direct_vec.y, -0.65)).normalized()
		else:
			shoot_dir = direct_vec

	# Mermiyi sahneye ekle
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(proj)
		proj.setup(spawn_pos, shoot_dir, self, magic_damage, _target_node)

## Yakın Asa Vuruşu (Belirgin Şekilde Daha Hızlı)
func _execute_melee_swing() -> void:
	if anim_sprite:
		anim_sprite.speed_scale = 1.9 # Sopa savurma animasyonu seri ve akıcı
		anim_sprite.play(&"attack_melee")

	attack_damage = melee_damage

	var tween: Tween = create_tween()
	# Asayı hızla havaya kaldırıp indirme (0.85s)
	tween.tween_interval(melee_impact_delay)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_activate_hitbox()
	)
	# Vuruş etki anı (0.16s)
	tween.tween_interval(0.16)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_deactivate_hitbox()
	)
	# Toparlanma süresi (0.35s)
	tween.tween_interval(0.35)
	tween.tween_callback(func():
		if anim_sprite:
			anim_sprite.speed_scale = 1.0
		if current_state == State.ATTACK and not is_dead:
			_attack_timer = melee_cooldown # Ardı ardına sopa vuruşları arasına kısa bekleme süresi
			current_state = State.CHASE if _target_node else State.PATROL
	)

func take_damage(amount: int) -> void:
	if anim_sprite:
		anim_sprite.speed_scale = 1.0
	_deactivate_hitbox()
	super.take_damage(amount)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	current_state = State.DEAD
	velocity.x = 0.0
	if is_on_floor():
		velocity.y = 0.0

	if anim_sprite:
		anim_sprite.speed_scale = 1.0
	_deactivate_hitbox()

	enemy_died.emit(self)

	# Saldırı ve oyuncu gövde çarpışmasını kapat (oyuncu cesedin içinden geçebilir),
	# ANCAK Zemin (Layer 1 Maskesi) açık kalmalı ki ceset yerin altına düşmesin!
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, true)

	if hurtbox_area:
		hurtbox_area.monitoring = false
		hurtbox_area.monitorable = false

	if health_bar:
		var bar_tween: Tween = create_tween()
		bar_tween.tween_property(health_bar, "modulate:a", 0.0, 0.3)

	if anim_sprite:
		anim_sprite.play(&"death")
		# 65 kare (2.7s) ölüm animasyonu oynadıktan sonra ceset bir süre yerde kalır, ardından solar
		get_tree().create_timer(3.5).timeout.connect(_fade_and_free)
	else:
		_fade_and_free()
