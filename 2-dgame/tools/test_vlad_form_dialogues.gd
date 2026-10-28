@tool
extends SceneTree

# Test Script: Vlad Boss Form Dialogue Integration & Battle Safety
# Comprehensive Automated Test for Section 7 (9 Test Items)

func _init() -> void:
	# 1. Autoloads setup under root
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
		print("--- VLAD BOSS FORM DIALOGUE INTEGRATION TEST (E2E) ---")
		print("========================================================")

		var StoryDataLoader = load("res://scripts/autoloads/story_data_loader.gd")

		var vampire_seq = StoryDataLoader.get_dialogue_sequence("vlad_taunt_vampire")
		var werewolf_seq = StoryDataLoader.get_dialogue_sequence("vlad_taunt_werewolf")
		var bat_seq = StoryDataLoader.get_dialogue_sequence("vlad_taunt_bat")
		var intro_seq = StoryDataLoader.get_dialogue_sequence("vlad_taunt")

		assert_test(not vampire_seq.is_empty(), "vlad_taunt_vampire exists in JSON (%d entries)" % vampire_seq.size())
		assert_test(not werewolf_seq.is_empty(), "vlad_taunt_werewolf exists in JSON (%d entries)" % werewolf_seq.size())
		assert_test(not bat_seq.is_empty(), "vlad_taunt_bat exists in JSON (%d entries)" % bat_seq.size())
		assert_test(not intro_seq.is_empty(), "vlad_taunt (intro) exists in JSON (%d entries)" % intro_seq.size())

		var throne_scene = load("res://scenes/levels/vlad/stage_3_throne_room.tscn") as PackedScene
		assert_test(throne_scene != null, "stage_3_throne_room.tscn loaded")
		if not throne_scene:
			get_tree().quit(1)
			return

		var throne_inst: Stage3ThroneRoom = throne_scene.instantiate() as Stage3ThroneRoom
		add_child(throne_inst)

		var boss = throne_inst.vlad_boss
		var player = throne_inst.player
		var dialogue_box = throne_inst.dialogue_box

		assert_test(boss != null, "VladBoss instance found and initialized")
		assert_test(player != null, "CombatPlayer instance found and initialized")
		assert_test(dialogue_box != null, "DialogueBox instance found and initialized")

		if not boss or not player or not dialogue_box:
			throne_inst.free()
			get_tree().quit(1)
			return

		# 1. Boss starts in Human form (VladForm.NORMAL = 0)
		assert_test(boss.current_form == 0, "Boss starts in Human form (NORMAL = 0)")
		assert_test(throne_inst._current_dialogue_state == "intro", "Intro dialogue state initialized to 'intro'")

		# 6. Dialogue Safety: No unfair damage during dialogue/cinematics
		var initial_boss_hp = boss.current_health
		var initial_player_hp = player.current_health

		boss.take_damage(20)
		assert_test(boss.current_health == initial_boss_hp, "Boss takes NO damage during dialogue/cinematic (HP: %d/%d)" % [boss.current_health, initial_boss_hp])
		assert_test(not boss.is_active, "Boss is_active is false during cinematic")

		player.take_damage(20)
		assert_test(player.current_health == initial_player_hp, "Player takes NO damage during dialogue/cinematic (HP: %d/%d)" % [player.current_health, initial_player_hp])

		# 7. Complete intro dialogue via dialogue_box close
		dialogue_box._close_dialogue()
		assert_test(throne_inst._current_dialogue_state == "none", "Dialogue state reset to 'none' after intro")
		assert_test(not throne_inst._is_intro_dialogue, "Intro dialogue flag unset")
		assert_test(boss.is_active, "Boss resumes activity (is_active = true) after dialogue completes")

		# 8. Form phase thresholds & HP gating
		boss.take_damage(200) # (600 - 200 = 400 < 450)
		assert_test(boss.current_health == 450, "Human form health correctly gated at 75%% (450 HP), current: %d" % boss.current_health)

		# 2 & 5. Transition to Vampire form (Form 1)
		boss.set_form(1, false)
		assert_test(boss.current_form == 1, "Boss switched to Vampire form (form 1)")
		assert_test(throne_inst._played_form_taunts.get(1, false) == true, "Vampire form taunt marked as played")

		throne_inst._play_form_taunt("vlad_taunt_vampire")
		assert_test(throne_inst._current_dialogue_state == "form_change", "State transitioned to 'form_change' for vampire taunt")
		assert_test(dialogue_box.panel.visible, "DialogueBox UI visible during vampire taunt")

		dialogue_box._close_dialogue()
		assert_test(throne_inst._current_dialogue_state == "none", "Dialogue state reset to 'none' after vampire taunt")
		assert_test(boss.is_active, "Boss resumed active combat after vampire taunt")

		# Test duplicate signal prevention (Item 5)
		var prev_state = throne_inst._current_dialogue_state
		throne_inst._on_vlad_form_changed(1)
		assert_test(throne_inst._current_dialogue_state == prev_state, "Repeated form_changed(1) does not re-open dialogue")

		# Vampire HP gating at 50% (300 HP)
		boss.break_blood_shield()
		boss._mist_dash_cooldown = 5.0 # Prevent 35% random mist evasion during deterministic gate test
		boss.take_damage(200) # 450 - 200 = 250 < 300
		assert_test(boss.current_health == 300, "Vampire form health gated at 50%% (300 HP), current: %d" % boss.current_health)

		# 3. Werewolf Form (Form 2)
		boss.set_form(2, false)
		assert_test(boss.current_form == 2, "Boss switched to Werewolf form (form 2)")
		assert_test(throne_inst._played_form_taunts.get(2, false) == true, "Werewolf form taunt marked as played")

		throne_inst._play_form_taunt("vlad_taunt_werewolf")
		assert_test(throne_inst._current_dialogue_state == "form_change", "State transitioned to 'form_change' for werewolf taunt")
		dialogue_box._close_dialogue()
		assert_test(throne_inst._current_dialogue_state == "none", "Dialogue state reset after werewolf taunt")
		assert_test(boss.is_active, "Boss resumed after werewolf taunt")

		# Werewolf HP gating at 25% (150 HP)
		boss.take_damage(200) # 300 - 200 = 100 < 150
		assert_test(boss.current_health == 150, "Werewolf form health gated at 25%% (150 HP), current: %d" % boss.current_health)

		# 4. Bat Form (Form 3)
		boss.set_form(3, false)
		assert_test(boss.current_form == 3, "Boss switched to Bat form (form 3)")
		assert_test(throne_inst._played_form_taunts.get(3, false) == true, "Bat form taunt marked as played")

		throne_inst._play_form_taunt("vlad_taunt_bat")
		assert_test(throne_inst._current_dialogue_state == "form_change", "State transitioned to 'form_change' for bat taunt")
		dialogue_box._close_dialogue()
		assert_test(throne_inst._current_dialogue_state == "none", "Dialogue state reset after bat taunt")

		# 9. Boss death in bat form & outro isolation
		boss.take_damage(150) # 150 - 150 = 0 HP
		assert_test(boss.current_health <= 0, "Bat form reaches 0 HP upon final blow")
		assert_test(boss.is_dead, "Boss is_dead flag set")

		throne_inst._on_vlad_boss_defeated()
		assert_test(throne_inst._boss_defeated, "Stage acknowledges _boss_defeated")

		throne_inst._on_flashback_finished()
		assert_test(throne_inst._current_dialogue_state == "outro", "State set to 'outro' on Fatih entrance")

		dialogue_box._close_dialogue()
		assert_test(boss.is_dead, "Boss remains dead after outro completed")

		print("\n========================================================")
		print("TEST RESULTS: %d PASSED, %d FAILED" % [passed_count, failed_count])
		print("========================================================")

		throne_inst.free()
		if failed_count == 0:
			print("ALL 9 REQUIRED VERIFICATIONS PASSED SUCCESSFULLY!")
			get_tree().quit(0)
		else:
			printerr("SOME CHECKS FAILED!")
			get_tree().quit(1)
