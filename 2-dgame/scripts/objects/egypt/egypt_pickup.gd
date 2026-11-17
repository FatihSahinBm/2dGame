class_name EgyptPickup
extends Area2D

## res://scripts/objects/egypt/egypt_pickup.gd
## Bölüm 3 toplanabilir eşyaları (Epic 2D-143): Güneş Mührü anahtarı ve iyileştirme iksiri.
## Oyuncu temas edince toplanır; durum kalıcıdır (yeniden yüklemede tekrar çıkmaz).

signal collected(kind: String, item_id: String)

const WorldObjectState = preload("res://scripts/components/world_object_state.gd")
const KIND_SEAL_KEY: String = "seal_key"
const KIND_POTION: String = "potion"
const SEAL_EVENT_PREFIX: String = "egypt_seal_key|"

@export_enum("seal_key", "potion") var kind: String = "potion"
@export var item_id: String = ""
@export var heal_amount: int = 35

var is_collected: bool = false
var _bob_t: float = 0.0
@onready var _sprite: Sprite2D = get_node_or_null("Sprite") as Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	if WorldObjectState.is_set(self, "collected"):
		is_collected = true
		queue_free()


func _process(delta: float) -> void:
	_bob_t += delta * 3.0
	if _sprite:
		_sprite.position.y = sin(_bob_t) * 3.0


static func has_seal_key(node: Node, key_id: String) -> bool:
	var gs: Node = node.get_node_or_null("/root/GameState") if node.is_inside_tree() else null
	return gs != null and gs.has_method("is_event_completed") and bool(gs.is_event_completed(SEAL_EVENT_PREFIX + key_id))


func collect(body: Node2D) -> void:
	if is_collected:
		return
	is_collected = true
	var gs: Node = get_node_or_null("/root/GameState")
	if kind == KIND_SEAL_KEY:
		if gs and gs.has_method("set_event_completed"):
			gs.set_event_completed(SEAL_EVENT_PREFIX + item_id, true)
		_play("seal_unlock")
	elif is_instance_valid(body) and body.has_method("heal"):
		body.heal(heal_amount)
		_play("checkpoint_activated")
	var stats: Node = get_node_or_null("/root/PlayStats")
	if stats and stats.has_method("record_item_collected"):
		stats.record_item_collected("egypt_%s_%s" % [kind, item_id])
	WorldObjectState.mark(self, "collected")
	collected.emit(kind, item_id)
	set_deferred("monitoring", false)
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.2)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collect(body)


func _play(key: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(key, -3.0)
