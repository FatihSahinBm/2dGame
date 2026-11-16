extends SceneTree

## res://verify_dynamic_lighting_feedback.gd
## Dinamik 2D Işıklandırma QA Doğrulama Testi (2D-148 Story)
## QA Yorumu: "Çevre ışıklandırması her ne kadar iyi olsa da karakter ışıklandırması
## çevre ışığı ile birleştiğinde çok parlak görünüyor. Bu yüzden karakter ışıklandırması
## yalnızca karanlık ortamlarla sınırlı kalmalı."

func _init() -> void:
	_run_async()

func _run_async() -> void:
	print("\n=== [TEST BAŞLANGICI] 2D-148: Dinamik Karakter Işıklandırması & Çevre Işığı Adaptasyonu ===")
	var total_tests: int = 0
	var passed_tests: int = 0

	# -------------------------------------------------------------
	# 1. TEST: Aydınlık / Gündüz Ortamında Karakter Işığının Kapalı Olması
	# -------------------------------------------------------------
	total_tests += 1
	var player_scene = load("res://scenes/combat/test_player.tscn")
	if not player_scene:
		print("❌ TEST 1 BAŞARISIZ: test_player.tscn yüklenemedi!")
		quit(1)
		return

	var day_root = Node2D.new()
	day_root.name = "DaytimeScene"
	root.add_child(day_root)

	# Zemin ekle (oyuncunun boşluğa düşmesini engellemek için)
	var floor_body = StaticBody2D.new()
	floor_body.name = "TestFloor"
	floor_body.collision_layer = 1
	var floor_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(2000.0, 40.0)
	floor_shape.shape = rect_shape
	floor_shape.position = Vector2(500.0, 320.0)
	floor_body.add_child(floor_shape)
	day_root.add_child(floor_body)

	var player = player_scene.instantiate() as CharacterBody2D
	day_root.add_child(player)
	player.global_position = Vector2(200.0, 300.0)
	
	# Birkaç kare simüle et
	await process_frame
	await physics_frame
	for i in range(5):
		await physics_frame

	var p_light = player.get_node_or_null("PlayerLight") as PointLight2D
	var day_disabled_ok = (p_light != null and (not p_light.enabled or p_light.energy <= 0.005))

	if day_disabled_ok:
		print("✅ TEST 1 GEÇTİ: Aydınlık/gündüz ortamında karakter ışığı tamamen kapalı (enabled: %s, energy: %.3f)." % [
			p_light.enabled, p_light.energy
		])
		passed_tests += 1
	else:
		print("❌ TEST 1 BAŞARISIZ: Aydınlık ortamda karakter ışığı açık kalmış! enabled: %s, energy: %f" % [
			p_light.enabled, p_light.energy
		])
		quit(1)
		return

	# -------------------------------------------------------------
	# 2. TEST: Karanlık Ortamda (Zindan / CanvasModulate) Karakter Işığının Aktifleşmesi
	# -------------------------------------------------------------
	total_tests += 1
	var dark_modulate = CanvasModulate.new()
	dark_modulate.name = "DungeonDarkness"
	dark_modulate.color = Color(0.50, 0.50, 0.58, 1.0) # Zindan koyuluğu
	day_root.add_child(dark_modulate)

	# Simüle et ve ışığın yumuşakça devreye girmesini bekle
	for i in range(50):
		await physics_frame

	var dark_enabled_ok = (p_light.enabled and p_light.energy >= 0.12 and p_light.energy <= 0.45)

	if dark_enabled_ok:
		print("✅ TEST 2 GEÇTİ: Karanlık zindan ortamında karakter ışığı otomatik devreye girdi (enabled: %s, energy: %.3f)." % [
			p_light.enabled, p_light.energy
		])
		passed_tests += 1
	else:
		print("❌ TEST 2 BAŞARISIZ: Karanlık ortamda karakter ışığı açılmadı veya aşırı parlak! enabled: %s, energy: %f" % [
			p_light.enabled, p_light.energy
		])
		quit(1)
		return

	# -------------------------------------------------------------
	# 3. TEST: Meşale/Kamp Ateşi Yakınında Karakter Işığının Kısılması (Aşırı Parlamayı Önleme)
	# -------------------------------------------------------------
	total_tests += 1
	var torch_scene = load("res://scenes/objects/standing_torch_post.tscn")
	var torch = torch_scene.instantiate() as Node2D
	day_root.add_child(torch)
	# Meşaleyi doğrudan oyuncunun yanına koy (30 px mesafe)
	torch.global_position = player.global_position + Vector2(30.0, 0.0)

	for i in range(50):
		await physics_frame

	var energy_near_torch = p_light.energy
	# Çevre ışığı varken karakterin kendi ışığı kısılmış olmalı (< 0.15)
	var dimmed_ok = (energy_near_torch < 0.15)

	if dimmed_ok:
		print("✅ TEST 3 GEÇTİ: Meşale/çevre ışığı yakınına gelindiğinde karakter ışığı kısıldı (energy: %.3f) ve aşırı parlama önlendi." % [
			energy_near_torch
		])
		passed_tests += 1
	else:
		print("❌ TEST 3 BAŞARISIZ: Meşale yanında karakter ışığı kısılmadı! energy: %f" % energy_near_torch)
		quit(1)
		return

	# -------------------------------------------------------------
	# 4. TEST: Meşaleden Uzaklaşıp Zifiri Karanlığa Geçildiğinde Işığın Yeniden Artması
	# -------------------------------------------------------------
	total_tests += 1
	# Oyuncuyu meşaleden 350 px uzağa taşı
	player.global_position = Vector2(800.0, 300.0)

	for i in range(30):
		await physics_frame

	var energy_in_shadows = p_light.energy
	var restored_ok = (p_light.enabled and energy_in_shadows > energy_near_torch and energy_in_shadows >= 0.18)

	if restored_ok:
		print("✅ TEST 4 GEÇTİ: Çevre ışığından uzaklaşılıp karanlığa dönüldüğünde karakter ışığı yumuşakça yeniden güçlendi (energy: %.3f)." % [
			energy_in_shadows
		])
		passed_tests += 1
	else:
		print("❌ TEST 4 BAŞARISIZ: Karanlıkta karakter ışığı yeniden yükselmedi! energy: %f" % energy_in_shadows)
		quit(1)
		return

	day_root.queue_free()

	# -------------------------------------------------------------
	# 5. TEST: Gerçek Oyun Sahnelerinde Otomatik Uyumluluk (Taş Devri vs Eflak Zindanı)
	# -------------------------------------------------------------
	total_tests += 1
	
	# A) Taş Devri Bölüm 1 (Gündüz vadisi -> Kapalı olmalı)
	var stage1_scene = load("res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn")
	var stage1 = stage1_scene.instantiate() as Node2D
	root.add_child(stage1)
	await process_frame
	await physics_frame
	for i in range(5):
		await physics_frame

	var s1_player_light = stage1.get_node_or_null("CombatPlayer/PlayerLight") as PointLight2D
	var s1_day_ok = (s1_player_light != null and (not s1_player_light.enabled or s1_player_light.energy <= 0.005))
	stage1.queue_free()

	# B) Eflak Bölüm 2 (Karanlık Kale Zindanı -> Açık olmalı)
	var dungeon_scene = load("res://scenes/levels/vlad/stage_2_castle_dungeon.tscn")
	var dungeon = dungeon_scene.instantiate() as Node2D
	root.add_child(dungeon)
	await process_frame
	await physics_frame
	for i in range(50):
		await physics_frame

	var dung_player_light = dungeon.get_node_or_null("CombatPlayer/PlayerLight") as PointLight2D
	var dung_dark_ok = (dung_player_light != null and dung_player_light.enabled and dung_player_light.energy > 0.05)
	dungeon.queue_free()

	if s1_day_ok and dung_dark_ok:
		print("✅ TEST 5 GEÇTİ: Gerçek sahnelerde doğrulandı -> Taş Devri gündüzünde karakter ışığı KAPALI, Eflak Zindanında AÇIK.")
		passed_tests += 1
	else:
		print("❌ TEST 5 BAŞARISIZ: Sahne bazlı ışık uyumsuz! s1_day_ok: %s, dung_dark_ok: %s" % [
			s1_day_ok, dung_dark_ok
		])
		quit(1)
		return

	print("\n=== TÜM TESTLER TAMAMLANDI: %d/%d Başarılı ===" % [passed_tests, total_tests])
	quit(0)
