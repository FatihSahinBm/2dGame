extends SceneTree

## res://tools/test_combat_vfx.gd
## Story 2D-150: Savaş geri bildirimi ve VFX kütüphanesi.
## Çalıştırma: godot --headless --path . --script res://tools/test_combat_vfx.gd

const CombatVfx = preload("res://scripts/effects/combat_vfx.gd")

class Dummy extends Node2D:
	var hits: int = 0
	func take_damage(_amount: int, _attacker: Variant = null) -> void:
		hits += 1

var _failed: bool = false


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Savaş VFX Kütüphanesi (2D-150) ===")
	var cinematic: Node = root.get_node_or_null("CinematicManager")
	var had_reduce: bool = cinematic.reduce_motion if cinematic else false
	if cinematic:
		cinematic.reduce_motion = false
	var host: Node2D = Node2D.new()
	root.add_child(host)

	# Şablonlar
	for template: String in ["spark", "heavy_spark", "dust", "blood"]:
		var effect: CPUParticles2D = CombatVfx.spawn(host, Vector2(100, 200), template)
		_check(effect != null and effect.one_shot and effect.emitting and effect.global_position == Vector2(100, 200), "'%s' şablonu çarpışma konumunda tek atımlık oluşuyor." % template)
	_check(CombatVfx.spawn(host, Vector2.ZERO, "olmayan") == null, "Tanımsız şablon çökmeden reddediliyor.")

	# Hafif / ağır ayrımı
	var light: CPUParticles2D = CombatVfx.spawn(host, Vector2.ZERO, "spark")
	var heavy: CPUParticles2D = CombatVfx.spawn(host, Vector2.ZERO, "heavy_spark")
	_check(heavy.amount > light.amount and heavy.initial_velocity_max > light.initial_velocity_max and heavy.lifetime > light.lifetime, "Ağır vuruş efekti hafiften belirgin biçimde büyük.")
	_check(CombatVfx.is_heavy_attack("heavy") and CombatVfx.is_heavy_attack("plunge") and not CombatVfx.is_heavy_attack("light"), "Saldırı türleri hafif/ağır olarak sınıflanıyor.")

	# Süre sonunda temizlik
	var count_before: int = CombatVfx.get_active_count(host)
	await create_timer(0.75).timeout
	_check(count_before >= 6 and CombatVfx.get_active_count(host) == 0, "Efektler süreleri bitince kendiliğinden temizleniyor.")

	# Ekran kalabalığı sınırı
	var spawned: int = 0
	for i: int in range(CombatVfx.MAX_ACTIVE_EFFECTS + 10):
		if CombatVfx.spawn(host, Vector2(i, 0), "spark") != null:
			spawned += 1
	_check(spawned == CombatVfx.MAX_ACTIVE_EFFECTS, "Aynı anda yaşayan efekt sayısı sınırlanıyor (%d)." % spawned)
	await create_timer(0.5).timeout

	# Yoğunluk ayarı
	if cinematic:
		cinematic.reduce_motion = true
		var reduced: CPUParticles2D = CombatVfx.spawn(host, Vector2.ZERO, "heavy_spark")
		_check(reduced.amount == int(round(float(CombatVfx.TEMPLATES["heavy_spark"]["amount"]) * 0.5)), "Hareketi Azalt açıkken parçacık yoğunluğu yarıya iniyor.")
		cinematic.reduce_motion = false

	# Hasar sayıları
	var small: Label = CombatVfx.spawn_damage_number(host, Vector2(50, 50), 12, false)
	var big: Label = CombatVfx.spawn_damage_number(host, Vector2(50, 50), 55, true)
	_check(small.text == "-12" and big.text == "-55" and big.get_theme_font_size("font_size") > small.get_theme_font_size("font_size"), "Hasar sayıları okunabilir; ağır vuruş sayısı daha büyük.")
	await create_timer(0.8).timeout
	_check(not is_instance_valid(small) and not is_instance_valid(big), "Hasar sayıları kaybolup temizleniyor.")

	# Oyuncu vuruşuna bağlanma
	var player: CharacterBody2D = (load("res://scenes/combat/test_player.tscn") as PackedScene).instantiate()
	host.add_child(player)
	await process_frame
	player.set_physics_process(false)
	var target: Dummy = Dummy.new()
	host.add_child(target)
	target.global_position = player.global_position + Vector2(40, 0)
	player.current_attack_type = "light"
	player._deal_damage_to_target(target, 25)
	var light_templates: Array = _templates(host)
	await create_timer(0.5).timeout
	player.current_attack_type = "heavy"
	player._deal_damage_to_target(target, 55)
	var heavy_templates: Array = _templates(host)
	_check(target.hits == 2 and light_templates == ["spark"] and heavy_templates == ["heavy_spark"], "Oyuncu vuruşları saldırı türüne uygun efekti hedefin konumunda üretiyor.")

	if cinematic:
		cinematic.reduce_motion = had_reduce
	host.queue_free()
	if _failed:
		printerr("SONUÇ: SAVAŞ VFX TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: SAVAŞ VFX TESTİ BAŞARILI")
		quit(0)


func _templates(host: Node) -> Array:
	var names: Array = []
	for node: Node in get_nodes_in_group("combat_vfx"):
		if host.is_ancestor_of(node) and not node.is_queued_for_deletion():
			names.append(str(node.get_meta("template", "")))
	return names


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
