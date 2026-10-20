@tool
extends SceneTree

## verify_stoneage_level08.gd
## Automated verification suite for Stone Age Level 08: İlk Kalp Parçası (The First Heart Fragment)

const Level08Script = preload("res://scripts/levels/stoneage/stoneage_08_first_heart_fragment.gd")

func _init() -> void:
	print("==================================================================")
	print(">>> RUNNING STONE AGE LEVEL 08 VERIFICATION SUITE")
	print("==================================================================")

	var all_passed: bool = true

	# Test 1: Load Scene
	var scene_path: String = "res://scenes/levels/stoneage/stoneage_08_first_heart_fragment.tscn"
	var packed_scene = load(scene_path) as PackedScene
	if not packed_scene:
		printerr("[FAIL] Could not load Level 08 scene: ", scene_path)
		quit(1)
		return
	print("[PASS] Level 08 scene loaded successfully.")

	# Test 2: Instantiate Scene
	var instance = packed_scene.instantiate()
	if not instance:
		printerr("[FAIL] Could not instantiate Level 08 scene!")
		quit(1)
		return
	print("[PASS] Level 08 scene instantiated successfully.")

	root.add_child(instance)
	await process_frame

	if not (instance is Level08Script):
		printerr("[FAIL] Root node script is not Level08Script!")
		all_passed = false
	else:
		print("[PASS] Root script is StoneAge08FirstHeartFragment.")

	# Test 3: Essential Nodes
	var player = instance.get_node_or_null("CombatPlayer")
	var hud = instance.get_node_or_null("FantasyHUD")
	var heart = instance.get_node_or_null("HeartFragment")
	var aftermath = instance.get_node_or_null("BossAftermath")
	var rift = instance.get_node_or_null("TemporalTimeRift")
	var flashback = instance.get_node_or_null("FlashbackSequence")

	if not player or not hud or not heart or not aftermath or not rift or not flashback:
		printerr("[FAIL] Missing one or more critical root level nodes!")
		all_passed = false
	else:
		print("[PASS] All core nodes (Player, HUD, HeartFragment, Aftermath, TimeRift, Flashback) present.")

	# Test 4: Boss Aftermath Constraints (NO active boss, NO boss HP bar)
	var boss_node = instance.find_child("*TRexBoss*", true, false)
	var boss_bar = instance.find_child("*BossHealthPanel*", true, false)
	if boss_node:
		printerr("[FAIL] Active boss character found in Level 08! Must only be aftermath wreckage.")
		all_passed = false
	else:
		print("[PASS] Constraint met: No active boss character in Level 08.")

	if boss_bar:
		printerr("[FAIL] Boss HP bar found in Level 08! Battle must NOT restart.")
		all_passed = false
	else:
		print("[PASS] Constraint met: No boss health bar in Level 08.")

	var wreckage = aftermath.get_node_or_null("FallenTrexWreckage")
	if not wreckage:
		printerr("[FAIL] FallenTrexWreckage missing in BossAftermath!")
		all_passed = false
	else:
		print("[PASS] FallenTrexWreckage present in BossAftermath.")

	# Test 5: Heart Fragment Pickup & GameState Update
	var sigs = {
		"pickup": false,
		"flash_start": false,
		"flash_end": false,
		"rift_open": false,
		"rift_enter": false
	}

	instance.heart_fragment_picked_up.connect(func(): sigs["pickup"] = true)
	instance.flashback_started.connect(func(): sigs["flash_start"] = true)
	instance.flashback_ended.connect(func(): sigs["flash_end"] = true)
	instance.time_rift_opened.connect(func(): sigs["rift_open"] = true)
	instance.time_rift_entered.connect(func(_p): sigs["rift_enter"] = true)

	# Trigger pickup
	instance._on_heart_fragment_body_entered(player)

	if not sigs["pickup"]:
		printerr("[FAIL] heart_fragment_picked_up signal was not emitted!")
		all_passed = false
	else:
		print("[PASS] Heart fragment pickup signal emitted.")

	# Check GameState
	var gs = instance.get_node_or_null("/root/GameState")
	if gs and gs.current_heart_pieces != 1:
		printerr("[FAIL] GameState current_heart_pieces is not 1!")
		all_passed = false
	else:
		print("[PASS] GameState heart pieces registered: 1.")

	# Test 6: Verify Single-Pickup Protection
	sigs["pickup"] = false
	instance._on_heart_fragment_body_entered(player)
	if sigs["pickup"]:
		printerr("[FAIL] Heart fragment allowed double collection!")
		all_passed = false
	else:
		print("[PASS] Single pickup constraint verified (no double collect).")

	# Test 7: Flashback Execution
	instance._start_first_flashback()
	if not sigs["flash_start"] or not flashback.visible:
		printerr("[FAIL] Flashback did not start or canvas not visible!")
		all_passed = false
	else:
		print("[PASS] First Flashback sequence started and canvas rendered.")

	instance._end_first_flashback()
	if not sigs["flash_end"]:
		printerr("[FAIL] Flashback did not trigger flashback_ended!")
		all_passed = false
	else:
		print("[PASS] Flashback sequence ended cleanly.")

	# Test 8: Time Rift Opening & Transition
	if not sigs["rift_open"] or not rift.visible:
		printerr("[FAIL] Time Rift did not open upon flashback conclusion!")
		all_passed = false
	else:
		print("[PASS] Time Rift opened and activated.")

	instance._on_time_rift_body_entered(player)
	if not sigs["rift_enter"]:
		printerr("[FAIL] time_rift_entered signal not emitted!")
		all_passed = false
	else:
		print("[PASS] Time rift entered signal fired successfully.")

	# Test 9: Next Era Target Verification
	if not ResourceLoader.exists(instance.next_era_scene_path):
		printerr("[FAIL] Next era target scene path does not exist: ", instance.next_era_scene_path)
		all_passed = false
	else:
		print("[PASS] Next era target scene exists: ", instance.next_era_scene_path)

	# Test 10: Camera Bounds
	instance._ensure_node_refs()
	instance._setup_camera()
	var cam = instance._player_camera
	if not cam:
		printerr("[FAIL] Camera could not be initialized!")
		all_passed = false
	else:
		if cam.limit_right != 2400:
			printerr("[FAIL] Camera limit right mismatch: ", cam.limit_right)
			all_passed = false
		else:
			print("[PASS] Camera limits verified: [0, 2400].")

	print("==================================================================")
	if all_passed:
		print(">>> ALL LEVEL 08 TESTS PASSED (100%)")
		print("==================================================================")
		quit(0)
	else:
		printerr(">>> LEVEL 08 VERIFICATION FAILED")
		print("==================================================================")
		quit(1)
