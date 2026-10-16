extends Node2D
class_name WorldParallaxBackground

## res://scripts/objects/world_parallax_background.gd
## Sakin, akıcı ve sinematik 2D dünya-koordinatı arka plan sistemi.
## Kamera smoothing (yumuşatma) ile tam senkronize çalışarak mikrotitreşimi (judder),
## baş dönmesini ve dikey zıplama sarsıntılarını tamamen önler.

@export var background_texture: Texture2D
@export var ground_y: float = 560.0 ## Sahnenin zemin Y seviyesi (karakterin ayak tabanı)
@export var texture_ground_y: float = 620.0 ## Dokudaki zemin/ufuk çizgisi Y seviyesi (~620)
@export var texture_scale: Vector2 = Vector2(0.85, 0.85)
@export var parallax_factor_x: float = 0.05 ## Sakin ve asil uzaklık hissi (%5 hız - baş dönmesini engeller)
@export var parallax_factor_y: float = 0.02 ## Dikey zıplamalarda ay ve dağların sallanmasını engeller (%2 bağıl hareket)
@export var tile_count: int = 3
@export var fog_color: Color = Color(0.08, 0.03, 0.07, 0.22)

var _camera: Camera2D = null
var _origin_cam: Vector2 = Vector2.ZERO
var _origin_node: Vector2 = Vector2.ZERO
var _tile_width: float = 0.0
var _sprites: Array[Sprite2D] = []
var _fog_rect: ColorRect = null
var _is_initialized: bool = false


func _ready() -> void:
	z_index = -50
	_setup_tiles()
	if fog_color.a > 0.0:
		_setup_fog()


func set_background_texture(new_tex: Texture2D, new_fog: Color = Color.TRANSPARENT, fade_time: float = 0.6) -> void:
	if not new_tex or background_texture == new_tex:
		return
	background_texture = new_tex
	if fade_time <= 0.0:
		for s in _sprites:
			s.texture = new_tex
	else:
		var tw: Tween = create_tween()
		for s in _sprites:
			tw.parallel().tween_property(s, "modulate:a", 0.0, fade_time * 0.4)
		tw.tween_callback(func():
			for s in _sprites:
				s.texture = new_tex
		)
		for s in _sprites:
			tw.parallel().tween_property(s, "modulate:a", 1.0, fade_time * 0.6)

	if new_fog != Color.TRANSPARENT and _fog_rect:
		var tw_fog: Tween = create_tween()
		tw_fog.tween_property(_fog_rect, "color", new_fog, fade_time)


func _setup_tiles() -> void:
	if not background_texture:
		return

	_tile_width = background_texture.get_width() * texture_scale.x
	var base_y: float = ground_y - (texture_ground_y * texture_scale.y)

	for i in range(tile_count):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = background_texture
		sprite.scale = texture_scale
		sprite.centered = false
		sprite.z_index = -50
		sprite.position = Vector2((i - 1) * _tile_width, base_y)
		add_child(sprite)
		_sprites.append(sprite)


func _setup_fog() -> void:
	_fog_rect = ColorRect.new()
	_fog_rect.color = fog_color
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_rect.z_index = -45

	var total_w: float = _tile_width * float(tile_count + 2)
	var base_y: float = ground_y - (texture_ground_y * texture_scale.y) - 200.0
	var total_h: float = (background_texture.get_height() * texture_scale.y) + 400.0 if background_texture else 1200.0

	_fog_rect.position = Vector2(-_tile_width * 2.0, base_y)
	_fog_rect.size = Vector2(total_w, total_h)
	add_child(_fog_rect)


func _process(_delta: float) -> void:
	if not _camera:
		_camera = get_viewport().get_camera_2d()
		if not _camera:
			return

	# get_screen_center_position(), Camera2D smoothing (yumuşatma) ile senkronize gerçek kare koordinatını verir
	var cam_pos: Vector2 = _camera.get_screen_center_position()
	if not _is_initialized:
		_origin_cam = cam_pos
		_origin_node = global_position
		_is_initialized = true

	var cam_delta: Vector2 = cam_pos - _origin_cam

	# X ekseninde sakin ve akıcı (%5 hızında) arka plan kayması
	global_position.x = _origin_node.x + cam_delta.x * (1.0 - parallax_factor_x)

	# Y ekseninde kameraya %98 oranında kilitlenerek zıplamalarda ayın/dağların zıplamasını ve mide bulantısını önler
	global_position.y = _origin_node.y + cam_delta.y * (1.0 - parallax_factor_y)

	# Görüş alanından çıkan tile'ları sakin şekilde sar (wrap)
	if _tile_width > 0.0 and _sprites.size() > 0:
		var wrap_span: float = _tile_width * float(_sprites.size())
		for sprite in _sprites:
			var rel_x: float = sprite.global_position.x - cam_pos.x
			if rel_x < -_tile_width * 1.5:
				sprite.position.x += wrap_span
			elif rel_x > _tile_width * 1.5:
				sprite.position.x -= wrap_span
