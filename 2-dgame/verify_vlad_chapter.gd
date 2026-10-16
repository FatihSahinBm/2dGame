@tool
extends SceneTree

const StoryDataLoader = preload("res://scripts/autoloads/story_data_loader.gd")

## res://verify_vlad_chapter.gd
## Vlad Bölümü (15. Yüzyıl Eflak) - 3 Sahne, Müttefikler, Ahlak ve Hikaye Doğrulama Testi.

func _init() -> void:
	print("--- VLAD CHAPTER VERIFICATION START ---")

	# 1. Hikaye ve Diyalog Verisi Testi
	var story_data = StoryDataLoader.load_chapter_data()
	if story_data.is_empty():
		push_error("FAIL: StoryDataLoader failed to load chapter_2_vlad.json")
		quit(1)
		return
	print("OK: chapter_2_vlad.json loaded successfully. Chapter ID: ", story_data.get("chapter_id"))

	var fatih_dialogues = StoryDataLoader.get_dialogue_sequence("fatih_intro")
	if fatih_dialogues.is_empty():
		push_error("FAIL: fatih_intro dialogue missing")
		quit(1)
		return
	print("OK: Fatih intro dialogues found: ", fatih_dialogues.size(), " entries.")

	var fatih_outro = StoryDataLoader.get_dialogue_sequence("fatih_outro")
	if fatih_outro.is_empty():
		push_error("FAIL: fatih_outro dialogue missing")
		quit(1)
		return
	print("OK: Fatih outro dialogues found: ", fatih_outro.size(), " entries.")

	var betrayal_shout = StoryDataLoader.get_random_shout(true)
	print("OK: Sample betrayal shout: '", betrayal_shout, "'")

	# 2. Müttefik Asker Sahneleri Testi
	var soldier_res = load("res://scenes/allies/ottoman_soldier.tscn")
	if not soldier_res:
		push_error("FAIL: Failed to load ottoman_soldier.tscn")
		quit(1)
		return
	var soldier_inst = soldier_res.instantiate()
	root.add_child(soldier_inst)
	print("OK: ottoman_soldier instantiated. HP: ", soldier_inst.max_health)
	soldier_inst.take_damage(20)
	if soldier_inst.current_health != 70:
		push_error("FAIL: Soldier health should be 70 after 20 damage")
		quit(1)
		return
	print("OK: Soldier took damage correctly.")
	soldier_inst.queue_free()

	var archer_res = load("res://scenes/allies/ottoman_archer.tscn")
	if not archer_res:
		push_error("FAIL: Failed to load ottoman_archer.tscn")
		quit(1)
		return
	var archer_inst = archer_res.instantiate()
	root.add_child(archer_inst)
	print("OK: ottoman_archer instantiated. HP: ", archer_inst.max_health)
	archer_inst.queue_free()

	# 3. Fatih NPC Testi
	var fatih_res = load("res://scenes/allies/fatih_npc.tscn")
	if not fatih_res:
		push_error("FAIL: Failed to load fatih_npc.tscn")
		quit(1)
		return
	var fatih_inst = fatih_res.instantiate()
	root.add_child(fatih_inst)
	print("OK: fatih_npc instantiated. Name: ", fatih_inst.character_name)
	fatih_inst.queue_free()

	# 4. Sahne 1 (Kazıklı Orman & Öncü Kamp) Testi
	var stage1_res = load("res://scenes/levels/vlad/stage_1_forest_camp.tscn")
	if not stage1_res:
		push_error("FAIL: Failed to load stage_1_forest_camp.tscn")
		quit(1)
		return
	var stage1_inst = stage1_res.instantiate()
	root.add_child(stage1_inst)
	print("OK: stage_1_forest_camp instantiated successfully.")
	stage1_inst.queue_free()

	# 5. Sahne 2 (Târgovişte Kale Mahzenleri) Testi
	var stage2_res = load("res://scenes/levels/vlad/stage_2_castle_dungeon.tscn")
	if not stage2_res:
		push_error("FAIL: Failed to load stage_2_castle_dungeon.tscn")
		quit(1)
		return
	var stage2_inst = stage2_res.instantiate()
	root.add_child(stage2_inst)
	print("OK: stage_2_castle_dungeon instantiated successfully.")
	stage2_inst.queue_free()

	# 6. Sahne 3 (Kan Taht Odası & Vlad Arenası) Testi
	var stage3_res = load("res://scenes/levels/vlad/stage_3_throne_room.tscn")
	if not stage3_res:
		push_error("FAIL: Failed to load stage_3_throne_room.tscn")
		quit(1)
		return
	var stage3_inst = stage3_res.instantiate()
	root.add_child(stage3_inst)
	print("OK: stage_3_throne_room instantiated successfully.")
	stage3_inst.queue_free()

	# 7. UI ve Flashback Testi
	var flashback_res = load("res://scenes/ui/flashback_overlay.tscn")
	if not flashback_res:
		push_error("FAIL: Failed to load flashback_overlay.tscn")
		quit(1)
		return
	var fb_inst = flashback_res.instantiate()
	root.add_child(fb_inst)
	print("OK: flashback_overlay instantiated.")
	fb_inst.queue_free()

	print("--- ALL 3 VLAD CHAPTER SCENES, ALLIES, AND MECHANICS VERIFIED WITH 100% SUCCESS ---")
	quit(0)
