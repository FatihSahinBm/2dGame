class_name Ww2Pickup
extends Area2D

## res://scripts/objects/ww2/ww2_pickup.gd
## Bölüm 4 toplanabilir eşyası (Epic 2D-144): temas edince Ww2Inventory'ye `amount` adet
## `item_id` eklenir. Toplanma kalıcıdır (WorldObjectState) — yeniden yüklemede tekrar çıkmaz.
## İkon, eşya tanımındaki icon_path'ten otomatik yüklenir.

signal collected(item_id: String, amount: int)

const WorldObjectState = preload("res://scripts/components/world_object_state.gd")
const Inventory = preload("res://scripts/components/ww2_inventory.gd")

@export var item_id: String = "field_bandage"
@export var amount: int = 1

var is_collected: bool = false
var _sprite: Sprite2D = null
var _bob_t: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	if get_node_or_null("CollisionShape2D") == null:
		var shape: CollisionShape2D = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = 18.0
		shape.shape = circle
		shape.position = Vector2(0.0, -16.0)
		add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var icon_path: String = str(Inventory.get_definition(item_id).get("icon_path", ""))
	if ResourceLoader.exists(icon_path):
		_sprite.texture = load(icon_path) as Texture2D
	_sprite.position = Vector2(0.0, -16.0)
	add_child(_sprite)
	body_entered.connect(_on_body_entered)
	if WorldObjectState.is_set(self, "collected"):
		is_collected = true
		queue_free()


func _process(delta: float) -> void:
	_bob_t += delta * 3.0
	if _sprite:
		_sprite.position.y = -16.0 + sin(_bob_t) * 3.0


func collect() -> void:
	if is_collected:
		return
	is_collected = true
	Inventory.add(self, item_id, amount)
	WorldObjectState.mark(self, "collected")
	var stats: Node = get_node_or_null("/root/PlayStats")
	if stats and stats.has_method("record_item_collected"):
		stats.record_item_collected("ww2_" + item_id)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("item_pickup" if am.has_method("has_sound") and am.has_sound("item_pickup") else "item_equip", -3.0)
	collected.emit(item_id, amount)
	set_deferred("monitoring", false)
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collect()
