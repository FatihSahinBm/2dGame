extends Node

## res://tests/verify_egypt_gameplay_runner.gd
## Bölüm 3 (Antik Mısır) oynanış doğrulaması — Epic 2D-143.
## Tuzaklar, Kefaret ve Yozlaşma rotaları (köle/lahit seçimleri), mühür bulmacası, mumya dalgası,
## 3 fazlı Firavun Kral savaşı ve final sekansı (Kalp Parçası → flashback → kılıç evrimi → outro).
## Çalıştırma: Godot --headless --path . res://tests/verify_egypt_gameplay.tscn

const L2: String = "res://scenes/levels/egypt/egypt_02_monument_courtyard.tscn"
const L3: String = "res://scenes/levels/egypt/egypt_03_cursed_tomb.tscn"
const L4: String = "res://scenes/levels/egypt/egypt_04_sun_throne.tscn"

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
	print("--- EGYPT CHAPTER (2D-143) GAMEPLAY ---")
	gs = get_node_or_null("/root/GameState")
	await _test_hazards()
	await _test_courtyard_redemption()
	await _test_courtyard_corruption()
	await _test_tomb()
	await _test_boss_and_finale("redemption", 0)
	await _test_boss_and_finale("god_king", 60)
	gs.reset_state()
	print("--- RESULT: %d passed, %d failed ---" % [passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _load(path: String) -> Node:
	gs.persistent_events.clear()
	get_node("/root/QuestManager").reset_quests()
	var level: Node = (load(path) as PackedScene).instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return level


func _unload(level: Node) -> void:
	var dlg: Node = level.get_node_or_null("DialogueBox")
	if dlg and dlg.has_method("skip_dialogue"):
		dlg.skip_dialogue()
	level.queue_free()
	await get_tree().process_frame
	var cm: Node = get_node_or_null("/root/CinematicManager")
	if cm and cm.has_method("force_reset"):
		cm.force_reset("test")


func _test_hazards() -> void:
	var trap: SandTrap = (load("res://scenes/hazards/egypt/sand_trap.tscn") as PackedScene).instantiate() as SandTrap
	add_child(trap)
	var target: Node2D = _damage_probe()
	trap.apply_tick(target)
	check(int(target.get_meta("dmg")) == trap.damage_per_tick, "kum tuzağı hasar veriyor (%d)" % trap.damage_per_tick)
	trap.queue_free()
	var beam: SunBeam = SunBeam.new()
	beam.autostart = false
	add_child(beam)
	beam.fire_sequence()
	check(beam.phase == SunBeam.Phase.TELEGRAPH and not beam.is_dangerous(), "güneş ışını önce telegraph (zararsız)")
	check(not beam.hit_body(target), "telegraph sırasında hasar yok")
	await get_tree().create_timer(beam.telegraph_time + 0.1).timeout
	check(beam.is_dangerous(), "telegraph sonrası ışın ateşlendi")
	check(beam.hit_body(target) and not beam.hit_body(target), "ışın bir aktivasyonda tek kez vuruyor")
	beam.queue_free()
	target.queue_free()


## take_damage çağrılarını sayan basit hedef
func _damage_probe() -> Node2D:
	var probe: Node2D = Node2D.new()
	var src: GDScript = GDScript.new()
	src.source_code = "extends Node2D\nfunc take_damage(a: int, _s: Variant = null) -> void:\n\tset_meta(\"dmg\", int(get_meta(\"dmg\", 0)) + a)\n"
	src.reload()
	probe.set_script(src)
	add_child(probe)
	return probe


## Açık diyaloğu kapatır (dialogue_completed yayılır); yoksa seviyenin geri çağrısını doğrudan çağırır
func _finish_dialogue(level: Egypt04SunThrone) -> void:
	var dlg: Node = level.dialogue_box
	if dlg and dlg.is_dialogue_active():
		dlg.skip_dialogue()
	else:
		level._on_dialogue_completed()
	await get_tree().process_frame


func _kill_all(level: Node, group_parent: String) -> void:
	var parent: Node = level.get_node_or_null(group_parent)
	if parent:
		for e: Node in parent.get_children():
			if e.has_method("take_damage"):
				e.take_damage(9999)
	await get_tree().process_frame


func _test_courtyard_redemption() -> void:
	gs.reset_state()
	var level: Egypt02MonumentCourtyard = await _load(L2) as Egypt02MonumentCourtyard
	var cages: Array[SlaveCage] = level.get_cages()
	check(cages.size() == 3, "avluda 3 köle kafesi")
	check(not cages[1].interaction_enabled and not cages[1].are_guards_defeated(), "muhafızlar yaşarken kafes kilitli")
	check(not level.can_exit(), "kararlar verilmeden çıkış kapalı")
	await _kill_all(level, "Enemies")
	await get_tree().process_frame
	check(cages[1].interaction_enabled, "muhafızlar ölünce köleyle konuşulabiliyor")
	for cage: SlaveCage in cages:
		level.apply_choice("free_slave", cage)
	check(gs.corruption_score == 0 and gs.allies_sacrificed_count == 0, "Kefaret: kurtarma yozlaşma eklemiyor")
	check(level.ChapterState.count_outcome(level, "freed") == 3, "3 köle özgür olarak kaydedildi")
	check(bool(gs.persistent_events.get("egypt_ally_nefer", false)) and level.ChapterState.is_redemption_path(level), "Nefer müttefik / Kefaret bayrakları")
	check(get_node("/root/QuestManager").is_quest_completed("egypt_break_the_chains"), "yan görev 'Zincirleri Kır' tamamlandı")
	var sarcs: Array[Node] = level.find_children("*", "CursedSarcophagus", true, false)
	(sarcs[0] as CursedSarcophagus).shatter()
	check(gs.corruption_score == 0 and (sarcs[0] as CursedSarcophagus).state == CursedSarcophagus.State.BROKEN, "lahdi kırmak yozlaşma eklemiyor")
	await get_tree().process_frame
	check(level.find_children("*", "", true, false).any(func(n: Node) -> bool: return n.name.begins_with("RisenMummy")), "kırılan lahitten mumya uyanıyor")
	check(level.can_exit() and level.get_exit_story_key() == "egypt_courtyard_exit_redemption", "çıkış açık, Kefaret anlatımı")
	await _unload(level)


func _test_courtyard_corruption() -> void:
	gs.reset_state()
	var level: Egypt02MonumentCourtyard = await _load(L2) as Egypt02MonumentCourtyard
	await _kill_all(level, "Enemies")
	var cages: Array[SlaveCage] = level.get_cages()
	var player: Node2D = level.player
	player.current_health = 20
	level.apply_choice("drain_slave", cages[0])
	check(gs.corruption_score == 20 and gs.allies_sacrificed_count == 1, "köle sömürüsü +20 yozlaşma ve kurban sayacı")
	check(player.current_health == 60, "sömürü oyuncuyu iyileştiriyor (+40)")
	cages[1].get_slave().take_damage(999, player)
	check(gs.corruption_score == 32 and gs.allies_killed_count == 1 and cages[1].outcome == "killed", "köle öldürmek +12 yozlaşma")
	level.apply_choice("drain_slave", cages[2])
	var sarc: CursedSarcophagus = level.find_children("*", "CursedSarcophagus", true, false)[0] as CursedSarcophagus
	level.apply_choice("drain_sarcophagus", sarc)
	check(gs.corruption_score == 72 and gs.allies_sacrificed_count == 3, "lahit sömürüsü +20 (toplam 72, 3 kurban)")
	check(sarc.state == CursedSarcophagus.State.DRAINED and not sarc.interaction_enabled, "sömürülen lahit tekrar kullanılamaz")
	check(gs.get_ending_alignment() == "god_king", "Yozlaşma rotası Tanrı-Kral eğilimine geçti")
	check(not level.ChapterState.is_redemption_path(level) and level.get_exit_story_key() == "egypt_courtyard_exit_corrupted", "Yozlaşma çıkış anlatımı")
	check(get_node("/root/QuestManager").get_quest("egypt_break_the_chains").get("status") == "failed", "yan görev başarısız sayıldı")
	await _unload(level)


func _test_tomb() -> void:
	gs.reset_state()
	var level: Egypt03CursedTomb = await _load(L3) as Egypt03CursedTomb
	check(level.seal_door != null and not level.can_exit(), "mühür kapısı kapalı, çıkış engelli")
	var keys: Array[EgyptPickup] = []
	for n: Node in level.find_children("*", "EgyptPickup", true, false):
		if (n as EgyptPickup).kind == EgyptPickup.KIND_SEAL_KEY:
			keys.append(n as EgyptPickup)
	check(keys.size() == 2, "iki Güneş Mührü anahtarı yerleştirildi")
	keys[0].collect(level.player)
	check(not level.seal_door.is_open and level.seal_door.get_collected_count() == 1, "tek anahtarla kapı açılmıyor")
	keys[1].collect(level.player)
	check(level.seal_door.is_open and level.can_exit(), "iki anahtarla mühür kapısı açıldı")
	var wave: Array[Node2D] = level.spawn_mummy_wave()
	check(wave.size() == 3, "mumya dalgası 3 mumya kaldırdı")
	await get_tree().create_timer(0.9).timeout
	check(wave[0].is_physics_processing(), "mumyalar kalkış animasyonundan sonra aktif")
	check(level.find_children("*", "SunBeam", true, false).size() >= 3 and level.find_children("*", "SandTrap", true, false).size() >= 2, "tuzak koridorları (ışın + kum)")
	await _unload(level)


func _test_boss_and_finale(route: String, corruption: int) -> void:
	gs.reset_state()
	gs.corruption_score = corruption
	var level: Egypt04SunThrone = await _load(L4) as Egypt04SunThrone
	level.autosave_on_complete = false
	var qm: Node = get_node("/root/QuestManager")
	for stage: String in ["cross_desert", "decide_courtyard", "collect_seals"]:
		qm.advance_quest("egypt_curse_of_the_sun", stage)
	var boss: PharaohBoss = level.boss
	check(level.dialogue_state == "intro" and not boss.is_active, "[%s] karşılama diyaloğu sürerken boss bekliyor" % route)
	await _finish_dialogue(level)
	check(boss.is_active, "[%s] diyalog sonrası savaş başladı" % route)
	boss.start_attack("beam")
	boss._execute_attack("beam")
	check(level.find_children("*", "SunBeam", true, false).size() >= 1, "[%s] Güneş Asası ışını (telegraph'lı) çağrıldı" % route)
	boss.take_damage(int(boss.max_health * 0.4))
	check(boss.phase == 2 and level.dialogue_state == "phase" and not boss.is_active, "[%s] 2. faz geçişi ve taunt" % route)
	await _finish_dialogue(level)
	boss._execute_attack("sand")
	check(level.find_children("*", "SandTrap", true, false).size() >= 3, "[%s] 2. faz kum tuzakları" % route)
	boss.take_damage(int(boss.max_health * 0.35))
	check(boss.phase == 3 and level.dialogue_state == "phase", "[%s] 3. faz geçişi ve taunt" % route)
	await _finish_dialogue(level)
	await get_tree().create_timer(0.7).timeout
	check(str(boss.anim.animation).ends_with("_enraged"), "[%s] 3. faz: çatlak altın maske animasyonları" % route)
	boss._execute_attack("summon")
	check(level.minions.size() == 3, "[%s] dirilen mumya ordusu çağrıldı" % route)
	boss.take_damage(99999)
	check(boss.is_dead and level.boss_defeated, "[%s] Firavun Kral yenildi" % route)
	await get_tree().create_timer(1.8).timeout
	check(int(gs.current_heart_pieces) >= 3 and level.dialogue_state == "last_words", "[%s] 3. Kalp Parçası alındı, son sözler" % route)
	await _finish_dialogue(level)
	check(level.flashback.is_playing() and level.flashback.memory_key == "egypt_memory_flashback", "[%s] memory_flashback (3. Anı Kırılması) tetiklendi" % route)
	level.flashback.skip_flashback()
	check(gs.has_ability("sun_seal_fracture") and level.dialogue_state == "evolution", "[%s] mühür zayıfladı, kılıç evrimi" % route)
	var leak: Node = level.player.get_node_or_null("SwordSealLeak")
	check(leak != null and leak.is_leaking() and level.hud.get_node_or_null("SealWeakenedBadge") != null, "[%s] kızıl-mavi sızıntı VFX + HUD rozeti" % route)
	await _finish_dialogue(level)
	check(level.dialogue_state == "outro" and gs.get_recorded_ending() == route and level.exit_rift.visible, "[%s] outro ve Bölüm 4 zaman yırtığı" % route)
	await _finish_dialogue(level)
	check(gs.is_chapter_completed("chapter_3"), "[%s] Bölüm 3 tamamlandı" % route)
	check(qm.get_quest("egypt_curse_of_the_sun").get("status") == "completed", "[%s] ana görev tamamlandı" % route)
	await get_tree().create_timer(2.2).timeout
	check(level.get_node_or_null("ResultsScreen") != null, "[%s] sonuç ekranı açıldı" % route)
	await _unload(level)
