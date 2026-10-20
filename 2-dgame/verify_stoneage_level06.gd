@tool
extends SceneTree

## verify_stoneage_level06.gd
## Automated verification suite for Stone Age Level 06: Dev Yaratığın Bölgesi (The Beast's Domain)

const BeastsDomainScript = preload("res://scripts/levels/stoneage/stoneage_06_beasts_domain.gd")
const ParallaxScript = preload("res://scripts/levels/stoneage/stoneage_06_parallax.gd")

func _init() -> void:
	print("==================================================================")
	print(">>> RUNNING STONE AGE LEVEL 06 VERIFICATION SUITE")
	print("==================================================================")

	var all_passed: bool = true

	# Test 1: Load Scene
	var scene_path: String = "res://scenes/levels/stoneage/stoneage_06_beasts_domain.tscn"
	var packed_scene = load(scene_path) as PackedScene
	if not packed_scene:
		printerr("[FAIL] Could not load scene: ", scene_path)
		quit(1)
		return
	print("[PASS] Level 06 scene loaded successfully.")

	# Test 2: Instantiate Scene
	var instance = packed_scene.instantiate()
	if not instance:
		printerr("[FAIL] Could not instantiate scene: ", scene_path)
		quit(1)
		return
	print("[PASS] Level 06 scene instantiated successfully.")

	# Add to tree to allow ready/setup to run
	root.add_child(instance)
	await process_frame

	# Ensure script is Stoneage06BeastsDomain
	if not (instance is BeastsDomainScript):
		printerr("[FAIL] Root node script is not BeastsDomainScript!")
		all_passed = false
	else:
		print("[PASS] Root script is BeastsDomainScript.")

	# Test 3: Check Essential Nodes
	var player = instance.get_node_or_null("CombatPlayer")
	var hud = instance.get_node_or_null("FantasyHUD")
	var parallax = instance.get_node_or_null("ParallaxBackdrop")
	var env = instance.get_node_or_null("Environment")
	var props = instance.get_node_or_null("PrehistoricForestProps")
	var footprints = instance.get_node_or_null("FootprintsAndTraces")
	var mechs = instance.get_node_or_null("MechanicalRemnants")
	var fx = instance.get_node_or_null("AtmosphericEffects")

	if not player:
		printerr("[FAIL] CombatPlayer node missing!")
		all_passed = false
	else:
		print("[PASS] CombatPlayer present.")

	if not hud:
		printerr("[FAIL] FantasyHUD node missing!")
		all_passed = false
	else:
		print("[PASS] FantasyHUD present.")

	if not parallax or not (parallax is ParallaxScript):
		printerr("[FAIL] ParallaxBackdrop missing or invalid class!")
		all_passed = false
	else:
		print("[PASS] Stoneage06Parallax present and initialized.")

	# Test 4: Check Ground Surfaces & Platforms
	var ground_names = [
		"GroundEntrance", "GroundFirstFootprintZone", "GroundBoneCrushedZone",
		"GroundClawRidgeZone", "GroundNestLairZone", "LedgeFossil1",
		"LedgeTitanRoot1", "LedgeFossil2", "LedgeTitanRoot2"
	]
	for gname in ground_names:
		var gnode = env.get_node_or_null(gname)
		if not gnode:
			printerr("[FAIL] Missing ground/ledge surface: ", gname)
			all_passed = false
		else:
			var col = gnode.get_node_or_null("CollisionShape2D")
			if not col:
				printerr("[FAIL] Surface missing collision shape: ", gname)
				all_passed = false
	print("[PASS] All 9 ground segments and elevated platforms verified with collisions.")

	# Test 5: Check Event Triggers
	var trigger_names = ["FootprintTremorZone", "ObservationZoneClaw", "NestDepressionZone", "ExitZone"]
	for tname in trigger_names:
		var tnode = env.get_node_or_null(tname) as Area2D
		if not tnode:
			printerr("[FAIL] Missing trigger zone: ", tname)
			all_passed = false
		else:
			if tnode.collision_mask & 1 == 0:
				printerr("[FAIL] Trigger does not detect layer 1 (player): ", tname)
				all_passed = false
	print("[PASS] All 4 event and exit trigger areas verified.")

	# Test 6: Check Environmental Props & Mechanical Remnants
	var prop_list = [
		"SnappedGiantTree1", "FallenColossusTrunk1", "GiantRibcageCluster1",
		"BoneHeap1", "ColossalClawScar1", "MassiveSkullFossil1",
		"NestDepressionMound1", "SnappedGiantTree2"
	]
	for pname in prop_list:
		var pnode = props.get_node_or_null(pname)
		if not pnode:
			printerr("[FAIL] Missing prehistoric prop: ", pname)
			all_passed = false
	print("[PASS] All 8 prehistoric trees, bone clusters, and nest props verified.")

	var mech_list = ["HeavyClawSheath", "ReinforcingSpineStrut", "CrackedConduitHousing"]
	for mname in mech_list:
		var mnode = mechs.get_node_or_null(mname)
		if not mnode:
			printerr("[FAIL] Missing mechanical remnant: ", mname)
			all_passed = false
	print("[PASS] All 3 Level 05 continuity mechanical remnants verified.")

	# Test 7: Verify Constraints - NO Boss HP Bar, NO Full Boss Sprite
	var boss_node = instance.find_child("*TRex*", true, false)
	var boss_bar = instance.find_child("*BossBar*", true, false)
	if boss_node:
		printerr("[FAIL] Full boss node detected! Level 06 must NOT contain the full boss!")
		all_passed = false
	else:
		print("[PASS] Constraint met: No full T-Rex boss node in Level 06.")

	if boss_bar:
		printerr("[FAIL] Boss HP bar detected! Level 06 must NOT start boss encounter!")
		all_passed = false
	else:
		print("[PASS] Constraint met: No boss health bar in Level 06.")

	# Test 8: Simulate Trigger Invocations
	var fp_zone = env.get_node_or_null("FootprintTremorZone") as Area2D
	var claw_zone = env.get_node_or_null("ObservationZoneClaw") as Area2D
	var nest_zone = env.get_node_or_null("NestDepressionZone") as Area2D
	var exit_zone = env.get_node_or_null("ExitZone") as Area2D

	var sigs = {"fp": false, "claw": false, "nest": false, "exit": false}

	instance.footprint_tremor_triggered.connect(func(): sigs["fp"] = true)
	instance.mechanical_claw_observed.connect(func(): sigs["claw"] = true)
	instance.nest_depression_reached.connect(func(): sigs["nest"] = true)
	instance.level_exit_reached.connect(func(_p): sigs["exit"] = true)

	instance._on_footprint_zone_body_entered(player)
	instance._on_claw_zone_body_entered(player)
	instance._on_nest_zone_body_entered(player)
	instance._on_exit_zone_body_entered(player)

	if not sigs["fp"] or not sigs["claw"] or not sigs["nest"] or not sigs["exit"]:
		printerr("[FAIL] Signal status - ", sigs)
		all_passed = false
	else:
		print("[PASS] All environmental and narrative signals fired correctly.")

	# Test 9: Camera Configuration
	instance._ensure_node_refs()
	instance._setup_camera()
	var cam = instance._player_camera
	if not cam:
		printerr("[FAIL] Camera could not be retrieved or created!")
		all_passed = false
	else:
		if cam.limit_right != 4200:
			printerr("[FAIL] Camera limit right is unexpected: ", cam.limit_right)
			all_passed = false
		else:
			print("[PASS] Camera configured with bounds: left=", cam.limit_left, " right=", cam.limit_right)

	print("==================================================================")
	if all_passed:
		print(">>> ALL LEVEL 06 TESTS PASSED (100%)")
		print("==================================================================")
		quit(0)
	else:
		printerr(">>> LEVEL 06 VERIFICATION FAILED")
		print("==================================================================")
		quit(1)
