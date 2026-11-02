extends SceneTree

# Yamalı Dünya — Gerçek Sahne Kamp Ateşi ve 2 Tam Loop Yakalama Aracı (Aşama 4)
# - İkinci AudioManager OLUŞTURMAZ, mevcut autoload /root/AudioManager'ı kullanır.
# - Gerçek sahne (stage_1_forest_camp.tscn) ve gerçek CampfireCheckpoint düğümünü çalıştırır.
# - En az 2 tam loop (25.0 saniye) kayıt alır, playback position ve loop sürekliliğini doğrular.

const OUT_DIR := "qa/audio/captures"
const SCENE_PATH := "res://scenes/levels/vlad/stage_1_forest_camp.tscn"
const SAMPLE_RATE := 44100

var capture: AudioEffectCapture
var telemetry: Dictionary = {
	"loop_positions": [],
	"playback_advancement": [],
	"loop_wraps_detected": 0
}


func _init() -> void:
	print("[CampfireQA] Gerçek sahne kamp ateşi yakalama aracı başlatılıyor...")
	call_deferred("_run_capture")


func _run_capture() -> void:
	# 1. Sahneyi yükle
	var ps: PackedScene = load(SCENE_PATH)
	if not ps:
		printerr("[CampfireQA] Sahne bulunamadı: ", SCENE_PATH)
		quit(1)
		return

	var scene := ps.instantiate()
	root.add_child(scene)
	current_scene = scene

	# 2. Gerçek sahnede CampfireCheckpoint objesini bul
	var campfire := scene.find_child("CampfireCheckpoint", true, false) as CampfireCheckpoint
	if not campfire:
		printerr("[CampfireQA] CampfireCheckpoint düğümü bulunamadı!")
		quit(1)
		return

	print("[CampfireQA] Gerçek CampfireCheckpoint bulundu: pos=%s" % campfire.global_position)

	# 3. Oyuncuyu/dinleyiciyi tam kamp ateşinin yanına konumlandır
	var player = scene.find_child("CombatPlayer", true, false)
	if not player:
		player = scene.find_child("Player", true, false)
	if player:
		player.global_position = campfire.global_position
		print("[CampfireQA] Dinleyici (Oyuncu) kamp ateşinin yanına yerleştirildi.")

	# 4. Kamp ateşini yak
	campfire.ignite_and_rest(player)
	await process_frame
	await process_frame

	var emitter = campfire.audio_emitter
	print("[CampfireQA] Emitter oluşturuldu: ", emitter != null)

	# 5. Master Bus'a AudioEffectCapture ekle
	capture = AudioEffectCapture.new()
	var master_bus_idx := AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(master_bus_idx, capture)

	# ------------------------------------------------------------------------
	# KAYIT B: Gerçek Kamp Ateşi (İzole - Yalnızca SFX Bus, en az 2 tam loop = 25s)
	# ------------------------------------------------------------------------
	print("[CampfireQA] --- KAYIT B: Gerçek Kamp Ateşi (25.0s, 2+ tam döngü) başlıyor ---")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Ambience"), true)

	await _record_with_telemetry("campfire_emitter_2loops.wav", 25.0, emitter)

	# ------------------------------------------------------------------------
	# KAYIT C: Gerçek Oyun Miksajı (Kamp ateşi + Orman ortamı + Müzik = 15.0s)
	# ------------------------------------------------------------------------
	print("[CampfireQA] --- KAYIT C: Gerçek Oyun Miksajı (Master Bus) başlıyor ---")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Ambience"), false)

	await _record_stream("campfire_full_mix.wav", 15.0)

	# Telemetriyi JSON olarak kaydet
	var f_tel := FileAccess.open("res://" + OUT_DIR + "/campfire_loop_telemetry.json", FileAccess.WRITE)
	if f_tel:
		f_tel.store_string(JSON.stringify(telemetry, "\t"))
		f_tel.close()

	print("[CampfireQA] Telemetri kaydedildi: %d döngü sarımı tespit edildi." % telemetry["loop_wraps_detected"])
	quit(0)


func _record_with_telemetry(filename: String, duration_s: float, emitter: Node) -> void:
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
		if sample_timer >= 0.1 and emitter and "_player" in emitter and is_instance_valid(emitter._player):
			sample_timer = 0.0
			var cur_pos: float = emitter._player.get_playback_position()
			telemetry["playback_advancement"].append(round(cur_pos * 1000.0) / 1000.0)
			if last_pos > 8.0 and cur_pos < 2.0:
				telemetry["loop_wraps_detected"] += 1
				print("[CampfireQA] DÖNGÜ SARIMI TESPİT EDİLDİ! (Önceki: %.2fs -> Şimdiki: %.2fs, Toplam Sarım: %d)" % [last_pos, cur_pos, telemetry["loop_wraps_detected"]])
			last_pos = cur_pos

	_save_wav(OUT_DIR + "/" + filename, chunks, total_samples)
	print("[CampfireQA] Kaydedildi: %s (%d sample, %.2f saniye)" % [filename, total_samples, float(total_samples) / SAMPLE_RATE])


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
