@tool
extends SceneTree

## res://verify_stoneage_level05.gd
## Taş Devri — Bölüm 05: Zamandan Kopan Parçalar (Temporal Fragments) Doğrulama Testi

func _init() -> void:
	print("--- STONE AGE LEVEL 05 (TEMPORAL FRAGMENTS) TEST START ---")

	var scene_path = "res://scenes/levels/stoneage/stoneage_05_temporal_fragments.tscn"
	var scene_res = load(scene_path)
	if not scene_res:
		push_error("FAIL: Could not load " + scene_path)
		quit(1)
		return
	print("OK: Level 05 scene resource loaded successfully.")

	var lvl = scene_res.instantiate()
	root.add_child(lvl)
	print("OK: Level 05 instantiated and added to tree.")

	# 1. Düğüm Doğrulaması (Node Verification)
	var player = lvl.get_node_or_null("CombatPlayer")
	var hud = lvl.get_node_or_null("FantasyHUD")
	var parallax = lvl.get_node_or_null("ParallaxBackdrop")
	var exit_zone = lvl.get_node_or_null("Environment/ExitZone")

	var g_entrance = lvl.get_node_or_null("Environment/GroundEntrance")
	var g_debris = lvl.get_node_or_null("Environment/GroundFirstDebris")
	var g_joint = lvl.get_node_or_null("Environment/GroundSeveredJointZone")
	var g_fault = lvl.get_node_or_null("Environment/GroundResonanceFault")
	var g_socket = lvl.get_node_or_null("Environment/GroundMassiveSocketZone")

	var l_rock1 = lvl.get_node_or_null("Environment/LedgeRock1")
	var l_girder1 = lvl.get_node_or_null("Environment/LedgeGirderBridge")
	var l_rock2 = lvl.get_node_or_null("Environment/LedgeRock2")
	var l_girder2 = lvl.get_node_or_null("Environment/LedgeGirder2")

	var small_plates = lvl.get_node_or_null("MechanicalRemnants/SmallPlates1")
	var severed_joint = lvl.get_node_or_null("MechanicalRemnants/SeveredJoint1")
	var medium_linkage = lvl.get_node_or_null("MechanicalRemnants/MediumLinkage1")
	var piston = lvl.get_node_or_null("MechanicalRemnants/PistonCasing1")
	var massive_socket = lvl.get_node_or_null("MechanicalRemnants/MassiveArmatureSocket")

	var motes = lvl.get_node_or_null("AtmosphericEffects/TemporalMoteParticles")
	var arcs = lvl.get_node_or_null("AtmosphericEffects/TemporalArcParticles")

	if not player or not hud or not parallax or not exit_zone:
		push_error("FAIL: Essential player, HUD, parallax or exit zone missing in Level 05!")
		quit(1)
		return

	if not g_entrance or not g_debris or not g_joint or not g_fault or not g_socket:
		push_error("FAIL: Playable ground segments missing!")
		quit(1)
		return

	if not l_rock1 or not l_girder1 or not l_rock2 or not l_girder2:
		push_error("FAIL: Natural rock and industrial girder ledges missing!")
		quit(1)
		return

	if not small_plates or not severed_joint or not medium_linkage or not piston or not massive_socket:
		push_error("FAIL: Mechanical remnant props missing!")
		quit(1)
		return

	if not motes or not arcs:
		push_error("FAIL: Temporal atmospheric particles missing!")
		quit(1)
		return

	print("OK: All nodes verified:")
	print("  - CombatPlayer at: ", player.position)
	print("  - ExitZone at: ", exit_zone.position)
	print("  - Embedded Alloy Plates at: ", small_plates.position)
	print("  - Severed Mechanical Joint at: ", severed_joint.position)
	print("  - Industrial Girder Bridge at: ", l_girder1.position)
	print("  - Medium Armature Linkage at: ", medium_linkage.position)
	print("  - Piston Casing at: ", piston.position)
	print("  - Massive Armature Socket at: ", massive_socket.position)

	# 2. Sinyal ve Kilometre Taşı Testleri (Signals & Milestones)
	var flags = {
		"plates": false,
		"joint": false,
		"resonance": false,
		"socket": false,
		"exit": false
	}

	lvl.remnant_discovered.connect(func(r_name: String):
		if r_name == "embedded_alloy_plates":
			flags["plates"] = true
		elif r_name == "severed_mechanical_joint":
			flags["joint"] = true
	)

	lvl.temporal_resonance_triggered.connect(func():
		flags["resonance"] = true
	)

	lvl.massive_socket_observed.connect(func():
		flags["socket"] = true
	)

	lvl.level_exit_reached.connect(func(_p):
		flags["exit"] = true
	)

	if not lvl.player:
		lvl._ensure_node_refs()
		lvl._setup_triggers()

	# Test 1: Small plates discovery
	lvl._on_plates_zone_body_entered(player)
	if not flags["plates"]:
		push_error("FAIL: ObservationZonePlates did not emit remnant_discovered!")
		quit(1)
		return
	print("OK: Milestone 1 (embedded_alloy_plates) verified.")

	# Test 2: Severed joint discovery
	lvl._on_joint_zone_body_entered(player)
	if not flags["joint"]:
		push_error("FAIL: ObservationZoneJoint did not emit remnant_discovered!")
		quit(1)
		return
	print("OK: Milestone 2 (severed_mechanical_joint) verified.")

	# Test 3: Temporal resonance event
	lvl._on_resonance_zone_body_entered(player)
	if not flags["resonance"]:
		push_error("FAIL: TemporalResonanceZone did not emit temporal_resonance_triggered!")
		quit(1)
		return
	print("OK: Milestone 3 (temporal_resonance_triggered) verified.")

	# Test 4: Massive socket climax
	lvl._on_socket_zone_body_entered(player)
	if not flags["socket"]:
		push_error("FAIL: ObservationZoneSocket did not emit massive_socket_observed!")
		quit(1)
		return
	print("OK: Milestone 4 (massive_socket_observed) verified.")

	# Test 5: Exit zone
	lvl._on_exit_zone_body_entered(player)
	if not flags["exit"]:
		push_error("FAIL: ExitZone did not emit level_exit_reached!")
		quit(1)
		return
	print("OK: Level 05 Exit Zone signal verified.")

	# 3. Fizik Adımları Simülasyonu
	for i in range(30):
		player._physics_process(0.0166)

	print("OK: Physics simulation steps completed with no errors.")
	lvl.queue_free()
	print("--- STONE AGE LEVEL 05 TESTS PASSED 100%! ---")
	quit(0)
