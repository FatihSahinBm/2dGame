extends SceneTree

## res://tools/test_secret_wall.gd
## Story 2D-133: Gizli kırılabilir duvar kuralları ve kalıcılığı.
## Çalıştırma: godot --headless --path . --script res://tools/test_secret_wall.gd

const WALL_SCENE: String = "res://scenes/objects/secret_breakable_wall.tscn"
const LEVEL_PATH: String = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"

class FakeAttacker extends Node2D:
	var current_attack_type: String = "light"

class FakeHud extends CanvasLayer:
	var coins: int = 10
	var tutorials: int = 0
	func update_coins(value: int) -> void:
		coins = value
	func set_tutorial(_title: String, _key: String, _desc: String) -> void:
		tutorials += 1

var _failed: bool = false
var _gs: Node = null


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Gizli Kırılabilir Duvar (2D-133) ===")
	_gs = root.get_node_or_null("GameState")
	if _gs == null:
		_gs = (load("res://scripts/autoloads/game_state.gd") as GDScript).new()
		_gs.name = "GameState"
		root.add_child(_gs)
	_gs.reset_state()

	var hud: FakeHud = FakeHud.new()
	hud.add_to_group("hud")
	root.add_child(hud)
	var attacker: FakeAttacker = FakeAttacker.new()
	root.add_child(attacker)

	# Duvar, sahne dosyası olan bir "seviye" altında durur (kalıcı kimlik için)
	var level: Node2D = _make_level()
	var wall: StaticBody2D = _add_wall(level)
	await process_frame
	var resisted: Array[int] = [0]
	var discovered: Array[int] = [0]
	wall.wall_hit_resisted.connect(func(_type: String) -> void: resisted[0] += 1)
	wall.secret_discovered.connect(func(_coins: int, _codex: String) -> void: discovered[0] += 1)
	var collision: CollisionShape2D = wall.get_node("CollisionShape2D")

	_check(wall.is_in_group("damageable") and not wall.is_broken and not collision.disabled, "Duvar başlangıçta sağlam ve geçişi kapatıyor.")

	# Yalnızca belirlenmiş saldırı kırabilir
	attacker.current_attack_type = "light"
	wall.take_damage(999, attacker)
	wall.take_damage(999)
	_check(not wall.is_broken and wall.current_health == wall.max_health and resisted[0] == 2, "Hafif saldırı ve kaynaksız hasar duvarı kırmıyor (direnç geri bildirimi veriliyor).")

	attacker.current_attack_type = "heavy"
	wall.take_damage(20, attacker)
	_check(not wall.is_broken and wall.current_health == wall.max_health - 20, "Ağır saldırı hasar işliyor; can bitmeden kırılmıyor.")
	wall.take_damage(55, attacker)
	await process_frame
	await process_frame
	_check(wall.is_broken and collision.disabled and wall.collision_layer == 0, "Can bitince duvar kırılıyor ve fizik çarpışması tamamen kalkıyor.")
	_check(not wall.is_in_group("damageable") and not wall.get_node("Visual").visible, "Kırık duvar artık hedef alınmıyor ve görünmüyor.")
	_check(discovered[0] == 1 and hud.coins == 10 + wall.reward_coins and hud.tutorials == 1, "Keşif bildirimi ve ödül bir kez veriliyor.")

	# Kırık duvara yeniden vurmak ödülü tekrarlamaz
	wall.take_damage(55, attacker)
	_check(discovered[0] == 1 and hud.coins == 10 + wall.reward_coins, "Kırık duvar yeniden ödül üretmiyor.")

	# Kayıt/yükleme benzetimi: durum JSON'dan geçer, sahne yeniden kurulur
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_gs.persistent_events))
	level.queue_free()
	await process_frame
	await process_frame
	_gs.reset_state()
	_gs.persistent_events = saved
	level = _make_level()
	wall = _add_wall(level)
	var rediscovered: Array[int] = [0]
	wall.secret_discovered.connect(func(_coins: int, _codex: String) -> void: rediscovered[0] += 1)
	await process_frame
	await process_frame
	_check(wall.is_broken and wall.get_node("CollisionShape2D").disabled, "Yükleme sonrası duvar kırık başlıyor.")
	_check(rediscovered[0] == 0 and hud.coins == 10 + wall.reward_coins and hud.tutorials == 1, "Yüklemede ödül ve bildirim tekrarlanmıyor.")

	# Farklı adlı ikinci duvar bağımsızdır
	var other: StaticBody2D = (load(WALL_SCENE) as PackedScene).instantiate()
	other.name = "SecretWallB"
	level.add_child(other)
	await process_frame
	_check(not other.is_broken, "Aynı sahnedeki başka bir duvar kırık durumu devralmıyor.")

	level.queue_free()
	hud.queue_free()
	attacker.queue_free()
	_gs.reset_state()
	if _failed:
		printerr("SONUÇ: GİZLİ DUVAR TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: GİZLİ DUVAR TESTİ BAŞARILI")
		quit(0)


func _make_level() -> Node2D:
	var level: Node2D = Node2D.new()
	level.name = "TestLevel"
	level.scene_file_path = LEVEL_PATH
	root.add_child(level)
	return level


func _add_wall(level: Node2D) -> StaticBody2D:
	var wall: StaticBody2D = (load(WALL_SCENE) as PackedScene).instantiate()
	wall.name = "SecretWallA"
	level.add_child(wall)
	return wall


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
