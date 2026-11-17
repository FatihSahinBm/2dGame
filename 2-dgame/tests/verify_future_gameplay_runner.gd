extends Node

## res://tests/verify_future_gameplay_runner.gd
## Bölüm 5 oynanış doğrulaması (Epic 2D-158) — mekanikler ve bosslar:
## lazer siper kuralı (CyberLaserSystem RayCast2D) + Kan Sisi + Faz Kalkanı, lazer kapısı, hidrolik pres,
## plazma kanalı, konveyör, zaman alanları, EMP/plazma, eşyalar, standart düşman kuralları,
## Krono-Muhafız (zırh/soğutma hücresi/dalış), AEGIS-09 (dron kalkanı/EMP), 3 formlu AI Lord
## (faz geçişleri, Siber-Ağ Kesintisi sabotajı, enerji kalkanı, yankı, zaman dondurma, ölüm sekansı).
## Çalıştırma: Godot --headless --path . res://tests/verify_future_gameplay.tscn

const U = preload("res://tests/future_test_utils.gd")
const ChapterState = preload("res://scripts/components/future_chapter_state.gd")
const Inventory = preload("res://scripts/components/future_inventory.gd")
const LordAttacks = preload("res://scripts/enemies/future/ai_lord_attacks.gd")
const EN: String = "res://scenes/enemies/future/"

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
	print("--- FUTURE CHAPTER (2D-158) GAMEPLAY ---")
	gs = get_node("/root/GameState")
	gs.reset_state()
	gs.persistent_events.clear()
	await _test_lasers()
	await _test_factory_hazards()
	await _test_items_and_emp()
	await _test_enemies()
	await _test_warden()
	await _test_aegis()
	await _test_ai_lord()
	gs.reset_state()
	print("--- RESULT: %d passed, %d failed ---" % [passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _frames(n: int = 3) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _clear() -> void:
	for c: Node in get_children():
		c.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Lazerler: siper kuralı, Kan Sisi, Faz Kalkanı, lazer kapısı, terminal
# ---------------------------------------------------------------------------
func _test_lasers() -> void:
	var p: CharacterBody2D = U.probe(self, Vector2(300, 0))
	var trap: FutureLaserTrap = FutureLaserTrap.new()
	trap.idle_time = 99.0
	add_child(trap)
	trap.global_position = Vector2(0, -20)
	var cover: StaticBody2D = U.wall(self, Vector2(150, -20), Vector2(24, 90))
	await _frames()
	trap.fire()
	await _frames(4)
	check(U.dmg(p) == 0 and trap.laser.current_actual_range < 160.0, "tarama lazeri: siper bloğu ışını keser (RayCast2D), arkadaki oyuncu güvende")
	await get_tree().create_timer(trap.laser.blast_duration + 0.1).timeout
	cover.queue_free()
	await _frames()
	trap.fire()
	await _frames(4)
	check(U.dmg(p) == trap.damage, "tarama lazeri: siper yoksa enerji hasarı (%d)" % U.dmg(p))
	await get_tree().create_timer(trap.laser.blast_duration + 0.1).timeout
	p.set_meta(Inventory.META_PHASE_UNTIL, Time.get_ticks_msec() + 5000)
	trap.fire()
	await _frames(4)
	check(U.dmg(p) == trap.damage + trap.damage / 2, "Faz Kalkanı Kapsülü lazer hasarını yarıya indirir")
	p.remove_meta(Inventory.META_PHASE_UNTIL)
	await get_tree().create_timer(trap.laser.blast_duration + 0.1).timeout
	p.is_blood_mist_dashing = true
	var before: int = U.dmg(p)
	trap.fire()
	await _frames(4)
	check(U.dmg(p) == before, "Kan Sisi Atılması lazer ışınından hasarsız geçer")
	p.is_blood_mist_dashing = false
	trap.set_powered(false)
	check(not trap.is_active(), "EMP terminali / güç kesintisi tarama lazerini kapatır")
	trap.queue_free()
	var gate: LaserGate = LaserGate.new()
	gate.cycle_off = 0.0
	gate.beam_length = 260.0
	add_child(gate)
	gate.global_position = Vector2(300, -240)
	before = U.dmg(p)
	await _frames(4)
	check(U.dmg(p) == before + gate.damage, "lazer kapısı: ışındaki oyuncu yanar (%d)" % gate.damage)
	var shield_wall: StaticBody2D = U.wall(self, Vector2(300, -120), Vector2(60, 16))
	await get_tree().create_timer(0.7).timeout
	before = U.dmg(p)
	await _frames(4)
	check(U.dmg(p) == before and gate.current_length < 130.0, "lazer kapısı da aynı siper kuralını kullanır (ışın engelde kesilir)")
	shield_wall.queue_free()
	var term: EmpTerminal = (load("res://scenes/objects/future/obj_emp_terminal.tscn") as PackedScene).instantiate() as EmpTerminal
	add_child(term)
	term.linked_paths = [term.get_path_to(gate)]
	term.interact()
	await get_tree().create_timer(0.7).timeout
	before = U.dmg(p)
	await _frames(4)
	check(term.is_hacked and not gate.is_active() and U.dmg(p) == before, "EMP terminali hacklenince lazer kapısı söner")
	await _clear()


# ---------------------------------------------------------------------------
# Fabrika: pres, plazma kanalı, konveyör, zaman alanları
# ---------------------------------------------------------------------------
func _test_factory_hazards() -> void:
	var p: CharacterBody2D = U.probe(self, Vector2(0, 0))
	var press: HydraulicPress = HydraulicPress.new()
	press.up_time = 0.05
	press.warn_time = 0.05
	add_child(press)
	press.global_position = Vector2(0, -150)
	press.travel = 135.0
	await get_tree().create_timer(0.45).timeout
	check(U.dmg(p) == press.damage, "hidrolik pres: uyarı ışığı -> ezme hasarı (%d)" % U.dmg(p))
	press.on_emp(5.0)
	check(not press.is_running(), "EMP presi havada kilitler")
	press.queue_free()
	var plasma: PlasmaChannel = PlasmaChannel.new()
	plasma.idle_time = 0.05
	plasma.burst_time = 1.0
	add_child(plasma)
	plasma.global_position = Vector2(0, 0)
	var before: int = U.dmg(p)
	await get_tree().create_timer(0.3).timeout
	check(U.dmg(p) == before + plasma.damage, "plazma kanalı püskürmesi enerji hasarı verir")
	plasma.queue_free()
	var belt: ConveyorBelt = (load("res://scenes/objects/future/obj_conveyor_belt.tscn") as PackedScene).instantiate() as ConveyorBelt
	add_child(belt)
	var term: EmpTerminal = (load("res://scenes/objects/future/obj_emp_terminal.tscn") as PackedScene).instantiate() as EmpTerminal
	term.mode = "reverse"
	add_child(term)
	term.linked_paths = [term.get_path_to(belt)]
	var v0: float = belt.get_surface_velocity().x
	term.interact()
	check(v0 > 0.0 and belt.get_surface_velocity().x == -v0, "kontrol terminali konveyör yönünü tersine çevirir")
	belt.set_powered(false)
	check(belt.get_surface_velocity() == Vector2.ZERO, "güçsüz konveyör durur")
	var slow: TimeSlowField = TimeSlowField.new()
	slow.size = Vector2(200, 200)
	add_child(slow)
	slow.global_position = Vector2(0, 50)
	await _frames(4)
	check(is_equal_approx(p.speed, 200.0 * slow.factor), "zaman yavaşlatma cebi oyuncu hızını düşürür (%.0f)" % p.speed)
	slow.dispose()
	await _frames(2)
	check(is_equal_approx(p.speed, 200.0), "alandan çıkınca hız geri gelir")
	var fast: TimeSlowField = TimeSlowField.new()
	fast.mode = "fast"
	fast.factor = 0.7
	fast.size = Vector2(200, 200)
	add_child(fast)
	fast.global_position = Vector2(0, 50)
	await _frames(4)
	check(p.speed > 200.0, "kırmızı zaman alanı hızlandırır (%.0f)" % p.speed)
	fast.dispose()
	await _clear()


# ---------------------------------------------------------------------------
# Eşyalar, EMP ve plazma
# ---------------------------------------------------------------------------
func _test_items_and_emp() -> void:
	gs.persistent_events.clear()
	var p: CharacterBody2D = U.probe(self, Vector2(-400, 0))
	Inventory.add(self, "nano_repair_kit", 2)
	p.current_health = 30
	check(Inventory.use(self, "nano_repair_kit", p) and p.current_health == 90 and Inventory.count(self, "nano_repair_kit") == 1,
		"Nano-Tamir Kiti +60 can, adet düşer")
	p.current_health = 100
	check(not Inventory.use(self, "nano_repair_kit", p), "can doluyken kit harcanmaz")
	Inventory.add(self, "chrono_injector", 1)
	check(Inventory.use(self, "chrono_injector", p) and is_equal_approx(p.speed, 260.0), "Krono-Enjektör hareket hızını +%30 artırır")
	Inventory.add(self, "core_access_chip", 1)
	check(not Inventory.use(self, "core_access_chip", p), "görev eşyası kullanılamaz")
	var enforcer: Node = U.instance(self, EN + "cyber_enforcer.tscn", Vector2(0, 0))
	U.wall(self, Vector2(0, 30), Vector2(2000, 60))
	var gate: LaserGate = LaserGate.new()
	add_child(gate)
	gate.global_position = Vector2(30, -60)
	await _frames(2)
	var hp0: int = int(enforcer.current_health)
	var emp: EmpGrenade = EmpGrenade.new()
	add_child(emp)
	emp.global_position = Vector2(10, -10)
	emp.detonate()
	check(int(enforcer.current_health) == hp0 - emp.damage * 2, "EMP mekanik düşmana çift hasar (%d -> %d)" % [hp0, int(enforcer.current_health)])
	check(enforcer.current_state == enforcer.State.HURT and not gate.is_active(), "EMP sersemletir ve lazer kapısını kapatır")
	var a: Node = U.instance(self, EN + "cyber_hound.tscn", Vector2(200, 0))
	var b: Node = U.instance(self, EN + "cyber_hound.tscn", Vector2(320, 0))
	await _frames(2)
	var bolt: PlasmaBolt = PlasmaBolt.new()
	add_child(bolt)
	bolt.global_position = Vector2(120, -20)
	await get_tree().create_timer(0.5).timeout
	check(int(a.current_health) < 75 and int(b.current_health) < 75, "Plazma Kesici Fişek düşmanları delip geçer")
	await _clear()


func _test_enemies() -> void:
	var p: CharacterBody2D = U.probe(self, Vector2(-80, 0))
	var enf: Node = U.instance(self, EN + "cyber_enforcer.tscn", Vector2(0, 0))
	enf.direction = -1
	await _frames(2)
	var hp0: int = int(enf.current_health)
	p.current_attack_type = "light"
	enf.take_damage(20)
	check(int(enf.current_health) == hp0 and enf.blocked_hits == 1, "Devriye Androidi önden hafif darbeyi kalkanla keser")
	p.current_attack_type = "heavy"
	enf.take_damage(20)
	check(int(enf.current_health) == hp0 - 20, "ağır saldırı kalkanı aşar")
	p.current_attack_type = "light"
	p.global_position = Vector2(80, 0)
	enf.take_damage(10)
	check(int(enf.current_health) == hp0 - 30, "arkadan saldırı kalkanı aşar")
	var jug: Node = U.instance(self, EN + "hydraulic_juggernaut.tscn", Vector2(600, 0))
	await _frames(2)
	jug.take_damage(10)
	check(jug.current_state != jug.State.HURT, "Hidrolik Yıkıcı darbelerle sendelemez (yüksek poise)")
	jug._piston_impact()
	check(get_tree().get_nodes_in_group("future_shock_waves").size() >= 2, "piston darbesi iki yöne şok dalgası yayar")
	var drone: Node = U.instance(self, EN + "chrono_drone.tscn", Vector2(-300, -100))
	await _frames(2)
	var field: Area2D = drone.cast_pulse(Vector2(-300, 0))
	check(field is TimeSlowField and drone.is_in_group("mechanical"), "Zaman-Bükücü Dron yavaşlatma alanı atar")
	var hound: Node = U.instance(self, EN + "cyber_hound.tscn", Vector2(-600, 0))
	await _frames(2)
	hound.pounce(1.0)
	check(hound.velocity.x > 0.0 and hound.velocity.y < 0.0, "Mekanik Tazı oyuncuya sıçrar")
	var bug: Node = U.instance(self, EN + "cyber_flying_bug_prime.tscn", Vector2(-800, -120))
	await _frames(2)
	check(bug is CyberFlyingBug and bug.is_in_group("mechanical") and (bug.get_node("Visual/AnimatedSprite2D") as AnimatedSprite2D).sprite_frames.resource_path.contains("prime"),
		"Gelişmiş Siber Uçan Böcek: Bölüm 1 böcek yapay zekâsı + neon zırhlı yeni kareler")
	await _clear()


# ---------------------------------------------------------------------------
# Mini-Boss 1: Krono-Muhafız
# ---------------------------------------------------------------------------
func _test_warden() -> void:
	var p: CharacterBody2D = U.probe(self, Vector2(-120, 0))
	var w: ChronoWarden = U.instance(self, EN + "chrono_warden_mech.tscn", Vector2(0, 0)) as ChronoWarden
	w.facing = -1
	w.arena_bounds = Vector2(-800, 800)
	await _frames(2)
	var hp0: int = w.current_health
	p.current_attack_type = "light"
	w.take_damage(30, p)
	check(w.current_health == hp0 and w.blocked_hits == 1, "Krono-Muhafız önden zırhla darbeyi engeller")
	p.global_position = Vector2(120, 0)
	w.take_damage(30, p)
	check(w.state == w.State.GROGGY and w.current_health == hp0 - 30, "sırttaki soğutma hücresine vuruş groggy penceresi açar")
	w.state = w.State.MOVE
	p.global_position = Vector2(-120, 0)
	p.current_attack_type = "plunge"
	w.take_damage(30, p)
	check(w.state == w.State.GROGGY, "dalış saldırısı (plunge) da groggy açar")
	var hp1: int = w.current_health
	p.current_attack_type = "light"
	w.take_damage(30, p)
	check(w.current_health == hp1 - 42, "groggy sırasında hasar x1.4")
	w.is_active = true
	w.start_attack("stomp")
	await get_tree().create_timer(0.7).timeout
	check(get_tree().get_nodes_in_group("future_shock_waves").size() >= 2, "zamansal ezme şok dalgası yayar")
	p.global_position = Vector2(120, 0)
	w.take_damage(9999, p)
	check(w.is_dead, "Krono-Muhafız arkadan vuruşla yenilir")
	await _clear()


# ---------------------------------------------------------------------------
# Mini-Boss 2: AEGIS-09
# ---------------------------------------------------------------------------
func _test_aegis() -> void:
	U.probe(self, Vector2(-200, 0))
	var holder: Node2D = Node2D.new()
	add_child(holder)
	var d0: AegisDrone = U.instance(holder, EN + "aegis_drone.tscn", Vector2(-80, -80)) as AegisDrone
	var d1: AegisDrone = U.instance(holder, EN + "aegis_drone.tscn", Vector2(80, -80)) as AegisDrone
	var core: AegisCore = (load(EN + "aegis_core.tscn") as PackedScene).instantiate() as AegisCore
	holder.add_child(core)
	core.ground_y = 0.0
	core.on_cinematic_ended()
	await _frames(3)
	check(core.drones.size() == 2 and core.shield_up, "AEGIS çekirdeği iki dronu sahiplendi, kalkan aktif")
	var hp0: int = core.current_health
	core.take_damage(50)
	check(core.current_health == hp0, "kalkan aktifken çekirdek hasar almaz")
	d0.die()
	d1.die()
	await _frames(2)
	check(core.is_exposed() and not core.shield_up, "iki dron düşünce kalkan çöker (overheat_exposed)")
	core.take_damage(40)
	check(core.current_health == hp0 - 50, "açıktaki çekirdek x1.25 hasar alır")
	core._expose_until = 0
	await _frames(3)
	check(core.shield_up and core.alive_feeding_drones() == 2, "ısınma bitince kalkan ve dronlar yeniden kurulur")
	var emp: EmpGrenade = EmpGrenade.new()
	holder.add_child(emp)
	emp.global_position = core.global_position
	emp.detonate()
	check(core.is_exposed(), "EMP El Bombası kalkanı düşürür")
	core.take_damage(9999)
	check(core.is_dead, "AEGIS-09 yenilir; dronları da düşer")
	await _clear()


# ---------------------------------------------------------------------------
# AI Lord: 3 form, sabotaj, kalkan, yankı, dondurma, ölüm sekansı
# ---------------------------------------------------------------------------
func _test_ai_lord() -> void:
	gs.persistent_events.clear()
	var p: CharacterBody2D = U.probe(self, Vector2(-300, 0))
	var lord: AiLordBoss = (load(EN + "ai_lord.tscn") as PackedScene).instantiate() as AiLordBoss
	lord.ground_y = 0.0
	lord.arena_bounds = Vector2(-800, 800)
	add_child(lord)
	await _frames(2)
	var requested: Array[int] = []
	lord.drones_requested.connect(func(c: int) -> void: requested.append(c))
	var turrets: Array[int] = []
	lord.turret_support_requested.connect(func(c: int, on: bool) -> void:
		if on:
			turrets.append(c)
	)
	check(lord.form == 1 and lord.anim.sprite_frames.resource_path.contains("sovereign") and lord.hovering, "Form 1: Algoritmik Hükümdar (süzülür)")
	lord.on_cinematic_ended()
	lord._execute("drones")
	check(requested == [4], "Form 1 dron çağrısı: 4 dron")
	for id: String in ["node_a", "node_b", "node_c"]:
		ChapterState.mark_node_destroyed(self, id)
	lord._execute("drones")
	check(requested == [4, 2] and LordAttacks.turret_count(self) == 2, "Siber-Ağ Kesintisi: dron çağrısı ve taret desteği %50 azalır")
	var lines: Array[Line2D] = LordAttacks.lattice(lord, lord.arena_bounds, 0.0, 10, 0)
	check(lines.size() == 3 and lines[0].default_color.r > 0.9 and lines[0].default_color.g < 0.3, "lazer ağı kırmızı Line2D nişan çizgileriyle telegraph edilir")
	lord.take_damage(int(lord.max_health * 0.36), p)
	check(lord.form == 2 and lord.state == lord.State.TRANSITION, "can %66'nın altına inince Form 2 geçişi")
	await get_tree().create_timer(1.1).timeout
	check(lord.anim.sprite_frames.resource_path.contains("titan") and not lord.hovering, "Form 2: Ağır Sibernetik Titan sheet'i")
	var tex: Image = lord.anim.sprite_frames.get_frame_texture(&"idle", 0).get_image()
	var bottom: int = 0
	for y: int in tex.get_height():
		for x: int in range(0, tex.get_width(), 2):
			if tex.get_pixel(x, y).a > 0.3:
				bottom = y
				break
	var feet: float = lord.anim.position.y + (float(bottom + 1) - tex.get_height() * 0.5) * lord.anim.scale.y
	check(absf(feet) <= 4.0, "Form 2 sheet'i FEET_Y çıpasına yeniden hizalandı (sapma %.1f px)" % feet)
	lord.on_cinematic_ended()
	lord._execute("turrets")
	check(turrets == [2], "Form 2 taret desteği (kesinti sonrası 2)")
	var hp2: int = lord.current_health
	p.current_attack_type = "light"
	lord.take_damage(50, p)
	check(lord.current_health == hp2 - 10, "enerji kalkanı hafif darbeyi %20'ye düşürür")
	lord.on_parried()
	lord.on_parried()
	check(lord.state == lord.State.GROGGY, "savuşturma enerji kalkanını kırar (groggy)")
	lord.take_damage(lord.current_health - int(lord.max_health * 0.30), p)
	check(lord.form == 3, "can %33'ün altına inince Form 3")
	await get_tree().create_timer(1.1).timeout
	check(lord.anim.sprite_frames.resource_path.contains("singularity"), "Form 3: Çekirdek Tekilliği sheet'i")
	lord.on_cinematic_ended()
	lord._execute("echo")
	lord._execute("freeze")
	await _frames(2)
	check(get_tree().get_nodes_in_group("ai_lord_echoes").size() == 1, "dijital yankı klonu oyuncunun hareketini taklit eder")
	check(get_tree().get_nodes_in_group("future_time_fields").size() >= 1, "zaman dondurma alanı oluşur")
	var cross: Array[Line2D] = LordAttacks.cross_beams(lord, lord.global_position + Vector2(0, -120), lord.arena_bounds, 0.0, 10)
	check(cross.size() == 3, "çapraz çekirdek ışınları")
	var defeated: Array[bool] = [false]
	lord.boss_defeated.connect(func() -> void: defeated[0] = true)
	lord.take_damage(99999, p)
	check(lord.is_dead and lord.anim.animation == &"collapse_death" and not defeated[0], "can 0: özel çöküş ölüm sekansı oynar")
	await get_tree().create_timer(2.6).timeout
	check(defeated[0] and get_tree().get_nodes_in_group("ai_lord_echoes").filter(func(e: Node) -> bool: return not e.is_queued_for_deletion() and not e.is_dead).is_empty(),
		"ölüm sekansı sonunda boss_defeated; yankılar dağılır")
	await _clear()
