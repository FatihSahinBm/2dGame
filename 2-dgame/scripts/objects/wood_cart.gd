class_name WoodCart
extends CharacterBody2D

## res://scripts/objects/wood_cart.gd
## Taş Devri Odun Arabası (Stone Age Wood Cart).
## - Oyuncu arabayı iterek (veya yanındayken E basarak) kanyon boyunca mağaraya taşır.
## - Belirli bir mesafede (pusu noktası) yırtıcı raptor saldırısı ve tehlike sekansı tetiklenir.
## - Mağara hedefine ulaştığında görev tamamlanır ve kabile şefi ödül verir.

signal push_started()
signal push_stopped()
signal ambush_triggered()
signal delivered_to_cave()
signal cart_damaged(current_hp: int, max_hp: int)
signal cart_destroyed()

@export var max_health: int = 250
@export var current_health: int = 250
@export var push_speed: float = 85.0
@export var target_destination_x: float = 1750.0
@export var ambush_waypoint_x: float = 1050.0

var is_active: bool = false
var is_delivered: bool = false
var is_destroyed: bool = false
var _player_nearby: bool = false
var _is_being_pushed: bool = false
var _ambush_spawned: bool = false
var _gravity: float = 1100.0

@onready var sprite: Sprite2D = $Visual/CartSprite
@onready var logs_sprite: Sprite2D = get_node_or_null("Visual/LogsSprite") as Sprite2D
@onready var dust_particles: CPUParticles2D = $Visual/WheelDust
@onready var push_zone: Area2D = $PushZone
@onready var prompt_label: Label = $UI/PromptLabel
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var progress_label: Label = $UI/ProgressLabel


func _ready() -> void:
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false
	if prompt_label:
		prompt_label.visible = false
	if progress_label:
		progress_label.visible = false
	if dust_particles:
		dust_particles.emitting = false

	if push_zone:
		push_zone.body_entered.connect(_on_push_zone_body_entered)
		push_zone.body_exited.connect(_on_push_zone_body_exited)


func activate_cart() -> void:
	is_active = true
	if health_bar:
		health_bar.visible = true
	if progress_label:
		progress_label.visible = true
	_update_progress_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active or is_delivered or is_destroyed:
		return

	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		if _player_nearby:
			_is_being_pushed = not _is_being_pushed
			if _is_being_pushed:
				push_started.emit()
			else:
				push_stopped.emit()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta

	if is_active and not is_delivered and not is_destroyed:
		_process_movement(delta)
		_check_waypoints()
	else:
		velocity.x = move_toward(velocity.x, 0.0, push_speed * 2.0 * delta)

	move_and_slide()

	if dust_particles:
		dust_particles.emitting = (absf(velocity.x) > 10.0 and is_on_floor())


func _process_movement(delta: float) -> void:
	var player_pushing: bool = false
	var player_node: CharacterBody2D = null

	if _player_nearby:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_node = players[0] as CharacterBody2D

	if player_node and is_instance_valid(player_node):
		var touching_cart: bool = (player_node.global_position.x < global_position.x and absf(player_node.global_position.x - global_position.x) < 70.0)
		var player_moving_right: bool = (player_node.velocity.x > 10.0 or Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D))
		player_pushing = touching_cart and (player_moving_right or _is_being_pushed)

	if player_pushing:
		velocity.x = move_toward(velocity.x, push_speed, push_speed * 3.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, push_speed * 4.0 * delta)

	_update_progress_ui()


func _check_waypoints() -> void:
	# 1. Pusu noktası kontrolü
	if not _ambush_spawned and global_position.x >= ambush_waypoint_x:
		_ambush_spawned = true
		ambush_triggered.emit()

	# 2. Mağara hedefine varış kontrolü
	if not is_delivered and global_position.x >= target_destination_x:
		_on_reach_destination()


func _on_reach_destination() -> void:
	is_delivered = true
	velocity.x = 0.0
	if prompt_label:
		prompt_label.text = "✓ Odun Arabası Mağaraya Ulaştı!"
		prompt_label.visible = true
	if dust_particles:
		dust_particles.emitting = false

	delivered_to_cave.emit()


func _update_progress_ui() -> void:
	if not progress_label:
		return
	var remaining_dist: float = maxf(0.0, target_destination_x - global_position.x)
	var pct: int = clampi(int(100.0 - (remaining_dist / (target_destination_x - 300.0) * 100.0)), 0, 100)
	progress_label.text = "Mağaraya Kalan: %d m (%% %d)" % [int(remaining_dist / 10.0), pct]


func take_damage(amount: int) -> void:
	if is_destroyed or is_delivered:
		return

	current_health = maxi(0, current_health - amount)
	if health_bar:
		health_bar.value = current_health

	cart_damaged.emit(current_health, max_health)

	# Hasar görsel geri bildirimi (kırmızı yanıp sönme)
	if sprite:
		var tw: Tween = create_tween()
		tw.tween_property(sprite, "modulate", Color(2.0, 0.4, 0.4, 1.0), 0.1)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	if current_health <= 0:
		_destroy_cart()


func _destroy_cart() -> void:
	is_destroyed = true
	velocity = Vector2.ZERO
	cart_destroyed.emit()
	if prompt_label:
		prompt_label.text = "✗ Araba Parçalandı!"
		prompt_label.visible = true


func _on_push_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		if is_active and not is_delivered and not is_destroyed and prompt_label:
			prompt_label.text = "[D veya E] Arabayı İt"
			prompt_label.visible = true


func _on_push_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		if prompt_label and not is_delivered and not is_destroyed:
			prompt_label.visible = false

