@tool
extends SceneTree

func _init() -> void:
	print("--- SİBER T-REX BOSS TEST VE DOĞRULAMA BAŞLADI ---")

	# 1. trex_frames.tres Yükleme ve Animasyon Kontrolü
	var frames_res = load("res://assets/characters/trex_boss/trex_frames.tres")
	if not frames_res:
		push_error("FAIL: trex_frames.tres yüklenemedi!")
		quit(1)
		return
	print("OK: trex_frames.tres başarıyla yüklendi.")

	var required_anims = [
		"intro_taunt", "idle", "walk", "run",
		"attack_bite", "attack_laser", "attack_platform_slam",
		"grab_counter", "stunned_groggy", "hurt", "death"
	]

	for anim in required_anims:
		if not frames_res.has_animation(StringName(anim)):
			push_error("FAIL: Eksik animasyon: " + anim)
			quit(1)
			return
		var count = frames_res.get_frame_count(StringName(anim))
		var speed = frames_res.get_animation_speed(StringName(anim))
		var loop = frames_res.get_animation_loop(StringName(anim))
		print("  - Animasyon: ", anim, " | Kare Sayısı: ", count, " | FPS: ", speed, " | Loop: ", loop)

	# 2. trex_boss.tscn Yükleme ve Düğüm Kontrolü
	var boss_scene_res = load("res://scenes/enemies/trex_boss.tscn")
	if not boss_scene_res:
		push_error("FAIL: res://scenes/enemies/trex_boss.tscn sahnesi bulunamadı!")
		quit(1)
		return
	print("OK: res://scenes/enemies/trex_boss.tscn yüklendi.")

	var boss_inst = boss_scene_res.instantiate()
	root.add_child(boss_inst)
	print("OK: TrexBoss örneklendi ve ağaca eklendi.")

	var anim_sprite = boss_inst.get_node_or_null("Visual/AnimatedSprite2D")
	if not anim_sprite:
		push_error("FAIL: Visual/AnimatedSprite2D bulunamadı!")
		quit(1)
		return
	print("OK: AnimatedSprite2D mevcut. Konum: ", anim_sprite.position, " Ölçek: ", anim_sprite.scale)

	var col_shape = boss_inst.get_node_or_null("CollisionShape2D")
	if not col_shape:
		push_error("FAIL: CollisionShape2D bulunamadı!")
		quit(1)
		return
	print("OK: Ana çarpışma alanı (CollisionShape2D) mevcut.")

	var hitbox = boss_inst.get_node_or_null("Visual/Hitbox")
	var laser_hitbox = boss_inst.get_node_or_null("Visual/LaserHitbox")
	var slam_hitbox = boss_inst.get_node_or_null("Visual/SlamHitbox")
	if not hitbox or not laser_hitbox or not slam_hitbox:
		push_error("FAIL: Saldırı hitbox'larından biri eksik!")
		quit(1)
		return
	print("OK: Isırık, Lazer ve Zemin Darbesi Hitbox'ları tam.")

	var hp_bar = boss_inst.get_node_or_null("UI/HealthBar")
	if not hp_bar:
		push_error("FAIL: UI/HealthBar bulunamadı!")
		quit(1)
		return
	print("OK: UI/HealthBar mevcut. Max HP: ", hp_bar.max_value)

	# 3. İstatistik ve Hasar Testi
	print("Boss Adı: ", boss_inst.monster_name)
	print("Boss Max HP: ", boss_inst.max_health)
	print("Boss Hasarı: ", boss_inst.attack_damage)
	print("Boss İtilme Direnci: ", boss_inst.knockback_resistance)

	print("Hasar alma simülasyonu yapılıyor (50 hasar)...")
	boss_inst.take_damage(50)
	if boss_inst.current_health != 700:
		push_error("FAIL: Can 700 olmalıydı, mevcut: " + str(boss_inst.current_health))
		quit(1)
		return
	print("OK: Hasar testi başarılı, kalan can: ", boss_inst.current_health)

	print("Faz ve Stagger testi (300 ek hasar)...")
	boss_inst.take_damage(300)
	print("OK: Kalan can: ", boss_inst.current_health, " | Mevcut Faz: ", boss_inst.boss_phase)
	if boss_inst.boss_phase < 2:
		push_error("FAIL: Boss Faz 2'ye geçmeliydi!")
		quit(1)
		return

	# 4. test_trex_boss.tscn Arena Sahnesi Testi
	var arena_res = load("res://scenes/dev/test_trex_boss.tscn")
	if not arena_res:
		push_error("FAIL: test_trex_boss.tscn bulunamadı!")
		quit(1)
		return
	print("OK: test_trex_boss.tscn sahnesi başarıyla yüklendi.")

	var arena_inst = arena_res.instantiate()
	root.add_child(arena_inst)
	print("OK: Arena sahnesi örneklendi.")

	var arena_boss = arena_inst.get_node_or_null("TrexBoss")
	var arena_player = arena_inst.get_node_or_null("TestPlayer")
	if not arena_boss:
		push_error("FAIL: Arena içinde TrexBoss bulunamadı!")
		quit(1)
		return
	if not arena_player:
		push_error("FAIL: Arena içinde TestPlayer bulunamadı!")
		quit(1)
		return
	print("OK: Arena sahnesinde hem TrexBoss (konum: ", arena_boss.position, ") hem de TestPlayer mevcut.")

	print("--- TÜM SİBER T-REX TESTLERİ %100 BAŞARIYLA TAMAMLANDI! ---")
	quit(0)
