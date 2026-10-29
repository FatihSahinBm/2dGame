extends Node2D

## res://tests/verify_inventory_runner.gd
## Story 2D-123: Envanter ve Kalp Parçaları Arayüzü Otomatik Doğrulama Testi

const InventoryDialogScene = preload("res://scenes/ui/inventory_dialog.tscn")
const FantasyHUDScene = preload("res://scenes/ui/fantasy_hud.tscn")
const PlayerScene = preload("res://scenes/player.tscn")

var _passed_tests: int = 0
var _failed_tests: int = 0


func _ready() -> void:
	get_tree().current_scene = self
	print("\n========================================================")
	print("  TEST: Story 2D-123 Envanter ve Kalp Parçaları Arayüzü ")
	print("========================================================\n")

	_run_all_tests()

	print("\n========================================================")
	if _failed_tests == 0:
		print("  SONUÇ: %d/%d ENVANTER VE KALP PARÇALARI TESTİ TAMAMEN BAŞARILI!" % [_passed_tests, _passed_tests])
	else:
		printerr("  HATA: %d test BAŞARISIZ OLDU! (Başarılı: %d)" % [_failed_tests, _passed_tests])
	print("========================================================\n")

	get_tree().quit(0 if _failed_tests == 0 else 1)


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		_passed_tests += 1
		print("PASS: %s" % test_name)
	else:
		_failed_tests += 1
		printerr("FAIL: %s" % test_name)


func _run_all_tests() -> void:
	_test_1_scene_and_node_hierarchy()
	_test_2_items_list_populating()
	_test_3_item_selection_and_detail_panel()
	_test_4_health_potion_consumption()
	_test_5_mana_potion_consumption()
	_test_6_secondary_weapon_equipping()
	_test_7_heart_quadrant_progression()
	_test_8_heart_piece_detail_lore()
	_test_9_keyboard_gamepad_toggle_and_pausing()
	_test_10_hud_inventory_integration()
	_test_11_save_manager_persistence()
	_test_12_procedural_audio_feedback()


func _test_1_scene_and_node_hierarchy() -> void:
	print("--- TEST 1: Sahne ve Düğüm Hiyerarşisi ---")
	var dialog = InventoryDialogScene.instantiate()
	add_child(dialog)

	_assert_true(dialog != null, "InventoryDialog sahnesi başarıyla yüklendi")
	_assert_true(dialog.btn_items_tab != null, "BtnItems sekme butonu mevcut")
	_assert_true(dialog.btn_heart_tab != null, "BtnHeart sekme butonu mevcut")
	_assert_true(dialog.item_list_container != null, "ItemList konteyneri mevcut")
	_assert_true(dialog.title_label != null, "Detay TitleLabel mevcut")
	_assert_true(dialog.category_badge != null, "CategoryBadge mevcut")
	_assert_true(dialog.desc_label != null, "DescLabel mevcut")
	_assert_true(dialog.action_button != null, "BtnAction butonu mevcut")
	_assert_true(dialog.btn_close != null, "BtnClose butonu mevcut")

	dialog.free()


func _test_2_items_list_populating() -> void:
	print("--- TEST 2: Çanta ve Eşya Listesi Doldurma ---")
	var hud = FantasyHUDScene.instantiate()
	hud.name = "FantasyHUD"
	add_child(hud)
	hud.health_potions = 4
	hud.mana_potions = 3
	hud.coins = 150
	hud.keys = 2

	var dialog = InventoryDialogScene.instantiate()
	add_child(dialog)
	dialog.open()

	var pot_item = dialog.get_item_data("health_potion")
	_assert_true(not pot_item.is_empty(), "Can İksiri verisi mevcut")
	_assert_true(pot_item["count"] == 4, "Can İksiri adedi HUD ile tutarlı (4)")
	_assert_true(pot_item["category"] == "consumable", "Can İksiri kategorisi consumable")

	var mana_item = dialog.get_item_data("mana_potion")
	_assert_true(not mana_item.is_empty(), "Mana İksiri verisi mevcut")
	_assert_true(mana_item["count"] == 3, "Mana İksiri adedi HUD ile tutarlı (3)")

	var coin_item = dialog.get_item_data("coins")
	_assert_true(coin_item["count"] == 150, "Altın Akçe adedi 150")

	var key_item = dialog.get_item_data("keys")
	_assert_true(key_item["count"] == 2, "Zindan Anahtarı adedi 2")

	var knife_item = dialog.get_item_data("secondary_knife")
	_assert_true(not knife_item.is_empty(), "Fırlatma Bıçağı verisi mevcut")
	_assert_true(knife_item["category"] == "secondary", "Bıçak kategorisi secondary")

	dialog.close()
	dialog.free()
	hud.free()


func _test_3_item_selection_and_detail_panel() -> void:
	print("--- TEST 3: Eşya Seçimi ve Detay Paneli Görselleştirmesi ---")
	var hud = FantasyHUDScene.instantiate()
	hud.name = "FantasyHUD"
	add_child(hud)

	var dialog = InventoryDialogScene.instantiate()
	add_child(dialog)
	dialog.open()

	var selected_events: Array[String] = []
	dialog.item_selected.connect(func(id, _data): selected_events.append(id))

	dialog.select_item("health_potion")
	_assert_true(selected_events.has("health_potion"), "item_selected sinyali yayımlandı")
	_assert_true(dialog.title_label.text == "Kırmızı Can İksiri", "Başlık etiketi doğru güncellendi")
	_assert_true("TÜKETİLEBİLİR" in dialog.category_badge.text, "Kategori rozeti tüketilebilir olarak işaretlendi")
	_assert_true("[2]" in dialog.shortcut_badge.text, "Kısayol rozeti [2] tuşunu gösteriyor")
	_assert_true("şifalı karışım" in dialog.desc_label.text.to_lower(), "Açıklama metni zengin arka plan içeriyor")

	dialog.close()
	dialog.free()
	hud.free()


func _test_4_health_potion_consumption() -> void:
	print("--- TEST 4: Can İksiri Tüketimi ve Senkronizasyon ---")
	var hud = FantasyHUDScene.instantiate()
	hud.name = "FantasyHUD"
	add_child(hud)
	hud.max_health = 100
	hud.current_health = 50
	hud.health_potions = 3

	var dialog = InventoryDialogScene.instantiate()
	add_child(dialog)
	dialog.open()

	dialog.select_item("health_potion")
	_assert_true(dialog.action_button.visible, "Aksiyon butonu görünür")
	_assert_true(not dialog.action_button.disabled, "Can eksikken aksiyon butonu aktif")

	var item_used_received := {"fired": false}
	dialog.item_used.connect(func(_id): item_used_received["fired"] = true)

	dialog.action_button.emit_signal("pressed")

	_assert_true(item_used_received["fired"], "item_used sinyali tetiklendi")
	_assert_true(hud.current_health == 85, "Can 35 puan arttı (50 -> 85)")
	_assert_true(hud.health_potions == 2, "Kalan can iksiri 1 azaldı (3 -> 2)")

	# Canı 100'e fulle
	hud.current_health = 100
	dialog.refresh_inventory()
	dialog.select_item("health_potion")
	_assert_true(dialog.action_button.disabled, "Can tam iken iksir içme butonu devre dışı bırakıldı")

	dialog.close()
	dialog.free()
	hud.free()


func _test_5_mana_potion_consumption() -> void:
	print("--- TEST 5: Mana İksiri Tüketimi ---")
	var hud = FantasyHUDScene.instantiate()
	hud.name = "FantasyHUD"
	add_child(hud)
	hud.max_mana = 40
	hud.current_mana = 10
	hud.mana_potions = 2

	var dialog = InventoryDialogScene.instantiate()
	add_child(dialog)
	dialog.open()

	dialog.select_item("mana_potion")
	_assert_true(not dialog.action_button.disabled, "Mana eksikken buton aktif")

	dialog.action_button.emit_signal("pressed")

	_assert_true(hud.current_mana == 30, "Mana 20 puan arttı (10 -> 30)")
	_assert_true(hud.mana_potions == 1, "Kalan mana iksiri 1 azaldı (2 -> 1)")

	dialog.close()
	dialog.free()
	hud.free()


func _test_6_secondary_weapon_equipping() -> void:
	print("--- TEST 6: İkincil Fırlatılabilir Eşya Kuşanma ---")
	var player = PlayerScene.instantiate()
	player.name = "CombatPlayer"
	add_child(player)
	player.secondary_inventory = {"knife": 5, "torch": 3, "holy_water": 2}
	player.active_secondary_type = "knife"

	var dialog = InventoryDialogScene.instantiate()
	add_child(dialog)
	dialog.open()

	# Meşale seç
	dialog.select_item("secondary_torch")
	_assert_true(dialog.action_button.visible, "Meşale için kuşanma butonu görünür")
	_assert_true("Hızlı Yuvaya Ata" in dialog.action_button.text, "Buton 'Hızlı Yuvaya Ata' metnine sahip")

	var equipped_received := {"type": ""}
	dialog.secondary_equipped.connect(func(type): equipped_received["type"] = type)

	dialog.action_button.emit_signal("pressed")

	_assert_true(equipped_received["type"] == "torch", "secondary_equipped('torch') yayımlandı")
	_assert_true(player.active_secondary_type == "torch", "Oyuncunun aktif ikincil eşyası 'torch' oldu")

	dialog.close()
	dialog.free()
	player.free()


func _test_7_heart_quadrant_progression() -> void:
	print("--- TEST 7: Dünya Kalbi Kadranı ve İlerleme Yüzdesi ---")
	var game_state = get_node_or_null("/root/GameState")
	if not game_state:
		game_state = Node.new()
		game_state.name = "GameState"
		add_child(game_state)
	game_state.set("current_heart_pieces", 1)

	var dialog = InventoryDialogScene.instantiate()
	add_child(dialog)
	dialog.open()

	# Kalp kadranı sekmesine geç
	dialog.switch_tab("heart")
	_assert_true(dialog.heart_quadrant_container.visible, "Kalp kadranı görünür oldu")
	_assert_true("1 / 4" in dialog.heart_progress_label.text and "25" in dialog.heart_progress_label.text, "Kadran 1/4 ve %25 ilerleme gösterdi")

	var slot1: Button = dialog.heart_quadrant_container.get_node_or_null("QuadrantSlot1")
	var slot2: Button = dialog.heart_quadrant_container.get_node_or_null("QuadrantSlot2")
	_assert_true(slot1 != null and "💎" in slot1.text, "1. Kalp Parçası toplandı (💎)")
	_assert_true(slot2 != null and "🔒" in slot2.text, "2. Kalp Parçası henüz kilitli (🔒)")

	# 2. Kalp Parçasını topla (Vlad Boss zaferi simülasyonu)
	game_state.set("current_heart_pieces", 2)
	dialog.refresh_inventory()
	_assert_true("2 / 4" in dialog.heart_progress_label.text and "50" in dialog.heart_progress_label.text, "Kadran 2/4 ve %50 ilerleme gösterdi")
	_assert_true("💎" in slot2.text, "2. Kalp Parçası artık toplandı ve parıldıyor (💎)")

	dialog.close()
	dialog.free()


func _test_8_heart_piece_detail_lore() -> void:
	print("--- TEST 8: Kalp Parçası Detay Paneli ve Hikâye Anlatımı ---")
	var game_state = get_node_or_null("/root/GameState")
	game_state.set("current_heart_pieces", 1)

	var dialog = InventoryDialogScene.instantiate()
	add_child(dialog)
	dialog.open()
	dialog.switch_tab("heart")

	# Parça 1 seç
	dialog.select_item("heart_fragment_1")
	_assert_true("Kadim Yankı" in dialog.title_label.text, "Parça 1 doğru başlığı taşıyor")
	_assert_true("TOPLANDI" in dialog.category_badge.text, "Toplandı rozeti görüntülendi")
	_assert_true("Kalp Rezonansı" in dialog.shortcut_badge.text, "Kazanılan yetenek Kalp Rezonansı")
	_assert_true("T-Rex" in dialog.desc_label.text, "Hikâye T-Rex kraterini anlatıyor")

	# Kilitli Parça 3 seç
	dialog.select_item("heart_fragment_3")
	_assert_true("KİLİTLİ" in dialog.category_badge.text, "Parça 3 kilitli rozetine sahip")
	_assert_true(dialog.action_button.disabled, "Kilitli parça rezonans butonu devre dışı")

	dialog.close()
	dialog.free()


func _test_9_keyboard_gamepad_toggle_and_pausing() -> void:
	print("--- TEST 9: Klavye / Gamepad ile Açma / Kapama ve Duraklatma ---")
	var dialog = InventoryDialogScene.instantiate()
	add_child(dialog)

	get_tree().paused = false
	_assert_true(not dialog.visible, "Başlangıçta envanter kapalı")

	# [I] Tuşu simülasyonu
	var event_i = InputEventKey.new()
	event_i.pressed = true
	event_i.keycode = KEY_I
	dialog._unhandled_input(event_i)

	_assert_true(dialog.visible, "[I] tuşuna basılınca envanter açıldı")
	_assert_true(get_tree().paused, "Envanter açılınca oyun duraklatıldı")

	# [TAB] Tuşu ile sekme geçişi
	var event_tab = InputEventKey.new()
	event_tab.pressed = true
	event_tab.keycode = KEY_TAB
	dialog._unhandled_input(event_tab)
	_assert_true(dialog._current_tab == "heart", "[TAB] tuşuyla Kalp Kadranı sekmesine geçildi")

	# [ESC] Tuşu ile kapatma
	var event_esc = InputEventKey.new()
	event_esc.pressed = true
	event_esc.keycode = KEY_ESCAPE
	dialog._unhandled_input(event_esc)

	_assert_true(not dialog.visible, "[ESC] tuşuna basılınca envanter kapandı")
	_assert_true(not get_tree().paused, "Envanter kapanınca oyun duraklatması çözüldü")

	dialog.free()


func _test_10_hud_inventory_integration() -> void:
	print("--- TEST 10: FantasyHUD Entegrasyonu ---")
	var hud = FantasyHUDScene.instantiate()
	hud.name = "FantasyHUD"
	add_child(hud)

	_assert_true(hud.has_method("toggle_inventory"), "FantasyHUD toggle_inventory() metoduna sahip")

	hud.toggle_inventory()
	_assert_true(hud.inventory_dialog != null, "HUD inventory_dialog örneğini oluşturdu")
	_assert_true(hud.inventory_dialog.visible, "toggle_inventory() pencereyi açtı")

	hud.toggle_inventory()
	_assert_true(not hud.inventory_dialog.visible, "İkinci toggle_inventory() pencereyi kapattı")

	hud.free()


func _test_11_save_manager_persistence() -> void:
	print("--- TEST 11: SaveManager Kalıcılık ve Canlı Veri Tutarlılığı ---")
	var save_mgr = SaveManager
	var game_state = GameState

	# Test değerleri ata
	game_state.current_heart_pieces = 2

	var hud = FantasyHUDScene.instantiate()
	hud.name = "FantasyHUD"
	add_child(hud)
	hud.health_potions = 5
	hud.mana_potions = 4
	hud.coins = 320

	save_mgr.save_game(1)

	# Sıfırla
	hud.health_potions = 1
	hud.mana_potions = 1
	hud.coins = 0
	game_state.current_heart_pieces = 0

	# Geri yükle ve mevcut düğümlere uygula
	save_mgr.load_game(1)
	save_mgr.apply_cached_stats_to_scene(self)

	_assert_true(hud.health_potions == 5, "Kayıttan can iksirleri (5) yüklendi")
	_assert_true(hud.mana_potions == 4, "Kayıttan mana iksirleri (4) yüklendi")
	_assert_true(hud.coins == 320, "Kayıttan akçeler (320) yüklendi")
	_assert_true(game_state.current_heart_pieces == 2, "Kayıttan Kalp Parçaları (2) yüklendi")

	hud.free()


func _test_12_procedural_audio_feedback() -> void:
	print("--- TEST 12: AudioManager Prosedürel Envanter Sesleri ---")
	var audio_mgr = AudioManager

	var sfx_list = ["inventory_open", "inventory_close", "potion_drink", "item_equip"]
	for sfx in sfx_list:
		_assert_true(audio_mgr.has_sound(sfx), "AudioManager '%s' ses kaydına sahip" % sfx)
		var entry = audio_mgr._sound_registry.get(sfx)
		_assert_true(entry is Callable or entry is AudioStream, "'%s' geçerli ses üreticisi veya AudioStream" % sfx)
