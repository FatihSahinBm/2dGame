extends Node

## res://tests/verify_camera_runner.gd
## Story 2D-147: Gelişmiş Kamera Takibi, Sarsıntı ve Boss Arenası Yönetimi Doğrulama Paketi

const AdvancedCamera2D = preload("res://scripts/camera/advanced_camera_2d.gd")

var tests_passed: int = 0
var tests_failed: int = 0


func _assert_true(cond: bool, msg: String) -> void:
	if cond:
		tests_passed += 1
		print("PASS: %s" % msg)
	else:
		tests_failed += 1
		printerr("FAIL: %s" % msg)


func _ready() -> void:
	print("\n========================================================")
	print("  TEST: Story 2D-147 Gelişmiş Kamera ve Sarsıntı Doğrulama ")
	print("========================================================")

	_run_all_tests()

	print("\n========================================================")
	if tests_failed == 0:
		print("  SONUÇ: %d/%d KAMERA TESTLERİ TAMAMEN BAŞARILI! " % [tests_passed, tests_passed + tests_failed])
		print("========================================================\n")
		get_tree().quit(0)
	else:
		printerr("  SONUÇ: %d BAŞARISIZ KAMERA TESTİ BULUNDU! " % tests_failed)
		print("========================================================\n")
		get_tree().quit(1)


func _run_all_tests() -> void:
	_test_initialization()
	_test_look_ahead_and_deadzone()
	_test_fall_look_down()
	_test_anti_jitter_direction_switch()
	_test_boss_arena_scaling()
	_test_multi_shake_priority_and_upper_limit()
	_test_shake_decay_and_zero_drift()
	_test_screen_shake_zero_disabled()
	_test_reduce_motion_disables_shake()
	_test_settings_dialog_sync()


# ---------------------------------------------------------------------------
# Test 1: Başlatma ve Singleton Kaydı
# ---------------------------------------------------------------------------
func _test_initialization() -> void:
	print("\n--- Test 1: Başlatma ve Singleton Kaydı ---")
	var cm = get_node_or_null("/root/CameraManager")
	_assert_true(cm != null, "CameraManager Autoload singleton olarak yüklendi.")

	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player = player_scene.instantiate() as CharacterBody2D
	add_child(player)

	var cam = player.get_node_or_null("Camera2D") as Camera2D
	_assert_true(cam != null, "Oyuncu sahnesi üzerinde Camera2D mevcut.")
	_assert_true(cam is AdvancedCamera2D, "Camera2D düğümü AdvancedCamera2D script'ine sahip.")

	# CameraManager kaydını doğrula
	_assert_true(cm.get_active_camera() == cam, "AdvancedCamera2D otomatik olarak CameraManager'a kaydedildi.")

	player.queue_free()


# ---------------------------------------------------------------------------
# Test 2: Yönsel Look-Ahead ve Deadzone
# ---------------------------------------------------------------------------
func _test_look_ahead_and_deadzone() -> void:
	print("\n--- Test 2: Yönsel Look-Ahead ve Deadzone ---")
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player = player_scene.instantiate() as CharacterBody2D
	add_child(player)

	var cam = player.get_node_or_null("Camera2D") as AdvancedCamera2D
	cam.reset_look_ahead()

	# Sağa hareket (Deadzone üzerinde, örneğin 240 px/s)
	player.velocity = Vector2(240.0, 0.0)
	# 0.25s simüle et (direction_switch_delay 0.12s'yi aşsın)
	for i in range(15):
		cam._process(0.02)

	_assert_true(cam.get_current_look_ahead().x > 15.0, "Sağa harekette kamera sağa doğru (look-ahead) açıldı.")

	# Deadzone altındaki mikro-hareket (15 px/s < 28 px/s deadzone)
	cam.reset_look_ahead()
	player.velocity = Vector2(15.0, 0.0)
	for i in range(10):
		cam._process(0.02)

	_assert_true(is_zero_approx(cam.get_current_look_ahead().x), "Deadzone altındaki mikro-harekette kamera look-ahead tetiklenmedi.")

	# Hareketsiz durma (velocity = 0): Look-ahead merkeze döner
	player.velocity = Vector2.ZERO
	for i in range(25):
		cam._process(0.02)

	_assert_true(cam.get_current_look_ahead().x < 1.0, "Oyuncu durduğunda kamera yumuşak biçimde merkeze geri döndü.")

	player.queue_free()


# ---------------------------------------------------------------------------
# Test 3: Düşüşte Görüş Alanı (Aşağı Bakış)
# ---------------------------------------------------------------------------
func _test_fall_look_down() -> void:
	print("\n--- Test 3: Düşüşte Görüş Alanı ---")
	var dummy_body = CharacterBody2D.new()
	add_child(dummy_body)

	var cam = AdvancedCamera2D.new()
	dummy_body.add_child(cam)
	cam._ready()

	# Yüksek düşüş hızı (320 px/s > fall_speed_threshold 160 px/s)
	dummy_body.velocity = Vector2(0.0, 320.0)
	for i in range(20):
		cam._process(0.02)

	_assert_true(cam.get_current_look_ahead().y > 10.0, "Oyuncu düşerken kamera aşağı yönlü görüş alanını (look-down) genişletti.")

	# Zemine basınca düşüş bakışı sıfırlanır
	dummy_body.velocity = Vector2.ZERO
	for i in range(40):
		cam._process(0.02)

	_assert_true(cam.get_current_look_ahead().y < 1.0, "Yere basıldığında düşüş bakışı merkeze geri döndü.")

	dummy_body.queue_free()


# ---------------------------------------------------------------------------
# Test 4: Hızlı Yön Değişimlerinde Titremeyi Önleme (Anti-Jitter)
# ---------------------------------------------------------------------------
func _test_anti_jitter_direction_switch() -> void:
	print("\n--- Test 4: Hızlı Yön Değişimlerinde Titremeyi Önleme (Anti-Jitter) ---")
	var dummy_body = CharacterBody2D.new()
	add_child(dummy_body)

	var cam = AdvancedCamera2D.new()
	dummy_body.add_child(cam)
	cam._ready()

	# Sağa yerleşmiş başlangıç
	dummy_body.velocity = Vector2(250.0, 0.0)
	for i in range(15):
		cam._process(0.02)
	var settled_x = cam.get_current_look_ahead().x
	_assert_true(settled_x > 20.0, "Sağa hareket look-ahead konumu oturdu: %f" % settled_x)

	# 20 kare boyunca her karede yön değiştir (A/D tuşlarını aşırı hızlı spam etme simülasyonu)
	var max_single_frame_delta: float = 0.0
	for i in range(20):
		dummy_body.velocity.x = -250.0 if (i % 2 == 0) else 250.0
		var prev_look = cam.get_current_look_ahead().x
		cam._process(0.016)
		var frame_diff = absf(cam.get_current_look_ahead().x - prev_look)
		max_single_frame_delta = maxf(max_single_frame_delta, frame_diff)

	# Anti-jitter grace period ve smooth damping sayesinde tek karede ani 50px zıplama olmamalı
	_assert_true(max_single_frame_delta < 8.0, "Spam yön değişiminde tek karelik sıçrama engellendi (max tek kare delta: %f px < 8.0 px)." % max_single_frame_delta)

	dummy_body.queue_free()


# ---------------------------------------------------------------------------
# Test 5: Boss Arenası Ölçekleme ve Sınırlar
# ---------------------------------------------------------------------------
func _test_boss_arena_scaling() -> void:
	print("\n--- Test 5: Boss Arenası Ölçekleme ve Sınırlar ---")
	var cm = get_node_or_null("/root/CameraManager")
	var dummy_body = CharacterBody2D.new()
	add_child(dummy_body)

	var cam = AdvancedCamera2D.new()
	dummy_body.add_child(cam)
	cam._ready()

	var arena_rect = Rect2(4300, -220, 1200, 870)
	var target_zoom = Vector2(0.82, 0.82)

	cam.enter_boss_arena(arena_rect, target_zoom)
	_assert_true(cam.is_in_boss_arena(), "Boss arenasına giriş durumu etkinleşti.")
	_assert_true(cam.limit_left == 4300 and cam.limit_right == 5500, "Boss arenası sol/sağ sınırları uygulandı.")
	_assert_true(cam.limit_top == -220 and cam.limit_bottom == 650, "Boss arenası üst/alt sınırları uygulandı.")

	# Zoom yumuşak geçişi
	for i in range(50):
		cam._process(0.02)

	_assert_true(is_equal_approx(cam.zoom.x, 0.82) and is_equal_approx(cam.zoom.y, 0.82), "Kamera boss arenası görünüm ölçeğine (0.82 zoom) yumuşak biçimde geçti.")

	# Çıkış
	cam.exit_boss_arena()
	_assert_true(not cam.is_in_boss_arena(), "Boss arenasından çıkıldı.")
	for i in range(50):
		cam._process(0.02)

	_assert_true(is_equal_approx(cam.zoom.x, 1.0), "Boss arenasından çıkıldığında zoom varsayılana (1.0) geri döndü.")

	dummy_body.queue_free()


# ---------------------------------------------------------------------------
# Test 6: Birden Fazla Sarsıntının Öncelik ve Üst Sınırla Birleştirilmesi
# ---------------------------------------------------------------------------
func _test_multi_shake_priority_and_upper_limit() -> void:
	print("\n--- Test 6: Multi-Shake Öncelik ve Üst Sınır ---")
	var dummy_body = CharacterBody2D.new()
	add_child(dummy_body)

	var cam = AdvancedCamera2D.new()
	dummy_body.add_child(cam)
	cam._ready()

	# 3 farklı kaynaktan aynı anda yüksek sarsıntı uygula (toplamı 20 + 22 + 18 = 60 px)
	cam.apply_shake(20.0, AdvancedCamera2D.ShakePriority.HIGH, 0.35, 25.0, "boss_slam")
	cam.apply_shake(22.0, AdvancedCamera2D.ShakePriority.CRITICAL, 0.35, 25.0, "laser_blast")
	cam.apply_shake(18.0, AdvancedCamera2D.ShakePriority.MEDIUM, 0.35, 25.0, "sword_strike")

	_assert_true(cam.get_active_shake_count() == 3, "3 farklı sarsıntı kaynağı aynı anda listeye alındı.")

	# Birkaç kare ilerlet ve üst sınırın asla aşılmadığını doğrula
	var max_observed_length: float = 0.0
	for i in range(15):
		cam._process(0.016)
		var len = cam.offset.length()
		max_observed_length = maxf(max_observed_length, len)

	_assert_true(max_observed_length > 5.0, "Birleştirilmiş sarsıntı offset üretti: %f px" % max_observed_length)
	_assert_true(max_observed_length <= cam.max_shake_intensity + 0.001, "Sarsıntı üst sınırı (max_shake_intensity = %f) asla aşılmadı (Gözlenen max: %f px)." % [cam.max_shake_intensity, max_observed_length])

	dummy_body.queue_free()


# ---------------------------------------------------------------------------
# Test 7: Sarsıntı Sönümlenmesi ve Sıfır Sapma (Zero Drift)
# ---------------------------------------------------------------------------
func _test_shake_decay_and_zero_drift() -> void:
	print("\n--- Test 7: Sarsıntı Sönümlenmesi ve Sıfır Sapma ---")
	var dummy_body = CharacterBody2D.new()
	add_child(dummy_body)

	var cam = AdvancedCamera2D.new()
	dummy_body.add_child(cam)
	cam._ready()

	cam.apply_shake(15.0, AdvancedCamera2D.ShakePriority.MEDIUM, 0.2, 25.0, "quick_hit")

	# Süreyi aşacak kadar (0.3s) ilerlet
	for i in range(20):
		cam._process(0.016)

	_assert_true(cam.get_active_shake_count() == 0, "Sarsıntı süresi tamamlanınca aktif sarsıntılar temizlendi.")
	_assert_true(cam.offset == Vector2.ZERO, "Sarsıntı bittiğinde offset tamamen Vector2.ZERO oldu (sıfır sapma).")

	dummy_body.queue_free()


# ---------------------------------------------------------------------------
# Test 8: Sarsıntı Yoğunluğu %0 İken Devre Dışı Kalma
# ---------------------------------------------------------------------------
func _test_screen_shake_zero_disabled() -> void:
	print("\n--- Test 8: Sarsıntı Yoğunluğu %0 İken Devre Dışı Kalma ---")
	var cm = get_node_or_null("/root/CameraManager")
	var prev_intensity = cm.get_screen_shake_intensity()

	cm.set_screen_shake_intensity(0.0)
	_assert_true(not cm.is_shake_enabled(), "screen_shake_intensity 0.0 iken is_shake_enabled false döndü.")

	var dummy_body = CharacterBody2D.new()
	add_child(dummy_body)

	var cam = AdvancedCamera2D.new()
	dummy_body.add_child(cam)
	cam._ready()

	cam.apply_shake(20.0, AdvancedCamera2D.ShakePriority.CRITICAL, 0.4, 25.0, "big_explosion")
	cam._process(0.02)

	_assert_true(cam.get_active_shake_count() == 0, "Sarsıntı yoğunluğu %0 iken sarsıntı listeye eklenmedi.")
	_assert_true(cam.offset == Vector2.ZERO, "Sarsıntı yoğunluğu %0 iken kamera offset sıfır kaldı.")

	# Eski değeri geri yükle
	cm.set_screen_shake_intensity(prev_intensity)
	dummy_body.queue_free()


# ---------------------------------------------------------------------------
# Test 9: CinematicManager Reduce Motion ile Sarsıntı Kapatma
# ---------------------------------------------------------------------------
func _test_reduce_motion_disables_shake() -> void:
	print("\n--- Test 9: Reduce Motion ile Sarsıntı Kapatma ---")
	var cin = get_node_or_null("/root/CinematicManager")
	var cm = get_node_or_null("/root/CameraManager")

	var prev_motion = cin.reduce_motion if cin else false
	if cin:
		cin.set_reduce_motion(true)

	_assert_true(cm.get_effective_shake_multiplier() == 0.0, "reduce_motion açıkken etkin sarsıntı çarpanı 0.0.")

	var dummy_body = CharacterBody2D.new()
	add_child(dummy_body)

	var cam = AdvancedCamera2D.new()
	dummy_body.add_child(cam)
	cam._ready()

	cam.apply_shake(25.0, AdvancedCamera2D.ShakePriority.CRITICAL, 0.5, 25.0, "roar")
	cam._process(0.02)

	_assert_true(cam.offset == Vector2.ZERO, "reduce_motion aktifken sarsıntı offset üretmedi.")

	if cin:
		cin.set_reduce_motion(prev_motion)
	dummy_body.queue_free()


# ---------------------------------------------------------------------------
# Test 10: Ayarlar Menüsü (SettingsDialog) Entegrasyonu
# ---------------------------------------------------------------------------
func _test_settings_dialog_sync() -> void:
	print("\n--- Test 10: Ayarlar Menüsü (SettingsDialog) Entegrasyonu ---")
	var cm = get_node_or_null("/root/CameraManager")
	cm.set_screen_shake_intensity(0.75)

	var settings_scene: PackedScene = load("res://scenes/ui/settings_dialog.tscn")
	var dialog = settings_scene.instantiate()
	add_child(dialog)

	dialog.open()

	var shake_slider: HSlider = dialog.find_child("ScreenShakeSlider", true, false) as HSlider
	_assert_true(shake_slider != null, "SettingsDialog içinde ScreenShakeSlider mevcut.")
	_assert_true(is_equal_approx(shake_slider.value, 75.0), "ScreenShakeSlider mevcut CameraManager değerini (75.0) gösteriyor.")

	# Slider değiştirilince CameraManager'a yansıma
	shake_slider.value = 40.0
	_assert_true(is_equal_approx(cm.get_screen_shake_intensity(), 0.40), "Slider değeri değiştirilince CameraManager güncellendi (0.40).")

	# Kalıcılık kontrolü
	cm.save_settings()
	_assert_true(FileAccess.file_exists("user://game_settings.json"), "user://game_settings.json dosyası mevcut.")

	# Varsayılana geri al
	cm.set_screen_shake_intensity(1.0)
	dialog.queue_free()
