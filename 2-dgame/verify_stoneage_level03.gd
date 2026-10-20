@tool
extends SceneTree

func _init() -> void:
	print("--- STONE AGE LEVEL 03 (BROKEN PASS) TEST START ---")

	var scene_path = "res://scenes/levels/stoneage/stoneage_03_broken_pass.tscn"
	var scene_res = load(scene_path)
	if not scene_res:
		push_error("FAIL: Could not load " + scene_path)
		quit(1)
		return
	print("OK: Level 03 scene resource loaded successfully.")

	var lvl = scene_res.instantiate()
	root.add_child(lvl)
	print("OK: Level 03 instantiated and added to tree.")

	# 1. Essential Node Verification
	var player = lvl.get_node_or_null("CombatPlayer")
	var hud = lvl.get_node_or_null("FantasyHUD")
	var parallax = lvl.get_node_or_null("ParallaxBackdrop")
	var exit_zone = lvl.get_node_or_null("Environment/ExitZone")

	var ground_entrance = lvl.get_node_or_null("Environment/GroundEntrance")
	var pillar1 = lvl.get_node_or_null("Environment/PillarStep1")
	var ground_ridge1 = lvl.get_node_or_null("Environment/GroundRidge1")
	var ledge1 = lvl.get_node_or_null("Environment/LedgeStep1")
	var ledge2 = lvl.get_node_or_null("Environment/LedgeStep2")
	var ground_mid = lvl.get_node_or_null("Environment/GroundMid")
	var pillar2 = lvl.get_node_or_null("Environment/PillarStep2")
	var ledge3 = lvl.get_node_or_null("Environment/LedgeStep3")
	var ground_ridge2 = lvl.get_node_or_null("Environment/GroundRidge2")
	var final_ledge = lvl.get_node_or_null("Environment/FinalLedge")
	var ground_exit = lvl.get_node_or_null("Environment/GroundExit")

	var hazard1 = lvl.get_node_or_null("Hazards/FallingRockHazard1")
	var hazard2 = lvl.get_node_or_null("Hazards/FallingRockHazard2")
	var prop_arch = lvl.get_node_or_null("Props/FracturedBridgeArch")
	var prop_boulder = lvl.get_node_or_null("Props/FissuredRockBoulder")
	var dust = lvl.get_node_or_null("AtmosphericDust")

	if not player:
		push_error("FAIL: CombatPlayer missing in Level 03!")
		quit(1)
		return
	if not hud:
		push_error("FAIL: FantasyHUD missing in Level 03!")
		quit(1)
		return
	if not parallax:
		push_error("FAIL: ParallaxBackdrop missing in Level 03!")
		quit(1)
		return
	if not exit_zone:
		push_error("FAIL: ExitZone missing in Level 03!")
		quit(1)
		return

	if not ground_entrance or not pillar1 or not ground_ridge1 or not ledge1 or not ledge2 or not ground_mid:
		push_error("FAIL: First half platforms / terrain missing!")
		quit(1)
		return
	if not pillar2 or not ledge3 or not ground_ridge2 or not final_ledge or not ground_exit:
		push_error("FAIL: Second half platforms / terrain missing!")
		quit(1)
		return
	if not hazard1 or not hazard2:
		push_error("FAIL: Falling rock hazards missing!")
		quit(1)
		return
	if not prop_arch or not prop_boulder or not dust:
		push_error("FAIL: Environmental props / atmospheric dust missing!")
		quit(1)
		return

	print("OK: All nodes verified:")
	print("  - CombatPlayer at: ", player.position)
	print("  - ExitZone at: ", exit_zone.position)
	print("  - FallingRockHazard1 at: ", hazard1.position)
	print("  - FallingRockHazard2 at: ", hazard2.position)
	print("  - FracturedBridgeArch at: ", prop_arch.position)

	# 2. Test Signals & Milestones
	var flags = {
		"hazard_bridge": false,
		"hazard_defile": false,
		"chasm_bridge": false,
		"chasm_final": false,
		"exit": false
	}

	lvl.hazard_encountered.connect(func(h_name: String):
		if h_name == "rock_fall_bridge":
			flags["hazard_bridge"] = true
		elif h_name == "rock_fall_defile":
			flags["hazard_defile"] = true
	)

	lvl.chasm_cleared.connect(func(c_name: String):
		if c_name == "shattered_bridge":
			flags["chasm_bridge"] = true
		elif c_name == "great_chasm":
			flags["chasm_final"] = true
	)

	lvl.level_exit_reached.connect(func(_p):
		flags["exit"] = true
	)

	if not lvl.player or not lvl.hazard1:
		lvl._ensure_node_refs()
		lvl._setup_triggers()

	print("DEBUG: lvl.hazard1 = ", lvl.hazard1, ", is_connected: ", hazard1.rock_triggered.is_connected(lvl._on_hazard1_triggered))

	# Test hazard 1 trigger
	hazard1.trigger_hazard()
	if not flags["hazard_bridge"]:
		push_error("FAIL: Hazard 1 did not emit hazard_encountered!")
		quit(1)
		return
	print("OK: Hazard 1 (rock_fall_bridge) triggered successfully.")

	# Test hazard 2 trigger
	hazard2.trigger_hazard()
	if not flags["hazard_defile"]:
		push_error("FAIL: Hazard 2 did not emit hazard_encountered!")
		quit(1)
		return
	print("OK: Hazard 2 (rock_fall_defile) triggered successfully.")

	# Test chasm cleared bridge
	lvl._on_bridge_chasm_body_entered(player)
	if not flags["chasm_bridge"]:
		push_error("FAIL: Bridge chasm zone did not emit chasm_cleared!")
		quit(1)
		return
	print("OK: Bridge chasm milestone cleared successfully.")

	# Test final chasm cleared
	lvl._on_final_chasm_body_entered(player)
	if not flags["chasm_final"]:
		push_error("FAIL: Final chasm zone did not emit chasm_cleared!")
		quit(1)
		return
	print("OK: Great chasm milestone cleared successfully.")

	# Test exit zone
	lvl._on_exit_zone_body_entered(player)
	if not flags["exit"]:
		push_error("FAIL: level_exit_reached did not fire on exit zone entry!")
		quit(1)
		return
	print("OK: Level 03 Exit zone signal triggered successfully.")

	# 3. Simulate physics steps to ensure stable character movement & hazard falls
	for i in range(30):
		hazard1._physics_process(0.0166)
		hazard2._physics_process(0.0166)
		player._physics_process(0.0166)

	print("OK: Physics simulation steps completed with no errors.")
	lvl.queue_free()
	print("--- STONE AGE LEVEL 03 TESTS PASSED 100%! ---")
	quit(0)
