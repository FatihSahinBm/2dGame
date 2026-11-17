class_name FutureRescueSpot
extends EgyptInteractable

## res://scripts/objects/future/future_rescue_spot.gd
## Son İnsanlık Sığınağı ahlaki seçim noktası (Epic 2D-158): metroda yaralı direnişçi
## ("survivor") veya Veri Kalesi'nde mühendis ("engineer"). Bağlı muhafızlar ölene kadar
## etkileşim kapalıdır. [E] ile konuşulur; seviye seçim diyaloğunu açar ve rescue() (Kefaret,
## tahliye kapsülü + eşya ödülü) ya da exploit() (GameState.register_ally_sacrifice: +20
## Yozlaşma, kurban sayacı, can) çağırır. NPC'yi kılıçla öldürmek EgyptSlave üzerinden
## register_ally_kill (+12 Yozlaşma) işler. Sonuç FutureChapterState'e kalıcı yazılır.

signal resolved(spot: FutureRescueSpot, outcome: String)

const ChapterState = preload("res://scripts/components/future_chapter_state.gd")
const Inventory = preload("res://scripts/components/future_inventory.gd")
const FutureFx = preload("res://scripts/effects/future_fx.gd")

@export_enum("survivor", "engineer") var kind: String = "survivor"
@export var guard_paths: Array[NodePath] = []
@export var reward_item: String = "nano_repair_kit"
@export var reward_amount: int = 2
## Seviyedeki benzersiz kimlik (boşsa NPC'nin slave_id'si); kalıcı sonuç bu kimlikle saklanır
@export var spot_id: String = ""

var outcome: String = ""
var _npc: EgyptSlave = null
var _capsule: Sprite2D = null


func _interactable_ready() -> void:
	prompt_key = "PROMPT_FUT_SURVIVOR" if kind == ChapterState.KIND_SURVIVOR else "PROMPT_FUT_ENGINEER"
	_capsule = get_node_or_null("Capsule") as Sprite2D
	_npc = get_node_or_null("Npc") as EgyptSlave
	if _npc:
		if not spot_id.is_empty():
			_npc.slave_id = spot_id
		_npc.killed.connect(_on_npc_killed)
	var saved: String = ChapterState.get_outcome(self, kind, get_spot_id())
	if not saved.is_empty():
		outcome = saved
		if _npc:
			_npc.apply_resolved(saved)
		_set_capsule_launched(saved == ChapterState.OUTCOME_FREED)
	set_interaction_enabled(false)


func _process(_delta: float) -> void:
	var can_talk: bool = not is_resolved() and are_guards_defeated()
	if can_talk != interaction_enabled:
		set_interaction_enabled(can_talk)


func get_spot_id() -> String:
	if not spot_id.is_empty():
		return spot_id
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


## Kefaret: tahliye kapsülüne taşınır, kapsül fırlar; eşya ödülü + Direniş Künyesi
func rescue() -> void:
	if is_resolved():
		return
	if _npc:
		_npc.set_freed()
	if not reward_item.is_empty() and reward_amount > 0:
		Inventory.add(self, reward_item, reward_amount)
	Inventory.add(self, "resistance_tag", 1 - mini(1, Inventory.count(self, "resistance_tag")))
	FutureFx.sfx(self, "checkpoint_activated", global_position)
	_set_capsule_launched(true)
	_resolve(ChapterState.OUTCOME_FREED)


## Yozlaşma: enerji/güç hücresi sömürülür (+20 Yozlaşma, kurban sayacı, can)
func exploit(target: Node2D) -> int:
	if is_resolved():
		return 0
	var heal: int = 0
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and gs.has_method("register_ally_sacrifice"):
		heal = int(gs.register_ally_sacrifice("future_" + kind))
	if is_instance_valid(target) and target.has_method("heal"):
		target.heal(heal)
	FutureFx.sfx(self, "soul_drain", global_position)
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


## Tahliye kapsülü kurtarmada yukarı fırlar ve kaybolur
func _set_capsule_launched(launched: bool) -> void:
	if not _capsule or not launched:
		return
	if not is_inside_tree() or not _capsule.visible:
		_capsule.visible = false
		return
	var tw: Tween = create_tween()
	tw.tween_property(_capsule, "position:y", _capsule.position.y - 260.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_capsule, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func() -> void: _capsule.visible = false)
