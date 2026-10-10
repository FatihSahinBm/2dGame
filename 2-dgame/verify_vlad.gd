@tool
extends SceneTree

func _init() -> void:
	print("--- VLAD BOSS VERIFICATION START ---")
	
	# 1. Load vlad_frames.tres
	var frames_res = load("res://assets/characters/vlad_all_animations/vlad_frames.tres")
	if not frames_res:
		push_error("FAIL: Failed to load vlad_frames.tres")
		quit(1)
		return
	print("OK: vlad_frames.tres loaded successfully.")
	
	var anim_names = frames_res.get_animation_names()
	print("OK: Total animations in vlad_frames.tres: ", anim_names.size())
	
	var required_anims = [
		"idle", "walk", "attack_thrust", "attack_impale",
		"vampire_idle", "vampire_glide", "vampire_attack_slash", "vampire_attack_blood_magic",
		"werewolf_idle", "werewolf_run", "werewolf_attack_claws", "werewolf_attack_leap",
		"bat_idle_fly", "bat_attack_dive", "bat_attack_screech",
		"transform_blood_smoke", "vfx_blood_smoke_burst",
		"hurt", "death", "vampire_hurt", "werewolf_hurt", "bat_hurt"
	]
	
	for req in required_anims:
		if not frames_res.has_animation(req):
			push_error("FAIL: Missing animation: " + req)
			quit(1)
			return
		print("  - Found animation: ", req, " (frames: ", frames_res.get_frame_count(req), ")")
	
	# 2. Load vlad_boss.tscn
	var boss_res = load("res://scenes/enemies/vlad_boss.tscn")
	if not boss_res:
		push_error("FAIL: Failed to load res://scenes/enemies/vlad_boss.tscn")
		quit(1)
		return
	print("OK: vlad_boss.tscn loaded.")
	
	var boss_instance = boss_res.instantiate()
	root.add_child(boss_instance)
	print("OK: vlad_boss instantiated.")
	
	var anim_sprite = boss_instance.get_node_or_null("Visual/AnimatedSprite2D")
	if not anim_sprite:
		push_error("FAIL: Visual/AnimatedSprite2D not found in vlad_boss")
		quit(1)
		return
	print("OK: AnimatedSprite2D found with offset = ", anim_sprite.offset, " scale = ", anim_sprite.scale)
	
	var smoke_vfx = boss_instance.get_node_or_null("Visual/SmokeVFX")
	if not smoke_vfx:
		push_error("FAIL: Visual/SmokeVFX not found in vlad_boss")
		quit(1)
		return
	print("OK: SmokeVFX found.")
	
	var col_shape = boss_instance.get_node_or_null("CollisionShape2D")
	if not col_shape:
		push_error("FAIL: CollisionShape2D not found in vlad_boss")
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
	
	print("Boss Name: ", boss_instance.monster_name)
	print("Boss Max HP: ", boss_instance.max_health)
	print("Boss Attack Damage: ", boss_instance.attack_damage)
	
	# 3. Simulate taking damage
	boss_instance.take_damage(50)
	if boss_instance.current_health != 550:
		push_error("FAIL: Boss health should be 550 after 50 damage")
		quit(1)
		return
	print("OK: Boss took damage, current HP = ", boss_instance.current_health)
	
	# 4. Verify test_combat.tscn
	var test_combat_res = load("res://scenes/dev/test_combat.tscn")
	if not test_combat_res:
		push_error("FAIL: Failed to load res://scenes/dev/test_combat.tscn")
		quit(1)
		return
	print("OK: test_combat.tscn loaded.")
	
	var combat_scene = test_combat_res.instantiate()
	root.add_child(combat_scene)
	print("OK: test_combat instantiated.")
	
	var vlad_in_combat = combat_scene.get_node_or_null("VladBoss")
	if not vlad_in_combat:
		push_error("FAIL: VladBoss not found in test_combat.tscn")
		quit(1)
		return
	print("OK: VladBoss is present in test_combat arena at position: ", vlad_in_combat.position)
	
	var player_in_combat = combat_scene.get_node_or_null("TestPlayer")
	if not player_in_combat:
		push_error("FAIL: TestPlayer not found in test_combat.tscn")
		quit(1)
		return
	print("OK: TestPlayer is present in test_combat arena.")
	
	print("--- ALL VLAD BOSS AND TEST_COMBAT TESTS PASSED WITH 100% SUCCESS ---")
	quit(0)
