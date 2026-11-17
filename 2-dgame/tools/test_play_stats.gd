extends SceneTree

## res://tools/test_play_stats.gd
## Story 2D-153: Oyun süresi, sonuç istatistikleri, sonuç ekranı ve jenerik.
## Çalıştırma: godot --headless --path . --script res://tools/test_play_stats.gd

const ResultsScreen = preload("res://scripts/ui/results_screen.gd")

var _failed: bool = false


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Oyun Süresi, İstatistik ve Jenerik (2D-153) ===")
	var gs: Node = _autoload("GameState", "res://scripts/autoloads/game_state.gd")
	var stats: Node = _autoload("PlayStats", "res://scripts/autoloads/play_stats.gd")
	gs.reset_state()
	stats.reset()

	# --- Süre sayacı kuralları ---
	var level: Node2D = Node2D.new()
	level.scene_file_path = "res://scenes/levels/vlad/stage_1_camp.tscn"
	root.add_child(level)
	current_scene = level
	_check(stats.is_time_running(), "Seviyede, duraklatma ve sinematik yokken sayaç çalışıyor.")
	gs.is_in_cinematic = true
	_check(not stats.is_time_running(), "Sinematik/diyalog sırasında sayaç duruyor.")
	gs.is_in_cinematic = false
	paused = true
	_check(not stats.is_time_running(), "Duraklatmada sayaç duruyor.")
	paused = false
	level.scene_file_path = "res://scenes/ui/main_menu.tscn"
	_check(not stats.is_time_running(), "Seviye dışı sahnede (menü) sayaç duruyor.")
	level.scene_file_path = "res://scenes/levels/vlad/stage_1_camp.tscn"

	stats.advance_time(3725.4)
	stats.advance_time(-50.0)
	_check(stats.play_time >= 3725.4 and stats.play_time < 3735.0, "Sayaç ilerliyor ve negatif adımla geriye gitmiyor.")
	_check(stats.format_time(3725.4) == "01:02:05", "Süre SS:DD:SN biçiminde gösteriliyor.")

	# --- İstatistikler ---
	var player: CharacterBody2D = (load("res://scenes/combat/test_player.tscn") as PackedScene).instantiate()
	level.add_child(player)
	await process_frame
	await process_frame
	player.set_physics_process(false)
	var hp: int = player.current_health
	player.player_damaged.emit(hp - 30, player.max_health)
	player.player_damaged.emit(hp - 10, player.max_health) # iyileşme hasar sayılmaz
	player.player_damaged.emit(hp - 25, player.max_health)
	_check(stats.damage_taken == 45, "Alınan hasar can düşüşlerinden toplanıyor; iyileşme sayılmıyor (45).")
	player.player_died.emit()
	_check(stats.deaths == 1, "Ölüm sayılıyor.")
	stats.record_boss_defeated("trex")
	stats.record_boss_defeated("trex")
	stats.record_boss_defeated("vlad")
	stats.record_item_collected("heart_fragment_1")
	stats.record_item_collected("heart_fragment_1")
	_check(stats.bosses_defeated.size() == 2 and stats.items_collected.size() == 1, "Aynı boss ve öğe iki kez sayılmıyor.")

	# --- Kayıt yuvasına bağlanma ---
	gs.corruption_score = 60
	gs.record_ending()
	stats.sync_to_game_state()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.persistent_events))
	_check(saved.has("play_stats") and int(saved["play_stats"]["deaths"]) == 1, "İstatistikler kayıt verisine (persistent_events) yazılıyor.")
	stats.reset()
	gs.persistent_events = saved
	stats.load_from_game_state()
	_check(stats.deaths == 1 and stats.damage_taken == 45 and stats.bosses_defeated.size() == 2 and stats.play_time >= 3725.4 and stats.play_time < 3735.0, "Kayıt yüklenince istatistikler geri geliyor.")
	stats.advance_time(100.0)
	stats.load_from_game_state()
	_check(stats.play_time >= 3825.0, "Daha eski kayıt yüklense de süre aynı oturumda geriye gitmiyor.")

	# --- Sonuç ekranı ---
	var screen: CanvasLayer = ResultsScreen.show_for(level)
	await process_frame
	var summary: Dictionary = stats.get_summary()
	var text: String = (screen.get_node("StatsLabel") if screen.has_node("StatsLabel") else screen.find_child("StatsLabel", true, false)).text
	_check(text.contains(str(summary["time_text"])) and text.contains(" 45") and text.contains(" 60 / 100"), "Sonuç ekranı biriken değerlerle tutarlı (süre, hasar, yozlaşma).")
	_check(summary["ending"] == "god_king" and (text.contains("Tanrı-Kral") or text.contains("God-King")), "Bitiş türü sonuç ekranında gösteriliyor.")
	_check(not text.contains("RESULTS_"), "Sonuç ekranında ham çeviri anahtarı yok.")
	_check(screen.find_child("ReplayButton", true, false) != null and screen.find_child("MenuButton", true, false) != null, "Baştan oyna ve ana menü seçenekleri var.")
	_check(ResultsScreen.show_for(level) == screen, "Sonuç ekranı iki kez açılmıyor.")

	# --- Jenerik: proje kaynaklarıyla doğrulama ---
	var credits: Dictionary = ResultsScreen.load_credits()
	var credits_text: String = ResultsScreen.build_credits_text(credits, false)
	var credits_md: String = FileAccess.get_file_as_string("res://CREDITS.md")
	_check(not credits.is_empty() and credits_text.contains("Godot Engine"), "Jenerik verisi yükleniyor ve motor atfını içeriyor.")
	var asset_ok: bool = credits_md.contains("Fantasy Knight") and credits_md.contains("aamatniekss") and credits_text.contains("Fantasy Knight") and credits_text.contains("aamatniekss")
	_check(asset_ok, "CREDITS.md'deki üçüncü taraf varlık (ad ve yazar) jenerikte birebir yer alıyor.")
	var screen_credits: String = (screen.find_child("CreditsLabel", true, false) as Label).text
	_check(screen_credits.contains("aamatniekss"), "Jenerik sonuç ekranında gösteriliyor.")

	# --- Baştan oyna: durum sıfırlanır ---
	paused = true # Sayaç dursun ki sıfır değeri kare beklemeden etkilenmesin
	stats.reset()
	_check(stats.deaths == 0 and is_equal_approx(stats.play_time, 0.0) and stats.bosses_defeated.is_empty(), "Sıfırlama tüm sayaçları başlangıca döndürüyor.")

	paused = false
	level.queue_free()
	gs.reset_state()
	if _failed:
		printerr("SONUÇ: İSTATİSTİK VE JENERİK TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: İSTATİSTİK VE JENERİK TESTİ BAŞARILI")
		quit(0)


func _autoload(node_name: String, script_path: String) -> Node:
	var node: Node = root.get_node_or_null(node_name)
	if node == null:
		node = (load(script_path) as GDScript).new()
		node.name = node_name
		root.add_child(node)
	return node


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
