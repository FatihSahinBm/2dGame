class_name SpikeTrap
extends Node2D

## res://scripts/objects/spike_trap.gd
## Story 2D-132: Kazıklı Zemin ve Çevre Tuzakları (Spike Hazard)
##
## Başarı Kriterleri:
## 1. Yeniden kullanılabilir sahne yapısı (STATIC, TIMED ve TRIGGERED modları).
## 2. Aktif/pasif zamanlama döngüsü ve yeniden kurulum.
## 3. Oyuncu ve uygun düşman sınıfları için çarpışma ve hasar kuralları.
## 4. Tutarlı hasar aralığı (damage_interval): tek temasta spam hasarı engeller.
## 5. Yukarı doğru geri tepme (knockback) ve ses/görsel efektler.
## 6. Oyuncu, düşman ve çevre katmanlarını doğru ayırt eder.

signal spikes_extended()
signal spikes_retracted()
signal target_hit(target: Node2D, damage: int)

enum TrapMode {
	STATIC = 0,    ## Sürekli dışarıda ve tehlikeli
	TIMED = 1,     ## Belirli aralıklarla periyodik açılıp kapanır
	TRIGGERED = 2  ## Üzerine basılınca kısa gecikmeyle fırlar ve geri çekilir
}

@export var mode: TrapMode = TrapMode.TIMED
@export var damage: int = 25
@export var damage_interval: float = 0.8 ## Aynı hedefe tekrar hasar verme bekleme süresi
@export var knockback_force: float = 240.0
@export var affects_player: bool = true
@export var affects_enemies: bool = true
@export var affects_allies: bool = false

# TIMED Modu Zamanlamaları
@export var active_duration: float = 1.6
@export var inactive_duration: float = 2.0
@export var initial_delay: float = 0.0

# TRIGGERED Modu Zamanlamaları
@export var trigger_delay: float = 0.35
@export var triggered_stay_duration: float = 1.2
@export var trigger_reset_duration: float = 1.5

var is_active: bool = false
var _cycle_timer: float = 0.0
var _is_trigger_primed: bool = false
var _is_trigger_cooling: bool = false
var _target_cooldowns: Dictionary = {} # target -> float kalan süre

# Düğümler
var hit_area: Area2D = null
var visual: Node2D = null
var spikes_node: Node2D = null
var col_shape: CollisionShape2D = null


func _ready() -> void:
	add_to_group("traps")
	add_to_group("hazards")

	_setup_internal_nodes()

	# Başlangıç durumu
	_cycle_timer = initial_delay
	if mode == TrapMode.STATIC:
		extend_spikes(false)
	elif mode == TrapMode.TIMED:
		if initial_delay <= 0.0:
			retract_spikes(false)
		else:
			retract_spikes(false)
	elif mode == TrapMode.TRIGGERED:
		retract_spikes(false)


func _setup_internal_nodes() -> void:
	# HitArea
	hit_area = get_node_or_null("HitArea") as Area2D
	if not hit_area:
		hit_area = Area2D.new()
		hit_area.name = "HitArea"
		add_child(hit_area)

	hit_area.collision_layer = 0
	# Katman 1 (Player) ve Katman 2 (Enemies) algıla
	var mask: int = 0
	if affects_player:
		mask |= 1
	if affects_enemies:
		mask |= 2
	hit_area.collision_mask = mask if mask > 0 else 3

	# Collision Shape
	col_shape = hit_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not col_shape:
		col_shape = CollisionShape2D.new()
		col_shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(60.0, 22.0)
		col_shape.shape = rect
		col_shape.position = Vector2(0.0, -11.0)
		hit_area.add_child(col_shape)

	if not hit_area.body_entered.is_connected(_on_body_entered):
		hit_area.body_entered.connect(_on_body_entered)

	# Visual
	visual = get_node_or_null("Visual") as Node2D
	if not visual:
		visual = Node2D.new()
		visual.name = "Visual"
		add_child(visual)

	spikes_node = visual.get_node_or_null("Spikes") as Node2D
	if not spikes_node:
		spikes_node = Node2D.new()
		spikes_node.name = "Spikes"

		# Doku var mı kontrol et, yoksa prosedürel üçgen kazıklar çiz
		var spike_tex: Texture2D = null
		if ResourceLoader.exists("res://assets/environment/dungeon/dungeon_spike_pit.png"):
			spike_tex = load("res://assets/environment/dungeon/dungeon_spike_pit.png")

		if spike_tex:
			var sprite := Sprite2D.new()
			sprite.texture = spike_tex
			sprite.position = Vector2(0.0, -16.0)
			spikes_node.add_child(sprite)
		else:
			# Prosedürel kazıklar
			for i in range(5):
				var poly := Polygon2D.new()
				var x_offset := -24.0 + float(i) * 12.0
				poly.polygon = PackedVector2Array([
					Vector2(x_offset - 5.0, 0.0),
					Vector2(x_offset, -20.0),
					Vector2(x_offset + 5.0, 0.0)
				])
				poly.color = Color(0.75, 0.75, 0.8, 1.0)
				spikes_node.add_child(poly)

		visual.add_child(spikes_node)


func _physics_process(delta: float) -> void:
	# 1. Hedef hasar bekleme sürelerini güncelle
	_update_damage_cooldowns(delta)

	# 2. Zamanlama Döngüsü (TIMED Modu)
	if mode == TrapMode.TIMED:
		_process_timed_mode(delta)

	# 3. Aktif durumdaysa alandaki hedefleri denetle
	if is_active and hit_area:
		for body in hit_area.get_overlapping_bodies():
			_try_damage_target(body)


func _update_damage_cooldowns(delta: float) -> void:
	var keys_to_remove: Array = []
	for body in _target_cooldowns.keys():
		if not is_instance_valid(body):
			keys_to_remove.append(body)
			continue
		var rem: float = _target_cooldowns[body] - delta
		if rem <= 0.0:
			keys_to_remove.append(body)
		else:
			_target_cooldowns[body] = rem

	for k in keys_to_remove:
		_target_cooldowns.erase(k)


func _process_timed_mode(delta: float) -> void:
	_cycle_timer += delta
	if is_active:
		if _cycle_timer >= active_duration:
			_cycle_timer = 0.0
			retract_spikes()
	else:
		if _cycle_timer >= inactive_duration:
			_cycle_timer = 0.0
			extend_spikes()


func _on_body_entered(body: Node2D) -> void:
	if not _is_valid_target(body):
		return

	if mode == TrapMode.TRIGGERED:
		if not is_active and not _is_trigger_primed and not _is_trigger_cooling:
			_start_triggered_sequence()
	elif is_active:
		_try_damage_target(body)


func _start_triggered_sequence() -> void:
	_is_trigger_primed = true

	# Kısa uyarı sallantısı
	if spikes_node:
		var tw := create_tween()
		tw.tween_property(spikes_node, "position:y", -3.0, trigger_delay * 0.5)
		tw.tween_property(spikes_node, "position:y", 0.0, trigger_delay * 0.5)
		tw.tween_callback(func():
			if not is_inside_tree():
				return
			_is_trigger_primed = false
			extend_spikes()
			# Belirlenen süre açık kalıp geri çekilsin
			get_tree().create_timer(triggered_stay_duration).timeout.connect(func():
				if not is_inside_tree():
					return
				retract_spikes()
				_is_trigger_cooling = true
				get_tree().create_timer(trigger_reset_duration).timeout.connect(func():
					_is_trigger_cooling = false
				)
			)
		)


## Kazıkları yukarı fırlar ve aktif hale getirir
func extend_spikes(animate: bool = true) -> void:
	is_active = true
	if spikes_node:
		if animate:
			var tw := create_tween()
			tw.tween_property(spikes_node, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			spikes_node.position.y = 0.0
		spikes_node.visible = true

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("spike_trap", -2.0)

	spikes_extended.emit()

	# Alanda bekleyen hedeflere hemen hasar uygula
	if hit_area:
		for body in hit_area.get_overlapping_bodies():
			_try_damage_target(body)


## Kazıkları aşağı çeker ve pasif hale getirir
func retract_spikes(animate: bool = true) -> void:
	is_active = false
	if spikes_node:
		if animate:
			var tw := create_tween()
			tw.tween_property(spikes_node, "position:y", 18.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				if not is_active and spikes_node:
					spikes_node.visible = false
			)
		else:
			spikes_node.position.y = 18.0
			spikes_node.visible = false

	spikes_retracted.emit()


## Hedefe tutarlı hasar ve geri tepme uygular
func _try_damage_target(body: Node2D) -> bool:
	if not is_active or not _is_valid_target(body):
		return false

	if _target_cooldowns.has(body):
		return false

	# Hasar bekleme süresini kaydet (Spam hasarı önler)
	_target_cooldowns[body] = damage_interval

	# Geri tepme (Knockback)
	if "velocity" in body and body is CharacterBody2D:
		body.velocity.y = -knockback_force

	# Hasar verme
	if body.has_method("take_damage"):
		var takes_attacker: bool = false
		for m in body.get_method_list():
			if m.get("name") == "take_damage" and m.get("args", []).size() >= 2:
				takes_attacker = true
				break
		if takes_attacker:
			body.take_damage(damage, self)
		else:
			body.take_damage(damage)
	elif body.has_method("hit"):
		body.hit(damage)

	target_hit.emit(body, damage)
	return true


func _is_valid_target(body: Node) -> bool:
	if not body or not is_instance_valid(body) or body.is_queued_for_deletion():
		return false

	# Ölü gövdeleri yoksay
	if "is_dead" in body and body.is_dead:
		return false
	if body.get("is_dead") == true:
		return false

	# Sinematik durumundaki oyuncuyu koru
	var gs = get_node_or_null("/root/GameState")
	if gs and "is_in_cinematic" in gs and gs.is_in_cinematic:
		if body.is_in_group("player"):
			return false

	# Katman filtreleri
	var is_player: bool = body.is_in_group("player") or body.name.to_lower().contains("player")
	var is_enemy: bool = body.is_in_group("enemies") or body.is_in_group("damageable") and not is_player
	var is_ally: bool = body.is_in_group("allies")

	if is_player and not affects_player:
		return false
	if is_enemy and not affects_enemies:
		return false
	if is_ally and not affects_allies:
		return false

	# Sadece hasar alabilir varlıklar
	return body.has_method("take_damage") or body.has_method("hit")
