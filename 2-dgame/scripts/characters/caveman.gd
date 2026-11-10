class_name Caveman
extends CharacterBody2D

## res://scripts/characters/caveman.gd
## Taş Devri Mağara Adamı / Kabile Şefi Orok.
## - İki yönlü mod: NPC (Diyalog & Görev Verici) veya ENEMY (Düşman & Savaş Karşılaşması).
## - Seçim tabanlı diyalog: Barışçıl seçimde Odun Arabası görevi açılır;
##   düşmanca seçimde anında savaş sekansı ve saldırı durumuna geçer.
## - Animasyonlar: idle, walk, attack, hurt, death (mevcut oynanış ile tam uyumlu).

signal dialogue_started()
signal dialogue_finished()
signal quest_accepted()
signal became_hostile()
signal caveman_died()

enum Mode { NPC, ENEMY }
enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }

@export var mode: Mode = Mode.NPC
@export var character_name: String = "Kabile Şefi Orok"
@export var title: String = "Mağara Halkı Reisi"
@export var max_health: int = 180
@export var current_health: int = 180
@export var speed: float = 75.0
@export var chase_speed: float = 130.0
@export var attack_damage: int = 22
@export var attack_range: float = 65.0
@export var attack_cooldown: float = 1.6
@export var is_chief: bool = true

var current_state: State = State.IDLE
var quest_state: String = "not_started"
var _player_ref: CharacterBody2D = null
var _player_in_interact_range: bool = false
var _attack_timer: float = 0.0
var _hurt_timer: float = 0.0
var _hit_flash_tween: Tween = null
var _gravity: float = 1100.0

@onready var visual: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var hitbox: Area2D = $Visual/Hitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var interact_area: Area2D = $InteractArea
@onready var prompt_label: Label = $UI/PromptLabel
@onready var health_bar: ProgressBar = $UI/HealthBar


func _ensure_nodes() -> void:
	if not visual: visual = get_node_or_null("Visual")
	if not anim_sprite: anim_sprite = get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	if not hitbox: hitbox = get_node_or_null("Visual/Hitbox") as Area2D
	if not hurtbox: hurtbox = get_node_or_null("Hurtbox") as Area2D
	if not interact_area: interact_area = get_node_or_null("InteractArea") as Area2D
	if not prompt_label: prompt_label = get_node_or_null("UI/PromptLabel") as Label
	if not health_bar: health_bar = get_node_or_null("UI/HealthBar") as ProgressBar


func _ready() -> void:
	_ensure_nodes()
	add_to_group("cavemen")
	current_health = max_health
	if hitbox:
		hitbox.monitoring = false
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = (mode == Mode.ENEMY)
	if prompt_label:
		prompt_label.text = "[E] Konuş (%s)" % character_name
		prompt_label.visible = false
	if mode == Mode.ENEMY:
		_enter_enemy_mode(false)
	else:
		_enter_npc_mode()
	if anim_sprite:
		anim_sprite.animation_finished.connect(_on_animation_finished)
	if interact_area:
		interact_area.body_entered.connect(func(b): if b.is_in_group("player"): _player_in_interact_range = true; if mode == Mode.NPC and prompt_label and current_state != State.DEAD: prompt_label.visible = true)
		interact_area.body_exited.connect(func(b): if b.is_in_group("player"): _player_in_interact_range = false; if prompt_label: prompt_label.visible = false)


func _enter_npc_mode() -> void:
	_ensure_nodes()
	mode = Mode.NPC
	current_state = State.IDLE
	if is_in_group("enemies"): remove_from_group("enemies")
	add_to_group("allies")
	_play_anim("idle")


func _enter_enemy_mode(show_roar: bool = true) -> void:
	_ensure_nodes()
	if mode == Mode.ENEMY and (current_state == State.CHASE or current_state == State.ATTACK):
		return
	mode = Mode.ENEMY
	if is_in_group("allies"): remove_from_group("allies")
	add_to_group("enemies")
	add_to_group("damageable")
	if health_bar: health_bar.visible = true
	if prompt_label: prompt_label.visible = false
	became_hostile.emit()

	if is_chief and is_inside_tree():
		for c in get_tree().get_nodes_in_group("cavemen"):
			if c != self and c.has_method("_enter_enemy_mode"):
				c._enter_enemy_mode(true)

	if show_roar:
		current_state = State.ATTACK
		_play_anim("attack")
		_attack_timer = 1.0
	else:
		current_state = State.PATROL
		_play_anim("walk")


func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.NPC or not _player_in_interact_range or current_state == State.DEAD:
		return
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		start_interaction()


func start_interaction() -> void:
	var dialogue_box = get_tree().get_first_node_in_group("dialogue_box")
	if not dialogue_box or not dialogue_box.has_method("start_dialogue_from_data"):
		return
	if prompt_label: prompt_label.visible = false
	dialogue_started.emit()

	var key: String = "caveman_encounter"
	if quest_state == "active": key = "caveman_quest_active"
	elif quest_state == "completed": key = "caveman_quest_complete"

	dialogue_box.start_dialogue_from_data(key, self)
	if not dialogue_box.choice_selected.is_connected(_on_dialogue_choice_selected):
		dialogue_box.choice_selected.connect(_on_dialogue_choice_selected)
	if not dialogue_box.dialogue_completed.is_connected(_on_dialogue_closed):
		dialogue_box.dialogue_completed.connect(_on_dialogue_closed)


func _on_dialogue_choice_selected(action: String) -> void:
	var box = get_tree().get_first_node_in_group("dialogue_box")
	if action == "accept_quest":
		quest_state = "active"
		quest_accepted.emit()
		if box and box.has_method("start_dialogue_from_data"):
			box.start_dialogue_from_data("caveman_quest_accept", self)
	elif action == "start_fight":
		if box and box.has_method("start_dialogue_from_data"):
			box.start_dialogue_from_data("caveman_fight_shout", self)
		_enter_enemy_mode(true)


func _on_dialogue_closed() -> void:
	dialogue_finished.emit()
	if mode == Mode.NPC and _player_in_interact_range and prompt_label:
		prompt_label.visible = true


func complete_quest() -> void:
	quest_state = "completed"
	var box = get_tree().get_first_node_in_group("dialogue_box")
	if box and box.has_method("start_dialogue_from_data"):
		box.start_dialogue_from_data("caveman_quest_complete", self)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta
	if mode == Mode.ENEMY:
		_process_enemy_ai(delta)
	move_and_slide()


func _process_enemy_ai(delta: float) -> void:
	if current_state == State.DEAD: return
	if _attack_timer > 0.0: _attack_timer -= delta
	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0 and current_state == State.HURT: current_state = State.CHASE

	if not _player_ref or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not _player_ref or current_state == State.HURT or current_state == State.ATTACK:
		velocity.x = move_toward(velocity.x, 0.0, speed * 2.0 * delta)
		return

	var dist_x: float = _player_ref.global_position.x - global_position.x
	var abs_dist: float = absf(dist_x)
	var face_dir: int = 1 if dist_x > 0 else -1
	if visual and abs_dist > 5.0:
		visual.scale.x = absf(visual.scale.x) * face_dir

	match current_state:
		State.IDLE, State.PATROL, State.CHASE:
			if abs_dist <= attack_range:
				if _attack_timer <= 0.0: _start_attack()
				else:
					current_state = State.IDLE
					velocity.x = 0.0
					_play_anim("idle")
			else:
				current_state = State.CHASE
				velocity.x = face_dir * chase_speed
				_play_anim("walk")


func _start_attack() -> void:
	current_state = State.ATTACK
	velocity.x = 0.0
	_attack_timer = attack_cooldown
	_play_anim("attack")
	var tw: Tween = create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func(): if hitbox and current_state == State.ATTACK: hitbox.monitoring = true)
	tw.tween_interval(0.3)
	tw.tween_callback(func(): if hitbox: hitbox.monitoring = false)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		var knock_dir: Vector2 = Vector2(visual.scale.x, -0.4).normalized()
		body.take_damage(attack_damage, knock_dir * 180.0)


func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DEAD: return
	if mode == Mode.NPC: _enter_enemy_mode(true)
	current_health = maxi(0, current_health - amount)
	if health_bar: health_bar.value = current_health

	if _hit_flash_tween and _hit_flash_tween.is_valid(): _hit_flash_tween.kill()
	if visual:
		visual.modulate = Color(2.5, 0.5, 0.5, 1.0)
		_hit_flash_tween = create_tween()
		_hit_flash_tween.tween_property(visual, "modulate", Color.WHITE, 0.2)

	if current_health <= 0:
		current_state = State.DEAD
		velocity = Vector2.ZERO
		if hitbox: hitbox.monitoring = false
		if health_bar: health_bar.visible = false
		if prompt_label: prompt_label.visible = false
		caveman_died.emit()
		_play_anim("death")
		var tw: Tween = create_tween()
		tw.tween_interval(1.8)
		tw.tween_property(visual, "modulate:a", 0.0, 0.8)
		tw.tween_callback(queue_free)
	else:
		current_state = State.HURT
		_hurt_timer = 0.4
		velocity = knockback_dir * 160.0
		_play_anim("hurt")


func _play_anim(anim_name: String) -> void:
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
		if anim_sprite.animation != anim_name:
			anim_sprite.play(anim_name)


func _on_animation_finished() -> void:
	if current_state == State.ATTACK:
		current_state = State.IDLE
		_play_anim("idle")
	elif current_state == State.HURT:
		current_state = State.CHASE
		_play_anim("walk")
