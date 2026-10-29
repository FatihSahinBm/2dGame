extends Node2D

## res://tests/verify_quest_runner.gd
## Story 2D-121: Görev Günlüğü ve Ekran Üstü Hedef Takibi Otomatik Doğrulama Testi

const QuestLogDialogScene = preload("res://scenes/ui/quest_log_dialog.tscn")
const FantasyHUDScene = preload("res://scenes/ui/fantasy_hud.tscn")
const Stage1CampScript = preload("res://scripts/levels/vlad/stage_1_camp.gd")

var _passed_tests: int = 0
var _failed_tests: int = 0


func _ready() -> void:
	get_tree().current_scene = self
	print("\n========================================================")
	print("  TEST: Story 2D-121 Görev Günlüğü ve Hedef Takip Sistemi")
	print("========================================================\n")

	_run_all_tests()

	print("\n========================================================")
	if _failed_tests == 0:
		print("  SONUÇ: %d/%d GÖREV SİSTEMİ TESTİ TAMAMEN BAŞARILI!" % [_passed_tests, _passed_tests])
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
	_test_1_quest_manager_initialization()
	_test_2_quest_start_and_stage_state()
	_test_3_objective_advancement_and_signals()
	_test_4_quest_completion_and_auto_tracking()
	_test_5_repeatable_and_non_repeatable_rules()
	_test_6_hud_objective_tracker_display()
	_test_7_hud_objective_complete_banner()
	_test_8_quest_log_dialog_tabs_and_details()
	_test_9_quest_log_dialog_tracking_switch()
	_test_10_quest_log_dialog_keyboard_toggle_and_pausing()
	_test_11_level_integration_camp_and_tent()
	_test_12_save_manager_quest_persistence()
	_test_13_audio_manager_procedural_sfx()


func _test_1_quest_manager_initialization() -> void:
	print("--- TEST 1: QuestManager İlklendirme ve Varsayılan Görevler ---")
	var q_mgr = get_node_or_null("/root/QuestManager")
	if not q_mgr:
		q_mgr = QuestManager
	_assert_true(q_mgr != null, "QuestManager örneği mevcut")

	q_mgr.reset_quests()
	var default_tracked = q_mgr.get_tracked_quest()
	_assert_true(not default_tracked.is_empty(), "Varsayılan takip edilen görev mevcut")
	_assert_true(default_tracked.get("id") == "fatih_audience", "Varsayılan takip edilen görev fatih_audience")
	_assert_true(q_mgr.is_quest_active("fatih_audience"), "fatih_audience başlangıçta aktif")

	var side_quest = q_mgr.get_quest("archer_quivers")
	_assert_true(not side_quest.is_empty(), "archer_quivers yan görevi kayıtlı")
	_assert_true(side_quest.get("status") == "not_started", "archer_quivers henüz başlamadı")
	_assert_true(side_quest.get("stages", []).size() == 2, "archer_quivers 2 aşamalı")

	var bridge_quest = q_mgr.get_quest("bridge_assault")
	_assert_true(not bridge_quest.is_empty(), "bridge_assault ana görevi kayıtlı")
	_assert_true(bridge_quest.get("stages", []).size() == 3, "bridge_assault 3 aşamalı")


func _test_2_quest_start_and_stage_state() -> void:
	print("--- TEST 2: Görev Başlatma ve Aşama Durumları ---")
	var q_mgr = QuestManager
	q_mgr.reset_quests()

	var received := {"started": false, "id": ""}
	var on_started = func(id: String, _dict: Dictionary):
		received["started"] = true
		received["id"] = id

	q_mgr.quest_started.connect(on_started)
	var ok: bool = q_mgr.start_quest("archer_quivers")
	q_mgr.quest_started.disconnect(on_started)

	_assert_true(ok, "start_quest('archer_quivers') başarılı")
	_assert_true(received["started"] and received["id"] == "archer_quivers", "quest_started sinyali doğru yayımlandı")
	_assert_true(q_mgr.is_quest_active("archer_quivers"), "archer_quivers artık aktif")

	var quest_data = q_mgr.get_quest("archer_quivers")
	_assert_true(quest_data.get("current_stage") == 0, "current_stage başlangıçta 0")
	var stages = quest_data.get("stages", [])
	_assert_true(not stages[0].get("completed", true), "Aşama 1 henüz tamamlanmadı")


func _test_3_objective_advancement_and_signals() -> void:
	print("--- TEST 3: Hedef İlerletme ve Sinyal Yayılımı ---")
	var q_mgr = QuestManager
	q_mgr.reset_quests()
	q_mgr.start_quest("archer_quivers")

	var received := {"completed": false, "stage_id": ""}
	var on_obj_completed = func(q_id: String, s_id: String, _desc: String):
		if q_id == "archer_quivers":
			received["completed"] = true
			received["stage_id"] = s_id

	q_mgr.objective_completed.connect(on_obj_completed)
	var advance_ok = q_mgr.advance_quest("archer_quivers", "find_quiver")
	q_mgr.objective_completed.disconnect(on_obj_completed)

	_assert_true(advance_ok, "advance_quest find_quiver başarılı")
	_assert_true(received["completed"] and received["stage_id"] == "find_quiver", "objective_completed sinyali doğru yayımlandı")

	var q = q_mgr.get_quest("archer_quivers")
	_assert_true(q.get("current_stage") == 1, "Mevcut aşama sıradaki aşama (1) oldu")
	_assert_true(q.get("stages")[0].get("completed") == true, "İlk aşama completed: true oldu")
	_assert_true(q.get("status") == "active", "Görev henüz tamamlanmadı, aktif kalmaya devam ediyor")


func _test_4_quest_completion_and_auto_tracking() -> void:
	print("--- TEST 4: Görev Tamamlama ve Otomatik Takip Geçişi ---")
	var q_mgr = QuestManager
	q_mgr.reset_quests()
	q_mgr.start_quest("archer_quivers")
	q_mgr.set_tracked_quest("archer_quivers")
	_assert_true(q_mgr.get_tracked_quest().get("id") == "archer_quivers", "Takip edilen görev archer_quivers olarak ayarlandı")

	var received := {"completed": false}
	var on_q_completed = func(q_id: String, _dict: Dictionary):
		if q_id == "archer_quivers":
			received["completed"] = true

	q_mgr.quest_completed.connect(on_q_completed)
	# 1. ve 2. aşamaları sırayla tamamla
	q_mgr.advance_quest("archer_quivers", "find_quiver")
	q_mgr.advance_quest("archer_quivers", "deliver_quiver")
	q_mgr.quest_completed.disconnect(on_q_completed)

	_assert_true(received["completed"], "quest_completed sinyali yayımlandı")
	_assert_true(q_mgr.is_quest_completed("archer_quivers"), "archer_quivers durumu 'completed'")
	_assert_true(not q_mgr.is_quest_active("archer_quivers"), "archer_quivers artık aktif değil")

	# Otomatik olarak sıradaki aktif göreve (fatih_audience) geçmeli
	var current_tracked = q_mgr.get_tracked_quest()
	_assert_true(current_tracked.get("id") == "fatih_audience", "Biten görev sonrası otomatik aktif fatih_audience takibe alındı")

	var completed_list = q_mgr.get_completed_quests()
	_assert_true(completed_list.size() >= 1, "get_completed_quests tamamlanan görevi içeriyor")


func _test_5_repeatable_and_non_repeatable_rules() -> void:
	print("--- TEST 5: Tekrarlanabilir ve Tekrarlanamaz Görev Kuralları ---")
	var q_mgr = QuestManager
	q_mgr.reset_quests()
	q_mgr.start_quest("archer_quivers")
	q_mgr.complete_quest("archer_quivers")

	# Tekrarlanamaz bir görev tamamlandıktan sonra yeniden başlatılamamalı
	var restart_ok = q_mgr.start_quest("archer_quivers")
	_assert_true(not restart_ok, "Tekrarlanamaz tamamlanmış görev yeniden başlatılamaz")

	# Tekrarlanabilir test görevi kaydet
	q_mgr.register_quest({
		"id": "bounty_undead",
		"title": "Avcı Sözleşmesi",
		"category": "side",
		"status": "not_started",
		"repeatable": true,
		"stages": [{"id": "hunt", "description": "3 Hortlak Avla", "completed": false}]
	})

	q_mgr.start_quest("bounty_undead")
	q_mgr.complete_quest("bounty_undead")
	_assert_true(q_mgr.is_quest_completed("bounty_undead"), "Avcı sözleşmesi tamamlandı")

	var restart_repeatable = q_mgr.start_quest("bounty_undead")
	_assert_true(restart_repeatable, "Tekrarlanabilir görev tamamlandıktan sonra yeniden başlatılabilir")
	_assert_true(q_mgr.is_quest_active("bounty_undead"), "Yeniden başlatılan görev tekrar aktif oldu")


func _test_6_hud_objective_tracker_display() -> void:
	print("--- TEST 6: HUD Hedef Takip Bileşeni Görselleştirme ---")
	var q_mgr = QuestManager
	q_mgr.reset_quests()

	var hud = FantasyHUDScene.instantiate()
	add_child(hud)

	var tracker: PanelContainer = hud.get_node_or_null("TopLeft/HBoxContainer/BarsVBox/ObjectiveTracker")
	var title_lbl: Label = hud.get_node_or_null("TopLeft/HBoxContainer/BarsVBox/ObjectiveTracker/VBox/HeaderHBox/QuestTitle")
	var badge_lbl: Label = hud.get_node_or_null("TopLeft/HBoxContainer/BarsVBox/ObjectiveTracker/VBox/HeaderHBox/Badge")
	var desc_lbl: Label = hud.get_node_or_null("TopLeft/HBoxContainer/BarsVBox/ObjectiveTracker/VBox/ObjectiveLabel")

	_assert_true(tracker != null, "HUD ObjectiveTracker düğümü mevcut")
	_assert_true(tracker.visible, "Varsayılan fatih_audience takipli iken Tracker görünür")
	_assert_true(title_lbl.text == "Otağ-ı Hümayun ve Sefer Meclisi", "Doğru görev başlığı görüntülendi")
	_assert_true(badge_lbl.text == "ANA GÖREV", "Doğru rozet metni görüntülendi (ANA GÖREV)")
	_assert_true("otağına gir" in desc_lbl.text.to_lower(), "Hedef aşama açıklaması doğru yazıldı")

	# Takip edilen görevi temizle / bitir
	q_mgr.complete_quest("fatih_audience")
	hud.update_tracked_objective({})
	_assert_true(not tracker.visible, "Takip edilen aktif görev yokken Tracker gizlendi")

	hud.free()


func _test_7_hud_objective_complete_banner() -> void:
	print("--- TEST 7: HUD Hedef Tamamlama Kutlama Bayrağı (Banner/Toast) ---")
	var hud = FantasyHUDScene.instantiate()
	add_child(hud)

	var banner: PanelContainer = hud.get_node_or_null("ObjectiveBanner")
	var banner_lbl: Label = hud.get_node_or_null("ObjectiveBanner/BannerLabel")
	_assert_true(banner != null, "ObjectiveBanner düğümü mevcut")
	_assert_true(banner_lbl != null, "BannerLabel düğümü mevcut")

	hud.show_objective_complete_banner("Alevli ok sadaklarını topla", false)
	_assert_true(banner.visible, "show_objective_complete_banner çağrıldığında banner görünür oldu")
	_assert_true("HEDEF TAMAMLANDI" in banner_lbl.text, "Hedef banner metni içeriyor")
	_assert_true("Alevli ok sadaklarını topla" in banner_lbl.text, "Hedef açıklaması banner'da gösterildi")

	hud.show_objective_complete_banner("Otağ-ı Hümayun ve Sefer Meclisi", true)
	_assert_true("GÖREV TAMAMLANDI" in banner_lbl.text, "Görev tamamlama banner'ı doğru başlık kullandı")

	hud.free()


func _test_8_quest_log_dialog_tabs_and_details() -> void:
	print("--- TEST 8: Görev Günlüğü Sekmeleri ve Detay Paneli ---")
	var q_mgr = QuestManager
	q_mgr.reset_quests()
	q_mgr.start_quest("archer_quivers")
	q_mgr.complete_quest("archer_quivers")

	var dialog = QuestLogDialogScene.instantiate()
	add_child(dialog)

	dialog.open()
	_assert_true(dialog.visible, "QuestLogDialog.open() pencereyi açtı")

	var active_tab_btn: Button = dialog.get_node_or_null("Panel/VBox/TabsContainer/BtnActive")
	var completed_tab_btn: Button = dialog.get_node_or_null("Panel/VBox/TabsContainer/BtnCompleted")
	var quest_list: VBoxContainer = dialog.get_node_or_null("Panel/VBox/MainSplit/LeftPane/Scroll/QuestList")
	var title_lbl: Label = dialog.get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/Header/TitleLabel")
	var stages_vbox: VBoxContainer = dialog.get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/StagesContainer")

	_assert_true(active_tab_btn != null and completed_tab_btn != null, "Sekme butonları mevcut")
	_assert_true(quest_list != null and quest_list.get_child_count() > 0, "Aktif sekmesinde görev listelendi")
	_assert_true(title_lbl.text == "Otağ-ı Hümayun ve Sefer Meclisi", "İlk aktif görev otomatik seçildi")
	_assert_true(stages_vbox != null and stages_vbox.get_child_count() > 0, "Aşama kontrol kutuları listelendi")

	# Tamamlanan sekmesine geçiş
	completed_tab_btn.emit_signal("pressed")
	_assert_true(quest_list.get_child_count() > 0, "Tamamlanan sekmesinde archer_quivers listelendi")
	_assert_true(title_lbl.text == "Alevli Ok Sadakları", "Tamamlanan görev detayları doğru görüntülendi")

	dialog.close()
	_assert_true(not dialog.visible, "QuestLogDialog.close() pencereyi kapattı")
	dialog.free()


func _test_9_quest_log_dialog_tracking_switch() -> void:
	print("--- TEST 9: Görev Günlüğü Üzerinden Takip Değiştirme ---")
	var q_mgr = QuestManager
	q_mgr.reset_quests()
	q_mgr.start_quest("archer_quivers")
	q_mgr.set_tracked_quest("fatih_audience")
	_assert_true(q_mgr.get_tracked_quest().get("id") == "fatih_audience", "Başlangıçta fatih_audience takipli")

	var dialog = QuestLogDialogScene.instantiate()
	add_child(dialog)
	dialog.open()

	# archer_quivers görevini seç
	dialog.select_quest("archer_quivers")
	var btn_track: Button = dialog.get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/TrackContainer/BtnTrack")
	_assert_true(btn_track != null, "BtnTrack butonu mevcut")

	btn_track.emit_signal("pressed")
	_assert_true(q_mgr.get_tracked_quest().get("id") == "archer_quivers", "Takip butonuyla archer_quivers takibe alındı")

	dialog.close()
	dialog.free()


func _test_10_quest_log_dialog_keyboard_toggle_and_pausing() -> void:
	print("--- TEST 10: Klavye / Gamepad ile Günlük Açma / Kapama ve Duraklatma ---")
	var dialog = QuestLogDialogScene.instantiate()
	add_child(dialog)

	get_tree().paused = false
	_assert_true(not dialog.visible, "Başlangıçta kapalı")

	# [J] tuşu simülasyonu
	var event_j = InputEventKey.new()
	event_j.pressed = true
	event_j.keycode = KEY_J
	dialog._unhandled_input(event_j)

	_assert_true(dialog.visible, "[J] tuşuna basılınca QuestLog açıldı")
	_assert_true(get_tree().paused, "QuestLog açılınca oyun duraklatıldı")

	# [ESC] tuşu simülasyonu
	var event_esc = InputEventKey.new()
	event_esc.pressed = true
	event_esc.keycode = KEY_ESCAPE
	dialog._unhandled_input(event_esc)

	_assert_true(not dialog.visible, "[ESC] tuşuna basılınca QuestLog kapandı")
	_assert_true(not get_tree().paused, "QuestLog kapanınca duraklatma çözüldü")

	dialog.free()


func _test_11_level_integration_camp_and_tent() -> void:
	print("--- TEST 11: Seviye Entegrasyonu (Ordugah ve Otağ Görev Akışı) ---")
	var q_mgr = QuestManager
	q_mgr.reset_quests()

	# Sahne mock: Düğümleri hazırla
	var camp = Stage1CampScript.new()
	var dummy_player = CharacterBody2D.new()
	dummy_player.name = "CombatPlayer"
	camp.add_child(dummy_player)
	var dummy_hud = CanvasLayer.new()
	dummy_hud.name = "FantasyHUD"
	camp.add_child(dummy_hud)
	var dummy_dialogue = CanvasLayer.new()
	dummy_dialogue.name = "DialogueBox"
	camp.add_child(dummy_dialogue)
	var dummy_gate = Area2D.new()
	dummy_gate.name = "TentEntranceArea"
	camp.add_child(dummy_gate)
	add_child(camp)

	# 1. Kemankeş ile diyalog kabul
	camp._on_dialogue_choice_selected("accept")
	_assert_true(q_mgr.is_quest_active("archer_quivers"), "Kemankeş görevi kabul edilince archer_quivers aktif oldu")

	# 2. Sadakları topla
	camp._on_quiver_collected()
	var q_data = q_mgr.get_quest("archer_quivers")
	_assert_true(q_data.get("current_stage") == 1, "Sadak toplanınca aşama 1'e ilerledi")

	# 3. Kemankeş'e teslim et
	camp._deliver_quiver_to_archer()
	_assert_true(q_mgr.is_quest_completed("archer_quivers"), "Sadak teslim edilince archer_quivers tamamlandı")

	# 4. Çadıra giriş kapısı
	camp._trigger_tent_transition()
	var fatih_q = q_mgr.get_quest("fatih_audience")
	_assert_true(fatih_q.get("stages")[0].get("completed") == true, "Çadıra girilince fatih_audience aşaması tamamlandı")

	dummy_player.free()
	dummy_hud.free()
	dummy_dialogue.free()
	dummy_gate.free()
	camp.free()


func _test_12_save_manager_quest_persistence() -> void:
	print("--- TEST 12: SaveManager Kayıt ve Yükleme Entegrasyonu ---")
	var q_mgr = QuestManager
	q_mgr.reset_quests()
	q_mgr.start_quest("archer_quivers")
	q_mgr.advance_quest("archer_quivers", "find_quiver")
	q_mgr.set_tracked_quest("archer_quivers")

	# Dışa aktar
	var save_data = q_mgr.export_save_data()
	_assert_true(save_data.has("tracked_quest_id") and save_data["tracked_quest_id"] == "archer_quivers", "Kayıt verisi tracked_quest_id içeriyor")
	_assert_true(save_data.has("quests"), "Kayıt verisi quests sözlüğü içeriyor")

	# QuestManager'ı sıfırla
	q_mgr.reset_quests()
	_assert_true(q_mgr.get_tracked_quest().get("id") == "fatih_audience", "Sıfırlama sonrası fatih_audience takipli")

	# Geri yükle
	q_mgr.import_save_data(save_data)
	_assert_true(q_mgr.get_tracked_quest().get("id") == "archer_quivers", "Geri yükleme sonrası archer_quivers takipli")
	var restored_q = q_mgr.get_quest("archer_quivers")
	_assert_true(restored_q.get("current_stage") == 1, "Geri yükleme sonrası aşama 1 korundu")
	_assert_true(restored_q.get("stages")[0].get("completed") == true, "Geri yükleme sonrası aşama 0 tamamlanma durumu korundu")


func _test_13_audio_manager_procedural_sfx() -> void:
	print("--- TEST 13: AudioManager Prosedürel Görev Ses Efektleri ---")
	var audio_mgr = AudioManager
	if not audio_mgr:
		audio_mgr = get_node_or_null("/root/AudioManager")

	var sfx_keys = ["objective_complete", "quest_complete", "quest_log_open", "quest_log_close"]
	for sfx in sfx_keys:
		_assert_true(audio_mgr.has_sound(sfx), "AudioManager '%s' ses kaydına sahip" % sfx)
		var entry = audio_mgr._sound_registry.get(sfx)
		_assert_true(entry is Callable or entry is AudioStream, "'%s' geçerli ses üreticisi veya AudioStream" % sfx)
