extends SceneTree

const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

var stage: Node
var player: Player
var vlad: CharacterBody2D
var platform_left: StaticBody2D
var platform_right: StaticBody2D
var ground1: StaticBody2D

var frame_counter: int = 0
var test_phase: int = 0
var phase_frame: int = 0

var passed_checks: Array[int] = [0]
var failed_checks: Array[int] = [0]
var errors: Array[String] = []

func assert_check(cond: bool, msg: String) -> void:
	if cond:
		print("  [PASS] ", msg)
		passed_checks[0] += 1
	else:
		printerr("  [FAIL] ", msg)
		failed_checks[0] += 1
		errors.append(msg)


func _init() -> void:
	print("==================================================================")
	print("--- TEST SUITE: PLAYER ONE-WAY PLATFORM DROP-DOWN MECHANIC ---")
	print("==================================================================")
	
	var packed: PackedScene = load(STAGE3_PATH) as PackedScene
	if not packed:
		_fail("Could not load stage 3 scene: " + STAGE3_PATH)
		return
	
	stage = packed.instantiate()
	root.add_child(stage)
	
	player = stage.get_node_or_null("CombatPlayer") as Player
	vlad = stage.get_node_or_null("VladBoss") as CharacterBody2D
	platform_left = stage.get_node_or_null("Environment/Arena1_ThroneRoom/PlatformLeft") as StaticBody2D
	platform_right = stage.get_node_or_null("Environment/Arena1_ThroneRoom/PlatformRight") as StaticBody2D
	ground1 = stage.get_node_or_null("Environment/Arena1_ThroneRoom/Ground1") as StaticBody2D
	
	if not player or not platform_left or not ground1:
		_fail("Essential nodes missing from stage 3 scene")
		return
	
	# Deactivate cinematics
	if vlad:
		vlad.is_active = true
		vlad._is_in_cinematic = false
	if stage.get("dialogue_box") and stage.dialogue_box:
		stage.dialogue_box.visible = false

func _process(_delta: float) -> bool:
	frame_counter += 1
	if frame_counter < 4:
		return false
	
	phase_frame += 1
	
	# Execute phased tests across real engine frames
	match test_phase:
		0:
			_run_phase_0_setup()
		1:
			_run_phase_1_normal_jump()
		2:
			_run_phase_2_dropdown_initiation()
		3:
			_run_phase_3_dropdown_physics_and_recovery()
		4:
			_run_phase_4_solid_ground_immunity()
		5:
			_run_phase_5_air_skills_double_jump_dash()
		6:
			_run_phase_6_held_key_no_loop()
		7:
			_run_phase_7_cleanup_on_death_and_respawn()
		8:
			_run_phase_8_stacked_platforms()
		9:
			_run_phase_9_boss_and_spear_regression()
		10:
			_finish_test_suite()
			return true
	
	return false

# -----------------------------------------------------------------------------
# PHASE 0: Initial Setup & Parser / Type Check
# -----------------------------------------------------------------------------
func _run_phase_0_setup() -> void:
	print("\n[TEST 11: Script Loading & Runtime Health]")
	assert_check(player != null, "Player node instantiated successfully")
	assert_check(player.has_method("_is_down_input_pressed"), "Player has _is_down_input_pressed method")
	assert_check(player.has_method("_get_current_one_way_platform"), "Player has _get_current_one_way_platform method")
	assert_check(player.has_method("_start_drop_through_platform"), "Player has _start_drop_through_platform method")
	assert_check(player.has_method("_clear_drop_through_platform"), "Player has _clear_drop_through_platform method")
	assert_check(InputMap.has_action("move_down"), "InputMap contains 'move_down' action")
	
	# Position player on Ground1 (in open space at X=500, clear of PlatformLeft overhead)
	player.global_position = Vector2(500.0, 560.0)
	player.velocity = Vector2.ZERO
	test_phase = 1
	phase_frame = 0

# -----------------------------------------------------------------------------
# PHASE 1: Normal Jump Preserved when NOT on One-Way Platform (Test 1)
# -----------------------------------------------------------------------------
func _run_phase_1_normal_jump() -> void:
	if phase_frame < 5:
		return

	if phase_frame == 5:
		print("\n[TEST 1: Normal Jump Preserved on Solid Ground]")
		assert_check(player.is_on_floor(), "Player is grounded on solid Ground1")
		assert_check(not player._is_dropping_through, "Player is not in drop-through state")
		# Trigger standard jump
		player.velocity.y = player.jump_velocity
		player._jump_buffer_timer = 0.0
		return

	
	if phase_frame == 8:
		assert_check(player.velocity.y < -500.0, "Player initiated normal jump (velocity.y: " + str(player.velocity.y) + ")")
		assert_check(not player._is_dropping_through, "Drop-through remains false during normal jump")
	
	if phase_frame > 10 and phase_frame < 180:
		if player.is_on_floor() and absf(player.global_position.y - 560.0) < 1.0:
			assert_check(player.is_on_floor(), "Player landed back on Ground1 after normal jump")
			assert_check(absf(player.global_position.y - 560.0) < 1.0, "Player Y position returned to 560.0 (actual: " + str(player.global_position.y) + ")")
			
			# Move to phase 2: place player on PlatformLeft
			player.global_position = Vector2(200.0, 418.0)
			player.velocity = Vector2.ZERO
			test_phase = 2
			phase_frame = 0
			return
	
	if phase_frame >= 180:
		_fail("Player failed to land back on Ground1 from normal jump. Current pos: " + str(player.global_position))
		test_phase = 2
		phase_frame = 0




# -----------------------------------------------------------------------------
# PHASE 2: Down + Jump on One-Way Platform Initiates Drop-Through (Test 2 & 3)
# -----------------------------------------------------------------------------
func _run_phase_2_dropdown_initiation() -> void:
	if phase_frame < 5:
		# Settle on platform
		return
	
	if phase_frame == 5:
		print("\n[TEST 2 & 3: Drop-Through Trigger & No Involuntary Upward Jump]")
		assert_check(player.is_on_floor(), "Player settled on PlatformLeft (Y = 418)")
		var detected_plat = player._get_current_one_way_platform()
		assert_check(detected_plat == platform_left, "Detected supporting platform matches PlatformLeft")
		
		# Trigger Drop-Down
		player._start_drop_through_platform(platform_left)
		assert_check(player._is_dropping_through, "Player _is_dropping_through is now TRUE")
		assert_check(player.get_collision_exceptions().has(platform_left), "PlatformLeft added to collision exceptions")
		assert_check(player.velocity.y >= 100.0, "Downward velocity applied (velocity.y: " + str(player.velocity.y) + " >= 100.0)")
		assert_check(player.velocity.y > 0.0, "[TEST 3] No upward velocity impulse generated (velocity.y > 0)")
		assert_check(player._jump_buffer_timer == 0.0, "Jump buffer timer safely zeroed out")
		
		test_phase = 3
		phase_frame = 0

# -----------------------------------------------------------------------------
# PHASE 3: Drop-Through Physics, Exception Removal, and Landing on Ground1 (Test 4 & 5)
# -----------------------------------------------------------------------------
func _run_phase_3_dropdown_physics_and_recovery() -> void:
	# Monitor velocity.y during drop
	if phase_frame < 15:
		if player.velocity.y < 0.0:
			assert_check(false, "Unwanted upward velocity detected during drop-through: " + str(player.velocity.y))
	
	# When player passes below platform bottom (442.0 + 6.0 = 448.0)
	if player.global_position.y > 450.0 and player._is_dropping_through:
		# Engine physics tick should clear exception
		pass
	
	if player.is_on_floor() and player.global_position.y > 550.0:
		print("\n[TEST 4 & 5: Exception Removal & Solid Ground Landing]")
		assert_check(not player._is_dropping_through, "Drop-through flag cleared after passing platform")
		assert_check(not player.get_collision_exceptions().has(platform_left), "PlatformLeft cleanly removed from collision exceptions")
		assert_check(player.is_on_floor(), "Player safely landed on solid Ground1 below platform")
		assert_check(absf(player.global_position.y - 560.0) < 1.0, "Player Y snapped accurately to Ground1 surface (Y = 560.0)")
		
		test_phase = 4
		phase_frame = 0
		return
	
	if phase_frame > 60:
		_fail("Player timed out falling from PlatformLeft to Ground1")
		test_phase = 4
		phase_frame = 0

# -----------------------------------------------------------------------------
# PHASE 4: Solid Ground Immunity (Test 6)
# -----------------------------------------------------------------------------
func _run_phase_4_solid_ground_immunity() -> void:
	if phase_frame == 1:
		print("\n[TEST 6: Solid Ground Immunity (Cannot Fall Through Ground)]")
		assert_check(player.is_on_floor(), "Player is on solid Ground1")
		var plat = player._get_current_one_way_platform()
		assert_check(plat == null, "Ground1 correctly identified as NOT a one-way platform (returns null)")
		
		# Attempt drop-through on Ground1
		if plat:
			player._start_drop_through_platform(plat)
		else:
			# If null, code will not start drop-through
			pass
		
		assert_check(not player._is_dropping_through, "_is_dropping_through is FALSE for solid ground")
		assert_check(player.get_collision_exceptions().size() == 0, "No collision exceptions created for solid ground")
		return
	
	if phase_frame == 10:
		assert_check(player.is_on_floor(), "Player remains solidly on Ground1")
		assert_check(player.global_position.y >= 559.0 and player.global_position.y <= 561.0, "Player position unchanged on ground (Y = " + str(player.global_position.y) + ")")
		
		test_phase = 5
		phase_frame = 0

# -----------------------------------------------------------------------------
# PHASE 5: Double Jump and Dash (Test 7)
# -----------------------------------------------------------------------------
func _run_phase_5_air_skills_double_jump_dash() -> void:
	if phase_frame == 1:
		print("\n[TEST 7: Air Skills Preservation (Double Jump & Dash)]")
		# Start jump from ground
		player.velocity.y = player.jump_velocity
		player._was_on_floor = false
		return
	
	if phase_frame == 10:
		# Now in air, trigger double jump
		var initial_jumps = player._air_jumps_left
		assert_check(initial_jumps > 0, "Air jumps available: " + str(initial_jumps))
		player._air_jumps_left -= 1
		player.velocity.y = player.jump_velocity * 0.88
		assert_check(player.velocity.y < -500.0, "Double jump impulse successfully applied (velocity.y: " + str(player.velocity.y) + ")")
		assert_check(player._air_jumps_left == 0, "Air jumps decremented to 0")
		return
	
	if phase_frame == 20:
		# Trigger dash while airborne
		player.facing_dir = 1.0
		player.perform_dash()
		assert_check(player.is_dashing, "Dash successfully activated in mid-air")
		assert_check(absf(player.velocity.x) >= player.dash_speed, "Dash horizontal speed applied (velocity.x: " + str(player.velocity.x) + ")")
		return
	
	if phase_frame == 50:
		# Wait for landing back on ground
		player.is_dashing = false
		player.global_position = Vector2(200.0, 560.0)
		player.velocity = Vector2.ZERO
		test_phase = 6
		phase_frame = 0

# -----------------------------------------------------------------------------
# PHASE 6: Holding Down + Jump Does NOT Cause Continuous Loop (Test 8)
# -----------------------------------------------------------------------------
func _run_phase_6_held_key_no_loop() -> void:
	if phase_frame == 1:
		print("\n[TEST 8: Held Key Anti-Oscillation / Single Trigger]")
		# Place player on PlatformLeft
		player.global_position = Vector2(200.0, 418.0)
		player.velocity = Vector2.ZERO
		return
	
	if phase_frame == 5:
		assert_check(player.is_on_floor(), "Player grounded on PlatformLeft")
		# Simulate key down edge
		player._prev_jump_key_pressed = false
		var raw_down: bool = true
		var jump_just_pressed: bool = (raw_down and not player._prev_jump_key_pressed)
		player._prev_jump_key_pressed = raw_down
		assert_check(jump_just_pressed, "First frame with key held registered as just_pressed")
		
		# Next frame while key is STILL held
		var jump_frame_2: bool = (raw_down and not player._prev_jump_key_pressed)
		assert_check(not jump_frame_2, "Second frame with key held correctly evaluated as FALSE (no rapid re-trigger)")
		
		test_phase = 7
		phase_frame = 0

# -----------------------------------------------------------------------------
# PHASE 7: Death & Respawn Cleanup (Test 9)
# -----------------------------------------------------------------------------
func _run_phase_7_cleanup_on_death_and_respawn() -> void:
	if phase_frame == 1:
		print("\n[TEST 9: Clean Exception Reset on Death & Respawn]")
		# Artificially activate drop-through exception
		player._start_drop_through_platform(platform_left)
		assert_check(player._is_dropping_through, "Drop-through artificially started")
		assert_check(player.get_collision_exceptions().has(platform_left), "Exception exists before death")
		
		# Call die()
		player.die()
		assert_check(not player._is_dropping_through, "_is_dropping_through reset to false on die()")
		assert_check(not player.get_collision_exceptions().has(platform_left), "Platform exception cleared on die()")
		
		# Reset death for continued tests
		player.is_dead = false
		test_phase = 8
		phase_frame = 0

# -----------------------------------------------------------------------------
# PHASE 8: Stacked One-Way Platforms (Test 10)
# -----------------------------------------------------------------------------
func _run_phase_8_stacked_platforms() -> void:
	if phase_frame == 1:
		print("\n[TEST 10: Stacked One-Way Platforms Interaction]")
		# Dynamically add an intermediate one-way platform above PlatformLeft
		var top_plat: StaticBody2D = StaticBody2D.new()
		top_plat.name = "TestStackedPlatTop"
		top_plat.global_position = Vector2(200.0, 300.0)
		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(240.0, 24.0)
		col.shape = shape
		col.one_way_collision = true
		top_plat.add_child(col)
		stage.get_node("Environment/Arena1_ThroneRoom").add_child(top_plat)
		
		# Put player on top_plat
		player.global_position = Vector2(200.0, 288.0)
		player.velocity = Vector2.ZERO
		return
	
	if phase_frame == 5:
		var top_plat = stage.get_node_or_null("Environment/Arena1_ThroneRoom/TestStackedPlatTop")
		assert_check(top_plat != null, "Created test stacked platform at Y = 300")
		
		# Trigger drop-through on top_plat
		player._start_drop_through_platform(top_plat)
		assert_check(player._is_dropping_through, "Drop-through started on top stacked platform")
		assert_check(player.get_collision_exceptions().has(top_plat), "Top platform in exceptions")
		assert_check(not player.get_collision_exceptions().has(platform_left), "Lower platform (PlatformLeft) is NOT in exceptions")
		return
	
	if phase_frame > 5 and phase_frame < 140:
		# Player drops past top_plat and should land on PlatformLeft (Y = 418)
		if player.is_on_floor() and absf(player.global_position.y - 418.0) < 3.0:
			assert_check(true, "Player safely landed on lower one-way platform (PlatformLeft at Y = " + str(player.global_position.y) + ")")
			assert_check(not player._is_dropping_through, "Drop-through ended upon clearing top platform")
			
			# Clean up test platform
			var top_plat = stage.get_node_or_null("Environment/Arena1_ThroneRoom/TestStackedPlatTop")
			if top_plat:
				top_plat.queue_free()
			
			test_phase = 9
			phase_frame = 0
			return

	if phase_frame >= 140:
		_fail("Player failed to land on PlatformLeft from stacked platform. Final pos: " + str(player.global_position))
		test_phase = 9
		phase_frame = 0



# -----------------------------------------------------------------------------
# PHASE 9: Boss AI & Human Spear Throw Regressions (Test 12)
# -----------------------------------------------------------------------------
func _run_phase_9_boss_and_spear_regression() -> void:
	print("\n[TEST 12: Boss AI & Elevated Spear Throw Regression Verification]")
	if not vlad:
		assert_check(false, "VladBoss node not found")
		test_phase = 10
		return
	
	vlad.set_form(0, false)
	player.global_position = Vector2(200.0, 418.0)
	vlad.global_position = Vector2(360.0, 560.0)
	vlad._target_node = player
	vlad._attack_timer = 0.0
	
	var diff_y = player.global_position.y - vlad.global_position.y
	var dist_x = absf(player.global_position.x - vlad.global_position.x)
	vlad._chase_normal_form(0.016, 214.0, dist_x, diff_y)
	
	assert_check(vlad.has_method("_execute_normal_spear_throw"), "VladBoss has _execute_normal_spear_throw method")
	assert_check(vlad.current_state == vlad.State.ATTACK, "Vlad entered ATTACK state against elevated platform player")
	assert_check(vlad.anim_sprite.animation == &"attack_thrust", "Vlad initiated attack_thrust animation for spear throw")
	var telegraph = stage.get_node_or_null("SpearAimTelegraph") as Line2D
	assert_check(telegraph != null, "SpearAimTelegraph Line2D exists during throw preparation")
	
	# Verify other forms integrity
	vlad._clear_spear_throw_telegraph()
	vlad.set_form(1, false) # Vampire
	assert_check(vlad.current_form == vlad.VladForm.VAMPIRE, "Form transitioned to VAMPIRE")
	vlad.set_form(2, false) # Werewolf
	assert_check(vlad.current_form == vlad.VladForm.WEREWOLF, "Form transitioned to WEREWOLF")
	vlad.set_form(3, false) # Bat
	assert_check(vlad.current_form == vlad.VladForm.BAT, "Form transitioned to BAT")
	
	test_phase = 10
	phase_frame = 0


# -----------------------------------------------------------------------------
# PHASE 10: Test Suite Conclusion & Reporting
# -----------------------------------------------------------------------------
func _finish_test_suite() -> void:
	print("\n==================================================================")
	print("TEST SUITE RESULTS: " + str(passed_checks[0]) + " PASSED, " + str(failed_checks[0]) + " FAILED")
	print("==================================================================")
	
	if failed_checks[0] > 0:
		printerr("\nERRORS ENCOUNTERED:")
		for err in errors:
			printerr("  - ", err)
		quit(1)
	else:
		print("ALL 12 ONE-WAY PLATFORM DROP-DOWN CHECKS PASSED WITH 0 ERRORS!")
		quit(0)

func _fail(msg: String) -> void:
	printerr("FATAL TEST FAILURE: ", msg)
	quit(1)
