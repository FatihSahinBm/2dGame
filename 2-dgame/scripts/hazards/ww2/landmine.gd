class_name Landmine
extends Area2D

## res://scripts/hazards/ww2/landmine.gd
## Gömülü mayın (Epic 2D-144): oyuncu basınca "tık" sesi, kısa gecikme, sonra patlama.
## Kan Sisi Atılması üzerinden geçerken tetiklenmez. El bombası/patlama da zincirleme patlatır.

signal detonated(at: Vector2)

const Explosion = preload("res://scripts/hazards/ww2/ww2_explosion.gd")
const TEX_IDLE: Texture2D = preload("res://assets/objects/ww2/landmine_0.png")
const TEX_ARMED: Texture2D = preload("res://assets/objects/ww2/landmine_1.png")

@export var damage: int = 30
@export var radius: float = 70.0
@export var fuse_time: float = 0.35

var is_triggered: bool = false
var is_detonated: bool = false
var _sprite: Sprite2D = null


func _ready() -> void:
	add_to_group("ww2_hazards")
	add_to_group("damageable")
	collision_layer = 0
	collision_mask = 1
	_sprite = Sprite2D.new()
	_sprite.texture = TEX_IDLE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0.0, -6.0)
	add_child(_sprite)
	if get_child_count() == 1:
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(28.0, 14.0)
		shape.shape = rect
		shape.position = Vector2(0.0, -7.0)
		add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not ("is_blood_mist_dashing" in body and bool(body.is_blood_mist_dashing)):
		trigger()


func trigger() -> void:
	if is_triggered:
		return
	is_triggered = true
	if _sprite:
		_sprite.texture = TEX_ARMED
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d("mine_click", global_position, null, 0.0, 900.0)
	get_tree().create_timer(fuse_time).timeout.connect(detonate)


## Patlamalar (el bombası) mayını zincirleme patlatır
func take_damage(_amount: int, _source: Variant = null) -> void:
	trigger()


func detonate() -> void:
	if is_detonated or not is_inside_tree():
		return
	is_detonated = true
	remove_from_group("damageable")
	Explosion.explode(get_parent(), global_position, radius, damage, true, true, self, "grenade_blast")
	detonated.emit(global_position)
	queue_free()
