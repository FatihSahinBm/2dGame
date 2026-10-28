extends SceneTree

const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

var stage: Node = null
var player: Player = null
var vlad: CharacterBody2D = null
var rampart2: StaticBody2D = null
var rampart1: StaticBody2D = null
var tower_plat1: StaticBody2D = null
var ground3: StaticBody2D = null

var frame_counter: int = 0
var test_phase: int = 0
var phase_frame: int = 0

var passed_count: int = 0
var failed_count: int = 0
var errors: Array[String] = []

var min_jump_y: float = 9999.0
var landed_on_rampart2: bool = false

func assert_check(cond: bool, msg: String) -> void:
	if cond:
		print("  [PASS] ", msg)
		passed_count += 1
	else:
		printerr("  [FAIL] ", msg)
		failed_count += 1
		errors.append(msg)

func _init() -> void:
	print("==================================================================")
	print("--- TEST: VLAD ARENA 3 RAMPART2 JUMP ACCESSIBILITY & REGRESSION ---")
	print("==================================================================")
	
	var packed: PackedScene = load(STAGE3_PATH) as PackedScene
	if not packed:
		_fail("Could not load stage 3 scene: " + STAGE3_PATH)
		return
	
	stage = packed.instantiate()
	root.add_child(stage)
	
	player = stage.get_node_or_null("CombatPlayer") as Player
	vlad = stage.get_node_or_null("VladBoss") as CharacterBody2D
	rampart2 = stage.get_node_or_null("Environment/Arena3_Ramparts/Rampart2") as StaticBody2D
	rampart1 = stage.get_node_or_null("Environment/Arena3_Ramparts/Rampart1") as StaticBody2D
	tower_plat1 = stage.get_node_or_null("Environment/Arena4_BellTower/TowerPlatform1") as StaticBody2D
	ground3 = stage.get_node_or_null("Environment/Arena3_Ramparts/Ground3") as StaticBody2D
	
	if not player or not vlad or not rampart2 or not ground3:
		_fail("Required nodes missing from stage 3")
		return
	
	if vlad:
		vlad.is_active = true
		vlad._is_in_cinematic = false
	if stage.get("dialogue_box") and stage.dialogue_box:
		stage.dialogue_box.visible = false

func _process(delta: float) -> bool:
	frame_counter += 1
	phase_frame += 1
	
	match test_phase:
		0:
			_run_phase_0_geometry_validation()
		1:
			_run_phase_1_single_jump_ascent()
		2:
			_run_phase_2_walking_on_rampart2()
		3:
			_run_phase_3_dropdown_from_rampart2()
		4:
			_run_phase_4_boss_regression_and_summary()
			return true
	
	return false

func _run_phase_0_geometry_validation() -> void:
	print("\n[CHECK 1 & 2: Rampart2 World Position & Visual/Collision Alignment]")
	assert_check(rampart2.position == Vector2(3750, 430), "Rampart2 position is Vector2(3750, 430) (got: %s)" % str(rampart2.position))
	
	var col: CollisionShape2D = rampart2.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_check(col != null and col.shape is RectangleShape2D, "Rampart2 has RectangleShape2D collision")
	var rshape: RectangleShape2D = col.shape as RectangleShape2D
	assert_check(rshape.size == Vector2(240, 24), "Rampart2 collision size is (240, 24) (got: %s)" % str(rshape.size))
	assert_check(col.one_way_collision, "Rampart2 one_way_collision is TRUE")
	
	var visual: Sprite2D = rampart2.get_node_or_null("PlatformVisual") as Sprite2D
	assert_check(visual != null and visual.texture != null, "Rampart2 has valid PlatformVisual Sprite2D")
	var tex_size: Vector2 = visual.texture.get_size()
	assert_check(tex_size == Vector2(240, 24), "Rampart2 texture size matches collision: (240, 24)")
	
	var surface_y: float = rampart2.position.y - (rshape.size.y / 2.0)
	assert_check(surface_y == 418.0, "Rampart2 walkable top surface is exactly Y = 418.0 (got: %s)" % str(surface_y))
	
	var ground_surface_y: float = 560.0
	var height_diff: float = ground_surface_y - surface_y
	assert_check(height_diff == 142.0, "Height difference from ground is 142.0 px (was 162.0 px)")
	
	print("\n[CHECK 6 & 7: Horizontal Distances & Other Platforms Preservation]")
	assert_check(rampart2.position.x == 3750.0, "Rampart2 horizontal position X = 3750.0 preserved")
	var dist_rampart1: float = rampart2.position.x - rampart1.position.x
	assert_check(dist_rampart1 == 800.0, "Horizontal distance to Rampart1 preserved: 800.0 px")
	var dist_tower1: float = tower_plat1.position.x - rampart2.position.x
	assert_check(dist_tower1 == 750.0, "Horizontal distance to TowerPlatform1 preserved: 750.0 px")
	
	# Verify all other 7 platforms
	var other_plats: Array[Dictionary] = [
		{"path": "Environment/Arena1_ThroneRoom/PlatformLeft", "pos": Vector2(200, 430)},
		{"path": "Environment/Arena1_ThroneRoom/PlatformRight", "pos": Vector2(980, 430)},
		{"path": "Environment/Arena2_BloodHall/PlatformL", "pos": Vector2(1580, 430)},
		{"path": "Environment/Arena2_BloodHall/PlatformR", "pos": Vector2(2320, 430)},
		{"path": "Environment/Arena3_Ramparts/Rampart1", "pos": Vector2(2950, 430)},
		{"path": "Environment/Arena4_BellTower/TowerPlatform1", "pos": Vector2(4500, 430)},
		{"path": "Environment/Arena4_BellTower/TowerPlatform2", "pos": Vector2(5200, 430)}
	]
	var other_ok: bool = true
	for op in other_plats:
		var node: StaticBody2D = stage.get_node_or_null(op["path"]) as StaticBody2D
		if not node or node.position != op["pos"]:
			other_ok = false
			break
	assert_check(other_ok, "All other 7 elevated platforms remain at Y = 430.0 without changes")
	
	# Prepare player below Rampart2 on Ground3
	player.global_position = Vector2(3750.0, 560.0)
	player.velocity = Vector2.ZERO
	test_phase = 1
	phase_frame = 0

func _run_phase_1_single_jump_ascent() -> void:
	if phase_frame < 5:
		return
	
	if phase_frame == 5:
		print("\n[CHECK 3: Single Jump Ascent & Landing on Rampart2]")
		assert_check(player.is_on_floor(), "Player is grounded on Ground3 at (3750, 560)")
		# Trigger single jump
		player.velocity.y = player.jump_velocity
		min_jump_y = player.global_position.y
		return
	
	if player.global_position.y < min_jump_y:
		min_jump_y = player.global_position.y
	
	# Check if player has landed on Rampart2
	if phase_frame > 15 and phase_frame < 120:
		if player.is_on_floor() and absf(player.global_position.y - 418.0) < 1.0:
			landed_on_rampart2 = true
			assert_check(min_jump_y < 418.0, "Player apex cleared platform top: apex Y = %s (< 418.0)" % str(min_jump_y))
			assert_check(player.is_on_floor(), "Player is firmly grounded on Rampart2")
			assert_check(absf(player.global_position.y - 418.0) < 1.0, "Player landed precisely at surface Y = 418.0 (actual: %s)" % str(player.global_position.y))
			assert_check(player._air_jumps_left == 1, "PROVED: Single jump ONLY (_air_jumps_left == 1, double jump NOT used)")
			
			test_phase = 2
			phase_frame = 0
			return
	
	if phase_frame >= 120:
		assert_check(false, "Player failed to land on Rampart2 with single jump. Pos: %s" % str(player.global_position))
		test_phase = 2
		phase_frame = 0

func _run_phase_2_walking_on_rampart2() -> void:
	if phase_frame == 1:
		print("\n[CHECK 4: Horizontal Walking Stability on Rampart2]")
	
	# Walk to the right
	if phase_frame < 25:
		player.velocity.x = 120.0
		player.facing_dir = 1.0
	elif phase_frame < 50:
		player.velocity.x = -120.0
		player.facing_dir = -1.0
	else:
		player.velocity.x = 0.0
		assert_check(player.is_on_floor(), "Player remained grounded while walking across Rampart2")
		assert_check(absf(player.global_position.y - 418.0) < 1.0, "Player Y remained stable at 418.0 during walk (actual: %s)" % str(player.global_position.y))
		assert_check(player.global_position.x > 3650.0 and player.global_position.x < 3850.0, "Player remained safely within 240px width (X: %s)" % str(player.global_position.x))
		
		# Move to drop-through test
		test_phase = 3
		phase_frame = 0

func _run_phase_3_dropdown_from_rampart2() -> void:
	if phase_frame < 5:
		player.velocity = Vector2.ZERO
		return
	
	if phase_frame == 5:
		print("\n[CHECK 5: Drop-Through Mechanism on Rampart2]")
		assert_check(player.is_on_floor(), "Player grounded on Rampart2 before drop-through")
		player._start_drop_through_platform(rampart2)
		assert_check(player._is_dropping_through, "Drop-through state initiated successfully on Rampart2")
		return
	
	if phase_frame > 10 and phase_frame < 120:
		if player.is_on_floor() and absf(player.global_position.y - 560.0) < 1.0:
			assert_check(not player._is_dropping_through, "Drop-through state cleared after landing")
			assert_check(player.is_on_floor(), "Player safely landed on Ground3 below Rampart2")
			assert_check(absf(player.global_position.y - 560.0) < 1.0, "Player Y cleanly snapped to Ground3 Y = 560.0 (actual: %s)" % str(player.global_position.y))
			
			test_phase = 4
			phase_frame = 0
			return
	
	if phase_frame >= 120:
		assert_check(false, "Player failed to land back on Ground3 from drop-through. Pos: %s" % str(player.global_position))
		test_phase = 4
		phase_frame = 0

func _run_phase_4_boss_regression_and_summary() -> void:
	print("\n[CHECK 8 & 9: Boss AI, Multi-Forms & Scene Health]")
	assert_check(vlad.has_method("take_damage"), "VladBoss has take_damage method")
	assert_check(vlad.has_method("set_form"), "VladBoss has set_form method")
	assert_check(vlad.has_method("_execute_normal_spear_throw"), "VladBoss has _execute_normal_spear_throw method")
	assert_check(vlad.has_signal("form_changed"), "VladBoss has form_changed signal")
	
	# Test forms
	vlad.set_form(0, false)
	assert_check(vlad.current_form == 0, "Normal form intact")
	vlad.set_form(1, false)
	assert_check(vlad.current_form == 1, "Vampire form intact")
	vlad.set_form(2, false)
	assert_check(vlad.current_form == 2, "Werewolf form intact")
	vlad.set_form(3, false)
	assert_check(vlad.current_form == 3, "Bat form intact")
	
	print("\n==================================================================")
	print("TEST SUITE RESULTS: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("==================================================================")
	
	if failed_count == 0:
		print("ALL RAMPART2 JUMP ACCESSIBILITY CHECKS PASSED WITH 0 ERRORS!")
		quit(0)
	else:
		print("TEST FAILED WITH %d ERRORS:" % failed_count)
		for e in errors:
			print("  - ", e)
		quit(1)

func _fail(msg: String) -> void:
	printerr("[FATAL ERROR] ", msg)
	quit(1)
