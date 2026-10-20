extends SceneTree

## res://tools/capture_level06_screenshots.gd
## Level 06 gerçek oyun içi ekran görüntülerini alan betik

func _initialize() -> void:
	print("--- CAPTURING LEVEL 06 REAL IN-ENGINE SCREENSHOTS ---")
	root.size = Vector2i(1280, 720)
	var scene_res = load("res://scenes/levels/stoneage/stoneage_06_beasts_domain.tscn")
	if not scene_res:
		push_error("FAIL: Could not load Level 06 scene!")
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
		{"name": "screenshot_level06_entrance.png", "x": 260.0, "desc": "1. Level 06 Başlangıç Alanı ve Devasa Çevre"},
		{"name": "screenshot_level06_colossal_scale.png", "x": 780.0, "desc": "2. Büyük Çevre Ölçeğini Gösteren Kırık Dev Ağaç ve Fosil Platform"},
		{"name": "screenshot_level06_footprints_debris.png", "x": 1380.0, "desc": "3. Büyük Ayak İzleri, Yıkılmış Gövde ve Titan Kökü"},
		{"name": "screenshot_level06_mechanical_remnants.png", "x": 1820.0, "desc": "4. Mekanik Kalıntılar: Titanyum Pençe ve Kaburga Kümeleri"},
		{"name": "screenshot_level06_nest_approach.png", "x": 2900.0, "desc": "5. Yuva Yaklaşımı, Devasa Çukur ve Bükülmüş Omurga Desteği"},
		{"name": "screenshot_level06_exit_to_07.png", "x": 3950.0, "desc": "6. Level 07 Dev Anne T-Rex Alanına Açılan Çıkış"}
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

	print("--- ALL LEVEL 06 REAL SCREENSHOTS CAPTURED SUCCESSFULLY! ---")
	lvl.queue_free()
	quit(0)
