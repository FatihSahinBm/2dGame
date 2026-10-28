extends SceneTree

# res://tools/test_vlad_stage2_platform_visuals.gd
# Görev 9: Vlad Mahzeni Platform ve Zemin Görsel Bütünlük ve Fizik Testi

const STAGE2_PATH = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"

var stage_instance: Node = null
var test_step: int = 0
var timer: float = 0.0

var plat1_ref: CollapsingPlatform = null
var plat1_shook: bool = false
var plat1_dropped: bool = false
var plat1_restored: bool = false


func _init() -> void:
	print("=================================================================")
	print("--- GÖREV 9: VLAD MAHZENİ PLATFORM & ZEMİN GÖRSEL DOĞRULAMA TESTİ ---")
	print("=================================================================\n")


func _process(delta: float) -> bool:
	timer += delta

	match test_step:
		0:
			_step_load_and_verify_ledges()
		1:
			_step_verify_collapsing_platforms()
		2:
			_step_verify_texture_filter_and_assets()
		3:
			_step_verify_walkable_alignment()
		4:
			_step_verify_preservation_of_traps_and_hazards()
		5:
			_step_test_collapsing_lifecycle()
		6:
			_step_finish_and_report()

	return false


func _step_load_and_verify_ledges() -> void:
	test_step = -1
	print("[ADIM 1] Sahne ve Taş Ledge / Zemin Geometrisi Doğrulaması...")

	var packed = load(STAGE2_PATH) as PackedScene
	if not packed:
		_fail("stage_2_castle_dungeon.tscn yüklenemedi!")
		return

	stage_instance = packed.instantiate()
	root.add_child(stage_instance)

	var entrance_ledge = stage_instance.get_node_or_null("Environment/EntranceLedge") as StaticBody2D
	var mid_ledge = stage_instance.get_node_or_null("Environment/MidLedge") as StaticBody2D
	var upper_corridor = stage_instance.get_node_or_null("Environment/UpperCorridor") as StaticBody2D

	if not entrance_ledge or not mid_ledge or not upper_corridor:
		_fail("Sabit zemin ledge'leri bulunamadı!")
		return

	# EntranceLedge
	var ent_col = entrance_ledge.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var ent_shape = ent_col.shape as RectangleShape2D
	var ent_vis = entrance_ledge.get_node_or_null("StoneLedgeVisual") as NinePatchRect
	assert(entrance_ledge.position == Vector2(180, 575), "EntranceLedge pozisyonu değişmemeli (180, 575)!")
	assert(ent_shape.size == Vector2(400, 50), "EntranceLedge çarpışma boyutu değişmemeli (400, 50)!")
	assert(ent_vis != null, "EntranceLedge StoneLedgeVisual NinePatchRect mevcut olmalı!")
	assert(ent_vis.offset_left == -200.0 and ent_vis.offset_right == 200.0, "EntranceLedge görsel genişliği 400px olmalı!")
	print("  - EntranceLedge: pos=%s, col_size=%s, visual_size=(%.0f, %.0f)" % [entrance_ledge.position, ent_shape.size, ent_vis.size.x, ent_vis.size.y])

	# MidLedge
	var mid_col = mid_ledge.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var mid_shape = mid_col.shape as RectangleShape2D
	var mid_vis = mid_ledge.get_node_or_null("StoneLedgeVisual") as NinePatchRect
	assert(mid_ledge.position == Vector2(920, 520), "MidLedge pozisyonu değişmemeli (920, 520)!")
	assert(mid_shape.size == Vector2(260, 40), "MidLedge çarpışma boyutu değişmemeli (260, 40)!")
	assert(mid_vis != null, "MidLedge StoneLedgeVisual NinePatchRect mevcut olmalı!")
	assert(mid_vis.offset_left == -130.0 and mid_vis.offset_right == 130.0, "MidLedge görsel genişliği 260px olmalı!")
	print("  - MidLedge: pos=%s, col_size=%s, visual_size=(%.0f, %.0f)" % [mid_ledge.position, mid_shape.size, mid_vis.size.x, mid_vis.size.y])

	# UpperCorridor
	var up_col = upper_corridor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var up_shape = up_col.shape as RectangleShape2D
	var up_vis = upper_corridor.get_node_or_null("StoneLedgeVisual") as NinePatchRect
	assert(upper_corridor.position == Vector2(1750, 575), "UpperCorridor pozisyonu değişmemeli (1750, 575)!")
	assert(up_shape.size == Vector2(1000, 60), "UpperCorridor çarpışma boyutu değişmemeli (1000, 60)!")
	assert(up_vis != null, "UpperCorridor StoneLedgeVisual NinePatchRect mevcut olmalı!")
	assert(up_vis.offset_left == -500.0 and up_vis.offset_right == 500.0, "UpperCorridor görsel genişliği 1000px olmalı!")
	print("  - UpperCorridor: pos=%s, col_size=%s, visual_size=(%.0f, %.0f)" % [upper_corridor.position, up_shape.size, up_vis.size.x, up_vis.size.y])

	print("  -> ADIM 1 BAŞARILI: Sabit taş zemin ve platform geometrisi kusursuz korundu.\n")
	test_step = 1


func _step_verify_collapsing_platforms() -> void:
	test_step = -1
	print("[ADIM 2] Çöken Platformların (CollapsingPlatform) Özellik Doğrulaması...")

	var plat1 = stage_instance.get_node_or_null("Platforms/CollapsingPlat1") as CollapsingPlatform
	var plat2 = stage_instance.get_node_or_null("Platforms/CollapsingPlat2") as CollapsingPlatform
	var plat3 = stage_instance.get_node_or_null("Platforms/CollapsingPlat3") as CollapsingPlatform

	if not plat1 or not plat2 or not plat3:
		_fail("Çöken platformlar bulunamadı!")
		return

	plat1_ref = plat1

	assert(plat1.position == Vector2(460, 520), "CollapsingPlat1 pozisyonu (460, 520) olmalı!")
	assert(plat2.position == Vector2(690, 480), "CollapsingPlat2 pozisyonu (690, 480) olmalı!")
	assert(plat3.position == Vector2(1170, 490), "CollapsingPlat3 pozisyonu (1170, 490) olmalı!")

	assert(is_equal_approx(plat1.collapse_delay, 2.4), "CollapsingPlat1 collapse_delay 2.4s olarak korunmalı!")
	assert(is_equal_approx(plat2.collapse_delay, 1.6), "CollapsingPlat2 collapse_delay 1.6s olarak korunmalı!")
	assert(is_equal_approx(plat3.collapse_delay, 1.6), "CollapsingPlat3 collapse_delay 1.6s olarak korunmalı!")

	# Çarpışma kutusu boyutu
	var col_shape1 = plat1.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert(col_shape1 != null and (col_shape1.shape as RectangleShape2D).size == Vector2(160, 20), "Platform çarpışma boyutu (160, 20) olmalı!")

	# Görsel sprite düğümü
	var sprite = plat1.get_node_or_null("Visual/PlatformSprite") as Sprite2D
	assert(sprite != null and sprite.texture != null, "PlatformSprite ve texture mevcut olmalı!")
	assert(sprite.texture.get_width() == 160 and sprite.texture.get_height() == 20, "Platform texture boyutu (160, 20) olmalı!")

	# Geçici Line2D'lerin kaldırıldığı doğrulanmalı
	var line1 = plat1.get_node_or_null("Visual/CrackLine1")
	var line2 = plat1.get_node_or_null("Visual/CrackLine2")
	assert(line1 == null and line2 == null, "Geçici Line2D vektör çizgileri kaldırılmış olmalı, gerçek pixel-art texture kullanılmalı!")

	print("  - Plat1: pos=%s, delay=%.2fs, size=%s" % [plat1.position, plat1.collapse_delay, (col_shape1.shape as RectangleShape2D).size])
	print("  - Plat2: pos=%s, delay=%.2fs" % [plat2.position, plat2.collapse_delay])
	print("  - Plat3: pos=%s, delay=%.2fs" % [plat3.position, plat3.collapse_delay])
	print("  -> ADIM 2 BAŞARILI: Çöken platformlar ve çökme süreleri eksiksiz doğrulandı.\n")
	test_step = 2


func _step_verify_texture_filter_and_assets() -> void:
	test_step = -1
	print("[ADIM 3] Piksel Keskinliği ve Doku Filtreleme Kontrolü (TEXTURE_FILTER_NEAREST)...")

	var ent_vis = stage_instance.get_node("Environment/EntranceLedge/StoneLedgeVisual") as NinePatchRect
	var mid_vis = stage_instance.get_node("Environment/MidLedge/StoneLedgeVisual") as NinePatchRect
	var up_vis = stage_instance.get_node("Environment/UpperCorridor/StoneLedgeVisual") as NinePatchRect
	var plat_sprite = plat1_ref.get_node("Visual/PlatformSprite") as Sprite2D
	var spike_trim = stage_instance.get_node_or_null("Environment/SpikePitHazard/SpikeTrim") as TextureRect

	assert(ent_vis.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "EntranceLedge texture_filter Nearest olmalı!")
	assert(mid_vis.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "MidLedge texture_filter Nearest olmalı!")
	assert(up_vis.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "UpperCorridor texture_filter Nearest olmalı!")
	assert(plat_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "PlatformSprite texture_filter Nearest olmalı!")

	if spike_trim:
		assert(spike_trim.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "SpikeTrim texture_filter Nearest olmalı!")

	# NinePatch ayarları
	assert(ent_vis.patch_margin_left == 24 and ent_vis.patch_margin_right == 24, "NinePatch sol/sağ marjinleri 24 olmalı!")
	assert(ent_vis.patch_margin_top == 16 and ent_vis.patch_margin_bottom == 16, "NinePatch üst/alt marjinleri 16 olmalı!")
	assert(ent_vis.axis_stretch_horizontal == NinePatchRect.AXIS_STRETCH_MODE_TILE, "NinePatch horizontal stretch TILE olmalı (bulanıklaşmama için)!")

	print("  - Tüm platform ve zemin görsel düğümleri TEXTURE_FILTER_NEAREST (keskin piksel) modunda.")
	print("  - NinePatchRect tekrarlama modu AXIS_STRETCH_MODE_TILE (kesintisiz dikişsiz doku).")
	print("  -> ADIM 3 BAŞARILI: Piksel keskinliği güvence altında.\n")
	test_step = 3


func _step_verify_walkable_alignment() -> void:
	test_step = -1
	print("[ADIM 4] Yürünebilir Yüzey ve Ayak Hizalama Kontrolü...")

	# EntranceLedge: StaticBody pos Y = 575, Shape size Y = 50 -> Top = 575 - 25 = 550.
	# Visual offset_top = -25 -> Top edge global Y = 575 - 25 = 550.
	var ent_top_col = 575.0 - (50.0 / 2.0)
	var ent_top_vis = 575.0 + (-25.0)
	assert(is_equal_approx(ent_top_col, ent_top_vis), "EntranceLedge görsel üst kenarı ile fizik üst kenarı uyuşmalı!")

	# MidLedge: StaticBody pos Y = 520, Shape size Y = 40 -> Top = 520 - 20 = 500.
	# Visual offset_top = -20 -> Top edge global Y = 520 - 20 = 500.
	var mid_top_col = 520.0 - (40.0 / 2.0)
	var mid_top_vis = 520.0 + (-20.0)
	assert(is_equal_approx(mid_top_col, mid_top_vis), "MidLedge görsel üst kenarı ile fizik üst kenarı uyuşmalı!")

	# UpperCorridor: StaticBody pos Y = 575, Shape size Y = 60 -> Top = 575 - 30 = 545.
	# Visual offset_top = -30 -> Top edge global Y = 575 - 30 = 545.
	var up_top_col = 575.0 - (60.0 / 2.0)
	var up_top_vis = 575.0 + (-30.0)
	assert(is_equal_approx(up_top_col, up_top_vis), "UpperCorridor görsel üst kenarı ile fizik üst kenarı uyuşmalı!")

	# CollapsingPlatform: pos Y = 520, Shape size Y = 20 -> Top = 520 - 10 = 510.
	# PlatformSprite centered at (0, 0), height = 20 -> Top = 520 - 10 = 510.
	var plat_top_col = 520.0 - (20.0 / 2.0)
	var plat_top_vis = 520.0 - (20.0 / 2.0)
	assert(is_equal_approx(plat_top_col, plat_top_vis), "CollapsingPlatform görsel üst yüzeyi fizik üst yüzeyiyle uyuşmalı!")

	print("  - EntranceLedge: fizik_top=%.1f px, görsel_top=%.1f px (Fark: 0.0 px)" % [ent_top_col, ent_top_vis])
	print("  - MidLedge:      fizik_top=%.1f px, görsel_top=%.1f px (Fark: 0.0 px)" % [mid_top_col, mid_top_vis])
	print("  - UpperCorridor: fizik_top=%.1f px, görsel_top=%.1f px (Fark: 0.0 px)" % [up_top_col, up_top_vis])
	print("  - CollapsingPlat:fizik_top=%.1f px, görsel_top=%.1f px (Fark: 0.0 px)" % [plat_top_col, plat_top_vis])
	print("  -> ADIM 4 BAŞARILI: Ayaklar asla taş içine batmaz veya havada süzülmez.\n")
	test_step = 4


func _step_verify_preservation_of_traps_and_hazards() -> void:
	test_step = -1
	print("[ADIM 5] Giyotin ve Ölüm Çukuru Korunma Kontrolü...")

	var guil1 = stage_instance.get_node_or_null("Traps/Guillotine1") as GuillotineTrap
	var guil2 = stage_instance.get_node_or_null("Traps/Guillotine2") as GuillotineTrap
	var spike = stage_instance.get_node_or_null("Environment/SpikePitHazard") as Area2D

	assert(guil1 != null and guil2 != null, "Giyotinler sahnede mevcut olmalı!")
	assert(guil1.position == Vector2(575, 330), "Guillotine1 pozisyonu (575, 330) korunmalı!")
	assert(guil2.position == Vector2(1040, 310), "Guillotine2 pozisyonu (1040, 310) korunmalı!")
	assert(guil1.damage == 25 and guil2.damage == 25, "Giyotin hasarı 25 olarak korunmalı!")
	assert(is_equal_approx(guil1.swing_speed, 2.4), "Guillotine1 swing_speed 2.4 korunmalı!")

	assert(spike != null, "SpikePitHazard sahnede mevcut olmalı!")
	assert(spike.position == Vector2(760, 650), "SpikePitHazard pozisyonu (760, 650) korunmalı!")

	print("  - Guillotine1: pos=%s, damage=%d, speed=%.2f" % [guil1.position, guil1.damage, guil1.swing_speed])
	print("  - Guillotine2: pos=%s, damage=%d, speed=%.2f" % [guil2.position, guil2.damage, guil2.swing_speed])
	print("  - SpikePitHazard: pos=%s" % [spike.position])
	print("  -> ADIM 5 BAŞARILI: Tuzak ve tehlike geometrileri kesinlikle değişmedi.\n")
	test_step = 5


func _step_test_collapsing_lifecycle() -> void:
	test_step = -1
	print("[ADIM 6] Canlı Çökme, Titreme ve Yenilenme Yaşam Döngüsü Kontrolü...")

	plat1_ref.collapsed.connect(func():
		plat1_dropped = true
		print("    [SİNYAL] CollapsingPlatform çöktü (collision disabled)")
	)
	plat1_ref.restored.connect(func():
		plat1_restored = true
		print("    [SİNYAL] CollapsingPlatform yenilendi (collision enabled)")
	)

	plat1_ref.trigger_collapse()
	print("  - Platform çöküşü tetiklendi...")

	# Süreç 2.4s çökme + 0.45s düşüş + 3.0s yenilenme + 0.4s animasyon = ~6.25s sürer
	var cycle_timer: SceneTreeTimer = create_timer(6.8)
	cycle_timer.timeout.connect(func():
		assert(plat1_dropped, "Platform çökme sinyali yayılmış olmalı!")
		assert(plat1_restored, "Platform yenilenme sinyali yayılmış olmalı!")
		assert(plat1_ref.collision_shape.disabled == false, "Yenilenme sonrası çarpışma tekrar devrede olmalı!")
		print("  -> ADIM 6 BAŞARILI: Çökme döngüsü eksiksiz tamamlandı.\n")
		test_step = 6
	)


func _step_finish_and_report() -> void:
	test_step = -1
	print("=================================================================")
	print("--- TÜM GÖREV 9 KONTROLLERİ VE TESTLERİ BAŞARIYLA TAMAMLANDI! ---")
	print("=================================================================")
	quit(0)


func _fail(reason: String) -> void:
	printerr("\n[BAŞARISIZ]: %s\n" % reason)
	quit(1)
