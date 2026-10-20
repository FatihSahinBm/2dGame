@tool
extends SceneTree

func _init() -> void:
	print("--- STONE AGE LEVEL 02 (SILENT VALLEY) TEST START ---")

	var scene_path = "res://scenes/levels/stoneage/stoneage_02_silent_valley.tscn"
	var scene_res = load(scene_path)
	if not scene_res:
		push_error("FAIL: Could not load " + scene_path)
		quit(1)
		return
	print("OK: Level 02 scene resource loaded successfully.")

	var lvl = scene_res.instantiate()
	root.add_child(lvl)
	print("OK: Level 02 instantiated and added to tree.")

	# 1. Essential Node Verification
	var player = lvl.get_node_or_null("CombatPlayer")
	var hud = lvl.get_node_or_null("FantasyHUD")
	var parallax = lvl.get_node_or_null("ParallaxBackdrop")
	var exit_zone = lvl.get_node_or_null("Environment/ExitZone")
	var obs_trunk = lvl.get_node_or_null("Environment/ObservationZoneTrunk")

	var ground_start = lvl.get_node_or_null("Environment/GroundStart")
	var ground_path1 = lvl.get_node_or_null("Environment/GroundPath1")
	var ground_mid = lvl.get_node_or_null("Environment/GroundMid")
	var ground_pass = lvl.get_node_or_null("Environment/GroundPass")

	var prop_trunk = lvl.get_node_or_null("Props/AncientBrokenTrunk")
	var spores = lvl.get_node_or_null("AmbientSpores")

	if not player:
		push_error("FAIL: CombatPlayer missing in Level 02!")
		quit(1)
		return
	if not hud:
		push_error("FAIL: FantasyHUD missing in Level 02!")
		quit(1)
		return
	if not parallax:
		push_error("FAIL: ParallaxBackdrop missing in Level 02!")
		quit(1)
		return
	if not exit_zone or not ground_start or not ground_path1 or not ground_mid or not ground_pass:
		push_error("FAIL: Environmental terrain or exit zone missing!")
		quit(1)
		return
	if not prop_trunk:
		push_error("FAIL: AncientBrokenTrunk prop missing!")
		quit(1)
		return
	if not spores:
		push_error("FAIL: Atmospheric spore particles missing!")
		quit(1)
		return

	# Verify unnatural stone structures and floating platforms are removed
	var plat1 = lvl.get_node_or_null("Environment/PlatformStep1")
	var plat2 = lvl.get_node_or_null("Environment/PlatformStep2")
	var plat3 = lvl.get_node_or_null("Environment/PlatformStep3")
	var prop_fossils = lvl.get_node_or_null("Props/FossilBoneSlab")
	var prop_boulder = lvl.get_node_or_null("Props/ClawGougeBoulder")
	var prop_sparks = lvl.get_node_or_null("Props/TemporalMicroSparks")

	if plat1 or plat2 or plat3:
		push_error("FAIL: Floating stone platforms should be removed!")
		quit(1)
		return
	if prop_fossils or prop_boulder or prop_sparks:
		push_error("FAIL: Unnatural carved stone structures should be removed!")
		quit(1)
		return

	print("OK: All nodes verified:")
	print("  - CombatPlayer at: ", player.position)
	print("  - ExitZone at: ", exit_zone.position)
	print("  - AncientBrokenTrunk at: ", prop_trunk.position)
	print("  - Unnatural stone structures successfully removed.")

	# 2. Test Signals and Observation Zones
	var obs_points: Array[String] = []
	var flags = { "exit": false }

	lvl.observation_point_reached.connect(func(point_name: String):
		obs_points.append(point_name)
	)
	lvl.level_exit_reached.connect(func(_p):
		flags["exit"] = true
	)

	if not lvl.player:
		lvl._ensure_node_refs()

	# Simulate reaching observation zone trunk
	lvl._on_trunk_zone_body_entered(player)
	if not ("broken_trunk" in obs_points):
		push_error("FAIL: observation_point_reached did not fire for trunk!")
		quit(1)
		return
	print("OK: Observation zone 'broken_trunk' triggered successfully.")

	# Simulate reaching exit zone
	lvl._on_exit_zone_body_entered(player)
	if not flags["exit"]:
		push_error("FAIL: level_exit_reached did not fire on exit zone entry!")
		quit(1)
		return
	print("OK: Level 02 Exit zone signal triggered successfully.")

	# 3. Simulate physics steps to ensure stable character movement & parallax
	for i in range(30):
		player._physics_process(0.0166)

	print("OK: Physics simulation steps completed with no errors.")
	lvl.queue_free()
	print("--- STONE AGE LEVEL 02 TESTS PASSED 100%! ---")
	quit(0)
