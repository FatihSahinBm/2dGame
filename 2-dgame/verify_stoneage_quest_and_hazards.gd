@tool
extends SceneTree

## res://verify_stoneage_quest_and_hazards.gd
## Taş Devri Görev ve Tehlike Sistemi Doğrulama Testi

func _init() -> void:
	print("--- STONE AGE QUEST & HAZARDS VERIFICATION START ---")

	# 1. Hikaye Verisi Doğrulama
	var story_loader = load("res://scripts/autoloads/story_data_loader.gd")
	assert(story_loader != null, "StoryDataLoader could not be loaded")
	var seq = story_loader.get_dialogue_sequence("caveman_encounter")
	assert(seq.size() > 0, "caveman_encounter sequence is missing")
	print("OK: caveman_encounter dialogue loaded with %d entries" % seq.size())
	assert(seq[0].has("choices"), "caveman_encounter must have choices")
	print("OK: caveman choices found: ", seq[0]["choices"].size())

	# 2. Mağara Adamı (Caveman) Sınıfı ve Animasyonları
	var caveman_res = load("res://scenes/characters/caveman.tscn")
	assert(caveman_res != null, "Failed to load caveman.tscn")
	var caveman = caveman_res.instantiate()
	root.add_child(caveman)
	if caveman.has_method("_ensure_nodes"):
		caveman._ensure_nodes()
	print("OK: Caveman instantiated successfully.")
	assert(caveman.anim_sprite != null, "Caveman missing anim_sprite")
	var frames: SpriteFrames = caveman.anim_sprite.sprite_frames
	assert(frames != null, "Caveman missing sprite_frames")
	for anim in ["idle", "walk", "attack", "hurt", "death"]:
		assert(frames.has_animation(anim), "Missing animation: " + anim)
		print("  -> Animation verified: ", anim)

	# Mod geçiş testi
	assert(caveman.mode == caveman.Mode.NPC, "Default mode should be NPC")
	caveman._enter_enemy_mode(false)
	assert(caveman.mode == caveman.Mode.ENEMY, "Should transition to ENEMY mode")
	print("OK: Caveman mode switching (NPC -> ENEMY) verified.")
	caveman.queue_free()

	# 3. Odun Arabası (WoodCart) Doğrulama
	var cart_res = load("res://scenes/objects/wood_cart.tscn")
	assert(cart_res != null, "Failed to load wood_cart.tscn")
	var cart = cart_res.instantiate()
	root.add_child(cart)
	print("OK: WoodCart instantiated successfully.")
	cart.activate_cart()
	assert(cart.is_active == true, "Cart should be active")
	cart.take_damage(25)
	assert(cart.current_health == cart.max_health - 25, "Cart take_damage failed")
	print("OK: WoodCart durability and activation verified.")
	cart.queue_free()

	# 4. Çevresel Tehlikeler (Gayzer & Düşen Kaya) Doğrulama
	var geyser_res = load("res://scenes/hazards/prehistoric_geyser_hazard.tscn")
	assert(geyser_res != null, "Failed to load prehistoric_geyser_hazard.tscn")
	var geyser = geyser_res.instantiate()
	root.add_child(geyser)
	print("OK: PrehistoricGeyserHazard instantiated.")
	geyser._start_telegraph()
	assert(geyser.current_state == geyser.State.TELEGRAPH, "Geyser telegraph state failed")
	geyser._start_eruption()
	assert(geyser.current_state == geyser.State.ERUPTING, "Geyser eruption state failed")
	geyser.queue_free()

	var rock_res = load("res://scenes/hazards/prehistoric_falling_rock.tscn")
	assert(rock_res != null, "Failed to load prehistoric_falling_rock.tscn")
	var rock = rock_res.instantiate()
	root.add_child(rock)
	print("OK: PrehistoricFallingRock instantiated.")
	rock.trigger_hazard()
	assert(rock._is_triggered == true, "Falling rock trigger failed")
	rock.queue_free()

	# 5. Sahne 1 (Stage 1 Prehistoric Valley) Entegrasyon Doğrulama
	var valley_res = load("res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn")
	assert(valley_res != null, "Failed to load stage_1_prehistoric_valley.tscn")
	var valley = valley_res.instantiate()
	root.add_child(valley)
	print("OK: Stage1PrehistoricValley instantiated.")
	var chief = valley.get_node_or_null("TribeCamp/CavemanChief")
	var v_cart = valley.get_node_or_null("Objects/WoodCart")
	assert(chief != null, "TribeCamp/CavemanChief missing in valley")
	assert(v_cart != null, "Objects/WoodCart missing in valley")
	assert(valley.get_node_or_null("Hazards/PrehistoricGeyserHazard") != null, "Geyser hazard missing in valley")
	assert(valley.get_node_or_null("Hazards/PrehistoricFallingRock") != null, "Falling rock hazard missing in valley")
	print("OK: All tribe camp, wood cart and hazard references verified in valley.")
	valley.queue_free()

	print("--- ALL VERIFICATIONS PASSED SUCCESSFULLY (EXIT CODE 0) ---")
	quit(0)

