class_name Stoneage04Parallax
extends Node2D

## res://scripts/levels/stoneage/stoneage_04_parallax.gd
## Taş Devri — Bölüm 04: Avcıların İzleri (Stone Age Level 04 Parallax Manager)
## - Uzak sisli kanopi (x0.08, z=-40)
## - Orta mesafe parçalanmış orman (x0.22, z=-30)
## - Yakın plan ilkel ağaç gövdeleri ve kökler (x0.45, z=-20)
## - Ön plan sarkan sarmaşıklar ve çerçeveleme (x1.15, z=30)
## - Kesintisiz yatay döngü (sonsuz wrap)

const TILE_COUNT: int = 4
const TILE_WIDTH: float = 1918.0
const BASE_Y: float = -220.0

const PARALLAX_FAR_X: float = 0.08
const PARALLAX_FAR_Y: float = 0.02
const PARALLAX_MID_X: float = 0.22
const PARALLAX_MID_Y: float = 0.04
const PARALLAX_NEAR_X: float = 0.45
const PARALLAX_NEAR_Y: float = 0.06
const PARALLAX_FG_X: float = 1.15
const PARALLAX_FG_Y: float = 0.08

var _camera: Camera2D = null
var _origin_cam: Vector2 = Vector2.ZERO
var _origin_node: Vector2 = Vector2.ZERO
var _is_initialized: bool = false

var _layer_far: Node2D = null
var _layer_mid: Node2D = null
var _layer_near: Node2D = null
var _layer_fg: Node2D = null

var _far_sprites: Array[Sprite2D] = []
var _mid_sprites: Array[Sprite2D] = []
var _near_sprites: Array[Sprite2D] = []
var _fg_sprites: Array[Sprite2D] = []


func _ready() -> void:
	z_index = -50
	_create_layers()


func _create_layers() -> void:
	# 1. Uzak Sisli Kanopi (z=-40)
	_layer_far = Node2D.new()
	_layer_far.name = "LayerFarMistyCanopy"
	_layer_far.z_index = -40
	var tex_far: Texture2D = load("res://assets/backgrounds/stoneage/hunters_far_misty_canopy.png")
	for k: int in range(TILE_COUNT):
		var sp: Sprite2D = Sprite2D.new()
		sp.texture = tex_far
		sp.centered = false
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.position = Vector2((k - 1) * TILE_WIDTH, BASE_Y)
		_layer_far.add_child(sp)
		_far_sprites.append(sp)
	add_child(_layer_far)

	# 2. Orta Mesafe Parçalanmış Orman (z=-30)
	_layer_mid = Node2D.new()
	_layer_mid.name = "LayerMidShatteredForest"
	_layer_mid.z_index = -30
	var tex_mid: Texture2D = load("res://assets/backgrounds/stoneage/hunters_mid_shattered_forest.png")
	for k: int in range(TILE_COUNT):
		var sp: Sprite2D = Sprite2D.new()
		sp.texture = tex_mid
		sp.centered = false
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.position = Vector2((k - 1) * TILE_WIDTH, BASE_Y)
		_layer_mid.add_child(sp)
		_mid_sprites.append(sp)
	add_child(_layer_mid)

	# 3. Yakın İlkel Ağaç Gövdeleri (z=-20)
	_layer_near = Node2D.new()
	_layer_near.name = "LayerNearDenseThicket"
	_layer_near.z_index = -20
	var tex_near: Texture2D = load("res://assets/backgrounds/stoneage/hunters_near_dense_thicket.png")
	for k: int in range(TILE_COUNT):
		var sp: Sprite2D = Sprite2D.new()
		sp.texture = tex_near
		sp.centered = false
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.position = Vector2((k - 1) * TILE_WIDTH, BASE_Y)
		_layer_near.add_child(sp)
		_near_sprites.append(sp)
	add_child(_layer_near)

	# 4. Ön Plan Sarkan Sarmaşıklar (z=30)
	_layer_fg = Node2D.new()
	_layer_fg.name = "LayerForegroundVines"
	_layer_fg.z_index = 30
	var tex_fg: Texture2D = load("res://assets/backgrounds/stoneage/hunters_fg_vines_foliage.png")
	for k: int in range(TILE_COUNT):
		var sp: Sprite2D = Sprite2D.new()
		sp.texture = tex_fg
		sp.centered = false
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.position = Vector2((k - 1) * TILE_WIDTH, BASE_Y)
		_layer_fg.add_child(sp)
		_fg_sprites.append(sp)
	add_child(_layer_fg)


func _process(_delta: float) -> void:
	if not _camera:
		var vp: Viewport = get_viewport()
		if vp:
			_camera = vp.get_camera_2d()
		if not _camera:
			_camera = get_node_or_null("../CombatPlayer/Camera2D") as Camera2D
		if not _camera:
			return

	var cam_pos: Vector2 = _camera.get_screen_center_position()
	if not _is_initialized:
		_origin_cam = cam_pos
		_origin_node = global_position
		_is_initialized = true

	var cam_delta: Vector2 = cam_pos - _origin_cam

	if _layer_far:
		_layer_far.global_position.x = _origin_node.x + cam_delta.x * (1.0 - PARALLAX_FAR_X)
		_layer_far.global_position.y = _origin_node.y + cam_delta.y * (1.0 - PARALLAX_FAR_Y)
		_wrap_tiles(_far_sprites, TILE_WIDTH, cam_pos.x)

	if _layer_mid:
		_layer_mid.global_position.x = _origin_node.x + cam_delta.x * (1.0 - PARALLAX_MID_X)
		_layer_mid.global_position.y = _origin_node.y + cam_delta.y * (1.0 - PARALLAX_MID_Y)
		_wrap_tiles(_mid_sprites, TILE_WIDTH, cam_pos.x)

	if _layer_near:
		_layer_near.global_position.x = _origin_node.x + cam_delta.x * (1.0 - PARALLAX_NEAR_X)
		_layer_near.global_position.y = _origin_node.y + cam_delta.y * (1.0 - PARALLAX_NEAR_Y)
		_wrap_tiles(_near_sprites, TILE_WIDTH, cam_pos.x)

	if _layer_fg:
		_layer_fg.global_position.x = _origin_node.x - cam_delta.x * (PARALLAX_FG_X - 1.0)
		_layer_fg.global_position.y = _origin_node.y - cam_delta.y * (PARALLAX_FG_Y - 1.0)
		_wrap_tiles(_fg_sprites, TILE_WIDTH, cam_pos.x)


func _wrap_tiles(sprites: Array[Sprite2D], tile_w: float, cam_x: float) -> void:
	if tile_w <= 0.0 or sprites.is_empty():
		return
	var span: float = tile_w * float(sprites.size())
	for s: Sprite2D in sprites:
		var rel_x: float = s.global_position.x - cam_x
		if rel_x < -tile_w * 1.5:
			s.position.x += span
		elif rel_x > tile_w * 1.5:
			s.position.x -= span
