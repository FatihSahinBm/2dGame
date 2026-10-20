class_name PrehistoricParallaxBackground
extends Node2D

## res://scripts/levels/stone_age/prehistoric_parallax_background.gd
## Tarih Öncesi Vadi & Siber T-Rex Arenası için çok katmanlı, akıcı ve derinlikli
## Parallax Arka Plan Sistemi. Kamera sarsıntı ve zıplama titreşimlerini önler.

@export var ground_y: float = 590.0
@export var level_width: float = 5500.0

const SKY_TEXTURE: Texture2D = preload("res://assets/backgrounds/prehistoric_sky_mountains.png")
const JUNGLE_TEXTURE: Texture2D = preload("res://assets/backgrounds/prehistoric_jungle_mid.png")
const RIFT_ARENA_TEXTURE: Texture2D = preload("res://assets/backgrounds/prehistoric_rift_arena.png")

const TILE_COUNT: int = 5
const SCALE_FAR: Vector2 = Vector2(1.0, 1.0)
const SCALE_MID: Vector2 = Vector2(1.0, 1.0)
const SCALE_NEAR: Vector2 = Vector2(1.0, 1.0)

const PARALLAX_FAR_X: float = 0.06
const PARALLAX_FAR_Y: float = 0.02
const PARALLAX_MID_X: float = 0.18
const PARALLAX_MID_Y: float = 0.05
const PARALLAX_NEAR_X: float = 0.32
const PARALLAX_NEAR_Y: float = 0.08

var _camera: Camera2D = null
var _origin_cam: Vector2 = Vector2.ZERO
var _origin_node: Vector2 = Vector2.ZERO
var _is_initialized: bool = false

var _sky_container: Node2D = null
var _jungle_container: Node2D = null
var _rift_container: Node2D = null

var _sky_sprites: Array[Sprite2D] = []
var _jungle_sprites: Array[Sprite2D] = []
var _rift_sprites: Array[Sprite2D] = []

var _sky_tile_width: float = 0.0
var _jungle_tile_width: float = 0.0
var _rift_tile_width: float = 0.0

var _atmosphere_tint: ColorRect = null


func _ready() -> void:
	z_index = -50
	_build_layers()
	_setup_atmosphere_tint()


func _build_layers() -> void:
	# 1. Uzak Dağlar ve Gökyüzü Katmanı (Z = -50)
	_sky_container = Node2D.new()
	_sky_container.z_index = -50
	add_child(_sky_container)
	_sky_tile_width = SKY_TEXTURE.get_width() * SCALE_FAR.x
	var sky_base_y: float = ground_y - (SKY_TEXTURE.get_height() * SCALE_FAR.y * 0.88)
	for i in range(TILE_COUNT):
		var s: Sprite2D = Sprite2D.new()
		s.texture = SKY_TEXTURE
		s.scale = SCALE_FAR
		s.centered = false
		s.position = Vector2((i - 1) * _sky_tile_width, sky_base_y)
		_sky_container.add_child(s)
		_sky_sprites.append(s)

	# 2. İlkel Orman Orta Katmanı (Z = -40)
	_jungle_container = Node2D.new()
	_jungle_container.z_index = -40
	add_child(_jungle_container)
	_jungle_tile_width = JUNGLE_TEXTURE.get_width() * SCALE_MID.x
	var jungle_base_y: float = ground_y - (JUNGLE_TEXTURE.get_height() * SCALE_MID.y * 0.92)
	for i in range(TILE_COUNT):
		var s: Sprite2D = Sprite2D.new()
		s.texture = JUNGLE_TEXTURE
		s.scale = SCALE_MID
		s.centered = false
		s.position = Vector2((i - 1) * _jungle_tile_width, jungle_base_y)
		_jungle_container.add_child(s)
		_jungle_sprites.append(s)

	# 3. Siber Zaman Yarığı & Arenaya Geçiş Katmanı (Z = -30)
	_rift_container = Node2D.new()
	_rift_container.z_index = -30
	add_child(_rift_container)
	_rift_tile_width = RIFT_ARENA_TEXTURE.get_width() * SCALE_NEAR.x
	var rift_base_y: float = ground_y - (RIFT_ARENA_TEXTURE.get_height() * SCALE_NEAR.y * 0.90)
	for i in range(TILE_COUNT):
		var s: Sprite2D = Sprite2D.new()
		s.texture = RIFT_ARENA_TEXTURE
		s.scale = SCALE_NEAR
		s.centered = false
		s.modulate.a = 0.0
		s.position = Vector2((i - 1) * _rift_tile_width, rift_base_y)
		_rift_container.add_child(s)
		_rift_sprites.append(s)


func _setup_atmosphere_tint() -> void:
	_atmosphere_tint = ColorRect.new()
	_atmosphere_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atmosphere_tint.z_index = -25
	_atmosphere_tint.color = Color(0.04, 0.08, 0.05, 0.15)
	_atmosphere_tint.size = Vector2(8000.0, 1600.0)
	_atmosphere_tint.position = Vector2(-2000.0, -600.0)
	add_child(_atmosphere_tint)


func _process(_delta: float) -> void:
	if not _camera:
		_camera = get_viewport().get_camera_2d()
		if not _camera:
			return

	var cam_pos: Vector2 = _camera.get_screen_center_position()
	if not _is_initialized:
		_origin_cam = cam_pos
		_origin_node = global_position
		_is_initialized = true

	var cam_delta: Vector2 = cam_pos - _origin_cam

	# Katman 1: Gökyüzü ve Uzak Dağlar
	if _sky_container:
		_sky_container.global_position.x = _origin_node.x + cam_delta.x * (1.0 - PARALLAX_FAR_X)
		_sky_container.global_position.y = _origin_node.y + cam_delta.y * (1.0 - PARALLAX_FAR_Y)
		_wrap_tiles(_sky_sprites, _sky_tile_width, cam_pos.x)

	# Katman 2: İlkel Orman
	if _jungle_container:
		_jungle_container.global_position.x = _origin_node.x + cam_delta.x * (1.0 - PARALLAX_MID_X)
		_jungle_container.global_position.y = _origin_node.y + cam_delta.y * (1.0 - PARALLAX_MID_Y)
		_wrap_tiles(_jungle_sprites, _jungle_tile_width, cam_pos.x)

	# Katman 3: Siber Zaman Yarığı & Arenaya Geçiş
	if _rift_container:
		_rift_container.global_position.x = _origin_node.x + cam_delta.x * (1.0 - PARALLAX_NEAR_X)
		_rift_container.global_position.y = _origin_node.y + cam_delta.y * (1.0 - PARALLAX_NEAR_Y)
		_wrap_tiles(_rift_sprites, _rift_tile_width, cam_pos.x)

	_update_dynamic_atmosphere(cam_pos.x)


func _wrap_tiles(sprites: Array[Sprite2D], tile_w: float, cam_x: float) -> void:
	if tile_w <= 0.0 or sprites.is_empty():
		return
	var span: float = tile_w * float(sprites.size())
	for s in sprites:
		var rel_x: float = s.global_position.x - cam_x
		if rel_x < -tile_w * 1.8:
			s.position.x += span
		elif rel_x > tile_w * 2.2:
			s.position.x -= span


func _update_dynamic_atmosphere(cam_x: float) -> void:
	# Bölüm boyunca ilerledikçe (0 -> 5000px):
	# 0 - 2000px: Vadi & Başlangıç (Zümrüt Yeşili & Amber İlkel Orman)
	# 2000 - 3800px: Zaman Yarığı Bozulma Geçişi (Cyan & Amber Elektrik)
	# 3800 - 5500px: Siber T-Rex Boss Arenası (Karanlık Volkanik Siber Fırtına)
	var progress: float = clampf((cam_x - 1800.0) / 2200.0, 0.0, 1.0)

	# Siber yarığın görünürlüğü
	for s in _rift_sprites:
		s.modulate.a = progress * 0.90

	# İlkel ormanın kararması ve siber fırtınaya bürünmesi
	var jungle_mod: Color = Color.WHITE.lerp(Color(0.45, 0.35, 0.40, 0.65), progress)
	for s in _jungle_sprites:
		s.modulate = jungle_mod

	# Atmosfer rengi
	if _atmosphere_tint:
		var jungle_color: Color = Color(0.04, 0.09, 0.06, 0.12)
		var rift_color: Color = Color(0.14, 0.04, 0.07, 0.42)
		_atmosphere_tint.color = jungle_color.lerp(rift_color, progress)
