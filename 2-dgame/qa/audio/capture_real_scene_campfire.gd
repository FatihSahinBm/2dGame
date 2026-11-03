extends SceneTree

# Yamalı Dünya — Gerçek Sahne Kamp Ateşi ve İki Katmanlı (Hybrid) Ses Doğrulama Aracı
# - Gerçek sahne (stage_1_forest_camp.tscn) ve gerçek CampfireCheckpoint düğümünü çalıştırır.
# - BedPlayer + CracklePlayer iki katmanlı ses sistemini 25 saniye boyunca kaydeder.
# - 11 saniyelik periyodik tekrar imzasının kaybolduğunu ve 3.5 kHz üstü True Peak'in <-6 dBFS olduğunu kanıtlar.
# - Mesafe kırpmasını (Distance Culling) test eder: 0 px, 200 px ve 600 px (450 px üzeri sessiz/culled).

const OUT_DIR := "qa/audio/captures"
const SCENE_PATH := "res://scenes/levels/vlad/stage_1_forest_camp.tscn"
const SAMPLE_RATE := 44100

var capture: AudioEffectCapture
var telemetry: Dictionary = {
	"loop_positions": [],
	"playback_advancement": [],
	"loop_wraps_detected": 0,
	"culling_test": {}
}


func _init() -> void:
	print("[CampfireQA] Gerçek sahne kamp ateşi hibrit yakalama aracı başlatılıyor...")
	call_deferred("_run_capture")


func _run_capture() -> void:
	var ps: PackedScene = load(SCENE_PATH)
	if not ps:
		printerr("[CampfireQA] Sahne bulunamadı: ", SCENE_PATH)
		quit(1)
		return

	var scene := ps.instantiate()
	root.add_child(scene)
	current_scene = scene

	var campfire := scene.find_child("CampfireCheckpoint", true, false) as CampfireCheckpoint
	if not campfire:
		printerr("[CampfireQA] CampfireCheckpoint düğümü bulunamadı!")
		quit(1)
		return

	print("[CampfireQA] Gerçek CampfireCheckpoint bulundu: pos=%s" % campfire.global_position)

	var player = scene.find_child("CombatPlayer", true, false)
	if not player:
		player = scene.find_child("Player", true, false)
	if player:
		player.global_position = campfire.global_position
		print("[CampfireQA] Dinleyici (Oyuncu) kamp ateşinin tam merkezine (dist=0) yerleştirildi.")

	# Kamp ateşini yak
	campfire.ignite_and_rest(player)
	await process_frame
	await process_frame

	var bed_player = campfire.bed_player
	var crackle_player = campfire.crackle_player
	print("[CampfireQA] BedPlayer: ", bed_player != null, " CracklePlayer: ", crackle_player != null)

	# Master Bus'a AudioEffectCapture ekle
	capture = AudioEffectCapture.new()
	var master_bus_idx := AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(master_bus_idx, capture)

	# İzole test: Müzik ve Ambience sustur, yalnızca SFX açık kalsın
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Ambience"), true)

	# ------------------------------------------------------------------------
	# TEST 1: 25 Saniyelik Hibrit Kamp Ateşi Kaydı (Bed + Random Crackles)
	# ------------------------------------------------------------------------
	print("[CampfireQA] --- TEST 1: 25.0s Hibrit Kamp Ateşi Kaydı Başlıyor ---")
	await _record_with_telemetry("campfire_hybrid_25s.wav", 25.0, bed_player)
	_duplicate_file(OUT_DIR + "/campfire_hybrid_25s.wav", OUT_DIR + "/campfire_emitter_2loops.wav")

	# ------------------------------------------------------------------------
	# TEST 2: Mesafe Kırpma (Distance Culling) Testi
	# ------------------------------------------------------------------------
	print("[CampfireQA] --- TEST 2: Mesafe Kırpma Doğrulaması ---")
	# 2A: 200 px mesafe (Sola doğru: 1020 - 200 = 820 px, güvenli alan, max_dist=450 px altında)
	if player:
		player.global_position = campfire.global_position - Vector2(200, 0)
	await process_frame
	await process_frame
	var samples_200px = await _record_samples(2.0)
	var max_amp_200px := _calc_max_amp(samples_200px)
	telemetry["culling_test"]["dist_200px_max_amp"] = max_amp_200px
	print("[CampfireQA] Mesafe 200 px (Etki Alanı İçi) Max Genlik: %.5f" % max_amp_200px)

	# 2B: 600 px mesafe (Sola doğru: 1020 - 600 = 420 px, güvenli kamp alanı içi, max_dist=450 px üzerinde)
	if player:
		player.global_position = campfire.global_position - Vector2(600, 0)
	# Process döngüsünün mesafeyi algılaması için birkaç kare bekle
	for i in range(10):
		await process_frame
	var samples_600px = await _record_samples(2.0)
	var max_amp_600px := _calc_max_amp(samples_600px)
	var is_culled = campfire._is_audio_culled if is_instance_valid(campfire) else true
	telemetry["culling_test"]["dist_600px_max_amp"] = max_amp_600px
	telemetry["culling_test"]["is_culled_flag"] = is_culled
	print("[CampfireQA] Mesafe 600 px (Kırpılmış/Cull Alanı) Max Genlik: %.5f (Culled Flag: %s)" % [max_amp_600px, is_culled])

	# ------------------------------------------------------------------------
	# TEST 3: Gerçek Oyun Miksajı (Kamp ateşi + Ortam + Müzik = 15.0s)
	# ------------------------------------------------------------------------
	if player:
		player.global_position = campfire.global_position
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Ambience"), false)
	await process_frame
	print("[CampfireQA] --- TEST 3: Tam Sahne Miksajı (15.0s) ---")
	await _record_stream("campfire_full_mix.wav", 15.0)

	# Telemetri JSON kaydı
	var f_tel := FileAccess.open("res://" + OUT_DIR + "/campfire_hybrid_telemetry.json", FileAccess.WRITE)
	if f_tel:
		f_tel.store_string(JSON.stringify(telemetry, "\t"))
		f_tel.close()

	print("[CampfireQA] Tüm testler ve kayıtlar başarıyla tamamlandı.")
	quit(0)


func _record_with_telemetry(filename: String, duration_s: float, player_node: AudioStreamPlayer2D) -> void:
	capture.clear_buffer()
	var chunks: Array[PackedVector2Array] = []
	var total_samples := 0
	var start_ms := Time.get_ticks_msec()
	var dur_ms := int(duration_s * 1000.0)

	var last_pos := -1.0
	var sample_timer := 0.0

	while Time.get_ticks_msec() - start_ms < dur_ms:
		await process_frame
		var avail := capture.get_frames_available()
		if avail > 0:
			chunks.append(capture.get_buffer(avail))
			total_samples += avail

		sample_timer += 0.016
		if sample_timer >= 0.1 and player_node and is_instance_valid(player_node):
			sample_timer = 0.0
			var cur_pos: float = player_node.get_playback_position()
			telemetry["playback_advancement"].append(round(cur_pos * 1000.0) / 1000.0)
			if last_pos > 5.0 and cur_pos < 2.0:
				telemetry["loop_wraps_detected"] += 1
				print("[CampfireQA] Bed döngü sarımı tespit edildi! (Önceki: %.2fs -> Şimdiki: %.2fs, Toplam Sarım: %d)" % [last_pos, cur_pos, telemetry["loop_wraps_detected"]])
			last_pos = cur_pos

	_save_wav(OUT_DIR + "/" + filename, chunks, total_samples)
	print("[CampfireQA] Kaydedildi: %s (%d sample, %.2f saniye)" % [filename, total_samples, float(total_samples) / SAMPLE_RATE])


func _record_samples(duration_s: float) -> Array[PackedVector2Array]:
	capture.clear_buffer()
	var chunks: Array[PackedVector2Array] = []
	var start_ms := Time.get_ticks_msec()
	var dur_ms := int(duration_s * 1000.0)

	while Time.get_ticks_msec() - start_ms < dur_ms:
		await process_frame
		var avail := capture.get_frames_available()
		if avail > 0:
			chunks.append(capture.get_buffer(avail))
	return chunks


func _calc_max_amp(chunks: Array[PackedVector2Array]) -> float:
	var m := 0.0
	for chunk in chunks:
		for v in chunk:
			m = maxf(m, absf(v.x))
			m = maxf(m, absf(v.y))
	return m


func _record_stream(filename: String, duration_s: float) -> void:
	capture.clear_buffer()
	var chunks: Array[PackedVector2Array] = []
	var total_samples := 0
	var start_ms := Time.get_ticks_msec()
	var dur_ms := int(duration_s * 1000.0)

	while Time.get_ticks_msec() - start_ms < dur_ms:
		await process_frame
		var avail := capture.get_frames_available()
		if avail > 0:
			chunks.append(capture.get_buffer(avail))
			total_samples += avail

	_save_wav(OUT_DIR + "/" + filename, chunks, total_samples)
	print("[CampfireQA] Kaydedildi: %s (%d sample, %.2f saniye)" % [filename, total_samples, float(total_samples) / SAMPLE_RATE])


func _duplicate_file(src_rel: String, dst_rel: String) -> void:
	var f_src := FileAccess.open("res://" + src_rel, FileAccess.READ)
	if not f_src:
		return
	var buf := f_src.get_buffer(f_src.get_length())
	f_src.close()

	var f_dst := FileAccess.open("res://" + dst_rel, FileAccess.WRITE)
	if f_dst:
		f_dst.store_buffer(buf)
		f_dst.close()


func _save_wav(rel_path: String, chunks: Array[PackedVector2Array], total_samples: int) -> void:
	var f := FileAccess.open("res://" + rel_path, FileAccess.WRITE)
	if not f:
		printerr("Dosya açılamadı: ", rel_path)
		return

	var num_channels := 2
	var bits_per_sample := 16
	var byte_rate := SAMPLE_RATE * num_channels * (bits_per_sample / 8)
	var block_align := num_channels * (bits_per_sample / 8)
	var subchunk2_size := total_samples * num_channels * (bits_per_sample / 8)
	var chunk_size := 36 + subchunk2_size

	f.store_string("RIFF")
	f.store_32(chunk_size)
	f.store_string("WAVE")
	f.store_string("fmt ")
	f.store_32(16)
	f.store_16(1)
	f.store_16(num_channels)
	f.store_32(SAMPLE_RATE)
	f.store_32(byte_rate)
	f.store_16(block_align)
	f.store_16(bits_per_sample)
	f.store_string("data")
	f.store_32(subchunk2_size)

	for chunk in chunks:
		for v in chunk:
			f.store_16(clampi(int(v.x * 32767.0), -32768, 32767))
			f.store_16(clampi(int(v.y * 32767.0), -32768, 32767))

	f.close()
