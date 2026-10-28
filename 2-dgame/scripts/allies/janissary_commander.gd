class_name JanissaryCommander
extends CharacterBody2D

## res://scripts/allies/janissary_commander.gd
## Târgovişte Gece Baskını'nda pusuya düşen ve ana karakter tarafından kurtarılan
## Osmanlı Öncü Kumandanı (Yeniçeri Ağası).

signal rescued()
signal reached_sultan_tent()
signal died(death_pos: Vector2)

@export var max_health: int = 140
@export var current_health: int = 140
@export var speed: float = 150.0
@export var attack_damage: int = 35
@export var attack_range: float = 65.0
@export var attack_cooldown: float = 0.9
@export var is_guard: bool = false

var gravity: float = 980.0
var is_rescued: bool = false
var _is_dead: bool = false
var _target_enemy: Node2D = null
var _attack_timer: float = 0.0
var _shout_timer: float = 3.5
var _player_ref: CharacterBody2D = null

@onready var visual: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var attack_area: Area2D = $Visual/AttackArea
@onready var health_bar: ProgressBar = $UI/HealthBar


func _ready() -> void:
	add_to_group("allies")
	add_to_group("damageable")
	_setup_player_collision_exception()
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false


func _setup_player_collision_exception() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if p is CollisionObject2D:
			add_collision_exception_with(p)
			p.add_collision_exception_with(self)


func on_cinematic_started() -> void:
	velocity.x = 0.0
	_target_enemy = null
	if anim_sprite and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")


func on_cinematic_ended() -> void:
	pass


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	# Sinematik sırasında saldırı ve hareket kilitlenir
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.is_in_cinematic:
		velocity.x = 0.0
		if anim_sprite and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")
		move_and_slide()
		return

	if is_guard:
		velocity.x = 0.0
		if anim_sprite and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")
		move_and_slide()
		return

	_attack_timer = maxf(0.0, _attack_timer - delta)
	_shout_timer = maxf(0.0, _shout_timer - delta)

	if not is_rescued:
		_combat_logic(delta)
	else:
		# Kurtarıldıktan sonra ordugaha doğru kararlı adımlarla ilerler
		velocity.x = speed * 1.05
		visual.scale.x = absf(visual.scale.x)
		if anim_sprite and anim_sprite.sprite_frames.has_animation("walk"):
			anim_sprite.play("walk")
		move_and_slide()


func _combat_logic(_delta: float) -> void:
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.is_in_cinematic:
		velocity.x = 0.0
		if anim_sprite and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")
		return

	_find_nearby_enemy()
	if _target_enemy and is_instance_valid(_target_enemy):
		var dist: float = global_position.distance_to(_target_enemy.global_position)
		var dir_x: float = signf(_target_enemy.global_position.x - global_position.x)
		if dir_x != 0.0:
			visual.scale.x = absf(visual.scale.x) * dir_x

		var in_reach: bool = dist <= attack_range or (is_on_wall() and dist <= 120.0)
		if in_reach:
			velocity.x = 0.0
			if _attack_timer <= 0.0:
				_perform_attack()
		else:
			velocity.x = dir_x * speed
			if is_on_wall() and is_on_floor() and dir_x > 0.0:
				velocity.y = -390.0
			if anim_sprite and anim_sprite.sprite_frames.has_animation("walk"):
				anim_sprite.play("walk")

		if _shout_timer <= 0.0 and randf() < 0.35:
			_shout_timer = randf_range(6.0, 10.0)
			shout("Yıkın barikatları! Hücum!")
	else:
		# Hedef yokken oyuncuyla omuz omuza hücum et
		if not _player_ref or not is_instance_valid(_player_ref):
			_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D

		if _player_ref and is_instance_valid(_player_ref):
			var dist_x: float = _player_ref.global_position.x - global_position.x
			if dist_x > 30.0:
				visual.scale.x = absf(visual.scale.x)
				var catchup_mult = clampf(dist_x / 60.0, 1.25, 2.6)
				velocity.x = speed * catchup_mult
				if is_on_wall() and is_on_floor():
					velocity.y = -390.0
				if anim_sprite and anim_sprite.sprite_frames.has_animation("walk"):
					anim_sprite.play("walk")
			elif dist_x < -80.0:
				visual.scale.x = -absf(visual.scale.x)
				velocity.x = -speed * 0.4
				if anim_sprite and anim_sprite.sprite_frames.has_animation("walk"):
					anim_sprite.play("walk")
			else:
				velocity.x = speed * 1.15
				visual.scale.x = absf(visual.scale.x)
				if is_on_wall() and is_on_floor():
					velocity.y = -390.0
				if anim_sprite and anim_sprite.sprite_frames.has_animation("walk"):
					anim_sprite.play("walk")
		else:
			velocity.x = speed
			visual.scale.x = absf(visual.scale.x)
			if is_on_wall() and is_on_floor():
				velocity.y = -390.0
			if anim_sprite and anim_sprite.sprite_frames.has_animation("walk"):
				anim_sprite.play("walk")

	move_and_slide()


func _find_nearby_enemy() -> void:
	# 1. Öncelik 1: Normal / Ana Bosslar (group "boss", örn. Vlad Boss)
	var bosses = get_tree().get_nodes_in_group("boss")
	var closest_boss: Node2D = null
	var closest_boss_dist: float = 950.0
	for b in bosses:
		if b is Node2D and is_instance_valid(b) and not b.is_queued_for_deletion() and not ("is_dead" in b and b.is_dead):
			var d = global_position.distance_to(b.global_position)
			if d < closest_boss_dist:
				closest_boss_dist = d
				closest_boss = b as Node2D
	if closest_boss:
		_target_enemy = closest_boss
		return

	# 2. Öncelik 2: Barikat önceliği (Yolu açmak için)
	var barricades = get_tree().get_nodes_in_group("barricades")
	var closest_barricade: Node2D = null
	var closest_barricade_dist: float = 750.0

	for b in barricades:
		if b is Node2D and is_instance_valid(b) and not b.is_queued_for_deletion() and not ("_is_destroyed" in b and b._is_destroyed):
			var d = global_position.distance_to(b.global_position)
			if d < closest_barricade_dist and b.global_position.x >= global_position.x - 30.0:
				closest_barricade_dist = d
				closest_barricade = b as Node2D

	if closest_barricade:
		_target_enemy = closest_barricade
		return

	# 3. Öncelik 3: Standart düşmanlar (mini-boss HARİÇ)
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var closest_dist: float = 850.0
	var standard_target: Node2D = null
	var mini_boss_target: Node2D = null
	var mini_boss_dist: float = 850.0

	for node in enemies:
		if node is Node2D and node != self and is_instance_valid(node) and not node.is_queued_for_deletion() and not ("is_dead" in node and node.is_dead) and not ("_is_destroyed" in node and node._is_destroyed):
			var d: float = global_position.distance_to(node.global_position)
			if node.is_in_group("mini_boss"):
				if d < mini_boss_dist:
					mini_boss_dist = d
					mini_boss_target = node
			else:
				if d < closest_dist:
					closest_dist = d
					standard_target = node

	if standard_target:
		_target_enemy = standard_target
		return

	# 4. Öncelik 4: Yalnızca başka düşman kalmadığında mini-boss'u hedef al
	_target_enemy = mini_boss_target


func _perform_attack() -> void:
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.is_in_cinematic:
		return

	_attack_timer = attack_cooldown
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")

	velocity.x = signf(visual.scale.x) * 50.0

	get_tree().create_timer(0.2).timeout.connect(func():
		if _is_dead:
			return
		_deal_damage_to_targets(attack_damage)
	)


func _deal_damage_to_targets(damage: int) -> void:
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.is_in_cinematic:
		return

	var hit_objects: Array[Object] = []

	if attack_area:
		for body in attack_area.get_overlapping_bodies():
			if body == self or body in hit_objects:
				continue
			var target = body
			if (target.is_in_group("enemies") or target.is_in_group("barricades")) and not target.is_in_group("allies") and not target.is_in_group("player"):
				hit_objects.append(target)
				var actual_damage = damage
				if target.is_in_group("mini_boss"):
					actual_damage = maxi(1, int(damage * 0.2))
				if target.has_method("take_damage"):
					target.take_damage(actual_damage)
				elif target.has_method("hit"):
					target.hit(actual_damage)

		for area in attack_area.get_overlapping_areas():
			var target = area.get_parent() if area.get_parent() != self else area
			if target == self or target in hit_objects:
				continue
			if (target.is_in_group("enemies") or target.is_in_group("barricades")) and not target.is_in_group("allies") and not target.is_in_group("player"):
				hit_objects.append(target)
				var actual_damage = damage
				if target.is_in_group("mini_boss"):
					actual_damage = maxi(1, int(damage * 0.2))
				if target.has_method("take_damage"):
					target.take_damage(actual_damage)
				elif target.has_method("hit"):
					target.hit(actual_damage)

	# Doğrudan fizik alanı sorgusu
	var space_state = get_world_2d().direct_space_state
	if space_state:
		var query = PhysicsShapeQueryParameters2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 56.0
		query.shape = shape
		query.transform = Transform2D(0.0, global_position + Vector2(signf(visual.scale.x) * 36.0, -18.0))
		query.collision_mask = 31
		query.exclude = [self]
		query.collide_with_bodies = true
		query.collide_with_areas = true
		var results = space_state.intersect_shape(query, 12)
		for r in results:
			var col = r.get("collider")
			if col and is_instance_valid(col) and col != self:
				var target = col
				if target is Area2D and target.get_parent() and target.get_parent() != self:
					target = target.get_parent()
				if target in hit_objects:
					continue
				if (target.is_in_group("enemies") or target.is_in_group("barricades")) and not target.is_in_group("allies") and not target.is_in_group("player"):
					hit_objects.append(target)
					var actual_damage = damage
					if target.is_in_group("mini_boss"):
						actual_damage = maxi(1, int(damage * 0.2))
					if target.has_method("take_damage"):
						target.take_damage(actual_damage)
					elif target.has_method("hit"):
						target.hit(actual_damage)


func mark_rescued() -> void:
	if is_rescued:
		return
	is_rescued = true
	rescued.emit()
	shout("Yiğit yabancı! Gel, seni derhal Hünkarımız Fatih Sultan Mehmet'in otağına götüreyim!")


func shout(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.global_position = global_position + Vector2(-120.0, -55.0)

	var parent_scene: Node = get_parent()
	if parent_scene:
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 30.0, 2.2)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 2.2)
		tw.tween_callback(label.queue_free)


func take_damage(amount: int, attacker: Node2D = null) -> void:
	if _is_dead:
		return
	current_health -= amount
	if health_bar:
		health_bar.value = current_health

	if visual and is_instance_valid(visual):
		var tw: Tween = create_tween()
		tw.tween_property(visual, "modulate", Color.RED, 0.08)
		tw.tween_property(visual, "modulate", Color.WHITE, 0.12)

	if attacker and attacker.is_in_group("player"):
		var game_state: Node = get_node_or_null("/root/GameState")
		if game_state and game_state.has_method("add_corruption"):
			game_state.add_corruption(8)

	if current_health <= 0:
		_is_dead = true
		died.emit(global_position)
		if anim_sprite and anim_sprite.sprite_frames.has_animation("death"):
			anim_sprite.play("death")
		queue_free()
