extends Node2D

## res://scripts/effects/sword_seal_leak_vfx.gd
## 3. Anı Kırılması sonrası kılıç evrimi (Epic 2D-143): kılıçtaki çatlaklardan sızan
## kızıl-mavi büyü parçacıkları ve HUD'da "mühür yarı yarıya zayıfladı" rozeti.
## Kullanım: SealLeakVfx.attach_to(player, hud) — iki kez çağrılırsa ikinciyi yok sayar.

const NODE_NAME: String = "SwordSealLeak"
const BADGE_NAME: String = "SealWeakenedBadge"
const PARTICLE_TEX: Texture2D = preload("res://assets/effects/egypt/seal_leak.png")
const ICON_TEX: Texture2D = preload("res://assets/ui/egypt/seal_crack_icon.png")
const CRIMSON: Color = Color(1.0, 0.25, 0.35, 0.9)
const AZURE: Color = Color(0.35, 0.55, 1.0, 0.9)

var _player: Node2D = null
var _crimson: CPUParticles2D = null
var _azure: CPUParticles2D = null


static func attach_to(player: Node2D, hud: CanvasLayer = null) -> Node2D:
	if not is_instance_valid(player):
		return null
	var vfx: Node2D = player.get_node_or_null(NODE_NAME) as Node2D
	if vfx == null:
		vfx = (load("res://scripts/effects/sword_seal_leak_vfx.gd") as GDScript).new() as Node2D
		vfx.name = NODE_NAME
		player.add_child(vfx)
	if hud and is_instance_valid(hud) and hud.get_node_or_null(BADGE_NAME) == null:
		var badge: Control = _build_badge(hud)
		hud.add_child(badge)
		_pulse_badge(badge)
	return vfx


func _ready() -> void:
	_player = get_parent() as Node2D
	z_index = 5
	_crimson = _make_emitter(CRIMSON, Vector2(0.0, -1.0))
	_azure = _make_emitter(AZURE, Vector2(0.3, -1.0))
	add_child(_crimson)
	add_child(_azure)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var facing: float = float(_player.get("facing_dir")) if "facing_dir" in _player else 1.0
	position = Vector2(14.0 * facing, -24.0)
	# Saldırı sırasında sızıntı yoğunlaşır
	var attacking: bool = bool(_player.get("is_attacking")) if "is_attacking" in _player else false
	var rate: float = 1.0 if attacking else 0.45
	_crimson.speed_scale = 0.6 + rate
	_azure.speed_scale = 0.6 + rate


func is_leaking() -> bool:
	return _crimson != null and _crimson.emitting and _azure != null and _azure.emitting


func _make_emitter(color: Color, dir: Vector2) -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.texture = PARTICLE_TEX
	p.amount = 14
	p.lifetime = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(3.0, 12.0)
	p.direction = dir
	p.spread = 25.0
	p.gravity = Vector2(0.0, -30.0)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.55
	p.color = color
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	p.emitting = true
	return p


static func _build_badge(hud: CanvasLayer) -> Control:
	var box: HBoxContainer = HBoxContainer.new()
	box.name = BADGE_NAME
	box.position = Vector2(20.0, 120.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	var icon: TextureRect = TextureRect.new()
	icon.texture = ICON_TEX
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(icon)
	var label: Label = Label.new()
	label.text = hud.tr("HUD_SEAL_WEAKENED")
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.85, 0.55, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	box.add_child(label)
	return box


## Rozet simgesi kızıl ↔ mavi nabız atar (yanıp sönmeyi azalt açıksa sabit kalır)
static func _pulse_badge(badge: Control) -> void:
	if not badge.is_inside_tree():
		return
	var cm: Node = badge.get_node_or_null("/root/CinematicManager")
	if cm != null and "reduce_flashing" in cm and bool(cm.reduce_flashing):
		return
	var icon: CanvasItem = badge.get_child(0) as CanvasItem
	var tw: Tween = icon.create_tween().set_loops()
	tw.tween_property(icon, "modulate", Color(1.4, 0.6, 0.8), 0.9)
	tw.tween_property(icon, "modulate", Color(0.7, 0.9, 1.5), 0.9)
