extends Node

## res://scripts/autoloads/audio_manager.gd
## Story 2D-110: Merkezi Ses Yöneticisi (AudioManager)
## Story 2D-111: Duruma Göre Değişen Müzik Katmanları (Adaptive Music & Layers)
## - Master, Music, SFX, Dialogue ve Ambience bağımsız ses yolları (AudioBus)
## - Efekt havuzlama (Pooling) ve eşzamanlı ses sınırı yönetimi (max_concurrent_sfx = 16)
## - Çift çalıcılı yumuşak müzik geçişi (cross-fade) ve sahne geçiş politikası
## - Dinamik müzik durumları (EXPLORATION, COMBAT, BOSS, VICTORY, DEFEAT)
## - Katmanlı müzik (Layered Audio) ve tam parça cross-fade desteği
## - Çatışma soğuma gecikmesi (Hysteresis) ile ani müzik kesintilerinin ve sıçramalarının önlenmesi
## - 4 Aşamalı boss temaları ve faz değişim entegrasyonu
## - Kulaklık/hoparlör seviye sıçramalarını önleyen ses seviyesi normalizasyonu
## - 2D konumsal ses desteği (play_sound_2d)
## - Güvenli ses çalma: Olmayan ses anahtarı oyunu çökertmez, hata ayıklama kaydı bırakır
## - Prosedürel ses sentezleme yedeği (harici ses dosyası olmasa bile zengin ses motoru)
## - Kalıcı ses seviyeleri (user://game_settings.json)

signal music_changed(track_key: String)
signal bus_volume_changed(bus_name: String, linear_volume: float)
signal music_state_changed(previous_state: MusicState, new_state: MusicState)
signal boss_phase_changed(phase_index: int)
signal combat_intensity_changed(intensity: float)

const SETTINGS_PATH: String = "user://game_settings.json"
const REQUIRED_BUSES: Array[String] = ["Master", "Music", "SFX", "Dialogue", "Ambience"]

enum MusicScenePolicy {
	MAINTAIN = 0,    ## Sahne değişse de mevcut müziği kesmeden devam ettir
	STOP = 1,        ## Sahne değişiminde müziği yumuşakça durdur
	AUTO_THEME = 2   ## Seviye türüne göre otomatik tema çal / cross-fade yap
}

enum MusicState {
	EXPLORATION = 0, ## Keşif modu (sakin, atmosferik tema)
	COMBAT = 1,      ## Çatışma modu (tempolu dövüş teması veya ek ritim katmanı)
	BOSS = 2,        ## Boss dövüşü modu (boss teması ve aşamalı fazlar)
	VICTORY = 3,     ## Zafer / Boss yenilgi teması
	DEFEAT = 4       ## Yenilgi / Oyuncu ölüm teması
}

enum CombatAudioMode {
	CROSSFADE = 0,   ## Çatışmada doğrudan tam çatışma parçasına geçiş yap
	LAYERED = 1      ## Keşif parçası çalarken üzerine ek ritim/perküsyon katmanı aç
}

@export var max_concurrent_sfx: int = 16
@export var music_policy: MusicScenePolicy = MusicScenePolicy.AUTO_THEME
@export var combat_audio_mode: CombatAudioMode = CombatAudioMode.CROSSFADE
@export var combat_cooldown_delay: float = 2.5 ## Çatışma bittikten sonra sakinleşme süresi (Hysteresis)

# Dinamik Müzik Durum Değişkenleri
var current_music_state: MusicState = MusicState.EXPLORATION
var _exploration_track_key: String = "menu_theme"
var _combat_track_key: String = "combat_theme"
var _current_boss_name: String = ""
var _current_boss_phase: int = 1

# Çatışma Takibi (Hysteresis)
var _active_combatants: Array[Node] = []
var _combat_cooldown_timer: float = 0.0

# Ses kayıtları (key -> AudioStream veya Callable)
var _sound_registry: Dictionary = {}

# SFX Havuzu
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
var _sword_slash_round_robin: int = 0
var _sword_hit_round_robin: int = 0
var _page_turn_round_robin: int = 0

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

# Katmanlı Müzik Çalıcısı (Layered Audio için ek perküsyon/ritim)
var _combat_layer_player: AudioStreamPlayer = null
var _combat_layer_tween: Tween = null
var _current_combat_layer_key: String = "combat_layer"

# Ortam ve Diyalog Çalıcıları (Çift Çalıcı ile Yumuşak Ambience Cross-Fade)
var _ambience_player_a: AudioStreamPlayer = null
var _ambience_player_b: AudioStreamPlayer = null
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
	_load_audio_assets_from_disk()
	load_audio_settings()


func _process(delta: float) -> void:
	# 1. Sahne Geçiş Kontrolü
	var tree := get_tree()
	if tree:
		var cur := tree.current_scene
		if cur != _last_scene:
			_on_scene_changed(cur)
			_last_scene = cur

	# 2. Çatışma Soğuma Sayacı (Hysteresis)
	if _combat_cooldown_timer > 0.0:
		_combat_cooldown_timer -= delta
		if _combat_cooldown_timer <= 0.0:
			_clean_dead_combatants()
			if current_music_state == MusicState.COMBAT and _active_combatants.is_empty():
				set_music_state(MusicState.EXPLORATION, 1.2)


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
	# Çift Müzik Çalıcıları
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.name = "MusicPlayerA"
	_music_player_a.bus = "Music"
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.name = "MusicPlayerB"
	_music_player_b.bus = "Music"
	add_child(_music_player_b)

	# Çatışma Katmanı Çalıcısı (Layered audio)
	_combat_layer_player = AudioStreamPlayer.new()
	_combat_layer_player.name = "CombatLayerPlayer"
	_combat_layer_player.bus = "Music"
	_combat_layer_player.volume_db = -80.0
	add_child(_combat_layer_player)

	# Ortam Çalıcıları (Çift Çalıcı ile Yumuşak Ambience Cross-Fade)
	_ambience_player_a = AudioStreamPlayer.new()
	_ambience_player_a.name = "AmbiencePlayerA"
	_ambience_player_a.bus = "Ambience"
	add_child(_ambience_player_a)

	_ambience_player_b = AudioStreamPlayer.new()
	_ambience_player_b.name = "AmbiencePlayerB"
	_ambience_player_b.bus = "Ambience"
	add_child(_ambience_player_b)

	_ambience_player = _ambience_player_a

	# Diyalog Çalıcısı
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
	var sound_to_play: Variant = sound
	if sound is String and sound == "page_turn":
		_page_turn_round_robin = (_page_turn_round_robin % 4) + 1
		var candidate_key := "page_turn_%d" % _page_turn_round_robin
		if has_sound(candidate_key):
			sound_to_play = candidate_key

	var stream := _resolve_stream(sound_to_play)
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

	_fill_procedural_if_needed(player, sound_to_play)
	return player


## Anti-fatigue ses varyasyonu: Pitch ve volume'e doğal mikro değişimler katar
func play_sfx_varied(sound: Variant, volume_db: float = 0.0, pitch_variance: float = 0.08, bus: String = "SFX") -> AudioStreamPlayer:
	var final_pitch: float = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	var final_vol: float = volume_db + randf_range(-0.5, 0.5)
	return play_sfx(sound, final_vol, final_pitch, bus)


## Kitap sayfası değiştirme sesi (4'lü Round-Robin varyasyon ve mikro perde değişkenliği)
func play_page_turn(volume_db: float = -2.0, pitch_variance: float = 0.04) -> AudioStreamPlayer:
	_page_turn_round_robin = (_page_turn_round_robin % 4) + 1
	var var_key := "page_turn_%d" % _page_turn_round_robin
	var final_key := var_key if has_sound(var_key) else "page_turn"
	var final_pitch: float = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	var final_vol: float = volume_db + randf_range(-0.35, 0.35)
	return play_sfx(final_key, final_vol, final_pitch, "SFX")


## Endüstri Standardı Katmanlı Kılıç Savurma (Dual-Layer: Whoosh + Transient Ring)
## - Katman 1 (Whoosh): Düşük-orta frekanslı aerodinamik hava sürtünmesi (0.00s)
## - Katman 2 (Ring): Yüksek frekanslı kristal çelik çınlaması (Transient Ring, ~15ms micro-offset)
## - 3'lü Round-Robin varyasyon ve ±%5 rastgele perde (pitch)
func play_sword_slash(volume_db: float = 0.0, pitch_variance: float = 0.05, micro_delay_ms: float = 15.0, specific_key: String = "") -> AudioStreamPlayer:
	var final_pitch: float = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	var final_vol: float = volume_db + randf_range(-0.35, 0.35)

	# Belirli bir saldırı türü (sol tık: sword_slash_1 / sword_slash_2, sağ tık: sword_slash_heavy) verilmişse doğrudan çal
	if not specific_key.is_empty() and has_sound(specific_key):
		var p_direct := play_sfx(specific_key, final_vol, final_pitch, "SFX")
		if micro_delay_ms > 0.0 and has_sound("sword_slash_ring") and is_inside_tree():
			var timer := get_tree().create_timer(micro_delay_ms / 1000.0)
			timer.timeout.connect(func():
				play_sfx("sword_slash_ring", final_vol - 6.0, final_pitch, "SFX")
			)
		return p_direct

	_sword_slash_round_robin = (_sword_slash_round_robin % 3) + 1
	var rr_idx: int = _sword_slash_round_robin

	# 1. Öncelik: Gerçek Stüdyo Kayıtları (sword_slash_1/2/3 veya sword_slash)
	var variant_key := "sword_slash_%d" % rr_idx
	var primary_key := variant_key if has_sound(variant_key) else ("sword_slash" if has_sound("sword_slash") else "")
	
	if not primary_key.is_empty():
		var p_main := play_sfx(primary_key, final_vol, final_pitch, "SFX")
		# İsteğe bağlı mikro-gecikmeli çelik transient katmanı (mikro detay ve katman uyumluluğu)
		if micro_delay_ms > 0.0 and has_sound("sword_slash_ring") and is_inside_tree():
			var timer := get_tree().create_timer(micro_delay_ms / 1000.0)
			timer.timeout.connect(func():
				play_sfx("sword_slash_ring", final_vol - 6.0, final_pitch, "SFX")
			)
		return p_main

	# 2. İkincil / Sentetik Çift Katman Yedek (Whoosh + Ring)
	var whoosh_key: String = ""
	for k in ["sword_slash_whoosh_%d" % rr_idx, "sword_slash_whoosh"]:
		if has_sound(k):
			whoosh_key = k
			break
			
	var ring_key: String = ""
	for k in ["sword_slash_ring_%d" % rr_idx, "sword_slash_ring"]:
		if has_sound(k):
			ring_key = k
			break

	if not whoosh_key.is_empty() and not ring_key.is_empty():
		var p_whoosh: AudioStreamPlayer = play_sfx(whoosh_key, final_vol - 1.0, final_pitch * randf_range(0.98, 1.02), "SFX")
		if micro_delay_ms > 0.0 and is_inside_tree():
			var timer := get_tree().create_timer(micro_delay_ms / 1000.0)
			var captured_ring := ring_key
			var captured_vol := final_vol
			var captured_pitch := final_pitch
			timer.timeout.connect(func():
				play_sfx(captured_ring, captured_vol, captured_pitch, "SFX")
			)
		else:
			play_sfx(ring_key, final_vol, final_pitch, "SFX")
		return p_whoosh

	return null


## Endüstri Standardı Katmanlı Kılıç Darbesi (Dual-Layer: Body Impact + Metal Armor Crunch)
## - Katman 1 (Thud): Tok kemik/et darbesi (anında patlar)
## - Katman 2 (Metal): Keskin zırh parçalama ve bıçak titreşimi
## - 3'lü Round-Robin varyasyon ve ±%5 rastgele perde (pitch)
func play_sword_hit(volume_db: float = 0.0, pitch_variance: float = 0.05) -> AudioStreamPlayer:
	_sword_hit_round_robin = (_sword_hit_round_robin % 3) + 1
	var rr_idx: int = _sword_hit_round_robin
	
	var final_pitch: float = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	var final_vol: float = volume_db + randf_range(-0.35, 0.35)

	# 1. Öncelik: Gerçek Stüdyo Darbe Kayıtları (sword_hit_1/2/3 veya sword_hit)
	var variant_key := "sword_hit_%d" % rr_idx
	var primary_key := variant_key if has_sound(variant_key) else ("sword_hit" if has_sound("sword_hit") else "")
	
	if not primary_key.is_empty():
		return play_sfx(primary_key, final_vol, final_pitch, "SFX")

	# 2. İkincil / Sentetik Çift Katman Yedek (Thud + Metal)
	var thud_key: String = ""
	for k in ["sword_hit_thud_%d" % rr_idx, "sword_hit_thud"]:
		if has_sound(k):
			thud_key = k
			break

	var metal_key: String = ""
	for k in ["sword_hit_metal_%d" % rr_idx, "sword_hit_metal"]:
		if has_sound(k):
			metal_key = k
			break

	if not thud_key.is_empty() and not metal_key.is_empty():
		var p_thud: AudioStreamPlayer = play_sfx(thud_key, final_vol, final_pitch, "SFX")
		play_sfx(metal_key, final_vol - 2.0, final_pitch * randf_range(0.96, 1.04), "SFX")
		return p_thud

	return null

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
		p.stop()
		p.stream = null
	for p2d in _sfx_2d_pool:
		p2d.stop()
		p2d.stream = null


func _exit_tree() -> void:
	stop_all_sfx()
	if _music_player_a:
		_music_player_a.stop()
		_music_player_a.stream = null
	if _music_player_b:
		_music_player_b.stop()
		_music_player_b.stream = null
	if _combat_layer_player:
		_combat_layer_player.stop()
		_combat_layer_player.stream = null
	if _ambience_player_a:
		_ambience_player_a.stop()
		_ambience_player_a.stream = null
	if _ambience_player_b:
		_ambience_player_b.stop()
		_ambience_player_b.stream = null
	if _dialogue_player:
		_dialogue_player.stop()
		_dialogue_player.stream = null


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


## Anti-fatigue 2D ses varyasyonu: Pitch ve volume'e mikro varyasyon katar
func play_sound_2d_varied(sound: Variant, global_pos: Vector2, parent_node: Node = null, volume_db: float = 0.0, max_dist: float = 600.0, pitch_variance: float = 0.08, bus: String = "SFX") -> AudioStreamPlayer2D:
	var final_vol: float = volume_db + randf_range(-0.5, 0.5)
	var p := play_sound_2d(sound, global_pos, parent_node, final_vol, max_dist, bus)
	if p:
		p.pitch_scale = clampf(randf_range(1.0 - pitch_variance, 1.0 + pitch_variance), 0.2, 4.0)
	return p


# ---------------------------------------------------------------------------
# 5. Müzik ve Yumuşak Çapraz Geçiş (Cross-Fade)
# ---------------------------------------------------------------------------
func play_music(sound: Variant, fade_in_duration: float = 0.8, volume_db: float = 0.0) -> void:
	crossfade_music(sound, fade_in_duration, volume_db)


func crossfade_music(sound: Variant, duration: float = 1.0, target_volume_db: float = 0.0) -> void:
	var key_str := str(sound)
	if key_str == _current_music_key and _active_music_player != null and _active_music_player.playing:
		# Parça zaten çalıyor; gereksiz baştan başlatma yapma, yalnızca hedef ses seviyesini yumuşat
		if _active_music_player.volume_db != target_volume_db:
			var tw := create_tween()
			tw.tween_property(_active_music_player, "volume_db", target_volume_db, maxf(duration, 0.1))
		return

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
# 6. Dinamik Müzik Durumları ve Katman Yönetimi (Story 2D-111)
# ---------------------------------------------------------------------------
func set_music_state(new_state: MusicState, transition_duration: float = 1.0) -> void:
	if new_state == current_music_state:
		return # Durum zaten aktif, parçayı gereksiz baştan başlatma

	var prev_state := current_music_state
	current_music_state = new_state
	music_state_changed.emit(prev_state, new_state)

	match new_state:
		MusicState.EXPLORATION:
			_mute_combat_layer(transition_duration)
			combat_intensity_changed.emit(0.0)
			crossfade_music(_exploration_track_key, maxf(transition_duration, 0.4), -6.0)

		MusicState.COMBAT:
			combat_intensity_changed.emit(1.0)
			if combat_audio_mode == CombatAudioMode.LAYERED:
				_unmute_combat_layer(transition_duration)
			else:
				_mute_combat_layer(0.3)
				crossfade_music(_combat_track_key, maxf(transition_duration, 0.3), -5.0)

		MusicState.BOSS:
			_mute_combat_layer(0.2)
			combat_intensity_changed.emit(1.5)
			var track_key := get_boss_phase_track_key(_current_boss_name, _current_boss_phase)
			crossfade_music(track_key, maxf(transition_duration, 0.5), -4.0)

		MusicState.VICTORY:
			_mute_combat_layer(0.2)
			combat_intensity_changed.emit(0.0)
			crossfade_music("victory_theme", maxf(transition_duration, 0.4), -4.0)

		MusicState.DEFEAT:
			_mute_combat_layer(0.2)
			combat_intensity_changed.emit(0.0)
			crossfade_music("defeat_theme", maxf(transition_duration, 0.5), -6.0)


func get_music_state() -> MusicState:
	return current_music_state


func set_exploration_theme(track_key: String) -> void:
	_exploration_track_key = track_key
	if current_music_state == MusicState.EXPLORATION:
		crossfade_music(track_key, 1.0, -6.0)


func set_combat_theme(track_key: String) -> void:
	_combat_track_key = track_key
	if current_music_state == MusicState.COMBAT and combat_audio_mode == CombatAudioMode.CROSSFADE:
		crossfade_music(track_key, 0.6, -5.0)


func set_combat_layer_key(layer_key: String) -> void:
	_current_combat_layer_key = layer_key


# --- Çatışma Olayları ve Soğuma Yönetimi (Hysteresis) ---
func on_combat_started(combatant: Node = null) -> void:
	if combatant and not _active_combatants.has(combatant):
		_active_combatants.append(combatant)
	_combat_cooldown_timer = 0.0

	# Boss savaşındayken müzik durumunu normal çatışmaya düşürme
	if current_music_state == MusicState.BOSS or current_music_state == MusicState.VICTORY:
		return

	if current_music_state != MusicState.COMBAT:
		set_music_state(MusicState.COMBAT, 0.5)


func on_combat_ended(combatant: Node = null, force: bool = false) -> void:
	if combatant:
		_active_combatants.erase(combatant)
	_clean_dead_combatants()

	if force:
		_active_combatants.clear()
		_combat_cooldown_timer = 0.0
		if current_music_state == MusicState.COMBAT:
			set_music_state(MusicState.EXPLORATION, 1.0)
		return

	if _active_combatants.is_empty():
		# Düşmanlar ölünce ani müzik kesilmesini önlemek için soğuma (hysteresis) başlat
		_combat_cooldown_timer = combat_cooldown_delay


func _clean_dead_combatants() -> void:
	var valid: Array[Node] = []
	for c in _active_combatants:
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			if "is_dead" in c and c.is_dead:
				continue
			valid.append(c)
	_active_combatants = valid


func get_active_combatant_count() -> int:
	_clean_dead_combatants()
	return _active_combatants.size()


# --- Boss Savaşı ve Faz Yönetimi ---
func on_boss_started(boss_name: String = "", initial_phase: int = 1) -> void:
	_current_boss_name = boss_name
	_current_boss_phase = maxi(1, initial_phase)
	set_music_state(MusicState.BOSS, 0.8)


func on_boss_phase_changed(phase_index: int) -> void:
	var target_phase = maxi(1, phase_index)
	if _current_boss_phase == target_phase and current_music_state == MusicState.BOSS:
		return

	_current_boss_phase = target_phase
	boss_phase_changed.emit(_current_boss_phase)

	if current_music_state == MusicState.BOSS:
		var track_key := get_boss_phase_track_key(_current_boss_name, _current_boss_phase)
		# Kulaklık ve hoparlör dengesi: Fazlar ilerledikçe artan dramatik güç (-4dB'den -2.5dB'ye)
		var phase_volumes := { 1: -4.0, 2: -3.5, 3: -3.0, 4: -2.5 }
		var target_vol: float = phase_volumes.get(_current_boss_phase, -3.5)
		crossfade_music(track_key, 0.8, target_vol)


func on_boss_defeated() -> void:
	_current_boss_name = ""
	_current_boss_phase = 1
	set_music_state(MusicState.VICTORY, 0.8)


func on_player_defeated() -> void:
	_active_combatants.clear()
	_combat_cooldown_timer = 0.0
	set_music_state(MusicState.DEFEAT, 0.8)


func register_boss_phase_theme(boss_name: String, phase: int, sound: Variant) -> void:
	var p := maxi(1, phase)
	var key := "%s_phase_%d" % [boss_name.to_lower(), p]
	if sound is AudioStream:
		register_sound(key, sound)
	elif sound is Callable:
		_sound_registry[key] = sound


func get_boss_phase_track_key(boss_name: String, phase: int) -> String:
	var p := maxi(1, phase)
	if not boss_name.is_empty():
		var named_key := "%s_phase_%d" % [boss_name.to_lower(), p]
		if has_sound(named_key):
			return named_key
		var named_theme := "%s_theme_p%d" % [boss_name.to_lower(), p]
		if has_sound(named_theme):
			return named_theme

	var generic_phase := "boss_phase_%d" % p
	if has_sound(generic_phase):
		return generic_phase

	var generic_theme := "boss_theme_p%d" % p
	if has_sound(generic_theme):
		return generic_theme

	return "vlad_theme"


# --- Katmanlı Ses (Layer) Yardımcıları ---
func _mute_combat_layer(duration: float = 0.5) -> void:
	if not _combat_layer_player:
		return
	if _combat_layer_tween and is_instance_valid(_combat_layer_tween):
		_combat_layer_tween.kill()

	_combat_layer_tween = create_tween()
	_combat_layer_tween.tween_property(_combat_layer_player, "volume_db", -80.0, maxf(duration, 0.05))
	_combat_layer_tween.tween_callback(func():
		if _combat_layer_player and current_music_state != MusicState.COMBAT:
			_combat_layer_player.stop()
	)


func _unmute_combat_layer(duration: float = 0.5, target_volume_db: float = -4.0) -> void:
	if not _combat_layer_player:
		return
	var stream := _resolve_stream(_current_combat_layer_key)
	if not stream:
		return

	if _combat_layer_tween and is_instance_valid(_combat_layer_tween):
		_combat_layer_tween.kill()

	if not _combat_layer_player.playing:
		_combat_layer_player.stream = stream
		_combat_layer_player.volume_db = -80.0
		_combat_layer_player.play()
		_fill_procedural_if_needed(_combat_layer_player, _current_combat_layer_key)

	_combat_layer_tween = create_tween()
	_combat_layer_tween.tween_property(_combat_layer_player, "volume_db", target_volume_db, maxf(duration, 0.05))


# ---------------------------------------------------------------------------
# 7. Ortam (Ambience) ve Diyalog (Dialogue)
# ---------------------------------------------------------------------------
func play_ambience(sound: Variant, fade_in_duration: float = 1.0, volume_db: float = 0.0) -> void:
	crossfade_ambience(sound, fade_in_duration, volume_db)


func crossfade_ambience(sound: Variant, duration: float = 1.0, target_volume_db: float = 0.0) -> void:
	var key_str := str(sound)
	if key_str == _current_ambience_key and _ambience_player != null and _ambience_player.playing:
		# Aynı ortam zaten çalıyor; ani seviye sıçraması olmadan hedef sesi yumuşat
		if _ambience_player.volume_db != target_volume_db:
			var tw := create_tween()
			tw.tween_property(_ambience_player, "volume_db", target_volume_db, maxf(duration, 0.1))
		return

	var stream := _resolve_stream(sound)
	if not stream:
		push_warning("AudioManager: Ortam sesi bulunamadı -> %s" % key_str)
		return

	if _ambience_tween and is_instance_valid(_ambience_tween):
		_ambience_tween.kill()

	var incoming: AudioStreamPlayer = _ambience_player_b if _ambience_player == _ambience_player_a else _ambience_player_a
	var outgoing: AudioStreamPlayer = _ambience_player

	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()
	_fill_procedural_if_needed(incoming, sound)

	_ambience_tween = create_tween().set_parallel(true)
	_ambience_tween.tween_property(incoming, "volume_db", target_volume_db, maxf(duration, 0.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if outgoing and outgoing.playing:
		_ambience_tween.tween_property(outgoing, "volume_db", -80.0, maxf(duration, 0.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_ambience_tween.chain().tween_callback(outgoing.stop)

	_ambience_player = incoming
	_current_ambience_key = key_str


func play_zone_ambience(zone_name: String, fade_duration: float = 1.0, volume_db: float = -6.0) -> void:
	var z := zone_name.to_lower()
	var sound_key := ""
	if z.contains("prehistoric") or z.contains("stone"):
		sound_key = "prehistoric_ambience"
	elif z.contains("vlad") or z.contains("wallachia") or z.contains("castle") or z.contains("throne"):
		sound_key = "vlad_ambience"
	elif z.contains("camp") or z.contains("raid") or z.contains("ottoman"):
		sound_key = "camp_ambience"
	else:
		sound_key = z

	crossfade_ambience(sound_key, fade_duration, volume_db)


func stop_ambience(fade_out_duration: float = 1.0) -> void:
	if not _ambience_player or not _ambience_player.playing:
		return
	if _ambience_tween and is_instance_valid(_ambience_tween):
		_ambience_tween.kill()

	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_ambience_player, "volume_db", -80.0, maxf(fade_out_duration, 0.05))
	_ambience_tween.tween_callback(func():
		if _ambience_player:
			_ambience_player.stop()
		_current_ambience_key = ""
	)


func get_current_ambience_key() -> String:
	return _current_ambience_key


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
# 8. Sahne Geçişlerinde Müzik Davranışı (Sahne Politikası)
# ---------------------------------------------------------------------------
func _on_scene_changed(new_scene: Node) -> void:
	if not new_scene:
		return

	# Sahne değişiminde çatışan düşman listesini ve sayaçları sıfırla
	on_combat_ended(null, true)
	_current_boss_name = ""
	_current_boss_phase = 1

	var path := new_scene.scene_file_path.to_lower()
	match music_policy:
		MusicScenePolicy.STOP:
			stop_music(0.4)
			stop_ambience(0.4)
		MusicScenePolicy.MAINTAIN:
			pass # Mevcut müzik aynen devam eder
		MusicScenePolicy.AUTO_THEME:
			if path.contains("main_menu"):
				set_exploration_theme("menu_theme")
				set_music_state(MusicState.EXPLORATION, 1.0)
				stop_ambience(0.5)
			elif path.contains("prehistoric") or path.contains("stoneage"):
				set_exploration_theme("prehistoric_theme")
				set_music_state(MusicState.EXPLORATION, 1.2)
				play_zone_ambience("prehistoric", 1.2, -6.0)
			elif path.contains("camp"):
				set_exploration_theme("vlad_theme")
				set_music_state(MusicState.EXPLORATION, 1.2)
				play_zone_ambience("camp", 1.2, -6.0)
			elif path.contains("vlad") or path.contains("throne"):
				set_exploration_theme("vlad_theme")
				set_music_state(MusicState.EXPLORATION, 1.2)
				play_zone_ambience("vlad", 1.2, -6.0)


# ---------------------------------------------------------------------------
# 9. Ses Seviyeleri ve Bağımsız Bus Kontrolleri
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
# 10. Ses Kaydı ve Prosedürel Ses Sentezi Fallback
# ---------------------------------------------------------------------------
func register_sound(key: String, stream: AudioStream) -> void:
	_sound_registry[key] = stream


func has_sound(key: String) -> bool:
	return _sound_registry.has(key)


func _load_audio_assets_from_disk() -> void:
	# 1. Otomatik Dizin Taraması: res://assets/audio/sfx/ altındaki tüm sesleri yükle
	var sfx_dir := DirAccess.open("res://assets/audio/sfx")
	if sfx_dir:
		sfx_dir.list_dir_begin()
		var file_name = sfx_dir.get_next()
		while not file_name.is_empty():
			if not sfx_dir.current_is_dir() and not file_name.ends_with(".import"):
				var ext = file_name.get_extension().to_lower()
				if ext in ["wav", "mp3", "ogg"]:
					var k = file_name.get_basename()
					var p = "res://assets/audio/sfx/" + file_name
					if ResourceLoader.exists(p):
						var res = load(p)
						if res is AudioStream:
							if res is AudioStreamWAV and (k == "campfire" or k == "torch" or k == "waterfall"):
								(res as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
							_sound_registry[k] = res
			file_name = sfx_dir.get_next()

	# 2. Otomatik Dizin Taraması: res://assets/audio/music/ altındaki tüm müzik ve ortam seslerini yükle
	var music_dir := DirAccess.open("res://assets/audio/music")
	if music_dir:
		music_dir.list_dir_begin()
		var m_file = music_dir.get_next()
		while not m_file.is_empty():
			if not music_dir.current_is_dir() and not m_file.ends_with(".import"):
				var ext = m_file.get_extension().to_lower()
				if ext in ["wav", "mp3", "ogg"]:
					var m_key = m_file.get_basename()
					var mp = "res://assets/audio/music/" + m_file
					if ResourceLoader.exists(mp):
						var res = load(mp)
						if res is AudioStream:
							if res is AudioStreamWAV:
								(res as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
							_sound_registry[m_key] = res
			m_file = music_dir.get_next()


func _resolve_stream(sound: Variant) -> AudioStream:
	if sound is AudioStream:
		return sound
	if sound is String:
		if sound.begins_with("res://"):
			if ResourceLoader.exists(sound):
				var loaded = load(sound)
				if loaded is AudioStream:
					return loaded
		if _sound_registry.has(sound):
			var entry = _sound_registry[sound]
			if entry is AudioStream:
				return entry
			elif entry is Callable:
				# Prosedürel generator hazırla
				var gen := AudioStreamGenerator.new()
				gen.mix_rate = 22050.0
				gen.buffer_length = 2.5 if sound == "bell_toll" else 1.0
				return gen

		var extensions: Array[String] = [".wav", ".mp3", ".ogg"]
		for ext in extensions:
			var sfx_path: String = "res://assets/audio/sfx/" + str(sound) + ext
			if ResourceLoader.exists(sfx_path):
				var res = load(sfx_path)
				if res is AudioStream:
					if res is AudioStreamWAV and (sound == "campfire" or sound == "torch" or sound == "torch_burn"):
						(res as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
					_sound_registry[sound] = res
					return res
			var music_path: String = "res://assets/audio/music/" + str(sound) + ext
			if ResourceLoader.exists(music_path):
				var res = load(music_path)
				if res is AudioStream:
					if res is AudioStreamWAV:
						(res as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
					_sound_registry[sound] = res
					return res
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

	# Kılıç Savurma (Slash) - Doğal aerodinamik çelik savrulması (Atari beepi yok)
	var slash_proc = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.18), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var norm := t / 0.18
			var noise := (randf() * 2.0 - 1.0)
			var sweep_freq := lerpf(1800.0, 450.0, norm * norm)
			var resonance := sin(t * sweep_freq * TAU) * 0.15
			var env := sin(PI * norm) * (1.0 - norm)
			var s := (noise * 0.65 + resonance) * env * 0.45
			pb.push_frame(Vector2(s, s))
	_sound_registry["sword_slash"] = slash_proc
	_sound_registry["sword_slash_1"] = slash_proc
	_sound_registry["sword_slash_2"] = slash_proc
	_sound_registry["sword_slash_3"] = slash_proc

	# Çift Katman 1: Hava Sürtünmesi (Whoosh - Kütle ve rüzgar hissi)
	var whoosh_proc = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.16), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var norm := t / 0.16
			var noise := (randf() * 2.0 - 1.0)
			var env := sin(PI * norm) ** 1.8
			var s := noise * env * 0.38
			pb.push_frame(Vector2(s, s))
	_sound_registry["sword_slash_whoosh"] = whoosh_proc
	_sound_registry["sword_slash_whoosh_1"] = whoosh_proc
	_sound_registry["sword_slash_whoosh_2"] = whoosh_proc
	_sound_registry["sword_slash_whoosh_3"] = whoosh_proc

	# Çift Katman 2: Kristal Çelik Tınısı (Transient Ring - Keskinlik patlaması)
	var ring_proc = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.22), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-18.0 * t)
			var steel := (sin(t * 1420.0 * TAU) * 0.38 + sin(t * 2840.0 * TAU) * 0.22) * env
			var spark := (randf() * 2.0 - 1.0) * exp(-70.0 * t) * 0.32
			var s := steel + spark
			pb.push_frame(Vector2(s, s))
	_sound_registry["sword_slash_ring"] = ring_proc
	_sound_registry["sword_slash_ring_1"] = ring_proc
	_sound_registry["sword_slash_ring_2"] = ring_proc
	_sound_registry["sword_slash_ring_3"] = ring_proc

	# Kılıç Vuruşu (Hit) - Tok gövde darbesi ve metalik titreşim
	var hit_proc = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.22), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var norm := t / 0.22
			var thud := sin(t * lerpf(120.0, 45.0, norm) * TAU) * 0.55 * exp(-18.0 * t)
			var crack := (randf() * 2.0 - 1.0) * exp(-50.0 * t) * 0.35
			var metal := sin(t * 1450.0 * TAU) * 0.15 * exp(-12.0 * t)
			var s := thud + crack + metal
			pb.push_frame(Vector2(s, s))
	_sound_registry["sword_hit"] = hit_proc
	_sound_registry["sword_hit_1"] = hit_proc
	_sound_registry["sword_hit_2"] = hit_proc
	_sound_registry["sword_hit_3"] = hit_proc

	# Çift Katman 1: Gövde/Kemik Tokluğu (Thud)
	var thud_proc = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.20), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var norm := t / 0.20
			var thud := sin(t * lerpf(110.0, 40.0, norm) * TAU) * 0.65 * exp(-20.0 * t)
			var crack := (randf() * 2.0 - 1.0) * exp(-45.0 * t) * 0.30
			var s := thud + crack
			pb.push_frame(Vector2(s, s))
	_sound_registry["sword_hit_thud"] = thud_proc
	_sound_registry["sword_hit_thud_1"] = thud_proc
	_sound_registry["sword_hit_thud_2"] = thud_proc
	_sound_registry["sword_hit_thud_3"] = thud_proc

	# Çift Katman 2: Zırh/Metal Parçalama (Metal Crunch)
	var metal_proc = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.24), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-15.0 * t)
			var metal := (sin(t * 1520.0 * TAU) * 0.35 + sin(t * 2650.0 * TAU) * 0.22) * env
			var scrape := (randf() * 2.0 - 1.0) * exp(-30.0 * t) * 0.25
			var s := metal + scrape
			pb.push_frame(Vector2(s, s))
	_sound_registry["sword_hit_metal"] = metal_proc
	_sound_registry["sword_hit_metal_1"] = metal_proc
	_sound_registry["sword_hit_metal_2"] = metal_proc
	_sound_registry["sword_hit_metal_3"] = metal_proc

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

	# Vlad / Gotik Kalesi Teması (Keşif Teması)
	_sound_registry["vlad_theme"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var organ := sin(t * 65.4 * TAU) * 0.3 + sin(t * 130.8 * TAU) * 0.15 + sin(t * 196.0 * TAU) * 0.1
			pb.push_frame(Vector2(organ, organ))

	# --- Story 2D-111: Durumsal Müzik & Katmanlar ---

	# Çatışma Ritim Katmanı (Layered Combat Percussion)
	_sound_registry["combat_layer"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var beat := fmod(t * 4.0, 1.0)
			var env := exp(-20.0 * beat)
			var noise := (randf() * 2.0 - 1.0) * 0.25
			var kick := sin(beat * 65.0 * TAU) * 0.35
			var s := (noise + kick) * env
			pb.push_frame(Vector2(s, s))

	# Normal Çatışma Teması (Driving Combat Battle)
	_sound_registry["combat_theme"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var step := int(fmod(t * 4.0, 4.0))
			var freqs := [110.0, 130.8, 146.8, 164.8]
			var base_f: float = freqs[step]
			var bass := sin(t * base_f * TAU) * 0.25
			var beat := fmod(t * 4.0, 1.0)
			var kick := sin(beat * 80.0 * TAU) * exp(-15.0 * beat) * 0.3
			var s := bass + kick
			pb.push_frame(Vector2(s, s))

	# Boss Faz 1: Ağır Gotik Org Teması
	var p1_func = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var s := (sin(t * 73.4 * TAU) * 0.3 + sin(t * 110.0 * TAU) * 0.2 + sin(t * 146.8 * TAU) * 0.15)
			pb.push_frame(Vector2(s, s))
	_sound_registry["boss_phase_1"] = p1_func
	_sound_registry["boss_theme_p1"] = p1_func

	# Boss Faz 2: Hızlanan Gerilim & Kromatik Org
	var p2_func = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var s := (sin(t * 77.8 * TAU) * 0.3 + sin(t * 155.6 * TAU) * 0.2 + sin(t * 233.1 * TAU) * 0.15)
			var pulse := sin(t * 6.0 * TAU) * 0.1
			pb.push_frame(Vector2(s + pulse, s + pulse))
	_sound_registry["boss_phase_2"] = p2_func
	_sound_registry["boss_theme_p2"] = p2_func

	# Boss Faz 3: Agresif Kurt / Yırtıcı Savaş Nabzı
	var p3_func = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var pulse := exp(-10.0 * fmod(t * 5.0, 1.0))
			var s := (sin(t * 87.3 * TAU) * 0.35 + sin(t * 174.6 * TAU) * 0.2) * pulse
			pb.push_frame(Vector2(s, s))
	_sound_registry["boss_phase_3"] = p3_func
	_sound_registry["boss_theme_p3"] = p3_func

	# Boss Faz 4: Final Yarasa / Kaotik Çan Kulesi Klimaksı
	var p4_func = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var step := int(fmod(t * 8.0, 4.0))
			var freqs := [146.8, 174.6, 220.0, 293.7]
			var s := sin(t * freqs[step] * TAU) * 0.25 + sin(t * 73.4 * TAU) * 0.2
			pb.push_frame(Vector2(s, s))
	_sound_registry["boss_phase_4"] = p4_func
	_sound_registry["boss_theme_p4"] = p4_func

	# Zafer Teması (Triumphant Fanfare)
	_sound_registry["victory_theme"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-2.0 * t)
			var s := (sin(t * 261.6 * TAU) * 0.3 + sin(t * 329.6 * TAU) * 0.25 + sin(t * 392.0 * TAU) * 0.2) * env
			pb.push_frame(Vector2(s, s))

	# Yenilgi Teması (Somber Defeat)
	_sound_registry["defeat_theme"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-1.5 * t)
			var s := (sin(t * 110.0 * TAU) * 0.3 + sin(t * 130.8 * TAU) * 0.2) * env
			pb.push_frame(Vector2(s, s))

	# --- Story 2D-112: Konumsal Sesler ve Bölgesel Ortam Sesleri ---

	# Tarih Öncesi Vadi Ambiyansı (Rüzgâr, Uğultu ve Yankılanan Kuş Sesleri)
	_sound_registry["prehistoric_ambience"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var wind := (randf() * 2.0 - 1.0) * 0.08 * (0.6 + 0.4 * sin(t * 0.4 * TAU))
			var rumble := sin(t * 42.0 * TAU) * 0.12
			var chirp := sin(t * 1250.0 * TAU) * exp(-15.0 * fmod(t * 2.5, 1.0)) * 0.05
			var s := wind + rumble + chirp
			pb.push_frame(Vector2(s, s))

	# Gotik Eflak / Vlad Kalesi Ambiyansı (Gece Esintisi, Cırcır Böcekleri, Su Damlası)
	_sound_registry["vlad_ambience"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var gust := (randf() * 2.0 - 1.0) * 0.06 * (0.5 + 0.5 * sin(t * 0.5 * TAU))
			var cricket := sin(t * 4500.0 * TAU) * sin(t * 30.0 * TAU) * 0.04
			var drip := sin(t * 900.0 * TAU) * exp(-40.0 * fmod(t * 1.2, 1.0)) * 0.06
			var s := gust + cricket + drip
			pb.push_frame(Vector2(s, s))
	_sound_registry["wallachia_ambience"] = _sound_registry["vlad_ambience"]

	# Ordugâh Gece Baskını Ambiyansı (Ateş Korları, Uğultu ve Esinti)
	_sound_registry["camp_ambience"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var breeze := (randf() * 2.0 - 1.0) * 0.07 * (0.7 + 0.3 * sin(t * 0.8 * TAU))
			var crackle := (1.0 if randf() < 0.008 else 0.0) * (randf() * 2.0 - 1.0) * 0.35
			var low_fire := sin(t * 58.0 * TAU) * 0.08
			var s := breeze + crackle + low_fire
			pb.push_frame(Vector2(s, s))

	# 2D Konumsal Meşale Sesi (Torch)
	_sound_registry["torch"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.5), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var flutter := (randf() * 2.0 - 1.0) * 0.15 * (0.8 + 0.2 * sin(t * 5.0 * TAU))
			var crackle := (1.0 if randf() < 0.015 else 0.0) * 0.3
			var s := flutter + crackle
			pb.push_frame(Vector2(s, s))

	# 2D Konumsal Kamp Ateşi Sesi (Campfire)
	_sound_registry["campfire"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.6), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var rumble := (randf() * 2.0 - 1.0) * 0.22 * (0.8 + 0.2 * sin(t * 3.5 * TAU))
			var pop := ((randf() * 2.0 - 1.0) * 0.5) if randf() < 0.02 else 0.0
			var s := rumble + pop
			pb.push_frame(Vector2(s, s))

	# Kontrol Noktası Aktivasyonu (Bright Chime & Ascending Harmonics)
	_sound_registry["checkpoint_activated"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.4), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-8.0 * t)
			var s := (sin(t * 523.25 * TAU) * 0.25 + sin(t * 659.25 * TAU) * 0.25 + sin(t * 783.99 * TAU) * 0.25) * env
			pb.push_frame(Vector2(s, s))

	# Dinlenme / Can Yenilenme (Warm Soothing Wave)
	_sound_registry["rest_heal"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.35), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := sin(PI * t / 0.35)
			var s := (sin(t * 440.0 * TAU) * 0.3 + sin(t * 880.0 * TAU) * 0.15) * env
			pb.push_frame(Vector2(s, s))

	# Story 2D-132: Tuzaklar ve Dinamik Platformlar Sesleri

	# Kazıklı Zemin / Fırlama Sesi (Spike Trap - Yaylı Fırlama Mekanizması)
	_sound_registry["spike_trap"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.25), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-25.0 * t)
			var spring := sin(t * 1200.0 * TAU) * 0.45 * env
			var scrape := (randf() * 2.0 - 1.0) * 0.3 * exp(-35.0 * t)
			var stone := sin(t * 110.0 * TAU) * 0.4 * exp(-15.0 * t)
			var s := spring + scrape + stone
			pb.push_frame(Vector2(s, s))

	# Sallanan Giyotin / Sarkaç Bıçağı Rüzgârı (Ultra hafif, yumuşak hava süzülmesi)
	_sound_registry["guillotine_swing"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.35), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := sin(PI * t / 0.35) ** 2.2
			var whisper := (randf() * 2.0 - 1.0) * 0.08
			var s := whisper * env * 0.15
			pb.push_frame(Vector2(s, s))

	# Çöken Platform Çatlama / Sallanma Sesi (Platform Crumble)
	_sound_registry["platform_crumble"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.28), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-10.0 * t)
			var rumble := sin(t * 65.0 * TAU) * 0.4
			var crackle := (1.0 if randf() < 0.03 else 0.0) * (randf() * 2.0 - 1.0) * 0.5
			var s := (rumble + crackle) * env
			pb.push_frame(Vector2(s, s))

	# Çöken Platform Yeniden Birleşme Sesi (Platform Restore)
	_sound_registry["platform_restore"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.25), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-12.0 * (0.25 - t))
			var click := sin(t * 580.0 * TAU) * 0.35
			var stone := sin(t * 120.0 * TAU) * 0.25
			var s := (click + stone) * env
			pb.push_frame(Vector2(s, s))

	# Story 2D-130: Fırlatılabilir İkincil Eşyalar Sesleri

	# Eşya Fırlatma Rüzgârı (Throw Item)
	_sound_registry["throw_item"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.18), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := sin(PI * t / 0.18)
			var whoosh := (randf() * 2.0 - 1.0) * 0.32
			var swoosh := sin(t * (340.0 - 150.0 * t) * TAU) * 0.2
			var s := (whoosh + swoosh) * env
			pb.push_frame(Vector2(s, s))

	# Fırlatma Bıçağı İsabet / Saplanma Sesi (Knife Hit)
	_sound_registry["knife_hit"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.16), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-28.0 * t)
			var clang := sin(t * (880.0 - 250.0 * t) * TAU) * 0.45
			var scrape := (randf() * 2.0 - 1.0) * 0.2
			var s := (clang + scrape) * env
			pb.push_frame(Vector2(s, s))

	# Meşale Alev Patlaması / Yanma Sesi (Torch Burn)
	_sound_registry["torch_burn"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.32), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-8.0 * t)
			var crackle := (1.0 if randf() < 0.05 else 0.0) * (randf() * 2.0 - 1.0) * 0.4
			var hiss := (randf() * 2.0 - 1.0) * 0.25
			var rumble := sin(t * 110.0 * TAU) * 0.2
			var s := (crackle + hiss + rumble) * env
			pb.push_frame(Vector2(s, s))

	# Kutsal Su Kırılma ve Işıltı Sesi (Holy Water Shatter)
	_sound_registry["holy_water_shatter"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.35), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var glass_env := exp(-45.0 * t)
			var glass := (randf() * 2.0 - 1.0) * 0.35 * glass_env
			var chime_env := exp(-6.0 * t)
			var chime := (sin(t * 1250.0 * TAU) * 0.25 + sin(t * 1760.0 * TAU) * 0.18) * chime_env
			var s := glass + chime
			pb.push_frame(Vector2(s, s))

	# Mühimmat Bitti / Boş Tetik Sesi (Empty Ammo)
	_sound_registry["empty_ammo"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.08), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-40.0 * t)
			var click := sin(t * 1200.0 * TAU) * 0.35 * env
			pb.push_frame(Vector2(click, click))

	# Story 2D-121: Görev Günlüğü ve Hedef Takip Sesleri

	# Görev Aşaması Tamamlandı / Çan Sesi (Objective Complete)
	_sound_registry["objective_complete"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.4), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-8.0 * t)
			var chime := (sin(t * 987.77 * TAU) * 0.3 + sin(t * 1318.5 * TAU) * 0.25) * env
			pb.push_frame(Vector2(chime, chime))

	# Görev Tamamlandı Zafer Fanfarı (Quest Complete)
	_sound_registry["quest_complete"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.7), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-4.5 * t)
			# Triad arpej (C5 -> E5 -> G5 -> C6)
			var freq := 523.25
			if t > 0.15: freq = 659.25
			if t > 0.30: freq = 783.99
			if t > 0.45: freq = 1046.50
			var horn := sin(t * freq * TAU) * 0.3 * env
			var sparkle := sin(t * freq * 2.0 * TAU) * 0.15 * env
			var s := horn + sparkle
			pb.push_frame(Vector2(s, s))

	# Görev Günlüğü Açılış Parşömen Hışırtısı (Quest Log Open)
	_sound_registry["quest_log_open"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.15), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := sin(PI * t / 0.15)
			var paper := (randf() * 2.0 - 1.0) * 0.28 * env
			pb.push_frame(Vector2(paper, paper))

	# Görev Günlüğü Kapanış Sesi (Quest Log Close)
	_sound_registry["quest_log_close"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.12), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-22.0 * t)
			var paper := (randf() * 2.0 - 1.0) * 0.22 * env
			pb.push_frame(Vector2(paper, paper))

	# Story 2D-123: Envanter ve Eşya Kullanım Sesleri

	# Envanter Çantası Açılış Sesi (Inventory Open)
	_sound_registry["inventory_open"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.18), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := sin(PI * t / 0.18)
			var rustle := (randf() * 2.0 - 1.0) * 0.25 * env
			var buckle := sin(t * 1450.0 * TAU) * 0.12 * exp(-28.0 * t)
			var s := rustle + buckle
			pb.push_frame(Vector2(s, s))

	# Envanter Çantası Kapanış Sesi (Inventory Close)
	_sound_registry["inventory_close"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.14), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-20.0 * t)
			var thud := sin(t * 180.0 * TAU) * 0.28 * env
			var click := sin(t * 900.0 * TAU) * 0.15 * env
			var s := thud + click
			pb.push_frame(Vector2(s, s))

	# İksir İçme / Yudumlama Sesi (Potion Drink)
	_sound_registry["potion_drink"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.28), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-6.0 * t)
			var gulp := sin(t * (240.0 - t * 160.0) * TAU) * 0.35 * env
			var glass := sin(t * 1850.0 * TAU) * 0.12 * exp(-35.0 * t)
			var s := gulp + glass
			pb.push_frame(Vector2(s, s))

	# Eşya / Silah Kuşanma Sesi (Item Equip)
	_sound_registry["item_equip"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.22), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-12.0 * t)
			var metallic := (sin(t * 880.0 * TAU) * 0.25 + sin(t * 1760.0 * TAU) * 0.18) * env
			var snap := (randf() * 2.0 - 1.0) * 0.15 * exp(-40.0 * t)
			var s := metallic + snap
			pb.push_frame(Vector2(s, s))

	# Story 2D-122: Düşman Kodeksi ve Bilgi Arşivi Sesleri

	# Kodeks Kitabı Açılış Sesi (Codex Open)
	_sound_registry["codex_open"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.22), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := sin(PI * t / 0.22)
			var parchment := (randf() * 2.0 - 1.0) * 0.26 * env
			var bass_thud := sin(t * 130.0 * TAU) * 0.22 * exp(-14.0 * t)
			var s := parchment + bass_thud
			pb.push_frame(Vector2(s, s))

	# Kodeks Kitabı Kapanış Sesi (Codex Close)
	_sound_registry["codex_close"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.16), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-18.0 * t)
			var book_slam := sin(t * 140.0 * TAU) * 0.35 * env
			var leather := (randf() * 2.0 - 1.0) * 0.15 * env
			var s := book_slam + leather
			pb.push_frame(Vector2(s, s))

	# Yeni Bilgi / Canavar Kilidi Açıldı Gizem Çanı (Codex Unlock)
	_sound_registry["codex_unlock"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.45), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-5.5 * t)
			var tone1 := sin(t * 659.25 * TAU) * 0.25 # E5
			var tone2 := sin(t * 1046.50 * TAU) * 0.20 # C6
			var chime := (tone1 + tone2) * env
			pb.push_frame(Vector2(chime, chime))

	# 2D Konumsal Şelale Sesi (Waterfall)
	_sound_registry["waterfall"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.8), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var roar := (randf() * 2.0 - 1.0) * 0.28
			var rumble := sin(t * 85.0 * TAU) * 0.15 + sin(t * 130.0 * TAU) * 0.1
			var s := roar + rumble
			pb.push_frame(Vector2(s, s))

	# 2D Düşman Adım Sesi (Enemy Step)
	_sound_registry["enemy_step"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.12), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-35.0 * t)
			var thud := sin(t * (95.0 - 40.0 * t) * TAU) * 0.5
			var grit := (randf() * 2.0 - 1.0) * 0.2
			var s := (thud + grit) * env
			pb.push_frame(Vector2(s, s))

	# 2D Zindan Su Damlaması (Dungeon Drip)
	_sound_registry["dungeon_drip"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.15), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-25.0 * t)
			var freq := 850.0 - 250.0 * t
			var s := sin(t * freq * TAU) * env * 0.45
			pb.push_frame(Vector2(s, s))

	# Kılıç Karşılama / Yansıtma (Parry Clang) - Parlak metalik çınlama ve yüksek harmonikler
	_sound_registry["parry_clang"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.32), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-18.0 * t)
			var spark := (randf() * 2.0 - 1.0) * exp(-50.0 * t) * 0.35
			var metal := (sin(t * 880.0 * TAU) * 0.35 + sin(t * 1760.0 * TAU) * 0.25 + sin(t * 3520.0 * TAU) * 0.15) * env
			var s := spark + metal
			pb.push_frame(Vector2(s, s))

	# Oyuncu Ölüm Teması / Ağır Çöküş (Player Death)
	_sound_registry["player_death"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.65), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-4.0 * t)
			var bass := sin(t * (110.0 - 50.0 * t) * TAU) * 0.4 * env
			var sub := sin(t * 55.0 * TAU) * 0.35 * exp(-3.0 * t)
			var minor := (sin(t * 220.0 * TAU) * 0.15 + sin(t * 261.6 * TAU) * 0.15) * exp(-6.0 * t)
			var s := bass + sub + minor
			pb.push_frame(Vector2(s, s))

	# Boss Kükremesi / Dönüşüm Patlaması (Boss Roar) - Çift testere dişi, distorsiyon ve titreme
	_sound_registry["boss_roar"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.7), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var tremolo := 0.7 + 0.3 * sin(t * 16.0 * TAU)
			var saw1 := 2.0 * (fmod(t * 60.0, 1.0) - 0.5)
			var saw2 := 2.0 * (fmod(t * 63.5, 1.0) - 0.5)
			var noise := (randf() * 2.0 - 1.0) * 0.3
			var roar := clampf((saw1 + saw2 + noise) * 1.4, -1.0, 1.0)
			var env := sin(PI * clampf(t / 0.7, 0.0, 1.0)) * tremolo * 0.45
			var s := roar * env
			pb.push_frame(Vector2(s, s))

	# Kan Kalkanı (Blood Shield) - Titreşen kan büyüsü rezonansı
	_sound_registry["blood_shield"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.4), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-7.0 * t)
			var pulse := 0.8 + 0.2 * sin(t * 24.0 * TAU)
			var hum := sin(t * 82.4 * TAU) * 0.35
			var magic := (sin(t * 330.0 * TAU) * 0.2 + sin(t * 660.0 * TAU) * 0.15) * pulse
			var s := (hum + magic) * env
			pb.push_frame(Vector2(s, s))

	# Kan Dalgası Büyüsü (Blood Magic Wave) - Alçalan koyu büyü frekans taraması
	_sound_registry["blood_magic"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.45), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var sweep := lerpf(680.0, 120.0, clampf(t / 0.45, 0.0, 1.0))
			var env := exp(-6.0 * t)
			var tone := sin(t * sweep * TAU) * 0.3
			var hiss := (randf() * 2.0 - 1.0) * 0.25 * env
			var s := (tone + hiss) * env
			pb.push_frame(Vector2(s, s))

	# Sis Kaçışı (Vampire Mist Dash) - Buharlaşma rüzgârı ve gizemli fısıltı
	_sound_registry["mist_dash"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.3), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := sin(PI * clampf(t / 0.3, 0.0, 1.0))
			var vapor := (randf() * 2.0 - 1.0) * 0.35 * env
			var whoosh := sin(t * (280.0 - 120.0 * t) * TAU) * 0.25 * env
			var s := vapor + whoosh
			pb.push_frame(Vector2(s, s))

	# Kurtadam Pençe Vuruşu (Werewolf Claw) - Sert yırtıcı darbe ve pençe kesiği
	_sound_registry["werewolf_claw"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.22), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-18.0 * t)
			var slash := (randf() * 2.0 - 1.0) * 0.4 * env
			var growl := sin(t * (140.0 - 60.0 * t) * TAU) * 0.35 * env
			var s := slash + growl
			pb.push_frame(Vector2(s, s))

	# Kurtadam Yere Çakılma (Werewolf Leap Slam) - Ağır sarsıntılı zemin darbesi
	_sound_registry["werewolf_leap"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.35), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := exp(-12.0 * t)
			var thud := sin(t * (90.0 - 45.0 * t) * TAU) * 0.5 * env
			var debris := (randf() * 2.0 - 1.0) * 0.25 * exp(-20.0 * t)
			var s := thud + debris
			pb.push_frame(Vector2(s, s))

	# Ultrasonik Yarasa Çığlığı (Bat Ultrasonic Scream) - Yüksek frekanslı vibratolu dalga
	_sound_registry["bat_scream"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.4), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := sin(PI * clampf(t / 0.4, 0.0, 1.0))
			var vibrato := sin(t * 32.0 * TAU) * 180.0
			var freq := 2400.0 + vibrato - 400.0 * t
			var s := sin(t * freq * TAU) * 0.28 * env
			pb.push_frame(Vector2(s, s))

	# Yarasa Hava Dalışı (Bat Swoop Dive) - Yırtıcı kanat rüzgârı ve hava akımı
	_sound_registry["bat_dive"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.32), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := sin(PI * clampf(t / 0.32, 0.0, 1.0))
			var wind := (randf() * 2.0 - 1.0) * 0.3 * env
			var pitch := lerpf(900.0, 300.0, clampf(t / 0.32, 0.0, 1.0))
			var swoop := sin(t * pitch * TAU) * 0.25 * env
			var s := wind + swoop
			pb.push_frame(Vector2(s, s))

	# Ulu Çan Akustik Şok (Great Bell Toll) - Katkılı inharmonik katedral çanı
	_sound_registry["bell_toll"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.95), pb.get_frames_available())
		var f0 := 220.0
		var partials := [1.0, 1.2, 1.5, 2.0, 2.76, 4.07]
		var weights := [0.35, 0.25, 0.18, 0.12, 0.08, 0.05]
		var decays := [2.5, 3.2, 3.8, 4.5, 5.5, 7.0]
		for i in range(n):
			var t := float(i) / 22050.0
			var s := 0.0
			for p in range(partials.size()):
				s += weights[p] * sin(t * f0 * partials[p] * TAU) * exp(-decays[p] * t)
			var strike := (randf() * 2.0 - 1.0) * exp(-45.0 * t) * 0.2
			var final_val := (s + strike) * 0.7
			pb.push_frame(Vector2(final_val, final_val))

	# Kılıç İsyanı Karanlık Fısıltısı (Sword Rebellion Whisper) - Story 2D-125
	_sound_registry["sword_rebellion_whisper"] = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.45), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var env := sin(PI * clampf(t / 0.45, 0.0, 1.0))
			var dissonant := sin(t * 185.0 * TAU) * 0.2 + sin(t * 196.0 * TAU) * 0.2
			var low_hum := sin(t * 46.2 * TAU) * 0.35
			var hiss := (randf() * 2.0 - 1.0) * 0.15 * env
			var s := (dissonant + low_hum + hiss) * env
			pb.push_frame(Vector2(s, s))

	# Kapı Kırılma ve Parçalanma Sesi (Door Break / Kick)
	var door_break_proc = func(pb: AudioStreamGeneratorPlayback):
		var n := mini(int(22050.0 * 0.45), pb.get_frames_available())
		for i in range(n):
			var t := float(i) / 22050.0
			var thud := sin(t * lerpf(90.0, 32.0, t / 0.45) * TAU) * 0.65 * exp(-14.0 * t)
			var splinter := (randf() * 2.0 - 1.0) * exp(-22.0 * t) * 0.45
			var slam := sin(t * 110.0 * TAU) * 0.3 * exp(-8.0 * t)
			var s := thud + splinter + slam
			pb.push_frame(Vector2(s, s))
	_sound_registry["door_break"] = door_break_proc
	_sound_registry["door_kick"] = door_break_proc
	_sound_registry["gate_break"] = door_break_proc


# ---------------------------------------------------------------------------
# 11. Kalıcılık (user://game_settings.json)
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
