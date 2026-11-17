extends SceneTree

## res://tools/test_jump_tolerance.gd
## Story 2D-155: Coyote Time (120 ms) ve Jump Buffering (100 ms).
## Gerçek fizik adımlarıyla çalışır: zeminli küçük bir sahne kurar ve zıplama girdisini benzetir.
## Çalıştırma: godot --headless --path . --script res://tools/test_jump_tolerance.gd

const FLOOR_Y: float = 600.0
const ON_FLOOR_X: float = 300.0
const OFF_FLOOR_X: float = 2000.0

var _failed: bool = false
var _player: CharacterBody2D = null


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Zıplama Toleransları (2D-155) ===")
	var floor_body: StaticBody2D = StaticBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(600, 40)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = Vector2(ON_FLOOR_X, FLOOR_Y + 20.0)
	root.add_child(floor_body)

	_player = (load("res://scenes/combat/test_player.tscn") as PackedScene).instantiate()
	root.add_child(_player)
	_player.double_jump_unlocked = false # Havada ikinci zıplama toleransı sonuçlarını etkilemesin

	_check(is_equal_approx(_player.coyote_time, 0.12), "Coyote süresi 120 ms.")
	_check(is_equal_approx(_player.jump_buffer_time, 0.10), "Zıplama tamponu 100 ms.")

	# 1. Coyote: kenardan boşluğa çıktıktan kısa süre sonra zıplama normal yükseklikte tetiklenir
	await _stand_on_floor()
	_step_off()
	await _frames(4) # ~33 ms
	await _press_jump()
	_check(is_equal_approx(_player.velocity.y, _player.jump_velocity) or _player.velocity.y < _player.jump_velocity * 0.8, "Kenardan çıktıktan ~40 ms sonra zıplama tam güçle tetikleniyor.")

	# 2. Coyote süresi aşılınca girdi yok sayılır, kontrolsüz ikinci sıçrama olmaz
	await _stand_on_floor()
	_step_off()
	await _frames(24) # 200 ms
	await _press_jump()
	_check(_player.velocity.y > 0.0, "Coyote süresi (200 ms sonra) aşılınca havada zıplama olmuyor.")
	await _frames(20)
	_check(_player.velocity.y > 0.0, "Süresi dolan tampon sonradan zıplama üretmiyor.")

	# 3. Buffer: yere inmeden hemen önce basılan zıplama, yere basılan ilk karelerde tetiklenir
	await _stand_on_floor()
	_player.global_position.y -= 14.0
	_player.velocity = Vector2(0, 260.0)
	await _frames(1)
	await _press_jump(false)
	var jumped: bool = false
	for i: int in range(14):
		await physics_frame
		if _player.velocity.y < -100.0:
			jumped = true
			break
	_check(jumped, "Yere inmeden hemen önce basılan zıplama inişte otomatik tetikleniyor.")

	# 4. Buffer süresi aşılırsa inişte zıplama olmaz
	await _stand_on_floor()
	_player.global_position.y -= 150.0
	_player.velocity = Vector2.ZERO
	await _frames(24) # 200 ms: coyote süresi dolsun, inişe ise hâlâ ~300 ms var
	await _press_jump(false)
	var late_jump: bool = false
	for i: int in range(90):
		await physics_frame
		if _player.velocity.y < -100.0:
			late_jump = true
		if _player.is_on_floor():
			break
	await _frames(6)
	_check(not late_jump and _player.velocity.y >= -1.0, "İnişten 100 ms'den önce basılan zıplama yok sayılıyor.")

	# 5. Hasar almak tamponu temizler
	await _stand_on_floor()
	_player._jump_buffer_timer = _player.jump_buffer_time
	_player.take_damage(1)
	_check(_player._jump_buffer_timer == 0.0, "Hasar alınca tamponlanmış zıplama temizleniyor.")

	# 6. Duvara sürtünme tamponu temizler (kod kuralı)
	var source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	var wall_at: int = source.find("is_wall_sliding = true")
	_check(wall_at != -1 and source.substr(wall_at, 120).contains("_jump_buffer_timer = 0.0"), "Duvar kayması başlarken tampon sıfırlanıyor.")

	Input.action_release("jump")
	_player.queue_free()
	floor_body.queue_free()
	if _failed:
		printerr("SONUÇ: ZIPLAMA TOLERANSI TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: ZIPLAMA TOLERANSI TESTİ BAŞARILI")
		quit(0)


func _frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame


## Oyuncuyu zemine koyar ve yere bastığı kareyi bekler
func _stand_on_floor() -> void:
	Input.action_release("jump")
	_player.is_hurt = false
	_player.velocity = Vector2.ZERO
	_player._jump_buffer_timer = 0.0
	_player.global_position = Vector2(ON_FLOOR_X, FLOOR_Y - 60.0)
	for i: int in range(120):
		await physics_frame
		if _player.is_on_floor():
			break
	await _frames(3)


## Zeminin dışına, aynı yüksekliğe taşır (kenardan adım atma)
func _step_off() -> void:
	_player.global_position.x = OFF_FLOOR_X
	_player.velocity = Vector2.ZERO


func _press_jump(wait_after: bool = true) -> void:
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	if wait_after:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
