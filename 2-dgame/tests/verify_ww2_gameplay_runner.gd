extends Node

## res://tests/verify_ww2_gameplay_runner.gd
## Bölüm 4 (2. Dünya Savaşı) oynanış doğrulaması — Epic 2D-144.
## Tehlikeler (topçu + sığınak, tel, mayın, gaz, projektör, el bombası/gizli duvar), eşyalar,
## Siperdeki Yaralılar + Mini-Boss 1, Sessiz Batarya + tren + takviye, laboratuvar bulmacası +
## Kafesteki Denekler + Mini-Boss 2, 3 formlu Cani Komutan, iki rotada final (Anı Kırılması)
## ve Kefaret/Yozlaşma uçtan uca kayıt-yükleme (WorldObjectState + GameState).
## Çalıştırma: Godot --headless --path . res://tests/verify_ww2_gameplay.tscn

const L1: String = "res://scenes/levels/ww2/stage_1_bombed_trenches.tscn"
const L2: String = "res://scenes/levels/ww2/stage_2_ruined_city_viaduct.tscn"
const L3: String = "res://scenes/levels/ww2/stage_3_occult_lab.tscn"
const L4: String = "res://scenes/levels/ww2/stage_4_command_bunker_boss.tscn"
const L5: String = "res://scenes/levels/ww2/stage_5_memory_rift.tscn"
const ChapterState = preload("res://scripts/components/ww2_chapter_state.gd")
const Inventory = preload("res://scripts/components/ww2_inventory.gd")
const Attacks = preload("res://scripts/enemies/ww2/commander_boss_attacks.gd")
const TEST_SLOT: int = 3

var failures: int = 0
var passes: int = 0
var gs: Node = null
var qm: Node = null


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", msg)
	else:
		failures += 1
		printerr("FAIL: ", msg)


func _ready() -> void:
	print("--- WW2 CHAPTER (2D-144) GAMEPLAY ---")
	gs = get_node("/root/GameState")
	qm = get_node("/root/QuestManager")
	await _test_hazards()
	await _test_trenches()
	await _test_viaduct()
	await _test_lab()
	await _test_boss("redemption", 0)
	await _test_boss("god_king", 60)
	await _test_finale("redemption", 0)
	await _test_finale("god_king", 60)
	await _test_save_load()
	gs.reset_state()
	print("--- RESULT: %d passed, %d failed ---" % [passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------
# Yardımcılar
# ---------------------------------------------------------------------------
func _load(path: String, keep_events: bool = false) -> Node:
	if not keep_events:
		gs.persistent_events.clear()
		qm.reset_quests()
	var level: Node = (load(path) as PackedScene).instantiate()
	if "autosave_on_complete" in level:
		level.autosave_on_complete = false
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


func _skip(level: Node) -> void:
	var dlg: Node = level.get_node_or_null("DialogueBox")
	if dlg and dlg.has_method("is_dialogue_active") and dlg.is_dialogue_active():
		dlg.skip_dialogue()
	elif level.has_method("_on_dialogue_completed"):
		level._on_dialogue_completed()
	await get_tree().process_frame


func _stage_done(quest_id: String, stage_id: String) -> bool:
	for st: Variant in qm.get_quest(quest_id).get("stages", []):
		if str((st as Dictionary).get("id", "")) == stage_id:
			return bool((st as Dictionary).get("completed", false))
	return false


## take_damage çağrılarını sayan, "player" grubundaki basit hedef
func _probe(at: Vector2 = Vector2.ZERO) -> Node2D:
	var probe: Node2D = Node2D.new()
	var src: GDScript = GDScript.new()
	src.source_code = "extends Node2D\nvar is_blood_mist_dashing: bool = false\nvar current_health: int = 50\nvar max_health: int = 100\n" \
		+ "func take_damage(a: int, _s: Variant = null) -> void:\n\tset_meta(\"dmg\", int(get_meta(\"dmg\", 0)) + a)\n" \
		+ "func heal(a: int) -> void:\n\tcurrent_health = mini(max_health, current_health + a)\n"
	src.reload()
	probe.set_script(src)
	probe.add_to_group("player")
	add_child(probe)
	probe.global_position = at
	return probe


func _dmg(probe: Node) -> int:
	return int(probe.get_meta("dmg", 0))


# ---------------------------------------------------------------------------
# Tehlikeler ve eşyalar
# ---------------------------------------------------------------------------
func _test_hazards() -> void:
	gs.reset_state()
	gs.persistent_events.clear()
	var probe: Node2D = _probe()
	var shell: ArtilleryShell = ArtilleryShell.new()
	shell.autostart = false
	shell.telegraph_time = 0.2
	add_child(shell)
	shell.arm()
	check(not shell.is_dangerous() and _dmg(probe) == 0, "topçu: önce hedef işareti + ıslık (zararsız telegraph)")
	await get_tree().create_timer(0.35).timeout
	check(_dmg(probe) == 22, "topçu: telegraph sonrası patlama hasarı (22)")
	var shelter: BunkerShelter = BunkerShelter.new()
	add_child(shelter)
	shelter.force_enter(probe)
	var shell2: ArtilleryShell = ArtilleryShell.new()
	shell2.autostart = false
	add_child(shell2)
	shell2.detonate()
	check(_dmg(probe) == 22, "sığınaktaki oyuncu topçudan etkilenmiyor")
	shelter.queue_free()
	probe.is_blood_mist_dashing = true
	var shell3: ArtilleryShell = ArtilleryShell.new()
	shell3.autostart = false
	add_child(shell3)
	shell3.detonate()
	check(_dmg(probe) == 22, "Kan Sisi Atılması topçu patlamasından korur")
	var wire: BarbedWire = BarbedWire.new()
	add_child(wire)
	check(not wire.apply_tick(probe), "Kan Sisi Atılması dikenli telden zarar görmeden geçer")
	probe.is_blood_mist_dashing = false
	check(wire.apply_tick(probe) and _dmg(probe) == 27, "dikenli tel yaralar (5)")
	wire.queue_free()
	var gas: ToxicGas = ToxicGas.new()
	add_child(gas)
	check(gas.apply_tick(probe) and _dmg(probe) == 33, "zehirli gaz hasar verir (6)")
	probe.set_meta(Inventory.META_GAS_IMMUNE_UNTIL, Time.get_ticks_msec() + 5000)
	check(not gas.apply_tick(probe), "gaz maskesi filtresi zehri engeller")
	probe.remove_meta(Inventory.META_GAS_IMMUNE_UNTIL)
	gas.set_active(false)
	check(not gas.apply_tick(probe), "kapatılan gaz (vantilatör) zarar vermez")
	gas.queue_free()
	var mine: Landmine = Landmine.new()
	add_child(mine)
	mine.trigger()
	await get_tree().create_timer(mine.fuse_time + 0.1).timeout
	check(_dmg(probe) == 63, "mayın tık → gecikme → patlama (30)")
	var light: Searchlight = Searchlight.new()
	light.sweep_from_deg = 0.0
	light.sweep_to_deg = 0.0
	add_child(light)
	await get_tree().process_frame
	check(light.is_point_lit(Vector2(0, 120)) and not light.is_point_lit(Vector2(300, 120)), "projektör konisi doğru alanı aydınlatıyor")
	light.queue_free()
	var barrage: ArtilleryBarrage = ArtilleryBarrage.new()
	barrage.active = false
	add_child(barrage)
	check(barrage.fire_salvo(0.0, 4).size() == 4, "topçu salvosu: 4 mermi")
	ChapterState.set_flag(self, ChapterState.FLAG_BATTERY_SILENCED, true)
	var halved: Array[Node2D] = barrage.fire_salvo(0.0, 4)
	check(halved.size() == 2 and int(halved[0].get("damage")) == 11, "Sessiz Batarya topçuyu %50 azaltır (2 mermi, 11 hasar)")
	for n: Node in get_children():
		if n is ArtilleryShell:
			n.queue_free()
	barrage.queue_free()
	var wall: SecretBreakableWall = (load("res://scenes/objects/secret_breakable_wall.tscn") as PackedScene).instantiate() as SecretBreakableWall
	wall.breaking_attack_types = ["heavy", "grenade"]
	add_child(wall)
	wall.global_position = Vector2(2000, 0)
	var grenade: StickGrenade = StickGrenade.new()
	add_child(grenade)
	grenade.global_position = Vector2(2000, -10)
	grenade.detonate()
	check(wall.is_broken, "Saplı El Bombası gizli duvarı kırar")
	wall.queue_free()
	Inventory.add(self, "field_bandage", 2)
	probe.current_health = 50
	check(Inventory.use(self, "field_bandage", probe) and probe.current_health == 90 and Inventory.count(self, "field_bandage") == 1,
		"Askeri Sargı Bezi +40 can, adet düşer")
	probe.current_health = 100
	check(not Inventory.use(self, "field_bandage", probe) and Inventory.count(self, "field_bandage") == 1, "can doluyken sargı harcanmaz")
	check(not Inventory.use(self, "radio_codes", probe), "görev eşyası kullanılamaz")
	check(gs.persistent_events.has("ww2_item|field_bandage"), "eşya adetleri GameState'te (kayda yazılır)")
	probe.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Sahne 1 — Siperler, yaralılar, Mini-Boss 1
# ---------------------------------------------------------------------------
func _test_trenches() -> void:
	gs.reset_state()
	var level: Ww2Stage1BombedTrenches = await _load(L1) as Ww2Stage1BombedTrenches
	level.barrage.active = false
	var spots: Array[RescueSpot] = level.get_spots()
	check(spots.size() == 2, "iki yaralı asker noktası")
	await get_tree().process_frame
	check(not spots[0].interaction_enabled, "muhafız yaşarken yaralıyla konuşulamaz")
	level.get_node("Enemies/Infantry1").take_damage(9999)
	level.get_node("Enemies/Flamer1").take_damage(9999)
	await get_tree().process_frame
	check(spots[0].interaction_enabled, "muhafız ölünce yaralıyla konuşulabilir")
	level.apply_choice("rescue_wounded", spots[0])
	check(spots[0].outcome == "freed" and Inventory.count(level, "field_bandage") == 2 and gs.corruption_score == 0, "Kefaret: yaralı kurtarıldı, +2 sargı bezi")
	level.apply_choice("exploit_wounded", spots[1])
	check(spots[1].outcome == "drained" and gs.corruption_score == 20 and gs.allies_sacrificed_count == 1, "Yozlaşma: yaşam gücü sömürüldü (+20)")
	check(qm.get_quest("ww2_wounded_in_trench").get("status") == "failed", "yan görev: biri sömürülünce başarısız")
	await _skip(level)
	var officer: TrenchOfficer = level.officer
	var player: Node2D = level.player
	officer.facing = -1
	player.global_position = officer.global_position + Vector2(-80, 0)
	player.current_attack_type = "light"
	var hp: int = officer.current_health
	officer.take_damage(100, player)
	check(hp - officer.current_health == 15 and officer.blocked_hits == 1, "Mini-Boss 1: ön zırh hasarı %15'e düşürür")
	player.global_position = officer.global_position + Vector2(80, 0)
	officer.take_damage(40, player)
	check(officer.tank_hp == 30 and not officer.is_groggy(), "arkadan vuruş sırt tankını yıpratır")
	player.global_position = officer.global_position + Vector2(-80, 0)
	player.current_attack_type = "plunge"
	officer.take_damage(40, player)
	check(officer.is_groggy(), "dalış saldırısı tankı patlattı → groggy penceresi")
	hp = officer.current_health
	player.current_attack_type = "light"
	officer.take_damage(100, player)
	check(hp - officer.current_health == 160, "groggy iken hasar katlanır (x1.6)")
	check(not level.can_exit(), "subay yaşarken çıkış kapalı")
	officer.take_damage(9999)
	check(level.can_exit() and level.is_officer_defeated(), "Mini-Boss 1 yenildi → çıkış açık (kalıcı)")
	await _unload(level)


# ---------------------------------------------------------------------------
# Sahne 2 — Şehir, viyadük, Sessiz Batarya
# ---------------------------------------------------------------------------
func _test_viaduct() -> void:
	gs.reset_state()
	var level: Ww2Stage2RuinedCityViaduct = await _load(L2) as Ww2Stage2RuinedCityViaduct
	var radio: FieldRadio = level.get_node("Radios/SabotageRadio") as FieldRadio
	radio.interact()
	check(not ChapterState.is_battery_silenced(level), "kodlar olmadan telsiz sabotajı yapılamaz")
	(level.get_node("Pickups/RadioCodes") as Ww2Pickup).collect()
	check(Inventory.has_item(level, "radio_codes") and _stage_done("ww2_silent_battery", "find_codes"), "Şifreli Telsiz Kodları bulundu")
	await _skip(level)
	radio.interact()
	check(ChapterState.is_battery_silenced(level) and _stage_done("ww2_silent_battery", "sabotage_radio"), "Sessiz Batarya: koordinatlar bozuldu")
	check(ChapterState.artillery_factor(level) == 0.5, "topçu çarpanı %50")
	var scout: Node = level.get_node("Enemies/Scout1")
	check((scout.call_artillery(level.player.global_position.x) as Array).size() == 1, "gözcü işaret fişeği: susturulmuş bataryadan tek mermi")
	await _skip(level)
	(level.get_node("Radios/EchoRadio") as FieldRadio).interact()
	var cm: Node = get_node("/root/CodexManager")
	check(cm.is_unlocked("ww2_broken_frequency"), "easter egg: Kırık Telsiz Frekansı Codex'te açıldı")
	await _skip(level)
	level._on_player_spotted(level.player)
	check(level.reinforcements.size() == 2 and level.reinforcement_waves == 1, "projektör alarmı: 2 takviye")
	level._on_player_spotted(level.player)
	check(level.reinforcement_waves == 1, "takviyeler yaşarken yeni dalga gelmez")
	var car: ArmoredTrainCar = level.get_node("Trains/TrainCarA") as ArmoredTrainCar
	var x0: float = car.position.x
	await get_tree().create_timer(0.3).timeout
	check(car.position.x > x0, "zırhlı tren vagonu viyadükte hareket ediyor")
	await _unload(level)


# ---------------------------------------------------------------------------
# Sahne 3 — Laboratuvar
# ---------------------------------------------------------------------------
func _test_lab() -> void:
	gs.reset_state()
	var level: Ww2Stage3OccultLab = await _load(L3) as Ww2Stage3OccultLab
	var gas: ToxicGas = level.get_node("CorridorGas") as ToxicGas
	check(gas.active and not level.lab_door.is_open, "gaz koridoru aktif, kapı kapalı")
	(level.get_node("Relays/Relay0") as PowerRelay).set_on(true)
	check(not level.relays_solved(), "yanlış röle dizisi çözüm saymaz")
	(level.get_node("Relays/Relay2") as PowerRelay).set_on(true)
	check(level.relays_solved() and not gas.active and level.lab_door.is_open, "röle bulmacası: gaz kesildi, kapı açıldı")
	await _skip(level)
	level.get_node("Enemies/Sapper1").take_damage(9999)
	level.get_node("Enemies/Infantry2").take_damage(9999)
	await get_tree().process_frame
	var cell_a: RescueSpot = level.get_node("Prisoners/CellA") as RescueSpot
	var cell_b: RescueSpot = level.get_node("Prisoners/CellB") as RescueSpot
	level.apply_choice("free_prisoner", cell_a)
	check(ChapterState.has_flag(level, ChapterState.FLAG_BACKDOOR_KEY) and Inventory.has_item(level, "bunker_keycard") and Inventory.has_item(level, "prisoner_tags"),
		"esir kurtarıldı → arka kapı kartı + künye")
	level.apply_choice("sacrifice_prisoner", cell_b)
	check(ChapterState.reactor_sacrifices(level) == 1 and gs.corruption_score == 20, "reaktöre feda: +20 Yozlaşma, kurban sayacı")
	check(level.get_exit_story_key() == "ww2_lab_exit_corrupted", "çıkış anlatımı seçime göre değişiyor")
	await _skip(level)
	(level.get_node("SecretBreakableWall") as SecretBreakableWall).take_damage(80, StickGrenade.new())
	(level.get_node("Interactables/Blueprint") as LoreRelic).interact()
	check(get_node("/root/CodexManager").is_unlocked("ww2_future_blueprint") and Inventory.has_item(level, "phosphor_flare"),
		"easter egg: Geleceğin Damgası Planları (Codex + bonus)")
	await _skip(level)
	var seal: OccultSeal = level.get_node("Interactables/OccultSeal") as OccultSeal
	seal.interact()
	check(not seal.is_open, "Kalp Rezonansı olmadan okült mühür açılmaz")
	await _skip(level)
	gs.unlock_ability("heart_resonance")
	seal.interact()
	check(seal.is_open, "Kalp Rezonansı okült mührü açıyor")
	await _skip(level)
	var lab: RefCounted = level.boss
	lab.start()
	await _skip(level)
	var doctor: OccultDoctor = lab.doctor
	var beast: FailedExperiment = lab.beast
	check(doctor.is_active and beast.is_active, "Mini-Boss 2: çift hedef aktif")
	var hp: int = doctor.current_health
	doctor.take_damage(60)
	check(doctor.current_health == hp and doctor.shielded, "tüpler sağlamken okült kalkan hasarı engeller")
	for tube: Node in level.find_children("*", "EnergyTube", true, false):
		(tube as EnergyTube).take_damage(999)
	check(not doctor.shielded, "tüm enerji tüpleri kırılınca kalkan iner")
	await _skip(level)
	doctor.take_damage(60)
	check(doctor.current_health == hp - 60, "kalkansız Başhekim hasar alır")
	var wall_x: float = lab.wall_left.position.x
	beast.slam()
	await get_tree().create_timer(0.5).timeout
	check(lab.wall_left.position.x > wall_x and lab.shrink_steps == 1, "Deney yere vurunca arena daralıyor")
	doctor.take_damage(9999)
	check(beast.enraged and not lab.is_cleared(), "Başhekim ölünce Deney öfkeleniyor")
	check(not level.can_exit(), "mini-bosslar yaşarken çıkış kapalı")
	beast.take_damage(9999)
	check(lab.is_cleared() and level.can_exit() and lab.wall_left.position.x == wall_x, "ikisi de yenildi → arena açıldı, çıkış serbest")
	await _unload(level)


# ---------------------------------------------------------------------------
# Sahne 4 — Cani Komutan (3 form)
# ---------------------------------------------------------------------------
func _test_boss(route: String, corruption: int) -> void:
	gs.reset_state()
	gs.corruption_score = corruption
	var level: Ww2Stage4CommandBunker = await _load(L4) as Ww2Stage4CommandBunker
	level.next_scene_path = ""
	ChapterState.set_flag(level, ChapterState.FLAG_BATTERY_SILENCED, route == "redemption")
	for stage: String in ["cross_trenches", "cross_viaduct", "infiltrate_lab"]:
		qm.advance_quest("ww2_iron_heart", stage)
	var boss: CommanderBoss = level.boss
	check(level.dialogue_state == "intro" and not boss.is_active, "[%s] karşılama diyaloğu sürerken boss bekliyor" % route)
	await _skip(level)
	check(boss.is_active and boss.form == 1, "[%s] Form 1 (Demir Komutan) başladı" % route)
	var player: Node2D = level.player
	var muzzle: Vector2 = Vector2(1250, 470)
	player.global_position = Vector2(820, 560)
	var hit: Node = Attacks.resolve_sniper(level, muzzle, muzzle + (Vector2(820, 536) - muzzle) * 10.0)
	check(hit is SandbagCover, "[%s] keskin nişancı atışını kum torbası siperi yuttu" % route)
	player.global_position = Vector2(1100, 560)
	hit = Attacks.resolve_sniper(level, muzzle, muzzle + (Vector2(1100, 536) - muzzle) * 10.0)
	check(hit == player, "[%s] siper yokken nişan çizgisindeki oyuncu vurulur" % route)
	var before: int = level.find_children("*", "ArtilleryShell", true, false).size()
	boss.artillery_requested.emit(4)
	var fired: int = level.find_children("*", "ArtilleryShell", true, false).size() - before
	check(fired == (2 if route == "redemption" else 4), "[%s] telsiz topçu çağrısı: %d mermi (Sessiz Batarya etkisi)" % [route, fired])
	boss.take_damage(int(boss.max_health * 0.36))
	await get_tree().create_timer(1.0).timeout
	check(boss.form == 2 and level.dialogue_state == "form" and boss.anim.sprite_frames.resource_path.contains("form2"), "[%s] Form 2: sheet değişti, taunt" % route)
	await _skip(level)
	player.current_attack_type = "light"
	var hp: int = boss.current_health
	boss.take_damage(100, player)
	check(hp - boss.current_health == 20 and boss.shield_poise == 92.0, "[%s] duruş kalkanı hasarı %%20'ye düşürür" % route)
	boss.on_parried()
	player.current_attack_type = "heavy"
	boss.take_damage(10, player)
	boss.take_damage(10, player)
	check(boss.state == CommanderBoss.State.GROGGY, "[%s] savuşturma + ağır vuruş kalkanı kırar → groggy" % route)
	boss.turret_support_requested.emit(true)
	check((level.get_node("Turrets/TurretL") as BunkerTurret).active, "[%s] taret desteği etkin" % route)
	level.set_turrets_active(false)
	boss.current_health = int(boss.max_health * 0.34)
	boss.take_damage(20)
	await get_tree().create_timer(1.0).timeout
	check(boss.form == 3 and boss.hovering and boss.anim.sprite_frames.resource_path.contains("form3"), "[%s] Form 3 (Çöken Çekirdek): süzülme" % route)
	await _skip(level)
	(level.get_node("Pillars/Pillar0") as EnergyTube).take_damage(999)
	check(boss.state == CommanderBoss.State.GROGGY and not boss.hovering, "[%s] enerji sütunu kırılınca boss yere çakılıp sersemler" % route)
	boss.arena_shrink_requested.emit(60.0)
	check(level.shrink_total == 60.0 and level.shrink_left.visible, "[%s] arena sınırları daralıyor" % route)
	boss.summon_requested.emit(2)
	await get_tree().create_timer(0.8).timeout
	check(level.minions.size() == 2, "[%s] deney askerleri çağrıldı" % route)
	player.global_position = Vector2(900, 560)
	check(Attacks.beam_hit(level, Vector2(900, 300), Vector2(900, 700)), "[%s] çapraz okült ışın oyuncuya isabet eder" % route)
	boss.take_damage(99999)
	check(boss.is_dead and boss.state == CommanderBoss.State.DYING and not level.boss_defeated, "[%s] özel ölüm sekansı başladı" % route)
	await get_tree().create_timer(boss.death_sequence_time + 1.8).timeout
	check(level.boss_defeated and int(gs.current_heart_pieces) >= 4, "[%s] Komutan yenildi, 4. Kalp Parçası alındı" % route)
	check(_stage_done("ww2_iron_heart", "defeat_commander") and _stage_done("ww2_iron_heart", "claim_heart"), "[%s] ana görev aşamaları" % route)
	check(level.dialogue_state == "last_words" and level.minions.all(func(m: Variant) -> bool: return not is_instance_valid(m) or bool(m.is_dead)),
		"[%s] son sözler, kalan deneyler temizlendi" % route)
	await _unload(level)


# ---------------------------------------------------------------------------
# Sahne 5 — Anı Kırılması ve bölüm sonu
# ---------------------------------------------------------------------------
func _test_finale(route: String, corruption: int) -> void:
	gs.reset_state()
	gs.corruption_score = corruption
	var level: Ww2Stage5MemoryRift = await _load(L5) as Ww2Stage5MemoryRift
	await get_tree().create_timer(0.8).timeout
	check(level.dialogue_state == "intro", "[%s] Anı Kırılması girişi" % route)
	await _skip(level)
	check(level.flashback.is_playing() and level.flashback.memory_key == "ww2_memory_flashback", "[%s] 4. Anı Kırılması flashback'i tetiklendi" % route)
	level.flashback.skip_flashback()
	check(gs.has_ability("vengeance_vow_aura") and level.dialogue_state == "evolution", "[%s] İntikam Yemini açıldı, kılıç evrimi" % route)
	var aura: Node = level.player.get_node_or_null("SwordVowAura")
	check(aura != null and aura.is_glowing() and level.player.get_node_or_null("SwordSealLeak") != null and level.hud.get_node_or_null("SealWeakenedBadge") != null,
		"[%s] kızıl-altın aura + çatlak sızıntısı + HUD rozeti" % route)
	await _skip(level)
	check(level.dialogue_state == "outro" and gs.get_recorded_ending() == route and level.exit_rift.visible, "[%s] outro ve Bölüm 5 zaman yırtığı" % route)
	await _skip(level)
	check(gs.is_chapter_completed("chapter_4") and get_node("/root/SaveManager").is_chapter_unlocked(5), "[%s] Bölüm 4 tamamlandı" % route)
	await get_tree().create_timer(2.2).timeout
	check(level.get_node_or_null("ResultsScreen") != null, "[%s] sonuç ekranı açıldı" % route)
	await _unload(level)


# ---------------------------------------------------------------------------
# Kefaret / Yozlaşma uçtan uca kayıt-yükleme
# ---------------------------------------------------------------------------
func _test_save_load() -> void:
	var sm: Node = get_node("/root/SaveManager")
	var backups: Dictionary = _backup_slot(TEST_SLOT)
	var prev_slot: int = int(sm.active_slot)
	gs.reset_state()
	var level: Ww2Stage1BombedTrenches = await _load(L1) as Ww2Stage1BombedTrenches
	level.barrage.active = false
	level.get_node("Enemies/Infantry1").take_damage(9999)
	level.get_node("Enemies/Flamer1").take_damage(9999)
	await get_tree().process_frame
	var spots: Array[RescueSpot] = level.get_spots()
	level.apply_choice("rescue_wounded", spots[0])
	spots[1].get_npc().take_damage(999)
	(level.get_node("Pickups/Grenades") as Ww2Pickup).collect()
	await _skip(level)
	var corruption: int = gs.corruption_score
	check(spots[1].outcome == "killed" and corruption == 12, "masum öldürüldü: +12 Yozlaşma")
	check(sm.save_game(TEST_SLOT), "kayıt alındı (yuva %d)" % TEST_SLOT)
	await _unload(level)
	gs.reset_state()
	check(gs.persistent_events.is_empty() and gs.corruption_score == 0, "durum sıfırlandı")
	check(sm.load_game(TEST_SLOT), "kayıt yüklendi")
	check(gs.corruption_score == corruption and ChapterState.get_outcome(self, "wounded", "wounded_a") == "freed"
		and ChapterState.get_outcome(self, "wounded", "wounded_b") == "killed", "Kefaret/Yozlaşma sonuçları ve puanı geri geldi")
	check(Inventory.count(self, "stick_grenade") == 2 and Inventory.count(self, "field_bandage") == 2, "WW2 envanteri geri geldi")
	var reloaded: Ww2Stage1BombedTrenches = await _load(L1, true) as Ww2Stage1BombedTrenches
	var rs: Array[RescueSpot] = reloaded.get_spots()
	check(rs[0].is_resolved() and rs[1].is_resolved() and not rs[0].get_npc().visible, "yeniden yüklenen sahnede seçimler kalıcı")
	check(reloaded.get_node_or_null("Pickups/Grenades") == null or (reloaded.get_node("Pickups/Grenades") as Ww2Pickup).is_collected,
		"toplanan eşya (WorldObjectState) tekrar çıkmıyor")
	await _unload(reloaded)
	_restore_slot(TEST_SLOT, backups)
	sm.active_slot = prev_slot
	sm.save_settings() # kayıt testi kullanıcının aktif yuva ayarını değiştirmesin


func _slot_files(slot: int) -> Array[String]:
	return ["user://savegame_slot_%d.json" % slot, "user://savegame_slot_%d_backup.json" % slot, "user://savegame_slot_%d_tmp.json" % slot]


func _backup_slot(slot: int) -> Dictionary:
	var saved: Dictionary = {}
	for path: String in _slot_files(slot):
		saved[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return saved


func _restore_slot(slot: int, saved: Dictionary) -> void:
	for path: String in _slot_files(slot):
		var data: Variant = saved.get(path)
		if data == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			f.store_buffer(data as PackedByteArray)
			f.close()
