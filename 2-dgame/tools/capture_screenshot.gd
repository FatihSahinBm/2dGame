extends SceneTree

func _initialize() -> void:
	print("--- TESTING STAGE 2 PLATFORMS ---")
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/levels/vlad/stage_2_castle_dungeon.tscn").instantiate()
	root.add_child(scene)
	
	# Process multiple frames so shaders, parallax and camera settle
	for i in range(15):
		await process_frame
		
	var img = root.get_texture().get_image()
	if img:
		if img.get_size() != Vector2i(1280, 720):
			img.resize(1280, 720, Image.INTERPOLATE_NEAREST)
		img.save_png("../output/vlad_stage2/stage_2_after.png")
		print("SUCCESS: Saved output/vlad_stage2/stage_2_after.png (1280x720)")
	
	# Verify Platform Collision Integrity
	var entrance = scene.get_node_or_null("Environment/EntranceLedge/CollisionShape2D")
	var mid = scene.get_node_or_null("Environment/MidLedge/CollisionShape2D")
	var upper = scene.get_node_or_null("Environment/UpperCorridor/CollisionShape2D")
	assert(entrance and entrance.shape.size == Vector2(400, 50), "EntranceLedge shape altered!")
	assert(mid and mid.shape.size == Vector2(260, 40), "MidLedge shape altered!")
	assert(upper and upper.shape.size == Vector2(1000, 60), "UpperCorridor shape altered!")
	print("SUCCESS: All Ledge CollisionShapes verified (400x50, 260x40, 1000x60).")

	# Verify Collapsing Platform Collision and Trigger Integrity
	var plat1 = scene.get_node_or_null("Platforms/CollapsingPlat1")
	assert(plat1 != null, "CollapsingPlat1 missing!")
	var plat_col = plat1.get_node_or_null("CollisionShape2D")
	assert(plat_col and plat_col.shape.size == Vector2(160, 20), "CollapsingPlatform shape altered!")
	assert(plat_col.one_way_collision == true, "One way collision altered!")
	var trigger = plat1.get_node_or_null("TriggerArea/CollisionShape2D")
	assert(trigger and trigger.shape.size == Vector2(150, 10), "Trigger shape altered!")
	print("SUCCESS: CollapsingPlatform CollisionShape verified (160x20, one_way=true, trigger=150x10).")

	# Test player on ledge
	var player = scene.get_node_or_null("CombatPlayer")
	assert(player != null, "Player missing!")
	print("SUCCESS: CombatPlayer spawned at: ", player.position)

	# Simulate collapse trigger
	print("Testing collapse trigger mechanics...")
	plat1._on_trigger_body_entered(player)
	assert(plat1._is_triggered == true, "Collapse trigger failed!")
	print("SUCCESS: CollapsingPlatform collapse trigger sequence started.")

	# Clean exit
	quit(0)
