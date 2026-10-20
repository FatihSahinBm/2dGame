class_name Stoneage03Parallax
extends Node2D

## res://scripts/levels/stoneage/stoneage_03_parallax.gd
## Taş Devri — Bölüm 03: Kırık Geçit Parallax Arka Plan Yöneticisi
## - Uzak dağ zirveleri (x0.10)
## - Orta mesafe sarp kayalıklar ve doğal kemerler (x0.25)
## - Yakın kaya sütunları ve monolitler (x0.55)
## - Kesintisiz yatay döngü (3x1920px = 5760px genişlik)

@export var camera_path: NodePath = ^"../CombatPlayer/Camera2D"

var _camera: Camera2D = null
var _layer_far: Node2D = null
var _layer_mid: Node2D = null
var _layer_near: Node2D = null

var _start_cam_x: float = 0.0


func _ready() -> void:
	_create_layers()
	_find_camera()


func _create_layers() -> void:
	# 1. Uzak Dağ Zirveleri (Far Peaks, z=-40)
	_layer_far = Node2D.new()
	_layer_far.name = "LayerFarPeaks"
	_layer_far.z_index = -40
	var tex_far = load("res://assets/backgrounds/stoneage/pass_far_peaks.png")
	for k in range(3):
		var sp = Sprite2D.new()
		sp.texture = tex_far
		sp.centered = false
		sp.position = Vector2(k * 1918, -220)
		_layer_far.add_child(sp)
	add_child(_layer_far)

	# 2. Orta Mesafe Sarp Kayalıklar (Mid Cliffs, z=-30)
	_layer_mid = Node2D.new()
	_layer_mid.name = "LayerMidCliffs"
	_layer_mid.z_index = -30
	var tex_mid = load("res://assets/backgrounds/stoneage/pass_mid_cliffs.png")
	for k in range(3):
		var sp = Sprite2D.new()
		sp.texture = tex_mid
		sp.centered = false
		sp.position = Vector2(k * 1918, -220)
		_layer_mid.add_child(sp)
	add_child(_layer_mid)

	# 3. Yakın Kaya Sütunları (Near Pillars, z=-20)
	_layer_near = Node2D.new()
	_layer_near.name = "LayerNearPillars"
	_layer_near.z_index = -20
	var tex_near = load("res://assets/backgrounds/stoneage/pass_near_pillars.png")
	for k in range(3):
		var sp = Sprite2D.new()
		sp.texture = tex_near
		sp.centered = false
		sp.position = Vector2(k * 1918, -220)
		_layer_near.add_child(sp)
	add_child(_layer_near)


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
