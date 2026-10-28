class_name ParallaxDepthLayer
extends Node2D

## res://scripts/objects/parallax_depth_layer.gd
## Kamera yumuşatması (smoothing) ile senkronize 2D derinlik ve mimari parallax katmanı.
## Dört arena boyunca mimari siluetleri, orta plan sütunlarını ve kontrollü ön plan dekorlarını
## titreşimsiz ve akıcı bir derinlik hissiyle hareket ettirir.

@export var parallax_factor_x: float = 0.15 ## 1.0 altı = arka plan (kameradan yavaş), 1.0 üstü = ön plan (kameradan hızlı)
@export var parallax_factor_y: float = 0.03 ## Dikey zıplamalarda kamera sarsıntısını engellemek için düşük tutulur
@export var anchor_x: float = 600.0 ## İlgili arenanın odak merkezi (Arena1=600, Arena2=1950, Arena3=3350, Arena4=4850)
@export var anchor_y: float = 380.0 ## Dikey odak noktası
@export var active_cam_min: float = -99999.0 ## Kamera bu X koordinatından küçükken katmanı gizle
@export var active_cam_max: float = 99999.0 ## Kamera bu X koordinatından büyükken katmanı gizle

var _camera: Camera2D = null
var _origin_node: Vector2 = Vector2.ZERO
var _is_initialized: bool = false


func _ready() -> void:
	process_priority = 100
	_origin_node = position


func set_camera(cam: Camera2D) -> void:
	_camera = cam


func _process(_delta: float) -> void:
	if not _camera:
		var vp: Viewport = get_viewport()
		if vp:
			_camera = vp.get_camera_2d()
	if not _camera:
		return

	var cam_pos: Vector2 = _camera.get_screen_center_position()
	if cam_pos == Vector2.ZERO and _camera.global_position != Vector2.ZERO:
		cam_pos = _camera.global_position

	# Arenalar arası görsel sızmayı (bleed) ve istenmeyen örtüşmeleri önleme
	if active_cam_min > -90000.0 or active_cam_max < 90000.0:
		var in_range: bool = cam_pos.x >= active_cam_min and cam_pos.x <= active_cam_max
		visible = in_range
		if not in_range:
			return

	if not _is_initialized:
		_origin_node = position
		_is_initialized = true

	var cam_delta_x: float = cam_pos.x - anchor_x
	var cam_delta_y: float = cam_pos.y - anchor_y

	# Parallax bağıl hareket formülü:
	# Kamera anchor noktasındayken (cam_delta = 0) nesne tam olarak sahne tasarımındaki _origin_node konumundadır.
	# Kamera hareket ettikçe nesnenin ekrandaki kayması tam olarak (parallax_factor) oranında gerçekleşir.
	position.x = _origin_node.x + cam_delta_x * (1.0 - parallax_factor_x)
	position.y = _origin_node.y + cam_delta_y * (1.0 - parallax_factor_y)
