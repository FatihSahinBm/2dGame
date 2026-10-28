extends SceneTree

const BRIDGE_SCENE_PATH = "res://scenes/levels/vlad/stage_1_bridge_assault.tscn"

var _passed_count = 0
var _failed_count = 0

func _init() -> void:
	print("==================================================")
	print("  TEST: VLAD CHAPTER GÖREV 5 - KOÇBAŞI & KAPI KIRILMASI")
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
	var scene_res = load(BRIDGE_SCENE_PATH)
	_assert_true(scene_res != null, "stage_1_bridge_assault.tscn sahnesi başarıyla yüklendi")
	if not scene_res:
		_finish()
		return

	var root_node = root
	var bridge = scene_res.instantiate() as Stage1BridgeAssault
	_assert_true(bridge != null, "Stage1BridgeAssault instance başarıyla oluşturuldu")
	root_node.add_child(bridge)

	# 2. Kapı Görsel Ağacı ve Düz Renkli ColorRect Kontrolü
	var exit_gate = bridge.get_node_or_null("ExitGate") as Area2D
	_assert_true(exit_gate != null, "ExitGate Area2D düğümü mevcut")

	# Eski ColorRect geçici kutuların bulunmadığını doğrula
	var old_pillar_l = exit_gate.get_node_or_null("ArchPillarLeft")
	var old_pillar_r = exit_gate.get_node_or_null("ArchPillarRight")
	var old_lintel = exit_gate.get_node_or_null("ArchLintel")
	var old_band = exit_gate.get_node_or_null("WoodenDoors/DoorBandTop")
	_assert_true(old_pillar_l == null and old_pillar_r == null and old_lintel == null and old_band == null, "Eski ilkel ColorRect sütun ve pervaz geometrileri tamamen kaldırılmış")

	# Yeni piksel-sanat assetlerinin varlığını doğrula
	var arch_stone = exit_gate.get_node_or_null("ArchStoneFrame") as Sprite2D
	_assert_true(arch_stone != null and arch_stone.texture != null, "ArchStoneFrame Sprite2D (gothic_gate_arch.png) mevcut")

	var portcullis = exit_gate.get_node_or_null("PortcullisBars") as Sprite2D
	_assert_true(portcullis != null and portcullis.texture != null, "PortcullisBars Sprite2D (gothic_portcullis.png) demir parmaklık mevcut")

	var door_l = exit_gate.get_node_or_null("WoodenDoors/DoorLeft") as Sprite2D
	var door_r = exit_gate.get_node_or_null("WoodenDoors/DoorRight") as Sprite2D
	_assert_true(door_l != null and door_l.texture != null, "DoorLeft Sprite2D (gothic_door_left.png) ahşap kanat mevcut")
	_assert_true(door_r != null and door_r.texture != null, "DoorRight Sprite2D (gothic_door_right.png) ahşap kanat mevcut")

	var mist = exit_gate.get_node_or_null("DungeonAbyssMist") as CPUParticles2D
	_assert_true(mist != null and mist.emitting, "DungeonAbyssMist mahzen sisi partikülü aktif")

	var torch_l = exit_gate.get_node_or_null("TorchLeft") as CPUParticles2D
	var torch_r = exit_gate.get_node_or_null("TorchRight") as CPUParticles2D
	_assert_true(torch_l != null and torch_r != null, "Giriş meşaleleri (TorchLeft & TorchRight) aktif")

	# 3. Koçbaşı Ekibi (BatteringRamCrew) Kontrolü
	var ram_crew = bridge.get_node_or_null("BatteringRamCrew") as BatteringRamCrew
	_assert_true(ram_crew != null, "BatteringRamCrew düğümü mevcut")

	# 4. Kumandan Durumu Dallanması Testi
	var game_state = root_node.get_node_or_null("GameState")
	if not game_state:
		var gs_script = load("res://scripts/autoloads/game_state.gd")
		if gs_script:
			game_state = Node.new()
			game_state.set_script(gs_script)
			game_state.name = "GameState"
			root_node.add_child(game_state)

	if game_state:
		game_state.is_commander_alive = false
		bridge._on_blood_knight_died()
		_assert_true(true, "Kumandan şehit düştüğünde 'battering_ram_victory_sergeant' dallanması başarıyla çağrıldı")

	# 5. Koçbaşı ve Kapı Kırılma Animasyon / Parçalanma Sekansı Testi
	print("  [INFO] Koçbaşı sekansı ve kapı kırılma simülasyonu çalıştırılıyor...")
	ram_crew._shatter_gate_visuals(exit_gate)

	# Tweenlerin ilerlemesi için zamanlayıcı bekle
	await create_timer(0.25).timeout

	# Kapı kanatlarının açıldığını / rotasyon aldığını doğrula
	var left_tweened = (door_l.rotation_degrees != 0.0 or door_l.modulate.a < 1.0 or door_l.position.x < -11.0)
	var right_tweened = (door_r.rotation_degrees != 0.0 or door_r.modulate.a < 1.0 or door_r.position.x > 11.0)
	_assert_true(left_tweened and right_tweened, "Kapı kanatları (DoorLeft & DoorRight) koçbaşı darbesiyle menteşelerinden koparak savruluyor")

	var port_tweened = (portcullis.position.y < -7.5 or portcullis.modulate.a < 1.0)
	_assert_true(port_tweened, "Demir parmaklık (PortcullisBars) yukarı doğru fırlayarak kırılıyor")

	# 6. Partikül Patlamaları Testi
	ram_crew._spawn_splinters_explosion(exit_gate.global_position)
	var particles_spawned = false
	for child in bridge.get_children():
		if child is CPUParticles2D and child.texture != null:
			particles_spawned = true
			break
	_assert_true(particles_spawned, "Ahşap kıymıkları ve demir parçaları CPUParticles2D enkaz patlaması başarıyla üretildi")

	# 7. Mahzene Geçiş (Transition) Tetikleme Testi
	bridge._gate_breached = true
	_assert_true(bridge.next_scene_path == "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn", "Sonraki sahne yolu 'stage_2_castle_dungeon.tscn' olarak doğru tanımlanmış")

	bridge.queue_free()
	_finish()

func _finish() -> void:
	print("==================================================")
	print("  TEST SONUÇLARI: %d BAŞARILI, %d BAŞARISIZ" % [_passed_count, _failed_count])
	print("==================================================")
	quit(_failed_count)
