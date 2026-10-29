extends Node

## res://tests/verify_traps_runner.gd
## Story 2D-132: Çevre Tuzakları ve Dinamik Platformlar Doğrulama Paketi

const SpikeTrapScript = preload("res://scripts/objects/spike_trap.gd")
const CollapsingPlatformScript = preload("res://scripts/objects/collapsing_platform.gd")
const GuillotineTrapScript = preload("res://scripts/objects/guillotine_trap.gd")

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
	print("  TEST: Story 2D-132 Çevre Tuzakları & Dinamik Platform ")
	print("========================================================")

	_run_all_tests()

	print("\n========================================================")
	if tests_failed == 0:
		print("  SONUÇ: %d/%d TUZAK VE PLATFORM TESTİ TAMAMEN BAŞARILI! " % [tests_passed, tests_passed + tests_failed])
		print("========================================================\n")
		get_tree().quit(0)
	else:
		printerr("  SONUÇ: %d BAŞARISIZ TUZAK/PLATFORM TESTİ BULUNDU! " % tests_failed)
		print("========================================================\n")
		get_tree().quit(1)


func _run_all_tests() -> void:
	_test_spike_trap_instantiation_and_modes()
	_test_spike_trap_timing_cycles()
	_test_spike_trap_damage_and_anti_spam()
	_test_spike_trap_layer_filtering()
	_test_collapsing_platform_setup_and_trigger()
	_test_collapsing_platform_collapse_and_restore()
	_test_collapsing_platform_one_shot_and_filters()
	_test_guillotine_trap_swing_and_cooldown()
	_test_guillotine_trap_pause_and_layers()
	_test_trap_audio_integration()


# ---------------------------------------------------------------------------
# Test 1: Kazıklı Zemin (SpikeTrap) Kurulumu ve Modlar
# ---------------------------------------------------------------------------
func _test_spike_trap_instantiation_and_modes() -> void:
	print("\n--- Test 1: SpikeTrap Kurulumu ve Modlar ---")
	var scene = load("res://scenes/objects/spike_trap.tscn")
	_assert_true(scene != null, "spike_trap.tscn sahnesi başarıyla yüklendi.")

	var spike = scene.instantiate()
	add_child(spike)

	_assert_true(spike.is_in_group("traps"), "SpikeTrap 'traps' grubunda.")
	_assert_true(spike.is_in_group("hazards"), "SpikeTrap 'hazards' grubunda.")
	_assert_true(spike.hit_area != null, "HitArea düğümü mevcut.")
	_assert_true(spike.col_shape != null, "CollisionShape2D düğümü mevcut.")

	# STATIC mod testi
	var static_spike = SpikeTrapScript.new()
	static_spike.mode = SpikeTrapScript.TrapMode.STATIC
	add_child(static_spike)
	_assert_true(static_spike.is_active, "STATIC modunda kazıklar başlangıçta aktiftir.")

	# TRIGGERED mod testi
	var trig_spike = SpikeTrapScript.new()
	trig_spike.mode = SpikeTrapScript.TrapMode.TRIGGERED
	add_child(trig_spike)
	_assert_true(not trig_spike.is_active, "TRIGGERED modunda kazıklar başlangıçta pasiftir.")

	spike.queue_free()
	static_spike.queue_free()
	trig_spike.queue_free()


# ---------------------------------------------------------------------------
# Test 2: Kazıklı Zemin Zamanlama Döngüsü (TIMED Modu)
# ---------------------------------------------------------------------------
func _test_spike_trap_timing_cycles() -> void:
	print("\n--- Test 2: SpikeTrap Zamanlama Döngüsü (TIMED Modu) ---")
	var spike = SpikeTrapScript.new()
	spike.mode = SpikeTrapScript.TrapMode.TIMED
	spike.active_duration = 1.0
	spike.inactive_duration = 1.5
	spike.initial_delay = 0.0
	add_child(spike)

	var extended_events: Array = []
	var retracted_events: Array = []
	spike.spikes_extended.connect(func(): extended_events.append(true))
	spike.spikes_retracted.connect(func(): retracted_events.append(true))

	_assert_true(not spike.is_active, "TIMED başlangıçta pasif durumda.")

	# Pasif süre dolunca aktifleşmeli
	spike._physics_process(1.6)
	_assert_true(spike.is_active, "inactive_duration sonrasında kazıklar açıldı.")
	_assert_true(extended_events.size() == 1, "spikes_extended sinyali yayıldı.")

	# Aktif süre dolunca kapanmalı
	spike._physics_process(1.1)
	_assert_true(not spike.is_active, "active_duration sonrasında kazıklar geri çekildi.")
	_assert_true(retracted_events.size() == 1, "spikes_retracted sinyali yayıldı.")

	spike.queue_free()


# ---------------------------------------------------------------------------
# Test 3: Kazıklı Zemin Hasarı, Knockback ve Spam Koruması
# ---------------------------------------------------------------------------
func _test_spike_trap_damage_and_anti_spam() -> void:
	print("\n--- Test 3: SpikeTrap Hasarı, Knockback ve Spam Koruması ---")
	var spike = SpikeTrapScript.new()
	spike.mode = SpikeTrapScript.TrapMode.STATIC
	spike.damage = 25
	spike.damage_interval = 0.8
	spike.knockback_force = 300.0
	add_child(spike)

	# Mock Target (CharacterBody2D)
	var target = CharacterBody2D.new()
	target.name = "Player"
	target.add_to_group("player")
	target.set("max_health", 100)
	target.set("current_health", 100)
	target.set("is_dead", false)

	var hit_record: Array = []
	var script_target = GDScript.new()
	script_target.source_code = """
extends CharacterBody2D
var max_health: int = 100
var current_health: int = 100
var is_dead: bool = false
signal damaged(amount)
func take_damage(amount: int, _attacker = null) -> void:
	current_health -= amount
	damaged.emit(amount)
"""
	script_target.reload()
	target.set_script(script_target)
	add_child(target)

	# 1. İlk temas: Hasar almalı ve yukarı itilmeli
	var hit1 = spike._try_damage_target(target)
	_assert_true(hit1, "Hedefe ilk temas başarıyla hasar verdi.")
	_assert_true(target.current_health == 75, "Hedefin canı 100 -> 75'e düştü (-25 hasar).")
	_assert_true(target.velocity.y == -300.0, "Yukarı doğru geri tepme (-300 px/s) uygulandı.")

	# 2. Aynı aralıkta hemen tekrar temas (Spam denemesi)
	var hit2 = spike._try_damage_target(target)
	_assert_true(not hit2, "Bekleme süresi dolmadan spam hasar verilmedi.")
	_assert_true(target.current_health == 75, "Can değeri aynı kaldı (tek temasta kontrolsüz hasar yok).")

	# 3. 0.4s sonra (hala bekleme süresinde)
	spike._physics_process(0.4)
	var hit3 = spike._try_damage_target(target)
	_assert_true(not hit3, "0.4s sonra (0.8s dolmadan) hasar yine engellendi.")

	# 4. Bekleme süresi tamamlanınca (0.45s daha geçince -> toplam 0.85s)
	spike._physics_process(0.45)
	var hit4 = spike._try_damage_target(target)
	_assert_true(hit4, "damage_interval dolduktan sonra güvenli biçimde 2. darbe uygulandı.")
	_assert_true(target.current_health == 50, "Hedefin canı 75 -> 50'ye düştü.")

	target.queue_free()
	spike.queue_free()


# ---------------------------------------------------------------------------
# Test 4: Kazıklı Zemin Katman ve Durum Filtreleme
# ---------------------------------------------------------------------------
func _test_spike_trap_layer_filtering() -> void:
	print("\n--- Test 4: SpikeTrap Katman ve Durum Filtreleme ---")
	var spike = SpikeTrapScript.new()
	spike.mode = SpikeTrapScript.TrapMode.STATIC
	spike.affects_player = true
	spike.affects_enemies = false # Düşmanlara hasar vermesin
	spike.affects_allies = false
	add_child(spike)

	var enemy = CharacterBody2D.new()
	enemy.name = "Goblin"
	enemy.add_to_group("enemies")
	enemy.set("is_dead", false)
	var enemy_damaged: Array = []
	var scr = GDScript.new()
	scr.source_code = """
extends CharacterBody2D
var is_dead: bool = false
func take_damage(_amount): pass
"""
	scr.reload()
	enemy.set_script(scr)
	add_child(enemy)

	_assert_true(not spike._is_valid_target(enemy), "affects_enemies=false iken düşman hedeflenmedi.")

	# Ölü oyuncu kontrolü
	var dead_player = CharacterBody2D.new()
	dead_player.name = "DeadPlayer"
	dead_player.add_to_group("player")
	dead_player.set_script(scr)
	dead_player.is_dead = true
	add_child(dead_player)

	_assert_true(not spike._is_valid_target(dead_player), "Ölü oyuncu gövdesi hasar almaz.")

	enemy.queue_free()
	dead_player.queue_free()
	spike.queue_free()


# ---------------------------------------------------------------------------
# Test 5: Çöken Platform (CollapsingPlatform) Kurulumu ve Tetiklenme
# ---------------------------------------------------------------------------
func _test_collapsing_platform_setup_and_trigger() -> void:
	print("\n--- Test 5: CollapsingPlatform Kurulumu ve Tetiklenme ---")
	var plat_scene = load("res://scenes/objects/collapsing_platform.tscn")
	_assert_true(plat_scene != null, "collapsing_platform.tscn sahnesi başarıyla yüklendi.")

	var plat = plat_scene.instantiate() as CollapsingPlatform
	add_child(plat)

	_assert_true(plat.is_in_group("platforms"), "Platform 'platforms' grubunda.")
	_assert_true(plat.is_in_group("collapsing_platforms"), "Platform 'collapsing_platforms' grubunda.")
	_assert_true(plat.state == CollapsingPlatform.PlatformState.IDLE, "Başlangıç durumu IDLE.")
	_assert_true(not plat.collision_shape.disabled, "Katı çarpışma kutusu başlangıçta aktif.")
	_assert_true(plat.collision_shape.one_way_collision, "Tek yönlü platform (one_way_collision) desteği aktif.")

	var dummy_player = CharacterBody2D.new()
	dummy_player.name = "Player"
	dummy_player.add_to_group("player")
	add_child(dummy_player)

	var shake_fired: Array = []
	plat.shake_started.connect(func(): shake_fired.append(true))

	# Oyuncu platformun trigger alanına bastı
	plat._on_trigger_body_entered(dummy_player)
	_assert_true(plat.state == CollapsingPlatform.PlatformState.SHAKING, "Oyuncu basınca platform SHAKING durumuna geçti.")
	_assert_true(shake_fired.size() == 1, "shake_started sinyali yayıldı.")

	dummy_player.queue_free()
	plat.queue_free()


# ---------------------------------------------------------------------------
# Test 6: Çöken Platform Çöküş ve Yeniden Kurulum (Restore)
# ---------------------------------------------------------------------------
func _test_collapsing_platform_collapse_and_restore() -> void:
	print("\n--- Test 6: CollapsingPlatform Çöküş ve Yeniden Kurulum ---")
	var plat = CollapsingPlatformScript.new()
	plat.collapse_delay = 0.2
	plat.restore_delay = 0.3
	plat.shake_intensity = 2.0
	add_child(plat)

	var collapsed_events: Array = []
	var restored_events: Array = []
	plat.collapsed.connect(func(): collapsed_events.append(true))
	plat.restored.connect(func(): restored_events.append(true))

	plat.trigger_collapse()
	_assert_true(plat.state == CollapsingPlatform.PlatformState.SHAKING, "Platform sallanmaya başladı.")

	# Çöküşü doğrudan çağırarak test et
	plat._collapse(false)
	_assert_true(plat.state == CollapsingPlatform.PlatformState.COLLAPSED, "Platform COLLAPSED durumuna geçti.")
	_assert_true(plat.collision_shape.disabled, "Çöküş anında katı çarpışma devre dışı bırakıldı.")
	_assert_true(collapsed_events.size() == 1, "collapsed sinyali tetiklendi.")

	# Yeniden kurulum (Restore)
	plat._restore(false)
	_assert_true(plat.state == CollapsingPlatform.PlatformState.IDLE, "Platform RESTORE sonrası tekrar IDLE durumuna döndü.")
	_assert_true(not plat.collision_shape.disabled, "Katı çarpışma tekrar devreye alındı.")
	_assert_true(restored_events.size() == 1, "restored sinyali tetiklendi.")
	_assert_true(plat.visual.visible, "Görsel görünür kılındı.")

	# Tekrar tetiklenebilirlik testi
	plat.trigger_collapse()
	_assert_true(plat.state == CollapsingPlatform.PlatformState.SHAKING, "Yenilenen platform güvenle 2. kez tetiklenebiliyor.")

	plat.queue_free()


# ---------------------------------------------------------------------------
# Test 7: Çöken Platform One-Shot ve Düşman Filtresi
# ---------------------------------------------------------------------------
func _test_collapsing_platform_one_shot_and_filters() -> void:
	print("\n--- Test 7: CollapsingPlatform One-Shot ve Düşman Filtresi ---")
	var plat = CollapsingPlatformScript.new()
	plat.trigger_on_enemies = false
	plat.affects_player = true
	add_child(plat)

	var enemy = CharacterBody2D.new()
	enemy.name = "EnemySkeleton"
	enemy.add_to_group("enemies")
	add_child(enemy)

	_assert_true(not plat._can_trigger(enemy), "trigger_on_enemies=false iken düşman platformu tetikleyemez.")

	plat.trigger_on_enemies = true
	_assert_true(plat._can_trigger(enemy), "trigger_on_enemies=true iken düşman platformu tetikleyebilir.")

	# force_restore() fonksiyonu
	plat._collapse()
	_assert_true(plat.state == CollapsingPlatform.PlatformState.COLLAPSED, "Platform çöktü.")
	plat.force_restore()
	_assert_true(plat.state == CollapsingPlatform.PlatformState.IDLE, "force_restore() anında platformu sağlam hale getirdi.")

	enemy.queue_free()
	plat.queue_free()


# ---------------------------------------------------------------------------
# Test 8: Sarkaç Giyotin Bıçağı (GuillotineTrap) Hareketi ve Hasarı
# ---------------------------------------------------------------------------
func _test_guillotine_trap_swing_and_cooldown() -> void:
	print("\n--- Test 8: GuillotineTrap Hareketi ve Hasar Aralığı ---")
	var scene = load("res://scenes/objects/guillotine_trap.tscn")
	_assert_true(scene != null, "guillotine_trap.tscn sahnesi başarıyla yüklendi.")

	var guillotine = scene.instantiate() as GuillotineTrap
	guillotine.swing_speed = 3.0
	guillotine.damage = 30
	guillotine.damage_interval = 0.75
	guillotine.knockback_force = 250.0
	add_child(guillotine)

	_assert_true(guillotine.is_in_group("traps"), "GuillotineTrap 'traps' grubunda.")
	_assert_true(guillotine.arm != null, "Sarkaç kolu (Arm) mevcut.")
	_assert_true(guillotine.blade_area != null, "Bıçak hasar alanı (HitArea) mevcut.")

	# Fizik adımı ile salınım açısının değişimi
	var initial_rot = guillotine.arm.rotation
	guillotine._physics_process(0.2)
	_assert_true(guillotine.arm.rotation != initial_rot, "Bıçak salınarak açısı değişti.")

	# Hedef hasar testi
	var target = CharacterBody2D.new()
	target.name = "Player"
	target.add_to_group("player")
	var scr = GDScript.new()
	scr.source_code = """
extends CharacterBody2D
var current_health: int = 100
var is_dead: bool = false
func take_damage(amount, _attacker = null): current_health -= amount
"""
	scr.reload()
	target.set_script(scr)
	add_child(target)

	var hit1 = guillotine._try_damage_target(target)
	_assert_true(hit1, "Giyotin bıçağı hedefe başarıyla hasar verdi.")
	_assert_true(target.current_health == 70, "Hedefin canı 100 -> 70'e düştü (-30 hasar).")

	# Spam darbe kontrolü
	var hit2 = guillotine._try_damage_target(target)
	_assert_true(not hit2, "damage_interval dolmadan giyotin mükerrer hasar vermedi.")
	_assert_true(target.current_health == 70, "Can 70'te korundu.")

	target.queue_free()
	guillotine.queue_free()


# ---------------------------------------------------------------------------
# Test 9: Sarkaç Giyotin Bıçağı Duraklatma ve Katmanlar
# ---------------------------------------------------------------------------
func _test_guillotine_trap_pause_and_layers() -> void:
	print("\n--- Test 9: GuillotineTrap Duraklatma ve Katmanlar ---")
	var guillotine = GuillotineTrapScript.new()
	guillotine.affects_player = false
	guillotine.affects_enemies = true
	add_child(guillotine)

	# Duraklatma kontrolü
	guillotine.set_paused(true)
	var rot_before = guillotine.arm.rotation
	guillotine._physics_process(0.5)
	_assert_true(guillotine.arm.rotation == rot_before, "Duraklatıldığında (is_paused=true) sarkaç hareketsiz kaldı.")

	guillotine.set_paused(false)
	guillotine._physics_process(0.1)
	_assert_true(guillotine.arm.rotation != rot_before, "Devam ettirildiğinde sarkaç salınımına devam etti.")

	# affects_player=false iken oyuncu hasar almaz
	var dummy_p = CharacterBody2D.new()
	dummy_p.name = "Player"
	dummy_p.add_to_group("player")
	var scr = GDScript.new()
	scr.source_code = "extends CharacterBody2D\nvar is_dead = false\nfunc take_damage(_a): pass"
	scr.reload()
	dummy_p.set_script(scr)
	add_child(dummy_p)

	_assert_true(not guillotine._is_valid_target(dummy_p), "affects_player=false iken oyuncu geçerli hedef sayılmaz.")

	dummy_p.queue_free()
	guillotine.queue_free()


# ---------------------------------------------------------------------------
# Test 10: Tuzak ve Platform Ses Entegrasyonu
# ---------------------------------------------------------------------------
func _test_trap_audio_integration() -> void:
	print("\n--- Test 10: Tuzak ve Platform Ses Entegrasyonu ---")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	_assert_true(audio_mgr != null, "AudioManager Autoload singleton mevcut.")
	if not audio_mgr:
		return

	# Prosedürel ses kayıtlarının varlığı
	_assert_true(audio_mgr.has_method("play_sfx"), "AudioManager.play_sfx metodu mevcut.")

	var s1 = audio_mgr.play_sfx("spike_trap")
	_assert_true(s1 != null, "spike_trap sesi başarıyla SFX havuzundan çaldı.")

	var s2 = audio_mgr.play_sfx("guillotine_swing")
	_assert_true(s2 != null, "guillotine_swing sesi başarıyla SFX havuzundan çaldı.")

	var s3 = audio_mgr.play_sfx("platform_crumble")
	_assert_true(s3 != null, "platform_crumble sesi başarıyla SFX havuzundan çaldı.")

	var s4 = audio_mgr.play_sfx("platform_restore")
	_assert_true(s4 != null, "platform_restore sesi başarıyla SFX havuzundan çaldı.")
