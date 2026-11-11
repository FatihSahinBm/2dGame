extends SceneTree

## res://verify_stoneage_minions.gd
## Taş Devri Minyonları Doğrulama Testi:
## Raptor (Yakın Dövüş) & Siber Uçan Böcek (Menzilli Uçan Düşman)

func _init() -> void:
	_run_async()

func _run_async() -> void:
	print("\n=== [TEST BAŞLANGICI] Taş Devri Minyonları: Raptor ve Siber Uçan Böcek ===")
	var total_tests: int = 0
	var passed_tests: int = 0

	# -------------------------------------------------------------
	# 1. TEST: Raptor Başlatma ve Özellik Kontrolleri
	# -------------------------------------------------------------
	total_tests += 1
	var raptor_scene = load("res://scenes/enemies/raptor.tscn")
	if not raptor_scene:
		print("❌ TEST 1 BAŞARISIZ: raptor.tscn yüklenemedi!")
		quit(1)
		return
	
	var raptor = raptor_scene.instantiate() as CharacterBody2D
	root.add_child(raptor)
	await process_frame
	await physics_frame

	var r_groups_ok = raptor.is_in_group("enemies") and raptor.is_in_group("damageable")
	var r_hp_ok = raptor.max_health == 110 and raptor.current_health == 110
	var r_col_ok = raptor.collision_layer == 2 and raptor.collision_mask == 1

	if r_groups_ok and r_hp_ok and r_col_ok:
		print("✅ TEST 1 GEÇTİ: Raptor başarıyla yüklendi, canı ve çarpışma katmanları doğrulandı.")
		passed_tests += 1
	else:
		print("❌ TEST 1 BAŞARISIZ: Raptor özelliklerinde tutarsızlık var!")
		quit(1)
		return

	# -------------------------------------------------------------
	# 2. TEST: Raptor Durum Makinesi (Algılama, Yaklaşma, Telegraph, Saldırı, Geri Çekilme)
	# -------------------------------------------------------------
	total_tests += 1
	var dummy_player = Node2D.new()
	dummy_player.name = "CombatPlayer"
	dummy_player.add_to_group("player")
	root.add_child(dummy_player)
	
	raptor.global_position = Vector2(500.0, 500.0)
	dummy_player.global_position = Vector2(700.0, 500.0) # 200px mesafe (detection_range: 340)
	
	raptor._target_node = dummy_player
	raptor.current_state = raptor.State.APPROACH
	raptor.velocity.x = 0.0
	raptor._physics_process(0.1)
	
	var is_approaching = raptor.velocity.x > 0.0 # Oyuncuya doğru koşmalı
	
	# Saldırı menziline sok ve telegraph başlat
	dummy_player.global_position = Vector2(550.0, 500.0) # 50px mesafe (attack_range: 85)
	raptor._attack_timer = 0.0
	raptor._physics_process(0.016)
	
	var is_telegraph = (raptor.current_state == raptor.State.TELEGRAPH)
	
	# Telegraph süresi dolunca saldırıya geçişi simüle et
	raptor._telegraph_timer = 0.0
	raptor._physics_process(0.016)
	var is_attacking = (raptor.current_state == raptor.State.ATTACK)
	var has_leap_vx = (raptor.velocity.x > 0.0)
	
	# Vuruş sonrası geri çekilme (RETREAT)
	raptor._start_retreat()
	var is_retreating = (raptor.current_state == raptor.State.RETREAT)
	var has_retreat_vx = (raptor.velocity.x < 0.0) # Geriye zıplamalı
	
	if is_approaching and is_telegraph and is_attacking and has_leap_vx and is_retreating and has_retreat_vx:
		print("✅ TEST 2 GEÇTİ: Raptor döngüsü (Yaklaşma -> Telegraph -> Atılma Saldırısı -> Geri Çekilme) doğrulandı.")
		passed_tests += 1
	else:
		print("❌ TEST 2 BAŞARISIZ: Raptor durum geçişlerinde hata! app:%s, tele:%s, att:%s, ret:%s" % [
			is_approaching, is_telegraph, is_attacking, is_retreating
		])
		quit(1)
		return

	# -------------------------------------------------------------
	# 3. TEST: Raptor Hasar Tepkisi ve Ölüm
	# -------------------------------------------------------------
	total_tests += 1
	raptor.take_damage(30)
	var hurt_ok = (raptor.current_health == 80 and raptor.current_state == raptor.State.HURT)
	
	raptor.take_damage(100) # Ölümcül hasar
	var dead_ok = (raptor.current_health == 0 and raptor.is_dead and raptor.collision_layer == 0)
	
	if hurt_ok and dead_ok:
		print("✅ TEST 3 GEÇTİ: Raptor hasar tepkisi (HURT/Knockback) ve ölüm davranışı doğrulandı.")
		passed_tests += 1
	else:
		print("❌ TEST 3 BAŞARISIZ: Raptor hasar alma veya ölüm mantığında hata!")
		quit(1)
		return

	raptor.queue_free()

	# -------------------------------------------------------------
	# 4. TEST: Siber Uçan Böcek (Hover, Kiting, Telegraph & Menzilli Saldırı)
	# -------------------------------------------------------------
	total_tests += 1
	var bug_scene = load("res://scenes/enemies/cyber_flying_bug.tscn")
	if not bug_scene:
		print("❌ TEST 4 BAŞARISIZ: cyber_flying_bug.tscn yüklenemedi!")
		quit(1)
		return

	var bug = bug_scene.instantiate() as CharacterBody2D
	root.add_child(bug)
	await process_frame
	await physics_frame

	var bug_groups_ok = bug.is_in_group("enemies") and bug.is_in_group("damageable")
	var bug_floating_ok = (bug.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING)
	
	# Kiting testi (Oyuncu çok yakınsa havada geri çekilmeli)
	bug.global_position = Vector2(500.0, 400.0)
	dummy_player.global_position = Vector2(550.0, 480.0) # 50px mesafe (min_attack_range: 140)
	bug._target_node = dummy_player
	bug.current_state = bug.State.HOVER_ENGAGE
	bug.velocity = Vector2.ZERO
	bug._physics_process(0.1)
	
	var is_kiting = (bug.velocity.x < 0.0) # Oyuncu sağda, böcek sola kaçmalı
	
	# İdeal menzilde nişan ve telegraph testi
	dummy_player.global_position = Vector2(700.0, 475.0) # 200px mesafe (ideal menzil)
	bug._attack_timer = 0.0
	bug._physics_process(0.016)
	
	var bug_telegraph_ok = (bug.current_state == bug.State.TELEGRAPH and bug.laser_aim_line.visible)
	
	# Ateş etme testi (Telegraph -> Shoot -> Reposition)
	bug._telegraph_timer = 0.0
	bug._physics_process(0.016) # TELEGRAPH -> SHOOT
	bug._physics_process(0.016) # SHOOT -> REPOSITION
	var bug_reposition_ok = (bug.current_state == bug.State.REPOSITION and bug._attack_timer > 0.0)

	if bug_groups_ok and bug_floating_ok and is_kiting and bug_telegraph_ok and bug_reposition_ok:
		print("✅ TEST 4 GEÇTİ: Siber Uçan Böcek havada süzülme, kiting, lazer telegraph ve atış döngüsü doğrulandı.")
		passed_tests += 1
	else:
		print("❌ TEST 4 BAŞARISIZ: Siber Uçan Böcek mantığında hata! float:%s, kite:%s, tele:%s, rep:%s" % [
			bug_floating_ok, is_kiting, bug_telegraph_ok, bug_reposition_ok
		])
		quit(1)
		return

	# -------------------------------------------------------------
	# 5. TEST: Siber Enerji Mermisi ve Parry / Yansıtma (Reflection)
	# -------------------------------------------------------------
	total_tests += 1
	var proj_scene = load("res://scenes/projectiles/cyber_energy_projectile.tscn")
	var proj = proj_scene.instantiate() as Area2D
	root.add_child(proj)
	proj.setup(Vector2(200.0, 200.0), Vector2.RIGHT, bug, 14)
	await process_frame
	
	var initial_dir = proj.direction
	var initial_speed = proj.speed
	
	# Kılıçla yansıtma (reflect)
	proj.reflect(dummy_player)
	var reflected_ok = (proj.is_reflected and proj.direction == -initial_dir and proj.speed > initial_speed)
	var mask_ok = (proj.collision_mask & 2) != 0 # Düşmanları vuracak şekilde güncellendi mi?

	if reflected_ok and mask_ok:
		print("✅ TEST 5 GEÇTİ: Siber enerji mermisi kılıç parry/yansıtma (ters yön, hız artışı, düşman maskesi) doğrulandı.")
		passed_tests += 1
	else:
		print("❌ TEST 5 BAŞARISIZ: Mermi yansıtma mantığında hata!")
		quit(1)
		return

	proj.queue_free()
	bug.queue_free()
	dummy_player.queue_free()

	# -------------------------------------------------------------
	# 6. TEST: Çoklu Düşman Sürü Ayrılması (Flocking Separation / Yığılmayı Önleme)
	# -------------------------------------------------------------
	total_tests += 1
	var r1 = raptor_scene.instantiate() as CharacterBody2D
	var r2 = raptor_scene.instantiate() as CharacterBody2D
	root.add_child(r1)
	root.add_child(r2)
	r1.global_position = Vector2(400.0, 500.0)
	r2.global_position = Vector2(410.0, 500.0) # Birbirine çok yakın (10px)
	await process_frame
	
	var sep_force_r1 = r1._calculate_flocking_separation_x()
	var sep_force_r2 = r2._calculate_flocking_separation_x()
	
	# r1 sola, r2 sağa itilmeli
	var flocking_ok = (sep_force_r1 < 0.0 and sep_force_r2 > 0.0)
	
	if flocking_ok:
		print("✅ TEST 6 GEÇTİ: Çoklu düşman senaryosunda sürü ayrılması (Flocking) birbirini iterek yığılmayı önledi.")
		passed_tests += 1
	else:
		print("❌ TEST 6 BAŞARISIZ: Sürü ayrılma hesabı hatalı! r1:%f, r2:%f" % [sep_force_r1, sep_force_r2])
		quit(1)
		return

	r1.queue_free()
	r2.queue_free()

	# -------------------------------------------------------------
	# 7. TEST: Bölüm 1 (stage_1_prehistoric_valley.tscn) Entegrasyonu
	# -------------------------------------------------------------
	total_tests += 1
	var stage1_scene = load("res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn")
	if not stage1_scene:
		print("❌ TEST 7 BAŞARISIZ: stage_1_prehistoric_valley.tscn yüklenemedi!")
		quit(1)
		return
		
	var stage1 = stage1_scene.instantiate()
	root.add_child(stage1)
	await process_frame
	await physics_frame
	
	var enemies_node = stage1.get_node_or_null("Enemies")
	var has_raptor = enemies_node != null and enemies_node.get_node_or_null("Raptor1") != null
	var has_cyber_bug = enemies_node != null and enemies_node.get_node_or_null("CyberFlyingBug1") != null
	var has_raptor2 = enemies_node != null and enemies_node.get_node_or_null("Raptor2") != null
	
	if has_raptor and has_cyber_bug and has_raptor2:
		print("✅ TEST 7 GEÇTİ: Bölüm 1 sahnesine Raptor minyonları ve Siber Uçan Böcekler başarıyla yerleştirildi.")
		passed_tests += 1
	else:
		print("❌ TEST 7 BAŞARISIZ: Bölüm 1 düşman düğümlerinde eksik var!")
		quit(1)
		return

	stage1.queue_free()

	print("\n=== TÜM TESTLER TAMAMLANDI: %d/%d Başarılı ===" % [passed_tests, total_tests])
	quit(0)
