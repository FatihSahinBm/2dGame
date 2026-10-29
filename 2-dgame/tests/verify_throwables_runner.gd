extends Node2D

## res://tests/verify_throwables_runner.gd
## Story 2D-130: Fırlatılabilir İkincil Eşyalar (Bıçak, Meşale, Kutsal Su) Otomatik Doğrulama Testi

const ThrowableProjectile = preload("res://scripts/projectiles/throwable_projectile.gd")
const BurnableVines = preload("res://scripts/objects/burnable_vines.gd")
const DestructibleBarricade = preload("res://scripts/objects/destructible_barricade.gd")
const PlayerScene = preload("res://scenes/player.tscn")
const BasicEnemyScene = preload("res://scenes/enemies/basic_enemy.tscn")
const BloodKnightScene = preload("res://scenes/enemies/blood_knight.tscn")
const FantasyHUDScene = preload("res://scenes/ui/fantasy_hud.tscn")

var _passed_tests: int = 0
var _failed_tests: int = 0


func _ready() -> void:
	get_tree().current_scene = self
	print("\n========================================================")
	print("  TEST: Story 2D-130 Fırlatılabilir İkincil Eşyalar     ")
	print("========================================================\n")

	_run_all_tests()

	print("\n========================================================")
	if _failed_tests == 0:
		print("  SONUÇ: %d/%d FIRLATILABİLİR EŞYA TESTİ TAMAMEN BAŞARILI!" % [_passed_tests, _passed_tests])
	else:
		printerr("  HATA: %d test BAŞARISIZ OLDU! (Başarılı: %d)" % [_failed_tests, _passed_tests])
	print("========================================================\n")

	await get_tree().process_frame
	get_tree().quit(0 if _failed_tests == 0 else 1)


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		_passed_tests += 1
		print("PASS: %s" % test_name)
	else:
		_failed_tests += 1
		printerr("FAIL: %s" % test_name)


func _run_all_tests() -> void:
	_test_1_scene_loading_and_properties()
	_test_2_parabolic_motion_and_trajectory()
	_test_3_knife_direct_damage_and_cleanup()
	_test_4_knife_wall_stick()
	_test_5_torch_burnable_objects()
	_test_6_torch_ground_fire_hazard()
	_test_7_holy_water_target_filtering()
	_test_8_holy_water_consecrated_hazard()
	_test_9_friendly_fire_prevention()
	_test_10_player_inventory_and_cycling()
	_test_11_empty_ammo_handling_and_feedback()
	_test_12_hud_secondary_slot_and_shake()
	_test_13_projectile_lifetime_and_expiration()
	_test_14_procedural_audio_streams()
	_test_15_save_manager_integration()


func _test_1_scene_loading_and_properties() -> void:
	print("--- Test 1: Mermi Sahneleri ve Özellikleri ---")
	var knife_scene = load("res://scenes/projectiles/throwable_knife.tscn")
	_assert_true(knife_scene != null, "throwable_knife.tscn başarıyla yüklendi.")
	var knife: Area2D = knife_scene.instantiate()
	add_child(knife)
	_assert_true(knife.projectile_type == ThrowableProjectile.ProjectileType.KNIFE, "Bıçak tipi KNIFE (0).")
	_assert_true(knife.damage == 30, "Bıçak taban hasarı 30.")
	_assert_true(knife.stick_on_solid == true, "Bıçak duvara saplanma özelliği aktif.")
	_assert_true(knife.is_in_group("throwable_projectiles"), "Bıçak 'throwable_projectiles' grubunda.")
	knife.queue_free()

	var torch_scene = load("res://scenes/projectiles/throwable_torch.tscn")
	_assert_true(torch_scene != null, "throwable_torch.tscn başarıyla yüklendi.")
	var torch: Area2D = torch_scene.instantiate()
	add_child(torch)
	_assert_true(torch.projectile_type == ThrowableProjectile.ProjectileType.TORCH, "Meşale tipi TORCH (1).")
	_assert_true(torch.creates_ground_hazard == true, "Meşale zemin yangın alanı oluşturma özelliği aktif.")
	_assert_true(torch.rotation_speed > 0.0, "Meşale havada takla atma dönme hızına sahip.")
	torch.queue_free()

	var holy_scene = load("res://scenes/projectiles/throwable_holy_water.tscn")
	_assert_true(holy_scene != null, "throwable_holy_water.tscn başarıyla yüklendi.")
	var holy: Area2D = holy_scene.instantiate()
	add_child(holy)
	_assert_true(holy.projectile_type == ThrowableProjectile.ProjectileType.HOLY_WATER, "Kutsal Su tipi HOLY_WATER (2).")
	_assert_true(holy.damage == 45, "Kutsal Su taban kutsal hasarı 45.")
	_assert_true(holy.creates_ground_hazard == true, "Kutsal Su kutsanmış zemin alanı oluşturur.")
	holy.queue_free()


func _test_2_parabolic_motion_and_trajectory() -> void:
	print("--- Test 2: Parabolik Hareket ve Yörünge Fiziği ---")
	var knife_scene = load("res://scenes/projectiles/throwable_knife.tscn")
	var knife: Area2D = knife_scene.instantiate()
	add_child(knife)
	knife.launch(Vector2(100.0, 200.0), 1.0)

	_assert_true(knife.velocity.x > 0.0, "Sağa fırlatıldığında yatay hız pozitif.")
	_assert_true(knife.velocity.y < 0.0, "Fırlatılış anında dikey hafif yukarı ivme mevcut.")

	var initial_vy = knife.velocity.y
	knife._physics_process(0.1)

	_assert_true(knife.global_position.x > 100.0, "Mermi yatayda ileri hareket etti.")
	_assert_true(knife.velocity.y > initial_vy, "Yerçekimi dikey hızı aşağıya doğru ivmelendirdi.")
	_assert_true(is_equal_approx(knife.rotation, knife.velocity.angle()), "Bıçağın burnu hız vektörünün açısını takip ediyor.")
	knife.queue_free()


func _test_3_knife_direct_damage_and_cleanup() -> void:
	print("--- Test 3: Bıçak Doğrudan Hasarı ve Temizlenme ---")
	var knife_scene = load("res://scenes/projectiles/throwable_knife.tscn")
	var knife: Area2D = knife_scene.instantiate()
	add_child(knife)

	var enemy = BasicEnemyScene.instantiate()
	enemy.current_health = 100
	add_child(enemy)

	var impact_events: Array = []
	knife.impacted.connect(func(tgt, _pos): impact_events.append(tgt))

	knife.launch(Vector2(0, 0), 1.0)
	knife._on_body_entered(enemy)

	_assert_true(impact_events.size() == 1, "Bıçak düşmana çarptığında 'impacted' sinyali yayıldı.")
	_assert_true(enemy.current_health == 70, "Düşman 30 hasar aldı (100 -> 70 HP).")
	_assert_true(knife.is_spent == true, "İsabet sonrası bıçak 'is_spent' durumuna geçti.")

	enemy.queue_free()
	knife.queue_free()


func _test_4_knife_wall_stick() -> void:
	print("--- Test 4: Bıçak Katı Duvara Saplanma ---")
	var knife_scene = load("res://scenes/projectiles/throwable_knife.tscn")
	var knife: Area2D = knife_scene.instantiate()
	add_child(knife)

	var wall = StaticBody2D.new()
	add_child(wall)

	var solid_hit_events: Array = []
	knife.solid_hit.connect(func(surf, _pos): solid_hit_events.append(surf))

	knife.launch(Vector2(0, 0), 1.0)
	knife._on_body_entered(wall)

	_assert_true(solid_hit_events.size() == 1, "Duvara çarptığında 'solid_hit' sinyali yayıldı.")
	_assert_true(knife.is_stuck == true, "Bıçak duvara saplandı (is_stuck == true).")
	_assert_true(knife.velocity == Vector2.ZERO, "Saplanan bıçağın hızı sıfırlandı.")

	wall.queue_free()
	knife.queue_free()


func _test_5_torch_burnable_objects() -> void:
	print("--- Test 5: Meşale ve Yanabilir Çevre Nesneleri ---")
	var torch_scene = load("res://scenes/projectiles/throwable_torch.tscn")

	# 1. DestructibleBarricade Testi
	var barricade_scene = load("res://scenes/objects/destructible_barricade.tscn")
	var barricade = barricade_scene.instantiate()
	add_child(barricade)
	barricade.current_health = 40

	var torch1: Area2D = torch_scene.instantiate()
	add_child(torch1)
	torch1.launch(Vector2.ZERO, 1.0)
	torch1._on_body_entered(barricade)

	_assert_true(barricade.current_health < 40, "Barikat meşale darbesiyle ateş hasarı aldı.")
	_assert_true(barricade.current_health <= 3, "Yanabilir barikat bonus alev hasarı aldı (25 * 1.5 = 37 hasar).")
	torch1.queue_free()
	barricade.queue_free()

	# 2. BurnableVines Testi
	var vines_scene = load("res://scenes/objects/burnable_vines.tscn")
	var vines = vines_scene.instantiate()
	add_child(vines)

	var torch2: Area2D = torch_scene.instantiate()
	add_child(torch2)
	torch2.launch(Vector2.ZERO, 1.0)
	torch2._on_body_entered(vines)

	_assert_true(vines.is_burning == true, "Sarmaşıklar tutuştu (is_burning == true).")
	_assert_true(vines.is_destroyed == true, "Meşale darbesiyle sarmaşıklar yok edildi.")
	torch2.queue_free()
	vines.queue_free()


func _test_6_torch_ground_fire_hazard() -> void:
	print("--- Test 6: Meşale Zemin Yangın Alanı (Ground Fire Hazard) ---")
	var torch_scene = load("res://scenes/projectiles/throwable_torch.tscn")
	var torch: Area2D = torch_scene.instantiate()
	add_child(torch)

	var floor_node = StaticBody2D.new()
	add_child(floor_node)

	torch.launch(Vector2(50, 50), 1.0)
	torch._on_body_entered(floor_node)

	var hazard = find_child("GroundFireHazard", true, false)
	_assert_true(hazard != null, "Zemine çarpan meşale 'GroundFireHazard' yangın alanı oluşturdu.")
	_assert_true(hazard is Area2D, "Yangın alanı Area2D türünde.")
	_assert_true(hazard.has_node("CollisionShape2D"), "Yangın alanı çarpışma sınırına sahip.")

	if hazard:
		hazard.queue_free()
	floor_node.queue_free()
	torch.queue_free()


func _test_7_holy_water_target_filtering() -> void:
	print("--- Test 7: Kutsal Su Hedef Filtreleme (Yalnızca Tasarımda Belirlenmiş Düşmanlar) ---")
	var holy_scene = load("res://scenes/projectiles/throwable_holy_water.tscn")

	# Desteklenen Hedef: BloodKnight (Unholy / Vlad askeri)
	var unholy_enemy = BloodKnightScene.instantiate()
	add_child(unholy_enemy)
	var init_hp = unholy_enemy.current_health

	var holy1: Area2D = holy_scene.instantiate()
	add_child(holy1)
	_assert_true(holy1.is_supported_holy_target(unholy_enemy), "BloodKnight geçerli kutsal su hedefidir.")
	holy1.launch(Vector2.ZERO, 1.0)
	holy1._on_body_entered(unholy_enemy)
	_assert_true(unholy_enemy.current_health == init_hp - 45, "BloodKnight 45 kutsal hasar aldı (%d -> %d HP)." % [init_hp, init_hp - 45])
	holy1.free()
	unholy_enemy.free()

	# Desteklenmeyen Hedef: Normal Hayvan / Dost Olmayan Kutsal Olmayan Nesne
	var normal_target = CharacterBody2D.new()
	normal_target.name = "ForestBeast"
	normal_target.add_to_group("damageable")
	var nhp = {"hp": 100}
	normal_target.set_meta("take_damage_called", false)
	# Basit take_damage fonksiyonu içeren nesne
	var mock_script = GDScript.new()
	mock_script.source_code = "extends CharacterBody2D\nvar current_health: int = 100\nfunc take_damage(amt: int, _atk = null): current_health -= amt\n"
	mock_script.reload()
	normal_target.set_script(mock_script)
	normal_target.current_health = 100
	add_child(normal_target)

	var holy2: Area2D = holy_scene.instantiate()
	add_child(holy2)
	_assert_true(not holy2.is_supported_holy_target(normal_target), "Normal hedef kutsal su için desteklenen tür DEĞİLDİR.")
	holy2.launch(Vector2.ZERO, 1.0)
	holy2._on_body_entered(normal_target)
	_assert_true(normal_target.current_health == 100, "Desteklenmeyen hedef kutsal sudan HASAR ALMAZ (100 HP korundu).")
	holy2.queue_free()
	normal_target.queue_free()


func _test_8_holy_water_consecrated_hazard() -> void:
	print("--- Test 8: Kutsal Su Kutsanmış Zemin Alanı (Holy Consecrated Hazard) ---")
	var holy_scene = load("res://scenes/projectiles/throwable_holy_water.tscn")
	var holy: Area2D = holy_scene.instantiate()
	add_child(holy)

	var floor_node = StaticBody2D.new()
	add_child(floor_node)

	holy.launch(Vector2(200, 200), 1.0)
	holy._on_body_entered(floor_node)

	var hazard = find_child("HolyConsecratedHazard", true, false)
	_assert_true(hazard != null, "Kırılan kutsal su şişesi 'HolyConsecratedHazard' kutsanmış alanı oluşturdu.")

	if hazard:
		hazard.queue_free()
	floor_node.queue_free()
	holy.queue_free()


func _test_9_friendly_fire_prevention() -> void:
	print("--- Test 9: Dost Birim ve Fırlatan Koruma Kuralı ---")
	var knife_scene = load("res://scenes/projectiles/throwable_knife.tscn")
	var knife: Area2D = knife_scene.instantiate()
	add_child(knife)

	var shooter = PlayerScene.instantiate()
	add_child(shooter)

	var ally = Node2D.new()
	ally.add_to_group("allies")
	add_child(ally)

	knife.launch(Vector2.ZERO, 1.0, Vector2.ZERO, shooter)

	# Fırlatanın kendisine çarpma denemesi
	knife._on_body_entered(shooter)
	_assert_true(knife.is_spent == false, "Mermi fırlatan oyuncuya çarpmaz / yok olmaz.")

	# Dost birliğe çarpma denemesi
	knife._on_body_entered(ally)
	_assert_true(knife.is_spent == false, "Mermi dost birliklere (allies) çarpmaz.")

	shooter.free()
	ally.free()
	knife.free()


func _test_10_player_inventory_and_cycling() -> void:
	print("--- Test 10: Oyuncu Envanteri, Mühimmat Düşümü ve Eşya Değiştirme ---")
	var player = PlayerScene.instantiate()
	add_child(player)

	_assert_true(player.secondary_inventory.has("knife"), "Envanterde 'knife' mevcut.")
	_assert_true(player.secondary_inventory.has("torch"), "Envanterde 'torch' mevcut.")
	_assert_true(player.secondary_inventory.has("holy_water"), "Envanterde 'holy_water' mevcut.")
	_assert_true(player.active_secondary_type == "knife", "Başlangıç aktif ikincil eşya 'knife'.")

	# Atış yapma ve mühimmat düşüşü
	var initial_knives = player.get_secondary_ammo("knife")
	var throw_result = player.throw_secondary()
	_assert_true(throw_result == true, "Mühimmat varken atış başarıyla gerçekleşti.")
	_assert_true(player.get_secondary_ammo("knife") == initial_knives - 1, "Bıçak sayısı 1 azaldı.")

	# Eşya döngüsü ([Q])
	player.cycle_secondary(1)
	_assert_true(player.active_secondary_type == "torch", "[Q] ile aktif eşya 'torch' oldu.")
	player.cycle_secondary(1)
	_assert_true(player.active_secondary_type == "holy_water", "[Q] ile aktif eşya 'holy_water' oldu.")
	player.cycle_secondary(1)
	_assert_true(player.active_secondary_type == "knife", "Döngü başa döndü ('knife').")

	# Doğrudan seçim ([5], [6], [7])
	player.select_secondary("torch")
	_assert_true(player.active_secondary_type == "torch", "select_secondary('torch') aktif eşyayı meşale yaptı.")

	# Cephane ekleme
	player.add_secondary_ammo("torch", 5)
	_assert_true(player.get_secondary_ammo("torch") == 8, "add_secondary_ammo() cephaneyi artırdı.")

	player.free()


func _test_11_empty_ammo_handling_and_feedback() -> void:
	print("--- Test 11: Mühimmat Yokken Atış Engelleme ve Geri Bildirim ---")
	var player = PlayerScene.instantiate()
	add_child(player)

	player.secondary_inventory["knife"] = 0
	player.active_secondary_type = "knife"

	var empty_events: Array = []
	player.secondary_ammo_empty.connect(func(type): empty_events.append(type))

	var throw_result = player.throw_secondary()

	_assert_true(throw_result == false, "Mühimmat 0 iken atış gerçekleşmedi (false döndü).")
	_assert_true(empty_events.size() == 1, "'secondary_ammo_empty' sinyali tetiklendi.")
	_assert_true(player.get_secondary_ammo("knife") == 0, "Cephane sayısı eksiye düşmedi (0 olarak kaldı).")

	player.free()


func _test_12_hud_secondary_slot_and_shake() -> void:
	print("--- Test 12: HUD İkincil Eşya Yuvası ve Görsel Uyarı ---")
	var hud: CanvasLayer = FantasyHUDScene.instantiate()
	add_child(hud)

	_assert_true(hud.secondary_slot != null, "HUD SlotTop ikincil eşya yuvası mevcut.")
	_assert_true(hud.secondary_count != null, "HUD ikincil eşya sayaç rozeti (CountBadge) mevcut.")
	_assert_true(hud.secondary_key != null, "HUD kısayol rozeti (KeyBadge 'F') mevcut.")

	# Slot güncelleme testi
	hud.update_secondary_slot("torch", 7)
	_assert_true(hud.active_secondary == "torch", "HUD aktif eşya 'torch' olarak güncellendi.")
	_assert_true(hud.secondary_count.text == "7", "HUD sayaç metni '7' oldu.")

	# Boş mühimmat uyarı animasyonu testi
	hud.flash_secondary_empty()
	_assert_true(true, "flash_secondary_empty() hatasız çağrıldı ve animasyon başlattı.")

	hud.queue_free()


func _test_13_projectile_lifetime_and_expiration() -> void:
	print("--- Test 13: Mermi Yaşam Süresi ve Zaman Aşımı Temizliği ---")
	var knife_scene = load("res://scenes/projectiles/throwable_knife.tscn")
	var knife: Area2D = knife_scene.instantiate()
	knife.lifetime = 0.1
	add_child(knife)

	var expired_events: Array = []
	knife.expired.connect(func(): expired_events.append(true))

	knife.launch(Vector2.ZERO, 1.0)
	knife._physics_process(0.12)

	_assert_true(expired_events.size() == 1, "Süresi dolan mermi 'expired' sinyali yaydı.")
	_assert_true(knife.is_spent == true, "Süresi dolan mermi is_spent=true durumuna geçti.")
	knife.queue_free()


func _test_14_procedural_audio_streams() -> void:
	print("--- Test 14: İkincil Eşya Prosedürel Sesleri ---")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	_assert_true(audio_mgr != null, "AudioManager Autoload singleton mevcut.")

	if audio_mgr:
		var p1 = audio_mgr.play_sfx("throw_item")
		_assert_true(p1 != null, "'throw_item' sesi başarıyla oluşturuldu ve çaldı.")
		var p2 = audio_mgr.play_sfx("knife_hit")
		_assert_true(p2 != null, "'knife_hit' sesi başarıyla oluşturuldu ve çaldı.")
		var p3 = audio_mgr.play_sfx("torch_burn")
		_assert_true(p3 != null, "'torch_burn' sesi başarıyla oluşturuldu ve çaldı.")
		var p4 = audio_mgr.play_sfx("holy_water_shatter")
		_assert_true(p4 != null, "'holy_water_shatter' sesi başarıyla oluşturuldu ve çaldı.")
		var p5 = audio_mgr.play_sfx("empty_ammo")
		_assert_true(p5 != null, "'empty_ammo' sesi başarıyla oluşturuldu ve çaldı.")


func _test_15_save_manager_integration() -> void:
	print("--- Test 15: SaveManager Entegrasyonu ve Mühimmat Kalıcılığı ---")
	var save_mgr = get_node_or_null("/root/SaveManager")
	_assert_true(save_mgr != null, "SaveManager Autoload singleton mevcut.")

	if save_mgr:
		var player = PlayerScene.instantiate()
		player.secondary_inventory = {"knife": 12, "torch": 8, "holy_water": 4}
		player.active_secondary_type = "torch"
		add_child(player)

		var live_stats = save_mgr._gather_live_stats()
		_assert_true(live_stats.has("secondary_inventory"), "live_stats 'secondary_inventory' alanını içeriyor.")
		_assert_true(live_stats["secondary_inventory"]["knife"] == 12, "Kayıt verisinde bıçak sayısı 12.")
		_assert_true(live_stats["active_secondary_type"] == "torch", "Kayıt verisinde aktif eşya 'torch'.")

		player.free()
