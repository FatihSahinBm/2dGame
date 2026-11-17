extends RefCounted

## res://scripts/enemies/future/future_spawner.gd
## Bölüm 5 düşman çağırma yardımcısı (Epic 2D-158): AI Lord dron çağrısı, kule dron dalgaları
## ve Veri Kalesi takviyeleri. Çağrılan düşman ışınlanma VFX'iyle belirir.

const FutureFx = preload("res://scripts/effects/future_fx.gd")
const SCENES: Dictionary = {
	"cyber_enforcer": "res://scenes/enemies/future/cyber_enforcer.tscn",
	"chrono_drone": "res://scenes/enemies/future/chrono_drone.tscn",
	"hydraulic_juggernaut": "res://scenes/enemies/future/hydraulic_juggernaut.tscn",
	"cyber_hound": "res://scenes/enemies/future/cyber_hound.tscn",
	"cyber_flying_bug_prime": "res://scenes/enemies/future/cyber_flying_bug_prime.tscn",
}


static func spawn(parent: Node, kind: String, at: Vector2, facing: int = -1) -> Node2D:
	var path: String = str(SCENES.get(kind, ""))
	if not is_instance_valid(parent) or path.is_empty() or not ResourceLoader.exists(path):
		return null
	var enemy: Node2D = (load(path) as PackedScene).instantiate() as Node2D
	if "direction" in enemy:
		enemy.direction = facing
	parent.add_child(enemy)
	enemy.global_position = at
	FutureFx.play_vfx(parent, FutureFx.VFX_TELEPORT, at + Vector2(0.0, -24.0), 0.5)
	return enemy


static func spawn_wave(parent: Node, kind: String, points: Array[Vector2], facing: int = -1) -> Array[Node2D]:
	var spawned: Array[Node2D] = []
	for p: Vector2 in points:
		var e: Node2D = spawn(parent, kind, p, facing)
		if e:
			spawned.append(e)
	return spawned


static func count_alive(nodes: Array) -> int:
	var alive: int = 0
	for n: Variant in nodes:
		if is_instance_valid(n) and not ("is_dead" in n and n.is_dead):
			alive += 1
	return alive


## Bir işaretçi düğümünün (Marker2D) çocuklarından ilk `count` konumu
static func points_from(markers: Node, count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if markers == null:
		return points
	for m: Node in markers.get_children():
		if m is Node2D and points.size() < count:
			points.append((m as Node2D).global_position)
	return points
