extends Node2D

## res://scripts/effects/sword_vow_aura_vfx.gd
## 4. Anı Kırılması sonrası kılıç evrimi (Epic 2D-144): Bölüm 3'ün kızıl-mavi mühür
## sızıntısı kızıl-altın bir aleve döner, kılıcın çevresinde nabız gibi atan bir aura ışığı
## eklenir ve HUD rozeti "mühür son günlerini sayıyor" olarak güncellenir.
## Kullanım: VowAura.attach_to(player, hud) — tekrar çağrılırsa mevcut olanı döndürür.

const SealLeakVfx = preload("res://scripts/effects/sword_seal_leak_vfx.gd")
const LIGHT_TEX: Texture2D = preload("res://assets/effects/lighting/light_radial_falloff.png")
const NODE_NAME: String = "SwordVowAura"
const CRIMSON: Color = Color(1.0, 0.2, 0.25, 0.95)
const GOLD: Color = Color(1.0, 0.78, 0.3, 0.95)

var _light: PointLight2D = null
var _t: float = 0.0


static func attach_to(player: Node2D, hud: CanvasLayer = null) -> Node2D:
	if not is_instance_valid(player):
		return null
	var leak: Node2D = SealLeakVfx.attach_to(player, hud)
	_recolor(leak)
	if hud and is_instance_valid(hud):
		var badge: Control = hud.get_node_or_null(SealLeakVfx.BADGE_NAME) as Control
		if badge:
			badge.modulate = Color(1.0, 0.75, 0.4)
			badge.tooltip_text = badge.tr("HUD_SEAL_VOW")
	var vfx: Node2D = player.get_node_or_null(NODE_NAME) as Node2D
	if vfx == null:
		vfx = (load("res://scripts/effects/sword_vow_aura_vfx.gd") as GDScript).new() as Node2D
		vfx.name = NODE_NAME
		player.add_child(vfx)
	return vfx


## Mühür sızıntısının parçacık renklerini kızıl-altına çevirir (emitter'lar hazır olunca)
static func _recolor(leak: Node2D) -> void:
	if not is_instance_valid(leak):
		return
	if not leak.is_node_ready():
		leak.ready.connect(_recolor.bind(leak), CONNECT_ONE_SHOT)
		return
	var emitters: Array[Node] = leak.find_children("*", "CPUParticles2D", false, false)
	for i: int in emitters.size():
		(emitters[i] as CPUParticles2D).color = CRIMSON if i % 2 == 0 else GOLD


func _ready() -> void:
	_light = PointLight2D.new()
	_light.texture = LIGHT_TEX
	_light.color = GOLD
	_light.energy = 0.5
	_light.texture_scale = 0.6
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	var player: Node2D = get_parent() as Node2D
	var facing: float = float(player.get("facing_dir")) if player and "facing_dir" in player else 1.0
	position = Vector2(14.0 * facing, -24.0)
	if _light:
		_light.energy = 0.45 + 0.25 * absf(sin(_t * 3.0))


func is_glowing() -> bool:
	return _light != null and _light.energy > 0.0
