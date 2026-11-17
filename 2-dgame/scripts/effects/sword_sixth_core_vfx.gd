extends Node2D

## res://scripts/effects/sword_sixth_core_vfx.gd
## Kabuğu kırılmış kılıcın uyanan 6. çekirdek aurası (Epic 2D-158). Bölüm 5 sonunda
## (sixth_core_awakening yeteneği) oyuncunun etrafında dönen mavi-mor zaman girdabı ve
## kılıçtan sızan veri kıvılcımları. Önceki kılıç VFX'lerinin (mühür sızıntısı, intikam aurası)
## yerini alır. attach_to() idempotenttir.

const FRAMES_PATH: String = "res://assets/effects/future/vfx_sixth_core_aura.tres"
const SPARK: String = "res://assets/effects/future/neon_spark.png"
const NODE_NAME: String = "SwordSixthCoreVfx"
const OLD_VFX: Array[String] = ["SwordSealLeakVfx", "SwordVowAuraVfx"]


static func attach_to(player: Node2D, _hud: CanvasLayer = null) -> Node2D:
	if not is_instance_valid(player):
		return null
	var existing: Node2D = player.get_node_or_null(NODE_NAME) as Node2D
	if existing:
		return existing
	for old: String in OLD_VFX:
		var n: Node = player.get_node_or_null(old)
		if n:
			n.queue_free()
	var root: Node2D = (load("res://scripts/effects/sword_sixth_core_vfx.gd") as GDScript).new() as Node2D
	root.name = NODE_NAME
	player.add_child(root)
	return root


func _ready() -> void:
	z_index = -1
	position = Vector2(0.0, -24.0)
	if ResourceLoader.exists(FRAMES_PATH):
		var aura: AnimatedSprite2D = AnimatedSprite2D.new()
		aura.sprite_frames = load(FRAMES_PATH) as SpriteFrames
		aura.scale = Vector2(0.45, 0.45)
		aura.modulate = Color(0.7, 0.6, 1.3, 0.55)
		add_child(aura)
		aura.play(&"default")
	if ResourceLoader.exists(SPARK):
		var sparks: CPUParticles2D = CPUParticles2D.new()
		sparks.texture = load(SPARK) as Texture2D
		sparks.amount = 14
		sparks.lifetime = 0.9
		sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		sparks.emission_sphere_radius = 18.0
		sparks.gravity = Vector2(0.0, -30.0)
		sparks.scale_amount_min = 0.3
		sparks.scale_amount_max = 0.6
		sparks.color = Color(0.6, 0.5, 1.0, 0.8)
		add_child(sparks)
