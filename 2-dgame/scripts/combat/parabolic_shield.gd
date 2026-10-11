extends Area2D
class_name ParabolicShield

## res://scripts/combat/parabolic_shield.gd
## Parabol (Yay) Şeklinde Fiziksel ve Görsel Enerji Kalkanı (180° Ön Koruma)
## Özellikler:
## - 180 derecelik parabolik yay şeklinde hem fiziksel CollisionPolygon2D hem de _draw() ile vektörel çizim
## - Düşman mermilerini (Area2D) algılayıp yansıtma (reflect) veya yok etme
## - Sadece ön taraftan gelen saldırıları engelleme (arkadan gelen saldırılar açıkta kalır)
## - Stamina (Dayanıklılık) sistemi: Açıkken saniyede tükenir, kapanınca yenilenir, bitince kırılır (cooldown)

# ── Sinyaller ────────────────────────────────────────────────────────────────
signal shield_opened()
signal shield_closed()
signal shield_broken()
signal stamina_changed(current: float, max_stamina: float)
signal projectile_reflected(projectile: Node2D)
signal attack_blocked(impact_pos: Vector2)

# ── Ayarlar & Dışa Aktarılan Değişkenler ──────────────────────────────────────
@export_group("Shield Geometry")
@export var radius: float = 38.0            # Kalkanın yarıçapı / ön uzaklığı
@export var thickness: float = 9.0          # Kalkanın et kalınlığı
@export var arc_angle_degrees: float = 180.0# Koruma açısı (180° = tam ön yarım daire)
@export var arc_segments: int = 24          # Yayın eğrilik pürüzsüzlüğü
@export var shield_offset: Vector2 = Vector2(8.0, -20.0) # Karakter göğüs hizası ofseti

@export_group("Stamina & Duration")
@export var max_stamina: float = 100.0
@export var current_stamina: float = 100.0
@export var drain_per_second: float = 22.0  # Saniyede harcanan stamina (~4.5 sn açık kalabilir)
@export var recover_per_second: float = 28.0# Kapanınca saniyede dolan stamina (~3.5 sn tam şarj)
@export var break_penalty_cooldown: float = 2.2 # Stamina bitince kalkanın kilitlenme süresi

@export_group("Visuals & Colors")
@export var energy_color: Color = Color(0.2, 0.75, 1.0, 0.35)   # İç enerji dolgu rengi
@export var edge_color: Color = Color(0.65, 0.95, 1.0, 0.95)   # Dış parlak hat rengi
@export var inner_edge_color: Color = Color(0.15, 0.5, 0.9, 0.6)# İç hat rengi

# ── Durum Değişkenleri ───────────────────────────────────────────────────────
var is_active: bool = false
var is_broken: bool = false
var _break_timer: float = 0.0
var _pulse_timer: float = 0.0
var _last_hit_flash: float = 0.0

# Geometri noktaları
var _polygon_points: PackedVector2Array = PackedVector2Array()
var _outer_points: PackedVector2Array = PackedVector2Array()
var _inner_points: PackedVector2Array = PackedVector2Array()

# Düğüm Referansları
var col_polygon: CollisionPolygon2D = null

func _get_col_polygon() -> CollisionPolygon2D:
	if not col_polygon and has_node("CollisionPolygon2D"):
		col_polygon = $CollisionPolygon2D
	return col_polygon

func _ready() -> void:
	# Fizik katmanı ayarları: Düşmanları ve mermileri dinleyecek
	collision_layer = 16 # Shield layer
	collision_mask = 7   # World (1), Enemy (2), Projectile/Hitbox (4)
	monitoring = false
	monitorable = false
	visible = false

	# Sinyal bağlantıları
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# Parabolik geometriyi hesapla ve CollisionPolygon2D'ye ata
	_generate_arc_geometry()

func _generate_arc_geometry() -> void:
	_polygon_points.clear()
	_outer_points.clear()
	_inner_points.clear()

	var half_angle_rad: float = deg_to_rad(arc_angle_degrees * 0.5)
	var step_angle: float = (half_angle_rad * 2.0) / float(arc_segments)

	# 1. Dış yay noktaları (-90° den +90° ye)
	# Parabolik büküm için cos(ang) ile ileri doğru hafif esnetme eklenir
	for i in range(arc_segments + 1):
		var ang: float = -half_angle_rad + float(i) * step_angle
		# Parabolik profil: Merkezde (ang=0) biraz daha ileri uzanır
		var bulge: float = 1.0 + (cos(ang) * 0.15)
		var pt: Vector2 = shield_offset + Vector2(cos(ang) * radius * bulge, sin(ang) * radius)
		_outer_points.append(pt)

	# 2. İç yay noktaları (Geri dönüş: +90° den -90° ye, et kalınlığı kadar içeride)
	for i in range(arc_segments, -1, -1):
		var ang: float = -half_angle_rad + float(i) * step_angle
		var bulge: float = 1.0 + (cos(ang) * 0.15)
		var inner_r: float = maxf(4.0, radius - thickness)
		var pt: Vector2 = shield_offset + Vector2(cos(ang) * inner_r * bulge, sin(ang) * inner_r)
		_inner_points.append(pt)

	# 3. Kapalı poligon dizisi (Dış noktalar + İç noktalar)
	_polygon_points.append_array(_outer_points)
	_polygon_points.append_array(_inner_points)

	# CollisionPolygon2D'yi güncelle
	var poly = _get_col_polygon()
	if not poly:
		poly = CollisionPolygon2D.new()
		add_child(poly)
		col_polygon = poly

	if poly:
		poly.polygon = _polygon_points

func _physics_process(delta: float) -> void:
	_pulse_timer += delta

	# Kırılma bekleme süresi (Break cooldown)
	if is_broken:
		_break_timer -= delta
		if _break_timer <= 0.0:
			is_broken = false
			current_stamina = 25.0 # Yeniden açılabilmesi için başlangıç enerjisi
			stamina_changed.emit(current_stamina, max_stamina)

	# Kalkan aktifken stamina tüket
	if is_active:
		current_stamina -= drain_per_second * delta
		stamina_changed.emit(current_stamina, max_stamina)
		if current_stamina <= 0.0:
			current_stamina = 0.0
			_break_shield()
		queue_redraw()
	else:
		# Kalkan kapalıyken stamina yenile
		if not is_broken and current_stamina < max_stamina:
			current_stamina = minf(max_stamina, current_stamina + recover_per_second * delta)
			stamina_changed.emit(current_stamina, max_stamina)

	# Darbe parlaması zamanlayıcısı
	if _last_hit_flash > 0.0:
		_last_hit_flash = maxf(0.0, _last_hit_flash - delta * 4.0)
		queue_redraw()

# ── Kalkanı Açma / Kapama Fonksiyonları ──────────────────────────────────────
func activate() -> bool:
	if is_broken or current_stamina <= 5.0 or is_active:
		return false

	is_active = true
	visible = true
	monitoring = true
	monitorable = true
	var poly = _get_col_polygon()
	if poly:
		poly.set_deferred("disabled", false)

	shield_opened.emit()
	queue_redraw()
	return true

func deactivate() -> void:
	if not is_active:
		return

	is_active = false
	visible = false
	monitoring = false
	monitorable = false
	var poly = _get_col_polygon()
	if poly:
		poly.set_deferred("disabled", true)

	shield_closed.emit()
	queue_redraw()

## Stamina tükendiğinde kalkanın kırılması
func _break_shield() -> void:
	deactivate()
	is_broken = true
	_break_timer = break_penalty_cooldown
	shield_broken.emit()

	# Kırılma ses/efekti için görsel geribildirim
	var parent_char = get_parent().get_parent() if get_parent() else null
	if parent_char and "visual_node" in parent_char and parent_char.visual_node:
		var orig = parent_char.visual_node.modulate
		parent_char.visual_node.modulate = Color(2.5, 0.4, 0.4, 1.0)
		if is_inside_tree() and get_tree():
			get_tree().create_timer(0.2).timeout.connect(func():
				if is_instance_valid(parent_char.visual_node):
					parent_char.visual_node.modulate = orig
			)

	_spawn_floating_text("⚡ KALKAN KIRILDI!", Color(1.0, 0.3, 0.3, 1.0))

# ── Çarpışma ve Yansıtma Mantığı ─────────────────────────────────────────────
func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return

	# 1. Büyü ve Düşman Mermileri (Projectile)
	if area.is_in_group("reflectable_projectile") or area.is_in_group("projectile") or area.is_in_group("enemy_projectile") or "DarkMagicProjectile" in area.name:
		_deflect_projectile(area)
		return

	# 2. Düşman Yakın Dövüş Hitbox'ı (Balyoz, pençe vb.)
	if area.name == "Hitbox" or area.is_in_group("enemy_attack"):
		_block_melee_attack(area)

func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body.is_in_group("reflectable_projectile") or body.is_in_group("projectile"):
		_deflect_projectile(body)

## Mermiyi Sekip Geri Yansıtma (Deflect / Reflect)
func _deflect_projectile(proj: Node2D) -> void:
	if not is_instance_valid(proj):
		return

	# Stamina tüket (mermi başına 14 puan)
	consume_stamina(14.0)
	_last_hit_flash = 1.0

	var player_node = get_parent().get_parent() if get_parent() else null

	# Merminin reflect metodu varsa (örn. DarkMagicProjectile) geri yansıt
	if proj.has_method("reflect"):
		proj.reflect(player_node)
		projectile_reflected.emit(proj)
		_spawn_floating_text("🛡️ REFLECT!", Color(0.4, 0.9, 1.0))
	else:
		# Yansıtma fonksiyonu yoksa mermiyi yok et/patlat
		if proj.has_method("_trigger_burst"):
			proj._trigger_burst()
		elif proj.has_method("destroy"):
			proj.destroy()
		else:
			proj.queue_free()
		_spawn_floating_text("🛡️ ENGELLENDİ!", Color(0.5, 0.8, 1.0))

	attack_blocked.emit(proj.global_position)

## Yakın Dövüş Saldırısını Engelleme
func _block_melee_attack(hitbox: Area2D) -> void:
	consume_stamina(22.0)
	_last_hit_flash = 1.0
	attack_blocked.emit(hitbox.global_position)
	_spawn_floating_text("🛡️ SAVUŞTURULDU (-%100)", Color(0.3, 0.9, 1.0))

## Dışarıdan Hasar Alındığında: Sadece Öndeki Saldırıları Engelle!
## Gelen saldırı kaynağı kalkanın baktığı ön yarı dairede (180°) mi kontrol eder.
func is_blocking_attack(attacker_global_pos: Vector2) -> bool:
	if not is_active:
		return false

	var to_attacker: Vector2 = attacker_global_pos - global_position
	# Kalkanın global bakış yönü (Visual parent'ının scale.x'ine göre belirlenir)
	var forward_dir: Vector2 = global_transform.x.normalized()

	# Dot product > -0.05: Kaynak ön 180 derecelik yarım daire içindedir!
	# Arkadan geliyorsa (< 0.0) kalkan korumaz!
	var is_in_front: bool = to_attacker.dot(forward_dir) >= -0.05

	if is_in_front:
		consume_stamina(18.0)
		_last_hit_flash = 1.0
		attack_blocked.emit(attacker_global_pos)
		return true

	return false

func consume_stamina(amount: float) -> void:
	current_stamina = maxf(0.0, current_stamina - amount)
	stamina_changed.emit(current_stamina, max_stamina)
	if current_stamina <= 0.0:
		_break_shield()

# ── Görselleştirme (_draw ile Parabol / Yay Çizimi) ──────────────────────────
func _draw() -> void:
	if not is_active:
		return

	# Nabız / Dalgalanma parıltı katsayısı
	var pulse: float = sin(_pulse_timer * 10.0) * 0.08
	var flash_boost: float = _last_hit_flash * 0.6

	# 1. İç Enerji Alanı (Yarı saydam poligon dolgusu)
	var dynamic_fill_color: Color = energy_color
	dynamic_fill_color.a = clampf(energy_color.a + pulse + flash_boost, 0.1, 0.8)
	if _polygon_points.size() >= 3:
		draw_colored_polygon(_polygon_points, dynamic_fill_color)

	# 2. Dış Parlak Parabolik Kenar Çizgisi (Line2D kalitesinde antialiased yay)
	var dynamic_edge_color: Color = edge_color
	if _last_hit_flash > 0.1:
		dynamic_edge_color = Color(1.5, 2.0, 2.5, 1.0) # Darbe anı beyaz/parlak flaş
	draw_polyline(_outer_points, dynamic_edge_color, 3.2, true)

	# 3. İç Kenar Çizgisi
	draw_polyline(_inner_points, inner_edge_color, 1.5, true)

	# 4. Mini Stamina Göstergesi (Kalkanın arkasında ince kavisli enerji barı)
	_draw_stamina_arc()

func _draw_stamina_arc() -> void:
	var stamina_pct: float = current_stamina / max_stamina
	var bar_radius: float = radius * 0.45
	var bar_angle: float = deg_to_rad(120.0) * stamina_pct
	var start_a: float = -bar_angle * 0.5
	var end_a: float = bar_angle * 0.5

	var bar_color: Color = Color(0.2, 0.9, 0.6, 0.8)
	if stamina_pct < 0.3:
		bar_color = Color(1.0, 0.25, 0.2, 0.9)
	elif stamina_pct < 0.6:
		bar_color = Color(1.0, 0.85, 0.2, 0.85)

	draw_arc(shield_offset, bar_radius, start_a, end_a, 16, bar_color, 2.0, true)

func _spawn_floating_text(text: String, color: Color) -> void:
	var parent_scene = get_tree().current_scene if (is_inside_tree() and get_tree()) else null
	if not parent_scene:
		return

	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.15, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.global_position = global_position + Vector2(-40.0, -55.0)
	parent_scene.add_child(label)

	var tw = label.create_tween()
	if tw:
		tw.tween_property(label, "global_position:y", label.global_position.y - 28.0, 0.55)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
		tw.tween_callback(label.queue_free)
