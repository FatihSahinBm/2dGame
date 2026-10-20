@tool
extends SceneTree

## res://verify_stoneage_level04.gd
## Taş Devri — Bölüm 04: Avcıların İzleri (Hunters' Traces) Doğrulama Testi

func _init() -> void:
	print("--- STONE AGE LEVEL 04 (HUNTERS' TRACES) TEST START ---")

	var scene_path = "res://scenes/levels/stoneage/stoneage_04_hunters_traces.tscn"
	var scene_res = load(scene_path)
	if not scene_res:
		push_error("FAIL: Could not load " + scene_path)
		quit(1)
		return
	print("OK: Level 04 scene resource loaded successfully.")

	var lvl = scene_res.instantiate()
	root.add_child(lvl)
	print("OK: Level 04 instantiated and added to tree.")

	# 1. Temel Düğüm Doğrulaması (Essential Node Verification)
	var player = lvl.get_node_or_null("CombatPlayer")
	var hud = lvl.get_node_or_null("FantasyHUD")
	var parallax = lvl.get_node_or_null("ParallaxBackdrop")
	var exit_zone = lvl.get_node_or_null("Environment/ExitZone")

	var ground_entrance = lvl.get_node_or_null("Environment/GroundEntrance")
	var ground_clue = lvl.get_node_or_null("Environment/GroundClueZone")
	var ground_mid = lvl.get_node_or_null("Environment/GroundMidRidge")
	var ground_hazard = lvl.get_node_or_null("Environment/GroundHazardZone")
	var ground_exit = lvl.get_node_or_null("Environment/GroundExit")

	var ledge_log1 = lvl.get_node_or_null("Environment/LedgeLog1")
	var ledge_rock1 = lvl.get_node_or_null("Environment/LedgeRock1")
	var ledge_log2 = lvl.get_node_or_null("Environment/LedgeLog2")
	var ledge_rock2 = lvl.get_node_or_null("Environment/LedgeRock2")

	var hazard_deadfall = lvl.get_node_or_null("Hazards/UnstableDeadfallHazard")
	var shadow = lvl.get_node_or_null("DistantShadowPresence/ApexDistantShadow")
	var leaves = lvl.get_node_or_null("AtmosphericLeaves")

	var footprint1 = lvl.get_node_or_null("FootprintsAndTraces/ApexFootprint1")
	var ferns1 = lvl.get_node_or_null("FootprintsAndTraces/TrampledCycadFerns1")
	var drag1 = lvl.get_node_or_null("FootprintsAndTraces/ApexDragMark1")
	var snapped_trunk = lvl.get_node_or_null("FootprintsAndTraces/SnappedTrunkProp")
	var rubble = lvl.get_node_or_null("FootprintsAndTraces/ShatteredBoulderRubble")
	var ribcage = lvl.get_node_or_null("FootprintsAndTraces/PrehistoricRibcage")

	if not player:
		push_error("FAIL: CombatPlayer missing in Level 04!")
		quit(1)
		return
	if not hud:
		push_error("FAIL: FantasyHUD missing in Level 04!")
		quit(1)
		return
	if not parallax:
		push_error("FAIL: ParallaxBackdrop missing in Level 04!")
		quit(1)
		return
	if not exit_zone:
		push_error("FAIL: ExitZone missing in Level 04!")
		quit(1)
		return

	if not ground_entrance or not ground_clue or not ground_mid or not ground_hazard or not ground_exit:
		push_error("FAIL: Playable ground segments missing!")
		quit(1)
		return
	if not ledge_log1 or not ledge_rock1 or not ledge_log2 or not ledge_rock2:
		push_error("FAIL: Elevated natural ledges missing!")
		quit(1)
		return
	if not hazard_deadfall:
		push_error("FAIL: UnstableDeadfallHazard missing!")
		quit(1)
		return
	if not shadow or not leaves:
		push_error("FAIL: Atmospheric shadow or falling leaves missing!")
		quit(1)
		return
	if not footprint1 or not ferns1 or not drag1 or not snapped_trunk or not rubble or not ribcage:
		push_error("FAIL: Apex hunter clues and footprints missing!")
		quit(1)
		return

	print("OK: All nodes verified:")
	print("  - CombatPlayer at: ", player.position)
	print("  - ExitZone at: ", exit_zone.position)
	print("  - UnstableDeadfallHazard at: ", hazard_deadfall.position)
	print("  - First Apex Footprint at: ", footprint1.position)
	print("  - Snapped Ancient Trunk at: ", snapped_trunk.position)
	print("  - Prehistoric Ribcage at: ", ribcage.position)
	print("  - Distant Shadow Presence at: ", shadow.position)

	# 2. Sinyal ve Kilometre Taşı Testleri (Signals & Milestones)
	var flags = {
		"footprint": false,
		"trunk": false,
		"deadfall": false,
		"presence": false,
		"exit": false
	}

	lvl.observation_made.connect(func(c_name: String):
		if c_name == "first_giant_footprint":
			flags["footprint"] = true
		elif c_name == "shattered_canopy_trunk":
			flags["trunk"] = true
	)

	lvl.hazard_triggered.connect(func(h_name: String):
		if h_name == "unstable_deadfall":
			flags["deadfall"] = true
	)

	lvl.distant_presence_sensed.connect(func():
		flags["presence"] = true
	)

	lvl.level_exit_reached.connect(func(_p):
		flags["exit"] = true
	)

	if not lvl.player:
		lvl._ensure_node_refs()
		lvl._setup_triggers()

	# Test Footprint Observation
	lvl._on_footprint_zone_body_entered(player)
	if not flags["footprint"]:
		push_error("FAIL: ObservationZoneFootprint did not emit observation_made!")
		quit(1)
		return
	print("OK: Observation Milestone 1 (first_giant_footprint) verified.")

	# Test Snapped Trunk Observation
	lvl._on_trunk_zone_body_entered(player)
	if not flags["trunk"]:
		push_error("FAIL: ObservationZoneTrunk did not emit observation_made!")
		quit(1)
		return
	print("OK: Observation Milestone 2 (shattered_canopy_trunk) verified.")

	# Test Deadfall Hazard Trigger
	lvl._on_deadfall_hazard_body_entered(player)
	if not flags["deadfall"]:
		push_error("FAIL: HazardZoneDeadfall did not emit hazard_triggered!")
		quit(1)
		return
	print("OK: Environmental Hazard (unstable_deadfall) verified.")

	# Test Distant Presence Climax
	lvl._on_presence_zone_body_entered(player)
	if not flags["presence"]:
		push_error("FAIL: ObservationZonePresence did not emit distant_presence_sensed!")
		quit(1)
		return
	print("OK: Tension Climax (distant_presence_sensed) verified.")

	# Test Exit Zone
	lvl._on_exit_zone_body_entered(player)
	if not flags["exit"]:
		push_error("FAIL: ExitZone did not emit level_exit_reached!")
		quit(1)
		return
	print("OK: Level 04 Exit Zone signal verified.")

	# 3. Fizik Adımları Simülasyonu (Physics Simulation)
	for i in range(30):
		player._physics_process(0.0166)

	print("OK: Physics simulation steps completed with no errors.")
	lvl.queue_free()
	print("--- STONE AGE LEVEL 04 TESTS PASSED 100%! ---")
	quit(0)
