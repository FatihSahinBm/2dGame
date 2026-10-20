extends SceneTree

## res://tools/capture_level08_screenshots.gd
## Level 08 gerçek oyun içi ekran görüntülerini yakalayan optimize edilmiş betik

func _initialize() -> void:
	print("--- CAPTURING LEVEL 08 REAL IN-ENGINE SCREENSHOTS ---")
	root.size = Vector2i(1280, 720)
	var scene_res = load("res://scenes/levels/stoneage/stoneage_08_first_heart_fragment.tscn")
	if not scene_res:
		push_error("FAIL: Could not load Level 08 scene!")
		quit(1)
		return

	var lvl = scene_res.instantiate()
	root.add_child(lvl)

	for f in range(5):
		await process_frame

	var player = lvl.get_node_or_null("CombatPlayer")
	var cam = player.get_node_or_null("Camera2D") as Camera2D if player else null
	var heart = lvl.get_node_or_null("HeartFragment")
	var rift = lvl.get_node_or_null("TemporalTimeRift")
	var flashback = lvl.get_node_or_null("FlashbackSequence")

	if not player or not cam:
		push_error("FAIL: Player or Camera missing!")
		quit(1)
		return

	# Shot 1: Boss sonrası savaş alanı (Post-boss crater area & fallen cyber-rex)
	player.position.x = 850.0
	player.position.y = 530.0
	cam.global_position.x = 950.0
	cam.global_position.y = 480.0
	for f in range(15):
		await process_frame
	_save_screen("screenshot_level08_aftermath_crater.png", "1. Boss Sonrası Savaş Alanı ve Yenilmiş Siber T-Rex")

	# Shot 2: İlk Kalp Parçasının parıldadığı an (Hovering Heart Fragment above crater)
	player.position.x = 1180.0
	player.position.y = 530.0
	cam.global_position.x = 1350.0
	cam.global_position.y = 470.0
	for f in range(15):
		await process_frame
	_save_screen("screenshot_level08_heart_fragment_hover.png", "2. İlk Kalp Parçasının Krater Üzerinde Parıldaması")

	# Shot 3: Kalp Parçasının toplanması (Pickup burst particles & collection)
	lvl._collect_heart_fragment()
	for f in range(6):
		await process_frame
	_save_screen("screenshot_level08_heart_pickup_sparkle.png", "3. İlk Kalp Parçasının Alınması ve Parçacık Işıltısı")

	# Shot 4: İlk Flashback Sahnesi (1462 Wallachia memory & spectral sword)
	if flashback:
		flashback.visible = true
		var ctrl = flashback.get_node_or_null("Control") as Control
		if ctrl:
			ctrl.modulate.a = 1.0
	for f in range(15):
		await process_frame
	_save_screen("screenshot_level08_flashback_wallachia.png", "4. İlk Flashback: 1462 Eflak Orman Kampı ve Kılıç Ruhu")

	# Shot 5: Zaman Yırtığının Açılması (Time Rift opening with dimensional swirl)
	if flashback:
		flashback.visible = false
	if rift:
		rift.visible = true
		rift.modulate.a = 1.0
		rift.scale = Vector2(1.0, 1.0)
		var rift_part = rift.get_node_or_null("RiftParticles") as CPUParticles2D
		if rift_part:
			rift_part.emitting = true

	cam.global_position.x = 1850.0
	cam.global_position.y = 470.0
	player.position.x = 1680.0
	player.position.y = 530.0
	player.modulate = Color.WHITE
	player.scale = Vector2(1.0, 1.0)
	for f in range(15):
		await process_frame
	_save_screen("screenshot_level08_time_rift_opening.png", "5. Zaman Yırtığının Açılması ve Boyutsal Kararsızlık")

	# Shot 6: Sonraki Çağa Geçiş Anı (Player stepping into the time rift towards Vlad era)
	player.position.x = 1930.0
	player.position.y = 510.0
	for f in range(10):
		await process_frame
	_save_screen("screenshot_level08_era_transition.png", "6. Sonraki Çağa (Eflak Seferi) Geçiş Eşiği")

	print("--- ALL LEVEL 08 REAL SCREENSHOTS CAPTURED SUCCESSFULLY! ---")
	lvl.queue_free()
	quit(0)


func _save_screen(filename: String, desc: String) -> void:
	var img = root.get_texture().get_image()
	if img:
		if img.get_size() != Vector2i(1280, 720):
			img.resize(1280, 720, Image.INTERPOLATE_NEAREST)
		img.save_png(filename)
		print("SUCCESS: Captured ", filename, " (", desc, ")")
