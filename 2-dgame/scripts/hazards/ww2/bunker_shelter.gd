class_name BunkerShelter
extends Area2D

## res://scripts/hazards/ww2/bunker_shelter.gd
## Beton sığınak / siper alma alanı (Epic 2D-144). İçindeki oyuncu topçu patlamalarından
## etkilenmez (Ww2Explosion.is_player_protected). İçerideyken sığınak hafifçe aydınlanır.

signal player_sheltered(inside: bool)

var _inside: Array[Node] = []


func _ready() -> void:
	add_to_group("ww2_shelters")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func shelters(body: Node) -> bool:
	return _inside.has(body)


## Testler ve yükleme anı için doğrudan kayıt
func force_enter(body: Node) -> void:
	if not _inside.has(body):
		_inside.append(body)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _inside.has(body):
		_inside.append(body)
		modulate = Color(1.15, 1.1, 0.95)
		player_sheltered.emit(true)


func _on_body_exited(body: Node2D) -> void:
	if _inside.has(body):
		_inside.erase(body)
		modulate = Color.WHITE
		player_sheltered.emit(false)
