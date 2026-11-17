extends RefCounted

## res://scripts/enemies/ww2/ww2_spawner.gd
## Bölüm 4 düşman çağırma yardımcısı (Epic 2D-144): Okült Deney Kalıntılarını "rise"
## animasyonuyla yerden kaldırır (kalkış süresince yapay zekâ kapalı) ve standart düşman
## sahnelerini örnekler. Komutan Form 3, projektör alarmı ve laboratuvar dalgası kullanır.

const SCENES: Dictionary = {
	"trench_infantry": "res://scenes/enemies/ww2/trench_infantry.tscn",
	"flamethrower": "res://scenes/enemies/ww2/flamethrower.tscn",
	"gas_sapper": "res://scenes/enemies/ww2/gas_sapper.tscn",
	"occult_remnant": "res://scenes/enemies/ww2/occult_remnant.tscn",
	"signal_scout": "res://scenes/enemies/ww2/signal_scout.tscn",
}
const RISE_TIME: float = 0.7


static func spawn(parent: Node, kind: String, at: Vector2, facing: int = -1) -> Node2D:
	var path: String = str(SCENES.get(kind, ""))
	if not is_instance_valid(parent) or path.is_empty() or not ResourceLoader.exists(path):
		return null
	var enemy: Node2D = (load(path) as PackedScene).instantiate() as Node2D
	if "direction" in enemy:
		enemy.direction = facing
	parent.add_child(enemy)
	enemy.global_position = at
	if kind == "occult_remnant":
		_play_rise(enemy)
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


static func _play_rise(enemy: Node2D) -> void:
	enemy.set_physics_process(false)
	var sprite: AnimatedSprite2D = enemy.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"rise"):
		sprite.play(&"rise")
	if not enemy.is_inside_tree():
		enemy.set_physics_process(true)
		return
	# Zamanlayıcı düşmanın çocuğudur: düşman erken yok edilirse geri çağrı da iptal olur
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = RISE_TIME
	timer.autostart = true
	timer.timeout.connect(enemy.set_physics_process.bind(true))
	if sprite:
		timer.timeout.connect(sprite.play.bind(&"idle"))
	timer.timeout.connect(timer.queue_free)
	enemy.add_child(timer)
