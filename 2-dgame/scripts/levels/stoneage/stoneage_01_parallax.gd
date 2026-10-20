class_name Stoneage01Parallax
extends Node2D

## res://scripts/levels/stoneage/stoneage_01_parallax.gd
## Taş Devri Level 01 için çok katmanlı, akıcı 16-bit pixel-art parallax arka plan sistemi.
## Dikey kamera zıplamalarında sarsıntıyı ve titremeyi önler.

@export var ground_y: float = 590.0

const FAR_TEXTURE: Texture2D = preload("res://assets/backgrounds/stoneage/bg_far_mountains.png")
const MID_TEXTURE: Texture2D = preload("res://assets/backgrounds/stoneage/bg_mid_canopy.png")
const NEAR_TEXTURE: Texture2D = preload("res://assets/backgrounds/stoneage/bg_near_cliffs.png")
const FG_TEXTURE: Texture2D = preload("res://assets/backgrounds/stoneage/fg_vines_framing.png")

const TILE_COUNT: int = 3
const SCALE_VEC: Vector2 = Vector2(1.0, 1.0)

const PARALLAX_FAR_X: float = 0.05
const PARALLAX_FAR_Y: float = 0.015
const PARALLAX_MID_X: float = 0.16
const PARALLAX_MID_Y: float = 0.04
const PARALLAX_NEAR_X: float = 0.30
const PARALLAX_NEAR_Y: float = 0.06
const PARALLAX_FG_X: float = 1.12
const PARALLAX_FG_Y: float = 1.05

var _camera: Camera2D = null
var _origin_cam: Vector2 = Vector2.ZERO
var _origin_node: Vector2 = Vector2.ZERO
var _is_initialized: bool = false

var _far_container: Node2D = null
var _mid_container: Node2D = null
var _near_container: Node2D = null
var _fg_container: Node2D = null

var _far_sprites: Array[Sprite2D] = []
var _mid_sprites: Array[Sprite2D] = []
var _near_sprites: Array[Sprite2D] = []
var _fg_sprites: Array[Sprite2D] = []

var _tile_width: float = 1376.0


func _ready() -> void:
	z_index = -50
	_build_layers()


func _build_layers() -> void:
	_tile_width = FAR_TEXTURE.get_width() * SCALE_VEC.x
	var base_y: float = ground_y - (FAR_TEXTURE.get_height() * SCALE_VEC.y * 0.90)

	# 1. Uzak Dağlar (Z = -50)
	_far_container = Node2D.new()
	_far_container.z_index = -50
	add_child(_far_container)
	for i in range(TILE_COUNT):
		var s: Sprite2D = Sprite2D.new()
		s.texture = FAR_TEXTURE
		s.scale = SCALE_VEC
		s.centered = false
		s.position = Vector2((i - 1) * _tile_width, base_y)
		_far_container.add_child(s)
		_far_sprites.append(s)

	# 2. Orta Kanopi Ormanı (Z = -40)
	_mid_container = Node2D.new()
	_mid_container.z_index = -40
	add_child(_mid_container)
	for i in range(TILE_COUNT):
		var s: Sprite2D = Sprite2D.new()
		s.texture = MID_TEXTURE
		s.scale = SCALE_VEC
		s.centered = false
		s.position = Vector2((i - 1) * _tile_width, base_y)
		_mid_container.add_child(s)
		_mid_sprites.append(s)

	# 3. Yakın Kayalıklar ve Kökler (Z = -30)
	_near_container = Node2D.new()
	_near_container.z_index = -30
	add_child(_near_container)
	for i in range(TILE_COUNT):
		var s: Sprite2D = Sprite2D.new()
		s.texture = NEAR_TEXTURE
		s.scale = SCALE_VEC
		s.centered = false
		s.position = Vector2((i - 1) * _tile_width, base_y)
		_near_container.add_child(s)
		_near_sprites.append(s)

	# 4. Ön Plan Sarmaşık Çerçevesi (Z = 20)
	_fg_container = Node2D.new()
	_fg_container.z_index = 20
	add_child(_fg_container)
	for i in range(TILE_COUNT):
		var s: Sprite2D = Sprite2D.new()
		s.texture = FG_TEXTURE
		s.scale = SCALE_VEC
		s.centered = false
		s.position = Vector2((i - 1) * _tile_width, base_y - 20.0)
		_fg_container.add_child(s)
		_fg_sprites.append(s)


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

	if _far_container:
		_far_container.global_position.x = _origin_node.x + cam_delta.x * (1.0 - PARALLAX_FAR_X)
		_far_container.global_position.y = _origin_node.y + cam_delta.y * (1.0 - PARALLAX_FAR_Y)
		_wrap_tiles(_far_sprites, _tile_width, cam_pos.x)

	if _mid_container:
		_mid_container.global_position.x = _origin_node.x + cam_delta.x * (1.0 - PARALLAX_MID_X)
		_mid_container.global_position.y = _origin_node.y + cam_delta.y * (1.0 - PARALLAX_MID_Y)
		_wrap_tiles(_mid_sprites, _tile_width, cam_pos.x)

	if _near_container:
		_near_container.global_position.x = _origin_node.x + cam_delta.x * (1.0 - PARALLAX_NEAR_X)
		_near_container.global_position.y = _origin_node.y + cam_delta.y * (1.0 - PARALLAX_NEAR_Y)
		_wrap_tiles(_near_sprites, _tile_width, cam_pos.x)

	if _fg_container:
		_fg_container.global_position.x = _origin_node.x - cam_delta.x * (PARALLAX_FG_X - 1.0)
		_fg_container.global_position.y = _origin_node.y - cam_delta.y * (PARALLAX_FG_Y - 1.0)
		_wrap_tiles(_fg_sprites, _tile_width, cam_pos.x)


func _wrap_tiles(sprites: Array[Sprite2D], tile_w: float, cam_x: float) -> void:
	if tile_w <= 0.0 or sprites.is_empty():
		return
	var span: float = tile_w * float(sprites.size())
	for s in sprites:
		var rel_x: float = s.global_position.x - cam_x
		if rel_x < -tile_w * 1.5:
			s.position.x += span
		elif rel_x > tile_w * 1.5:
			s.position.x -= span
