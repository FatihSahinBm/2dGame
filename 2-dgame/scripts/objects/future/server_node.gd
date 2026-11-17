class_name ServerNode
extends StaticBody2D

## res://scripts/objects/future/server_node.gd
## Yardımcı sunucu düğümü (Epic 2D-158) — Siber-Ağ Kesintisi yan görevi. Kılıç, EMP veya
## plazma ile yok edilir; yok edilince FutureChapterState'e kalıcı yazılır. Üçü de düşünce
## AI Lord'un Form 1 dron çağrısı ve Form 2 taret desteği %50 azalır.

signal destroyed(node_id: String, total: int)

const ChapterState = preload("res://scripts/components/future_chapter_state.gd")
const FutureFx = preload("res://scripts/effects/future_fx.gd")
const TEX_ON: String = "res://assets/objects/future/obj_server_node.png"
const TEX_OFF: String = "res://assets/objects/future/obj_server_node_off.png"

@export var node_id: String = "node_a"
@export var max_health: int = 90

var current_health: int = 90
var is_dead: bool = false
var _sprite: Sprite2D = null


func _ready() -> void:
	add_to_group("damageable")
	add_to_group(FutureFx.MECHANICAL_GROUP)
	add_to_group("future_server_nodes")
	collision_layer = 4
	collision_mask = 0
	current_health = max_health
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(44.0, 90.0)
	cs.shape = rect
	cs.position = Vector2(0.0, -45.0)
	add_child(cs)
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEX_ON) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0.0, -48.0)
	add_child(_sprite)
	if ChapterState.is_node_destroyed(self, node_id):
		_apply_destroyed(false)


func take_damage(amount: int, _attacker: Variant = null) -> void:
	if is_dead:
		return
	current_health -= maxi(1, amount)
	_sprite.modulate = Color(2.0, 1.4, 1.8)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	if current_health <= 0:
		var total: int = ChapterState.mark_node_destroyed(self, node_id)
		_apply_destroyed(true)
		destroyed.emit(node_id, total)


func emp_stun(_duration: float) -> void:
	pass


func _apply_destroyed(with_fx: bool) -> void:
	is_dead = true
	current_health = 0
	remove_from_group("damageable")
	collision_layer = 0
	if ResourceLoader.exists(TEX_OFF):
		_sprite.texture = load(TEX_OFF) as Texture2D
	_sprite.rotation = 0.12
	if with_fx:
		FutureFx.play_vfx(get_parent(), FutureFx.VFX_EMP, global_position + Vector2(0.0, -48.0), 0.8)
		FutureFx.sfx(self, "sfx_emp_detonate", global_position, -4.0)
