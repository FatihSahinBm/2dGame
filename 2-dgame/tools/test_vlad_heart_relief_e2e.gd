extends SceneTree

const STAGE2_SCENE_PATH = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"

var _passed_count = 0
var _failed_count = 0

func _init() -> void:
	print("==================================================")
	print("  TEST: VLAD CHAPTER GÖREV 6.1 - DİLSİZ KILIÇ TEPKİSİ VE ANLATIM KONTROLÜ")
	print("==================================================")
	call_deferred("_run_all_tests")

func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_passed_count += 1
		print("  [PASS] %s" % msg)
	else:
		_failed_count += 1
		printerr("  [FAIL] %s" % msg)

func _run_all_tests() -> void:
	# 1. Sahneyi Yükle ve Ağaca Ekle
	var scene_res = load(STAGE2_SCENE_PATH)
	_assert_true(scene_res != null, "stage_2_castle_dungeon.tscn sahnesi başarıyla yüklendi")
	if not scene_res:
		_finish()
		return

	var root_node = root
	var dungeon = scene_res.instantiate() as Stage2CastleDungeon
	_assert_true(dungeon != null, "Stage2CastleDungeon instance başarıyla oluşturuldu")
	root_node.add_child(dungeon)

	# 2. Kalp Kabartması Düğüm ve Bileşen Kontrolü
	var relief = dungeon.get_node_or_null("Environment/BoneArchiveMural") as AncientHeartRelief
	_assert_true(relief != null, "BoneArchiveMural düğümü AncientHeartRelief tipinde mevcut")

	var stone_slab = relief.get_node_or_null("StoneSlab") as Sprite2D
	_assert_true(stone_slab != null and stone_slab.texture != null, "StoneSlab Sprite2D (ancient_heart_relief.png) mevcut")

	var glow = relief.get_node_or_null("GlowOverlay") as Sprite2D
	_assert_true(glow != null and glow.texture != null, "GlowOverlay Sprite2D (ancient_heart_relief_glow.png) mevcut")

	var prompt = relief.get_node_or_null("PromptLabel") as Label
	_assert_true(prompt != null and prompt.text.contains("[E]"), "PromptLabel [E] etkileşim ipucu mevcut")

	var dialogue_box = dungeon.get_node_or_null("DialogueBox") as DialogueBox
	_assert_true(dialogue_box != null, "DialogueBox sahneye başarıyla entegre edilmiş")

	# 3. Oyuncu Yaklaşma ve İpucu Gösterme Testi
	var player = dungeon.get_node_or_null("CombatPlayer") as CharacterBody2D
	_assert_true(player != null, "CombatPlayer sahnede mevcut")

	relief._on_body_entered(player)
	_assert_true(relief._player_nearby, "Oyuncu kabartmanın yanına geldiğinde tespit edildi")
	_assert_true(prompt.visible, "Oyuncu yaklaştığında [E] etkileşim ipucu görünür oldu")

	# 4. Etkileşim ve Kılıcın Dilsiz Tepkisi Testi
	print("  [INFO] Kabartma inceleniyor ve kılıç tepkisi tetikleniyor...")
	var initial_examined = relief.is_examined
	_assert_true(not initial_examined, "Başlangıçta kabartma incelenmemiş durumda")

	var signal_state = {"emitted": false}
	relief.relief_examined.connect(func():
		signal_state["emitted"] = true
	)

	relief.examine_relief()
	_assert_true(relief.is_examined, "Kabartma incelendi durumuna geçti (is_examined = true)")
	_assert_true(not prompt.visible, "İnceleme başladığında ipucu gizlendi")

	# Çatlakların morumsu parlamasını doğrula
	await create_timer(0.3).timeout
	_assert_true(glow.modulate.a > 0.1, "Kabartma çatlakları ametist moru rezonansla parıldıyor")
	_assert_true(dialogue_box.panel.visible, "Diyalog kutusu (DialogueBox) anlatım metnini gösteriyor")

	# 1. Replik Kontrolü: Taş Kabartma Çevresel Anlatımı
	var speaker_lbl = dialogue_box.speaker_name_label
	_assert_true(speaker_lbl.text == "Kadim Taş Kabartma", "1. replik konuşmacısı 'Kadim Taş Kabartma' olarak çevresel")

	# 2. Replik Kontrolü: Dilsiz Kılıç Tepkisi (Kılıcın Yankısı kaldırılmış olmalı, portresiz ve konuşmacısız)
	dialogue_box._advance_dialogue()
	_assert_true(speaker_lbl.text == "", "2. replikte 'Kılıcın Yankısı' konuşmacı etiketi tamamen kaldırılmış (boş)")
	_assert_true(dialogue_box._full_text.contains("Kabza elinde aniden buz kesiyor"), "2. replik kılıcın fiziksel dilsiz titremesini betimliyor")

	var portrait_container = dialogue_box.get_node_or_null("Panel/PortraitContainer") as Control
	if portrait_container:
		_assert_true(not portrait_container.visible, "Portresiz anlatım biçimi: Portre kutusu gizlendi")

	# Diyaloğu kapat
	dialogue_box._close_dialogue()

	await create_timer(0.4).timeout
	_assert_true(signal_state["emitted"], "relief_examined sinyali başarıyla yayımlandı")
	_assert_true(dungeon._mural_reaction_done, "Stage2CastleDungeon._mural_reaction_done durumu true oldu")

	# 5. Tekrar Tetiklenmeme (Idempotency) Testi
	var second_signal_state = {"emitted": false}
	relief.relief_examined.connect(func():
		second_signal_state["emitted"] = true
	)
	relief.examine_relief()
	_assert_true(not second_signal_state["emitted"], "Kabartma ikinci kez incelenmek istendiğinde efektler üst üste binmiyor")

	# 6. Yetenek/Kalp Parçası Verilmediğini Doğrulama
	var game_state = root_node.get_node_or_null("GameState")
	if game_state and "collected_heart_pieces" in game_state:
		_assert_true(game_state.collected_heart_pieces.is_empty(), "Kabartma incelemesi gerçek Kalp Parçası vermiyor (yalnızca çevresel anlatım)")

	dungeon.queue_free()
	_finish()

func _finish() -> void:
	print("==================================================")
	print("  TEST SONUÇLARI: %d BAŞARILI, %d BAŞARISIZ" % [_passed_count, _failed_count])
	print("==================================================")
	quit(_failed_count)
