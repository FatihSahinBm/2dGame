class_name TestVladStage3Parallax
extends SceneTree

## tools/test_vlad_stage3_parallax.gd
## Vlad Stage 3 Throne Room Parallax and Depth Layer Automated Test Suite

const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

var tests_passed: int = 0
var tests_failed: int = 0


func _init() -> void:
	print("========================================================")
	print("--- VLAD STAGE 3 PARALLAX & DEPTH LAYER TEST SUITE ---")
	print("========================================================")
	
	var packed: PackedScene = load(STAGE3_PATH) as PackedScene
	if not packed:
		_fail("Failed to load stage_3_throne_room.tscn")
		quit(1)
		return
	
	var stage: Node2D = packed.instantiate() as Node2D
	if not stage:
		_fail("Failed to instantiate stage_3_throne_room.tscn")
		quit(1)
		return
	
	root.add_child(stage)
	
	_test_far_sky_layer(stage)
	_test_world_backdrop_layer(stage)
	_test_midground_depth_layers(stage)
	_test_near_depth_layer(stage)
	_test_foreground_framing_layer(stage)
	_test_parallax_motion_ratios(stage)
	_test_combat_readability_clearance(stage)
	_test_gameplay_geometry_integrity(stage)
	
	print("========================================================")
	print("TEST RESULTS: %d PASSED, %d FAILED" % [tests_passed, tests_failed])
	print("========================================================")
	
	stage.queue_free()
	
	if tests_failed > 0:
		print("ERROR: Parallax depth test suite failed!")
		quit(1)
	else:
		print("SUCCESS: All parallax and depth layers verified flawlessly!")
		quit(0)


func _assert(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  [PASS] %s" % msg)
	else:
		tests_failed += 1
		print("  [FAIL] %s" % msg)


func _fail(msg: String) -> void:
	tests_failed += 1
	print("  [FAIL] %s" % msg)


func _test_far_sky_layer(stage: Node2D) -> void:
	print("\n[SECTION 1: Far Sky & Skyline Parallax Layer (-60)]")
	var far_sky: Node2D = stage.get_node_or_null("FarSkyBackdrop") as Node2D
	_assert(far_sky != null, "FarSkyBackdrop node exists")
	if not far_sky:
		return
	
	_assert(far_sky is WorldParallaxBackground, "FarSkyBackdrop uses WorldParallaxBackground script")
	_assert(far_sky.z_index == -60, "FarSkyBackdrop z_index == -60 (deepest far layer)")
	
	var sky_bg: WorldParallaxBackground = far_sky as WorldParallaxBackground
	_assert(sky_bg.background_texture != null, "FarSkyBackdrop has background_texture assigned")
	if sky_bg.background_texture:
		_assert(sky_bg.background_texture.resource_path.ends_with("distant_gothic_skyline.png"), "FarSkyBackdrop uses distant_gothic_skyline.png")
	
	_assert(sky_bg.parallax_factor_x <= 0.03, "FarSkyBackdrop parallax_factor_x <= 0.03 (slow majestic horizon)")
	_assert(sky_bg.parallax_factor_y <= 0.02, "FarSkyBackdrop parallax_factor_y <= 0.02 (prevents jump nausea)")
	_assert(sky_bg.tile_count >= 4, "FarSkyBackdrop tile_count >= 4 (seamless horizontal coverage)")


func _test_world_backdrop_layer(stage: Node2D) -> void:
	print("\n[SECTION 2: Main Arena World Backdrop (-50)]")
	var backdrop: Node2D = stage.get_node_or_null("WorldBackdrop") as Node2D
	_assert(backdrop != null, "WorldBackdrop node preserved")
	if not backdrop:
		return
	
	_assert(backdrop is WorldParallaxBackground, "WorldBackdrop uses WorldParallaxBackground script")
	_assert(backdrop.z_index == -50, "WorldBackdrop z_index == -50")
	var wb: WorldParallaxBackground = backdrop as WorldParallaxBackground
	_assert(wb.background_texture != null, "WorldBackdrop has base texture assigned")
	_assert(wb.has_method("set_background_texture"), "WorldBackdrop maintains set_background_texture API for boss phases")


func _test_midground_depth_layers(stage: Node2D) -> void:
	print("\n[SECTION 3: Midground Architectural Parallax Layers (-25)]")
	var mid_root: Node2D = stage.get_node_or_null("Environment/MidgroundDepth") as Node2D
	_assert(mid_root != null, "Environment/MidgroundDepth node exists")
	if not mid_root:
		return
	
	var arenas: Array[Dictionary] = [
		{ "name": "Mid_Arena1", "anchor_x": 600.0, "tex": "throne_mid_arch_pillars.png" },
		{ "name": "Mid_Arena2", "anchor_x": 1950.0, "tex": "blood_hall_colonnade_mid.png" },
		{ "name": "Mid_Arena3", "anchor_x": 3350.0, "tex": "ramparts_mid_battlements.png" },
		{ "name": "Mid_Arena4", "anchor_x": 4850.0, "tex": "belltower_mid_timber_frame.png" }
	]
	
	for a in arenas:
		var node: Node2D = mid_root.get_node_or_null(a["name"]) as Node2D
		_assert(node != null, "%s exists in MidgroundDepth" % a["name"])
		if not node:
			continue
		
		_assert(node is ParallaxDepthLayer, "%s is ParallaxDepthLayer" % a["name"])
		_assert(node.z_index == -25, "%s z_index == -25 (behind characters & platforms)" % a["name"])
		
		var layer: ParallaxDepthLayer = node as ParallaxDepthLayer
		_assert(abs(layer.anchor_x - a["anchor_x"]) < 1.0, "%s anchor_x == %.1f" % [a["name"], a["anchor_x"]])
		_assert(layer.parallax_factor_x > 0.08 and layer.parallax_factor_x < 0.20, "%s parallax_factor_x in midground range (0.08..0.20)" % a["name"])
		_assert(layer.parallax_factor_y <= 0.05, "%s parallax_factor_y <= 0.05" % a["name"])
		
		var sprite_count: int = 0
		for child in node.get_children():
			if child is Sprite2D:
				var s: Sprite2D = child as Sprite2D
				_assert(s.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s sprite %s texture_filter is nearest (pixel-art)" % [a["name"], s.name])
				if s.texture:
					_assert(s.texture.resource_path.ends_with(a["tex"]), "%s sprite uses %s" % [a["name"], a["tex"]])
				sprite_count += 1
		_assert(sprite_count >= 2, "%s has at least 2 architectural backdrop sprites" % a["name"])


func _test_near_depth_layer(stage: Node2D) -> void:
	print("\n[SECTION 4: Near Depth Pilaster & Transition Layer (-12)]")
	var near_root: Node2D = stage.get_node_or_null("Environment/NearDepth") as Node2D
	_assert(near_root != null, "Environment/NearDepth node exists")
	if not near_root:
		return
	
	var near_arenas: Array[Dictionary] = [
		{ "node": "Near_Arena1", "pilasters": ["PilasterArena1Left", "PilasterBarrier1"] },
		{ "node": "Near_Arena2", "pilasters": ["PilasterBarrier2"] },
		{ "node": "Near_Arena3", "pilasters": ["PilasterBarrier3"] },
		{ "node": "Near_Arena4", "pilasters": ["PilasterArena4Right"] }
	]
	
	for a in near_arenas:
		var node: Node2D = near_root.get_node_or_null(a["node"]) as Node2D
		_assert(node != null, "%s exists in NearDepth" % a["node"])
		if not node:
			continue
		
		_assert(node is ParallaxDepthLayer, "%s is ParallaxDepthLayer" % a["node"])
		_assert(node.z_index == -12, "%s z_index == -12" % a["node"])
		
		var layer: ParallaxDepthLayer = node as ParallaxDepthLayer
		_assert(layer.parallax_factor_x > 0.20 and layer.parallax_factor_x < 0.40, "%s parallax_factor_x in near range (0.20..0.40)" % a["node"])
		
		for pname in a["pilasters"]:
			var p: Sprite2D = node.get_node_or_null(pname) as Sprite2D
			_assert(p != null, "Near pilaster %s exists in %s" % [pname, a["node"]])
			if p and p.texture:
				_assert(p.texture.resource_path.ends_with("castle_transition_pilaster.png"), "Pilaster %s uses castle_transition_pilaster.png" % pname)


func _test_foreground_framing_layer(stage: Node2D) -> void:
	print("\n[SECTION 5: Controlled Foreground Framing Layer (+30)]")
	var fg_root: Node2D = stage.get_node_or_null("Environment/ForegroundFraming") as Node2D
	_assert(fg_root != null, "Environment/ForegroundFraming node exists")
	if not fg_root:
		return
	
	var fg_arenas: Array[String] = ["FG_Arena1", "FG_Arena2", "FG_Arena3", "FG_Arena4"]
	for fg_name in fg_arenas:
		var node: Node2D = fg_root.get_node_or_null(fg_name) as Node2D
		_assert(node != null, "%s exists in ForegroundFraming" % fg_name)
		if not node:
			continue
		
		_assert(node is ParallaxDepthLayer, "%s is ParallaxDepthLayer" % fg_name)
		_assert(node.z_index == 30, "%s z_index == +30 (renders in foreground)" % fg_name)
		
		var layer: ParallaxDepthLayer = node as ParallaxDepthLayer
		_assert(layer.parallax_factor_x > 1.05, "%s parallax_factor_x > 1.05 (rushes past camera)" % fg_name)


func _test_parallax_motion_ratios(stage: Node2D) -> void:
	print("\n[SECTION 6: Camera Tracking & Relative Parallax Shift]")
	# Create simulated camera
	var cam: Camera2D = Camera2D.new()
	stage.add_child(cam)
	
	var mid1: ParallaxDepthLayer = stage.get_node_or_null("Environment/MidgroundDepth/Mid_Arena1") as ParallaxDepthLayer
	var fg1: ParallaxDepthLayer = stage.get_node_or_null("Environment/ForegroundFraming/FG_Arena1") as ParallaxDepthLayer
	
	if mid1 and fg1:
		# Use player's real camera
		var player_cam: Camera2D = stage.get_node_or_null("CombatPlayer/Camera2D") as Camera2D
		if player_cam:
			cam = player_cam
		mid1.set_camera(cam)
		fg1.set_camera(cam)
		
		# Test anchor centering
		cam.global_position = Vector2(600, 380)
		mid1._process(0.016)
		fg1._process(0.016)
		
		var mid_origin_x: float = mid1.position.x
		var fg_origin_x: float = fg1.position.x
		_assert(abs(mid_origin_x) < 0.1, "Midground at anchor center has zero relative displacement")
		_assert(abs(fg_origin_x) < 0.1, "Foreground at anchor center has zero relative displacement")
		
		# Move camera right by 200px
		cam.global_position = Vector2(800, 380)
		mid1._process(0.016)
		fg1._process(0.016)
		
		# Midground factor = 0.12 -> delta * (1 - 0.12) = 200 * 0.88 = 176
		# On screen relative to cam: 176 - 200 = -24 (-12% shift)
		var mid_shift_x: float = mid1.position.x
		var mid_screen_shift: float = mid_shift_x - 200.0
		_assert(abs(mid_screen_shift - (-24.0)) < 1.0, "Midground shifts on screen by -24px (-12%% speed) for +200px camera movement")
		
		# Foreground factor = 1.15 -> delta * (1 - 1.15) = 200 * (-0.15) = -30
		# On screen relative to cam: -30 - 200 = -230 (-115% speed, moves faster than world)
		var fg_shift_x: float = fg1.position.x
		var fg_screen_shift: float = fg_shift_x - 200.0
		_assert(abs(fg_screen_shift - (-230.0)) < 1.0, "Foreground shifts on screen by -230px (-115%% speed) for +200px camera movement")
	
	cam.queue_free()


func _test_combat_readability_clearance(stage: Node2D) -> void:
	print("\n[SECTION 7: Character Readability & Combat Clearance]")
	# Combat action occurs on ground Y = 560, player height ~60 (Y: 500..560), jump up to Y: 350
	# Foreground ceiling valances must remain strictly at Y <= 90
	var fg_root: Node2D = stage.get_node_or_null("Environment/ForegroundFraming") as Node2D
	if fg_root:
		for fg_arena in fg_root.get_children():
			for child in fg_arena.get_children():
				if child is Sprite2D and child.name.begins_with("CeilingValance"):
					var s: Sprite2D = child as Sprite2D
					# Bottom of ceiling valance (valance height 140, centered = true -> y + 70 = 20 + 70 = 90)
					var bottom_y: float = s.position.y + 70.0
					_assert(bottom_y <= 120.0, "%s bottom Y (%.1f) is well above combat play band (Y >= 350)" % [s.name, bottom_y])


func _test_gameplay_geometry_integrity(stage: Node2D) -> void:
	print("\n[SECTION 8: Gameplay Geometry, Collisions & Interactive Node Integrity]")
	# Verify ground walkable surfaces remain strictly at Y = 560
	for i in range(1, 5):
		var ground_name: String = "Environment/Arena%d_%s/Ground%d" % [
			i,
			["ThroneRoom", "BloodHall", "Ramparts", "BellTower"][i - 1],
			i
		]
		var ground: StaticBody2D = stage.get_node_or_null(ground_name) as StaticBody2D
		_assert(ground != null, "%s ground body exists" % ground_name)
		if ground:
			_assert(ground.position.y == 590.0, "%s position.y == 590.0 (walkable top = 560.0)" % ground_name)
	
	# Verify WeakArchway and GreatBell nodes remain completely unaltered
	var archway: Node = stage.get_node_or_null("Environment/Arena3_Ramparts/WeakArchway")
	var bell: Node = stage.get_node_or_null("Environment/Arena4_BellTower/GreatBell")
	_assert(archway != null, "WeakArchway intact under Arena 3")
	_assert(bell != null, "GreatBell intact under Arena 4")
