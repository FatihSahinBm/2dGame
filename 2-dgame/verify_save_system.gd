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
	if int(info.get("schema_version", 0)) != 2:
		push_error("FAIL: Kayıt dosyasında schema_version = 2 olmalı!")
		get_tree().quit(1)
		return
	print("OK: schema_version = 2 doğrulandı.")

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
	print("OK: v1 eski kayıt biçimi v2 şemasına veri kaybı olmadan otomatik yükseltildi (Migrated).")

	# Temizlik
	save_mgr.delete_save(1)
	save_mgr.delete_save(2)

	print("--- TUM KALICI KAYIT VE YUKLEME ALTYAPISI TESTLERI %100 BASARIYLA GECTI! ---")
	get_tree().quit(0)
