extends Node

## res://scripts/autoloads/audio_manager.gd
## Story 2D-110: Merkezi Ses Yöneticisi (AudioManager)
## - Master, Music, SFX, Dialogue ve Ambience bağımsız ses yolları (AudioBus)
## - Efekt havuzlama (Pooling) ve eşzamanlı ses sınırı yönetimi
## - Çift çalıcılı yumuşak müzik geçişi (cross-fade) ve sahne geçiş politikası
## - 2D konumsal ses desteği (play_sound_2d)
## - Güvenli ses çalma: Olmayan ses anahtarı oyunu çökertmez, hata ayıklama kaydı bırakır
## - Prosedürel ses sentezleme yedeği (harici ses dosyası olmasa bile çalışan zengin sesler)
## - Kalıcı ses seviyeleri (user://game_settings.json)

signal music_changed(track_key: String)
signal bus_volume_changed(bus_name: String, linear_volume: float)

const SETTINGS_PATH: String = "user://game_settings.json"
const REQUIRED_BUSES: Array[String] = ["Master", "Music", "SFX", "Dialogue", "Ambience"]

enum MusicScenePolicy {
	MAINTAIN = 0,    ## Sahne değişse de mevcut müziği kesmeden devam ettir
	STOP = 1,        ## Sahne değişiminde müziği yumuşakça durdur
	AUTO_THEME = 2   ## Seviye türüne göre otomatik tema çal / cross-fade yap
}

@export var max_concurrent_sfx: int = 16
@export var music_policy: MusicScenePolicy = MusicScenePolicy.AUTO_THEME

# Ses kayıtları (key -> AudioStream veya Callable)
var _sound_registry: Dictionary = {}

# SFX Havuzu
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0

# 2D Ses Havuzu
var _sfx_2d_pool: Array[AudioStreamPlayer2D] = []
var _sfx_2d_index: int = 0
const POOL_2D_SIZE: int = 8

# Çift Müzik Çalıcı (Cross-fade için)
var _music_player_a: AudioStreamPlayer = null
var _music_player_b: AudioStreamPlayer = null
var _active_music_player: AudioStreamPlayer = null
var _current_music_key: String = ""
var _music_tween: Tween = null

# Ortam ve Diyalog Çalıcıları
var _ambience_player: AudioStreamPlayer = null
var _ambience_tween: Tween = null
var _current_ambience_key: String = ""
var _dialogue_player: AudioStreamPlayer = null

var _last_scene: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_init_players()
	_register_builtin_procedural_sounds()
	load_audio_settings()


func _process(_delta: float) -> void:
	var tree := get_tree()
	if not tree:
		return
	var cur := tree.current_scene
	if cur != _last_scene:
		_on_scene_changed(cur)
		_last_scene = cur


# ---------------------------------------------------------------------------
# 1. Ses Yolları (AudioBus) Kurulumu ve Doğrulama
# ---------------------------------------------------------------------------
func _ensure_audio_buses() -> void:
	for bus_name in REQUIRED_BUSES:
		if bus_name == "Master":
			continue
		var idx := AudioServer.get_bus_index(bus_name)
		if idx == -1:
			var new_idx := AudioServer.bus_count
			AudioServer.add_bus(new_idx)
			AudioServer.set_bus_name(new_idx, bus_name)
			AudioServer.set_bus_send(new_idx, "Master")


func has_bus(bus_name: String) -> bool:
	return AudioServer.get_bus_index(bus_name) != -1


# ---------------------------------------------------------------------------
# 2. Çalıcı Düğümlerin ve Havuzun (Pooling) Başlatılması
# ---------------------------------------------------------------------------
func _init_players() -> void:
	# Müzik çalıcıları
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.name = "MusicPlayerA"
	_music_player_a.bus = "Music"
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.name = "MusicPlayerB"
	_music_player_b.bus = "Music"
	add_child(_music_player_b)

	# Ortam çalıcısı
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = "Ambience"
	add_child(_ambience_player)

	# Diyalog çalıcısı
	_dialogue_player = AudioStreamPlayer.new()
	_dialogue_player.name = "DialoguePlayer"
	_dialogue_player.bus = "Dialogue"
	add_child(_dialogue_player)

	# SFX Havuzu
	for i in range(max_concurrent_sfx):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	# 2D SFX Havuzu
	for i in range(POOL_2D_SIZE):
		var p2d := AudioStreamPlayer2D.new()
		p2d.name = "SFXPlayer2D_%d" % i
		p2d.bus = "SFX"
		p2d.max_distance = 1200.0
		add_child(p2d)
		_sfx_2d_pool.append(p2d)


# ---------------------------------------------------------------------------
# 3. SFX Çalma ve Havuzlama (Pooling & Concurrency Management)
# ---------------------------------------------------------------------------
func play_sfx(sound: Variant, volume_db: float = 0.0, pitch_scale: float = 1.0, bus: String = "SFX") -> AudioStreamPlayer:
	var stream := _resolve_stream(sound)
	if not stream:
		push_warning("AudioManager: Ses anahtarı veya kaynak bulunamadı -> %s" % str(sound))
		return null

	var player := _get_available_sfx_player()
	if not player:
		return null

	player.stop()
	player.bus = bus if has_bus(bus) else "SFX"
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch_scale, 0.2, 4.0)
	player.play()

	_fill_procedural_if_needed(player, sound)
	return player


func _get_available_sfx_player() -> AudioStreamPlayer:
	# 1. Boşta (çalmayan) oyuncu ara
	for p in _sfx_pool:
		if not p.playing:
			return p

	# 2. Tüm oyuncular meşgulse: Round-robin ile en eskiyi yeniden kullan (recycle)
	var recycled: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % _sfx_pool.size()
	return recycled


func stop_all_sfx() -> void:
	for p in _sfx_pool:
		if p.playing:
			p.stop()
	for p2d in _sfx_2d_pool:
		if p2d.playing:
			p2d.stop()


# ---------------------------------------------------------------------------
# 4. 2D Konumsal Ses Çalma
# ---------------------------------------------------------------------------
func play_sound_2d(sound: Variant, global_pos: Vector2, parent_node: Node = null, volume_db: float = 0.0, max_dist: float = 1200.0, bus: String = "SFX") -> AudioStreamPlayer2D:
	var stream := _resolve_stream(sound)
	if not stream:
		push_warning("AudioManager: 2D ses anahtarı bulunamadı -> %s" % str(sound))
		return null

	var player: AudioStreamPlayer2D = null
	for p in _sfx_2d_pool:
		if not p.playing:
			player = p
			break

	if not player:
		player = _sfx_2d_pool[_sfx_2d_index]
		_sfx_2d_index = (_sfx_2d_index + 1) % _sfx_2d_pool.size()

	player.stop()
	player.bus = bus if has_bus(bus) else "SFX"
	player.stream = stream
	player.global_position = global_pos
	player.max_distance = max_dist
	player.volume_db = volume_db
	player.play()

	_fill_procedural_if_needed(player, sound)
	return player


# ---------------------------------------------------------------------------
# 5. Müzik ve Yumuşak Çapraz Geçiş (Cross-Fade)
# ---------------------------------------------------------------------------
func play_music(sound: Variant, fade_in_duration: float = 0.8, volume_db: float = 0.0) -> void:
	crossfade_music(sound, fade_in_duration, volume_db)


func crossfade_music(sound: Variant, duration: float = 1.0, target_volume_db: float = 0.0) -> void:
	var key_str := str(sound)
	if key_str == _current_music_key and _active_music_player != null and _active_music_player.playing:
		return # Aynı parça zaten çalıyor, kesintiye uğratma

	var stream := _resolve_stream(sound)
	if not stream:
		push_warning("AudioManager: Müzik anahtarı bulunamadı -> %s" % key_str)
		return

	if _music_tween and is_instance_valid(_music_tween):
		_music_tween.kill()

	var incoming: AudioStreamPlayer = _music_player_b if _active_music_player == _music_player_a else _music_player_a
	var outgoing: AudioStreamPlayer = _active_music_player

	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()
	_fill_procedural_if_needed(incoming, sound)

	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(incoming, "volume_db", target_volume_db, maxf(duration, 0.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if outgoing and outgoing.playing:
		_music_tween.tween_property(outgoing, "volume_db", -80.0, maxf(duration, 0.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_music_tween.chain().tween_callback(outgoing.stop)

	_active_music_player = incoming
	_current_music_key = key_str
	music_changed.emit(_current_music_key)


func stop_music(fade_out_duration: float = 0.8) -> void:
	if not _active_music_player or not _active_music_player.playing:
		return

	if _music_tween and is_instance_valid(_music_tween):
		_music_tween.kill()

	_music_tween = create_tween()
	_music_tween.tween_property(_active_music_player, "volume_db", -80.0, maxf(fade_out_duration, 0.05))
	_music_tween.tween_callback(func():
		if _active_music_player:
			_active_music_player.stop()
		_current_music_key = ""
	)


func get_current_music_key() -> String:
	return _current_music_key


# ---------------------------------------------------------------------------
# 6. Ortam (Ambience) ve Diyalog (Dialogue)
# ---------------------------------------------------------------------------
func play_ambience(sound: Variant, fade_in_duration: float = 1.0, volume_db: float = 0.0) -> void:
	var key_str := str(sound)
	if key_str == _current_ambience_key and _ambience_player.playing:
		return

	var stream := _resolve_stream(sound)
	if not stream:
		push_warning("AudioManager: Ortam sesi bulunamadı -> %s" % key_str)
		return

	if _ambience_tween and is_instance_valid(_ambience_tween):
		_ambience_tween.kill()

	_ambience_player.stream = stream
	_ambience_player.volume_db = -80.0
	_ambience_player.play()
	_fill_procedural_if_needed(_ambience_player, sound)

	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_ambience_player, "volume_db", volume_db, maxf(fade_in_duration, 0.05))
	_current_ambience_key = key_str


func stop_ambience(fade_out_duration: float = 1.0) -> void:
	if not _ambience_player or not _ambience_player.playing:
		return
	if _ambience_tween and is_instance_valid(_ambience_tween):
		_ambience_tween.kill()

	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_ambience_player, "volume_db", -80.0, maxf(fade_out_duration, 0.05))
	_ambience_tween.tween_callback(func():
		_ambience_player.stop()
		_current_ambience_key = ""
	)


func play_dialogue(sound: Variant, volume_db: float = 0.0) -> AudioStreamPlayer:
	var stream := _resolve_stream(sound)
	if not stream:
		return null
	_dialogue_player.stop()
	_dialogue_player.stream = stream
	_dialogue_player.volume_db = volume_db
	_dialogue_player.play()
	_fill_procedural_if_needed(_dialogue_player, sound)
	return _dialogue_player


# ---------------------------------------------------------------------------
# 7. Sahne Geçişlerinde Müzik Davranışı (Sahne Politikası)
# ---------------------------------------------------------------------------
func _on_scene_changed(new_scene: Node) -> void:
	if not new_scene:
		return

	var path := new_scene.scene_file_path.to_lower()
	match music_policy:
		MusicScenePolicy.STOP:
			stop_music(0.4)
		MusicScenePolicy.MAINTAIN:
			pass # Mevcut müzik aynen devam eder
		MusicScenePolicy.AUTO_THEME:
			if path.contains("main_menu"):
				crossfade_music("menu_theme", 1.0, -6.0)
			elif path.contains("prehistoric") or path.contains("stoneage"):
				crossfade_music("prehistoric_theme", 1.2, -8.0)
			elif path.contains("vlad") or path.contains("camp") or path.contains("throne"):
				crossfade_music("vlad_theme", 1.2, -8.0)


# ---------------------------------------------------------------------------
# 8. Ses Seviyeleri ve Bağımsız Bus Kontrolleri
# ---------------------------------------------------------------------------
func set_bus_volume_linear(bus_name: String, linear_vol: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		push_warning("AudioManager: Bilinmeyen ses bus'ı -> " + bus_name)
		return
	var clamped := clampf(linear_vol, 0.0, 1.0)
	var db := linear_to_db(maxf(clamped, 0.0001))
	AudioServer.set_bus_volume_db(idx, db)
	save_audio_settings()
	bus_volume_changed.emit(bus_name, clamped)


func get_bus_volume_linear(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	var db := AudioServer.get_bus_volume_db(idx)
	return db_to_linear(db)


func set_bus_volume_db(bus_name: String, db_vol: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, db_vol)
		save_audio_settings()
		bus_volume_changed.emit(bus_name, db_to_linear(db_vol))


func get_bus_volume_db(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	return AudioServer.get_bus_volume_db(idx) if idx != -1 else 0.0


func set_bus_mute(bus_name: String, mute: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_mute(idx, mute)
		save_audio_settings()


func is_bus_muted(bus_name: String) -> bool:
	var idx := AudioServer.get_bus_index(bus_name)
	return AudioServer.is_bus_mute(idx) if idx != -1 else false


# ---------------------------------------------------------------------------
# 9. Ses Kaydı ve Prosedürel Ses Sentezi Fallback
# ---------------------------------------------------------------------------
func register_sound(key: String, stream: AudioStream) -> void:
	_sound_registry[key] = stream


func has_sound(key: String) -> bool:
	return _sound_registry.has(key)


func _resolve_stream(sound: Variant) -> AudioStream:
	if sound is AudioStream:
		return sound
	if sound is String:
		if _sound_registry.has(sound):
			var entry = _sound_registry[sound]
			if entry is AudioStream:
				return entry
			elif entry is Callable:
				# Prosedürel generator hazırla
				var gen := AudioStreamGenerator.new()
				gen.mix_rate = 22050.0
				gen.buffer_length = 1.0
				return gen
	return null


func _fill_procedural_if_needed(player: Node, sound: Variant) -> void:
	if not (sound is String) or not _sound_registry.has(sound):
		return
	var entry = _sound_registry[sound]
	if not (entry is Callable):
		return

	var playback: AudioStreamGeneratorPlayback = null
	if player.has_method("get_stream_playback"):
		playback = player.get_stream_playback()
	if playback:
		entry.call(playback)


func _register_builtin_procedural_sounds() -> void:
	# UI Tıklama
	_sound_registry["ui_click"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.05), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-40.0 * t)
			var s := sin(t * 900.0 * TAU) * env * 0.4
			pb.push_frame(Vector2(s, s))

	# Zıplama
	_sound_registry["jump"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.12), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var freq := 220.0 + 350.0 * t
			var env := exp(-12.0 * t)
			var s := sin(t * freq * TAU) * env * 0.35
			pb.push_frame(Vector2(s, s))

	# Dash / Atılma
	_sound_registry["dash"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.16), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := sin(PI * t / 0.16)
			var noise := (randf() * 2.0 - 1.0) * env * 0.35
			pb.push_frame(Vector2(noise, noise))

	# Kılıç Savurma (Slash)
	_sound_registry["sword_slash"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.18), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := sin(PI * t / 0.18)
			var s := (sin(t * (400.0 - 180.0 * t) * TAU) * 0.3 + (randf() * 2.0 - 1.0) * 0.2) * env
			pb.push_frame(Vector2(s, s))

	# Kılıç Vuruşu (Hit)
	_sound_registry["sword_hit"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.14), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-25.0 * t)
			var s := (sin(t * 180.0 * TAU) * 0.5 + sin(t * 950.0 * TAU) * 0.25) * env
			pb.push_frame(Vector2(s, s))

	# Hasar Alma (Hurt)
	_sound_registry["player_hurt"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.2), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-15.0 * t)
			var s := (sin(t * (140.0 - 50.0 * t) * TAU) * 0.5) * env
			pb.push_frame(Vector2(s, s))

	# Menü Müziği Teması (Loopable Procedural Ambient)
	_sound_registry["menu_theme"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var s := (sin(t * 110.0 * TAU) * 0.2 + sin(t * 165.0 * TAU) * 0.1 + sin(t * 220.0 * TAU) * 0.05)
			pb.push_frame(Vector2(s, s))

	# Tarih Öncesi Vadi Teması
	_sound_registry["prehistoric_theme"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var bass := sin(t * 73.4 * TAU) * 0.25
			var pulse := sin(t * 146.8 * TAU) * 0.1 * sin(t * 2.0 * TAU)
			pb.push_frame(Vector2(bass + pulse, bass + pulse))

	# Vlad / Gotik Kalesi Teması
	_sound_registry["vlad_theme"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var organ := sin(t * 65.4 * TAU) * 0.3 + sin(t * 130.8 * TAU) * 0.15 + sin(t * 196.0 * TAU) * 0.1
			pb.push_frame(Vector2(organ, organ))


# ---------------------------------------------------------------------------
# 10. Kalıcılık (user://game_settings.json)
# ---------------------------------------------------------------------------
func load_audio_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not f:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		var audio_data: Dictionary = json.data.get("audio_settings", {})
		if audio_data.has("master_volume"):
			set_bus_volume_linear("Master", float(audio_data["master_volume"]))
		if audio_data.has("music_volume"):
			set_bus_volume_linear("Music", float(audio_data["music_volume"]))
		if audio_data.has("sfx_volume"):
			set_bus_volume_linear("SFX", float(audio_data["sfx_volume"]))
		if audio_data.has("dialogue_volume"):
			set_bus_volume_linear("Dialogue", float(audio_data["dialogue_volume"]))
		if audio_data.has("ambience_volume"):
			set_bus_volume_linear("Ambience", float(audio_data["ambience_volume"]))
	f.close()


func save_audio_settings() -> void:
	var existing: Dictionary = {}
	if FileAccess.file_exists(SETTINGS_PATH):
		var rf := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if rf:
			var json := JSON.new()
			if json.parse(rf.get_as_text()) == OK and json.data is Dictionary:
				existing = json.data
			rf.close()

	var audio_data := {
		"master_volume": get_bus_volume_linear("Master"),
		"music_volume": get_bus_volume_linear("Music"),
		"sfx_volume": get_bus_volume_linear("SFX"),
		"dialogue_volume": get_bus_volume_linear("Dialogue"),
		"ambience_volume": get_bus_volume_linear("Ambience")
	}
	existing["audio_settings"] = audio_data

	var wf := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if wf:
		wf.store_string(JSON.stringify(existing, "\t"))
		wf.close()
