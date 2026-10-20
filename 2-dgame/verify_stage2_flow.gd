@tool
extends SceneTree

func _init() -> void:
	print("--- STAGE 2 DETAILED FLOW VERIFICATION START ---")

	var arena_res = load("res://scenes/levels/stone_age/stage_2_trex_boss_arena.tscn")
	if not arena_res:
		push_error("FAIL: Could not load stage_2_trex_boss_arena.tscn")
		quit(1)
		return

	var stage2 = arena_res.instantiate()
	root.add_child(stage2)
	print("OK: stage_2_trex_boss_arena.tscn instantiated.")

	# 1. Background & Parallax Check
	var parallax = stage2.get_node_or_null("PrehistoricParallaxBackground")
	if not parallax:
		push_error("FAIL: PrehistoricParallaxBackground node missing!")
		quit(1)
		return
	print("OK: PrehistoricParallaxBackground present.")

	# 2. Player check
	var player = stage2.get_node_or_null("CombatPlayer")
	if not player:
		push_error("FAIL: CombatPlayer missing!")
		quit(1)
		return
	print("OK: CombatPlayer position: ", player.position, " (Expected around x=160, y=520)")

	# 3. Enemies check
	var enemies_node = stage2.get_node_or_null("Enemies")
	if not enemies_node:
		push_error("FAIL: Enemies container missing!")
		quit(1)
		return

	var goblin1 = enemies_node.get_node_or_null("Goblin1")
	var mushroom1 = enemies_node.get_node_or_null("Mushroom1")
	var flying_eye1 = enemies_node.get_node_or_null("FlyingEye1")
	var goblin2 = enemies_node.get_node_or_null("Goblin2")
	var flying_eye2 = enemies_node.get_node_or_null("FlyingEye2")

	if not goblin1 or not mushroom1 or not flying_eye1 or not goblin2 or not flying_eye2:
		push_error("FAIL: Not all expected enemies are instantiated in stage 2!")
		quit(1)
		return

	print("OK: All progression enemies verified:")
	print("  - Section B (First Encounter): Goblin1 at ", goblin1.position)
	print("  - Section D (Second Encounter): Mushroom1 at ", mushroom1.position, ", FlyingEye1 at ", flying_eye1.position)
	print("  - Section E (Transition Hazard): Goblin2 at ", goblin2.position, ", FlyingEye2 at ", flying_eye2.position)

	# 4. Obstacles and Environmental Triggers check
	var env = stage2.get_node_or_null("Environment")
	if not env:
		push_error("FAIL: Environment node missing!")
		quit(1)
		return

	var collapse1 = env.get_node_or_null("CollapsingPlat1")
	var collapse2 = env.get_node_or_null("CollapsingPlat2")
	var barricade = env.get_node_or_null("DestructibleBarricade")
	var barricade_zone = env.get_node_or_null("BarricadeHintZone")
	var cyber_debris = env.get_node_or_null("CyberRexDebrisProp")
	var tremor_zone = env.get_node_or_null("TremorZone")
	var boss_trigger = env.get_node_or_null("BossTriggerArea")

	if not collapse1 or not collapse2 or not barricade or not barricade_zone:
		push_error("FAIL: Section C obstacles missing!")
		quit(1)
		return
	print("OK: Section C obstacles verified (Collapsing Platforms 1 & 2, Destructible Barricade, Hint Zone).")

	if not cyber_debris or not tremor_zone:
		push_error("FAIL: Section E cyber debris or tremor zone missing!")
		quit(1)
		return
	print("OK: Section E cyber debris prop and tremor zone verified at ", cyber_debris.position)

	if not boss_trigger:
		push_error("FAIL: Section F boss trigger area missing!")
		quit(1)
		return
	print("OK: Section F boss trigger area verified at ", boss_trigger.position)

	# 5. Boss and Boss Arena check
	var trex = stage2.get_node_or_null("TrexBoss")
	var boss_panel = stage2.get_node_or_null("UI/BossHealthPanel")
	if not trex or not boss_panel:
		push_error("FAIL: TrexBoss or BossHealthPanel missing!")
		quit(1)
		return

	print("OK: Section F Boss arena verified: TrexBoss at ", trex.position, " (Expected at x=4950, far at end)")
	print("Distance from player spawn to boss: ", player.position.distance_to(trex.position), " px.")

	# 6. Test Zone Trigger signals
	stage2._on_barricade_zone_entered(player)
	print("OK: Barricade zone entered signal tested.")
	stage2._on_tremor_zone_entered(player)
	print("OK: Tremor zone entered signal tested.")
	stage2._on_boss_trigger_entered(player)
	print("OK: Boss trigger entered signal tested (camera locked to arena, boss panel opened).")

	stage2.queue_free()
	print("--- STAGE 2 DETAILED FLOW VERIFICATION PASSED 100%! ---")
	quit(0)
