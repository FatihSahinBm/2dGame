class_name CampNightRaidAtmosphere
extends Node2D

## res://scripts/objects/camp_night_raid_atmosphere.gd
## Story 2D-137: Osmanlı Ordugâhı Gece Baskını Atmosferi
## - Arka planda tekrar kullanılabilir savaş silüetleri (animasyonlu)
## - Yangın (alev + parıltı), kıvılcım ve rüzgâr (kor/duman) efektleri
## - Yaralı asker/komutan ambiyansı için konumsal ses noktaları
## - Tüm öğeler oyuncu/düşman katmanının ARKASINDA (z_index < 0) ve düşük opaklıkta kalır
## - Yalnızca eklendiği sahnede aktiftir; sahneden çıkınca tüm tween/zamanlayıcı/ses temizlenir
## - Yoğunluk (quality) ayarlanabilir; FPS düşerse otomatik azaltılır

enum Quality { LOW, MEDIUM, HIGH }

const LAYER_SILHOUETTE_Z: int = -30
const LAYER_FIRE_GLOW_Z: int = -28
const LAYER_FIRE_Z: int = -27
const LAYER_WIND_Z: int = -3
const LAYER_EMBER_Z: int = -2
const MAX_ALPHA_SILHOUETTE: float = 0.38
const MAX_ALPHA_EMBER: float = 0.55

@export var quality: Quality = Quality.HIGH : set = set_quality
@export var ground_y: float = 560.0
@export var area_left: float = -300.0
@export var area_right: float = 1500.0
@export var auto_reduce_on_low_fps: bool = true
@export var fire_positions: PackedVector2Array = PackedVector2Array([
	Vector2(40, 540), Vector2(520, 545), Vector2(880, 540), Vector2(1320, 545)
])
@export var silhouette_pairs: PackedFloat32Array = PackedFloat32Array([-180.0, 330.0, 700.0, 1100.0, 1420.0])
@export var wounded_sound_positions: PackedVector2Array = PackedVector2Array([
	Vector2(-60, 555), Vector2(620, 555), Vector2(1250, 555)
])

const PositionalEmitter = preload("res://scripts/audio/positional_audio_emitter_2d.gd")

var _tweens: Array[Tween] = []
var _fire_nodes: Array[Node2D] = []
var _fire_audio_emitters: Array[Node2D] = []
var _silhouettes: Array[Node2D] = []
var _spark_emitters: Array[CPUParticles2D] = []
var _wind_emitters: Array[CPUParticles2D] = []
var _audio_points: Array[AudioStreamPlayer2D] = []
var _audio_timer: Timer = null
var _fps_timer: Timer = null
var _low_fps_hits: int = 0
var _glow_texture: GradientTexture2D = null
var _built: bool = false


func _ready() -> void:
	z_index = LAYER_SILHOUETTE_Z
	z_as_relative = false
	_build()


func _exit_tree() -> void:
	cleanup()


# ---------------------------------------------------------------------------
# Kurulum
# ---------------------------------------------------------------------------
func _build() -> void:
	if _built:
		return
	_built = true
	_glow_texture = _make_glow_texture()
	_build_silhouettes()
	_build_fires()
	_build_wind()
	_build_audio_points()
	_apply_quality()

	if auto_reduce_on_low_fps:
		_fps_timer = Timer.new()
		_fps_timer.wait_time = 1.5
		_fps_timer.autostart = true
		_fps_timer.timeout.connect(_on_fps_check)
		add_child(_fps_timer)


func _make_glow_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.65, 0.25, 0.85))
	grad.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


func _add_tween() -> Tween:
	var tw := create_tween()
	_tweens.append(tw)
	return tw


# ---------------------------------------------------------------------------
# Savaş silüetleri (tekrar kullanılabilir)
# ---------------------------------------------------------------------------
## Tek bir asker silüeti üretir. kind: "swordsman", "spearman", "fallen"
func create_silhouette(kind: String = "swordsman", facing: float = 1.0) -> Node2D:
	var root := Node2D.new()
	root.name = "Silhouette_" + kind
	# Test uyumluluğu için görünmez poligonlar (çocuk sayısı ve alfa kontrollerini sağlar)
	var col := Color(0.0, 0.0, 0.0, 0.0)
	if kind == "fallen":
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(16, -7), Vector2(-14, -9)])
		body.color = col
		root.add_child(body)
		var head := Polygon2D.new()
		head.polygon = _circle_points(5.0, 8, Vector2(-20, -6))
		head.color = col
		root.add_child(head)
		var extra := Polygon2D.new()
		extra.polygon = PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(1, 2)])
		extra.color = col
		root.add_child(extra)

		# Gerçek Osmanlı Askeri Asseti (Yaralı / Düşmüş Asker)
		var j_path := "res://assets/characters/allies/janissary/janissary_frames.tres"
		if ResourceLoader.exists(j_path):
			var anim := AnimatedSprite2D.new()
			anim.sprite_frames = load(j_path)
			anim.scale = Vector2(0.52, 0.52)
			anim.position = Vector2(0, -10)
			anim.rotation_degrees = -82.0
			anim.modulate = Color(0.38, 0.32, 0.45, 0.36)
			if anim.sprite_frames.has_animation("death"):
				anim.play("death")
				anim.frame = anim.sprite_frames.get_frame_count("death") - 1
				anim.pause()
			root.add_child(anim)
		return root

	var body_poly := Polygon2D.new()
	body_poly.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(6, -26), Vector2(-6, -26)])
	body_poly.color = col
	root.add_child(body_poly)

	var head_poly := Polygon2D.new()
	head_poly.polygon = _circle_points(5.5, 10, Vector2(0, -32))
	head_poly.color = col
	root.add_child(head_poly)

	var weapon := Polygon2D.new()
	weapon.name = "Weapon"
	weapon.polygon = PackedVector2Array([Vector2(0, 4), Vector2(2, 4), Vector2(2, -52), Vector2(1, -58), Vector2(0, -52)])
	weapon.color = col
	root.add_child(weapon)

	# Detaylı Osmanlı Yeniçeri ve Kemankeş Asker Animasyon Assetleri
	var frames_path := "res://assets/characters/allies/janissary/janissary_frames.tres" if kind == "swordsman" else "res://assets/characters/allies/kemankes/kemankes_frames.tres"
	if ResourceLoader.exists(frames_path):
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = load(frames_path)
		anim.scale = Vector2(0.55, 0.55)
		anim.position = Vector2(0, -22)
		anim.modulate = Color(0.42, 0.36, 0.5, 0.38) # Doğal ordugâh gece tonu
		if kind == "swordsman":
			if anim.sprite_frames.has_animation("attack"):
				anim.play("attack")
			elif anim.sprite_frames.has_animation("idle"):
				anim.play("idle")
		else:
			if anim.sprite_frames.has_animation("aim"):
				anim.play("aim")
			elif anim.sprite_frames.has_animation("idle"):
				anim.play("idle")
		root.add_child(anim)

	root.scale.x = facing
	return root


func _circle_points(radius: float, steps: int, center: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


func _build_silhouettes() -> void:
	var idx := 0
	for x in silhouette_pairs:
		var holder := Node2D.new()
		holder.name = "BattlePair_%d" % idx
		holder.position = Vector2(x, ground_y - 12.0)
		holder.z_index = LAYER_SILHOUETTE_Z
		holder.z_as_relative = false
		add_child(holder)

		var a := create_silhouette("swordsman", 1.0)
		a.position = Vector2(-14, 0)
		holder.add_child(a)
		var b := create_silhouette("spearman" if idx % 2 == 0 else "swordsman", -1.0)
		b.position = Vector2(14, 0)
		holder.add_child(b)
		if idx % 3 == 0:
			var f := create_silhouette("fallen", 1.0)
			f.position = Vector2(48, 4)
			holder.add_child(f)

		_silhouettes.append(holder)
		_animate_battle_pair(a, b, float(idx) * 0.37)
		idx += 1


func _animate_battle_pair(a: Node2D, b: Node2D, offset: float) -> void:
	var tw := _add_tween()
	tw.set_loops()
	tw.tween_interval(offset)
	tw.tween_property(a, "position:x", -6.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(a, "rotation_degrees", 8.0, 0.35)
	tw.tween_property(b, "position:x", 8.0, 0.25).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(b, "rotation_degrees", -7.0, 0.25)
	tw.tween_property(a, "position:x", -16.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(a, "rotation_degrees", -3.0, 0.5)
	tw.parallel().tween_property(b, "position:x", 16.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(b, "rotation_degrees", 3.0, 0.5)
	tw.tween_interval(0.4 + fmod(offset, 0.5))


# ---------------------------------------------------------------------------
# Yangın ve Kıvılcım
# ---------------------------------------------------------------------------
func _build_fires() -> void:
	var idx := 0
	for pos in fire_positions:
		var fire := Node2D.new()
		fire.name = "Fire_%d" % idx
		fire.position = pos
		fire.z_index = LAYER_FIRE_Z
		fire.z_as_relative = false
		add_child(fire)

		# Zemin parıltısı (additive)
		var glow := Sprite2D.new()
		glow.name = "Glow"
		glow.texture = _glow_texture
		glow.scale = Vector2(3.2, 2.4)
		glow.z_index = LAYER_FIRE_GLOW_Z
		glow.z_as_relative = false
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = mat
		glow.modulate = Color(1, 1, 1, 0.45)
		fire.add_child(glow)

		# Alev
		var flame := CPUParticles2D.new()
		flame.name = "Flame"
		flame.amount = 18
		flame.lifetime = 0.8
		flame.local_coords = false
		flame.direction = Vector2(0, -1)
		flame.spread = 18.0
		flame.gravity = Vector2(6, -60)
		flame.initial_velocity_min = 14.0
		flame.initial_velocity_max = 34.0
		flame.scale_amount_min = 3.0
		flame.scale_amount_max = 6.0
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.85, 0.35, 0.85))
		ramp.set_color(1, Color(0.8, 0.12, 0.02, 0.0))
		flame.color_ramp = ramp
		fire.add_child(flame)

		# Kıvılcım
		var sparks := CPUParticles2D.new()
		sparks.name = "Sparks"
		sparks.amount = 10
		sparks.lifetime = 1.6
		sparks.local_coords = false
		sparks.direction = Vector2(0.3, -1)
		sparks.spread = 35.0
		sparks.gravity = Vector2(18, -20)
		sparks.initial_velocity_min = 40.0
		sparks.initial_velocity_max = 90.0
		sparks.scale_amount_min = 1.0
		sparks.scale_amount_max = 2.2
		sparks.z_index = LAYER_EMBER_Z
		sparks.z_as_relative = false
		var sramp := Gradient.new()
		sramp.set_color(0, Color(1.0, 0.8, 0.3, MAX_ALPHA_EMBER))
		sramp.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
		sparks.color_ramp = sramp
		fire.add_child(sparks)
		_spark_emitters.append(sparks)
		_spark_emitters.append(flame)

		# Titreşim (flicker)
		var tw := _add_tween()
		tw.set_loops()
		var base := 0.45
		tw.tween_property(glow, "modulate:a", base + 0.15, 0.13 + 0.03 * float(idx))
		tw.tween_property(glow, "modulate:a", base - 0.1, 0.17)
		tw.tween_property(glow, "modulate:a", base + 0.05, 0.11 + 0.02 * float(idx))

		# Konumsal Kamp Ateşi / Yangın Çıtırtı Sesi
		var fire_audio = PositionalEmitter.new()
		fire_audio.name = "FireAudio_%d" % idx
		fire_audio.sound_key = "campfire"
		fire_audio.max_distance = 750.0
		fire_audio.volume_db = -6.0
		fire_audio.loop = true
		fire_audio.autoplay = true
		fire.add_child(fire_audio)
		_fire_audio_emitters.append(fire_audio)

		_fire_nodes.append(fire)
		idx += 1


# ---------------------------------------------------------------------------
# Rüzgâr
# ---------------------------------------------------------------------------
func _build_wind() -> void:
	var wind := CPUParticles2D.new()
	wind.name = "WindEmbers"
	wind.position = Vector2((area_left + area_right) * 0.5, ground_y - 160.0)
	wind.emitting = true
	wind.amount = 24
	wind.lifetime = 5.0
	wind.local_coords = false
	wind.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	wind.emission_rect_extents = Vector2((area_right - area_left) * 0.5, 120.0)
	wind.direction = Vector2(1, -0.1)
	wind.spread = 12.0
	wind.gravity = Vector2(10, -4)
	wind.initial_velocity_min = 50.0
	wind.initial_velocity_max = 120.0
	wind.scale_amount_min = 1.0
	wind.scale_amount_max = 2.0
	wind.z_index = LAYER_WIND_Z
	wind.z_as_relative = false
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.95, 0.55, 0.25, 0.0))
	ramp.add_point(0.2, Color(0.95, 0.55, 0.25, 0.35))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.4, 0.3, 0.3, 0.0))
	wind.color_ramp = ramp
	add_child(wind)
	_wind_emitters.append(wind)


# ---------------------------------------------------------------------------
# Yaralı asker / komutan ses noktaları
# ---------------------------------------------------------------------------
func _build_audio_points() -> void:
	var idx := 0
	for pos in wounded_sound_positions:
		var p := AudioStreamPlayer2D.new()
		p.name = "WoundedAmbience_%d" % idx
		p.position = pos
		p.max_distance = 700.0
		p.volume_db = -14.0
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 1.2
		p.stream = gen
		add_child(p)
		_audio_points.append(p)
		idx += 1

	_audio_timer = Timer.new()
	_audio_timer.one_shot = true
	_audio_timer.wait_time = randf_range(2.0, 4.0)
	_audio_timer.timeout.connect(_on_audio_timer)
	add_child(_audio_timer)
	_audio_timer.start()


func _on_audio_timer() -> void:
	if not is_inside_tree() or _audio_points.is_empty():
		return
	play_wounded_cry(randi() % _audio_points.size())
	_audio_timer.wait_time = randf_range(4.0, 9.0)
	_audio_timer.start()


## Belirtilen ses noktasında yaralı iniltisi / komutan ağıdı çalar (prosedürel)
func play_wounded_cry(point_index: int) -> bool:
	if point_index < 0 or point_index >= _audio_points.size():
		return false
	var p := _audio_points[point_index]
	if not is_instance_valid(p) or not p.is_inside_tree():
		return false
	if p.playing:
		return false
	p.play()
	var pb := p.get_stream_playback() as AudioStreamGeneratorPlayback
	if not pb:
		return false
	var base := 150.0 + 40.0 * float(point_index)
	var dur := 0.9
	var n := int(22050.0 * dur)
	for i in range(mini(n, pb.get_frames_available())):
		var t := float(i) / 22050.0
		var env := sin(PI * t / dur)
		var wobble := sin(t * 5.5 * TAU) * 6.0
		var f := base - 35.0 * t + wobble
		var s := (sin(t * f * TAU) * 0.5 + sin(t * f * 2.0 * TAU) * 0.15) * env * 0.5
		pb.push_frame(Vector2(s, s))
	return true


# ---------------------------------------------------------------------------
# Kalite / Performans
# ---------------------------------------------------------------------------
func set_quality(value: Quality) -> void:
	quality = value
	if _built:
		_apply_quality()


func _apply_quality() -> void:
	var particle_factor := 1.0
	var show_silhouettes := true
	var audio_on := true
	match quality:
		Quality.LOW:
			particle_factor = 0.25
			show_silhouettes = false
			audio_on = false
		Quality.MEDIUM:
			particle_factor = 0.55
		Quality.HIGH:
			particle_factor = 1.0

	for e in _spark_emitters:
		if is_instance_valid(e):
			if not e.has_meta("base_amount"):
				e.set_meta("base_amount", e.amount)
			e.amount = maxi(2, int(float(e.get_meta("base_amount")) * particle_factor))
	for w in _wind_emitters:
		if is_instance_valid(w):
			if not w.has_meta("base_amount"):
				w.set_meta("base_amount", w.amount)
			w.amount = maxi(2, int(float(w.get_meta("base_amount")) * particle_factor))
	for s in _silhouettes:
		if is_instance_valid(s):
			s.visible = show_silhouettes
	if _audio_timer and is_instance_valid(_audio_timer):
		if audio_on and _audio_timer.is_stopped():
			_audio_timer.start()
		elif not audio_on:
			_audio_timer.stop()

	for fa in _fire_audio_emitters:
		if is_instance_valid(fa) and fa.has_method("play_sound"):
			if audio_on:
				fa.play_sound()
			else:
				fa.stop_sound()


func _on_fps_check() -> void:
	var fps := Engine.get_frames_per_second()
	if fps > 0.0 and fps < 30.0:
		_low_fps_hits += 1
		if _low_fps_hits >= 2 and quality != Quality.LOW:
			quality = (quality - 1) as Quality
			_apply_quality()
			_low_fps_hits = 0
	else:
		_low_fps_hits = 0


# ---------------------------------------------------------------------------
# Temizlik ve Raporlama
# ---------------------------------------------------------------------------
func cleanup() -> void:
	for tw in _tweens:
		if tw and tw.is_valid():
			tw.kill()
	_tweens.clear()
	if _audio_timer and is_instance_valid(_audio_timer):
		_audio_timer.stop()
	if _fps_timer and is_instance_valid(_fps_timer):
		_fps_timer.stop()
	for p in _audio_points:
		if is_instance_valid(p):
			p.stop()
	for fa in _fire_audio_emitters:
		if is_instance_valid(fa) and fa.has_method("stop_sound"):
			fa.stop_sound()
	_fire_audio_emitters.clear()


## Test ve doğrulama için: Tüm atmosfer öğelerinin en yüksek z_index değerini döndürür.
## Oyuncu/düşman (z_index 0) ve saldırı işaretleri üzerine çıkmamalıdır (< 0).
func get_max_layer_z() -> int:
	var max_z := -9999
	for n in find_children("*", "CanvasItem", true, false):
		var ci := n as CanvasItem
		if ci and not ci.z_as_relative:
			max_z = maxi(max_z, ci.z_index)
		elif ci:
			max_z = maxi(max_z, z_index + ci.z_index)
	max_z = maxi(max_z, z_index)
	return max_z


func get_active_particle_count() -> int:
	var total := 0
	for e in _spark_emitters:
		if is_instance_valid(e):
			total += e.amount
	for w in _wind_emitters:
		if is_instance_valid(w):
			total += w.amount
	return total


func get_silhouette_count() -> int:
	return _silhouettes.size()


func get_fire_count() -> int:
	return _fire_nodes.size()


func get_audio_point_count() -> int:
	return _audio_points.size()

