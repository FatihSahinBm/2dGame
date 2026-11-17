extends SceneTree

## res://tools/test_plunge_attack.gd
## Story 2D-129: Havadan yere sert iniş (plunge attack). Gerçek fizik adımlarıyla çalışır.
## Çalıştırma: godot --headless --path . --script res://tools/test_plunge_attack.gd

class DummyEnemy extends CharacterBody2D:
	var hits: int = 0
	var is_dead: bool = false
	func take_damage(_amount: int, _attacker: Variant = null) -> void:
		hits += 1

const FLOOR_Y: float = 600.0

var _failed: bool = false
var _player: CharacterBody2D = null


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Plunge Attack (2D-129) ===")
	var floor_body: StaticBody2D = StaticBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(900, 40)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = Vector2(300, FLOOR_Y + 20.0)
	root.add_child(floor_body)

	_player = (load("res://scenes/combat/test_player.tscn") as PackedScene).instantiate()
	root.add_child(_player)
	if not _player.has_sword and _player.has_method("pickup_sword"):
		_player.pickup_sword()
	_player.has_sword = true

	var near: DummyEnemy = _spawn_enemy(Vector2(350, FLOOR_Y - 20))
	var far: DummyEnemy = _spawn_enemy(Vector2(300 + _player.PLUNGE_RADIUS + 120, FLOOR_Y - 20))
	var ally: DummyEnemy = _spawn_enemy(Vector2(270, FLOOR_Y - 20))
	ally.add_to_group("allies")

	var landed: Array[int] = []
	var cancelled: Array[int] = [0]
	_player.plunge_landed.connect(func(count: int) -> void: landed.append(count))
	_player.plunge_cancelled.connect(func() -> void: cancelled[0] += 1)

	# Yerdeyken başlatılamaz
	await _stand()
	_check(not _player.can_start_plunge() and not _player.start_plunge(), "Yerdeyken iniş saldırısı başlatılamıyor.")

	# Havada başlar, dikey hızla iner
	_player.global_position = Vector2(300, FLOOR_Y - 260)
	_player.velocity = Vector2(120, -50)
	await _frames(3)
	_check(_player.start_plunge() and _player.is_plunging and _player.is_attacking, "Havada iniş saldırısı başlıyor.")
	_check(not _player.start_plunge(), "İniş sürerken ikinci iniş başlatılamıyor.")
	await _frames(2)
	_check(is_equal_approx(_player.velocity.x, 0.0) and _player.velocity.y > 800.0, "İniş boyunca yatay hareket kilitli, dikey hız sabit.")

	for i: int in range(120):
		await physics_frame
		if not _player.is_plunging:
			break
	_check(landed.size() == 1 and landed[0] == 1, "Zemine temas tek bir iniş olayı üretti ve yalnızca menzildeki düşman sayıldı.")
	_check(near.hits == 1 and far.hits == 0 and ally.hits == 0, "Alan hasarı: yakın düşman 1 kez vuruldu; uzak düşman ve müttefik etkilenmedi.")
	_check(near.velocity.x > 0.0 and near.velocity.y < 0.0, "Vurulan düşman oyuncudan uzağa doğru geri itildi.")
	await _frames(10)
	_check(near.hits == 1 and landed.size() == 1, "Aynı iniş için hasar tekrarlanmıyor.")
	await create_timer(_player.PLUNGE_RECOVERY + 0.1).timeout
	_check(not _player.is_attacking and not _player.is_plunging and _player.current_attack_type == "", "İnişten sonra saldırı ve hareket kontrolü normale dönüyor.")

	# Hasar alınca iniş etkisiz iptal edilir
	_player.global_position = Vector2(300, FLOOR_Y - 400)
	_player.velocity = Vector2.ZERO
	await _frames(3)
	_player.start_plunge()
	await _frames(2)
	_player.is_hurt = true
	await _frames(2)
	_check(cancelled[0] == 1 and not _player.is_plunging and not _player.is_attacking, "Hasar alma inişi iptal ediyor; durum takılı kalmıyor.")
	_player.is_hurt = false
	await _stand()
	_check(near.hits == 1 and landed.size() == 1, "İptal edilen iniş hasar ve iniş olayı üretmiyor.")

	# Zemine ulaşılamazsa süre aşımıyla iptal
	_player.global_position = Vector2(5000, -3000)
	_player.velocity = Vector2.ZERO
	await _frames(3)
	_player.start_plunge()
	await create_timer(_player.PLUNGE_MAX_DURATION + 0.2).timeout
	_check(cancelled[0] == 2 and not _player.is_plunging, "Zemine ulaşamayan iniş süre aşımıyla güvenle sonlanıyor.")

	for node: Node in [near, far, ally, _player, floor_body]:
		node.queue_free()
	if _failed:
		printerr("SONUÇ: PLUNGE ATTACK TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: PLUNGE ATTACK TESTİ BAŞARILI")
		quit(0)


func _spawn_enemy(pos: Vector2) -> DummyEnemy:
	var enemy: DummyEnemy = DummyEnemy.new()
	enemy.add_to_group("enemies")
	root.add_child(enemy)
	enemy.global_position = pos
	return enemy


func _frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame


func _stand() -> void:
	_player.velocity = Vector2.ZERO
	_player.global_position = Vector2(300, FLOOR_Y - 60)
	for i: int in range(120):
		await physics_frame
		if _player.is_on_floor():
			break
	await _frames(3)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
