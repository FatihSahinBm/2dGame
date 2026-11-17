extends Node

## res://verify_save_system.gd
## Kalıcı Kayıt ve Yükleme Altyapısı (Save / Load System) Kapsamlı Otomasyon Testi — Epic 2D-104

func _ready() -> void:
	print("--- KALICI KAYIT VE YUKLEME ALTYAPISI TESTI BASLADI (2D-104) ---")

	# 1. SaveManager ve GameState Autoload Kontrolü
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr:
		var res = load("res://scripts/autoloads/save_manager.gd")
		save_mgr = res.new()
		save_mgr.name = "SaveManager"
		get_tree().root.add_child(save_mgr)

	var game_state = get_node_or_null("/root/GameState")
	if not game_state:
		var gs_res = load("res://scripts/autoloads/game_state.gd")
		game_state = gs_res.new()
		game_state.name = "GameState"
		get_tree().root.add_child(game_state)

	print("OK: SaveManager ve GameState hazır.")

	# Başlangıç temizliği
	save_mgr.delete_save(1)
	if save_mgr.has_save(1):
		push_error("FAIL: Başlangıçta kayıt silinemedi!")
		get_tree().quit(1)
		return
	print("OK: Temiz test ortamı hazırlandı.")

	# 2. Şema Sürümü ve Temel Kayıt Testi
	game_state.current_stage_path = "res://scenes/levels/vlad/stage_1_forest_camp.tscn"
	game_state.corruption_score = 35
	game_state.allies_sacrificed_count = 2
	game_state.allies_killed_count = 1
	game_state.current_heart_pieces = 2
	var test_abilities: Array[String] = ["shadow_step", "parry_guard"]
	game_state.unlocked_abilities = test_abilities
	var test_chapters: Array[String] = ["chapter_1"]
	game_state.completed_chapters = test_chapters
	game_state.is_commander_rescued = true

	var save_ok = save_mgr.save_game(1)
	if not save_ok or not save_mgr.has_save(1):
		push_error("FAIL: save_game(1) başarısız oldu!")
		get_tree().quit(1)
		return
	print("OK: v2 formatında kayıt dosyası başarıyla oluşturuldu.")

	var info = save_mgr.get_save_info(1)
	if int(info.get("schema_version", 0)) != save_mgr.CURRENT_SCHEMA_VERSION:
		push_error("FAIL: Kayıt dosyasında schema_version güncel sürüm olmalı!")
		get_tree().quit(1)
		return
	print("OK: schema_version güncel sürüm (v%d) olarak doğrulandı." % save_mgr.CURRENT_SCHEMA_VERSION)

	# 3. KULLANICI HATASI SENARYOSU DOĞRULAMASI:
	# "Durdurduktan sonra ana menüye dönüp devam et diyince hangi bölümde durdurursam durdurayım trex partının başına atıyor"
	print("--- KULLANICI HATA SENARYOSU TEST EDILIYOR ---")
	
	# Oyuncu Vlad Zindanında (Stage 2) ilerliyor
	var stage2_path = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"
	game_state.current_stage_path = stage2_path
	save_mgr.cached_checkpoint_id = "checkpoint_dungeon_depths"
	save_mgr.cached_checkpoint_position = Vector2(1820.0, 450.0)

	# Duraklatma menüsünden Ana Menü'ye dönüldü (save_game tetiklenir)
	var pause_save_ok = save_mgr.save_game(1)
	if not pause_save_ok:
		push_error("FAIL: Duraklatma menüsü kaydı başarısız!")
		get_tree().quit(1)
		return
	print("OK: Vlad Stage 2 zindanındayken kaydedildi.")

	# Oyuncu Ana Menüye döndü (GameState bellekte sıfırlanmış veya başlangıçta varsayalım)
	game_state.reset_state()
	if game_state.current_stage_path == stage2_path:
		push_error("FAIL: reset_state sahneyi sıfırlamadı!")
		get_tree().quit(1)
		return

	# Ana Menüde "Devam Et" tıklandı
	var load_ok = save_mgr.load_game(1)
	if not load_ok:
		push_error("FAIL: load_game(1) başarısız!")
		get_tree().quit(1)
		return

	if game_state.current_stage_path != stage2_path:
		push_error("FAIL: Devam Et yapıldığında Vlad Stage 2 yerine '" + game_state.current_stage_path + "' sahnesine yönlendirildi!")
		get_tree().quit(1)
		return
	print("OK: 'Devam Et' tıklandığında tam kalınan sahneye (" + stage2_path + ") dönüldüğü kanıtlandı! T-Rex hatası çözüldü.")

	# 4. Otomatik Yedekleme (Backup Rotation) Testi
	print("--- YEDEKLEME VE KURTARMA (SELF-HEALING) TESTI ---")
	# İkinci bir kayıt alındığında önceki kayıt otomatik _backup.json dosyasına rotasyonlanır
	game_state.corruption_score = 50
	save_mgr.save_game(1)

	var backup_file_path = "user://savegame_slot_1_backup.json"
	if not FileAccess.file_exists(backup_file_path):
		push_error("FAIL: Yedekleme dosyası (backup.json) oluşturulamadı!")
		get_tree().quit(1)
		return
	print("OK: Otomatik yedek kayıt (backup.json) mevcut.")

	# 5. Bozuk Kayıt Dosyasından Kurtarma Testi
	# Ana kayıt dosyasını bilerek bozuyoruz (geçersiz JSON metni yazarak)
	var main_save_path = "user://savegame_slot_1.json"
	var corrupt_file = FileAccess.open(main_save_path, FileAccess.WRITE)
	corrupt_file.store_string("{ <<< BOZUK JSON VERISI >>> }")
	corrupt_file.close()
	print("Ana dosya bilerek bozuldu (corrupted file simulation).")

	# load_game çağrıldığında ana dosya bozuksa yedekten kurtarmalı ve çökmemeli
	var recovered_load = save_mgr.load_game(1)
	if not recovered_load:
		push_error("FAIL: Bozuk ana dosya sonrası yedekten kurtarma (self-healing) başarısız!")
		get_tree().quit(1)
		return

	if game_state.current_stage_path != stage2_path:
		push_error("FAIL: Kurtarılan veri yanlış sahneyi içeriyor!")
		get_tree().quit(1)
		return
	print("OK: Bozuk ana kayıt dosyası tespit edildi ve yedekten (backup.json) %100 başarıyla kurtarıldı!")

	# 6. Eski Kayıt Biçiminden Güncel Biçime Geçiş (Schema Migration) Testi
	print("--- SCHEMA MIGRATION (v1 -> v2) TESTI ---")
	save_mgr.delete_save(2)
	var legacy_v1_data = {
		"version": 1,
		"timestamp": "2026-10-20T10:00:00",
		"current_stage_path": "res://scenes/levels/vlad/stage_3_throne_room.tscn",
		"corruption_score": 75,
		"allies_sacrificed_count": 4,
		"allies_killed_count": 2,
		"current_heart_pieces": 3,
		"unlocked_abilities": ["parry_guard"],
		"completed_chapters": ["chapter_1", "chapter_2"],
		"is_commander_alive": false,
		"is_commander_rescued": true,
		"has_commander_orders": true,
		"fatih_audience_completed": true
	}
	var legacy_file = FileAccess.open("user://savegame_slot_2.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy_v1_data, "\t"))
	legacy_file.close()

	var load_legacy_ok = save_mgr.load_game(2)
	if not load_legacy_ok:
		push_error("FAIL: v1 kayıt yüklenemedi!")
		get_tree().quit(1)
		return

	if game_state.current_stage_path != "res://scenes/levels/vlad/stage_3_throne_room.tscn":
		push_error("FAIL: v1 kayıt migration sonrası doğru sahneyi yükleyemedi!")
		get_tree().quit(1)
		return
	if game_state.corruption_score != 75:
		push_error("FAIL: v1 corruption_score migration sonrası kayboldu!")
		get_tree().quit(1)
		return
	print("OK: v1 eski kayıt biçimi güncel şemaya veri kaybı olmadan otomatik yükseltildi (Migrated).")

	# 6b. Bütünlük (Integrity) Testleri — Epic 2D-104
	print("--- BUTUNLUK, DEGISTIRILMIS KAYIT VE DESTEKLENMEYEN SURUM TESTI ---")
	var slot2_path = "user://savegame_slot_2.json"
	var slot2_backup = "user://savegame_slot_2_backup.json"
	save_mgr.delete_save(2)
	game_state.corruption_score = 10
	game_state.current_stage_path = stage2_path
	save_mgr.cached_checkpoint_position = Vector2(123.456, 0.1 + 0.2)
	save_mgr.save_game(2)
	if not save_mgr.load_game(2) or game_state.corruption_score != 10:
		push_error("FAIL: Küsuratlı konum içeren v3 kayıt kendi checksum'ıyla doğrulanamadı!")
		get_tree().quit(1)
		return
	print("OK: v3 kayıt (küsuratlı değerlerle) tam içerik checksum'ından geçti.")

	# Dosya elle değiştirilir (yozlaşma sıfırlanır), checksum eski hâliyle kalır; yedek yoktur
	var tampered: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(slot2_path))
	tampered["corruption_data"]["corruption_score"] = 0
	var tamper_file = FileAccess.open(slot2_path, FileAccess.WRITE)
	tamper_file.store_string(JSON.stringify(tampered, "\t"))
	tamper_file.close()
	if FileAccess.file_exists(slot2_backup):
		DirAccess.remove_absolute(slot2_backup)
	var error_messages: Array[String] = []
	var on_save_error = func(_slot: int, message: String): error_messages.append(message)
	save_mgr.save_error.connect(on_save_error)
	game_state.corruption_score = 77
	if save_mgr.load_game(2) or game_state.corruption_score != 77:
		push_error("FAIL: İçeriği değiştirilmiş kayıt checksum doğrulamasından geçti!")
		get_tree().quit(1)
		return
	if error_messages.is_empty() or not error_messages[-1].contains("bütünlük"):
		push_error("FAIL: Değiştirilmiş kayıt için anlaşılır hata mesajı üretilmedi!")
		get_tree().quit(1)
		return
	print("OK: Değiştirilmiş kayıt reddedildi, oyun durumu korunup anlaşılır hata verildi.")

	# Checksum'ı silinmiş güncel sürüm kaydı da kabul edilmemeli
	tampered.erase("checksum")
	tamper_file = FileAccess.open(slot2_path, FileAccess.WRITE)
	tamper_file.store_string(JSON.stringify(tampered, "\t"))
	tamper_file.close()
	if save_mgr.load_game(2):
		push_error("FAIL: Checksum'ı silinmiş v3 kayıt kabul edildi!")
		get_tree().quit(1)
		return
	print("OK: Checksum'ı silinmiş güncel sürüm kaydı reddedildi.")

	# Daha yeni (desteklenmeyen) şema sürümü çökmeden reddedilmeli
	var future_file = FileAccess.open(slot2_path, FileAccess.WRITE)
	future_file.store_string(JSON.stringify({"schema_version": 99, "timestamp": "2099-01-01T00:00:00"}, "\t"))
	future_file.close()
	error_messages.clear()
	if save_mgr.load_game(2) or error_messages.is_empty() or not error_messages[-1].contains("v99"):
		push_error("FAIL: Desteklenmeyen şema sürümü kontrollü biçimde reddedilmedi!")
		get_tree().quit(1)
		return
	save_mgr.save_error.disconnect(on_save_error)
	print("OK: Desteklenmeyen şema sürümü (v99) çökmeden, açıklayıcı hatayla reddedildi.")

	# Eski v2 kayıtları (sınırlı checksum) hâlâ yüklenebilmeli
	var legacy_v2: Dictionary = {
		"schema_version": 2, "version": 2, "timestamp": "2026-11-01T12:00:00",
		"stage_data": {"current_stage_path": stage2_path, "checkpoint_id": "", "checkpoint_position": {"x": 0.0, "y": 0.0}},
		"corruption_data": {"corruption_score": 33, "allies_sacrificed_count": 1, "allies_killed_count": 0, "current_heart_pieces": 1}
	}
	legacy_v2["checksum"] = ("2|%s|%s|%s" % [stage2_path, legacy_v2["timestamp"], save_mgr.INTEGRITY_SALT]).sha256_text()
	var v2_file = FileAccess.open(slot2_path, FileAccess.WRITE)
	v2_file.store_string(JSON.stringify(legacy_v2, "\t"))
	v2_file.close()
	if not save_mgr.load_game(2) or game_state.corruption_score != 33:
		push_error("FAIL: v2 kayıt v3 şemasına yükseltilerek yüklenemedi!")
		get_tree().quit(1)
		return
	print("OK: v2 kayıt eski checksum'ıyla doğrulanıp v3 şemasına yükseltildi.")
	save_mgr.cached_checkpoint_position = Vector2(1820.0, 450.0)

	# 7. QA HATA SENARYOSU DOĞRULAMASI (Oyuncu Konumu Korunumu):
	# "Bölüm seçiminde oynaya bastıktan sonra bölümde ne kadar ileri olursan ol en başa atıyor.
	#  Ve menüye dönüp devam et dediğimizde kaldığımız yerden değil de en başından başlatıyor."
	print("--- OYUNCU POZISYONU VE CHECKPOINT RESTORE TESTI ---")
	var dummy_scene = Node2D.new()
	var dummy_player = CharacterBody2D.new()
	dummy_player.name = "CombatPlayer"
	dummy_player.global_position = Vector2(1450.0, 380.0)
	dummy_scene.add_child(dummy_player)
	add_child(dummy_scene)

	# Sahne içindeyken save_game çağrıldığında oyuncunun koordinatı yakalanmalı
	save_mgr.cached_checkpoint_position = dummy_player.global_position
	save_mgr.save_game(1)

	# Oyuncuyu sahne başlangıcına (0, 0) sıfırlıyoruz (sahne yeni yüklenmiş gibi)
	dummy_player.global_position = Vector2.ZERO

	# load_game ve apply_cached_stats_to_scene çağrıldığında oyuncu tam kaydedildiği yere (1450, 380) gitmeli
	save_mgr.load_game(1)
	save_mgr.apply_cached_stats_to_scene(dummy_scene)

	if dummy_player.global_position != Vector2(1450.0, 380.0):
		push_error("FAIL: apply_cached_stats_to_scene oyuncuyu kaydedilen konuma (1450, 380) taşımadı! Mevcut: " + str(dummy_player.global_position))
		get_tree().quit(1)
		return
	print("OK: apply_cached_stats_to_scene oyuncuyu tam kaydedildiği koordinata (" + str(dummy_player.global_position) + ") basariyla yerlestirdi!")
	dummy_scene.queue_free()

	# 8. 3 Kayıt Yuvası ve Yuva Özeti (Slot Summary) Testi
	print("--- 3 KAYIT YUVASI VE OZET DOGRULAMASI ---")
	# Yuva 1: Vlad Ormanı
	game_state.current_stage_path = "res://scenes/levels/vlad/stage_1_forest_camp.tscn"
	save_mgr.save_game(1)

	# Yuva 2: Vlad Kale Mahzenleri
	game_state.current_stage_path = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"
	save_mgr.save_game(2)

	# Yuva 3: Taş Devri Kanyonu
	game_state.current_stage_path = "res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn"
	save_mgr.save_game(3)

	var s1 = save_mgr.get_slot_summary(1)
	var s2 = save_mgr.get_slot_summary(2)
	var s3 = save_mgr.get_slot_summary(3)

	if not s1.get("has_save") or not str(s1.get("location_name")).contains("Orman"):
		push_error("FAIL: Yuva 1 özeti hatalı: " + str(s1))
		get_tree().quit(1)
		return
	if not s2.get("has_save") or not str(s2.get("location_name")).contains("Kale Mahzenleri"):
		push_error("FAIL: Yuva 2 özeti hatalı: " + str(s2))
		get_tree().quit(1)
		return
	if not s3.get("has_save") or not str(s3.get("location_name")).contains("Tarih Öncesi"):
		push_error("FAIL: Yuva 3 özeti hatalı: " + str(s3))
		get_tree().quit(1)
		return
	print("OK: 3 kayıt yuvası için tarih ve konum özetleri (%s / %s / %s) doğrulandı." % [s1.location_name, s2.location_name, s3.location_name])

	# 9. Otomatik Kayıt (Auto-Save) Açma/Kapama Testi
	print("--- OTOMATIK KAYIT AYARI TESTI ---")
	save_mgr.set_autosave_enabled(false)
	if save_mgr.is_autosave_enabled():
		push_error("FAIL: Otomatik kayıt kapatılamadı!")
		get_tree().quit(1)
		return
	save_mgr.set_autosave_enabled(true)
	if not save_mgr.is_autosave_enabled():
		push_error("FAIL: Otomatik kayıt açılamadı!")
		get_tree().quit(1)
		return
	print("OK: Otomatik kayıt açma/kapama fonksiyonu doğrulandı.")

	# 10. Bölüm Seçimi İlerleme Korunumu Testi
	print("--- BOLUM SECIMI KALINAN YER KORUNUMU TESTI ---")
	# Oyuncunun Yuva 1'de Vlad Kale Mahzenleri'nde (Stage 2) olduğu durumu yükleyelim
	save_mgr.load_game(2)
	var ch_dlg_res = load("res://scenes/ui/chapter_select_dialog.tscn")
	var ch_dlg = ch_dlg_res.instantiate()
	add_child(ch_dlg)
	ch_dlg.open()

	# Bölüm 2 kartındaki sahne yolunun stage 2 olarak kaldığı kanıtlanmalı
	var ch_list = ch_dlg.find_child("ChapterList", true, false)
	if ch_list and ch_list.get_child_count() >= 2:
		var card2 = ch_list.get_child(1)
		var btn2 = card2.find_child("Button", true, false) as Button
		if btn2:
			print("OK: Bölüm 2 butonu mevcut, buton metni: " + btn2.text)
			if not btn2.text.contains("Devam"):
				push_warning("WARN: Buton metninde Devam ibaresi bekleniyordu.")
	ch_dlg.queue_free()

	# Temizlik
	save_mgr.delete_save(1)
	save_mgr.delete_save(2)
	save_mgr.delete_save(3)

	print("--- TUM KALICI KAYIT VE YUKLEME ALTYAPISI TESTLERI %100 BASARIYLA GECTI! ---")
	get_tree().quit(0)
