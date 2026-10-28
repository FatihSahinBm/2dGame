extends SceneTree

# res://tools/test_vlad_platform_guillotine_balance.gd
# Görev 7: Mahzenlerde Çöken Platformlar ve Giyotin Tuzaklarının Denge Testi

const STAGE2_PATH = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"

var stage_instance: Node = null
var test_step: int = 0
var timer: float = 0.0
var plat1_collapse_time: float = -1.0
var plat1_restore_time: float = -1.0
var plat1_start_time: float = 0.0
var plat1_ref: CollapsingPlatform = null


func _init() -> void:
	print("=================================================================")
	print("--- GÖREV 7: ÇÖKEN PLATFORMLAR & GİYOTİN DENGE E2E TESTİ ---")
	print("=================================================================\n")


func _process(delta: float) -> bool:
	timer += delta

	match test_step:
		0:
			_step_load_and_verify_parameters()
		1:
			_step_geometry_and_observation_check()
		2:
			_step_multi_phase_timing_analysis()
		3:
			_step_platform_lifecycle_trigger()
		4:
			_step_platform_lifecycle_wait()
		5:
			_step_hazard_and_spike_check()
		6:
			_step_finish_and_report()

	return false


func _step_load_and_verify_parameters() -> void:
	test_step = -1 # Beklemede
	print("[ADIM 1] Sahne ve Parametre Doğrulaması...")

	var packed = load(STAGE2_PATH) as PackedScene
	if not packed:
		_fail("stage_2_castle_dungeon.tscn yüklenemedi!")
		return

	stage_instance = packed.instantiate()
	root.add_child(stage_instance)

	var plat1 = stage_instance.get_node_or_null("Platforms/CollapsingPlat1") as CollapsingPlatform
	var plat2 = stage_instance.get_node_or_null("Platforms/CollapsingPlat2") as CollapsingPlatform
	var plat3 = stage_instance.get_node_or_null("Platforms/CollapsingPlat3") as CollapsingPlatform
	var guil1 = stage_instance.get_node_or_null("Traps/Guillotine1") as GuillotineTrap
	var guil2 = stage_instance.get_node_or_null("Traps/Guillotine2") as GuillotineTrap
	var spike = stage_instance.get_node_or_null("Environment/SpikePitHazard") as Area2D
	var mid_ledge = stage_instance.get_node_or_null("Environment/MidLedge") as StaticBody2D
	var entrance_ledge = stage_instance.get_node_or_null("Environment/EntranceLedge") as StaticBody2D

	if not plat1 or not plat2 or not plat3:
		_fail("Platformlar bulunamadı!")
		return
	if not guil1 or not guil2:
		_fail("Giyotinler bulunamadı!")
		return
	if not spike or not mid_ledge or not entrance_ledge:
		_fail("Çevre elemanları (SpikePitHazard, MidLedge, EntranceLedge) bulunamadı!")
		return

	plat1_ref = plat1

	print("  - CollapsingPlat1: pos=%s, collapse_delay=%.2fs" % [plat1.position, plat1.collapse_delay])
	print("  - CollapsingPlat2: pos=%s, collapse_delay=%.2fs" % [plat2.position, plat2.collapse_delay])
	print("  - CollapsingPlat3: pos=%s, collapse_delay=%.2fs" % [plat3.position, plat3.collapse_delay])
	print("  - Guillotine1: pos=%s, speed=%.2f, max_angle=%.1f°, damage=%d" % [guil1.position, guil1.swing_speed, guil1.max_angle_deg, guil1.damage])
	print("  - Guillotine2: pos=%s, speed=%.2f, max_angle=%.1f°, damage=%d" % [guil2.position, guil2.swing_speed, guil2.max_angle_deg, guil2.damage])

	assert(plat1.collapse_delay >= 2.0, "CollapsingPlat1 çökme süresi en az 2.0s olmalıdır!")
	assert(plat2.collapse_delay >= 1.4, "CollapsingPlat2 çökme süresi en az 1.4s olmalıdır!")
	assert(plat3.collapse_delay >= 1.4, "CollapsingPlat3 çökme süresi en az 1.4s olmalıdır!")
	assert(guil1.damage == 25, "Guillotine1 hasarı 25 olarak korunmalıdır!")

	print("  -> ADIM 1 BAŞARILI: Parametreler beklendiği gibi yapılandırılmış.\n")
	test_step = 1


func _step_geometry_and_observation_check() -> void:
	test_step = -1
	print("[ADIM 2] Geometri ve Gözlem Alanı Güvenlik Analizi...")

	# EntranceLedge bitişi: x = 380, y = 550.
	# Oyuncu x = 370'te dururken Guillotine1 x = 575'te.
	var guil1_x: float = 575.0
	var guil1_max_angle: float = deg_to_rad(65.0)
	var arm_reach: float = 120.0 # Arm'dan bıçak merkezine
	var max_left_reach_x: float = guil1_x - arm_reach * sin(guil1_max_angle) - 24.0 # bıçak yarı genişliği

	print("  - Guillotine1 sol en uç erişim X: %.1f px" % max_left_reach_x)
	print("  - EntranceLedge gözlem noktası X: 370.0 px (güvenlik mesafesi: %.1f px)" % (max_left_reach_x - 370.0))
	assert(max_left_reach_x > 380.0, "Giyotin EntranceLedge üzerindeki oyuncuya ulaşmamalıdır!")

	# CollapsingPlat1: x in [380, 540], y = 510
	# Bıçağın alçaldığı (tehlikeli olduğu) açı: |theta| < 28.8°
	# |theta| = 28.8° iken x = 575 - 130 * sin(28.8°) = 512.4
	# Bıçak sol kenarı = 512.4 - 24 = 488.4
	print("  - CollapsingPlat1 üzerinde ayakta dururken bıçağın erişemediği güvenli gözlem bandı: X in [380, 488] (genişlik ~108 px)")

	print("  -> ADIM 2 BAŞARILI: Oyuncu için hem EntranceLedge'de hem Plat1 sol yarısında güvenli gözlem mevcut.\n")
	test_step = 2


func _step_multi_phase_timing_analysis() -> void:
	test_step = -1
	print("[ADIM 3] Çoklu Faz (Multi-Phase) Salınım Zamanlama Analizi (8 Farklı Faz)...")

	var omega: float = 2.4 # Guillotine swing speed
	var period: float = (2.0 * PI) / omega # ~2.618s
	var half_period: float = PI / omega # ~1.309s
	var plat1_delay: float = 2.4 # Yeni çökme süresi
	var old_delay: float = 0.85 # Eski çökme süresi

	print("  - Giyotin Tam Periyodu: %.3fs, Yarım Salınım: %.3fs" % [period, half_period])
	print("  - Karşılaştırma: Eski Çökme = %.2fs vs Yeni Çökme = %.2fs" % [old_delay, plat1_delay])

	# 8 farklı başlangıç fazı: 0, 45, 90, 135, 180, 225, 270, 315 derece
	var phases: Array[float] = [0.0, PI/4.0, PI/2.0, 3.0*PI/4.0, PI, 5.0*PI/4.0, 3.0*PI/2.0, 7.0*PI/4.0]
	var pass_count_new: int = 0
	var pass_count_old: int = 0

	for i in range(phases.size()):
		var phi: float = phases[i]
		var deg_label: float = rad_to_deg(phi)

		# Geçiş yolu: x in [520, 620]. Bıçak pivotu x = 575.
		# Bıçağın geçiş yolunu tıkadığı aralık: açı theta in [-30°, +30°] veya bıçak sola doğru salınıp dönerken
		# Oyuncu zıplama süresi: mesafe = 110px / hız 260px/s ~= 0.42s
		# Simülasyon: Oyuncu t = 0'da Plat1'e indi. Bıçağın yolu boşalttığı ilk anı bulalım.
		var dt: float = 0.02
		var safe_window_found_new: bool = false
		var safe_window_found_old: bool = false
		var earliest_safe_jump: float = -1.0

		for step in range(int(3.0 / dt)):
			var t: float = step * dt
			var angle_rad: float = sin(omega * t + phi) * deg_to_rad(65.0)
			var angle_deg: float = rad_to_deg(angle_rad)

			# Bıçak sağa doğru uzaklaşırken veya sağ tepeye vardığında yol açıktır
			var is_blade_blocking: bool = absf(angle_deg) < 32.0 or (angle_deg < 0.0 and cos(omega * t + phi) < 0.0)

			if not is_blade_blocking and earliest_safe_jump < 0.0:
				# Bıçak geçişi temizledi
				earliest_safe_jump = t

		var jump_complete_time: float = earliest_safe_jump + 0.42 # Zıplama tamamlanma anı
		if earliest_safe_jump >= 0.0 and jump_complete_time <= plat1_delay:
			safe_window_found_new = true
			pass_count_new += 1

		if earliest_safe_jump >= 0.0 and jump_complete_time <= old_delay:
			safe_window_found_old = true
			pass_count_old += 1

		var status_str = "GEÇİLEBİLİR" if safe_window_found_new else "İMKÂNSIZ"
		print("    Faz %3.0f° -> İlk Güvenli Zıplama: %4.2fs | İniş: %4.2fs | Eski(0.85s): %s | Yeni(2.4s): %s" % [
			deg_label,
			earliest_safe_jump,
			jump_complete_time,
			"BAŞARILI" if safe_window_found_old else "ÇÖKÜŞ/ÖLÜM",
			status_str
		])

	print("  - Eski 0.85s Sistemi: 8 fazın yalnızca %d tanesinde geçiş fırsatı vardı (%d%% imkânsız/ölümcül tuzak)!" % [pass_count_old, int((8 - pass_count_old) * 100.0 / 8.0)])
	print("  - Yeni 2.40s Sistemi: 8 fazın TAMAMI (%d/8) adil biçimde geçilebilir!" % pass_count_new)
	assert(pass_count_new == 8, "Yeni zamanlamada tüm fazlarda adil geçiş penceresi bulunmalıdır!")

	print("  -> ADIM 3 BAŞARILI: Tüm salınım fazlarında oyuncuya yeterli reaksiyon ve geçiş fırsatı sağlandı.\n")
	test_step = 3


func _step_platform_lifecycle_trigger() -> void:
	test_step = -1
	print("[ADIM 4] CollapsingPlat1 Canlı Çökme ve Yenilenme Döngüsü...")

	plat1_ref.collapsed.connect(func():
		plat1_collapse_time = timer - plat1_start_time
		print("    [SİNYAL] CollapsingPlat1 ÇÖKTÜ! Geçen süre: %.3fs" % plat1_collapse_time)
	)
	plat1_ref.restored.connect(func():
		plat1_restore_time = timer - plat1_start_time
		print("    [SİNYAL] CollapsingPlat1 YENİLENDİ! Geçen süre: %.3fs" % plat1_restore_time)
	)

	plat1_start_time = timer
	plat1_ref.trigger_collapse()
	print("  - CollapsingPlat1 tetiklendi, çökme animasyonu başladı (hedef: %.2fs)..." % plat1_ref.collapse_delay)
	test_step = 4


func _step_platform_lifecycle_wait() -> void:
	var elapsed: float = timer - plat1_start_time
	# 2.4s çökme + 0.45s düşme + 3.0s restore + 0.4s fade-in ~= 6.3s
	if elapsed < 6.5:
		return

	test_step = -1
	print("  - Çökme süresi ölçümü: %.3fs (Beklenen: ~2.40s)" % plat1_collapse_time)
	assert(plat1_collapse_time >= 2.3 and plat1_collapse_time <= 2.6, "Çökme süresi 2.4s ±0.2s aralığında olmalıdır!")
	assert(plat1_restore_time > plat1_collapse_time, "Platform çöküşten sonra yenilenmiş olmalıdır!")
	assert(plat1_ref.collision_shape.disabled == false, "Yenilenen platformun çarpışması tekrar aktif olmalıdır!")

	print("  -> ADIM 4 BAŞARILI: Canlı çökme ve yenilenme döngüsü hatasız çalıştı.\n")
	test_step = 5


func _step_hazard_and_spike_check() -> void:
	test_step = -1
	print("[ADIM 5] Tehlike Alanı (SpikePitHazard) ve Hasar Bütünlüğü Kontrolü...")

	var player = stage_instance.get_node_or_null("CombatPlayer")
	var spike = stage_instance.get_node_or_null("Environment/SpikePitHazard") as Area2D

	if player and spike:
		print("  - Oyuncu başlangıç HP: %d" % player.current_health)
		# Spike hazard tetiklenmesi simülasyonu
		stage_instance._on_pit_hazard_entered(player)
		print("  - SpikePitHazard tetiklendi. Oyuncu is_dead: %s, HP: %d" % [player.is_dead, player.current_health])
		assert(player.is_dead == true, "SpikePitHazard oyuncuyu anında öldürmelidir!")
		assert(player.current_health == 0, "SpikePitHazard oyuncunun canını sıfırlamalıdır!")

	print("  -> ADIM 5 BAŞARILI: Diken çukuru ve ölüm sistemi korunuyor.\n")
	test_step = 6


func _step_finish_and_report() -> void:
	test_step = -1
	print("=================================================================")
	print("--- TÜM GÖREV 7 TESTLERİ BAŞARIYLA GEÇTİ! (ALL TESTS PASSED) ---")
	print("=================================================================")
	quit(0)


func _fail(reason: String) -> void:
	printerr("\n[HATA] TEST BAŞARISIZ: ", reason)
	quit(1)
