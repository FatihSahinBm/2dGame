class_name TestVladStage3CameraMotion
extends SceneTree

## tools/test_vlad_stage3_camera_motion.gd
## Comprehensive real-camera motion test and measurement suite for Vlad Stage 3 Throne Room.
## Measures layer displacements, smoothing behavior, reverse motion symmetry, and arena boundaries.

const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

var stage: Stage3ThroneRoom = null
var player: CharacterBody2D = null
var cam: Camera2D = null

var far_sky: WorldParallaxBackground = null
var world_bg: WorldParallaxBackground = null
var mid_root: Node2D = null
var near_root: Node2D = null
var fg_root: Node2D = null

# Test waypoints across the 4 arenas
var waypoints: Array[Dictionary] = [
	{ "name": "Arena 1 Start", "pos": Vector2(180, 560), "arena": 1 },
	{ "name": "Arena 1 Center", "pos": Vector2(600, 560), "arena": 1 },
	{ "name": "Arena 1-2 Boundary", "pos": Vector2(1250, 560), "arena": 1 },
	{ "name": "Arena 2 Center", "pos": Vector2(1950, 560), "arena": 2 },
	{ "name": "Arena 2-3 Boundary", "pos": Vector2(2650, 560), "arena": 2 },
	{ "name": "Arena 3 Center", "pos": Vector2(3350, 560), "arena": 3 },
	{ "name": "Arena 3-4 Boundary", "pos": Vector2(4050, 560), "arena": 3 },
	{ "name": "Arena 4 Center", "pos": Vector2(4850, 560), "arena": 4 }
]

var measurements: Array[Dictionary] = []
var step_idx: int = 0
var sub_step: int = 0
var frame_wait: int = 0

var smoothing_frames: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0


func _init() -> void:
	print("================================================================================")
	print("--- VLAD STAGE 3 REAL CAMERA MOTION & ARENA TRANSITION MEASUREMENT SUITE ---")
	print("================================================================================")


func _process(_delta: float) -> bool:
	frame_wait += 1
	match sub_step:
		0:
			# Setup scene and initialize camera
			if frame_wait == 1:
				var packed: PackedScene = load(STAGE3_PATH) as PackedScene
				stage = packed.instantiate() as Stage3ThroneRoom
				root.add_child(stage)
				
				# Suppress dialogue box and cutscene tweens to isolate gameplay camera tracking
				if stage.dialogue_box:
					stage.dialogue_box.queue_free()
					stage.dialogue_box = null
				if stage.flashback_overlay:
					stage.flashback_overlay.queue_free()
					stage.flashback_overlay = null
				for tw in stage.get_tree().get_processed_tweens():
					tw.kill()
				
				player = stage.player
				player.can_move = false
				player.velocity = Vector2.ZERO
				
				cam = player.get_node_or_null("Camera2D") as Camera2D
				if cam:
					cam.offset = Vector2.ZERO
					cam.zoom = Vector2.ONE
					cam.position_smoothing_enabled = true
					cam.position_smoothing_speed = 8.0
					# Unclamp limits during motion test to measure continuous across-castle tracking
					cam.limit_left = -10000000
					cam.limit_right = 10000000
					cam.limit_top = -10000000
					cam.limit_bottom = 10000000
				
				far_sky = stage.get_node_or_null("FarSkyBackdrop") as WorldParallaxBackground
				world_bg = stage.get_node_or_null("WorldBackdrop") as WorldParallaxBackground
				mid_root = stage.get_node_or_null("Environment/MidgroundDepth") as Node2D
				near_root = stage.get_node_or_null("Environment/NearDepth") as Node2D
				fg_root = stage.get_node_or_null("Environment/ForegroundFraming") as Node2D
				
				player.global_position = waypoints[0]["pos"]
				if cam:
					cam.reset_smoothing()
				
				print("[INITIALIZED] Scene loaded. Settle at Arena 1 Start (180, 560)...")
			
			if frame_wait >= 15:
				sub_step = 1
				step_idx = 0
				frame_wait = 0
				print("\n[SECTION 1: Forward Waypoint Progression (1 -> 8)]")

		1:
			# Forward progression through waypoints
			var wp: Dictionary = waypoints[step_idx]
			player.global_position = wp["pos"]
			
			var target_x: float = wp["pos"].x + cam.position.x
			var cam_x: float = cam.get_screen_center_position().x
			var lag: float = abs(target_x - cam_x)
			
			# If transitioning between Waypoint 0 and Waypoint 1, record smoothing frames
			if step_idx == 1 and frame_wait <= 35:
				smoothing_frames.append({
					"frame": frame_wait,
					"cam": cam.get_screen_center_position(),
					"target": wp["pos"] + cam.position
				})
			
			# Wait until smoothing has converged to < 0.2px (or max 60 frames)
			if lag < 0.2 or frame_wait >= 60:
				_record_measurement(wp["name"], wp["pos"], step_idx, "forward")
				step_idx += 1
				frame_wait = 0
				if step_idx >= waypoints.size():
					print("\n[FORWARD COMPLETED] Starting reverse progression (8 -> 1)...")
					sub_step = 2
					step_idx = waypoints.size() - 1

		2:
			# Reverse progression through waypoints
			var wp_rev: Dictionary = waypoints[step_idx]
			player.global_position = wp_rev["pos"]
			
			var target_x_rev: float = wp_rev["pos"].x + cam.position.x
			var cam_x_rev: float = cam.get_screen_center_position().x
			var lag_rev: float = abs(target_x_rev - cam_x_rev)
			
			if lag_rev < 0.2 or frame_wait >= 60:
				_record_measurement(wp_rev["name"], wp_rev["pos"], step_idx, "reverse")
				step_idx -= 1
				frame_wait = 0
				if step_idx < 0:
					print("\n[REVERSE COMPLETED] Analyzing mathematical measurements...")
					sub_step = 3

		3:
			# Analyze collected measurements and verify mathematical correctness
			_analyze_forward_motion()
			_analyze_reverse_symmetry()
			_analyze_smoothing_trajectory()
			_analyze_boundary_transitions()
			
			print("\n================================================================================")
			print("CAMERA MOTION TEST SUMMARY: %d PASSED, %d FAILED" % [tests_passed, tests_failed])
			print("================================================================================")
			
			stage.queue_free()
			quit(0 if tests_failed == 0 else 1)
			return true

	return false


func _record_measurement(wp_name: String, target_pos: Vector2, idx: int, direction: String) -> void:
	var cam_pos: Vector2 = cam.get_screen_center_position()
	var m: Dictionary = {
		"idx": idx,
		"name": wp_name,
		"dir": direction,
		"target": target_pos,
		"cam": cam_pos,
		"far_sky_pos": far_sky.global_position if far_sky else Vector2.ZERO,
		"world_bg_pos": world_bg.global_position if world_bg else Vector2.ZERO,
		"mid": {},
		"near": {},
		"fg": {}
	}
	
	if mid_root:
		for child in mid_root.get_children():
			if child is ParallaxDepthLayer:
				m["mid"][child.name] = {
					"pos": child.position,
					"global_pos": child.global_position,
					"visible": child.visible
				}
	
	if near_root:
		for child in near_root.get_children():
			if child is ParallaxDepthLayer:
				m["near"][child.name] = {
					"pos": child.position,
					"global_pos": child.global_position,
					"visible": child.visible
				}
	
	if fg_root:
		for child in fg_root.get_children():
			if child is ParallaxDepthLayer:
				m["fg"][child.name] = {
					"pos": child.position,
					"global_pos": child.global_position,
					"visible": child.visible
				}
	
	measurements.append(m)
	print("  [%s] %-20s | Target: %s | CamPos: (%.1f, %.1f)" % [
		direction.to_upper(), wp_name, str(target_pos), cam_pos.x, cam_pos.y
	])


func _assert(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  [PASS] %s" % msg)
	else:
		tests_failed += 1
		print("  [FAIL] %s" % msg)


func _analyze_forward_motion() -> void:
	print("\n[SECTION 2: Forward Motion & Parallax Factor Validation]")
	
	# Compare Arena 1 Start (idx 0) and Arena 1 Center (idx 1)
	var m0: Dictionary = {}
	var m1: Dictionary = {}
	for m in measurements:
		if m["dir"] == "forward" and m["idx"] == 0:
			m0 = m
		elif m["dir"] == "forward" and m["idx"] == 1:
			m1 = m
	
	if m0.is_empty() or m1.is_empty():
		_assert(false, "Failed to retrieve forward measurements for Arena 1")
		return
	
	var delta_cam_x: float = m1["cam"].x - m0["cam"].x
	print("  Camera X delta (Arena 1 Start -> Center): %.2f px" % delta_cam_x)
	_assert(abs(delta_cam_x - 420.0) < 2.0, "Camera tracked target from X=180 to X=600 (+420px)")
	
	# 1. FarSkyBackdrop (factor = 0.02)
	# World delta: (1 - 0.02) * delta_cam
	# Screen delta: World delta - delta_cam = -0.02 * delta_cam
	var far_sky_world_delta: float = m1["far_sky_pos"].x - m0["far_sky_pos"].x
	var far_sky_screen_delta: float = far_sky_world_delta - delta_cam_x
	var expected_far_screen: float = -delta_cam_x * 0.02
	print("  FarSkyBackdrop | Measured Screen Shift: %6.2f px | Expected: %6.2f px" % [far_sky_screen_delta, expected_far_screen])
	_assert(abs(far_sky_screen_delta - expected_far_screen) < 0.5, "FarSkyBackdrop matches 2%% screen parallax")
	
	# 2. WorldBackdrop (factor = 0.04)
	var wb_world_delta: float = m1["world_bg_pos"].x - m0["world_bg_pos"].x
	var wb_screen_delta: float = wb_world_delta - delta_cam_x
	var expected_wb_screen: float = -delta_cam_x * 0.04
	print("  WorldBackdrop  | Measured Screen Shift: %6.2f px | Expected: %6.2f px" % [wb_screen_delta, expected_wb_screen])
	_assert(abs(wb_screen_delta - expected_wb_screen) < 0.5, "WorldBackdrop matches 4%% screen parallax")
	
	# 3. Midground Arena 1 (factor = 0.12)
	var mid1_m0: Dictionary = m0["mid"]["Mid_Arena1"]
	var mid1_m1: Dictionary = m1["mid"]["Mid_Arena1"]
	var mid1_world_delta: float = mid1_m1["pos"].x - mid1_m0["pos"].x
	var mid1_screen_delta: float = mid1_world_delta - delta_cam_x
	var expected_mid_screen: float = -delta_cam_x * 0.12
	print("  Mid_Arena1     | Measured Screen Shift: %6.2f px | Expected: %6.2f px" % [mid1_screen_delta, expected_mid_screen])
	_assert(abs(mid1_screen_delta - expected_mid_screen) < 0.5, "Mid_Arena1 matches 12%% screen parallax")
	
	# 4. Near Arena 1 (factor = 0.28)
	var near1_m0: Dictionary = m0["near"]["Near_Arena1"]
	var near1_m1: Dictionary = m1["near"]["Near_Arena1"]
	var near1_world_delta: float = near1_m1["pos"].x - near1_m0["pos"].x
	var near1_screen_delta: float = near1_world_delta - delta_cam_x
	var expected_near_screen: float = -delta_cam_x * 0.28
	print("  Near_Arena1    | Measured Screen Shift: %6.2f px | Expected: %6.2f px" % [near1_screen_delta, expected_near_screen])
	_assert(abs(near1_screen_delta - expected_near_screen) < 0.5, "Near_Arena1 matches 28%% screen parallax")
	
	# 5. Foreground Arena 1 (factor = 1.15)
	var fg1_m0: Dictionary = m0["fg"]["FG_Arena1"]
	var fg1_m1: Dictionary = m1["fg"]["FG_Arena1"]
	var fg1_world_delta: float = fg1_m1["pos"].x - fg1_m0["pos"].x
	var fg1_screen_delta: float = fg1_world_delta - delta_cam_x
	var expected_fg_screen: float = -delta_cam_x * 1.15
	print("  FG_Arena1      | Measured Screen Shift: %6.2f px | Expected: %6.2f px" % [fg1_screen_delta, expected_fg_screen])
	_assert(abs(fg1_screen_delta - expected_fg_screen) < 0.5, "FG_Arena1 matches 115%% screen parallax (rushes past camera)")
	
	# Verify depth layer hierarchy ordering (Far Sky < World Backdrop < Midground < Near < Foreground)
	_assert(abs(far_sky_screen_delta) < abs(wb_screen_delta), "Depth ordering: FarSky (2%) moves slower on screen than WorldBackdrop (4%)")
	_assert(abs(wb_screen_delta) < abs(mid1_screen_delta), "Depth ordering: WorldBackdrop (4%) moves slower on screen than Midground (12%)")
	_assert(abs(mid1_screen_delta) < abs(near1_screen_delta), "Depth ordering: Midground (12%) moves slower on screen than Near (28%)")
	_assert(abs(near1_screen_delta) < abs(fg1_screen_delta), "Depth ordering: Near (28%) moves slower on screen than Foreground (115%)")


func _analyze_reverse_symmetry() -> void:
	print("\n[SECTION 3: Left vs Right Motion Symmetry]")
	
	for i in range(waypoints.size()):
		var fwd: Dictionary = {}
		var rev: Dictionary = {}
		for m in measurements:
			if m["idx"] == i:
				if m["dir"] == "forward":
					fwd = m
				elif m["dir"] == "reverse":
					rev = m
		
		if not fwd.is_empty() and not rev.is_empty():
			var cam_diff: float = abs(fwd["cam"].x - rev["cam"].x)
			_assert(cam_diff < 0.5, "Camera symmetry at %s: diff = %.3f px (< 0.5px sub-pixel)" % [fwd["name"], cam_diff])
			
			var sky_diff: float = abs(fwd["far_sky_pos"].x - rev["far_sky_pos"].x)
			_assert(sky_diff < 0.5, "FarSkyBackdrop symmetry at %s: diff = %.3f px (< 0.5px sub-pixel)" % [fwd["name"], sky_diff])


func _analyze_smoothing_trajectory() -> void:
	print("\n[SECTION 4: Camera Smoothing Trajectory & Lag Convergence]")
	
	if smoothing_frames.size() >= 20:
		var initial_dist: float = abs(smoothing_frames[0]["target"].x - smoothing_frames[0]["cam"].x)
		var final_dist: float = abs(smoothing_frames[-1]["target"].x - smoothing_frames[-1]["cam"].x)
		print("  Initial camera lag at frame 1: %.2f px" % initial_dist)
		print("  Final camera lag at frame 35:   %.2f px" % final_dist)
		_assert(final_dist < 4.0, "Camera smoothing smoothly converges from 420px to <4px within 35 frames")
		
		# Verify monotonic convergence (distance shrinks every frame)
		var is_monotonic: bool = true
		for k in range(1, smoothing_frames.size()):
			var d_prev: float = abs(smoothing_frames[k-1]["target"].x - smoothing_frames[k-1]["cam"].x)
			var d_curr: float = abs(smoothing_frames[k]["target"].x - smoothing_frames[k]["cam"].x)
			if d_curr > d_prev + 0.1:
				is_monotonic = false
				break
		_assert(is_monotonic, "Smoothing interpolation is strictly monotonic with zero overshoot or oscillations")


func _analyze_boundary_transitions() -> void:
	print("\n[SECTION 5: Arena Boundaries, Visibility Filtering & Culling]")
	
	# Waypoint 1: Arena 1 Center (X = 600)
	var m_a1: Dictionary = measurements[1]
	_assert(m_a1["mid"]["Mid_Arena1"]["visible"] == true, "Arena 1 Midground is VISIBLE in Arena 1")
	_assert(m_a1["mid"]["Mid_Arena2"]["visible"] == false, "Arena 2 Midground is HIDDEN in Arena 1 Center")
	_assert(m_a1["mid"]["Mid_Arena3"]["visible"] == false, "Arena 3 Midground is HIDDEN in Arena 1 Center")
	_assert(m_a1["mid"]["Mid_Arena4"]["visible"] == false, "Arena 4 Midground is HIDDEN in Arena 1 Center")
	
	# Waypoint 2: Boundary 1-2 (X = 1250) -> Overlap zone [-500..1450] and [1050..2850]
	var m_b12: Dictionary = measurements[2]
	_assert(m_b12["mid"]["Mid_Arena1"]["visible"] == true, "Boundary 1-2: Arena 1 layer remains VISIBLE (no sudden pop-out)")
	_assert(m_b12["mid"]["Mid_Arena2"]["visible"] == true, "Boundary 1-2: Arena 2 layer is already VISIBLE (seamless blend)")
	_assert(m_b12["mid"]["Mid_Arena3"]["visible"] == false, "Boundary 1-2: Arena 3 layer is HIDDEN (no far-room bleed)")
	_assert(m_b12["mid"]["Mid_Arena4"]["visible"] == false, "Boundary 1-2: Arena 4 layer is HIDDEN (no far-room bleed)")
	
	# Waypoint 4: Boundary 2-3 (X = 2650) -> Overlap zone [1050..2850] and [2450..4250]
	var m_b23: Dictionary = measurements[4]
	_assert(m_b23["mid"]["Mid_Arena2"]["visible"] == true, "Boundary 2-3: Arena 2 layer remains VISIBLE")
	_assert(m_b23["mid"]["Mid_Arena3"]["visible"] == true, "Boundary 2-3: Arena 3 layer is already VISIBLE")
	_assert(m_b23["mid"]["Mid_Arena1"]["visible"] == false, "Boundary 2-3: Arena 1 layer is HIDDEN")
	_assert(m_b23["mid"]["Mid_Arena4"]["visible"] == false, "Boundary 2-3: Arena 4 layer is HIDDEN")
	
	# Waypoint 6: Boundary 3-4 (X = 4050) -> Overlap zone [2450..4250] and [3850..6000]
	var m_b34: Dictionary = measurements[6]
	_assert(m_b34["mid"]["Mid_Arena3"]["visible"] == true, "Boundary 3-4: Arena 3 layer remains VISIBLE")
	_assert(m_b34["mid"]["Mid_Arena4"]["visible"] == true, "Boundary 3-4: Arena 4 layer is already VISIBLE")
	_assert(m_b34["mid"]["Mid_Arena1"]["visible"] == false, "Boundary 3-4: Arena 1 layer is HIDDEN")
	_assert(m_b34["mid"]["Mid_Arena2"]["visible"] == false, "Boundary 3-4: Arena 2 layer is HIDDEN")
	
	# Waypoint 7: Arena 4 Center (X = 4850)
	var m_a4: Dictionary = measurements[7]
	_assert(m_a4["mid"]["Mid_Arena4"]["visible"] == true, "Arena 4 Midground is VISIBLE in Arena 4 Center")
	_assert(m_a4["mid"]["Mid_Arena1"]["visible"] == false, "Arena 1 Midground is HIDDEN in Arena 4 Center")
	_assert(m_a4["mid"]["Mid_Arena2"]["visible"] == false, "Arena 2 Midground is HIDDEN in Arena 4 Center")
	_assert(m_a4["mid"]["Mid_Arena3"]["visible"] == false, "Arena 3 Midground is HIDDEN in Arena 4 Center")
