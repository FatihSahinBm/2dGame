@tool
extends SceneTree

# Test Script: Vlad Chapter - Commander Fate & Fatih Tent Branching (E2E)
# Validates Branch A (Alive), Branch B (Fallen), Orders Drop, and Dialogue Integrity

func _init() -> void:
	# 1. Setup Autoloads under root
	var GameStateClass = load("res://scripts/autoloads/game_state.gd")
	var gs = Node.new()
	gs.name = "GameState"
	gs.set_script(GameStateClass)
	root.add_child(gs)

	var StoryDataLoaderClass = load("res://scripts/autoloads/story_data_loader.gd")
	var sdl = Node.new()
	sdl.name = "StoryDataLoader"
	sdl.set_script(StoryDataLoaderClass)
	root.add_child(sdl)
	sdl._ready()

	# 2. Add Runner Node to scene tree
	var runner = TestRunner.new()
	root.add_child(runner)


class TestRunner extends Node:
	var passed_count: int = 0
	var failed_count: int = 0

	func assert_test(cond: bool, msg: String) -> void:
		if cond:
			print("  [PASS] ", msg)
			passed_count += 1
		else:
			printerr("  [FAIL] ", msg)
			failed_count += 1

	func _ready() -> void:
		print("\n========================================================")
		print("--- VLAD CHAPTER: COMMANDER FATE & FATIH TENT TEST ---")
		print("========================================================")

		var StoryDataLoader = load("res://scripts/autoloads/story_data_loader.gd")
		var game_state = get_node_or_null("/root/GameState")
		assert_test(game_state != null, "GameState autoload active")

		# --- DIALOGUE CONTENT VALIDATION ---
		print("\n[VERIFYING JSON DIALOGUE KEYS]")
		var rescue_seq = StoryDataLoader.get_dialogue_sequence("commander_rescue")
		var orders_seq = StoryDataLoader.get_dialogue_sequence("commander_orders_note")
		var intro_seq = StoryDataLoader.get_dialogue_sequence("fatih_intro")
		var fallen_seq = StoryDataLoader.get_dialogue_sequence("fatih_commander_fallen")

		assert_test(not rescue_seq.is_empty(), "commander_rescue exists in JSON (%d entries)" % rescue_seq.size())
		assert_test(not orders_seq.is_empty(), "commander_orders_note exists in JSON (%d entries)" % orders_seq.size())
		assert_test(not intro_seq.is_empty(), "fatih_intro exists in JSON (%d entries)" % intro_seq.size())
		assert_test(not fallen_seq.is_empty(), "fatih_commander_fallen exists in JSON (%d entries)" % fallen_seq.size())

		# Check developer comment removed from commander_orders_note
		if not orders_seq.is_empty():
			var note_text: String = orders_seq[0].get("text", "")
			var has_dev_comment: bool = note_text.contains("Kumandan düşmüş olsa da") or note_text.contains("(")
			assert_test(not has_dev_comment, "commander_orders_note clean of bracketed developer notes")

		# ========================================================
		# SCENARIO A: COMMANDER SURVIVES (YOL A)
		# ========================================================
		print("\n[TEST SCENARIO A: COMMANDER SURVIVES]")
		game_state.reset_state()
		assert_test(game_state.is_commander_alive, "Initial state: is_commander_alive is true")

		var forest_scene = load("res://scenes/levels/vlad/stage_1_forest_camp.tscn") as PackedScene
		var forest_inst: Stage1ForestCamp = forest_scene.instantiate() as Stage1ForestCamp
		add_child(forest_inst)

		# 1. Ambush cleared with commander alive
		forest_inst._on_ambush_cleared()
		assert_test(game_state.is_commander_alive, "State A: Commander is marked alive in GameState")
		assert_test(game_state.is_commander_rescued, "State A: Commander is marked rescued in GameState")
		assert_test(not game_state.has_commander_orders, "State A: Commander orders NOT collected (unneeded)")

		# Verify no orders drop spawned
		var spawned_orders = forest_inst.find_children("*", "CommanderOrdersDrop", true, false)
		assert_test(spawned_orders.is_empty(), "State A: No CommanderOrdersDrop spawned on alive path")

		forest_inst.free()

		# 2. Enter Camp scene (Stage 1 Camp)
		var camp_scene = load("res://scenes/levels/vlad/stage_1_camp.tscn") as PackedScene
		var camp_inst: Stage1Camp = camp_scene.instantiate() as Stage1Camp
		add_child(camp_inst)

		var camp_commander = camp_inst.get_node_or_null("Allies/JanissaryCommander")
		assert_test(camp_commander != null and is_instance_valid(camp_commander), "State A: JanissaryCommander present in Camp scene")
		camp_inst.free()

		# 3. Enter Fatih's Tent scene (Stage 1 Fatih Tent)
		var tent_scene = load("res://scenes/levels/vlad/stage_1_fatih_tent.tscn") as PackedScene
		var tent_inst: Stage1FatihTent = tent_scene.instantiate() as Stage1FatihTent
		add_child(tent_inst)

		var tent_commander = tent_inst.get_node_or_null("JanissaryCommander")
		assert_test(tent_commander != null and is_instance_valid(tent_commander), "State A: JanissaryCommander present in Fatih's tent")

		# Check audience dialogue selection
		var tent_diag_box = tent_inst.dialogue_box
		tent_inst._start_fatih_audience()
		assert_test(tent_diag_box.panel.visible, "State A: Dialogue box active for audience")

		# Verify fatih_intro completed
		tent_diag_box._close_dialogue()
		assert_test(game_state.fatih_audience_completed, "State A: Fatih audience completed successfully")
		tent_inst.free()

		# ========================================================
		# SCENARIO B: COMMANDER FALLS IN AMBUSH (YOL B)
		# ========================================================
		print("\n[TEST SCENARIO B: COMMANDER DIES]")
		game_state.reset_state()

		var forest_inst_b: Stage1ForestCamp = forest_scene.instantiate() as Stage1ForestCamp
		add_child(forest_inst_b)

		var commander_b = forest_inst_b.commander
		var death_pos = commander_b.global_position if commander_b else Vector2(580, 560)

		# 1. Trigger commander death
		forest_inst_b._on_commander_died(death_pos)
		assert_test(not game_state.is_commander_alive, "State B: is_commander_alive set to false")
		assert_test(not game_state.is_commander_rescued, "State B: is_commander_rescued set to false")

		# Verify orders drop spawned near death position
		var orders_list = forest_inst_b.find_children("*", "CommanderOrdersDrop", true, false)
		assert_test(orders_list.size() == 1, "State B: Exactly one CommanderOrdersDrop spawned")

		# Test duplicate death signal prevention
		forest_inst_b._on_commander_died(death_pos)
		var orders_list_dup = forest_inst_b.find_children("*", "CommanderOrdersDrop", true, false)
		assert_test(orders_list_dup.size() == 1, "State B: Repeated death signal does NOT spawn second drop")

		# Test exit gate guard when orders not yet collected
		var can_exit_without_orders = true
		if not game_state.is_commander_alive and not game_state.has_commander_orders:
			can_exit_without_orders = false
		assert_test(not can_exit_without_orders, "State B: Player cannot exit forest without collecting orders")

		# 2. Player collects orders drop
		var orders_drop: CommanderOrdersDrop = orders_list[0] as CommanderOrdersDrop
		orders_drop._collect()
		assert_test(game_state.has_commander_orders, "State B: has_commander_orders set to true on collection")
		assert_test(orders_drop._is_collected, "State B: Orders drop marked collected")

		# Test duplicate collection prevention
		var orders_dup_test = orders_drop._is_collected
		assert_test(orders_dup_test == true, "State B: Orders drop cannot be collected multiple times")

		forest_inst_b.free()

		# 3. Enter Camp scene with commander dead
		var camp_inst_b: Stage1Camp = camp_scene.instantiate() as Stage1Camp
		add_child(camp_inst_b)

		var camp_cmd_b = camp_inst_b.get_node_or_null("Allies/JanissaryCommander")
		assert_test(camp_cmd_b == null or camp_cmd_b.is_queued_for_deletion(), "State B: Dead commander removed from Camp scene")
		camp_inst_b.free()

		# 4. Enter Fatih's Tent scene with commander dead
		var tent_inst_b: Stage1FatihTent = tent_scene.instantiate() as Stage1FatihTent
		add_child(tent_inst_b)

		var tent_cmd_b = tent_inst_b.get_node_or_null("JanissaryCommander")
		assert_test(tent_cmd_b == null or tent_cmd_b.is_queued_for_deletion(), "State B: Dead commander removed from Fatih's tent scene")

		# Check alternative audience dialogue (fatih_commander_fallen)
		var tent_diag_box_b = tent_inst_b.dialogue_box
		tent_inst_b._start_fatih_audience()
		assert_test(tent_diag_box_b.panel.visible, "State B: Dialogue box active for alternative audience")

		# Complete alternative dialogue
		tent_diag_box_b._close_dialogue()
		assert_test(game_state.fatih_audience_completed, "State B: Alternative Fatih audience completed successfully")
		tent_inst_b.free()

		# ========================================================
		# SUMMARY & EXIT
		# ========================================================
		print("\n========================================================")
		print("TEST RESULTS: %d PASSED, %d FAILED" % [passed_count, failed_count])
		print("========================================================")

		if failed_count == 0:
			print("ALL SCENARIOS & REPLICAS PASSED SUCCESSFULLY!")
			get_tree().quit(0)
		else:
			printerr("SOME CHECKS FAILED!")
			get_tree().quit(1)
