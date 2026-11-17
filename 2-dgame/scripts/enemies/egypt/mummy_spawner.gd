extends RefCounted

## res://scripts/enemies/egypt/mummy_spawner.gd
## Dirilen Mumya yardımcıları (Epic 2D-143): kumdan "rise" animasyonuyla kalkış ve dalga çağırma.
## Kalkış süresince yapay zekâ ve hasar kutusu kapalıdır; animasyon bitince devriyeye başlar.
## Kullanım: MummySpawner.spawn(parent, Vector2(...)) / MummySpawner.spawn_wave(parent, points)

const MUMMY_SCENE_PATH: String = "res://scenes/enemies/egypt/risen_mummy.tscn"
const RISE_TIME: float = 0.75


static func spawn(parent: Node, at: Vector2, facing: int = -1) -> Node2D:
	if not is_instance_valid(parent) or not ResourceLoader.exists(MUMMY_SCENE_PATH):
		return null
	var mummy: Node2D = (load(MUMMY_SCENE_PATH) as PackedScene).instantiate() as Node2D
	if "direction" in mummy:
		mummy.direction = facing
	parent.add_child(mummy)
	mummy.global_position = at
	_play_rise(mummy)
	return mummy


static func spawn_wave(parent: Node, points: Array[Vector2], facing: int = -1) -> Array[Node2D]:
	var spawned: Array[Node2D] = []
	for p: Vector2 in points:
		var m: Node2D = spawn(parent, p, facing)
		if m:
			spawned.append(m)
	if not spawned.is_empty() and parent.is_inside_tree():
		var am: Node = parent.get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sound_2d"):
			am.play_sound_2d("mummy_rise", points[0], null, -2.0, 1200.0)
	return spawned


static func count_alive(nodes: Array) -> int:
	var alive: int = 0
	for n: Variant in nodes:
		if is_instance_valid(n) and not ("is_dead" in n and n.is_dead):
			alive += 1
	return alive


static func _play_rise(mummy: Node2D) -> void:
	mummy.set_physics_process(false)
	var sprite: AnimatedSprite2D = mummy.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"rise"):
		sprite.play(&"rise")
	if not mummy.is_inside_tree():
		mummy.set_physics_process(true)
		return
	# Zamanlayıcı mumyanın çocuğudur: mumya erken yok edilirse geri çağrı da iptal olur
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = RISE_TIME
	timer.autostart = true
	timer.timeout.connect(mummy.set_physics_process.bind(true))
	if sprite:
		timer.timeout.connect(sprite.play.bind(&"idle"))
	timer.timeout.connect(timer.queue_free)
	mummy.add_child(timer)
