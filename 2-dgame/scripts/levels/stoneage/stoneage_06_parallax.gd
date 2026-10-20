class_name Stoneage06Parallax
extends Node2D

## res://scripts/levels/stoneage/stoneage_06_parallax.gd
## Taş Devri — Bölüm 06: Dev Yaratığın Bölgesi Parallax Arka Plan Yöneticisi
## - Uzak fırtınalı dağ zirveleri ve sisli kanyonlar (x0.10, z=-40)
## - Orta mesafe devasa kırılmış tarih öncesi ağaç gövdeleri ve kanopi (x0.25, z=-30)
## - Yakın plan fosil monolitleri, dev kemik siluetleri ve sarp kayalıklar (x0.55, z=-20)
## - Ön plan devasa sarkan kökler ve ön kaya çerçeveleme (x1.15, z=30)
## - Kesintisiz yatay döngü (3x1918px = 5754px genişlik)

@export var camera_path: NodePath = ^"../CombatPlayer/Camera2D"

var _camera: Camera2D = null
var _layer_far: Node2D = null
var _layer_mid: Node2D = null
var _layer_near: Node2D = null
var _layer_fg: Node2D = null

var _start_cam_x: float = 0.0


func _ready() -> void:
	_create_layers()
	_find_camera()


func _create_layers() -> void:
	# 1. Uzak Fırtınalı Zirveler (Far Colossal Peaks, z=-40)
	_layer_far = Node2D.new()
	_layer_far.name = "LayerFarColossalPeaks"
	_layer_far.z_index = -40
	var tex_far = load("res://assets/backgrounds/stoneage/domain_far_colossal_peaks.png")
	for k in range(3):
		var sp = Sprite2D.new()
		sp.texture = tex_far
		sp.centered = false
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.position = Vector2(k * 1918, -220)
		_layer_far.add_child(sp)
	add_child(_layer_far)

	# 2. Orta Mesafe Titanik Kanopi & Kırık Gövdeler (Mid Titanic Canopy, z=-30)
	_layer_mid = Node2D.new()
	_layer_mid.name = "LayerMidTitanicCanopy"
	_layer_mid.z_index = -30
	var tex_mid = load("res://assets/backgrounds/stoneage/domain_mid_titanic_canopy.png")
	for k in range(3):
		var sp = Sprite2D.new()
		sp.texture = tex_mid
		sp.centered = false
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.position = Vector2(k * 1918, -220)
		_layer_mid.add_child(sp)
	add_child(_layer_mid)

	# 3. Yakın Fosil Kayalıklar & Monolitler (Near Bone Crags, z=-20)
	_layer_near = Node2D.new()
	_layer_near.name = "LayerNearBoneCrags"
	_layer_near.z_index = -20
	var tex_near = load("res://assets/backgrounds/stoneage/domain_near_bone_crags.png")
	for k in range(3):
		var sp = Sprite2D.new()
		sp.texture = tex_near
		sp.centered = false
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.position = Vector2(k * 1918, -220)
		_layer_near.add_child(sp)
	add_child(_layer_near)

	# 4. Ön Plan Devasa Kök Çerçeveleme (Foreground Framing Roots, z=30)
	_layer_fg = Node2D.new()
	_layer_fg.name = "LayerForegroundFramingRoots"
	_layer_fg.z_index = 30
	var tex_fg = load("res://assets/backgrounds/stoneage/domain_fg_framing_roots.png")
	for k in range(3):
		var sp = Sprite2D.new()
		sp.texture = tex_fg
		sp.centered = false
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.position = Vector2(k * 1918, -220)
		_layer_fg.add_child(sp)
	add_child(_layer_fg)


func _find_camera() -> void:
	if has_node(camera_path):
		_camera = get_node(camera_path) as Camera2D
	else:
		_camera = get_viewport().get_camera_2d()

	if _camera:
		_start_cam_x = _camera.global_position.x


func _process(_delta: float) -> void:
	if not _camera:
		_find_camera()
		if not _camera:
			return

	var cam_x: float = _camera.global_position.x
	var offset_x: float = cam_x - _start_cam_x

	if _layer_far:
		_layer_far.position.x = offset_x * 0.10
	if _layer_mid:
		_layer_mid.position.x = offset_x * 0.25
	if _layer_near:
		_layer_near.position.x = offset_x * 0.55
	if _layer_fg:
		_layer_fg.position.x = offset_x * 1.15
