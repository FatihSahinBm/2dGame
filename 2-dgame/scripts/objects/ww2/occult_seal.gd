class_name OccultSeal
extends EgyptInteractable

## res://scripts/objects/ww2/occult_seal.gd
## Okült mühür (Epic 2D-144): Bölüm 1'de açılan Kalp Rezonansı (heart_resonance) yeteneği
## varsa [E] ile açılır ve bağlı bariyeri kaldırır (gizli geçit / bonus ödül).
## Yetenek yoksa kilitli kalır ve ipucu verir. Açık durum kalıcıdır.

signal seal_result(opened: bool)

const ABILITY_ID: String = "heart_resonance"

@export var barrier_path: NodePath

var is_open: bool = false


func _interactable_ready() -> void:
	prompt_key = "PROMPT_WW2_SEAL"
	if is_persisted("opened"):
		_apply_open()


func _on_interact() -> void:
	if is_open:
		return
	var gs: Node = get_node_or_null("/root/GameState")
	var can: bool = gs != null and gs.has_method("has_ability") and bool(gs.has_ability(ABILITY_ID))
	if can:
		persist("opened")
		_apply_open()
		var am: Node = get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sound_2d"):
			am.play_sound_2d("seal_unlock", global_position, null, -2.0, 900.0)
	seal_result.emit(can)
	interaction_requested.emit(self)


func _apply_open() -> void:
	is_open = true
	set_interaction_enabled(false)
	modulate = Color(0.6, 0.6, 0.7, 0.6)
	var barrier: Node = get_node_or_null(barrier_path)
	if barrier:
		for child: Node in barrier.get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred("disabled", true)
		if barrier is CanvasItem:
			create_tween().tween_property(barrier, "modulate:a", 0.0, 0.6)
