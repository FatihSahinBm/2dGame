extends SceneTree

## res://tools/capture_level05_screenshots.gd
## Level 05 gerçek oyun içi ekran görüntülerini alan betik

func _initialize() -> void:
	print("--- CAPTURING LEVEL 05 REAL IN-ENGINE SCREENSHOTS ---")
	root.size = Vector2i(1280, 720)
	var scene_res = load("res://scenes/levels/stoneage/stoneage_05_temporal_fragments.tscn")
	if not scene_res:
		push_error("FAIL: Could not load Level 05 scene!")
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
		{"name": "screenshot_level05_entrance.png", "x": 240.0, "desc": "1. Level 05 Başlangıç Alanı"},
		{"name": "screenshot_level05_first_plates.png", "x": 1050.0, "desc": "2. İlk Metal Kalıntılar ve Gömülü Plakalar"},
		{"name": "screenshot_level05_severed_joint.png", "x": 1780.0, "desc": "3. Kopmuş Mekanik Eklem ve Kablo Kalıntıları"},
		{"name": "screenshot_level05_temporal_resonance.png", "x": 2520.0, "desc": "4. Zamansal İzler, Kiriş Köprü ve Piston Kovanı"},
		{"name": "screenshot_level05_massive_socket.png", "x": 3280.0, "desc": "5. Devasa Omuz Soketi ve Zamansal Enerji Parıltısı"},
		{"name": "screenshot_level05_exit_to_06.png", "x": 3880.0, "desc": "6. Level 06'ya Doğru Giden Çıkış Boğazı"}
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

	print("--- ALL LEVEL 05 REAL SCREENSHOTS CAPTURED SUCCESSFULLY! ---")
	lvl.queue_free()
	quit(0)
