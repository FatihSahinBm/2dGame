extends Node

## res://scripts/autoloads/weather_manager.gd
## Story 2D-149: Seviye Bazlı Hava Durumu Sistemi
## - Seviye türüne göre hava profili seçimi (Yağmur, Rüzgâr, Sis, Şimşek, Kül)
## - Ekran/çevre partikülleri ve şimşek-ses (ışık hızı - ses hızı gecikmesi) zamanlaması
## - Efekt yoğunluğunu azaltma veya kapatma seçeneği (OFF, LOW, MEDIUM, HIGH)
## - Sahne değişiminde kaynakların tam temizlenmesi ve sızma önleme
## - CinematicManager erişilebilirlik entegrasyonu (reduce_flashing ile flaş kapatma, reduce_motion ile sarsıntı kapatma)

signal weather_changed(profile: int, intensity: int)
signal lightning_struck(intensity: float)
signal thunder_played()

const SETTINGS_PATH: String = "user://game_settings.json"

enum Profile {
	CLEAR = 0,      ## Açık hava / efekt yok
	RAIN = 1,       ## Yağmur ve su damlacıkları
	WIND = 2,       ## Rüzgâr ve fırtına parçacıkları
	FOG = 3,        ## Sis / pus tabakası
	LIGHTNING = 4,  ## Şimşek fırtınası (yağmur + şimşek flaşı + gök gürültüsü)
	ASH = 5,        ## Kül ve yangın kıvılcımları (ordugâh baskını / yangın)
	CUSTOM = 6      ## Özel profil
}

enum Intensity {
	OFF = 0,        ## Efektler tamamen kapalı (%0)
	LOW = 1,        ## Düşük yoğunluk (%30)
	MEDIUM = 2,     ## Orta yoğunluk (%65)
	HIGH = 3        ## Yüksek yoğunluk (%100)
}

var current_profile: Profile = Profile.CLEAR
var current_intensity: Intensity = Intensity.HIGH

var _last_scene: Node = null
var _weather_canvas: CanvasLayer = null
var _emitters: Array[CPUParticles2D] = []
var _flash_rect: ColorRect = null
var _thunder_player: AudioStreamPlayer = null
var _lightning_timer: Timer = null
var _sound_delay_timer: Timer = null
var _active_tweens: Array[Tween] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func _process(_delta: float) -> void:
	var tree := get_tree()
	if not tree:
		return
	var cur := tree.current_scene
	if cur != _last_scene:
		_on_scene_changed(cur)
		_last_scene = cur


# ---------------------------------------------------------------------------
# Sahne Takibi ve Otomatik Profil Eşleme
# ---------------------------------------------------------------------------
func _on_scene_changed(new_scene: Node) -> void:
	clean_weather()
	if not new_scene:
		return

	var path := new_scene.scene_file_path.to_lower()
	if path.is_empty():
		return

	# Menüler, testler ve diyalog sahnelerinde hava durumu açılmaz (sahne dışına taşma önlenir)
	if path.contains("menu") or path.contains("tests/") or path.contains("dialog"):
		set_profile(Profile.CLEAR)
		return

	# Seviyeye göre profil seçimi
	if path.contains("stage_1_prehistoric_valley"):
		set_profile(Profile.LIGHTNING)
	elif path.contains("stage_2_trex_boss_arena"):
		set_profile(Profile.WIND)
	elif path.contains("stage_1_forest_camp") or path.contains("stage_1_camp"):
		set_profile(Profile.ASH)
	elif path.contains("stage_2_castle_dungeon"):
		set_profile(Profile.FOG)
	elif path.contains("stage_3_throne_room"):
		set_profile(Profile.LIGHTNING)
	elif path.contains("stoneage_"):
		set_profile(Profile.RAIN)
	else:
		set_profile(Profile.CLEAR)


# ---------------------------------------------------------------------------
# Profil ve Yoğunluk Yönetimi
# ---------------------------------------------------------------------------
func set_profile(profile: Profile, force_reload: bool = false) -> void:
	if current_profile == profile and not force_reload and _weather_canvas != null and is_instance_valid(_weather_canvas):
		return
	current_profile = profile
	_build_weather_layer()
	weather_changed.emit(int(current_profile), int(current_intensity))


func get_current_profile() -> Profile:
	return current_profile


func set_intensity(intensity: Intensity) -> void:
	current_intensity = intensity
	save_settings()
	if current_intensity != Intensity.OFF and (_weather_canvas == null or not is_instance_valid(_weather_canvas)) and current_profile != Profile.CLEAR:
		_build_weather_layer()
	else:
		_apply_intensity()
	weather_changed.emit(int(current_profile), int(current_intensity))


func get_intensity() -> Intensity:
	return current_intensity


func is_weather_active() -> bool:
	return current_profile != Profile.CLEAR and current_intensity != Intensity.OFF


func get_active_particle_count() -> int:
	var total := 0
	for e in _emitters:
		if is_instance_valid(e) and e.emitting:
			total += e.amount
	return total


# ---------------------------------------------------------------------------
# Hava Durumu Katmanı İnşası
# ---------------------------------------------------------------------------
func _build_weather_layer() -> void:
	clean_weather()

	if current_profile == Profile.CLEAR or current_intensity == Intensity.OFF:
		return

	_weather_canvas = CanvasLayer.new()
	_weather_canvas.layer = 12 # Oyun dünyasının üstünde, HUD'un (20+) altında
	add_child(_weather_canvas)

	# Flaş dikdörtgeni
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather_canvas.add_child(_flash_rect)

	# Gök gürültüsü ses çalıcısı
	_thunder_player = AudioStreamPlayer.new()
	_thunder_player.bus = "SFX"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 1.4
	_thunder_player.stream = gen
	_weather_canvas.add_child(_thunder_player)

	# Şimşek döngü zamanlayıcısı
	_lightning_timer = Timer.new()
	_lightning_timer.one_shot = true
	_lightning_timer.timeout.connect(_on_lightning_timer_timeout)
	_weather_canvas.add_child(_lightning_timer)

	# Işık-ses gecikme zamanlayıcısı
	_sound_delay_timer = Timer.new()
	_sound_delay_timer.one_shot = true
	_sound_delay_timer.timeout.connect(_on_sound_delay_timeout)
	_weather_canvas.add_child(_sound_delay_timer)

	# Profile göre partikül yayıcıları
	match current_profile:
		Profile.RAIN:
			_create_rain_emitter()
		Profile.WIND:
			_create_wind_emitter()
		Profile.FOG:
			_create_fog_emitter()
		Profile.ASH:
			_create_ash_emitter()
		Profile.LIGHTNING:
			_create_rain_emitter()
			_create_wind_emitter()
			_schedule_next_lightning()

	_apply_intensity()


var _rain_streak_texture: ImageTexture = null


func _get_rain_streak_texture() -> ImageTexture:
	if _rain_streak_texture:
		return _rain_streak_texture
	var img := Image.create(2, 22, false, Image.FORMAT_RGBA8)
	for y in range(22):
		var alpha: float = (float(y) / 22.0) * 0.85
		for x in range(2):
			img.set_pixel(x, y, Color(0.75, 0.88, 1.0, alpha))
	_rain_streak_texture = ImageTexture.create_from_image(img)
	return _rain_streak_texture


func _create_rain_emitter() -> void:
	var rain := CPUParticles2D.new()
	rain.name = "RainEmitter"
	rain.position = Vector2(640, -40)
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(850, 20)
	rain.texture = _get_rain_streak_texture()
	rain.direction = Vector2(0.18, 1.0)
	rain.spread = 2.0
	rain.gravity = Vector2(30, 850)
	rain.initial_velocity_min = 700.0
	rain.initial_velocity_max = 950.0
	rain.scale_amount_min = 1.0
	rain.scale_amount_max = 1.6
	rain.color = Color(0.8, 0.9, 1.0, 0.65)
	rain.lifetime = 1.0
	_weather_canvas.add_child(rain)
	_emitters.append(rain)


func _create_wind_emitter() -> void:
	var wind := CPUParticles2D.new()
	wind.name = "WindEmitter"
	wind.position = Vector2(-40, 360)
	wind.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	wind.emission_rect_extents = Vector2(20, 400)
	wind.direction = Vector2(1.0, 0.12)
	wind.spread = 12.0
	wind.gravity = Vector2(40, 20)
	wind.initial_velocity_min = 450.0
	wind.initial_velocity_max = 700.0
	wind.scale_amount_min = 2.0
	wind.scale_amount_max = 4.0
	wind.color = Color(0.85, 0.90, 0.95, 0.28)
	wind.lifetime = 1.8
	_weather_canvas.add_child(wind)
	_emitters.append(wind)


func _create_fog_emitter() -> void:
	var fog := CPUParticles2D.new()
	fog.name = "FogEmitter"
	fog.position = Vector2(640, 600)
	fog.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fog.emission_rect_extents = Vector2(740, 160)
	fog.direction = Vector2(1.0, 0.0)
	fog.spread = 15.0
	fog.gravity = Vector2(0, -10)
	fog.initial_velocity_min = 20.0
	fog.initial_velocity_max = 45.0
	fog.scale_amount_min = 14.0
	fog.scale_amount_max = 28.0
	fog.color = Color(0.72, 0.78, 0.85, 0.18)
	fog.lifetime = 3.5
	_weather_canvas.add_child(fog)
	_emitters.append(fog)


func _create_ash_emitter() -> void:
	var ash := CPUParticles2D.new()
	ash.name = "AshEmitter"
	ash.position = Vector2(640, 740)
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(740, 40)
	ash.direction = Vector2(0.5, -1.0)
	ash.spread = 25.0
	ash.gravity = Vector2(30, -50)
	ash.initial_velocity_min = 70.0
	ash.initial_velocity_max = 140.0
	ash.scale_amount_min = 2.0
	ash.scale_amount_max = 4.5
	ash.color = Color(1.0, 0.55, 0.2, 0.65)
	ash.lifetime = 2.4
	_weather_canvas.add_child(ash)
	_emitters.append(ash)


# ---------------------------------------------------------------------------
# Yoğunluk Ayarlaması (OFF, LOW, MEDIUM, HIGH)
# ---------------------------------------------------------------------------
func _apply_intensity() -> void:
	if current_intensity == Intensity.OFF:
		for e in _emitters:
			if is_instance_valid(e):
				e.emitting = false
		if _lightning_timer and is_instance_valid(_lightning_timer):
			_lightning_timer.stop()
		if _sound_delay_timer and is_instance_valid(_sound_delay_timer):
			_sound_delay_timer.stop()
		if _flash_rect and is_instance_valid(_flash_rect):
			_flash_rect.color.a = 0.0
		return

	var ratio := 1.0
	match current_intensity:
		Intensity.LOW:
			ratio = 0.30
		Intensity.MEDIUM:
			ratio = 0.65
		Intensity.HIGH:
			ratio = 1.0

	for e in _emitters:
		if is_instance_valid(e):
			e.emitting = true
			var base_amt := 60
			if e.name.contains("Rain"):
				base_amt = 150
			elif e.name.contains("Wind"):
				base_amt = 50
			elif e.name.contains("Fog"):
				base_amt = 25
			elif e.name.contains("Ash"):
				base_amt = 80
			e.amount = maxi(int(float(base_amt) * ratio), 4)

	if current_profile == Profile.LIGHTNING and _lightning_timer and is_instance_valid(_lightning_timer):
		if _lightning_timer.is_stopped():
			_schedule_next_lightning()


# ---------------------------------------------------------------------------
# Şimşek ve Gök Gürültüsü Zamanlaması (Işık Hızı / Ses Hızı Gecikmesi)
# ---------------------------------------------------------------------------
func _schedule_next_lightning() -> void:
	if not _lightning_timer or not is_instance_valid(_lightning_timer):
		return
	var base_time := 8.0
	match current_intensity:
		Intensity.LOW:
			base_time = 16.0
		Intensity.MEDIUM:
			base_time = 11.0
		Intensity.HIGH:
			base_time = 7.0
	_lightning_timer.wait_time = randf_range(base_time * 0.75, base_time * 1.35)
	_lightning_timer.start()


func _on_lightning_timer_timeout() -> void:
	if current_intensity == Intensity.OFF or current_profile != Profile.LIGHTNING:
		return
	trigger_lightning(randf_range(0.8, 1.0), randf_range(0.35, 0.75))
	_schedule_next_lightning()


## Şimşek çaktırır: Önce görsel flaş patlar, distance_delay sonra gök gürültüsü duyulur
func trigger_lightning(intensity: float = 1.0, distance_delay: float = 0.45) -> void:
	if current_intensity == Intensity.OFF:
		return

	# Görsel flaş: Erişilebilirlik kontrolü
	var is_reduce_flash := false
	var cm = get_node_or_null("/root/CinematicManager")
	if cm and "reduce_flashing" in cm and cm.reduce_flashing:
		is_reduce_flash = true

	if _flash_rect and is_instance_valid(_flash_rect):
		var tw := create_tween()
		_active_tweens.append(tw)

		if is_reduce_flash:
			# Flaş azaltılmışsa: Sert beyaz çakma yerine hafif yumuşak mavi/gri ton
			_flash_rect.color = Color(0.2, 0.3, 0.5, 0.0)
			tw.tween_property(_flash_rect, "color:a", 0.12 * intensity, 0.25)
			tw.tween_property(_flash_rect, "color:a", 0.0, 0.6)
		else:
			# Normal çift vuruşlu gerçekçi şimşek parlaması
			_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
			tw.tween_property(_flash_rect, "color:a", 0.85 * intensity, 0.04)
			tw.tween_property(_flash_rect, "color:a", 0.25 * intensity, 0.05)
			tw.tween_property(_flash_rect, "color:a", 0.70 * intensity, 0.04)
			tw.tween_property(_flash_rect, "color:a", 0.0, 0.22)

	lightning_struck.emit(intensity)

	# Mesafe gecikmesi sonrasında gök gürültüsü
	if _sound_delay_timer and is_instance_valid(_sound_delay_timer):
		_sound_delay_timer.wait_time = maxf(distance_delay, 0.05)
		_sound_delay_timer.start()


func _on_sound_delay_timeout() -> void:
	play_thunder_sound()


func play_thunder_sound() -> void:
	if current_intensity == Intensity.OFF:
		return

	if _thunder_player and is_instance_valid(_thunder_player):
		_thunder_player.play()
		var pb := _thunder_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if pb:
			var dur := 1.1
			var sample_rate := 22050.0
			var n := int(sample_rate * dur)
			var frames := mini(n, pb.get_frames_available())
			for i in range(frames):
				var t := float(i) / sample_rate
				var env := exp(-2.4 * t) * (1.0 - exp(-25.0 * t))
				var rumble := sin(t * 54.0 * TAU) * 0.45 + sin(t * 88.0 * TAU) * 0.25
				var noise := (randf() * 2.0 - 1.0) * 0.3 * exp(-5.0 * t)
				var s := clampf((rumble + noise) * env * 0.65, -1.0, 1.0)
				pb.push_frame(Vector2(s, s))

	# Kamera titreşimi (Erişilebilirlik kontrolü)
	var cam_mgr = get_node_or_null("/root/CameraManager")
	if cam_mgr and cam_mgr.has_method("apply_shake"):
		var cin = get_node_or_null("/root/CinematicManager")
		var is_reduce_motion: bool = cin != null and "reduce_motion" in cin and cin.reduce_motion
		if not is_reduce_motion:
			cam_mgr.apply_shake(4.0, 0, 0.35, 18.0, "thunder_rumble")

	thunder_played.emit()


# ---------------------------------------------------------------------------
# Temizlik ve Sahne Değişimi Yönetimi
# ---------------------------------------------------------------------------
func clean_weather() -> void:
	for tw in _active_tweens:
		if is_instance_valid(tw):
			tw.kill()
	_active_tweens.clear()

	_emitters.clear()
	_flash_rect = null
	_thunder_player = null
	_lightning_timer = null
	_sound_delay_timer = null

	if _weather_canvas and is_instance_valid(_weather_canvas):
		if _weather_canvas.get_parent():
			_weather_canvas.get_parent().remove_child(_weather_canvas)
		_weather_canvas.free()
		_weather_canvas = null


func _exit_tree() -> void:
	clean_weather()


# ---------------------------------------------------------------------------
# Kalıcılık (user://game_settings.json)
# ---------------------------------------------------------------------------
func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not f:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		if json.data.has("weather_intensity"):
			current_intensity = clampi(int(json.data.get("weather_intensity", 3)), 0, 3) as Intensity
	f.close()


func save_settings() -> void:
	var existing: Dictionary = {}
	if FileAccess.file_exists(SETTINGS_PATH):
		var rf := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if rf:
			var json := JSON.new()
			if json.parse(rf.get_as_text()) == OK and json.data is Dictionary:
				existing = json.data
			rf.close()
	existing["weather_intensity"] = int(current_intensity)
	var wf := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if wf:
		wf.store_string(JSON.stringify(existing, "\t"))
		wf.close()
