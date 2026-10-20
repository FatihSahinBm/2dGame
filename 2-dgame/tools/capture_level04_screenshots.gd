extends SceneTree

## res://tools/capture_level04_screenshots.gd
## Level 04 gerçek oyun içi ekran görüntülerini alan betik

func _initialize() -> void:
	print("--- CAPTURING LEVEL 04 REAL IN-ENGINE SCREENSHOTS ---")
	root.size = Vector2i(1280, 720)
	var scene_res = load("res://scenes/levels/stoneage/stoneage_04_hunters_traces.tscn")
	if not scene_res:
		push_error("FAIL: Could not load Level 04 scene!")
		quit(1)
		return

	var lvl = scene_res.instantiate()
	root.add_child(lvl)

	# Process frames so tree is completely ready
	for f in range(5):
		await process_frame

	var player = lvl.get_node_or_null("CombatPlayer")
	var cam = player.get_node_or_null("Camera2D") as Camera2D if player else null

	if not player or not cam:
		push_error("FAIL: Player or Camera missing!")
		quit(1)
		return

	var shots = [
		{"name": "screenshot_level04_entry.png", "x": 240.0, "desc": "1. Level 04'e Giriş"},
		{"name": "screenshot_level04_first_clues.png", "x": 1150.0, "desc": "2. İlk Dev Ayak İzi ve Ezilmiş Bitkiler"},
		{"name": "screenshot_level04_shattered_trunk.png", "x": 2080.0, "desc": "3. Kırılmış Gövde, Taze Kıymıklar ve Sürüklenme İzi"},
		{"name": "screenshot_level04_deadfall_hazard.png", "x": 2680.0, "desc": "4. Dengesiz Kütük Tehlikesi ve Parçalanmış Kayalar"},
		{"name": "screenshot_level04_tension_climax.png", "x": 3300.0, "desc": "5. Gerilim Zirvesi, Fosil Kaburga ve Uzaktaki Belirsiz Gölge"},
		{"name": "screenshot_level04_exit_to_05.png", "x": 3880.0, "desc": "6. Level 05'e Açılan Çıkış Geçidi"}
	]

	for shot in shots:
		player.position.x = shot["x"]
		player.position.y = 530.0
		cam.global_position.x = shot["x"]
		cam.global_position.y = 480.0

		# Settle frames for parallax and particles
		for f in range(15):
			await process_frame

		var img = root.get_texture().get_image()
		if img:
			if img.get_size() != Vector2i(1280, 720):
				img.resize(1280, 720, Image.INTERPOLATE_NEAREST)
			img.save_png(shot["name"])
			print("SUCCESS: Captured ", shot["name"], " (", shot["desc"], ")")

	print("--- ALL LEVEL 04 REAL SCREENSHOTS CAPTURED SUCCESSFULLY! ---")
	lvl.queue_free()
	quit(0)
