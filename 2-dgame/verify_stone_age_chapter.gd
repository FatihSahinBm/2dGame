@tool
extends SceneTree

const StoryDataLoader = preload("res://scripts/autoloads/story_data_loader.gd")

## res://verify_stone_age_chapter.gd
## Taş Devri Bölümü (M.Ö. 65 Milyon Yıl) — Vadi & T-Rex Boss Arenası Doğrulama Testi.

func _init() -> void:
	print("--- STONE AGE CHAPTER VERIFICATION START ---")

	# 1. Hikaye ve Diyalog Verisi Testi
	var story_data = StoryDataLoader.load_chapter_data(StoryDataLoader.CHAPTER_1_PATH)
	if story_data.is_empty():
		push_error("FAIL: StoryDataLoader failed to load chapter_1_stone_age.json")
		quit(1)
		return
	print("OK: chapter_1_stone_age.json loaded successfully. Chapter ID: ", story_data.get("chapter_id"))
	print("Era: ", story_data.get("era"))

	var intro_dialogues = StoryDataLoader.get_dialogue_sequence("intro_awakening", StoryDataLoader.CHAPTER_1_PATH)
	if intro_dialogues.is_empty():
		push_error("FAIL: intro_awakening dialogue missing")
		quit(1)
		return
	print("OK: Intro awakening dialogues found: ", intro_dialogues.size(), " entries.")

	var trex_enc = StoryDataLoader.get_dialogue_sequence("trex_encounter", StoryDataLoader.CHAPTER_1_PATH)
	if trex_enc.is_empty():
		push_error("FAIL: trex_encounter dialogue missing")
		quit(1)
		return
	print("OK: T-Rex encounter dialogues found: ", trex_enc.size(), " entries.")

	var trex_vic = StoryDataLoader.get_dialogue_sequence("trex_victory", StoryDataLoader.CHAPTER_1_PATH)
	if trex_vic.is_empty():
		push_error("FAIL: trex_victory dialogue missing")
		quit(1)
		return
	print("OK: T-Rex victory dialogues found: ", trex_vic.size(), " entries.")

	# 2. Stage 1 Sahnesi (Prehistoric Valley) Testi
	var stage1_res = load("res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn")
	if not stage1_res:
		push_error("FAIL: Failed to load stage_1_prehistoric_valley.tscn")
		quit(1)
		return
	var stage1 = stage1_res.instantiate()
	root.add_child(stage1)
	print("OK: Stage 1 (Prehistoric Valley) instantiated successfully.")

	var player1 = stage1.get_node_or_null("CombatPlayer")
	var rift1 = stage1.get_node_or_null("DimensionalTimeRift")
	var gate1 = stage1.get_node_or_null("ExitGate")
	var barricade = stage1.get_node_or_null("Environment/DestructibleBarricade")
	var collapse1 = stage1.get_node_or_null("Environment/CollapsingPlat1")

	if not player1 or not rift1 or not gate1 or not barricade or not collapse1:
		push_error("FAIL: Essential nodes missing in Stage 1!")
		quit(1)
		return
	print("OK: Stage 1 essential nodes verified (Player, Rift, Gate, Barricade, Collapsing Platform).")
	stage1.queue_free()

	# 3. Stage 2 Sahnesi (T-Rex Boss Arena) Testi
	var stage2_res = load("res://scenes/levels/stone_age/stage_2_trex_boss_arena.tscn")
	if not stage2_res:
		push_error("FAIL: Failed to load stage_2_trex_boss_arena.tscn")
		quit(1)
		return
	var stage2 = stage2_res.instantiate()
	root.add_child(stage2)
	print("OK: Stage 2 (T-Rex Boss Arena) instantiated successfully.")

	var player2 = stage2.get_node_or_null("CombatPlayer")
	var trex = stage2.get_node_or_null("TrexBoss")
	var heart = stage2.get_node_or_null("HeartPieceVisual")
	var exit_rift = stage2.get_node_or_null("DimensionalTimeRiftExit")
	var boss_ui = stage2.get_node_or_null("UI/BossHealthPanel")

	if not player2 or not trex or not heart or not exit_rift or not boss_ui:
		push_error("FAIL: Essential nodes missing in Stage 2!")
		quit(1)
		return
	print("OK: Stage 2 essential nodes verified (Player, TrexBoss, HeartPieceVisual, ExitRift, BossUI).")
	stage2.queue_free()

	print("--- STONE AGE CHAPTER VERIFICATION PASSED SUCCESSFULLY! ---")
	quit(0)
