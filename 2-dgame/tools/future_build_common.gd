extends RefCounted

## res://tools/future_build_common.gd
## Bölüm 5 sahne kurucularının ortak yardımcıları (Epic 2D-158): düğüm sahipliği, şekiller,
## manifestten sprite hizalama, nine-patch platform blokları ve sahne kaydetme.
## Kullanan araçlar: tools/build_future_actors.gd, tools/build_future_levels.gd

const CHAR_DIR: String = "res://assets/characters/future/%s/%s_%s"


## Kökün altındaki (örneklenmiş sahnelerin içi hariç) tüm düğümlerin sahibini ayarlar
static func own(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		if child.scene_file_path.is_empty():
			own(child, owner)


static func save(root: Node, path: String) -> bool:
	own(root, root)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(root)
	if err != OK:
		push_error("pack başarısız: %s (%d)" % [path, err])
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	err = ResourceSaver.save(packed, path)
	root.free()
	if err != OK:
		push_error("kaydedilemedi: %s (%d)" % [path, err])
		return false
	print("OK  ", path)
	return true


static func rect(size: Vector2) -> RectangleShape2D:
	var r: RectangleShape2D = RectangleShape2D.new()
	r.size = size
	return r


static func circle(radius: float) -> CircleShape2D:
	var c: CircleShape2D = CircleShape2D.new()
	c.radius = radius
	return c


static func shape(parent: Node, shp: Shape2D, pos: Vector2 = Vector2.ZERO, node_name: String = "CollisionShape2D") -> CollisionShape2D:
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = node_name
	cs.shape = shp
	cs.position = pos
	parent.add_child(cs)
	return cs


static func manifest(entity: String) -> Dictionary:
	var path: String = CHAR_DIR % [entity, entity, "manifest.json"]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


static func frames(entity: String) -> SpriteFrames:
	return load(CHAR_DIR % [entity, entity, "frames.tres"]) as SpriteFrames


## AnimatedSprite2D (centered): ayak çıpası (ya da uçanlarda gövde merkezi) orijine gelir
static func animated_sprite(parent: Node, entity: String, scale: float, anim: StringName = &"idle") -> AnimatedSprite2D:
	var m: Dictionary = manifest(entity)
	var size: Array = m.get("frame_size", [64, 64])
	var feet_y: float = float(m.get("feet_y", int(size[1])))
	var spr: AnimatedSprite2D = AnimatedSprite2D.new()
	spr.name = "AnimatedSprite2D"
	spr.sprite_frames = frames(entity)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(scale, scale)
	spr.position = Vector2(0.0, (float(size[1]) * 0.5 - feet_y) * scale)
	if spr.sprite_frames and spr.sprite_frames.has_animation(anim):
		spr.animation = anim
		spr.autoplay = String(anim)
	parent.add_child(spr)
	return spr


static func instance(parent: Node, path: String, node_name: String, pos: Vector2 = Vector2.ZERO) -> Node:
	var node: Node = (load(path) as PackedScene).instantiate()
	node.name = node_name
	parent.add_child(node)
	if node is Node2D:
		(node as Node2D).position = pos
	return node


static func sprite(parent: Node, tex_path: String, pos: Vector2, scale: Vector2 = Vector2.ONE, node_name: String = "Sprite", z: int = 0) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.name = node_name
	s.texture = load(tex_path) as Texture2D
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos
	s.scale = scale
	s.z_index = z
	parent.add_child(s)
	return s


## Zemin / platform: StaticBody2D + nine-patch görsel (üst kenar = çarpışma üstü)
static func block(parent: Node, node_name: String, top_left: Vector2, size: Vector2, tex_path: String) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = node_name
	body.position = top_left + size * 0.5
	parent.add_child(body)
	shape(body, rect(size))
	var np: NinePatchRect = NinePatchRect.new()
	np.name = "Visual"
	np.texture = load(tex_path) as Texture2D
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	np.patch_margin_left = 8
	np.patch_margin_top = 8
	np.patch_margin_right = 8
	np.patch_margin_bottom = 8
	np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	np.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	np.position = -size * 0.5
	np.size = size
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(np)
	return body


static func area(parent: Node, node_name: String, pos: Vector2, size: Vector2) -> Area2D:
	var a: Area2D = Area2D.new()
	a.name = node_name
	a.position = pos
	a.collision_layer = 0
	a.collision_mask = 1
	parent.add_child(a)
	shape(a, rect(size))
	return a
