extends SceneTree

## res://verify_stoneage_qa_feedback.gd
## Taş Devri QA Geri Bildirimi Regresyon Testleri
## 2D-101: "Mağara adamlarıyla diyalogda savaşmayı seçince oyun çöküyor, her birinde oluyor."
## 2D-136: "Uçan böceğin arkasından kırmızı lazer çıkıyor saldırıdan önce."

const CAVEMAN_SCENE: String = "res://scenes/characters/caveman.tscn"
const PLAYER_SCENE: String = "res://scenes/combat/test_player.tscn"  # Bölümlerdeki gerçek oyuncu (CombatPlayer)
const DIALOGUE_SCENE: String = "res://scenes/ui/dialogue_box.tscn"
const BUG_SCENE: String = "res://scenes/enemies/cyber_flying_bug.tscn"
const STORY_LOADER: String = "res://scripts/autoloads/story_data_loader.gd"
const PLAYER_POS: Vector2 = Vector2(100.0, 300.0)
const CAVEMAN_POS: Vector2 = Vector2(180.0, 300.0)
const HIT_DAMAGE: int = 30
const AIM_TOLERANCE_PX: float = 2.0
const ZOOM_SETTLE_SEC: float = 0.6  # Diyalog kamera tween'i 0.45 sn sürer
## sahne -> [sprite seti klasörü, scriptin çağırdığı animasyonlar]
const SPRITE_SETS: Dictionary = {
	"res://scenes/enemies/raptor.tscn": ["raptor", ["idle", "walk", "run", "attack_bite", "hurt", "death"]],
	BUG_SCENE: ["cyber_bug", ["idle", "walk", "attack", "hit", "death"]],
	CAVEMAN_SCENE: ["caveman", ["idle", "walk", "attack", "hurt", "death"]],
}

var _total: int = 0
var _passed: int = 0
var _player: CharacterBody2D = null
var _box: CanvasLayer = null


func _init() -> void:
	_run_async()


func _run_async() -> void:
	print("\n=== [TEST BAŞLANGICI] Taş Devri QA Geri Bildirimi (2D-101 & 2D-136) ===")
	await process_frame
	# Oyuncu ve diyalog kutusu tüm testlerde ortak; zemin olmadığı için oyuncu fiziği kapalı.
	_player = _spawn(PLAYER_SCENE, PLAYER_POS) as CharacterBody2D
	_box = _spawn(DIALOGUE_SCENE) as CanvasLayer
	await process_frame
	_player.set_physics_process(false)

	await _test_player_hits_hostile_cavemen()
	await _test_player_hits_npc_caveman()
	await _test_dialogue_choice("start_fight", 1, "caveman_fight_shout")
	await _test_dialogue_choice("accept_quest", 0, "caveman_quest_accept")
	await _test_bug_aim_line_points_at_target()
	await _test_bug_recovers_flight_anim_after_hit()
	await _test_dedicated_sprites()

	await _cleanup([_box, _player])
	print("\n=== SONUÇ: %d/%d Başarılı ===" % [_passed, _total])
	quit(0 if _passed == _total else 1)


func _check(ok: bool, label: String, detail: String = "") -> void:
	_total += 1
	if ok:
		_passed += 1
		print("✅ TEST %d GEÇTİ: %s" % [_total, label])
	else:
		print("❌ TEST %d BAŞARISIZ: %s %s" % [_total, label, detail])


func _spawn(scene_path: String, pos: Vector2 = Vector2.ZERO) -> Node:
	var scene: PackedScene = load(scene_path) as PackedScene
	var node: Node = scene.instantiate()
	if node is Node2D:
		(node as Node2D).position = pos
	root.add_child(node)
	return node


## Zemin olmayan test sahnesinde düşmesin ve oyuncuya saldırmasın diye yapay zekâsı kapalı doğar.
func _spawn_caveman(pos: Vector2 = CAVEMAN_POS) -> CharacterBody2D:
	var caveman: CharacterBody2D = _spawn(CAVEMAN_SCENE, pos) as CharacterBody2D
	caveman.set_physics_process(false)
	return caveman


func _cleanup(nodes: Array[Node]) -> void:
	for n: Node in nodes:
		if is_instance_valid(n):
			n.queue_free()
	await process_frame


## 2D-101: Düşman olmuş reis ve savaşçıya oyuncunun kılıç darbesi hata vermeden hasar işler.
func _test_player_hits_hostile_cavemen() -> void:
	var chief: CharacterBody2D = _spawn_caveman()
	var warrior: CharacterBody2D = _spawn_caveman(CAVEMAN_POS + Vector2(60.0, 0.0))
	warrior.is_chief = false
	await process_frame

	chief._enter_enemy_mode(true)
	_check(chief.mode == chief.Mode.ENEMY and warrior.mode == warrior.Mode.ENEMY,
		"Reis düşman olunca savaşçı da düşman oldu.")

	var damaged: Array[String] = []
	for c: CharacterBody2D in [chief, warrior]:
		var before: int = c.current_health
		_player._deal_damage_to_target(c, HIT_DAMAGE)
		if c.current_health == before - HIT_DAMAGE:
			damaged.append(c.name)
	_check(damaged.size() == 2,
		"Oyuncunun kılıç darbesi her iki düşman mağara adamına hasar verdi (script hatası yok).",
		"hasar alan: %s" % [damaged])
	_check(chief.velocity.x > 0.0,
		"Darbe mağara adamını saldırgandan uzağa savurdu.", "velocity: %s" % chief.velocity)

	var before_dir: int = chief.current_health
	chief.take_damage(10, Vector2.LEFT)
	_check(chief.current_health == before_dir - 10 and chief.velocity.x < 0.0,
		"Yön vektörüyle gelen hasar (tehlike/tuzak imzası) hâlâ çalışıyor.")
	await _cleanup([chief, warrior])


## 2D-101: Henüz konuşulmamış (NPC) mağara adamına vurulunca düşmana dönüşür ve hasar alır.
func _test_player_hits_npc_caveman() -> void:
	var npc: CharacterBody2D = _spawn_caveman()
	await process_frame

	var before: int = npc.current_health
	_player._deal_damage_to_target(npc, HIT_DAMAGE)
	_check(npc.mode == npc.Mode.ENEMY and npc.current_health == before - HIT_DAMAGE,
		"NPC mağara adamı vurulunca düşman oldu ve hasar aldı.",
		"mode: %s, can: %d/%d" % [npc.mode, npc.current_health, before])
	await _cleanup([npc])


## 2D-101: Diyalog seçiminden sonra reisin cevap satırı gösterilir, diyalog temiz kapanır
## ve (savaş seçildiyse) ardından gelen kılıç darbesi oyunu durdurmaz.
func _test_dialogue_choice(action: String, choice_index: int, reply_key: String) -> void:
	var chief: CharacterBody2D = _spawn_caveman()
	await process_frame
	var cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	var zoom_before: Vector2 = cam.zoom if cam else Vector2.ONE

	chief.start_interaction()
	await create_timer(ZOOM_SETTLE_SEC).timeout
	_box._is_typing = false
	_box._on_typing_finished()
	_box._on_choice_clicked(choice_index)

	var loader: GDScript = load(STORY_LOADER) as GDScript
	var expected: Array = loader.get_dialogue_sequence(reply_key)
	var queue: Array = _box._dialogue_queue
	var reply_shown: bool = (
		_box.is_dialogue_active() and _box._current_index == 0
		and queue.size() == expected.size() and not expected.is_empty()
		and str(queue[0].get("text", "")) == str(expected[0].get("text", ""))
	)
	_check(reply_shown, "'%s' seçiminden sonra '%s' cevap satırı gösterildi." % [action, reply_key],
		"aktif: %s, indeks: %d" % [_box.is_dialogue_active(), _box._current_index])

	_box._advance_dialogue()
	var cine: Node = root.get_node_or_null("CinematicManager")
	_check(not _box.is_dialogue_active() and (cine == null or not cine.is_active()),
		"'%s' cevabı bitince diyalog kapandı ve sinematik kilidi kalmadı." % action)

	await create_timer(ZOOM_SETTLE_SEC).timeout
	_check(cam != null and cam.zoom.is_equal_approx(zoom_before),
		"'%s' diyaloğu bitince kamera yakınlaştırması eski değerine döndü." % action,
		"önce: %s, sonra: %s" % [zoom_before, cam.zoom if cam else Vector2.ZERO])

	if action == "start_fight":
		var before: int = chief.current_health
		_player._deal_damage_to_target(chief, HIT_DAMAGE)
		_check(chief.mode == chief.Mode.ENEMY and chief.current_health == before - HIT_DAMAGE,
			"Savaş seçildikten sonra reise vurmak oyunu durdurmadı, hasar işlendi.")
	else:
		_check(chief.mode == chief.Mode.NPC and chief.quest_state == "active",
			"Görev kabul edilince reis dost kaldı ve görev aktifleşti.")
	await _cleanup([chief])


## 2D-136: Nişan lazeri, böcek hangi yöne bakarsa baksın hedefe doğru uzanır (arkadan çıkmaz).
func _test_bug_aim_line_points_at_target() -> void:
	var bug: CharacterBody2D = _spawn(BUG_SCENE, Vector2(500.0, 400.0)) as CharacterBody2D
	var target: Node2D = Node2D.new()
	root.add_child(target)
	await process_frame

	for side: float in [1.0, -1.0]:
		var side_name: String = "sağda" if side > 0.0 else "solda"
		target.global_position = bug.global_position + Vector2(200.0 * side, 75.0)
		bug._target_node = target
		bug.current_state = bug.State.HOVER_ENGAGE
		bug._attack_timer = 0.0
		bug.velocity = Vector2.ZERO
		bug._physics_process(0.016)
		var start_err: float = _aim_tip_error(bug, target)

		target.global_position += Vector2(0.0, -40.0)
		bug._physics_process(0.016)
		var track_err: float = _aim_tip_error(bug, target)

		_check(bug.current_state == bug.State.TELEGRAPH and bug.laser_aim_line.visible
			and start_err <= AIM_TOLERANCE_PX and track_err <= AIM_TOLERANCE_PX,
			"Hedef %s iken nişan lazeri hedefi gösteriyor." % side_name,
			"sapma: %.1f px (başlangıç), %.1f px (takip)" % [start_err, track_err])
		bug.laser_aim_line.visible = false
	await _cleanup([bug, target])


## 2D-136: Darbe tepkisi bitince böcek uçuş animasyonuna döner (son "hit" karesinde donmaz).
func _test_bug_recovers_flight_anim_after_hit() -> void:
	var bug: CharacterBody2D = _spawn(BUG_SCENE, Vector2(500.0, 400.0)) as CharacterBody2D
	var target: Node2D = Node2D.new()
	root.add_child(target)
	target.global_position = bug.global_position + Vector2(200.0, 75.0)
	await process_frame

	bug._target_node = target
	bug._attack_timer = 10.0  # Test süresince saldırıya geçmesin
	bug.take_damage(5)
	var hit_started: bool = bug.anim_sprite.animation == &"hit"
	await create_timer(0.6).timeout
	_check(hit_started and bug.anim_sprite.animation != &"hit" and bug.anim_sprite.is_playing(),
		"Darbe tepkisinden sonra böcek uçuş animasyonuna döndü.",
		"hit başladı: %s, şimdiki animasyon: %s" % [hit_started, bug.anim_sprite.animation])
	await _cleanup([bug, target])


## 2D-101 / 2D-136: Her karakter başka karakterin karelerini değil kendi sprite setini kullanır.
func _test_dedicated_sprites() -> void:
	for scene_path: String in SPRITE_SETS:
		var set_name: String = SPRITE_SETS[scene_path][0]
		var node: Node = _spawn(scene_path)
		node.set_physics_process(false)
		var sprite: AnimatedSprite2D = node.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
		var frames: SpriteFrames = sprite.sprite_frames if sprite else null
		var missing: Array[String] = []
		for anim: String in SPRITE_SETS[scene_path][1]:
			if frames == null or not frames.has_animation(anim) or frames.get_frame_count(anim) < 2:
				missing.append(anim)
		var expected_path: String = "res://assets/characters/%s/%s_frames.tres" % [set_name, set_name]
		_check(frames != null and frames.resource_path == expected_path and missing.is_empty()
			and sprite.scale == Vector2.ONE,
			"%s kendi sprite setini 1:1 ölçekte kullanıyor, tüm animasyonlar mevcut." % set_name,
			"kaynak: %s, eksik: %s" % [frames.resource_path if frames else "yok", missing])
		await _cleanup([node])


func _aim_tip_error(bug: CharacterBody2D, target: Node2D) -> float:
	var line: Line2D = bug.laser_aim_line as Line2D
	if line == null or line.get_point_count() < 2:
		return INF
	return line.to_global(line.get_point_position(1)).distance_to(target.global_position)
