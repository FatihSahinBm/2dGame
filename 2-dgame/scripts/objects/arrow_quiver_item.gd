class_name ArrowQuiverItem
extends Area2D

## res://scripts/objects/arrow_quiver_item.gd
## 1. Sahne Kırık Erzak Yolu'ndaki Alevli Ok Sadakları (Yan Görev Nesnesi).
## Oyuncu bunu toplayıp ordugahtaki Kemankeş okçusuna teslim edebilir.

signal collected()

var _is_collected: bool = false

@onready var visual: CanvasItem = get_node_or_null("Visual") as CanvasItem
@onready var prompt: Label = get_node_or_null("PromptLabel") as Label


func _ready() -> void:
	add_to_group("collectibles")
	body_entered.connect(_on_body_entered)
	if prompt:
		prompt.visible = false


func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return
	if body.is_in_group("player"):
		_is_collected = true
		collected.emit()
		_spawn_pickup_feedback()
		queue_free()


func _spawn_pickup_feedback() -> void:
	var label: Label = Label.new()
	label.text = "🏹 Alevli Ok Sadakları Alındı!"
	label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 13)
	label.global_position = global_position + Vector2(-60.0, -35.0)

	var parent_scene: Node = get_parent()
	if parent_scene:
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 25.0, 0.7)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
		tw.tween_callback(label.queue_free)
