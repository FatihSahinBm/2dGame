class_name ArtilleryBarrage
extends Node2D

## res://scripts/hazards/ww2/artillery_barrage.gd
## Zamanlanmış topçu barajı (Epic 2D-144). Her `interval` saniyede bir salvo: oyuncunun
## çevresine `shells_per_salvo` mermi düşer (hedef işaretli, ıslıklı). Sessiz Batarya
## yan görevi tamamlandıysa mermi sayısı ve hasar %50 azalır (Ww2ChapterState).
## Oyuncu yalnızca x aralığındayken ateş edilir; sığınaklar koruma sağlar.

signal salvo_fired(count: int)

const ShellScript = preload("res://scripts/hazards/ww2/artillery_shell.gd")
const ChapterState = preload("res://scripts/components/ww2_chapter_state.gd")

@export var active: bool = true
@export var interval: float = 6.0
@export var shells_per_salvo: int = 3
@export var shell_damage: int = 22
@export var spread: float = 260.0
@export var x_range: Vector2 = Vector2(-INF, INF)
@export var ground_y: float = 560.0
@export var first_delay: float = 2.5

var _timer: float = 0.0


func _ready() -> void:
	_timer = first_delay


func _process(delta: float) -> void:
	if not active:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval
		var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if player and player.global_position.x >= x_range.x and player.global_position.x <= x_range.y:
			fire_salvo(player.global_position.x)


## Merkez x etrafına salvo atar; oluşturulan mermileri döndürür
func fire_salvo(center_x: float, count: int = -1) -> Array[Node2D]:
	var factor: float = ChapterState.artillery_factor(self)
	var n: int = count if count > 0 else shells_per_salvo
	n = maxi(1, int(ceil(float(n) * factor)))
	var shells: Array[Node2D] = []
	var host: Node = get_parent() if get_parent() else self
	for i: int in n:
		var shell: Node2D = ShellScript.new() as Node2D
		shell.set("damage", int(round(float(shell_damage) * factor)))
		shell.set("telegraph_time", 1.0 + 0.25 * float(i))
		var offset: float = 0.0 if i == 0 else randf_range(-spread, spread)
		var x: float = clampf(center_x + offset, x_range.x, x_range.y) if x_range.x > -INF else center_x + offset
		host.add_child(shell)
		shell.global_position = Vector2(x, ground_y)
		shells.append(shell)
	salvo_fired.emit(n)
	return shells
