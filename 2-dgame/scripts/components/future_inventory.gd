extends RefCounted

## res://scripts/components/future_inventory.gd
## Bölüm 5 eşyaları (Epic 2D-158). Tanımlar (ad, açıklama, ikon — TR/EN)
## data/story/chapter_5_future.json "items" bloğundadır; adetler GameState.persistent_events
## içinde "future_item|<id>" olarak tutulur, böylece kayıt/yükleme ile korunur.
## Kullanılabilir: nano_repair_kit, chrono_injector, phase_shield_capsule, emp_grenade, plasma_cutter_flare.
## Görev eşyaları (core_access_chip, resistance_tag, stamped_prototype_part) yalnızca sahiplik bayrağıdır.

const CHAPTER_PATH: String = "res://data/story/chapter_5_future.json"
const PREFIX: String = "future_item|"
const EmpScript = preload("res://scripts/objects/future/emp_grenade.gd")
const PlasmaScript = preload("res://scripts/objects/future/plasma_bolt.gd")

const NANO_HEAL: int = 60
const INJECTOR_TIME: float = 8.0
const INJECTOR_MULT: float = 1.3
const PHASE_TIME: float = 15.0
const PHASE_FACTOR: float = 0.5
const META_PHASE_UNTIL: StringName = &"future_phase_until"
const META_INJECTOR_BASE: StringName = &"future_injector_base_speed"
const META_INJECTOR_UNTIL: StringName = &"future_injector_until"

static var _defs: Array = []


static func get_definitions() -> Array:
	if _defs.is_empty() and FileAccess.file_exists(CHAPTER_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHAPTER_PATH))
		if parsed is Dictionary:
			_defs = ((parsed as Dictionary).get("items", []) as Array).duplicate(true)
	return _defs


static func get_definition(item_id: String) -> Dictionary:
	for def: Variant in get_definitions():
		if def is Dictionary and str((def as Dictionary).get("id", "")) == item_id:
			return def as Dictionary
	return {}


static func _gs(node: Node) -> Node:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return null
	var gs: Node = node.get_node_or_null("/root/GameState")
	return gs if gs and "persistent_events" in gs else null


static func count(node: Node, item_id: String) -> int:
	var gs: Node = _gs(node)
	return int(gs.persistent_events.get(PREFIX + item_id, 0)) if gs else 0


static func add(node: Node, item_id: String, amount: int = 1) -> int:
	var gs: Node = _gs(node)
	if gs == null or amount == 0:
		return count(node, item_id)
	var total: int = maxi(0, count(node, item_id) + amount)
	gs.persistent_events[PREFIX + item_id] = total
	return total


static func has_item(node: Node, item_id: String) -> bool:
	return count(node, item_id) > 0


static func is_usable(item_id: String) -> bool:
	return bool(get_definition(item_id).get("usable", false))


## Eşyayı kullanır ve bir adet düşer. Etki uygulanamazsa (ör. can dolu) eşya harcanmaz.
static func use(node: Node, item_id: String, player: Node2D) -> bool:
	if not is_usable(item_id) or count(node, item_id) <= 0 or not is_instance_valid(player):
		return false
	if not _apply_effect(item_id, player):
		return false
	add(node, item_id, -1)
	return true


static func _apply_effect(item_id: String, player: Node2D) -> bool:
	var facing: float = float(player.get("facing_dir")) if "facing_dir" in player else 1.0
	match item_id:
		"nano_repair_kit":
			if "current_health" in player and "max_health" in player and int(player.current_health) >= int(player.max_health):
				return false
			if player.has_method("heal"):
				player.heal(NANO_HEAL)
			_sfx(player, "potion_drink")
			return true
		"chrono_injector":
			_apply_injector(player)
			_sfx(player, "sfx_time_slow_warp")
			return true
		"phase_shield_capsule":
			player.set_meta(META_PHASE_UNTIL, Time.get_ticks_msec() + int(PHASE_TIME * 1000.0))
			_sfx(player, "item_equip")
			return true
		"emp_grenade":
			var grenade: Node2D = EmpScript.new() as Node2D
			grenade.set("throw_velocity", Vector2(280.0 * facing, -330.0))
			player.get_parent().add_child(grenade)
			grenade.global_position = player.global_position + Vector2(14.0 * facing, -30.0)
			return true
		"plasma_cutter_flare":
			var bolt: Node2D = PlasmaScript.new() as Node2D
			bolt.set("direction", 1.0 if facing >= 0.0 else -1.0)
			player.get_parent().add_child(bolt)
			bolt.global_position = player.global_position + Vector2(18.0 * facing, -24.0)
			return true
	return false


## Faz Kalkanı aktifse lazer/enerji hasarı yarıya iner (tuzaklar ve boss ışınları uygular)
static func energy_damage_factor(player: Node) -> float:
	if is_instance_valid(player) and player.has_meta(META_PHASE_UNTIL) and Time.get_ticks_msec() < int(player.get_meta(META_PHASE_UNTIL)):
		return PHASE_FACTOR
	return 1.0


## Enerji kaynaklı hasarı Faz Kalkanı ve Kan Sisi kurallarıyla uygular (tüm lazerler bunu kullanır)
static func apply_energy_damage(player: Node, amount: int, source: Variant) -> bool:
	if not is_instance_valid(player) or not player.has_method("take_damage"):
		return false
	if "is_blood_mist_dashing" in player and bool(player.is_blood_mist_dashing):
		return false
	player.take_damage(maxi(1, int(round(float(amount) * energy_damage_factor(player)))), source)
	return true


## Stamina dolar, hareket ve saldırı (animasyon) hızı geçici olarak artar; üst üste kullanım katlanmaz
static func _apply_injector(player: Node2D) -> void:
	var shield: Variant = player.get("parabolic_shield") if "parabolic_shield" in player else null
	if shield is Object and is_instance_valid(shield) and "current_stamina" in shield:
		shield.current_stamina = float(shield.max_stamina)
	if not ("speed" in player):
		return
	if not player.has_meta(META_INJECTOR_BASE):
		player.set_meta(META_INJECTOR_BASE, float(player.speed))
		player.speed = float(player.speed) * INJECTOR_MULT
	var sprite: AnimatedSprite2D = player.get("anim_sprite") as AnimatedSprite2D if "anim_sprite" in player else null
	if sprite:
		sprite.speed_scale = INJECTOR_MULT
	var until: int = Time.get_ticks_msec() + int(INJECTOR_TIME * 1000.0)
	player.set_meta(META_INJECTOR_UNTIL, until)
	player.get_tree().create_timer(INJECTOR_TIME).timeout.connect(func() -> void:
		if not is_instance_valid(player) or int(player.get_meta(META_INJECTOR_UNTIL, 0)) > until:
			return
		if player.has_meta(META_INJECTOR_BASE):
			player.speed = float(player.get_meta(META_INJECTOR_BASE))
			player.remove_meta(META_INJECTOR_BASE)
		if is_instance_valid(sprite):
			sprite.speed_scale = 1.0
	)


static func _sfx(node: Node, key: String) -> void:
	var am: Node = node.get_node_or_null("/root/AudioManager") if node.is_inside_tree() else null
	if am and am.has_method("play_sfx"):
		am.play_sfx(key, -2.0)
