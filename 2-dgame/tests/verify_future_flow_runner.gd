extends Node

## res://tests/verify_future_flow_runner.gd
## Bölüm 5 akış doğrulaması (Epic 2D-158): 5 sekansın seviye mantığı, Son İnsanlık Sığınağı
## ahlaki seçimleri (Kefaret / +20 sömürü / +12 öldürme), Büyük Keşif Anı + Geçmişe Düşen Enkaz,
## easter egg'ler, güç yönlendirme + zaman mühürlü kapı + Siber-Ağ Kesintisi, mini-boss kapıları,
## AI Lord arenası, kılıç kabuğunun kırılışı + Bölüm 6 geçişi (iki son eşiği) ve
## Kefaret/Yozlaşma uçtan uca kayıt-yükleme (WorldObjectState + GameState).
## Çalıştırma: Godot --headless --path . res://tests/verify_future_flow.tscn

const U = preload("res://tests/future_test_utils.gd")
const ChapterState = preload("res://scripts/components/future_chapter_state.gd")
const Inventory = preload("res://scripts/components/future_inventory.gd")
const WorldObjectState = preload("res://scripts/components/world_object_state.gd")
const LV: String = "res://scenes/levels/future/"
const TEST_SLOT: int = 3

var failures: int = 0
var passes: int = 0
var gs: Node = null


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", msg)
	else:
		failures += 1
		printerr("FAIL: ", msg)


func _ready() -> void:
	print("--- FUTURE CHAPTER (2D-158) FLOW, ENDINGS & SAVE ---")
	gs = get_node("/root/GameState")
	_test_ending_rule()
	await _test_stage_1()
	await _test_stage_2()
	await _test_stage_3()
	await _test_stage_4()
	await _test_finale(0, 0, "redemption")
	await _test_finale(30, 1, "god_king")
	await _test_save_load()
	gs.reset_state()
	print("--- RESULT: %d passed, %d failed ---" % [passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


## Bölüm 6 son kuralı: < 50 Kefaret, >= 50 veya >= 3 kurban Tanrı-Kral
func _test_ending_rule() -> void:
	gs.reset_state()
	gs.add_corruption(49)
	check(gs.get_ending_alignment() == "redemption", "Yozlaşma 49: Kefaret")
	gs.add_corruption(1)
	check(gs.get_ending_alignment() == "god_king", "Yozlaşma 50: Tanrı-Kral")
	gs.reset_state()
	for i: int in 3:
		gs.allies_sacrificed_count += 1
	check(gs.get_ending_alignment() == "god_king", "3 kurban: Tanrı-Kral (puandan bağımsız)")
	gs.reset_state()


func _test_stage_1() -> void:
	gs.reset_state()
	var level: FutureStage1NeonRuins = await U.load_level(self, LV + "stage_1_neon_ruins.tscn") as FutureStage1NeonRuins
	await U.skip(self, level)
	var spots: Array[FutureRescueSpot] = level.get_rescue_spots()
	check(spots.size() == 2 and not spots[0].interaction_enabled, "metro sığınağında 2 direnişçi; muhafızlar ölmeden konuşulamaz")
	level.player.current_attack_type = "heavy" # kalkanlı android önden yalnızca ağır saldırıyla düşer
	for g: String in ["ShelterGuardA", "ShelterGuardB", "ShelterDrone"]:
		level.get_node("Enemies/" + g).take_damage(9999)
	level.player.current_attack_type = ""
	await get_tree().process_frame
	await get_tree().process_frame
	check(spots[0].interaction_enabled, "muhafızlar yenilince direnişçiyle konuşulabilir")
	level.apply_choice("rescue_survivor", spots[0])
	check(spots[0].outcome == "freed" and Inventory.count(self, "nano_repair_kit") == 2 and Inventory.has_item(self, "resistance_tag"),
		"Kefaret: tahliye kapsülü + 2 Nano-Tamir Kiti + Direniş Künyesi")
	level.apply_choice("exploit_survivor", spots[1])
	check(gs.corruption_score == 20 and gs.allies_sacrificed_count == 1, "sömürü: +20 Yozlaşma ve kurban sayacı")
	await U.skip(self, level)
	check(str(get_node("/root/QuestManager").get_quest("future_last_shelter").get("status", "")) == "failed",
		"Son İnsanlık Sığınağı: bir direnişçi sömürülünce yan görev başarısız")
	check(level.find_children("*", "FutureLaserTrap", true, false).size() >= 2 and level.find_children("*", "LaserGate", true, false).size() >= 2
		and level.get_node_or_null("CollapsingBridge") != null, "çatı geçişleri: tarama lazerleri, lazer kapıları, çöken köprü")
	level.next_scene_path = ""
	level.transition_to_next()
	await U.skip(self, level)
	check(U.stage_done(self, "future_processor_heart", "cross_neon_ruins"), "çıkışta 'Neon enkazını aş' aşaması tamamlanır")
	await U.unload(self, level)


func _test_stage_2() -> void:
	gs.reset_state()
	var level: FutureStage2TemporalAssembly = await U.load_level(self, LV + "stage_2_temporal_assembly.tscn") as FutureStage2TemporalAssembly
	await U.skip(self, level)
	level.trigger_mold_discovery()
	await U.skip(self, level)
	check(level.mold_seen and U.stage_done(self, "future_processor_heart", "reach_assembly"), "Büyük Keşif Anı: damgalı kalıp, kılıç titrer, görev ilerler")
	for n: String in ["ScanSocket", "ScanHarness"]:
		(level.get_node("Objects/" + n) as FutureLoreTerminal).interact()
		await U.skip(self, level)
	var cm: Node = get_node("/root/CodexManager")
	check(ChapterState.all_scanned(self) and Inventory.has_item(self, "stamped_prototype_part") and cm.is_unlocked("future_lore_fallen_wreckage"),
		"Geçmişe Düşen Enkazın Sırrı: iki şema taranır, özel Codex + Damgalı Prototip Parçası")
	var wall: SecretBreakableWall = level.get_node("Objects/RexSecretWall") as SecretBreakableWall
	var probe: Node = Node.new()
	probe.set_script(GDScript.new())
	var emp: EmpGrenade = EmpGrenade.new()
	wall.take_damage(999, emp)
	emp.free()
	probe.free()
	(level.get_node("Objects/RexTelemetry") as FutureLoreTerminal).interact()
	await U.skip(self, level)
	check(wall.is_broken and cm.is_unlocked("future_lore_rex_telemetry"), "easter egg: gizli duvar ardında Unit-REX-01 telemetri terminali")
	check(not level.can_exit(), "Krono-Muhafız yenilmeden kapı kilitli")
	level.start_warden_fight()
	await U.skip(self, level)
	level.warden.die()
	await U.skip(self, level)
	var gate_shape: CollisionShape2D = level.gate_lock.get_child(0) as CollisionShape2D
	await get_tree().physics_frame
	check(level.can_exit() and gate_shape.disabled and U.stage_done(self, "future_processor_heart", "defeat_chrono_warden"),
		"Krono-Muhafız yenilince kapı kilidi açılır")
	await U.unload(self, level)


func _test_stage_3() -> void:
	gs.reset_state()
	var level: FutureStage3ResistanceCitadel = await U.load_level(self, LV + "stage_3_resistance_citadel.tscn") as FutureStage3ResistanceCitadel
	await U.skip(self, level)
	var ta: EmpTerminal = level.get_node("Objects/TerminalA") as EmpTerminal
	var tb: EmpTerminal = level.get_node("Objects/TerminalB") as EmpTerminal
	tb.interact()
	check(not tb.is_hacked, "güç yönlendirme: ikinci terminal birinci olmadan çalışmaz")
	ta.interact()
	await U.skip(self, level)
	tb.interact()
	await U.skip(self, level)
	var gates_off: bool = true
	for i: int in 3:
		gates_off = gates_off and not (level.get_node("Hazards/CorridorGate%d" % i) as LaserGate).is_active()
	check(ta.is_hacked and tb.is_hacked and gates_off and not (level.get_node("Hazards/VaultLaser") as FutureLaserTrap).is_active(),
		"EMP terminalleri sırayla hacklenir; lazer kapıları ve tarama lazeri söner")
	var door: FutureResonanceDoor = level.get_node("Objects/ResonanceDoor") as FutureResonanceDoor
	door.interact()
	await U.skip(self, level)
	check(not door.is_open, "Kalp Rezonansı olmadan zaman mühürlü kapı açılmaz")
	gs.unlock_ability("heart_resonance")
	door.interact()
	await U.skip(self, level)
	await get_tree().physics_frame
	check(door.is_open and (level.get_node("SealBarrier").get_child(0) as CollisionShape2D).disabled, "heart_resonance ile mühürlü kapı açılır")
	for n: String in ["ServerA", "ServerB", "ServerC"]:
		(level.get_node("ServerNodes/" + n) as ServerNode).take_damage(999)
		await U.skip(self, level)
	check(ChapterState.is_network_down(self) and U.stage_done(self, "future_network_outage", "destroy_nodes"), "Siber-Ağ Kesintisi: 3 düğüm imha edildi")
	var spots: Array[FutureRescueSpot] = level.get_rescue_spots()
	level.apply_choice("evacuate_engineer", spots[0])
	level.apply_choice("evacuate_engineer", spots[1])
	await U.skip(self, level)
	check(Inventory.count(self, "emp_grenade") == 4 and U.stage_done(self, "future_last_shelter", "evacuate_engineers") and gs.corruption_score == 0,
		"mühendisler tahliye edildi (Kefaret, EMP ödülü)")
	check(not level.can_exit(), "AEGIS-09 yenilmeden asansör kilitli")
	level.start_aegis_fight()
	await U.skip(self, level)
	level.aegis.die()
	await U.skip(self, level)
	check(level.can_exit() and Inventory.has_item(self, "core_access_chip"), "AEGIS-09 yenilince Çekirdek Erişim Çipi")
	check(level.get_exit_story_key() == "fut_citadel_exit_redemption", "kimse sömürülmediyse Kefaret çıkış diyaloğu")
	await U.unload(self, level)


func _test_stage_4() -> void:
	gs.reset_state()
	var level: FutureStage4AiLordCitadel = await U.load_level(self, LV + "stage_4_ai_lord_citadel.tscn") as FutureStage4AiLordCitadel
	await U.skip(self, level)
	check(level.find_children("WaveTrigger*", "Area2D", true, false).size() == 3 and level.find_children("*", "LaserGate", true, false).size() >= 3,
		"kule tırmanışı: 3 dron dalgası ve Kan Sisi lazer ızgaraları")
	level.start_boss_fight()
	await U.skip(self, level)
	check(level.boss.is_active, "taunt sonrası AI Lord savaşı başlar")
	var drones: Array[Node2D] = level.spawn_drones(2)
	check(drones.size() == 2, "AI Lord dron çağrısı arenaya dron getirir")
	level.set_turrets_active(2, true)
	check(level.active_turrets == 2, "Form 2 taret desteği arena taretlerini açar")
	level.next_scene_path = ""
	level.boss.take_damage(999999)
	await get_tree().create_timer(2.6).timeout
	await U.skip(self, level)
	check(level.boss_defeated and level.active_turrets == 0 and U.stage_done(self, "future_processor_heart", "defeat_ai_lord"),
		"AI Lord yenildi: taretler kapanır, görev ilerler")
	await U.unload(self, level)


## Kılıç kabuğu kırılma ve Bölüm 6 geçiş testi (iki son eşiği)
func _test_finale(corruption: int, sacrifices: int, expected: String) -> void:
	gs.reset_state()
	gs.current_heart_pieces = 4
	gs.add_corruption(corruption)
	gs.allies_sacrificed_count = sacrifices
	if expected == "god_king" and corruption < 50:
		gs.allies_sacrificed_count = 3
	var level: FutureStage5SwordShattering = await U.load_level(self, LV + "stage_5_sword_shattering.tscn") as FutureStage5SwordShattering
	var shattered: Array[bool] = [false]
	level.shell_shattered.connect(func() -> void: shattered[0] = true)
	level.extract_heart_piece()
	await get_tree().create_timer(1.8).timeout
	check(gs.current_heart_pieces == 5 and get_node("/root/CodexManager").is_unlocked("future_lore_processor_heart"), "5. Kalp Parçası AI Lord'un çekirdeğinden söküldü")
	level.shatter_sword_shell()
	check(shattered[0] and gs.has_ability("sixth_core_awakening") and level.player.get_node_or_null("SwordSixthCoreVfx") != null,
		"6. çekirdek uyandı, kılıcın dış kabuğu paramparça (VFX + aura)")
	level._summon_wizard_shadow()
	level._play_outro()
	check(gs.get_recorded_ending() == expected and level.void_rift.visible, "son eğilimi '%s' kaydedildi, Hiçlik Arenası yırtığı açıldı" % expected)
	level._complete_chapter()
	check(gs.is_chapter_completed("chapter_5") and level.chapter_completed, "Bölüm 5 tamamlandı (Bölüm 6 geçişi hazır)")
	await U.unload(self, level)


## Kefaret/Yozlaşma uçtan uca kayıt-yükleme (WorldObjectState + GameState)
func _test_save_load() -> void:
	var sm: Node = get_node("/root/SaveManager")
	var backups: Dictionary = U.backup_slot(TEST_SLOT)
	var prev_slot: int = int(sm.active_slot)
	gs.reset_state()
	var level: FutureStage1NeonRuins = await U.load_level(self, LV + "stage_1_neon_ruins.tscn") as FutureStage1NeonRuins
	var spots: Array[FutureRescueSpot] = level.get_rescue_spots()
	level.apply_choice("rescue_survivor", spots[0])
	spots[1].get_npc().take_damage(999)
	(level.get_node("Pickups/EmpPack") as FuturePickup).collect()
	ChapterState.mark_node_destroyed(self, "node_a")
	await U.skip(self, level)
	check(spots[1].outcome == "killed" and gs.corruption_score == 12, "direnişçi öldürüldü: +12 Yozlaşma")
	check(sm.save_game(TEST_SLOT), "kayıt alındı (yuva %d)" % TEST_SLOT)
	await U.unload(self, level)
	gs.reset_state()
	check(gs.persistent_events.is_empty() and gs.corruption_score == 0, "durum sıfırlandı")
	check(sm.load_game(TEST_SLOT), "kayıt yüklendi")
	check(gs.corruption_score == 12 and ChapterState.get_outcome(self, "survivor", "survivor_a") == "freed"
		and ChapterState.get_outcome(self, "survivor", "survivor_b") == "killed" and ChapterState.is_node_destroyed(self, "node_a"),
		"Kefaret/Yozlaşma sonuçları, puan ve Siber-Ağ ilerlemesi geri geldi")
	check(Inventory.count(self, "emp_grenade") == 2 and Inventory.count(self, "nano_repair_kit") == 2, "Bölüm 5 envanteri geri geldi")
	var reloaded: FutureStage1NeonRuins = await U.load_level(self, LV + "stage_1_neon_ruins.tscn", true) as FutureStage1NeonRuins
	var rs: Array[FutureRescueSpot] = reloaded.get_rescue_spots()
	check(rs[0].is_resolved() and rs[1].is_resolved() and not rs[0].get_npc().visible, "yeniden yüklenen sahnede seçimler kalıcı")
	check(reloaded.get_node_or_null("Pickups/EmpPack") == null or (reloaded.get_node("Pickups/EmpPack") as FuturePickup).is_collected,
		"toplanan eşya (WorldObjectState) tekrar çıkmıyor")
	await U.unload(self, reloaded)
	U.restore_slot(TEST_SLOT, backups)
	sm.active_slot = prev_slot
	sm.save_settings()
