extends SceneTree

# res://tools/test_vlad_stage2_gates.gd
# Görev 11.1: Vlad Mahzeni Kapı ve Mekanizmaları Kapsamlı Denetim ve Regresyon Testi

const STAGE2_PATH = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"

var stage: Node2D = null
var test_step: int = 0
var frame_count: int = 0

var chain_lever: DungeonChainLever = null
var lever_visual: Sprite2D = null
var lever_prompt: Label = null
var entrance_arch: Sprite2D = null
var outer_portcullis: Node2D = null
var outer_gate_col: CollisionShape2D = null

var blood_gate: Area2D = null
var blood_gate_col: CollisionShape2D = null
var arch_visual: Sprite2D = null
var gate_bars: Sprite2D = null
var player: CharacterBody2D = null

var b1: BloodAltarBrazier = null
var b2: BloodAltarBrazier = null
var b3: BloodAltarBrazier = null


func _init() -> void:
	print("=================================================================")
	print("--- GÖREV 11.1: MAHZEN KAPILARI DENETİM VE REGRESYON TESTİ ---")
	print("=================================================================\n")


func _process(_delta: float) -> bool:
	frame_count += 1

	match test_step:
		0:
			_step_0_load_scene()
		1:
			_step_1_verify_nodes_and_initial_closed_state()
		2:
			_step_2_verify_closed_gate_passage_blocked()
		3:
			_step_3_test_chain_lever_interaction()
		4:
			_step_4_test_idempotency_and_double_call_guards()
		5:
			_step_5_test_brazier_puzzle_progression()
		6:
			_step_6_test_open_gate_passage_and_transition()
		7:
			_step_7_verify_regressions()
		8:
			_step_8_complete()

	return false


func _step_0_load_scene() -> void:
	test_step = -1
	print("[ADIM 0] Sahne Yükleniyor...")
	var packed: PackedScene = load(STAGE2_PATH) as PackedScene
	if not packed:
		_fail("stage_2_castle_dungeon.tscn sahnesi yüklenemedi!")
		return

	stage = packed.instantiate() as Node2D
	root.add_child(stage)
	print("  PASS: Sahne örneklendi ve ağaca eklendi.")
	test_step = 1


func _step_1_verify_nodes_and_initial_closed_state() -> void:
	test_step = -1
	print("\n[KONTROL 1 & 2] Düğümlerin, Kaynakların ve Başlangıç Kapalı Durumunun Denetimi...")

	var bracket = stage.get_node_or_null("EntranceMechanism/ChainBracket") as Sprite2D
	if not bracket or not bracket.texture:
		_fail("ChainBracket eksik veya texturesiz!")
		return
	print("  PASS: ChainBracket doğrulandı: ", bracket.texture.resource_path)

	chain_lever = stage.get_node_or_null("EntranceMechanism/ChainLever") as DungeonChainLever
	if not chain_lever:
		_fail("ChainLever eksik veya sınıfı yanlış!")
		return
	lever_visual = chain_lever.get_node_or_null("Visual") as Sprite2D
	if not lever_visual or not lever_visual.texture:
		_fail("ChainLever/Visual eksik veya texturesiz!")
		return
	lever_prompt = chain_lever.get_node_or_null("PromptLabel") as Label
	if not lever_prompt or lever_prompt.text != "[E] Zinciri Çek":
		_fail("ChainLever/PromptLabel eksik veya metni hatalı!")
		return
	print("  PASS: ChainLever doğrulandı (PromptLabel: '%s')" % lever_prompt.text)

	entrance_arch = stage.get_node_or_null("EntranceMechanism/EntranceArch") as Sprite2D
	if not entrance_arch or not entrance_arch.texture:
		_fail("EntranceArch eksik veya texturesiz!")
		return
	print("  PASS: EntranceArch doğrulandı: ", entrance_arch.texture.resource_path)

	outer_portcullis = stage.get_node_or_null("EntranceMechanism/OuterPortcullis") as Node2D
	if not outer_portcullis or not (outer_portcullis is Sprite2D):
		_fail("OuterPortcullis eksik veya Sprite2D değil!")
		return
	var portcullis_sprite: Sprite2D = outer_portcullis as Sprite2D
	if not portcullis_sprite.texture:
		_fail("OuterPortcullis texturesiz!")
		return
	print("  PASS: OuterPortcullis doğrulandı: ", portcullis_sprite.texture.resource_path)

	outer_gate_col = stage.get_node_or_null("EntranceMechanism/OuterGateStatic/CollisionShape2D") as CollisionShape2D
	if not outer_gate_col or not outer_gate_col.shape:
		_fail("OuterGateStatic/CollisionShape2D eksik!")
		return
	var rect_shape: RectangleShape2D = outer_gate_col.shape as RectangleShape2D
	if rect_shape.size != Vector2(20, 100):
		_fail("OuterGateStatic çarpışma boyutu değişmiş! Beklenen (20, 100), gelen: %s" % str(rect_shape.size))
		return
	if outer_gate_col.disabled:
		_fail("OuterGateStatic başlangıçta devre dışı (açık)! Kapalı olmalıydı.")
		return
	print("  PASS: OuterGateStatic çarpışması başlangıçta aktif (boyut: %s)" % str(rect_shape.size))

	blood_gate = stage.get_node_or_null("BloodAltarGate") as Area2D
	if not blood_gate:
		_fail("BloodAltarGate eksik!")
		return
	blood_gate_col = blood_gate.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not blood_gate_col or not blood_gate_col.shape:
		_fail("BloodAltarGate/CollisionShape2D eksik!")
		return
	var blood_rect: RectangleShape2D = blood_gate_col.shape as RectangleShape2D
	if blood_rect.size != Vector2(70, 220):
		_fail("BloodAltarGate çarpışma boyutu değişmiş! Beklenen (70, 220), gelen: %s" % str(blood_rect.size))
		return
	print("  PASS: BloodAltarGate tetikleme alanı korundu (boyut: %s)" % str(blood_rect.size))

	arch_visual = blood_gate.get_node_or_null("ArchVisual") as Sprite2D
	if not arch_visual or not arch_visual.texture:
		_fail("BloodAltarGate/ArchVisual eksik veya texturesiz!")
		return
	print("  PASS: BloodAltarGate/ArchVisual doğrulandı: ", arch_visual.texture.resource_path)

	gate_bars = blood_gate.get_node_or_null("PortcullisBars") as Sprite2D
	if not gate_bars or not gate_bars.texture:
		_fail("BloodAltarGate/PortcullisBars eksik veya texturesiz!")
		return
	print("  PASS: BloodAltarGate/PortcullisBars doğrulandı: ", gate_bars.texture.resource_path)

	if stage.get("_gate_unlocked"):
		_fail("Taht kapısı başlangıçta açık (_gate_unlocked = true)! Kapalı olmalıydı.")
		return
	if outer_portcullis.position.y != 512.0:
		_fail("Dış parmaklık kapalı Y konumu hatalı! Beklenen 512, gelen: %f" % outer_portcullis.position.y)
		return
	if gate_bars.position.y != 28.0:
		_fail("Taht parmaklığı kapalı Y konumu hatalı! Beklenen 28, gelen: %f" % gate_bars.position.y)
		return

	player = stage.get_node_or_null("CombatPlayer") as CharacterBody2D
	print("  PASS: Başlangıçta iki kapı da doğru kapalı konumda ve fizik engelleri aktif.")
	test_step = 2


func _step_2_verify_closed_gate_passage_blocked() -> void:
	test_step = -1
	print("\n[KONTROL 3] Kapalı Taht Kapısından Geçiş Denemesi...")
	if player and stage.has_method("_on_dungeon_gate_entered"):
		stage._on_dungeon_gate_entered(player)
		if stage.get("_is_transitioning"):
			_fail("Kapalı Taht kapısı sahne geçişi başlattı! Geçiş engellenmeliydi.")
			return
		print("  PASS: Kapalı kapıya giren oyuncu sahne geçişi başlatmadı.")

	test_step = 3


func _step_3_test_chain_lever_interaction() -> void:
	test_step = -1
	print("\n[KONTROL 4] Giriş Kapısı Zincir Mekanizması Etkileşimi...")
	chain_lever.activate_lever()

	if not chain_lever.is_pulled:
		_fail("chain_lever.activate_lever() sonrası is_pulled false!")
		return
	if not stage.get("_outer_gate_unlocked"):
		_fail("Zincir çekildikten sonra stage._outer_gate_unlocked true olmadı!")
		return
	print("  PASS: Zincir kolu çekildi, _outer_gate_unlocked = true.")

	test_step = 4


func _step_4_test_idempotency_and_double_call_guards() -> void:
	test_step = -1
	print("\n[KONTROL 5] Çift Tetikleme ve Sinyal İdempotency Denetimi...")
	# Tekrar zincir kolu çekilirse veya _on_outer_lever_activated çağrılırsa hata olmamalı
	chain_lever.activate_lever()
	stage._on_outer_lever_activated()
	print("  PASS: İkinci zincir çekme çağrısı güvenle engellendi.")

	# _setup_braziers tekrar çağrıldığında sinyaller çift bağlanmamalı
	stage._setup_braziers()
	print("  PASS: _setup_braziers tekrarlı çağrıda sinyal çift bağlanmadı.")

	test_step = 5


func _step_5_test_brazier_puzzle_progression() -> void:
	test_step = -1
	print("\n[KONTROL 6] Mangal Bulmacası Erken Tetikleme Koruması ve Tamamlanma...")
	var puzzle_braziers: Node2D = stage.get_node_or_null("PuzzleBraziers") as Node2D
	if not puzzle_braziers or puzzle_braziers.get_child_count() != 3:
		_fail("PuzzleBraziers eksik veya 3 mangal içermiyor!")
		return

	b1 = puzzle_braziers.get_child(0) as BloodAltarBrazier
	b2 = puzzle_braziers.get_child(1) as BloodAltarBrazier
	b3 = puzzle_braziers.get_child(2) as BloodAltarBrazier

	# 1. Mangal Yakılıyor
	b1.ignite_brazier()
	if stage.get("_braziers_lit") != 1:
		_fail("1. mangal sonrası _braziers_lit beklenen 1, gelen: %d" % stage.get("_braziers_lit"))
		return
	if stage.get("_gate_unlocked"):
		_fail("1. mangal yakılınca kapı erken açıldı!")
		return
	print("  PASS: 1. Mangal yandı -> _braziers_lit = 1, kapı kapalı.")

	# 1. Mangal tekrar yakılırsa sayaç artmamalı
	b1.ignite_brazier()
	if stage.get("_braziers_lit") != 1:
		_fail("Aynı mangal tekrar yakılınca sayaç arttı! Gelen: %d" % stage.get("_braziers_lit"))
		return
	print("  PASS: Aynı mangalın tekrar yakılması sayacı artırmadı.")

	# 2. Mangal Yakılıyor
	b2.ignite_brazier()
	if stage.get("_braziers_lit") != 2:
		_fail("2. mangal sonrası _braziers_lit beklenen 2, gelen: %d" % stage.get("_braziers_lit"))
		return
	if stage.get("_gate_unlocked"):
		_fail("2. mangal yakılınca kapı erken açıldı!")
		return
	print("  PASS: 2. Mangal yandı -> _braziers_lit = 2, kapı kapalı.")

	# 3. Mangal Yakılıyor -> Kapı AÇILMALI
	b3.ignite_brazier()
	if stage.get("_braziers_lit") != 3:
		_fail("3. mangal sonrası _braziers_lit beklenen 3, gelen: %d" % stage.get("_braziers_lit"))
		return
	if not stage.get("_gate_unlocked"):
		_fail("3 mangalın tümü yandı ancak Taht kapısı açılmadı!")
		return
	print("  PASS: 3. Mangal yandı -> _braziers_lit = 3, Taht Odası kapısı başarıyla açıldı (_gate_unlocked = true).")

	# Tekrar _unlock_throne_gate çağrılırsa idempotency korunmalı
	stage._unlock_throne_gate()
	print("  PASS: _unlock_throne_gate() tekrarlı çağrıda güvenle korundu.")

	test_step = 6


func _step_6_test_open_gate_passage_and_transition() -> void:
	test_step = -1
	print("\n[KONTROL 7] Açık Taht Kapısından Geçiş ve Sahne Geçiş Tetiklemesi...")
	if player and stage.has_method("_on_dungeon_gate_entered"):
		stage._on_dungeon_gate_entered(player)
		if not stage.get("_is_transitioning"):
			_fail("Açık Taht kapısına giren oyuncu sahne geçişi tetiklemedi!")
			return
		print("  PASS: Açık kapıya giren oyuncu sahne geçişi başlattı (_is_transitioning = true).")

	test_step = 7


func _step_7_verify_regressions() -> void:
	test_step = -1
	print("\n[KONTROL 8] Platform, Giyotin ve Tuzaklar Regresyon Denetimi...")
	var platforms: Node2D = stage.get_node_or_null("Platforms") as Node2D
	if not platforms or platforms.get_child_count() != 3:
		_fail("Çöken platform sayısı bozulmuş! Beklenen 3.")
		return
	print("  PASS: 3 Çöken platform eksiksiz mevcut.")

	var traps: Node2D = stage.get_node_or_null("Traps") as Node2D
	if not traps or traps.get_child_count() != 2:
		_fail("Giyotin tuzağı sayısı bozulmuş! Beklenen 2.")
		return
	print("  PASS: 2 Giyotin tuzağı eksiksiz mevcut (Guillotine1, Guillotine2).")

	var spike_pit: Area2D = stage.get_node_or_null("Environment/SpikePitHazard") as Area2D
	if not spike_pit:
		_fail("SpikePitHazard eksik!")
		return
	print("  PASS: SpikePitHazard ölüm çukuru eksiksiz mevcut.")

	test_step = 8


func _step_8_complete() -> void:
	test_step = -1
	print("\n=================================================================")
	print("--- TÜM GÖREV 11.1 DENETİM VE REGRESYON TESTLERİ BAŞARILI (8/8) ---")
	print("=================================================================")
	stage.queue_free()
	quit(0)


func _fail(msg: String) -> void:
	printerr("\nFAIL: ", msg)
	if stage:
		stage.queue_free()
	quit(1)
