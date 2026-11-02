extends SceneTree

# Yamalı Dünya — Master Bus Ses Yakalama Aracı (Aşama 5)
# Master Bus'a AudioEffectCapture ekleyerek gerçek motor miksini 44.1kHz 16-bit stereo PCM WAV olarak kaydeder.

const OUT_DIR := "qa/audio/captures"
const SAMPLE_RATE := 44100

var capture: AudioEffectCapture
var am: Node
var frames_recorded: Array[PackedVector2Array] = []
var total_frames := 0


func _init() -> void:
	print("[AudioCapture] Başlatılıyor...")
	call_deferred("_setup_and_run")


func _setup_and_run() -> void:
	# 1. Output klasörünü hazırla
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + OUT_DIR))

	# 2. AudioManager yükle
	var am_scene = load("res://scripts/autoloads/audio_manager.gd")
	if am_scene:
		am = Node.new()
		am.set_script(am_scene)
		root.add_child(am)
		am._ready()

	# 3. Master Bus'a AudioEffectCapture ekle
	capture = AudioEffectCapture.new()
	var master_bus_idx := AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(master_bus_idx, capture)

	print("[AudioCapture] Master Bus Capture efekti eklendi (Bus %d)" % master_bus_idx)

	# Test Senaryoları
	await _record_scenario("capture_campfire", 4.0, func():
		if am and am.has_method("play_sfx"):
			am.play_sfx("campfire", -6.0)
	)

	await _record_scenario("capture_torch", 4.0, func():
		if am and am.has_method("play_sfx"):
			am.play_sfx("torch", -6.0)
	)

	await _record_scenario("capture_ambience_prehistoric", 4.0, func():
		if am and am.has_method("play_music"):
			am.play_music("prehistoric_ambience", 0.0, -8.0)
	)

	await _record_scenario("capture_ambience_vlad", 4.0, func():
		if am and am.has_method("play_music"):
			am.play_music("vlad_ambience", 0.0, -8.0)
	)

	await _record_scenario("capture_sword_slashes", 3.0, func():
		if am and am.has_method("play_sword_slash"):
			for i in range(5):
				am.play_sword_slash(i % 2 == 1)
				var t_end = Time.get_ticks_msec() + 250
				while Time.get_ticks_msec() < t_end:
					await process_frame
	)

	print("[AudioCapture] Tüm ses yakalama senaryoları tamamlandı.")
	quit(0)


func _record_scenario(name: String, duration_s: float, trigger: Callable) -> void:
	print("[AudioCapture] Senaryo başlıyor: %s (%.1fs)" % [name, duration_s])
	capture.clear_buffer()
	if am and am.has_method("stop_all_sfx"):
		am.stop_all_sfx()
	if am and am.has_method("stop_music"):
		am.stop_music()

	await process_frame
	trigger.call()

	var gathered: Array[PackedVector2Array] = []
	var total_samples := 0
	var start_t := Time.get_ticks_msec()
	var dur_ms := int(duration_s * 1000.0)

	while Time.get_ticks_msec() - start_t < dur_ms:
		await process_frame
		var avail := capture.get_frames_available()
		if avail > 0:
			var buf := capture.get_buffer(avail)
			gathered.append(buf)
			total_samples += avail

	var out_path := OUT_DIR + "/" + name + ".wav"
	_save_wav(out_path, gathered, total_samples)
	print("[AudioCapture] Kaydedildi: %s (%d sample)" % [out_path, total_samples])


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

	# RIFF Header
	f.store_string("RIFF")
	f.store_32(chunk_size)
	f.store_string("WAVE")

	# fmt subchunk
	f.store_string("fmt ")
	f.store_32(16) # Subchunk1Size = 16 for PCM
	f.store_16(1)  # AudioFormat = 1 (PCM)
	f.store_16(num_channels)
	f.store_32(SAMPLE_RATE)
	f.store_32(byte_rate)
	f.store_16(block_align)
	f.store_16(bits_per_sample)

	# data subchunk
	f.store_string("data")
	f.store_32(subchunk2_size)

	# Samples
	for chunk in chunks:
		for v in chunk:
			var l := clampi(int(v.x * 32767.0), -32768, 32767)
			var r := clampi(int(v.y * 32767.0), -32768, 32767)
			f.store_16(l)
			f.store_16(r)

	f.close()
