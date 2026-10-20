extends SceneTree

## res://tools/capture_level02_clean.gd
## Level 02 Sessiz Vadi'den taş bloklar ve havada duran platformlar kaldırıldıktan sonra
## gerçek oyun içi ekran görüntülerini yakalayan betik.

func _init() -> void:
	print("--- CAPTURING LEVEL 02 CLEAN NATURAL ENVIRONMENT SCREENSHOTS ---")
	root.size = Vector2i(1280, 720)
	var scene_res = load("res://scenes/levels/stoneage/stoneage_02_silent_valley.tscn")
	if not scene_res:
		push_error("FAIL: Could not load Level 02 scene!")
		quit(1)
		return

	var lvl = scene_res.instantiate()
	root.add_child(lvl)

	for f in range(5):
		await process_frame

	var player = lvl.get_node_or_null("CombatPlayer")
	if not player:
		push_error("FAIL: Player missing!")
		quit(1)
		return

	var cam = player.get_node_or_null("Camera2D") as Camera2D

	if not cam:
		cam = Camera2D.new()
		cam.name = "Camera2D"
		player.add_child(cam)

	var shots = [
		{"name": "screenshot_level02_cleansed_trunk.png", "x": 1120.0, "desc": "1. Doğal Devrik Ağaç Gövdesi ve Eğrelti Otları"},
		{"name": "screenshot_level02_cleansed_valley.png", "x": 2200.0, "desc": "2. Temiz Doğal Vadi Yolu (Taş Yapılar Kaldırıldı)"},
		{"name": "screenshot_level02_cleansed_pass.png", "x": 3300.0, "desc": "3. Çıkışa Doğru Kesintisiz Doğal Orman Yürüyüşü"}
	]

	for shot in shots:
		player.position.x = shot["x"]
		player.position.y = 530.0
		cam.global_position.x = shot["x"]
		cam.global_position.y = 480.0

		for f in range(20):
			await process_frame

		var img = root.get_texture().get_image()
		if img:
			if img.get_size() != Vector2i(1280, 720):
				img.resize(1280, 720, Image.INTERPOLATE_NEAREST)
			img.save_png(shot["name"])
			print("SUCCESS: Captured ", shot["name"], " (", shot["desc"], ")")

	print("--- ALL LEVEL 02 CLEAN SCREENSHOTS CAPTURED SUCCESSFULLY! ---")
	lvl.queue_free()
	quit(0)
