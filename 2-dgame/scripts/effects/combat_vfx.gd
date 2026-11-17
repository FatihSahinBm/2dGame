extends RefCounted

## res://scripts/effects/combat_vfx.gd
## Savaş geri bildirimi efekt kütüphanesi (Story 2D-150).
##
## Tekrar kullanılabilir şablonlar: "spark" (hafif vuruş kıvılcımı), "heavy_spark" (ağır vuruş),
## "dust" (toz), "blood" (kan). Her efekt çarpışma konumunda oluşur ve süresi bitince kendini siler.
## - Hafif/ağır ayrımı: ağır vuruşlar daha çok ve daha hızlı parçacık, daha büyük hasar sayısı
##   ve kamera sarsıntısı üretir; hafif vuruşlar küçük kıvılcımla sınırlıdır.
## - Yoğunluk: "Hareketi Azalt" açıksa parçacık sayısı yarıya iner ve sarsıntı uygulanmaz
##   (sarsıntı ayrıca CameraManager'ın yoğunluk ayarına tabidir).
## - Ekran kalabalığı: aynı anda en fazla MAX_ACTIVE_EFFECTS efekt yaşar; sınır aşılırsa yeni
##   parçacık efekti oluşturulmaz. Efektler z_index = EFFECT_Z ile saldırı uyarılarının altında çizilir.

const GROUP: StringName = &"combat_vfx"
const MAX_ACTIVE_EFFECTS: int = 24
const EFFECT_Z: int = 5

const TEMPLATES: Dictionary = {
	"spark": {"amount": 8, "lifetime": 0.22, "speed": [70.0, 150.0], "gravity": 260.0, "scale": [1.5, 2.5], "color": Color(1.0, 0.9, 0.55), "spread": 55.0},
	"heavy_spark": {"amount": 20, "lifetime": 0.36, "speed": [130.0, 290.0], "gravity": 320.0, "scale": [2.0, 4.0], "color": Color(1.0, 0.72, 0.3), "spread": 80.0},
	"dust": {"amount": 14, "lifetime": 0.45, "speed": [40.0, 120.0], "gravity": 180.0, "scale": [2.0, 4.0], "color": Color(0.78, 0.72, 0.62, 0.85), "spread": 85.0},
	"blood": {"amount": 12, "lifetime": 0.4, "speed": [60.0, 170.0], "gravity": 520.0, "scale": [1.5, 3.0], "color": Color(0.75, 0.06, 0.1), "spread": 65.0},
}

## Oyuncu saldırı türü -> şablon ve sarsıntı
const ATTACK_PROFILES: Dictionary = {
	"light": {"template": "spark", "shake": 0.0, "heavy": false},
	"combo": {"template": "spark", "shake": 1.5, "heavy": false},
	"crouch": {"template": "spark", "shake": 0.0, "heavy": false},
	"heavy": {"template": "heavy_spark", "shake": 5.0, "heavy": true},
	"plunge": {"template": "heavy_spark", "shake": 0.0, "heavy": true},
}


static func is_heavy_attack(attack_type: String) -> bool:
	return bool((ATTACK_PROFILES.get(attack_type, {}) as Dictionary).get("heavy", false))


static func get_active_count(host: Node) -> int:
	return host.get_tree().get_nodes_in_group(GROUP).size() if is_instance_valid(host) and host.is_inside_tree() else 0


## Şablon efektini verilen dünya konumunda oluşturur. Sınır aşıldıysa veya şablon yoksa null döner.
static func spawn(host: Node, world_position: Vector2, template_name: String, direction: Vector2 = Vector2.UP) -> CPUParticles2D:
	if not is_instance_valid(host) or not host.is_inside_tree() or not TEMPLATES.has(template_name):
		return null
	if get_active_count(host) >= MAX_ACTIVE_EFFECTS:
		return null
	var config: Dictionary = TEMPLATES[template_name] as Dictionary
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.amount = maxi(1, int(round(float(config["amount"]) * get_density_scale(host))))
	particles.lifetime = float(config["lifetime"])
	particles.direction = direction.normalized() if direction.length() > 0.01 else Vector2.UP
	particles.spread = float(config["spread"])
	particles.initial_velocity_min = float((config["speed"] as Array)[0])
	particles.initial_velocity_max = float((config["speed"] as Array)[1])
	particles.gravity = Vector2(0.0, float(config["gravity"]))
	particles.scale_amount_min = float((config["scale"] as Array)[0])
	particles.scale_amount_max = float((config["scale"] as Array)[1])
	particles.color = config["color"] as Color
	particles.z_index = EFFECT_Z
	particles.add_to_group(GROUP)
	particles.set_meta("template", template_name)
	host.add_child(particles)
	particles.global_position = world_position
	particles.emitting = true
	# Süre sonunda temizlik (finished sinyali gelmese de zamanlayıcı garanti eder)
	host.get_tree().create_timer(particles.lifetime + 0.15).timeout.connect(particles.queue_free)
	return particles


## Oyuncunun bir hedefe vuruşu için efekt: saldırı türüne göre kıvılcım ve sarsıntı
static func spawn_hit(attacker: Node2D, target: Variant, attack_type: String) -> CPUParticles2D:
	if not is_instance_valid(attacker) or not attacker.is_inside_tree() or not (target is Node2D) or not is_instance_valid(target):
		return null
	var profile: Dictionary = ATTACK_PROFILES.get(attack_type, ATTACK_PROFILES["light"]) as Dictionary
	var target_node: Node2D = target as Node2D
	var hit_position: Vector2 = target_node.global_position + Vector2(0.0, -24.0)
	var away: Vector2 = Vector2(signf(target_node.global_position.x - attacker.global_position.x), -0.6)
	var host: Node = attacker.get_parent() if attacker.get_parent() else attacker
	var effect: CPUParticles2D = spawn(host, hit_position, str(profile["template"]), away)
	var shake: float = float(profile["shake"])
	if shake > 0.0 and get_density_scale(attacker) >= 1.0:
		var camera: Node = attacker.get_node_or_null("Camera2D")
		if camera and camera.has_method("apply_shake"):
			camera.apply_shake(shake)
	return effect


## Okunabilir hasar sayısı: yukarı süzülür ve kaybolur. Ağır vuruşta daha büyük ve sarı.
static func spawn_damage_number(host: Node, world_position: Vector2, amount: int, heavy: bool = false) -> Label:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return null
	var label: Label = Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override("font_size", 18 if heavy else 13)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25) if heavy else Color(1.0, 0.3, 0.3))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = EFFECT_Z + 1
	host.add_child(label)
	label.global_position = world_position + Vector2(-10.0, -56.0)
	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 30.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)
	return label


## Erişilebilirlik: "Hareketi Azalt" açıkken efekt yoğunluğu yarıya iner
static func get_density_scale(host: Node) -> float:
	var cinematic: Node = host.get_node_or_null("/root/CinematicManager") if is_instance_valid(host) and host.is_inside_tree() else null
	return 0.5 if cinematic and "reduce_motion" in cinematic and cinematic.reduce_motion else 1.0
