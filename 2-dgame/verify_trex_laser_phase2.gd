extends SceneTree

## res://verify_trex_laser_phase2.gd
## T-Rex Siber Lazer & Faz 2 Mekaniği Otomatik Doğrulama Testi

const CyberLaserSystemScript = preload("res://scripts/enemies/cyber_laser_system.gd")

func _init() -> void:
	_run_async()

func _run_async() -> void:
	print("\n=== [TEST BAŞLANGICI] T-Rex Faz 2 ve Siber Lazer Doğrulaması ===")
	var total_tests: int = 0
	var passed_tests: int = 0

	# 1. TEST: T-Rex Boss Sahnesi ve Bileşenlerinin Yüklenmesi
	total_tests += 1
	var boss_scene = load("res://scenes/enemies/trex_boss.tscn")
	if not boss_scene:
		print("❌ TEST 1 BAŞARISIZ: trex_boss.tscn yüklenemedi!")
		quit(1)
		return

	var boss = boss_scene.instantiate()
	root.add_child(boss)
	await process_frame
	await physics_frame

	var cyber_laser = boss.get_node_or_null("Visual/CyberLaserSystem")
	if cyber_laser != null and cyber_laser is CyberLaserSystemScript:
		print("✅ TEST 1 GEÇTİ: T-Rex boss ve CyberLaserSystem başarıyla yüklendi.")
		passed_tests += 1
	else:
		print("❌ TEST 1 BAŞARISIZ: CyberLaserSystem bulunamadı!")
		quit(1)
		return

	# 2. TEST: Faz 2 Tekrarlanmayan Eşik Kontrolü (<= %60 HP)
	total_tests += 1
	var max_hp = boss.max_health
	var phase_signals: Array = []
	boss.phase_changed.connect(func(p: int): phase_signals.append(p))

	# HP'yi %70'e düşür (Eşik aşılmadı)
	boss.take_damage(int(max_hp * 0.30))
	var phase_after_30pct = boss.boss_phase

	# HP'yi %55'e düşür (Eşik aşıldı, Faz 2 devreye girmeli)
	boss.take_damage(int(max_hp * 0.15))
	var phase_after_45pct = boss.boss_phase
	var p2_triggered = boss._phase_2_triggered

	# HP'yi %45'e düşür (Tekrar Faz 2 tetiklenmemeli)
	boss.take_damage(int(max_hp * 0.10))
	var p2_signal_count = phase_signals.count(2)

	if phase_after_30pct == 1 and phase_after_45pct == 2 and p2_triggered and p2_signal_count == 1:
		print("✅ TEST 2 GEÇTİ: Faz 2 tam olarak <= %60 can eşiğinde ve yalnızca BİR kez tetiklendi.")
		passed_tests += 1
	else:
		print("❌ TEST 2 BAŞARISIZ: Faz geçiş mantığında hata! P1: %d, P2: %d, Tetiklenme Sayısı: %d" % [phase_after_30pct, phase_after_45pct, p2_signal_count])
		quit(1)
		return

	boss.queue_free()
	await process_frame

	# 3. TEST: Bağımsız CyberLaserSystem Engel Algılama & Clamping Testi
	total_tests += 1
	var laser_scene = load("res://scenes/enemies/cyber_laser_system.tscn")
	var laser = laser_scene.instantiate()
	root.add_child(laser)
	laser.global_position = Vector2(100, 200)

	# Engel olarak statik bir gövde yerleştir (Layer 1, X = 320, yani mesafe = 220px)
	var obstacle = StaticBody2D.new()
	obstacle.collision_layer = 1
	obstacle.collision_mask = 0
	obstacle.global_position = Vector2(320, 200)
	var obs_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(40, 100)
	obs_shape.shape = rect_shape
	obstacle.add_child(obs_shape)
	root.add_child(obstacle)

	# Fizik döngüsünün engeli ve lazeri kaydetmesi için iki frame bekle
	await process_frame
	await physics_frame
	await physics_frame

	laser._ensure_nodes()
	laser.start_telegraph(1)

	var telegraph_range = laser.current_actual_range
	var is_clamped = telegraph_range < 500.0 and telegraph_range >= 180.0

	laser.fire_laser(1)
	var blast_active = laser.is_active
	var blast_range = laser.current_actual_range

	if is_clamped and blast_active and blast_range == telegraph_range:
		print("✅ TEST 3 GEÇTİ: Lazer telegraph ve ışın boyutu engeli tutarlı şekilde algılayıp mesafeyi sınırladı (Menzil: %.1f px)." % blast_range)
		passed_tests += 1
	else:
		print("❌ TEST 3 BAŞARISIZ: Engel lazeri durduramadı! Telegraph: %.1f, Blast: %.1f" % [telegraph_range, blast_range])
		quit(1)
		return

	# 4. TEST: Siper Arkasındaki Oyuncunun Korunması
	total_tests += 1
	# Siperin arkasındaki hedef oyuncu (X = 420, engel X = 320'nin arkasında)
	var protected_player = CharacterBody2D.new()
	protected_player.add_to_group("player")
	protected_player.collision_layer = 1
	protected_player.global_position = Vector2(420, 200)
	var p_shape = CollisionShape2D.new()
	var p_rect = RectangleShape2D.new()
	p_rect.size = Vector2(32, 64)
	p_shape.shape = p_rect
	protected_player.add_child(p_shape)
	root.add_child(protected_player)

	await physics_frame
	await physics_frame

	# Siper arkasındaki hedef lazer kutusunun içinde kalmamalıdır
	var laser_area = laser.laser_area
	var overlaps = laser_area.get_overlapping_bodies() if laser_area else []
	var protected_in_laser = protected_player in overlaps

	if not protected_in_laser:
		print("✅ TEST 4 GEÇTİ: Siper monolitinin arkasındaki oyuncu lazer etki alanının dışında kaldı (0 Hasar).")
		passed_tests += 1
	else:
		print("❌ TEST 4 BAŞARISIZ: Siper arkasındaki oyuncu korunamadı!")
		quit(1)
		return

	# 5. TEST: Toparlanma Penceresi ve Savunmasızlık Buharı
	total_tests += 1
	laser._on_blast_finished()
	var laser_stopped = not laser.is_active
	var steam_active = laser.exhaust_steam != null and laser.exhaust_steam.emitting

	if laser_stopped and steam_active:
		print("✅ TEST 5 GEÇTİ: Lazer sonrası 1.2s toparlanma buharı ve savunmasızlık penceresi etkinleşti.")
		passed_tests += 1
	else:
		print("❌ TEST 5 BAŞARISIZ: Toparlanma aşaması düzgün başlatılamadı!")
		quit(1)
		return

	laser.queue_free()
	obstacle.queue_free()
	protected_player.queue_free()
	await process_frame

	# 6. TEST: Arena Sahnesi Entegrasyonu (Cover Monoliths & Elevated Platforms)
	total_tests += 1
	var arena_scene = load("res://scenes/levels/stone_age/stage_2_trex_boss_arena.tscn")
	if not arena_scene:
		print("❌ TEST 6 BAŞARISIZ: stage_2_trex_boss_arena.tscn yüklenemedi!")
		quit(1)
		return

	var arena = arena_scene.instantiate()
	root.add_child(arena)
	await process_frame

	var mono_left = arena.get_node_or_null("Environment/CoverMonolithLeft")
	var mono_right = arena.get_node_or_null("Environment/CoverMonolithRight")
	var plat_left = arena.get_node_or_null("Environment/PlatformArenaLeft")
	var plat_high = arena.get_node_or_null("Environment/PlatformArenaCenterHigh")

	if mono_left != null and mono_right != null and plat_left != null and plat_high != null:
		print("✅ TEST 6 GEÇTİ: Arena tasarımı siper monolitleri ve dikey kaçınma platformlarını eksiksiz barındırıyor.")
		passed_tests += 1
	else:
		print("❌ TEST 6 BAŞARISIZ: Arena siper veya platform bileşenleri eksik!")
		quit(1)
		return

	arena.queue_free()

	print("\n=== TÜM TESTLER TAMAMLANDI: %d/%d Başarılı ===" % [passed_tests, total_tests])
	quit(0)
