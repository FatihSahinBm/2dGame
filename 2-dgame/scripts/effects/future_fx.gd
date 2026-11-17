extends RefCounted

## res://scripts/effects/future_fx.gd
## Bölüm 5 ortak efekt ve hasar yardımcıları (Epic 2D-158): SpriteFrames VFX paketlerini
## (assets/effects/future/*.tres) tek seferlik oynatır, imza farkı olan take_damage
## çağrılarını tek noktadan yapar, kamera sarsıntısı ve konumlu ses uygular.

const Explosion = preload("res://scripts/hazards/ww2/ww2_explosion.gd")
const VFX_EMP: String = "res://assets/effects/future/vfx_emp_blast.tres"
const VFX_TELEPORT: String = "res://assets/effects/future/ai_lord_teleport_vfx.tres"
const VFX_TIME_FRACTURE: String = "res://assets/effects/future/vfx_time_fracture.tres"
const VFX_SHELL_SHATTER: String = "res://assets/effects/future/vfx_sword_shell_shatter.tres"
const VFX_SIXTH_CORE: String = "res://assets/effects/future/vfx_sixth_core_aura.tres"
const MECHANICAL_GROUP: StringName = &"mechanical"
const EMP_GROUP: StringName = &"emp_receivers"


## VFX paketini konumda oynatır; loop değilse bitince silinir. Oluşan sprite'ı döndürür.
static func play_vfx(host: Node, frames_path: String, pos: Vector2, scale: float = 1.0, z: int = 40) -> AnimatedSprite2D:
	if not is_instance_valid(host) or not host.is_inside_tree() or not ResourceLoader.exists(frames_path):
		return null
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = load(frames_path) as SpriteFrames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = z
	sprite.scale = Vector2(scale, scale)
	host.add_child(sprite)
	sprite.global_position = pos
	if not sprite.sprite_frames.get_animation_loop(&"default"):
		sprite.animation_finished.connect(sprite.queue_free)
	sprite.play(&"default")
	return sprite


## take_damage imzası (1 ya da 2 parametre) farklı olan hedefler için güvenli hasar
static func damage(node: Node, amount: int, source: Variant = null) -> void:
	if not is_instance_valid(node) or not node.has_method("take_damage"):
		return
	Explosion._damage(node, amount, source as Node if source is Node else null)


static func is_mechanical(node: Node) -> bool:
	return is_instance_valid(node) and node.is_in_group(MECHANICAL_GROUP)


## EMP darbesi: yarıçaptaki mekaniklere çift hasar + sersemletme; kalkan/taret/kapı gibi
## "emp_receivers" grubundaki nesnelere on_emp() çağrısı. Etkilenen düğüm sayısını döndürür.
static func emp_burst(host: Node, pos: Vector2, radius: float, base_damage: int, stun_time: float, source: Node = null) -> int:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return 0
	var hits: int = 0
	var tree: SceneTree = host.get_tree()
	for node: Node in tree.get_nodes_in_group("damageable"):
		if not (node is Node2D) or node.is_in_group("player") or node.is_in_group("allies"):
			continue
		if "is_dead" in node and bool(node.is_dead):
			continue
		if (node as Node2D).global_position.distance_to(pos) > radius:
			continue
		var mech: bool = is_mechanical(node)
		damage(node, base_damage * (2 if mech else 1), source)
		if mech and node.has_method("emp_stun"):
			node.emp_stun(stun_time)
		hits += 1
	for node: Node in tree.get_nodes_in_group(EMP_GROUP):
		if node is Node2D and (node as Node2D).global_position.distance_to(pos) <= radius and node.has_method("on_emp"):
			node.on_emp(stun_time)
			hits += 1
	play_vfx(host, VFX_EMP, pos, 1.2)
	sfx(host, "sfx_emp_detonate", pos)
	shake(host, 7.0, 0.35, "future_emp")
	return hits


static func sfx(host: Node, key: String, pos: Vector2 = Vector2.INF, volume_db: float = -2.0) -> void:
	var am: Node = host.get_node_or_null("/root/AudioManager") if is_instance_valid(host) and host.is_inside_tree() else null
	if am == null:
		return
	if pos != Vector2.INF and am.has_method("play_sound_2d"):
		am.play_sound_2d(key, pos, null, volume_db, 1400.0)
	elif am.has_method("play_sfx"):
		am.play_sfx(key, volume_db)


static func shake(host: Node, strength: float, duration: float, source_id: String) -> void:
	var cam: Node = host.get_node_or_null("/root/CameraManager") if is_instance_valid(host) and host.is_inside_tree() else null
	if cam and cam.has_method("apply_shake"):
		cam.apply_shake(strength, 1, duration, 25.0, source_id)


## Kısa ömürlü bir parlama (PointLight2D yerine hafif bir sprite halesi)
static func flash_sprite(host: Node, texture_path: String, pos: Vector2, color: Color, life: float = 0.4, scale: float = 2.0) -> void:
	if not is_instance_valid(host) or not ResourceLoader.exists(texture_path):
		return
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = load(texture_path) as Texture2D
	spr.modulate = color
	spr.scale = Vector2(scale, scale)
	spr.z_index = 45
	host.add_child(spr)
	spr.global_position = pos
	var tw: Tween = spr.create_tween()
	tw.tween_property(spr, "modulate:a", 0.0, life)
	tw.tween_callback(spr.queue_free)
