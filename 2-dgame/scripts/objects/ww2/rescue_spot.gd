class_name RescueSpot
extends EgyptInteractable

## res://scripts/objects/ww2/rescue_spot.gd
## Yaralı asker (siper) veya esir hücresi (laboratuvar) — Epic 2D-144 ahlaki seçim noktası.
## Bağlı muhafızlar ölene kadar etkileşim kapalıdır. [E] ile konuşulur; seviye seçim
## diyaloğunu açar ve rescue() (Kefaret) ya da exploit() (+20 Yozlaşma, can) çağırır.
## NPC'yi kılıçla öldürmek EgyptSlave üzerinden register_ally_kill (+12 Yozlaşma) işler.
## Sonuç Ww2ChapterState'e kalıcı yazılır; kurtarmanın eşya ödülü Ww2Inventory'ye eklenir.

signal resolved(spot: RescueSpot, outcome: String)

const ChapterState = preload("res://scripts/components/ww2_chapter_state.gd")
const Inventory = preload("res://scripts/components/ww2_inventory.gd")
const TEX_CELL_CLOSED: Texture2D = preload("res://assets/objects/ww2/prisoner_cell_closed.png")
const TEX_CELL_OPEN: Texture2D = preload("res://assets/objects/ww2/prisoner_cell_open.png")

@export_enum("wounded", "prisoner") var kind: String = "wounded"
@export var guard_paths: Array[NodePath] = []
@export var reward_item: String = "field_bandage"
@export var reward_amount: int = 2

var outcome: String = ""
var _npc: EgyptSlave = null
var _cell: Sprite2D = null


func _interactable_ready() -> void:
	prompt_key = "PROMPT_WW2_WOUNDED" if kind == ChapterState.KIND_WOUNDED else "PROMPT_WW2_PRISONER"
	_cell = get_node_or_null("Cell") as Sprite2D
	_npc = get_node_or_null("Npc") as EgyptSlave
	if _npc:
		_npc.killed.connect(_on_npc_killed)
	var saved: String = ChapterState.get_outcome(self, kind, get_spot_id())
	if not saved.is_empty():
		outcome = saved
		if _npc:
			_npc.apply_resolved(saved)
		_set_open(true)
	set_interaction_enabled(false)


func _process(_delta: float) -> void:
	var can_talk: bool = not is_resolved() and are_guards_defeated()
	if can_talk != interaction_enabled:
		set_interaction_enabled(can_talk)


func get_spot_id() -> String:
	return _npc.slave_id if _npc else str(name)


func get_npc() -> EgyptSlave:
	return _npc


func is_resolved() -> bool:
	return not outcome.is_empty()


func are_guards_defeated() -> bool:
	for path: NodePath in guard_paths:
		var guard: Node = get_node_or_null(path)
		if is_instance_valid(guard) and not ("is_dead" in guard and guard.is_dead):
			return false
	return true


## Kefaret: yaralı sığınağa taşınır / esir serbest kalır, eşya ödülü verilir
func rescue() -> void:
	if is_resolved():
		return
	_set_open(true)
	_play("cage_open" if kind == ChapterState.KIND_PRISONER else "checkpoint_activated")
	if _npc:
		_npc.set_freed()
	if not reward_item.is_empty() and reward_amount > 0:
		Inventory.add(self, reward_item, reward_amount)
	if kind == ChapterState.KIND_PRISONER:
		Inventory.add(self, "bunker_keycard", 1 - mini(1, Inventory.count(self, "bunker_keycard")))
	_resolve(ChapterState.OUTCOME_FREED)


## Yozlaşma: yaşam gücü sömürülür / esir reaktörde feda edilir (+20 Yozlaşma, can)
func exploit(target: Node2D) -> int:
	if is_resolved():
		return 0
	var heal: int = 0
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and gs.has_method("register_ally_sacrifice"):
		heal = int(gs.register_ally_sacrifice("ww2_" + kind))
	if is_instance_valid(target) and target.has_method("heal"):
		target.heal(heal)
	_play("soul_drain")
	if _npc:
		_npc.set_drained()
	_resolve(ChapterState.OUTCOME_DRAINED)
	return heal


func _on_npc_killed(_n: EgyptSlave) -> void:
	if not is_resolved():
		_resolve(ChapterState.OUTCOME_KILLED)


func _resolve(result: String) -> void:
	outcome = result
	set_interaction_enabled(false)
	ChapterState.record_outcome(self, kind, get_spot_id(), result)
	resolved.emit(self, result)


func _set_open(is_open: bool) -> void:
	if _cell:
		_cell.texture = TEX_CELL_OPEN if is_open else TEX_CELL_CLOSED


func _play(key: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d(key, global_position, null, -2.0, 900.0)
