extends SceneTree

## res://tools/test_blood_knight_skills.gd
## Story 2D-141: Kan Şövalyesi kan dalgası ve zincirle çekme saldırıları. Gerçek fizik adımlarıyla.
## Çalıştırma: godot --headless --path . --script res://tools/test_blood_knight_skills.gd

const FLOOR_Y: float = 600.0

var _failed: bool = false
var _knight: CharacterBody2D = null
var _player: CharacterBody2D = null
var _skills: Node = null


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Kan Şövalyesi Saldırıları (2D-141) ===")
	var game_state: Node = root.get_node_or_null("GameState")
	if game_state:
		game_state.is_in_cinematic = false
	_make_static(Vector2(800, FLOOR_Y + 20), Vector2(2000, 40)) # zemin

	_knight = (load("res://scenes/enemies/blood_knight.tscn") as PackedScene).instantiate()
	root.add_child(_knight)
	_knight.global_position = Vector2(400, FLOOR_Y - 40)
	_player = (load("res://scenes/combat/test_player.tscn") as PackedScene).instantiate()
	root.add_child(_player)
	_player.global_position = Vector2(650, FLOOR_Y - 40)
	await _frames(20)
	_skills = _knight.get_node_or_null("Skills")
	_check(_skills != null, "Şövalyede menzilli saldırı bileşeni var.")
	# Testte yakın dövüş ve yürüme karışmasın: şövalyenin kendi yapay zekası kapatılır
	_knight.set_physics_process(false)

	# --- Kan dalgası ---
	_skills.wave_cooldown = 0.0
	_skills.chain_cooldown = 99.0
	var dist: float = _knight.global_position.distance_to(_player.global_position)
	_check(_skills.try_use(_player, dist) and _skills.active_skill == "wave", "Orta menzilde kan dalgası başlıyor.")
	_check(_knight.find_child("SkillTelegraph", true, false) != null, "Dalga öncesi görsel uyarı (telegraph) gösteriliyor.")
	_check(not _skills.try_use(_player, dist), "Saldırı sürerken ikinci saldırı başlamıyor.")
	await _frames(10)
	_check(_skills.get_active_waves().is_empty(), "Uyarı süresi bitmeden dalga çıkmıyor (kaçınma fırsatı).")
	var hp: int = _player.current_health
	await _wait_for(func() -> bool: return _player.current_health < hp, 3.0)
	_check(hp - _player.current_health == _skills.WAVE_DAMAGE, "Dalga yerdeki oyuncuya bir kez tam hasar veriyor.")
	var hp_after: int = _player.current_health
	await _frames(30)
	_check(_player.current_health == hp_after, "Aynı dalga ikinci kez hasar vermiyor.")
	await _wait_for(func() -> bool: return _skills.get_active_waves().is_empty() and not _skills.is_busy(), 4.0)
	_check(_skills.get_active_waves().is_empty(), "Dalga menzili bitince temizleniyor.")
	_check(not _skills.is_busy() and not _knight._is_attacking, "Toparlanma penceresinden sonra şövalye normale dönüyor.")
	_check(not _skills.try_use(_player, dist), "Bekleme süresindeyken dalga tekrar kullanılamıyor.")

	# Dalganın üstünden zıplayan oyuncu vurulmaz
	_skills.wave_cooldown = 0.0
	_player.global_position = Vector2(650, FLOOR_Y - 40)
	await _frames(10)
	_skills.try_use(_player, _knight.global_position.distance_to(_player.global_position))
	hp = _player.current_health
	await _wait_for(func() -> bool: return not _skills.get_active_waves().is_empty(), 2.0)
	_player.set_physics_process(false)
	_player.global_position = Vector2(650, FLOOR_Y - 140) # havada, dalganın üstünde
	await _wait_for(func() -> bool: return _skills.get_active_waves().is_empty(), 3.0)
	_check(_player.current_health == hp, "Zıplayan (dalganın üstündeki) oyuncu vurulmuyor.")
	_player.set_physics_process(true)
	await _wait_for(func() -> bool: return not _skills.is_busy(), 2.0)

	# --- Zincir: geçerli hedef ---
	_player.global_position = Vector2(400 + 300, FLOOR_Y - 40)
	await _frames(20)
	_skills.chain_cooldown = 0.0
	_skills.wave_cooldown = 99.0
	var caught: Array[int] = [0]
	var missed: Array[String] = []
	_skills.chain_caught.connect(func(_p: Node2D) -> void: caught[0] += 1)
	_skills.chain_missed.connect(func(reason: String) -> void: missed.append(reason))
	dist = _knight.global_position.distance_to(_player.global_position)
	_check(_skills.try_use(_player, dist) and _skills.active_skill == "chain", "Uzak menzilde zincir başlıyor.")
	hp = _player.current_health
	await _wait_for(func() -> bool: return caught[0] > 0, 2.0)
	_check(caught[0] == 1 and not _player.can_move and hp - _player.current_health == _skills.CHAIN_DAMAGE, "Zincir oyuncuyu yakalıyor, küçük hasar veriyor ve hareketini kilitliyor.")
	await _wait_for(func() -> bool: return _skills._phase == "recovery" or not _skills.is_busy(), 3.0)
	var gap: float = absf(_player.global_position.x - _knight.global_position.x)
	_check(gap <= _skills.CHAIN_STOP_DISTANCE + 20.0, "Oyuncu şövalyenin önüne çekildi (mesafe %.0f px)." % gap)
	_check(_player.global_position.y <= FLOOR_Y + 1.0 and _player.is_on_floor(), "Çekme oyuncuyu zemine gömmüyor (ayaklar zemin üstünde).")
	_check(_player.can_move, "Sersemleme bitince oyuncunun hareketi geri açılıyor.")
	await _wait_for(func() -> bool: return not _skills.is_busy(), 2.0)

	# --- Zincir: duvar arkasındaki hedef (geçersiz) ---
	var wall: StaticBody2D = _make_static(Vector2(560, FLOOR_Y - 60), Vector2(20, 160))
	_player.global_position = Vector2(700, FLOOR_Y - 40)
	await _frames(15)
	_skills.chain_cooldown = 0.0
	_skills.try_use(_player, _knight.global_position.distance_to(_player.global_position))
	await _wait_for(func() -> bool: return not missed.is_empty(), 2.0)
	_check(missed == ["blocked"] and caught[0] == 1 and _player.can_move, "Duvar arkasındaki hedefte zincir boşa dönüyor; oyuncu etkilenmiyor.")
	wall.queue_free()
	await _wait_for(func() -> bool: return not _skills.is_busy(), 2.0)

	# --- Zincir: telegraph sırasında kaçan hedef ---
	_player.global_position = Vector2(700, FLOOR_Y - 40)
	await _frames(15)
	_skills.chain_cooldown = 0.0
	_skills.try_use(_player, _knight.global_position.distance_to(_player.global_position))
	await _frames(5)
	_player.global_position = Vector2(1300, FLOOR_Y - 40)
	await _wait_for(func() -> bool: return missed.size() >= 2, 2.0)
	_check(missed.size() == 2 and caught[0] == 1, "Uyarı sırasında uzaklaşan oyuncu yakalanmıyor (adil kaçınma).")
	await _wait_for(func() -> bool: return not _skills.is_busy(), 2.0)

	# --- Ölüm: süren çekme iptal, oyuncu serbest, ödül olayı tek ---
	_player.global_position = Vector2(700, FLOOR_Y - 40)
	await _frames(15)
	_skills.chain_cooldown = 0.0
	_skills.try_use(_player, _knight.global_position.distance_to(_player.global_position))
	await _wait_for(func() -> bool: return caught[0] >= 2, 2.0)
	var deaths: Array[int] = [0]
	_knight.died.connect(func() -> void: deaths[0] += 1)
	_knight.take_damage(99999)
	_knight.take_damage(99999)
	_knight._die()
	await _frames(3)
	_check(deaths[0] == 1, "Ölüm ve ödül olayı yalnızca bir kez çalışıyor.")
	_check(not _skills.is_busy() and _player.can_move, "Ölüm süren zinciri iptal edip oyuncuyu serbest bırakıyor.")

	if _failed:
		printerr("SONUÇ: KAN ŞÖVALYESİ TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: KAN ŞÖVALYESİ TESTİ BAŞARILI")
		quit(0)


func _make_static(pos: Vector2, size: Vector2) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	body.position = pos
	root.add_child(body)
	return body


func _frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame


func _wait_for(condition: Callable, timeout: float) -> void:
	var elapsed: float = 0.0
	while elapsed < timeout and not condition.call():
		await physics_frame
		elapsed += 1.0 / float(Engine.physics_ticks_per_second)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
