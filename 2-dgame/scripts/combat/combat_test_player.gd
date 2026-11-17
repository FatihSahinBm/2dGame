extends "res://scripts/player.gd"

## res://scripts/combat/combat_test_player.gd
## Vlad bölümü mekanikleri: Kan Sisi Atılması (Blood Mist Dash),
## Kılıç İsyanı (Sword Rebellion) ve Can Yenileme (Heal) desteği.

const SwordRebellionManager = preload("res://scripts/combat/sword_rebellion_manager.gd")


func _ready() -> void:
	super._ready()
	add_to_group("player")
	_setup_rebellion_manager()


func _setup_rebellion_manager() -> void:
	if not sword_rebellion:
		sword_rebellion = get_node_or_null("SwordRebellionManager")
		if not sword_rebellion:
			sword_rebellion = SwordRebellionManager.new()
			sword_rebellion.name = "SwordRebellionManager"
			add_child(sword_rebellion)


## Can Yenileme (Müttefik sömürüsü veya vampirik darbeden)
func heal(amount: int) -> void:
	if is_dead:
		return
	current_health = mini(max_health, current_health + amount)
	player_damaged.emit(current_health, max_health)

	# Yeşil / Kızıl can yenileme efekti
	if visual_node:
		var tw: Tween = create_tween()
		tw.tween_property(visual_node, "modulate", Color(0.3, 1.8, 0.4, 1.0), 0.08)
		tw.tween_property(visual_node, "modulate", Color.WHITE, 0.15)

	# Uçan bildirim metni
	var parent_scene: Node = get_parent()
	if parent_scene:
		var label: Label = Label.new()
		label.text = tr("FLOAT_HEAL") % amount
		label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_font_size_override("font_size", 13)
		label.global_position = global_position + Vector2(-20.0, -45.0)
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 25.0, 0.6)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
		tw.tween_callback(label.queue_free)


# --- Kan Sisi Atılması kuralları (Story 2D-126) ---
## Açılma koşulu: GameState "blood_mist_dash" yeteneği (Vlad yenilince açılır).
const BLOOD_MIST_ABILITY_ID: String = "blood_mist_dash"
const BLOOD_MIST_DURATION: float = 0.26      # Atılma ve hasar almama penceresi (sn)
const BLOOD_MIST_COOLDOWN: float = 0.42      # Atılma başından itibaren bekleme süresi (sn)
const BLOOD_MIST_SPEED_MULT: float = 1.35
const BLOOD_MIST_RADIUS: float = 32.0
const BLOOD_MIST_DAMAGE: int = 20            # Düşman başına, atılma başına bir kez
const BLOOD_MIST_LEECH_PER_ENEMY: int = 10
const BLOOD_MIST_LEECH_CAP: int = 30         # Tek atılmada en fazla iyileşme

var is_blood_mist_dashing: bool = false
var _mist_hit_ids: Dictionary = {}
var _mist_healed: int = 0


## Dash / Kan Sisi Atılması
func perform_dash() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	var has_blood_mist: bool = game_state and game_state.has_method("has_ability") and game_state.has_ability(BLOOD_MIST_ABILITY_ID)

	if not has_blood_mist:
		super.perform_dash()
		return
	if is_blood_mist_dashing or not can_dash:
		return

	# --- Kan Sisi Atılması (Blood Mist Dash) ---
	is_dashing = true
	is_blood_mist_dashing = true
	can_dash = false
	_mist_hit_ids.clear()
	_mist_healed = 0
	set_collision_mask_value(2, false) # Düşman çarpışmasını devre dışı bırak
	velocity.x = facing_dir * (dash_speed * BLOOD_MIST_SPEED_MULT) # Daha hızlı ve akıcı
	velocity.y = 0.0
	_play_sfx("mist_dash", -3.0)

	if anim_sprite and anim_sprite.sprite_frames.has_animation("dash"):
		anim_sprite.play("dash")

	# Kızıl sis ve yarı saydamlık
	if visual_node:
		visual_node.modulate = Color(1.8, 0.1, 0.2, 0.4)

	_spawn_blood_mist_trail()
	_leech_enemies_in_path()

	# Zamanlayıcılar metoda bağlıdır: düğüm serbest kalırsa (sahne değişimi) kendiliğinden düşer
	get_tree().create_timer(BLOOD_MIST_DURATION).timeout.connect(_end_blood_mist_dash)
	get_tree().create_timer(BLOOD_MIST_COOLDOWN).timeout.connect(_reset_blood_mist_cooldown)


## Atılmayı bitirir; çarpışma maskesi ve görsel her durumda eski hâline döner
func _end_blood_mist_dash() -> void:
	if not is_blood_mist_dashing:
		return
	is_blood_mist_dashing = false
	is_dashing = false
	set_collision_mask_value(2, true)
	if visual_node:
		visual_node.modulate = Color.WHITE


func _reset_blood_mist_cooldown() -> void:
	can_dash = true


func _physics_process(delta: float) -> void:
	if is_plunging:
		_process_plunge(delta)
		return
	super._physics_process(delta)
	_process_hold_to_attack(delta)
	# Sis hâlindeyken yol boyunca karşılaşılan düşmanlar taranır
	if is_blood_mist_dashing:
		_leech_enemies_in_path()


## Hasar almama penceresi: yalnızca take_damage ile gelen saldırıları (yakın dövüş, mermi) etkiler;
## çukur/boşluk gibi doğrudan ölüm kaynakları bu pencereden etkilenmez.
func take_damage(amount: int, attacker_source: Variant = Vector2.INF) -> void:
	if is_blood_mist_dashing and not is_dead:
		_spawn_dodge_text(tr("FLOAT_MIST_DODGE"))
		return
	super.take_damage(amount, attacker_source)


func _leech_enemies_in_path() -> void:
	if not is_inside_tree() or get_world_2d() == null:
		return
	var space_state = get_world_2d().direct_space_state
	if space_state == null:
		return
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = BLOOD_MIST_RADIUS
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2 # Düşmanlar
	query.collide_with_bodies = true

	for res in space_state.intersect_shape(query):
		_leech_from(res.get("collider"))


## Tek bir hedefe sis hasarı uygular. Aynı hedef aynı atılmada yalnızca bir kez vurulur;
## müttefikler etkilenmez; toplam iyileşme BLOOD_MIST_LEECH_CAP ile sınırlıdır.
func _leech_from(collider: Variant) -> bool:
	if not (collider is Node) or not is_instance_valid(collider) or collider == self:
		return false
	var target: Node = collider as Node
	if not target.has_method("take_damage") or target.is_in_group("allies"):
		return false
	if "is_dead" in target and target.is_dead:
		return false
	var target_id: int = target.get_instance_id()
	if _mist_hit_ids.has(target_id):
		return false
	_mist_hit_ids[target_id] = true
	target.take_damage(BLOOD_MIST_DAMAGE)
	var heal_amount: int = mini(BLOOD_MIST_LEECH_PER_ENEMY, BLOOD_MIST_LEECH_CAP - _mist_healed)
	if heal_amount > 0:
		_mist_healed += heal_amount
		heal(heal_amount)
	return true


func _spawn_blood_mist_trail() -> void:
	var parent_scene: Node = get_parent()
	if not parent_scene:
		return
	var mist: CPUParticles2D = CPUParticles2D.new()
	mist.emitting = true
	mist.one_shot = true
	mist.amount = 32
	mist.lifetime = 0.4
	mist.explosiveness = 0.6
	mist.spread = 180.0
	mist.gravity = Vector2(0, -20)
	mist.initial_velocity_min = 20.0
	mist.initial_velocity_max = 80.0
	mist.color = Color(0.85, 0.08, 0.18, 0.8)
	mist.global_position = global_position
	parent_scene.add_child(mist)
	mist.finished.connect(mist.queue_free)


# --- Havadan Yere Sert İniş / Plunge Attack (Story 2D-129) ---
## Girdi: havadayken AŞAĞI yön basılıyken hafif saldırı.
## Kurallar: yalnızca havada ve kılıç eldeyken başlar; iniş boyunca yatay hareket kilitlidir;
## zemine temas TEK bir iniş olayı üretir (alan hasarı + geri itme + toz + sarsıntı);
## hasar alma/ölüm veya zemine hiç ulaşamama durumunda iniş etkisiz iptal edilir.
signal plunge_started()
signal plunge_landed(hit_count: int)
signal plunge_cancelled()

const PLUNGE_FALL_SPEED: float = 900.0
const PLUNGE_MAX_DURATION: float = 1.5      # Zemine ulaşılamazsa iptal (sn)
const PLUNGE_RECOVERY: float = 0.22         # İnişten sonra kontrolün geri dönmesi (sn)
const PLUNGE_RADIUS: float = 96.0
const PLUNGE_DAMAGE: int = 45
const PLUNGE_KNOCKBACK: Vector2 = Vector2(260.0, -170.0)

var is_plunging: bool = false
var _plunge_time: float = 0.0
var _plunge_impact_done: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack_light") and _is_down_input_pressed() and can_start_plunge():
		get_viewport().set_input_as_handled()
		start_plunge()
		return
	super._unhandled_input(event)


func can_start_plunge() -> bool:
	if is_plunging or is_dead or is_hurt or not can_move or not has_sword:
		return false
	if is_on_floor() or is_attacking or is_dashing or is_rolling or is_sliding or is_defending or is_rebelling:
		return false
	return true


func start_plunge() -> bool:
	if not can_start_plunge():
		return false
	is_plunging = true
	is_attacking = true
	current_attack_type = "plunge"
	_plunge_time = 0.0
	_plunge_impact_done = false
	velocity = Vector2(0.0, PLUNGE_FALL_SPEED)
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")
	_play_sword_slash(-4.0, "sword_slash_2")
	plunge_started.emit()
	return true


func _process_plunge(delta: float) -> void:
	if is_dead or is_hurt:
		cancel_plunge()
		return
	_plunge_time += delta
	velocity = Vector2(0.0, PLUNGE_FALL_SPEED)
	move_and_slide()
	if is_on_floor():
		_land_plunge()
	elif _plunge_time >= PLUNGE_MAX_DURATION:
		cancel_plunge()


## Zemine çarpma: alan hasarı yalnızca bir kez uygulanır
func _land_plunge() -> void:
	if _plunge_impact_done:
		return
	_plunge_impact_done = true
	is_plunging = false
	velocity = Vector2.ZERO
	var hit_count: int = 0
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			if _apply_plunge_hit(node):
				hit_count += 1
	_spawn_plunge_dust()
	_play_sfx("sword_hit_thud", 0.0)
	var cam: Node = get_node_or_null("Camera2D")
	if cam and cam.has_method("apply_shake"):
		cam.apply_shake(7.0)
	var input_mgr: Node = get_node_or_null("/root/InputControllerManager")
	if input_mgr and input_mgr.has_method("vibrate_heavy"):
		input_mgr.vibrate_heavy()
	plunge_landed.emit(hit_count)
	get_tree().create_timer(PLUNGE_RECOVERY).timeout.connect(_end_plunge_recovery)


func _apply_plunge_hit(node: Node) -> bool:
	if not (node is Node2D) or node == self or not is_instance_valid(node):
		return false
	if node.is_in_group("allies") or not node.has_method("take_damage"):
		return false
	if "is_dead" in node and node.is_dead:
		return false
	var target: Node2D = node as Node2D
	if global_position.distance_to(target.global_position) > PLUNGE_RADIUS:
		return false
	target.take_damage(PLUNGE_DAMAGE)
	PoiseComponent.apply_player_hit(target, "plunge")
	if target is CharacterBody2D and is_instance_valid(target):
		var away: float = 1.0 if target.global_position.x >= global_position.x else -1.0
		(target as CharacterBody2D).velocity = Vector2(PLUNGE_KNOCKBACK.x * away, PLUNGE_KNOCKBACK.y)
	return true


func _end_plunge_recovery() -> void:
	if current_attack_type == "plunge":
		is_attacking = false
		current_attack_type = ""


## İnişi etkisiz bitirir (hasar alma, ölüm veya zemine ulaşamama)
func cancel_plunge() -> void:
	if not is_plunging:
		return
	is_plunging = false
	_plunge_impact_done = true
	if current_attack_type == "plunge":
		is_attacking = false
		current_attack_type = ""
	plunge_cancelled.emit()


func _spawn_plunge_dust() -> void:
	var parent_scene: Node = get_parent()
	if parent_scene == null:
		return
	var dust: CPUParticles2D = CPUParticles2D.new()
	dust.one_shot = true
	dust.amount = 22
	dust.lifetime = 0.45
	dust.explosiveness = 0.95
	dust.direction = Vector2(0, -1)
	dust.spread = 85.0
	dust.initial_velocity_min = 70.0
	dust.initial_velocity_max = 190.0
	dust.gravity = Vector2(0, 380)
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 4.0
	dust.color = Color(0.78, 0.72, 0.62, 0.85)
	dust.global_position = global_position
	parent_scene.add_child(dust)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)


# --- Basılı tutarak saldırı (Story 2D-118, erişilebilirlik) ---
var _hold_attack_wait: float = 0.0


## Seçenek açıksa, hafif saldırı tuşu basılı kaldıkça saldırı girdisi kendiliğinden tekrarlanır.
## Tekrarlanan girdi normal saldırı yolundan geçer; tüm kilitler (isyan, savunma, sinematik) geçerlidir.
func _process_hold_to_attack(delta: float) -> void:
	_hold_attack_wait = maxf(_hold_attack_wait - delta, 0.0)
	var comfort: Node = get_node_or_null("/root/ComfortSettings") if is_inside_tree() else null
	if comfort == null or not comfort.hold_to_attack or _hold_attack_wait > 0.0:
		return
	if is_attacking or is_dead or not can_move or not Input.is_action_pressed("attack_light"):
		return
	_hold_attack_wait = float(comfort.HOLD_ATTACK_INTERVAL)
	var repeat_event: InputEventAction = InputEventAction.new()
	repeat_event.action = "attack_light"
	repeat_event.pressed = true
	_unhandled_input(repeat_event)
