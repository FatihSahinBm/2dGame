extends RefCounted

## res://scripts/components/ww2_inventory.gd
## Bölüm 4 eşyaları (Epic 2D-144). Eşya tanımları (ad, açıklama, ikon — TR/EN)
## data/story/chapter_4_ww2.json "items" bloğundadır; adetler GameState.persistent_events
## içinde "ww2_item|<id>" olarak tutulur, böylece kayıt/yükleme ile korunur.
## Kullanılabilir eşyalar: field_bandage, adrenaline_syringe, gas_filter, stick_grenade, phosphor_flare.
## Görev eşyaları (radio_codes, bunker_keycard, prisoner_tags) yalnızca sahiplik bayrağıdır.

const CHAPTER_PATH: String = "res://data/story/chapter_4_ww2.json"
const PREFIX: String = "ww2_item|"
const GrenadeScript = preload("res://scripts/objects/ww2/stick_grenade.gd")
const FlareScript = preload("res://scripts/objects/ww2/phosphor_flare.gd")

const BANDAGE_HEAL: int = 40
const ADRENALINE_TIME: float = 8.0
const ADRENALINE_SPEED_MULT: float = 1.35
const GAS_FILTER_TIME: float = 20.0
const META_GAS_IMMUNE_UNTIL: StringName = &"ww2_gas_immune_until"
const META_ADRENALINE_BASE: StringName = &"ww2_adrenaline_base_speed"
const META_ADRENALINE_UNTIL: StringName = &"ww2_adrenaline_until"

static var _defs: Array = []


## JSON'daki eşya tanımları (önbellekli)
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
	match item_id:
		"field_bandage":
			if "current_health" in player and "max_health" in player and int(player.current_health) >= int(player.max_health):
				return false
			if player.has_method("heal"):
				player.heal(BANDAGE_HEAL)
			_sfx(player, "potion_drink")
			return true
		"adrenaline_syringe":
			_apply_adrenaline(player)
			_sfx(player, "potion_drink")
			return true
		"gas_filter":
			player.set_meta(META_GAS_IMMUNE_UNTIL, Time.get_ticks_msec() + int(GAS_FILTER_TIME * 1000.0))
			_sfx(player, "item_equip")
			return true
		"stick_grenade":
			var grenade: Node2D = GrenadeScript.new() as Node2D
			var facing: float = float(player.get("facing_dir")) if "facing_dir" in player else 1.0
			grenade.set("throw_velocity", Vector2(260.0 * facing, -340.0))
			player.get_parent().add_child(grenade)
			grenade.global_position = player.global_position + Vector2(14.0 * facing, -30.0)
			return true
		"phosphor_flare":
			var flare: Node2D = FlareScript.new() as Node2D
			player.get_parent().add_child(flare)
			flare.global_position = player.global_position + Vector2(0.0, -20.0)
			return true
	return false


## Gaz maskesi filtresi aktif mi (ToxicGas hasarını engeller)
static func is_gas_immune(player: Node) -> bool:
	return is_instance_valid(player) and player.has_meta(META_GAS_IMMUNE_UNTIL) \
		and Time.get_ticks_msec() < int(player.get_meta(META_GAS_IMMUNE_UNTIL))


## Üst üste kullanım süreyi uzatır; hız çarpanı katlanmaz
static func _apply_adrenaline(player: Node2D) -> void:
	if not ("speed" in player):
		return
	if not player.has_meta(META_ADRENALINE_BASE):
		player.set_meta(META_ADRENALINE_BASE, float(player.speed))
		player.speed = float(player.speed) * ADRENALINE_SPEED_MULT
	var until: int = Time.get_ticks_msec() + int(ADRENALINE_TIME * 1000.0)
	player.set_meta(META_ADRENALINE_UNTIL, until)
	var timer: SceneTreeTimer = player.get_tree().create_timer(ADRENALINE_TIME)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(player) or int(player.get_meta(META_ADRENALINE_UNTIL, 0)) > until:
			return
		if player.has_meta(META_ADRENALINE_BASE):
			player.speed = float(player.get_meta(META_ADRENALINE_BASE))
			player.remove_meta(META_ADRENALINE_BASE)
	)


static func _sfx(node: Node, key: String) -> void:
	var am: Node = node.get_node_or_null("/root/AudioManager") if node.is_inside_tree() else null
	if am and am.has_method("play_sfx"):
		am.play_sfx(key, -2.0)
