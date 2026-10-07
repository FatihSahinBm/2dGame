@tool
extends SceneTree

func _init() -> void:
	print("--- OGRE BOSS VERIFICATION START ---")
	
	# 1. Load ogre_frames.tres
	var frames_res = load("res://assets/characters/monsters/ogre/ogre_frames.tres")
	if not frames_res:
		push_error("FAIL: Failed to load ogre_frames.tres")
		quit(1)
		return
	print("OK: ogre_frames.tres loaded.")
	
	var anims = frames_res.get_animation_names()
	print("OK: Ogre animations found: ", anims)
	for req in ["idle", "walk", "attack", "hit", "death"]:
		if not frames_res.has_animation(req):
			push_error("FAIL: Missing animation: " + req)
			quit(1)
			return
		print("  - Found animation: ", req, " (frames: ", frames_res.get_frame_count(req), ")")
	
	# 2. Load and instantiate ogre_boss.tscn
	var boss_res = load("res://scenes/enemies/ogre_boss.tscn")
	if not boss_res:
		push_error("FAIL: Failed to load res://scenes/enemies/ogre_boss.tscn")
		quit(1)
		return
	print("OK: ogre_boss.tscn loaded.")
	
	var boss_instance = boss_res.instantiate()
	root.add_child(boss_instance)
	print("OK: ogre_boss instantiated and added to root.")
	
	# Verify required nodes
	var anim_sprite = boss_instance.get_node_or_null("Visual/AnimatedSprite2D")
	if not anim_sprite:
		push_error("FAIL: Visual/AnimatedSprite2D not found in ogre_boss")
		quit(1)
		return
	print("OK: AnimatedSprite2D found with texture_filter = ", anim_sprite.texture_filter)
	
	var col_shape = boss_instance.get_node_or_null("CollisionShape2D")
	if not col_shape:
		push_error("FAIL: CollisionShape2D not found in ogre_boss")
		quit(1)
		return
	print("OK: CollisionShape2D found.")
	
	var hitbox = boss_instance.get_node_or_null("Visual/Hitbox")
	if not hitbox:
		push_error("FAIL: Visual/Hitbox not found")
		quit(1)
		return
	print("OK: Hitbox found.")
	
	var hp_bar = boss_instance.get_node_or_null("UI/HealthBar")
	if not hp_bar:
		push_error("FAIL: UI/HealthBar not found")
		quit(1)
		return
	print("OK: HealthBar found with max_value = ", hp_bar.max_value)
	
	# Verify boss stats
	print("Boss Name: ", boss_instance.monster_name)
	print("Boss Max HP: ", boss_instance.max_health)
	print("Boss Attack Damage: ", boss_instance.attack_damage)
	print("Boss Knockback Resistance: ", boss_instance.knockback_resistance)
	
	# 3. Simulate taking damage
	print("Simulating taking damage...")
	boss_instance.take_damage(50)
	if boss_instance.current_health != boss_instance.max_health - 50:
		push_error("FAIL: Boss health should be reduced")
		quit(1)
		return
	print("OK: Boss took damage, current HP = ", boss_instance.current_health)
	
	# 4. Load test_boss.tscn
	var arena_res = load("res://scenes/dev/test_boss.tscn")
	if not arena_res:
		push_error("FAIL: Failed to load res://scenes/dev/test_boss.tscn")
		quit(1)
		return
	print("OK: test_boss.tscn loaded.")
	
	var arena_scene = arena_res.instantiate()
	root.add_child(arena_scene)
	print("OK: test_boss arena scene instantiated.")
	
	var arena_boss = arena_scene.get_node_or_null("OgreBoss")
	var arena_player = arena_scene.get_node_or_null("Player")
	if not arena_boss or not arena_player:
		push_error("FAIL: OgreBoss or Player missing in arena")
		quit(1)
		return
	print("OK: Arena has both OgreBoss and Player.")
	
	print("--- ALL OGRE BOSS TESTS PASSED WITH 100% SUCCESS ---")
	quit(0)
