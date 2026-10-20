@tool
extends SceneTree

func _init() -> void:
	print("--- STONE AGE LEVEL 01 (TIME RIFT FALL) TEST START ---")

	var scene_path = "res://scenes/levels/stoneage/stoneage_01_time_rift_fall.tscn"
	var scene_res = load(scene_path)
	if not scene_res:
		push_error("FAIL: Could not load " + scene_path)
		quit(1)
		return
	print("OK: Scene resource loaded successfully.")

	var lvl = scene_res.instantiate()
	root.add_child(lvl)
	print("OK: Level 01 instantiated and added to tree.")

	# 1. Essential Node Verification
	var player = lvl.get_node_or_null("CombatPlayer")
	var rift = lvl.get_node_or_null("TemporalTimeRift")
	var rift_sprite = lvl.get_node_or_null("TemporalTimeRift/RiftSprite")
	var parallax = lvl.get_node_or_null("ParallaxBackdrop")
	var exit_zone = lvl.get_node_or_null("Environment/ExitZone")
	var ground_start = lvl.get_node_or_null("Environment/GroundStart")
	var ground_mid = lvl.get_node_or_null("Environment/GroundMid")
	var ground_exit = lvl.get_node_or_null("Environment/GroundExit")
	var platform_ledge = lvl.get_node_or_null("Environment/PlatformLedge")
	var dust = lvl.get_node_or_null("Effects/ImpactDustParticles")
	var debris = lvl.get_node_or_null("Effects/ImpactDebrisParticles")
	var hud = lvl.get_node_or_null("FantasyHUD")

	if not player:
		push_error("FAIL: CombatPlayer missing!")
		quit(1)
		return
	if not rift or not rift_sprite:
		push_error("FAIL: TemporalTimeRift missing!")
		quit(1)
		return
	if not parallax:
		push_error("FAIL: ParallaxBackdrop missing!")
		quit(1)
		return
	if not exit_zone or not ground_start or not ground_mid or not ground_exit or not platform_ledge:
		push_error("FAIL: Environmental terrain or exit zone missing!")
		quit(1)
		return
	if not dust or not debris:
		push_error("FAIL: Impact effect particles missing!")
		quit(1)
		return
	if not hud:
		push_error("FAIL: FantasyHUD missing!")
		quit(1)
		return

	print("OK: All nodes verified:")
	print("  - TemporalTimeRift at: ", rift.position)
	print("  - CombatPlayer at: ", player.position)
	print("  - ExitZone at: ", exit_zone.position)

	# 2. Test Sequence Signals
	var flags = {
		"landed": false,
		"controls": false,
		"exit": false
	}

	lvl.player_landed.connect(func(): flags["landed"] = true)
	lvl.controls_enabled.connect(func(): flags["controls"] = true)
	lvl.level_exit_reached.connect(func(_p): flags["exit"] = true)

	# Simulate ground landing
	lvl._handle_ground_landing()
	if not flags["landed"]:
		push_error("FAIL: player_landed signal did not fire on landing!")
		quit(1)
		return
	print("OK: Ground impact and landing sequence executed.")

	# Simulate exit zone trigger
	lvl._on_exit_zone_body_entered(player)
	if not flags["exit"]:
		push_error("FAIL: level_exit_reached signal did not fire when entering exit zone!")
		quit(1)
		return
	print("OK: Level 02 exit zone trigger verified.")

	# 3. Simulate physics steps to ensure no crashes
	for i in range(15):
		lvl._physics_process(0.0166)

	print("OK: Physics simulation steps completed with no errors.")
	lvl.queue_free()
	print("--- STONE AGE LEVEL 01 TESTS PASSED 100%! ---")
	quit(0)
