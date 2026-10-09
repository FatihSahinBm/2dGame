extends Area2D

## DarkMagicProjectile - Necromancer Kara Büyü Mermisi
## Uçan mor karanlık büyü küresi, oyuncuya veya dünyaya çarptığında patlar.
## Kılıçla tam zamanında hafif saldırı (Sol Tık) yapıldığında dümdüz geri yansıtılabilir (Parry).

@export var speed: float = 340.0
@export var damage: int = 30
@export var lifetime: float = 4.0
@export var knockback_force: float = 180.0
@export var homing_strength: float = 2.4 # Engellerin etrafından kavis alarak hedefe yönelme gücü

var direction: Vector2 = Vector2.RIGHT
var is_bursting: bool = false
var is_reflected: bool = false
var _caster: Node2D = null
var _target_node: Node2D = null

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var col_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("reflectable_projectile")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if anim_sprite:
		anim_sprite.animation_finished.connect(_on_animation_finished)
		anim_sprite.play(&"travel")

	# Ömür sayacı (boşluğa uçup gitmesin)
	get_tree().create_timer(lifetime).timeout.connect(func():
		if is_instance_valid(self) and not is_bursting:
			_trigger_burst()
	)

func setup(spawn_pos: Vector2, target_dir: Vector2, caster_node: Node2D = null, custom_damage: int = 30, target_node: Node2D = null) -> void:
	global_position = spawn_pos
	direction = target_dir.normalized()
	_caster = caster_node
	_target_node = target_node
	damage = custom_damage

	# Mermiyi hareket yönüne göre çevir
	if direction.x < 0:
		scale.x = -abs(scale.x)
	else:
		scale.x = abs(scale.x)

## Büyüyü Dümdüz Geri Yansıtma (Parry / Deflect)
func reflect(reflector: Node2D = null) -> void:
	if is_bursting or is_reflected:
		return

	is_reflected = true
	_caster = reflector
	_target_node = null # Artık oyuncuyu takip etmez

	# Kullanıcı isteği: "büyüyü dümdüz geri yollasın"
	# Oyuncunun baktığı yöne (veya geliş yönünün tam tersine) DÜMDÜZ yatay olarak fırlatılır
	var reflect_x: float = 1.0
	if reflector and "facing_dir" in reflector:
		reflect_x = float(reflector.facing_dir)
	elif not is_zero_approx(direction.x):
		reflect_x = -signf(direction.x)

	direction = Vector2(reflect_x, 0.0).normalized()
	speed = 460.0 # Geri yansıtıldığında daha hızlı ve tok uçar
	damage = int(damage * 1.5) # Yansıtılan büyü düşmanlara daha yüksek hasar verir (45 hasar)

	# Yön ölçeğini anında güncelle
	if direction.x < 0:
		scale.x = -abs(scale.x)
	else:
		scale.x = abs(scale.x)

	# Görsel ark parlama efekti (Yansıtıldığında mavi/mor enerjiyle parlar)
	if anim_sprite:
		anim_sprite.modulate = Color(2.8, 2.5, 5.0, 1.0)
		var tw = create_tween()
		tw.tween_property(anim_sprite, "modulate", Color(1.3, 1.1, 1.8, 1.0), 0.25)

	# Geri uçuş için ömür süresini sıfırla
	get_tree().create_timer(lifetime).timeout.connect(func():
		if is_instance_valid(self) and not is_bursting:
			_trigger_burst()
	)

func _physics_process(delta: float) -> void:
	if is_bursting:
		return

	# Eğer yansıtılmadıysa hedefi takip eder (homing). Yansıtıldıysa DÜMDÜZ uçar!
	if not is_reflected and _target_node and is_instance_valid(_target_node):
		var target_center = _target_node.global_position + Vector2(0, -18.0)
		var desired_dir = (target_center - global_position).normalized()
		direction = direction.slerp(desired_dir, homing_strength * delta)
		if direction.x < 0:
			scale.x = -abs(scale.x)
		else:
			scale.x = abs(scale.x)

	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if is_bursting or body == self:
		return

	# 1. YANSITILMIŞ MERMİ DURUMU:
	if is_reflected:
		# Oyuncuya çarpmaz
		if body == _caster or body.is_in_group("player"):
			return

		# Düşmanlara çarparsa hasar ver
		var hit_enemy: bool = false
		if body.is_in_group("enemies") or body.has_method("take_damage") or body.has_method("hit"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
				hit_enemy = true
			elif body.has_method("hit"):
				body.hit(damage)
				hit_enemy = true

			if "velocity" in body:
				body.velocity.x += direction.x * knockback_force * 1.5
				body.velocity.y = -100.0

		_trigger_burst()
		return

	# 2. NORMAL (YANSITILMAMIŞ) MERMİ DURUMU:
	if body == _caster:
		return

	# Düşmanların birbirini vurmasını engelle (Necromancer dost canavarları vurmasın)
	if body.is_in_group("enemies") and body != _caster:
		return

	# Oyuncuya çarpma durumu:
	if body.is_in_group("player"):
		# Sıkı zamanlama penceresi (0.12s) ve dar ön menzil kontrolü:
		if body.has_method("can_parry_projectile") and body.can_parry_projectile():
			var player_chest: Vector2 = body.global_position + Vector2(0.0, -20.0)
			var to_proj: Vector2 = global_position - player_chest
			var facing: float = body.get("facing_dir") if body.get("facing_dir") != null else 1.0
			var forward_dist: float = to_proj.x * facing
			var y_diff: float = absf(to_proj.y)
			if forward_dist >= 10.0 and forward_dist <= 55.0 and y_diff <= 26.0:
				reflect(body)
				if body.has_method("_play_parry_feedback"):
					body._play_parry_feedback(global_position)
				return

		# Zamanlama tutmadıysa oyuncu tam hasar alır!
		if body.has_method("take_damage"):
			body.take_damage(damage)
		elif body.has_method("hit"):
			body.hit(damage)

		if "velocity" in body:
			body.velocity.x += direction.x * knockback_force
			body.velocity.y = -120.0

		_trigger_burst()
		return

	# Diğer hedefler (varsa)
	var hit_target: bool = false
	if body.has_method("take_damage"):
		body.take_damage(damage)
		hit_target = true
	elif body.has_method("hit"):
		body.hit(damage)
		hit_target = true

	# Geri itme kuvveti
	if hit_target and "velocity" in body:
		body.velocity.x += direction.x * knockback_force
		body.velocity.y = -120.0

	_trigger_burst()

func _on_area_entered(area: Area2D) -> void:
	if is_bursting:
		return

	var parent_body = area.get_parent()

	# 1. Kılıç vuruş alanı (AttackArea) mermiye değdiyse
	if not is_reflected and (area.name == "AttackArea" or area.is_in_group("player_attack")):
		var player_node = parent_body
		if player_node and "visual_node" in player_node:
			player_node = player_node
		elif area.get_parent() and area.get_parent().get_parent() and area.get_parent().get_parent().is_in_group("player"):
			player_node = area.get_parent().get_parent()

		# Sadece oyuncunun parry penceresi o an aktifse ve mermi kılıcın önündeyse yansıt!
		if player_node and player_node.has_method("can_parry_projectile") and player_node.can_parry_projectile():
			var player_chest: Vector2 = player_node.global_position + Vector2(0.0, -20.0)
			var to_proj: Vector2 = global_position - player_chest
			var facing: float = player_node.get("facing_dir") if player_node.get("facing_dir") != null else 1.0
			var forward_dist: float = to_proj.x * facing
			var y_diff: float = absf(to_proj.y)
			if forward_dist >= 10.0 and forward_dist <= 55.0 and y_diff <= 26.0:
				reflect(player_node)
				if player_node.has_method("_play_parry_feedback"):
					player_node._play_parry_feedback(global_position)
				return
		return

	# 2. Yansıtılmış mermi düşman Hurtbox'ına çarptıysa
	if is_reflected:
		if parent_body and parent_body.is_in_group("player"):
			return
		if parent_body and parent_body.is_in_group("enemies"):
			if parent_body.has_method("take_damage"):
				parent_body.take_damage(damage)
				if "velocity" in parent_body:
					parent_body.velocity.x += direction.x * knockback_force * 1.5
			_trigger_burst()
		return

	# 3. Yansıtılmamış normal mermi oyuncunun Hurtbox'ına çarptıysa
	if parent_body and parent_body.is_in_group("player"):
		# Sadece son anda tam pencere ve mesafe içindeyse savuşturulur:
		if parent_body.has_method("can_parry_projectile") and parent_body.can_parry_projectile():
			var player_chest: Vector2 = parent_body.global_position + Vector2(0.0, -20.0)
			var to_proj: Vector2 = global_position - player_chest
			var facing: float = parent_body.get("facing_dir") if parent_body.get("facing_dir") != null else 1.0
			var forward_dist: float = to_proj.x * facing
			var y_diff: float = absf(to_proj.y)
			if forward_dist >= 10.0 and forward_dist <= 50.0 and y_diff <= 24.0:
				reflect(parent_body)
				if parent_body.has_method("_play_parry_feedback"):
					parent_body._play_parry_feedback(global_position)
				return

		# Zamanlama kaçtıysa (erken ya da geç saldırıldıysa) hasar al!
		if parent_body.has_method("take_damage"):
			parent_body.take_damage(damage)
			if "velocity" in parent_body:
				parent_body.velocity.x += direction.x * knockback_force
				parent_body.velocity.y = -120.0
		_trigger_burst()

func _trigger_burst() -> void:
	if is_bursting:
		return
	is_bursting = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if col_shape:
		col_shape.set_deferred("disabled", true)

	if anim_sprite:
		anim_sprite.play(&"burst")
	else:
		queue_free()

func _on_animation_finished() -> void:
	if anim_sprite and anim_sprite.animation == &"burst":
		queue_free()
