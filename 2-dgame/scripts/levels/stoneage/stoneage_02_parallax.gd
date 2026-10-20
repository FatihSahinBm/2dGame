class_name Stoneage02Parallax
extends Node2D

## res://scripts/levels/stoneage/stoneage_02_parallax.gd
## Taş Devri — Level 02: Sessiz Vadi Parallax Arka Plan Sistemi.
## Sisli dağlar, ilkel vadi kanopisi ve dikey kanyon kayalıklarıyla 4 katmanlı derinlik sunar.

@export var ground_y: float = 590.0

const FAR_TEXTURE: Texture2D = preload("res://assets/backgrounds/stoneage/valley_far_mountains.png")
const MID_TEXTURE: Texture2D = preload("res://assets/backgrounds/stoneage/valley_mid_jungle.png")
const TILE_COUNT: int = 5
const SCALE_VEC: Vector2 = Vector2(1.0, 1.0)
const PARALLAX_FAR_X: float = 0.06
const PARALLAX_FAR_Y: float = 0.02
const PARALLAX_MID_X: float = 0.18
const PARALLAX_MID_Y: float = 0.05

var _camera: Camera2D = null
var _origin_cam: Vector2 = Vector2.ZERO
var _origin_node: Vector2 = Vector2.ZERO
var _is_initialized: bool = false

var _far_container: Node2D = null
var _mid_container: Node2D = null

var _far_sprites: Array[Sprite2D] = []
var _mid_sprites: Array[Sprite2D] = []

var _tile_width: float = 1376.0


func _ready() -> void:
	z_index = -50
	_build_layers()


func _build_layers() -> void:
	_tile_width = FAR_TEXTURE.get_width() * SCALE_VEC.x
	var base_y: float = ground_y - (FAR_TEXTURE.get_height() * SCALE_VEC.y * 0.90)

	# 1. Uzak Dağlar & Sisli Vadi (Z = -50)
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

	# 3. Atmosferik Derinlik Rengi (Z = -35)
	var tint: ColorRect = ColorRect.new()
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.z_index = -35
	tint.color = Color(0.04, 0.08, 0.05, 0.12)
	tint.size = Vector2(8000.0, 1600.0)
	tint.position = Vector2(-2000.0, -600.0)
	add_child(tint)


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
