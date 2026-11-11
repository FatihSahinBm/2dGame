extends SceneTree

## res://verify_stoneage_combat_and_fire.gd
## Doğrulama Testi:
## 1. Bölüm 7 Küçük T-Rex (Raptor) Zemin Hizalaması (Ayaklar ve Çarpışma Kutusu tam zeminde)
## 2. Sol Taraf Ateş Düzenlemesi (Direkli Meşale & Zeminde Taş Ocaklı Kamp Ateşi)
## 3. Sahne Entegrasyonu (stoneage_07_mother_trex.tscn & stage_2_trex_boss_arena.tscn)

func _init() -> void:
	_run_async()

func _run_async() -> void:
	print("\n=== [TEST BAŞLANGICI] Bölüm 7: Küçük T-Rex Zemin Hizalama & Sol Taraf Ateş Düzenlemesi ===")
	var total_tests: int = 0
	var passed_tests: int = 0

	# -------------------------------------------------------------
	# 1. TEST: Küçük T-Rex (Raptor) Boyut ve Zemin Hizalaması
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
	
	var col_shape = raptor.get_node("CollisionShape2D") as CollisionShape2D
	var sprite = raptor.get_node("Visual/AnimatedSprite2D") as AnimatedSprite2D
	
	# Çarpışma kutusunun alt noktası Y=0 olmalı (tam zemin seviyesi)
	var col_rect = col_shape.shape as RectangleShape2D
	var col_bottom = col_shape.position.y + (col_rect.size.y / 2.0)
	var col_bottom_ok = absf(col_bottom) < 0.01
	
	# Sprite ayakları zemin seviyesinde veya hafif çim içine gömülü olmalı (0 ile 12 px arası, havada asılı kalma yok)
	var sprite_feet_y = sprite.position.y + (331.5 * sprite.scale.y)
	var sprite_feet_ok = (sprite_feet_y >= 0.0 and sprite_feet_y <= 12.0)
	
	# Trex Boss için de aynı zemin temas kontrolü
	var boss_scene = load("res://scenes/enemies/trex_boss.tscn")
	var boss = boss_scene.instantiate() as CharacterBody2D
	var boss_sprite = boss.get_node("Visual/AnimatedSprite2D") as AnimatedSprite2D
	var boss_feet_idle_y = boss_sprite.position.y + (331.5 * boss_sprite.scale.y) # +12.2 px
	var boss_feet_walk_y = boss_sprite.position.y + (317.0 * boss_sprite.scale.y) # +6.1 px
	var boss_contact_ok = (boss_feet_idle_y > 0.0 and boss_feet_walk_y > 0.0) # Yürürken asla havada kalmaz
	boss.queue_free()
	
	# Küçük T-Rex ölçeği (Boss 0.42 iken minyon 0.24 olmalı)
	var is_small_trex = (sprite.scale.y <= 0.28 and sprite.scale.y >= 0.20)
	var has_snap = raptor.floor_stop_on_slope and raptor.floor_snap_length > 0.0
	
	if col_bottom_ok and sprite_feet_ok and is_small_trex and has_snap and boss_contact_ok:
		print("✅ TEST 1 GEÇTİ: T-Rex Boss & Raptor ayak zemin teması (Boss walk feet: +%.1f px, idle: +%.1f px, Raptor idle: +%.1f px) yürüyüş döngüsünde havada kalmayacak şekilde doğrulandı." % [
			boss_feet_walk_y, boss_feet_idle_y, sprite_feet_y
		])
		passed_tests += 1
	else:
		print("❌ TEST 1 BAŞARISIZ: Küçük T-Rex zemin hizalama hatası! col_bottom: %f, sprite_feet: %f, small: %s, snap: %s" % [
			col_bottom, sprite_feet_y, is_small_trex, has_snap
		])
		quit(1)
		return
		
	raptor.queue_free()

	# -------------------------------------------------------------
	# 2. TEST: Direkli Meşale (StandingTorchPost) Düğüm & Efekt Doğrulaması
	# -------------------------------------------------------------
	total_tests += 1
	var torch_scene = load("res://scenes/objects/standing_torch_post.tscn")
	if not torch_scene:
		print("❌ TEST 2 BAŞARISIZ: standing_torch_post.tscn yüklenemedi!")
		quit(1)
		return
		
	var torch_post = torch_scene.instantiate() as Node2D
	root.add_child(torch_post)
	await process_frame
	
	var has_pole = torch_post.get_node_or_null("WoodenPole") != null
	var has_torch_head = torch_post.get_node_or_null("TorchHead") != null
	var has_base_hearth = torch_post.get_node_or_null("BaseHearth") != null
	var has_flames = torch_post.get_node_or_null("FlameCoreParticles") != null
	var has_flicker = torch_post.get_node_or_null("FlickeringLight2D") != null
	var has_audio = torch_post.get_node_or_null("TorchAudio") != null
	
	if has_pole and has_torch_head and has_base_hearth and has_flames and has_flicker and has_audio:
		print("✅ TEST 2 GEÇTİ: Direkli Meşale (Ahşap direk, zemin taşları, alev/kıvılcım partikülleri, titreşen ışık ve ses) doğrulandı.")
		passed_tests += 1
	else:
		print("❌ TEST 2 BAŞARISIZ: Direkli meşale bileşenlerinde eksik var!")
		quit(1)
		return
		
	torch_post.queue_free()

	# -------------------------------------------------------------
	# 3. TEST: Taş Ocaklı Kamp Ateşi (Campfire) Zemin Doğrulaması
	# -------------------------------------------------------------
	total_tests += 1
	var camp_scene = load("res://scenes/objects/campfire.tscn")
	var campfire = camp_scene.instantiate() as Node2D
	root.add_child(campfire)
	await process_frame
	
	var has_hearth = campfire.get_node_or_null("HearthStones") != null
	var has_coals = campfire.get_node_or_null("GlowingCoals") != null
	var has_wood = campfire.get_node_or_null("WoodSprite") != null
	
	if has_hearth and has_coals and has_wood:
		print("✅ TEST 3 GEÇTİ: Zemindeki kamp ateşi taş ocak halkası, kor közler ve odun yapısıyla doğrulandı.")
		passed_tests += 1
	else:
		print("❌ TEST 3 BAŞARISIZ: Kamp ateşi zemin bileşenlerinde eksik var!")
		quit(1)
		return
		
	campfire.queue_free()

	# -------------------------------------------------------------
	# 4. TEST: Bölüm 7 (StoneAge07MotherTrex & Stage2TrexBossArena) Sahne Entegrasyonu
	# -------------------------------------------------------------
	total_tests += 1
	var stage7_scene = load("res://scenes/levels/stoneage/stoneage_07_mother_trex.tscn")
	if not stage7_scene:
		print("❌ TEST 4 BAŞARISIZ: stoneage_07_mother_trex.tscn yüklenemedi!")
		quit(1)
		return
		
	var stage7 = stage7_scene.instantiate() as Node2D
	root.add_child(stage7)
	await process_frame
	
	var entrance_torch = stage7.get_node_or_null("EntranceTorchLeft")
	var entrance_camp = stage7.get_node_or_null("Campfire")
	var old_floating_rift = stage7.get_node_or_null("DimensionalTimeRift")
	var raptor1 = stage7.get_node_or_null("Enemies/Raptor1")
	print("raptor1 node: ", raptor1, " pos: ", (raptor1.position if raptor1 else "null"))
	
	# Havada asılı kalan eski yırtık kaldırılmış olmalı
	var no_floating_rift = (old_floating_rift == null)
	# Sol tarafta hem direkli meşale hem zeminde kamp ateşi tam zemin yüksekliğinde (560) bulunmalı
	var torch_ground_ok = (entrance_torch != null and entrance_torch.position.y == 560.0)
	var camp_ground_ok = (entrance_camp != null and entrance_camp.position.y == 560.0)
	# Raptor zemin yüksekliği (~560) tolerans dahilinde olmalı
	var raptor_ground_ok = (raptor1 != null and absf(raptor1.position.y - 560.0) < 1.5)
	
	if no_floating_rift and torch_ground_ok and camp_ground_ok and raptor_ground_ok:
		print("✅ TEST 4 GEÇTİ: Bölüm 7 sahnesinde sol taraftaki direkli meşale ve kamp ateşi zemine (y=560) oturtuldu, havada asılı ateş kaldırıldı ve küçük T-Rex tam zeminde doğrulandı.")
		passed_tests += 1
	else:
		print("❌ TEST 4 BAŞARISIZ: Sahne entegrasyonu hatalı! no_rift:%s, torch:%s, camp:%s, raptor:%s" % [
			no_floating_rift, torch_ground_ok, camp_ground_ok, raptor_ground_ok
		])
		quit(1)
		return
		
	stage7.queue_free()

	print("\n=== TÜM TESTLER TAMAMLANDI: %d/%d Başarılı ===" % [passed_tests, total_tests])
	quit(0)
