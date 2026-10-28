extends SceneTree

# res://tools/test_vlad_stage2_braziers.gd
# Görev 10: Vlad Mahzeni Bulmaca Mangalları Görsel ve Mantık Doğrulama Testi

const STAGE2_PATH = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"

var stage_instance: Node = null
var test_step: int = 0
var timer: float = 0.0

var b1: BloodAltarBrazier = null
var b2: BloodAltarBrazier = null
var b3: BloodAltarBrazier = null


func _init() -> void:
	print("=================================================================")
	print("--- GÖREV 10: BULMACA MANGALLARI (BRAZIERS) DOĞRULAMA TESTİ ---")
	print("=================================================================\n")


func _process(delta: float) -> bool:
	timer += delta

	match test_step:
		0:
			_step_load_scene_and_check_braziers()
		1:
			_step_verify_brazier_visual_and_collision_structure()
		2:
			_step_verify_unlit_states()
		3:
			_step_test_individual_ignition()
		4:
			_step_test_puzzle_completion_and_gate()
		5:
			_step_verify_regressions()
		6:
			_step_finish()

	return false


func _step_load_scene_and_check_braziers() -> void:
	test_step = -1
	print("[ADIM 1] Sahne Yükleme ve Mangal Düğümleri Tespiti...")

	var packed = load(STAGE2_PATH) as PackedScene
	if not packed:
		_fail("stage_2_castle_dungeon.tscn sahnesi yüklenemedi!")
		return

	stage_instance = packed.instantiate()
	root.add_child(stage_instance)

	b1 = stage_instance.get_node_or_null("PuzzleBraziers/Brazier1") as BloodAltarBrazier
	b2 = stage_instance.get_node_or_null("PuzzleBraziers/Brazier2") as BloodAltarBrazier
	b3 = stage_instance.get_node_or_null("PuzzleBraziers/Brazier3") as BloodAltarBrazier

	if not b1 or not b2 or not b3:
		_fail("PuzzleBraziers altındaki mangallar (Brazier1, Brazier2, Brazier3) bulunamadı!")
		return

	assert(b1.position == Vector2(1520, 535), "Brazier1 pozisyonu (1520, 535) olmalı!")
	assert(b2.position == Vector2(1780, 535), "Brazier2 pozisyonu (1780, 535) olmalı!")
	assert(b3.position == Vector2(2040, 535), "Brazier3 pozisyonu (2040, 535) olmalı!")

	print("  - Brazier1: pos=%s, is_ignited=%s" % [b1.position, b1.is_ignited])
	print("  - Brazier2: pos=%s, is_ignited=%s" % [b2.position, b2.is_ignited])
	print("  - Brazier3: pos=%s, is_ignited=%s" % [b3.position, b3.is_ignited])
	print("  -> ADIM 1 BAŞARILI: Mangallar doğru konumlarında yüklendi.\n")
	test_step = 1


func _step_verify_brazier_visual_and_collision_structure() -> void:
	test_step = -1
	print("[ADIM 2] Mangal Görsel Düğümleri, TextureFilter ve Çarpışma Yapısı...")

	var braziers = [b1, b2, b3]
	for i in range(braziers.size()):
		var b = braziers[i]
		var col = b.get_node_or_null("CollisionShape2D") as CollisionShape2D
		assert(col != null, "Brazier%d CollisionShape2D mevcut olmalı!" % (i + 1))
		var rect = col.shape as RectangleShape2D
		assert(rect != null and rect.size == Vector2(40, 40), "Brazier%d çarpışma kutusu (40, 40) olmalı!" % (i + 1))
		assert(b.collision_layer == 4 and b.collision_mask == 1, "Brazier%d collision layer/mask (4/1) korunmalı!" % (i + 1))

		var base_sprite = b.get_node_or_null("Base") as Sprite2D
		assert(base_sprite != null, "Brazier%d Base Sprite2D mevcut olmalı!" % (i + 1))
		assert(base_sprite.texture != null, "Brazier%d Base texture atanmış olmalı!" % (i + 1))
		assert(base_sprite.texture.resource_path.ends_with("dungeon_brazier_base.png"), "Brazier%d Base texture dungeon_brazier_base.png olmalı!" % (i + 1))
		assert(base_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Brazier%d Base texture_filter Nearest olmalı!" % (i + 1))

		var fire_vis = b.get_node_or_null("FireVisual") as AnimatedSprite2D
		assert(fire_vis != null, "Brazier%d FireVisual AnimatedSprite2D mevcut olmalı!" % (i + 1))
		assert(fire_vis.sprite_frames != null, "Brazier%d FireVisual sprite_frames mevcut olmalı!" % (i + 1))
		assert(fire_vis.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Brazier%d FireVisual texture_filter Nearest olmalı!" % (i + 1))

		var prompt = b.get_node_or_null("PromptLabel") as Label
		assert(prompt != null, "Brazier%d PromptLabel mevcut olmalı!" % (i + 1))
		assert(prompt.text.contains("Mangalı Yak"), "Brazier%d PromptLabel metni 'Mangalı Yak' içermeli!" % (i + 1))

	print("  - Tüm 3 mangalın Base (Sprite2D) ve FireVisual (AnimatedSprite2D) düğümleri TEXTURE_FILTER_NEAREST modunda.")
	print("  - Çarpışma boyutları (40x40), katmanları (4/1) ve PromptLabel yapıları eksiksiz.")
	print("  -> ADIM 2 BAŞARILI: Görsel ve fizik yapısı doğrulandı.\n")
	test_step = 2


func _step_verify_unlit_states() -> void:
	test_step = -1
	print("[ADIM 3] Sönük Durum (Unlit) Kontrolü...")

	assert(b1.is_ignited == false, "Brazier1 başlangıçta sönük olmalı!")
	assert(b2.is_ignited == false, "Brazier2 başlangıçta sönük olmalı!")
	assert(b3.is_ignited == false, "Brazier3 başlangıçta sönük olmalı!")

	assert(b1.fire_visual.visible == false, "Brazier1 FireVisual başlangıçta görünmez olmalı!")
	assert(b2.fire_visual.visible == false, "Brazier2 FireVisual başlangıçta görünmez olmalı!")
	assert(b3.fire_visual.visible == false, "Brazier3 FireVisual başlangıçta görünmez olmalı!")

	print("  - Başlangıçta tüm mangallar sönük durumda; alev görselleri kapalı.")
	print("  -> ADIM 3 BAŞARILI: Sönük durum güvence altında.\n")
	test_step = 3


func _step_test_individual_ignition() -> void:
	test_step = -1
	print("[ADIM 4] Bağımsız Mangal Yakma (Individual Ignition) Testi...")

	# Yalnızca Brazier1'i yak
	b1.ignite_brazier()

	assert(b1.is_ignited == true, "Brazier1 is_ignited true olmalı!")
	assert(b1.fire_visual.visible == true, "Brazier1 FireVisual görünür olmalı!")

	# Brazier2 ve Brazier3 sönük kalmalı!
	assert(b2.is_ignited == false, "Brazier2 hâlâ sönük olmalı!")
	assert(b2.fire_visual.visible == false, "Brazier2 FireVisual hâlâ görünmez olmalı!")
	assert(b3.is_ignited == false, "Brazier3 hâlâ sönük olmalı!")
	assert(b3.fire_visual.visible == false, "Brazier3 FireVisual hâlâ görünmez olmalı!")

	print("  - Brazier1 yakıldı -> is_ignited=true, fire_visual.visible=true")
	print("  - Brazier2 ve Brazier3 sönük kaldı (çapraz durum kirlenmesi yok).")
	print("  -> ADIM 4 BAŞARILI: Mangallar birbirinden bağımsız çalışıyor.\n")
	test_step = 4


func _step_test_puzzle_completion_and_gate() -> void:
	test_step = -1
	print("[ADIM 5] 3 Mangallı Bulmaca Tamamlanması ve Kapı Açılışı...")

	# Brazier2'yi yak
	b2.ignite_brazier()
	assert(stage_instance._braziers_lit == 2, "Yanan mangal sayısı 2 olmalı!")
	assert(stage_instance._gate_unlocked == false, "2 mangalda kapı henüz açılmamalı!")

	# Brazier3'ü yak -> Bulmaca çözülür!
	b3.ignite_brazier()
	assert(stage_instance._braziers_lit == 3, "Yanan mangal sayısı 3 olmalı!")
	assert(stage_instance._gate_unlocked == true, "3 mangal yandığında taht kapısı kilidi açılmalı (_gate_unlocked=true)!")

	print("  - 1. Mangal yandı (1/3)")
	print("  - 2. Mangal yandı (2/3)")
	print("  - 3. Mangal yandı (3/3) -> MÜHÜR KIRILDI! Taht kapısı açıldı.")
	print("  -> ADIM 5 BAŞARILI: Bulmaca ve sinyal mekanizması kusursuz çalışıyor.\n")
	test_step = 5


func _step_verify_regressions() -> void:
	test_step = -1
	print("[ADIM 6] Regresyon Kontrolleri (Zeminler, Çöken Platformlar, Giyotinler)...")

	var ent = stage_instance.get_node("Environment/EntranceLedge") as StaticBody2D
	var mid = stage_instance.get_node("Environment/MidLedge") as StaticBody2D
	var up = stage_instance.get_node("Environment/UpperCorridor") as StaticBody2D
	var p1 = stage_instance.get_node("Platforms/CollapsingPlat1") as CollapsingPlatform
	var g1 = stage_instance.get_node("Traps/Guillotine1") as GuillotineTrap

	assert(ent.position == Vector2(180, 575), "EntranceLedge pozisyonu değişmemeli!")
	assert(mid.position == Vector2(920, 520), "MidLedge pozisyonu değişmemeli!")
	assert(up.position == Vector2(1750, 575), "UpperCorridor pozisyonu değişmemeli!")
	assert(is_equal_approx(p1.collapse_delay, 2.4), "CollapsingPlat1 delay 2.4s korunmalı!")
	assert(g1.damage == 25, "Guillotine1 hasarı 25 korunmalı!")

	print("  - Zemin ledgeleri, çöken platformlar ve giyotin parametreleri korundu.")
	print("  -> ADIM 6 BAŞARILI: Sıfır regresyon.\n")
	test_step = 6


func _step_finish() -> void:
	test_step = -1
	print("=================================================================")
	print("--- TÜM GÖREV 10 DOĞRULAMA TESTLERİ BAŞARIYLA TAMAMLANDI! ---")
	print("=================================================================")
	quit(0)


func _fail(reason: String) -> void:
	printerr("\n[BAŞARISIZ]: %s\n" % reason)
	quit(1)
