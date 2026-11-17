extends SceneTree

## res://tools/test_parry.gd
## Story 2D-127: Savuşturma (parry) penceresi, geri bildirim ve düşman sersemletme kuralları.
## Çalıştırma: godot --headless --path . --script res://tools/test_parry.gd

const ParryResolver = preload("res://scripts/combat/parry_resolver.gd")

class ParryableEnemy extends Node2D:
	var is_dead: bool = false
	var parried: int = 0
	var last_duration: float = 0.0
	func on_parried(duration: float = 0.9) -> void:
		parried += 1
		last_duration = duration

class BossLike extends Node2D:
	var is_dead: bool = false

var _failed: bool = false


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Savuşturma ve Karşı Saldırı (2D-127) ===")
	var player: CharacterBody2D = (load("res://scenes/combat/test_player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.global_position = Vector2(500, 500)

	var near: ParryableEnemy = _spawn(ParryableEnemy.new(), Vector2(560, 500)) as ParryableEnemy
	var mid: ParryableEnemy = _spawn(ParryableEnemy.new(), Vector2(620, 500)) as ParryableEnemy
	var far: ParryableEnemy = _spawn(ParryableEnemy.new(), Vector2(500 + ParryResolver.STAGGER_RANGE + 80, 500)) as ParryableEnemy
	var boss: BossLike = _spawn(BossLike.new(), Vector2(520, 500)) as BossLike

	var parries: Array[int] = [0]
	var blocks: Array[int] = [0]
	player.parry_performed.connect(func() -> void: parries[0] += 1)
	player.attack_blocked.connect(func(_reduced: int, _original: int) -> void: blocks[0] += 1)

	# Pencere içinde: hasar yok, yalnızca en yakın savuşturulabilir düşman sersemler
	var hp: int = player.current_health
	player.is_defending = true
	player.block_timer = 0.0
	player.take_damage(30)
	_check(player.current_health == hp and parries[0] == 1, "Pencere içindeki savunma saldırıyı tamamen etkisizleştiriyor.")
	_check(near.parried == 1 and mid.parried == 0 and far.parried == 0, "Yalnızca en yakın savuşturulabilir düşman sersemliyor.")
	_check(is_equal_approx(near.last_duration, ParryResolver.STAGGER_DURATION), "Sersemleme süresi merkezi sabitten geliyor.")
	_check(is_instance_valid(boss), "Boss benzeri düşman (on_parried uygulamayan) sersemletilmiyor ve hata oluşmuyor.")
	await create_timer(0.2, true, false, true).timeout
	_check(is_equal_approx(Engine.time_scale, 1.0), "Hit-stop sonrası zaman ölçeği normale dönüyor.")

	# Pencere dışında: normal blok kuralları (azaltılmış hasar), sersemletme yok
	hp = player.current_health
	player.is_defending = true
	player.block_timer = player.parry_window + 0.3
	player.take_damage(30)
	_check(parries[0] == 1 and near.parried == 1, "Pencere dışındaki savunma savuşturma sayılmıyor.")
	_check(blocks[0] == 1 and player.current_health < hp and player.current_health > hp - 30, "Pencere dışında azaltılmış blok hasarı uygulanıyor (ayrı geri bildirim).")

	# Savunma yokken tam hasar
	hp = player.current_health
	player.is_defending = false
	player.take_damage(10)
	_check(player.current_health == hp - 10, "Savunma yokken normal hasar kuralları uygulanıyor.")

	# Ölü düşman ve menzil dışı hedef seçilmez
	near.is_dead = true
	mid.is_dead = true
	_check(ParryResolver.stagger_attacker(player) == null and far.parried == 0, "Ölü ve menzil dışındaki düşmanlar sersemletilmiyor.")

	# Gerçek düşman sınıfları kuralı uyguluyor
	for path: String in ["res://scripts/enemies/monster_enemy.gd", "res://scripts/enemies/raptor.gd"]:
		_check(_has_method(path, "on_parried"), path.get_file() + " savuşturulabilir (on_parried var).")
	for path: String in ["res://scripts/enemies/vlad_boss.gd", "res://scripts/enemies/trex_boss.gd", "res://scripts/enemies/necromancer.gd", "res://scripts/enemies/ogre_boss.gd"]:
		_check(_declares_method(path, "is_parry_immune"), path.get_file() + " sersemletmeye bağışık (boss kuralı).")
	_check(not _declares_method("res://scripts/enemies/blood_knight.gd", "on_parried"), "blood_knight.gd (mini-boss) sersemletilemez.")

	# Gerçek boss sahnesi: en yakın düşman olsa da seçilmez
	var ogre: Node2D = (load("res://scenes/enemies/ogre_boss.tscn") as PackedScene).instantiate()
	root.add_child(ogre)
	ogre.set_physics_process(false)
	ogre.global_position = player.global_position + Vector2(30, 0)
	_check(ogre.has_method("on_parried") and ParryResolver.stagger_attacker(player) == null, "Gerçek boss sahnesi savuşturmayla sersemletilmiyor.")
	ogre.queue_free()

	for node: Node in [near, mid, far, boss, player]:
		node.queue_free()
	if _failed:
		printerr("SONUÇ: SAVUŞTURMA TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: SAVUŞTURMA TESTİ BAŞARILI")
		quit(0)


func _spawn(node: Node2D, pos: Vector2) -> Node2D:
	node.add_to_group("enemies")
	root.add_child(node)
	node.global_position = pos
	return node


func _has_method(script_path: String, method: String) -> bool:
	for info: Dictionary in (load(script_path) as GDScript).get_script_method_list():
		if info.get("name", "") == method:
			return true
	return false


## Metot bu dosyada mı tanımlı (üst sınıftan miras alınanlar hariç)?
func _declares_method(script_path: String, method: String) -> bool:
	return FileAccess.get_file_as_string(script_path).contains("func %s(" % method)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
