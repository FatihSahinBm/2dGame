extends RefCounted

## res://scripts/hazards/ww2/ww2_explosion.gd
## Bölüm 4 ortak patlama yardımcısı (Epic 2D-144): topçu mermisi, mayın ve el bombası
## aynı kuralı kullanır. Oyuncu bir sığınağın içindeyse veya Kan Sisi Atılması yapıyorsa
## korunur. Patlama görseli (6 kare), ses ve kamera sarsıntısı burada üretilir.

const EXPLOSION_FRAMES: int = 6
const FX_DIR: String = "res://assets/effects/ww2/explosion_%d.png"


## Oyuncunun patlamadan korunup korunmadığı (sığınak / kan sisi)
static func is_player_protected(player: Node) -> bool:
	if not is_instance_valid(player):
		return true
	if "is_blood_mist_dashing" in player and bool(player.is_blood_mist_dashing):
		return true
	if not player.is_inside_tree():
		return false
	for shelter: Node in player.get_tree().get_nodes_in_group("ww2_shelters"):
		if shelter.has_method("shelters") and bool(shelter.shelters(player)):
			return true
	return false


## Patlatır; hasar verilen düğüm sayısını döndürür.
## hit_player: oyuncu da etkilenir. source: hasar kaynağı (current_attack_type taşıyabilir).
static func explode(host: Node, pos: Vector2, radius: float, damage: int, hit_player: bool = true,
		hit_enemies: bool = true, source: Node = null, sfx_key: String = "artillery_blast") -> int:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return 0
	var hits: int = 0
	var tree: SceneTree = host.get_tree()
	if hit_player:
		var player: Node2D = tree.get_first_node_in_group("player") as Node2D
		if player and player.global_position.distance_to(pos) <= radius and not is_player_protected(player):
			if player.has_method("take_damage"):
				player.take_damage(damage, pos)
				hits += 1
	if hit_enemies:
		for node: Node in tree.get_nodes_in_group("damageable"):
			if not (node is Node2D) or node.is_in_group("player") or node.is_in_group("allies"):
				continue
			if "is_dead" in node and bool(node.is_dead):
				continue
			if (node as Node2D).global_position.distance_to(pos) > radius:
				continue
			_damage(node, damage, source)
			hits += 1
	spawn_fx(host, pos)
	var am: Node = host.get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d(sfx_key, pos, null, -2.0, 1400.0)
	var cam: Node = host.get_node_or_null("/root/CameraManager")
	if cam and cam.has_method("apply_shake"):
		cam.apply_shake(6.0, 1, 0.3, 25.0, "ww2_explosion")
	return hits


static func _damage(node: Node, damage: int, source: Node) -> void:
	for m: Dictionary in node.get_method_list():
		if m.get("name") == "take_damage":
			if (m.get("args", []) as Array).size() >= 2:
				node.take_damage(damage, source)
			else:
				node.take_damage(damage)
			return


static func spawn_fx(host: Node, pos: Vector2) -> void:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	var frames: SpriteFrames = SpriteFrames.new()
	frames.set_animation_loop(&"default", false)
	frames.set_animation_speed(&"default", 14.0)
	for i: int in EXPLOSION_FRAMES:
		var path: String = FX_DIR % i
		if ResourceLoader.exists(path):
			frames.add_frame(&"default", load(path) as Texture2D)
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 40
	sprite.offset = Vector2(0.0, -36.0)
	host.add_child(sprite)
	sprite.global_position = pos
	sprite.animation_finished.connect(sprite.queue_free)
	sprite.play(&"default")
