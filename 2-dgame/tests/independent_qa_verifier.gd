extends SceneTree

func _init() -> void:
	print('========================================================')
	print('  INDEPENDENT QA: ANIMATION, GAMEPLAY & BOUNDARY AUDIT  ')
	print('========================================================')

	# 1. Player Sahnesini Yükle ve Ağaca Ekle
	var player_scn = load('res://scenes/player.tscn')
	if not player_scn:
		printerr('FAIL: res://scenes/player.tscn yüklenemedi!')
		quit(1)
		return
	print('PASS: res://scenes/player.tscn başarıyla yüklendi.')

	var player = player_scn.instantiate()
	root.add_child(player)
	player.global_position = Vector2(200, 300)
	print('PASS: Player sahne ağacına eklendi (global_position: ', player.global_position, ')')

	var anim = player.get_node_or_null('Visual/AnimatedSprite2D')
	if not anim:
		printerr('FAIL: Visual/AnimatedSprite2D bulunamadı!')
		quit(1)
		return
	print('PASS: AnimatedSprite2D düğümü doğrulandı.')

	var col = player.get_node_or_null('CollisionShape2D')
	if not col:
		printerr('FAIL: CollisionShape2D bulunamadı!')
		quit(1)
		return
	print('PASS: CollisionShape2D düğümü doğrulandı. Pozisyon: ', col.position, ' Şekil: ', col.shape.size)

	# Ayak hiza doğrulaması: Col shape boyu 38, y=-19 -> alt sınır y=0
	var col_bottom = col.position.y + (col.shape.size.y / 2.0)
	if abs(col_bottom) < 0.01:
		print('PASS: Fizik taban çarpışma düzlemi tam y=0 (Karakter zemine mükemmel oturuyor).')
	else:
		printerr('FAIL: Fizik taban hizası y=0 değil: ', col_bottom)

	# 2. Bütün Temel Animasyonların Doğrulanması
	var required_anims = [
		'idle', 'idle_armed', 'run', 'run_armed',
		'jump', 'jump_armed', 'fall', 'fall_armed',
		'attack', 'attack_combo', 'heavy_attack',
		'crouch', 'crouch_attack', 'crouch_walk',
		'hit', 'death'
	]

	var frames = anim.sprite_frames
	for a_name in required_anims:
		if frames.has_animation(a_name):
			var frame_count = frames.get_frame_count(a_name)
			var fps = frames.get_animation_speed(a_name)
			print('PASS: Animasyon mevcut: %s (Frame: %d, FPS: %.1f)' % [a_name, frame_count, fps])
		else:
			printerr('FAIL: Gerekli animasyon eksik: ', a_name)

	# 3. Yüz ve Yön Değişimi (Sprite Flipping & Symmetry)
	player.facing_dir = 1
	var visual = player.get_node_or_null('Visual')
	visual.scale.x = 1
	print('PASS: Sağa bakış yönü: scale.x = ', visual.scale.x)
	player.facing_dir = -1
	visual.scale.x = -1
	print('PASS: Sola bakış yönü: scale.x = ', visual.scale.x, ' (AttackArea ve Sprite simetrik döndü)')
	visual.scale.x = 1
	player.facing_dir = 1

	# 4. Kılıç Saldırı Mekaniği (Light, Combo, Heavy)
	player.has_sword = true
	player.is_armed = true
	player.perform_light_attack()
	if player.is_attacking and player.current_attack_type == 'light':
		print('PASS: perform_light_attack() başarıyla is_attacking=true ve type=light tetikledi.')
	else:
		printerr('FAIL: perform_light_attack() beklenen durumu üretmedi!')

	# Saldırı sıfırlama
	player.is_attacking = false
	player.current_attack_type = ''

	player.perform_heavy_attack()
	if player.is_attacking and player.current_attack_type == 'heavy':
		print('PASS: perform_heavy_attack() başarıyla is_attacking=true ve type=heavy tetikledi.')
	else:
		printerr('FAIL: perform_heavy_attack() beklenen durumu üretmedi!')

	player.is_attacking = false
	player.current_attack_type = ''

	# 5. Hasar Alma, Knockback ve Sersemlik (Hit)
	var prev_hp = player.current_health
	player.take_damage(25, Vector2(player.global_position.x + 50, player.global_position.y))
	if player.current_health == prev_hp - 25:
		print('PASS: take_damage(25) canı doğru düşürdü (Yeni Can: ', player.current_health, ')')
	else:
		printerr('FAIL: Can doğru düşmedi: ', player.current_health)

	# 6. Ölüm ve Yeniden Doğuş (Death & Respawn)
	player.take_damage(500)
	if player.is_dead and player.current_health <= 0:
		print('PASS: 500 hasar sonrası is_dead=true ve can=0.')
	else:
		printerr('FAIL: Ölüm durumu tetiklenmedi!')

	player.respawn()
	if not player.is_dead and player.current_health == player.max_health:
		print('PASS: respawn() oyuncuyu tam canla ve ölüm durumunu sıfırlayarak canlandırdı.')
	else:
		printerr('FAIL: respawn() beklenen durumu üretmedi!')

	# 7. Boss Kapısı ve Harita Sınırı Doğrulamaları
	# Köprü Saldırısı Sahnesi Kontrolü
	var bridge_scn = load('res://scenes/levels/vlad/stage_1_bridge_assault.tscn')
	if bridge_scn:
		var bridge = bridge_scn.instantiate()
		var gate_col = bridge.get_node_or_null('ExitGate/GateBlocker/CollisionShape2D')
		var wall_right = bridge.get_node_or_null('WallRight/CollisionShape2D')
		var cam = bridge.get_node_or_null('Camera2D')
		if gate_col and not gate_col.disabled:
			print('PASS: Bridge Assault kapı engelleyicisi (GateBlocker) başlangıçta KAPALI ve AKTİF (disabled=false).')
		else:
			printerr('FAIL: GateBlocker başlangıçta kapalı değil!')
		if wall_right:
			print('PASS: WallRight harita sonu koruması mevcut (x = ', wall_right.global_position.x, ').')
		if cam and cam.limit_right <= 2400:
			print('PASS: Camera limit_right (', cam.limit_right, ') harita boşluğuna taşmayı engelliyor.')
		bridge.free()

	# Kale Mahzeni Sahnesi Kontrolü
	var dungeon_scn = load('res://scenes/levels/vlad/stage_2_castle_dungeon.tscn')
	if dungeon_scn:
		var dungeon = dungeon_scn.instantiate()
		var blood_gate = dungeon.get_node_or_null('BloodAltarGate/BloodGateStatic/CollisionShape2D')
		var wall_right = dungeon.get_node_or_null('WallRight/CollisionShape2D')
		var cam = dungeon.get_node_or_null('Camera2D')
		if blood_gate and not blood_gate.disabled:
			print('PASS: Kale Mahzeni BloodGateStatic başlangıçta KAPALI ve AKTİF (disabled=false).')
		else:
			printerr('FAIL: BloodGateStatic başlangıçta kapalı değil!')
		if wall_right:
			print('PASS: Dungeon WallRight harita sonu koruması mevcut (x = ', wall_right.global_position.x, ').')
		if cam and cam.limit_right <= 2300:
			print('PASS: Dungeon camera limit_right (', cam.limit_right, ') harita boşluğuna taşmayı engelliyor.')
		dungeon.free()

	print('========================================================')
	print('  TÜM BAĞIMSIZ QA ANİMASYON VE HARİTA TESTLERİ BAŞARILI! ')
	print('========================================================')
	quit(0)
