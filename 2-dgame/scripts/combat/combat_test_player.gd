extends "res://scripts/player.gd"

## res://scripts/combat/combat_test_player.gd
## Vlad bölümü mekanikleri: Kan Sisi Atılması (Blood Mist Dash),
## Kılıç İsyanı (Sword Rebellion) ve Can Yenileme (Heal) desteği.

const SwordRebellionManager = preload("res://scripts/combat/sword_rebellion_manager.gd")


func _ready() -> void:
	super._ready()
	add_to_group("player")
	_setup_rebellion_manager()


func _setup_rebellion_manager() -> void:
	if not sword_rebellion:
		sword_rebellion = get_node_or_null("SwordRebellionManager")
		if not sword_rebellion:
			sword_rebellion = SwordRebellionManager.new()
			sword_rebellion.name = "SwordRebellionManager"
			add_child(sword_rebellion)


## Can Yenileme (Müttefik sömürüsü veya vampirik darbeden)
func heal(amount: int) -> void:
	if is_dead:
		return
	current_health = mini(max_health, current_health + amount)
	player_damaged.emit(current_health, max_health)

	# Yeşil / Kızıl can yenileme efekti
	if visual_node:
		var tw: Tween = create_tween()
		tw.tween_property(visual_node, "modulate", Color(0.3, 1.8, 0.4, 1.0), 0.08)
		tw.tween_property(visual_node, "modulate", Color.WHITE, 0.15)

	# Uçan bildirim metni
	var parent_scene: Node = get_parent()
	if parent_scene:
		var label: Label = Label.new()
		label.text = "+%d CAN" % amount
		label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_font_size_override("font_size", 13)
		label.global_position = global_position + Vector2(-20.0, -45.0)
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 25.0, 0.6)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
		tw.tween_callback(label.queue_free)


## Dash / Kan Sisi Atılması
func perform_dash() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	var has_blood_mist: bool = game_state and game_state.has_method("has_ability") and game_state.has_ability("blood_mist_dash")

	if not has_blood_mist:
		super.perform_dash()
		return

	# --- Kan Sisi Atılması (Blood Mist Dash) ---
	is_dashing = true
	can_dash = false
	set_collision_mask_value(2, false) # Düşman çarpışmasını devre dışı bırak
	velocity.x = facing_dir * (dash_speed * 1.35) # Daha hızlı ve akıcı
	velocity.y = 0.0

	if anim_sprite and anim_sprite.sprite_frames.has_animation("dash"):
		anim_sprite.play("dash")

	# Kızıl sis ve yarı saydamlık
	if visual_node:
		visual_node.modulate = Color(1.8, 0.1, 0.2, 0.4)

	_spawn_blood_mist_trail()

	# İçinden geçtiği düşmanlara hasar ver ve can sömür
	_leech_enemies_in_path()

	get_tree().create_timer(0.26).timeout.connect(func():
		is_dashing = false
		set_collision_mask_value(2, true)
		if visual_node:
			visual_node.modulate = Color.WHITE
	)

	get_tree().create_timer(0.42).timeout.connect(func():
		can_dash = true
	)


func _leech_enemies_in_path() -> void:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 32.0
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2 # Düşmanlar
	query.collide_with_bodies = true

	var results = space_state.intersect_shape(query)
	for res in results:
		var collider = res.get("collider")
		if collider and collider != self and collider.has_method("take_damage"):
			collider.take_damage(20)
			heal(10) # Düşmandan can sömür


func _spawn_blood_mist_trail() -> void:
	var parent_scene: Node = get_parent()
	if not parent_scene:
		return
	var mist: CPUParticles2D = CPUParticles2D.new()
	mist.emitting = true
	mist.one_shot = true
	mist.amount = 32
	mist.lifetime = 0.4
	mist.explosiveness = 0.6
	mist.spread = 180.0
	mist.gravity = Vector2(0, -20)
	mist.initial_velocity_min = 20.0
	mist.initial_velocity_max = 80.0
	mist.color = Color(0.85, 0.08, 0.18, 0.8)
	mist.global_position = global_position
	parent_scene.add_child(mist)
	mist.finished.connect(mist.queue_free)
