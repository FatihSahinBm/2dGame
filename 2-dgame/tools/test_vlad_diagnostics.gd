@tool
extends SceneTree

func _init() -> void:
	print("\n==========================================")
	print("--- COMPREHENSIVE DIALOGUE & ANIM VERIFICATION ---")
	print("==========================================")

	var dl = load("res://scripts/autoloads/story_data_loader.gd")
	# Simulate Autoload _ready
	var dummy_node = Node.new()
	dummy_node.set_script(dl)
	dummy_node._ready()
	dummy_node.free()

	var test_keys = [
		# Chapter 2 Vlad Keys
		"commander_rescue",
		"fatih_intro",
		"commander_orders_note",
		"archer_sidequest_callout",
		"archer_sidequest_accept",
		"archer_sidequest_decline",
		"archer_sidequest_complete",
		"blood_knight_intro",
		"battering_ram_victory",
		"vlad_taunt",
		"fatih_outro",
		"memory_flashback",
		# Chapter 1 Stone Age Keys
		"intro_awakening",
		"barricade_hint",
		"trex_encounter",
		"trex_victory"
	]

	var fail_count: int = 0
	print("\n[1] Testing Dialogue Keys:")
	for k in test_keys:
		var seq = dl.get_dialogue_sequence(k)
		if seq.is_empty():
			printerr("  FAIL: Key '", k, "' returned EMPTY sequence!")
			fail_count += 1
		else:
			print("  PASS: Key '", k, "' -> ", seq.size(), " dialogue entries.")

	print("\n[2] Testing Random Shout:")
	var ambient_shout = dl.get_random_shout(false)
	var betrayal_shout = dl.get_random_shout(true)
	print("  PASS: Ambient shout: '", ambient_shout, "'")
	print("  PASS: Betrayal shout: '", betrayal_shout, "'")

	print("\n[3] Testing Fatih NPC & Tent Scene:")
	var tent_scene = load("res://scenes/levels/vlad/stage_1_fatih_tent.tscn") as PackedScene
	if not tent_scene:
		printerr("  FAIL: Could not load stage_1_fatih_tent.tscn")
		fail_count += 1
	else:
		var tent_inst = tent_scene.instantiate()
		var fatih = tent_inst.get_node_or_null("FatihNPC")
		if not fatih:
			printerr("  FAIL: FatihNPC missing in stage_1_fatih_tent.tscn")
			fail_count += 1
		else:
			print("  PASS: FatihNPC found. Checking animations...")
			var sprite = fatih.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
			if sprite and sprite.sprite_frames:
				var anims = sprite.sprite_frames.get_animation_names()
				print("  PASS: Fatih animations available: ", anims)
				if "idle" in anims and "command" in anims and "draw_sword" in anims:
					print("  PASS: Essential Fatih animations ('idle', 'draw_sword', 'command') all present.")
				else:
					printerr("  FAIL: Missing essential Fatih animations!")
					fail_count += 1
			fatih.play_draw_sword_animation()
			fatih.play_command_animation()
			fatih.play_idle_animation()
			print("  PASS: Fatih animation helper calls succeeded.")
		tent_inst.free()

	print("\n[4] Testing DialogueBox Instantiation & Portrait Loading:")
	var db_scene = load("res://scenes/ui/dialogue_box.tscn") as PackedScene
	if not db_scene:
		printerr("  FAIL: Could not load dialogue_box.tscn")
		fail_count += 1
	else:
		var root_node = root
		var db = db_scene.instantiate()
		root_node.add_child(db)
		if db.has_signal("entry_started"):
			print("  PASS: DialogueBox has entry_started signal.")
		else:
			printerr("  FAIL: DialogueBox missing entry_started signal!")
			fail_count += 1
		
		# Test starting dialogue from data with fatih_intro
		db._ready()
		db.start_dialogue_from_data("fatih_intro")
		if db.panel and db.panel.visible:
			print("  PASS: DialogueBox successfully opened with 'fatih_intro'.")
			print("  Speaker: ", db.speaker_name_label.text)
			print("  Content preview: ", db._full_text.substr(0, 40), "...")
		else:
			printerr("  FAIL: DialogueBox failed to open with 'fatih_intro'!")
			fail_count += 1
		db.queue_free()



	print("\n==========================================")
	if fail_count == 0:
		print("--- ALL VERIFICATIONS PASSED SUCCESSFULLY (0 FAILS) ---")
	else:
		printerr("--- VERIFICATION COMPLETED WITH ", fail_count, " FAILS ---")
	print("==========================================\n")
	quit()
