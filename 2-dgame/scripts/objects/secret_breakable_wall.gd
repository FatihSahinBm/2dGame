class_name SecretBreakableWall
extends StaticBody2D

## res://scripts/objects/secret_breakable_wall.gd
## Gizli kırılabilir duvar (Story 2D-133).
## - Yalnızca belirlenmiş saldırı türleri (varsayılan: ağır saldırı) duvarı kırabilir;
##   diğer vuruşlar duvarı çatlatmaz, yalnızca "dayanıyor" ipucu verir.
## - Kırılınca çarpışma kapanır, keşif bildirimi ve ses/efekt oynar, ödül bir kez verilir.
## - Kırık durumu WorldObjectState ile kalıcıdır: kayıt/yükleme sonrası duvar kırık başlar
##   ve ödül yeniden verilmez.
## Sahnede CollisionShape2D / Visual yoksa wall_size'a göre kendisi oluşturur.

signal wall_hit_resisted(attack_type: String)
signal wall_broken()
signal secret_discovered(reward_coins: int, codex_entry_id: String)

const WorldObjectState = preload("res://scripts/components/world_object_state.gd")
const STATE_BROKEN: String = "broken"

@export var wall_size: Vector2 = Vector2(40.0, 96.0)
## Duvarı kırabilen oyuncu saldırı türleri (Player.current_attack_type)
@export var breaking_attack_types: Array[String] = ["heavy"]
@export var max_health: int = 50
@export var reward_coins: int = 25
## Boş değilse kırılınca bu kodeks kaydı açılır (parşömen/dünya bilgisi bağlantısı)
@export var codex_entry_id: String = ""
@export var wall_color: Color = Color(0.32, 0.29, 0.34, 1.0)

var current_health: int = 0
var is_broken: bool = false

var _collision: CollisionShape2D = null
var _visual: CanvasItem = null


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("secret_walls")
	collision_layer = 3
	collision_mask = 0
	current_health = max_health
	_ensure_nodes()
	# Kayıtlı durum: daha önce kırılmış duvar sessizce açık başlar (ödül ve bildirim yok)
	if WorldObjectState.is_set(self, STATE_BROKEN):
		_apply_broken_state()


## Hasar girişi. Saldıran oyuncunun saldırı türü izinli değilse duvar dayanır.
func take_damage(amount: int, attacker: Variant = null) -> void:
	if is_broken or amount <= 0:
		return
	var attack_type: String = ""
	if attacker is Node and is_instance_valid(attacker) and "current_attack_type" in attacker:
		attack_type = str(attacker.current_attack_type)
	if not breaking_attack_types.has(attack_type):
		wall_hit_resisted.emit(attack_type)
		_play_resist_feedback()
		return

	current_health = maxi(current_health - amount, 0)
	if current_health <= 0:
		_break_wall()
	else:
		_play_resist_feedback()


func _break_wall() -> void:
	if is_broken:
		return
	WorldObjectState.mark(self, STATE_BROKEN)
	_apply_broken_state()
	wall_broken.emit()

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sound_2d"):
		audio_mgr.play_sound_2d("platform_crumble", global_position)
	_spawn_rubble()
	_grant_reward()


## Kırık durumu uygular: geçiş açılır, fizik çarpışması geride kalmaz
func _apply_broken_state() -> void:
	is_broken = true
	current_health = 0
	remove_from_group("damageable")
	collision_layer = 0
	if _collision:
		_collision.set_deferred("disabled", true)
	if _visual:
		_visual.visible = false


func _grant_reward() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	if reward_coins > 0 and hud and hud.has_method("update_coins") and "coins" in hud:
		hud.update_coins(int(hud.coins) + reward_coins)
	if not codex_entry_id.is_empty():
		var codex: Node = get_node_or_null("/root/CodexManager")
		if codex and codex.has_method("unlock_entry"):
			codex.unlock_entry(codex_entry_id)
	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(tr("SECRET_FOUND_TITLE"), tr("SECRET_FOUND_SUB"), tr("SECRET_FOUND_DESC") % reward_coins)
	secret_discovered.emit(reward_coins, codex_entry_id)


func _play_resist_feedback() -> void:
	if _visual == null or not is_inside_tree():
		return
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "modulate", Color(1.5, 1.4, 1.2, 1.0), 0.05)
	tween.tween_property(_visual, "modulate", Color.WHITE, 0.18)


func _spawn_rubble() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var rubble: CPUParticles2D = CPUParticles2D.new()
	rubble.one_shot = true
	rubble.amount = 18
	rubble.lifetime = 0.7
	rubble.explosiveness = 0.9
	rubble.spread = 70.0
	rubble.direction = Vector2(0, -1)
	rubble.initial_velocity_min = 60.0
	rubble.initial_velocity_max = 170.0
	rubble.gravity = Vector2(0, 520)
	rubble.scale_amount_min = 2.0
	rubble.scale_amount_max = 4.5
	rubble.color = wall_color.lightened(0.15)
	rubble.global_position = global_position + Vector2(0, -wall_size.y * 0.5)
	parent_node.add_child(rubble)
	rubble.emitting = true
	rubble.finished.connect(rubble.queue_free)


func _ensure_nodes() -> void:
	_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _collision == null:
		_collision = CollisionShape2D.new()
		_collision.name = "CollisionShape2D"
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = wall_size
		_collision.shape = shape
		_collision.position = Vector2(0, -wall_size.y * 0.5)
		add_child(_collision)
	_visual = get_node_or_null("Visual") as CanvasItem
	if _visual == null:
		var rect: ColorRect = ColorRect.new()
		rect.name = "Visual"
		rect.color = wall_color
		rect.size = wall_size
		rect.position = Vector2(-wall_size.x * 0.5, -wall_size.y)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_visual = rect
