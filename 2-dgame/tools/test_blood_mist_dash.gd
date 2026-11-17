extends SceneTree

## res://tools/test_blood_mist_dash.gd
## Story 2D-126: Kan Sisi Atılması kuralları.
## Çalıştırma: godot --headless --path . --script res://tools/test_blood_mist_dash.gd

class DummyTarget extends Node2D:
	var hits: int = 0
	var is_dead: bool = false
	func take_damage(_amount: int, _attacker: Variant = null) -> void:
		hits += 1

var _failed: bool = false


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Kan Sisi Atılması (2D-126) ===")
	var game_state: Node = root.get_node_or_null("GameState")
	if game_state == null:
		game_state = (load("res://scripts/autoloads/game_state.gd") as GDScript).new()
		game_state.name = "GameState"
		root.add_child(game_state)
	game_state.reset_state()

	var player: CharacterBody2D = (load("res://scenes/combat/test_player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false) # Zeminsiz test sahnesinde düşmeyi engelle
	var mask_before: bool = player.get_collision_mask_value(2)

	# Yetenek kilitliyken sis atılması etkinleşmez (normal dash çalışır)
	player.perform_dash()
	_check(not player.is_blood_mist_dashing, "Yetenek kilitliyken Kan Sisi etkinleşmiyor.")
	await create_timer(0.6).timeout
	_check(player.can_dash and not player.is_dashing and player.get_collision_mask_value(2) == mask_before, "Normal dash bitince durum ve çarpışma maskesi eski hâlinde.")

	game_state.unlock_ability(player.BLOOD_MIST_ABILITY_ID)
	player.current_health = 50
	player.perform_dash()
	_check(player.is_blood_mist_dashing and player.is_dashing and not player.can_dash, "Yetenek açıkken Kan Sisi başlıyor ve bekleme süresi devreye giriyor.")
	_check(not player.get_collision_mask_value(2), "Atılma sırasında düşman çarpışması kapalı.")

	# Hasar almama penceresi
	player.take_damage(40)
	_check(player.current_health == 50, "Atılma sırasında take_damage ile gelen hasar alınmıyor.")

	# Aynı hedef tek atılmada yalnızca bir kez vurulur; müttefik etkilenmez; iyileşme sınırlıdır
	var enemy: DummyTarget = DummyTarget.new()
	var ally: DummyTarget = DummyTarget.new()
	ally.add_to_group("allies")
	root.add_child(enemy)
	root.add_child(ally)
	player._leech_from(enemy)
	player._leech_from(enemy)
	player._leech_from(ally)
	_check(enemy.hits == 1, "Aynı düşman tek atılmada yalnızca bir kez hasar alıyor.")
	_check(ally.hits == 0, "Müttefikler sis hasarından etkilenmiyor.")
	_check(player.current_health == 50 + player.BLOOD_MIST_LEECH_PER_ENEMY, "Düşman başına can çalma uygulanıyor.")
	var extras: Array[DummyTarget] = []
	for i: int in range(5):
		var extra: DummyTarget = DummyTarget.new()
		root.add_child(extra)
		extras.append(extra)
		player._leech_from(extra)
	_check(player.current_health == 50 + player.BLOOD_MIST_LEECH_CAP, "Tek atılmadaki toplam iyileşme sınırı aşılmıyor.")

	# Bekleme süresindeyken yeniden etkinleşmez
	var hits_before: int = player._mist_hit_ids.size()
	player.perform_dash()
	_check(player._mist_hit_ids.size() == hits_before, "Atılma sürerken ikinci atılma başlamıyor.")

	await create_timer(player.BLOOD_MIST_COOLDOWN + 0.15).timeout
	_check(not player.is_blood_mist_dashing and not player.is_dashing and player.can_dash, "Süre bitince atılma sonlanıyor ve yeniden kullanılabiliyor.")
	_check(player.get_collision_mask_value(2) == mask_before, "Çarpışma maskesi kalıcı olarak kapalı kalmıyor.")
	player.take_damage(5)
	_check(player.current_health < 50 + player.BLOOD_MIST_LEECH_CAP, "Pencere dışında normal hasar kuralları uygulanıyor.")

	# Yeni atılmada aynı düşman yeniden vurulabilir
	player.perform_dash()
	player._leech_from(enemy)
	_check(enemy.hits == 2, "Sonraki atılmada vuruş kaydı sıfırlanıyor.")

	# Atılma sürerken düğüm serbest kalırsa (sahne değişimi) zamanlayıcılar hata üretmemeli
	player.queue_free()
	await create_timer(0.7).timeout
	print("PASS: Atılma sırasında oyuncu serbest bırakılınca zamanlayıcılar sessizce düştü.")

	for node: Node in extras + [enemy, ally]:
		node.queue_free()
	game_state.reset_state()
	if _failed:
		printerr("SONUÇ: KAN SİSİ ATILMASI TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: KAN SİSİ ATILMASI TESTİ BAŞARILI")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
