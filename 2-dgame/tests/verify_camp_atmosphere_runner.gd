extends Node

## tests/verify_camp_atmosphere_runner.gd
## Story 2D-137: Osmanlı Ordugâhı Gece Baskını Atmosferi doğrulama testi

func _ready() -> void:
	print("\n========================================================")
	print("  TEST: Story 2D-137 Ordugâh Gece Baskını Atmosferi     ")
	print("========================================================")
	var ok: bool = true

	var scene: PackedScene = load("res://scenes/levels/vlad/stage_1_camp.tscn")
	if not scene:
		printerr("FAIL: stage_1_camp.tscn yüklenemedi!")
		get_tree().quit(1)
		return

	var camp = scene.instantiate()
	add_child(camp)
	await get_tree().process_frame
	await get_tree().process_frame

	var atmo = camp.get_node_or_null("NightRaidAtmosphere")
	if not atmo:
		printerr("FAIL: NightRaidAtmosphere sahnede bulunamadı!")
		get_tree().quit(1)
		return
	print("PASS: Atmosfer düğümü ordugâh sahnesinde mevcut.")

	# 1. Savaş silüetleri
	if atmo.get_silhouette_count() < 3:
		printerr("FAIL: Yeterli savaş silüeti yok: ", atmo.get_silhouette_count())
		ok = false
	else:
		print("PASS: Savaş silüetleri (", atmo.get_silhouette_count(), " grup) oluşturuldu.")

	# Tekrar kullanılabilirlik
	var s1 = atmo.create_silhouette("spearman", 1.0)
	var s2 = atmo.create_silhouette("fallen", -1.0)
	if not s1 or not s2 or s1.get_child_count() < 3:
		printerr("FAIL: create_silhouette tekrar kullanılabilir değil!")
		ok = false
	else:
		print("PASS: create_silhouette() ile yeniden kullanılabilir silüet üretilebiliyor.")
	s1.queue_free()
	s2.queue_free()

	# 2. Yangın / kıvılcım / rüzgâr
	if atmo.get_fire_count() < 2 or atmo.get_active_particle_count() <= 0:
		printerr("FAIL: Yangın/kıvılcım/rüzgâr öğeleri eksik!")
		ok = false
	else:
		print("PASS: Yangın (", atmo.get_fire_count(), "), kıvılcım ve rüzgâr parçacıkları aktif (", atmo.get_active_particle_count(), " parçacık).")

	# 3. Ses noktaları
	if atmo.get_audio_point_count() < 2:
		printerr("FAIL: Yaralı ambiyans ses noktaları eksik!")
		ok = false
	else:
		print("PASS: ", atmo.get_audio_point_count(), " yaralı asker/komutan ses noktası mevcut.")
	var played = atmo.play_wounded_cry(0)
	print("INFO: play_wounded_cry(0) -> ", played)

	# 4. Katman yönetimi (oyuncu okunabilirliği)
	var player = camp.get_node_or_null("CombatPlayer")
	var player_z: int = player.z_index if player else 0
	var max_z: int = atmo.get_max_layer_z()
	print("INFO: Atmosfer max z = ", max_z, ", oyuncu z = ", player_z)
	if max_z >= player_z:
		printerr("FAIL: Atmosfer öğeleri oyuncu/düşman katmanını örtebilir!")
		ok = false
	else:
		print("PASS: Tüm atmosfer öğeleri oyuncu/düşman/saldırı işaretlerinin arkasında (z < 0).")

	# Silüet opaklığı sınırı
	var alpha_ok: bool = true
	for n in atmo.find_children("*", "Polygon2D", true, false):
		if (n as Polygon2D).color.a > 0.4:
			alpha_ok = false
	if not alpha_ok:
		printerr("FAIL: Silüet opaklığı çok yüksek!")
		ok = false
	else:
		print("PASS: Silüet opaklığı düşük tutuldu (<= 0.4).")

	# 5. Kalite / yoğunluk azaltma
	atmo.quality = 2
	var high_count: int = atmo.get_active_particle_count()
	atmo.quality = 1
	var med_count: int = atmo.get_active_particle_count()
	atmo.quality = 0
	var low_count: int = atmo.get_active_particle_count()
	print("INFO: Parçacık sayıları HIGH=", high_count, " MEDIUM=", med_count, " LOW=", low_count)
	var low_hidden: bool = true
	for s in atmo.find_children("BattlePair_*", "Node2D", true, false):
		if (s as Node2D).visible:
			low_hidden = false
	if not (high_count > med_count and med_count > low_count) or not low_hidden:
		printerr("FAIL: Efekt yoğunluğu kademeli olarak azaltılamıyor!")
		ok = false
	else:
		print("PASS: Efekt yoğunluğu HIGH > MEDIUM > LOW olarak azaltılabiliyor (LOW'da silüetler gizli).")
	atmo.quality = 2

	# 6. Sahneden çıkınca temizlik
	camp.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(atmo):
		printerr("FAIL: Atmosfer sahneden çıkınca temizlenmedi!")
		ok = false
	else:
		print("PASS: Sahne kaldırılınca atmosfer öğeleri tamamen temizlendi.")

	# 7. Yalnızca ilgili sahnede aktif: diğer sahnelerde atmosfer düğümü yok
	var other = load("res://scenes/levels/vlad/stage_1_forest_camp.tscn").instantiate()
	add_child(other)
	await get_tree().process_frame
	if other.find_child("NightRaidAtmosphere", true, false):
		printerr("FAIL: Atmosfer ilgisiz sahnede de aktif!")
		ok = false
	else:
		print("PASS: Atmosfer yalnızca ordugâh sahnesinde aktif.")
	other.queue_free()
	await get_tree().process_frame

	print("========================================================")
	if ok:
		print("  SONUÇ: ORDUGÂH ATMOSFERİ TESTLERİ TAMAMEN BAŞARILI!   ")
		print("========================================================\n")
		get_tree().quit(0)
	else:
		printerr("  SONUÇ: BAZI ATMOSFER TESTLERİ BAŞARISIZ OLDU!   ")
		print("========================================================\n")
		get_tree().quit(1)

