class_name CampfireCheckpoint
extends Area2D

## res://scripts/objects/campfire_checkpoint.gd
## Story 2D-131: Kontrol Noktaları ve Kamp Ateşi (Checkpoints & Campfire)
##
## Başarı Kriterleri:
## 1. Kontrol noktası etkinleştirme ([E] etkileşim veya temas), görsel ve ses geri bildirimi.
## 2. Oyuncu yeniden doğma noktasının kaydedilmesi (SaveManager.set_checkpoint).
## 3. Can ve iksir yenileme (dinlenme davranışıyla tam can/mana ve iksir tazeleme).
## 4. Sıradan devriye düşmanlarının yeniden başlaması (respawnable_enemies); boss/kapı/görev korunması.
## 5. Ölüm sonrası oyuncunun son aktif kontrol noktasında güvenli doğması.
## 6. Bölüm yeniden yüklenince kalıcı görev/boss ilerlemesinin korunması.
## 7. Kontrol noktasına art arda etkileşimlerin idempotent (güvenli/tekrarlanabilir) olması.

signal checkpoint_activated(checkpoint_id: String, spawn_pos: Vector2)
signal player_rested(checkpoint_id: String)
signal enemies_respawned(count: int)

enum ActivationMode {
	INTERACT_ONLY = 0, ## Sadece [E] tuşu ile etkileşim
	TOUCH_ONLY = 1,    ## Sadece alana temas edince otomatik
	BOTH = 2           ## Temas edince veya [E] ile dinlenme
}

@export var checkpoint_id: String = "campfire_default"
@export var is_lit: bool = false
@export var activation_mode: ActivationMode = ActivationMode.INTERACT_ONLY
@export var heal_amount: int = 100
@export var refill_potions: bool = true
@export var potion_heal_count: int = 3
@export var potion_mana_count: int = 2
@export var spawn_offset: Vector2 = Vector2(30.0, 0.0)
@export var respawn_enemies_on_rest: bool = true
@export var prompt_text_unlit: String = "[E] Kamp Ateşini Yak (Kontrol Noktası)"
@export var prompt_text_lit: String = "[E] Kamp Ateşinde Dinlen"

const PositionalEmitter = preload("res://scripts/audio/positional_audio_emitter_2d.gd")

# Düğüm Referansları (Varsa sahneden, yoksa prosedürel inşa edilir)
var visual_root: Node2D = null
var unlit_visual: CanvasItem = null
var fire_visual: CanvasItem = null
var particles: CPUParticles2D = null
var warm_light: PointLight2D = null
var prompt_label: Label = null
var col_shape: CollisionShape2D = null
var audio_emitter: Node2D = null

var _player_in_range: Node2D = null
var _respawnable_registry: Array[Dictionary] = []
var _is_resting_cooldown: bool = false
var _cooldown_timer: float = 0.0


func _ready() -> void:
	add_to_group("campfires")
	add_to_group("checkpoints")

	# 1. Çarpışma ve Alan Ayarları
	collision_layer = 4
	collision_mask = 1
	monitoring = true
	monitorable = true

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# 2. Düğümleri bul veya oluştur
	_setup_internal_nodes()

	# 3. GameState veya SaveManager üzerinden daha önce yakılmış mı kontrol et
	_check_initial_lit_state()

	# 4. Sahnedeki 'respawnable_enemies' grubundaki düşmanları kaydet
	_scan_and_register_scene_enemies()

	# 5. Görsel durumu güncelle
	_update_visuals(false)


func _setup_internal_nodes() -> void:
	# Collision Shape
	col_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not col_shape:
		col_shape = CollisionShape2D.new()
		col_shape.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = 48.0
		col_shape.shape = circle
		add_child(col_shape)

	# Visual Root
	visual_root = get_node_or_null("Visual") as Node2D
	if not visual_root:
		visual_root = Node2D.new()
		visual_root.name = "Visual"
		add_child(visual_root)

	# Unlit Visual (Odun kütükleri ve taş halkası)
	unlit_visual = visual_root.get_node_or_null("UnlitVisual") as CanvasItem
	if not unlit_visual:
		var unlit_node := Node2D.new()
		unlit_node.name = "UnlitVisual"
		if ResourceLoader.exists("res://assets/environment/campfire/campfire_hearth.png"):
			var hearth := Sprite2D.new()
			hearth.name = "HearthSprite"
			hearth.position = Vector2(0, 4)
			hearth.texture = load("res://assets/environment/campfire/campfire_hearth.png")
			unlit_node.add_child(hearth)
			if ResourceLoader.exists("res://assets/environment/campfire/campfire_coals.png"):
				var coals := Sprite2D.new()
				coals.name = "CoalsSprite"
				coals.position = Vector2(0, 4)
				coals.texture = load("res://assets/environment/campfire/campfire_coals.png")
				unlit_node.add_child(coals)
		else:
			# Basit odun ve taş görsel temsili
			var log_poly := Polygon2D.new()
			log_poly.polygon = PackedVector2Array([
				Vector2(-24, 6), Vector2(-12, -4), Vector2(16, 8), Vector2(24, 12),
				Vector2(12, 14), Vector2(-16, 12)
			])
			log_poly.color = Color(0.35, 0.22, 0.12, 1.0)
			unlit_node.add_child(log_poly)

			var log_poly2 := Polygon2D.new()
			log_poly2.polygon = PackedVector2Array([
				Vector2(20, 6), Vector2(10, -5), Vector2(-18, 7), Vector2(-22, 11),
				Vector2(-8, 14), Vector2(14, 12)
			])
			log_poly2.color = Color(0.28, 0.18, 0.1, 1.0)
			unlit_node.add_child(log_poly2)

		visual_root.add_child(unlit_node)
		unlit_visual = unlit_node

	# Fire Visual (Alev görseli)
	fire_visual = visual_root.get_node_or_null("FireVisual") as CanvasItem
	if not fire_visual:
		var fire_node := Node2D.new()
		fire_node.name = "FireVisual"
		if ResourceLoader.exists("res://assets/environment/campfire/campfire_flame_0.png"):
			if ResourceLoader.exists("res://assets/environment/campfire/campfire_light_glow.png"):
				var glow := Sprite2D.new()
				glow.name = "LightGlow"
				var mat := CanvasItemMaterial.new()
				mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				glow.material = mat
				glow.position = Vector2(0, -4)
				glow.scale = Vector2(1.2, 0.9)
				glow.texture = load("res://assets/environment/campfire/campfire_light_glow.png")
				glow.modulate = Color(1.0, 0.65, 0.25, 0.65)
				fire_node.add_child(glow)

			var sf := SpriteFrames.new()
			sf.add_animation("flame_burn")
			sf.set_animation_speed("flame_burn", 10.0)
			sf.set_animation_loop("flame_burn", true)
			for i in range(6):
				var frame_tex = load("res://assets/environment/campfire/campfire_flame_%d.png" % i)
				if frame_tex:
					sf.add_frame("flame_burn", frame_tex)
			var anim_sprite := AnimatedSprite2D.new()
			anim_sprite.name = "AnimatedFlame"
			anim_sprite.sprite_frames = sf
			anim_sprite.animation = "flame_burn"
			anim_sprite.position = Vector2(0, -10)
			anim_sprite.play("flame_burn")
			fire_node.add_child(anim_sprite)
		else:
			# İç içe alev poligonları
			var outer_flame := Polygon2D.new()
			outer_flame.name = "OuterFlame"
			outer_flame.polygon = PackedVector2Array([
				Vector2(-14, 8), Vector2(-8, -12), Vector2(0, -28), Vector2(8, -14),
				Vector2(14, 8), Vector2(0, 12)
			])
			outer_flame.color = Color(1.0, 0.45, 0.1, 0.9)
			fire_node.add_child(outer_flame)

			var inner_flame := Polygon2D.new()
			inner_flame.name = "InnerFlame"
			inner_flame.polygon = PackedVector2Array([
				Vector2(-7, 6), Vector2(-4, -6), Vector2(0, -18), Vector2(4, -8),
				Vector2(7, 6), Vector2(0, 8)
			])
			inner_flame.color = Color(1.0, 0.9, 0.3, 0.95)
			fire_node.add_child(inner_flame)

		visual_root.add_child(fire_node)
		fire_visual = fire_node

	# Embers Particles (Kıvılcım parçacıkları)
	particles = visual_root.get_node_or_null("EmbersParticles") as CPUParticles2D
	if not particles:
		particles = CPUParticles2D.new()
		particles.name = "EmbersParticles"
		particles.emitting = false
		particles.amount = 16
		particles.lifetime = 1.2
		particles.speed_scale = 1.0
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.emission_rect_extents = Vector2(14, 4)
		particles.direction = Vector2(0, -1)
		particles.spread = 25.0
		particles.gravity = Vector2(0, -30.0)
		particles.initial_velocity_min = 25.0
		particles.initial_velocity_max = 55.0
		particles.scale_amount_min = 1.5
		particles.scale_amount_max = 3.0
		particles.color = Color(1.0, 0.65, 0.2, 0.85)
		visual_root.add_child(particles)

	# Prompt Label
	prompt_label = visual_root.get_node_or_null("PromptLabel") as Label
	if not prompt_label:
		prompt_label = Label.new()
		prompt_label.name = "PromptLabel"
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prompt_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5, 1.0))
		prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
		prompt_label.add_theme_constant_override("outline_size", 4)
		prompt_label.add_theme_font_size_override("font_size", 11)
		prompt_label.position = Vector2(-120, -52)
		prompt_label.size = Vector2(240, 22)
		prompt_label.visible = false
		visual_root.add_child(prompt_label)


func _check_initial_lit_state() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and "cached_checkpoint_id" in save_mgr:
		if save_mgr.cached_checkpoint_id == checkpoint_id:
			is_lit = true

	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("is_event_completed"):
		if gs.is_event_completed("checkpoint_lit_" + checkpoint_id):
			is_lit = true


func _scan_and_register_scene_enemies() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if not tree:
		return
	var enemies = tree.get_nodes_in_group("respawnable_enemies")
	for enemy in enemies:
		if enemy is Node2D:
			register_respawnable_enemy(enemy)


## Düşmanı yeniden doğma kayıt listesine ekler
func register_respawnable_enemy(enemy: Node2D) -> void:
	# Zaten kayıtlı mı kontrol et
	for entry in _respawnable_registry:
		if entry.get("node") and entry["node"].get_ref() == enemy:
			return

	var entry: Dictionary = {
		"node": weakref(enemy),
		"name": enemy.name,
		"scene_file_path": enemy.scene_file_path,
		"parent": enemy.get_parent(),
		"parent_path": enemy.get_parent().get_path() if enemy.get_parent() else NodePath(""),
		"spawn_pos": enemy.global_position,
		"spawn_rot": enemy.rotation,
		"max_health": enemy.max_health if "max_health" in enemy else 100,
		"direction": enemy.direction if "direction" in enemy else 1
	}
	_respawnable_registry.append(entry)


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_is_resting_cooldown = false

	# Ateş alevi ve ışık için organik nefes alma / titreşim efekti
	if is_lit and fire_visual and fire_visual.visible:
		var t := Time.get_ticks_msec() * 0.001
		var flame_wobble_x := 1.0 + 0.04 * sin(t * 7.3) + 0.02 * sin(t * 13.7)
		var flame_wobble_y := 1.0 + 0.05 * sin(t * 5.1) + 0.02 * cos(t * 11.2)
		fire_visual.scale = Vector2(flame_wobble_x, flame_wobble_y)

		# Yer ışığı parlama / titreme efekti (LightGlow)
		var glow_sprite = fire_visual.get_node_or_null("LightGlow") as CanvasItem
		if glow_sprite:
			var glow_alpha := 0.65 + 0.12 * sin(t * 6.0) + 0.08 * sin(t * 11.0)
			glow_sprite.modulate.a = clampf(glow_alpha, 0.45, 0.85)

		# Közlerin akkorlaşma nabzı (CoalsSprite)
		if unlit_visual:
			var coals_sprite = unlit_visual.get_node_or_null("CoalsSprite") as CanvasItem
			if coals_sprite:
				var coals_pulse := 1.2 + 0.25 * sin(t * 3.5)
				coals_sprite.modulate = Color(coals_pulse, coals_pulse * 0.75, coals_pulse * 0.45, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or _is_resting_cooldown:
		return

	if activation_mode == ActivationMode.TOUCH_ONLY:
		return

	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		ignite_and_rest(_player_in_range)
		if get_viewport():
			get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return

	_player_in_range = body
	_update_prompt_text()

	if activation_mode == ActivationMode.TOUCH_ONLY:
		ignite_and_rest(body)
	elif activation_mode == ActivationMode.BOTH and not is_lit:
		ignite_and_rest(body)


func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		if prompt_label:
			prompt_label.visible = false


func _is_player(node: Node) -> bool:
	if not node:
		return false
	return node.is_in_group("player") or node.name.to_lower().contains("player")


func _update_prompt_text() -> void:
	if not prompt_label:
		return
	var is_en: bool = false
	var loc_mgr = get_node_or_null("/root/LocalizationManager")
	if loc_mgr and loc_mgr.has_method("get_current_locale"):
		is_en = loc_mgr.get_current_locale().to_lower().begins_with("en")
	elif TranslationServer.has_method("get_locale"):
		is_en = TranslationServer.get_locale().to_lower().begins_with("en")
	var lit_txt = tr("PROMPT_CAMPFIRE_REST") if is_en else prompt_text_lit
	var unlit_txt = tr("PROMPT_CAMPFIRE_LIGHT") if is_en else prompt_text_unlit
	prompt_label.text = lit_txt if is_lit else unlit_txt
	prompt_label.visible = (_player_in_range != null)


func _update_visuals(animate: bool = true) -> void:
	if fire_visual:
		fire_visual.visible = is_lit
		var anim_flame = fire_visual.get_node_or_null("AnimatedFlame") as AnimatedSprite2D
		if anim_flame:
			if is_lit:
				anim_flame.play("flame_burn")
			else:
				anim_flame.stop()
		if is_lit and animate:
			var tw := create_tween()
			fire_visual.scale = Vector2(0.2, 0.2)
			tw.tween_property(fire_visual, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(fire_visual, "scale", Vector2(1.0, 1.0), 0.15)

	if unlit_visual:
		unlit_visual.modulate = Color(1.25, 1.15, 1.05, 1.0) if is_lit else Color(0.85, 0.85, 0.85, 1.0)
		var coals_sprite = unlit_visual.get_node_or_null("CoalsSprite") as CanvasItem
		if coals_sprite and not is_lit:
			coals_sprite.modulate = Color(0.35, 0.32, 0.32, 1.0)
		var unlit_smoke = unlit_visual.get_node_or_null("UnlitSmoke") as CPUParticles2D
		if unlit_smoke:
			unlit_smoke.emitting = not is_lit

	if particles:
		particles.emitting = is_lit

	# Positional Audio Emitter Yönetimi (Idempotent)
	if is_lit:
		if not audio_emitter:
			audio_emitter = PositionalEmitter.new()
			audio_emitter.name = "CampfirePositionalAudio"
			audio_emitter.sound_key = "campfire"
			audio_emitter.max_distance = 950.0
			audio_emitter.volume_db = -5.0
			audio_emitter.loop = true
			add_child(audio_emitter)
	else:
		if audio_emitter:
			audio_emitter.queue_free()
			audio_emitter = null


## Kamp ateşini yakar, oyuncuyu dinlendirir, can/iksir tazeler ve kaydeder (İdempotent)
func ignite_and_rest(player_node: Node2D = null) -> void:
	if _is_resting_cooldown:
		return
	_is_resting_cooldown = true
	_cooldown_timer = 0.35

	if not player_node:
		player_node = _player_in_range
	if not player_node and is_inside_tree() and get_tree():
		var scene = get_tree().current_scene
		if scene:
			player_node = scene.find_child("Player", true, false)
			if not player_node:
				player_node = scene.find_child("CombatPlayer", true, false)

	var was_already_lit: bool = is_lit
	is_lit = true
	_update_visuals(not was_already_lit)
	_update_prompt_text()

	var spawn_pos: Vector2 = get_spawn_position()

	# 1. Kontrol noktasını SaveManager'a kaydet
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("set_checkpoint"):
		var cur_stage_path: String = ""
		if owner and "scene_file_path" in owner and not str(owner.scene_file_path).is_empty():
			cur_stage_path = str(owner.scene_file_path)
		elif is_inside_tree() and get_tree() and get_tree().current_scene:
			cur_stage_path = get_tree().current_scene.scene_file_path
		save_mgr.set_checkpoint(checkpoint_id, spawn_pos, true, cur_stage_path)

	# 2. GameState kalıcı olay kaydı
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("set_event_completed"):
		gs.set_event_completed("checkpoint_lit_" + checkpoint_id, true)

	# 3. Oyuncu canını ve iksirlerini yenile
	_replenish_player_and_potions(player_node)

	# 4. Sıradan devriye düşmanlarını yeniden başlat (respawnable_enemies)
	if respawn_enemies_on_rest:
		respawn_enemies()

	# 5. Görsel ve ses geri bildirimi
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if not was_already_lit:
		_spawn_floating_label(tr("CAMPFIRE_LIT_MSG"), Color(1.0, 0.65, 0.2, 1.0))
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("checkpoint_activated")
		checkpoint_activated.emit(checkpoint_id, spawn_pos)
	else:
		_spawn_floating_label(tr("CAMPFIRE_RESTED_MSG"), Color(0.35, 0.95, 0.55, 1.0))
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("rest_heal")
		player_rested.emit(checkpoint_id)


## Oyuncunun canını ve HUD iksirlerini tazeler
func _replenish_player_and_potions(player_node: Node2D) -> void:
	if player_node:
		var max_hp = player_node.get("max_health")
		if max_hp != null:
			player_node.set("current_health", int(max_hp))
			if player_node.has_signal("player_damaged"):
				player_node.player_damaged.emit(int(max_hp), int(max_hp))
		if player_node.get("is_dead") != null:
			player_node.set("is_dead", false)
		if player_node.get("can_move") != null:
			player_node.set("can_move", true)

	# HUD senkronizasyonu
	if is_inside_tree() and get_tree():
		var scene = get_tree().current_scene
		var hud = null
		if scene:
			hud = scene.find_child("FantasyHUD", true, false)
		if not hud and get_parent():
			hud = get_parent().find_child("FantasyHUD", true, false)
		if hud:
			var hud_max_hp = hud.get("max_health")
			if hud_max_hp != null:
				hud.set("current_health", int(hud_max_hp))
			var hud_max_mana = hud.get("max_mana")
			if hud_max_mana != null:
				hud.set("current_mana", int(hud_max_mana))
			if refill_potions:
				if hud.get("health_potions") != null:
					hud.set("health_potions", potion_heal_count)
				if hud.get("mana_potions") != null:
					hud.set("mana_potions", potion_mana_count)
			if hud.has_method("update_all"):
				hud.update_all()


## Sıradan düşmanları yeniden başlatır; boss ve kalıcı olaylar korunur
func respawn_enemies() -> int:
	var respawn_count: int = 0
	var gs = get_node_or_null("/root/GameState")

	# Kayıtlı düşmanları gez
	for entry in _respawnable_registry:
		var ref = entry.get("node")
		var enemy_instance: Node2D = ref.get_ref() if ref else null

		# Kalıcı bir boss veya özel görev düşmanıysa ve tamamlanmışsa canlandırma
		var enemy_name: String = str(entry.get("name", ""))
		if gs and gs.has_method("is_event_completed"):
			if gs.is_event_completed("boss_defeated_" + enemy_name) or gs.is_event_completed("enemy_cleared_" + enemy_name):
				continue

		if enemy_instance and is_instance_valid(enemy_instance) and enemy_instance.is_inside_tree():
			# Düşman hala sahnede yaşıyor veya ölü gövde olarak duruyor
			enemy_instance.global_position = entry["spawn_pos"]
			if "velocity" in enemy_instance:
				enemy_instance.velocity = Vector2.ZERO
			var m_hp = entry.get("max_health", 100)
			if enemy_instance.get("current_health") != null or "current_health" in enemy_instance:
				enemy_instance.set("current_health", int(m_hp))
			if enemy_instance.get("is_dead") != null or "is_dead" in enemy_instance:
				enemy_instance.set("is_dead", false)
			if enemy_instance.get("direction") != null or "direction" in enemy_instance:
				enemy_instance.set("direction", int(entry.get("direction", 1)))

			enemy_instance.visible = true
			enemy_instance.modulate.a = 1.0

			if enemy_instance is CollisionObject2D:
				enemy_instance.set_collision_layer_value(1, true)
				enemy_instance.set_collision_mask_value(1, true)

			if enemy_instance.has_method("_update_health_bar"):
				enemy_instance._update_health_bar()
			elif enemy_instance.has_method("init_health_bar"):
				enemy_instance.init_health_bar()

			respawn_count += 1
		else:
			# Düşman queue_free() ile silinmişse, sahnesinden yeniden örnekle
			var scene_path: String = str(entry.get("scene_file_path", ""))
			var parent_node: Node = entry.get("parent")
			if not parent_node and is_inside_tree() and get_tree():
				var p_path: NodePath = entry.get("parent_path", NodePath(""))
				if not p_path.is_empty():
					parent_node = get_node_or_null(p_path)

			if not parent_node and is_inside_tree() and get_tree():
				parent_node = get_tree().current_scene

			if scene_path.length() > 0 and ResourceLoader.exists(scene_path) and parent_node:
				var scene_res = load(scene_path)
				if scene_res:
					var new_enemy: Node2D = scene_res.instantiate() as Node2D
					if new_enemy:
						new_enemy.global_position = entry["spawn_pos"]
						new_enemy.rotation = float(entry.get("spawn_rot", 0.0))
						if "direction" in new_enemy:
							new_enemy.direction = int(entry.get("direction", 1))
						parent_node.add_child(new_enemy)
						if not new_enemy.is_in_group("respawnable_enemies"):
							new_enemy.add_to_group("respawnable_enemies")
						entry["node"] = weakref(new_enemy)
						respawn_count += 1

	enemies_respawned.emit(respawn_count)
	return respawn_count


## Oyuncunun yeniden doğacağı güvenli dünya koordinatını döndürür
func get_spawn_position() -> Vector2:
	return global_position + spawn_offset


## Ekrana süzülen metin geri bildirimi oluşturur
func _spawn_floating_label(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.global_position = global_position + Vector2(-90.0, -48.0)

	var parent_scene: Node = get_parent()
	if not parent_scene and is_inside_tree() and get_tree():
		parent_scene = get_tree().current_scene

	if parent_scene:
		parent_scene.add_child(label)
		var tw := label.create_tween()
		if tw:
			tw.tween_property(label, "global_position:y", label.global_position.y - 30.0, 0.85)
			tw.parallel().tween_property(label, "modulate:a", 0.0, 0.85)
			tw.tween_callback(label.queue_free)
