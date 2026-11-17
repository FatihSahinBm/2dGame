class_name SlaveCage
extends EgyptInteractable

## res://scripts/objects/egypt/slave_cage.gd
## Muhafız kuşatması altındaki köle kafesi (Epic 2D-143). Kafesin muhafızları ölene kadar
## etkileşim kapalıdır. Ardından [E] ile köleyle konuşulur; seviye seçim diyaloğunu açar ve
## free_slave() (Kefaret) ya da drain_slave() (+20 Yozlaşma) çağırır. Köleyi kılıçla
## öldürmek EgyptSlave üzerinden +12 Yozlaşma işler. Sonuç kalıcı bayrak olarak kaydedilir.

signal resolved(cage: SlaveCage, outcome: String)

const ChapterState = preload("res://scripts/components/egypt_chapter_state.gd")
const TEX_CLOSED: Texture2D = preload("res://assets/objects/egypt/slave_cage_closed.png")
const TEX_OPEN: Texture2D = preload("res://assets/objects/egypt/slave_cage_open.png")

@export var guard_paths: Array[NodePath] = []

var outcome: String = ""
var _slave: EgyptSlave = null
var _sprite: Sprite2D = null


func _interactable_ready() -> void:
	prompt_key = "PROMPT_EGYPT_SLAVE"
	_sprite = get_node_or_null("Sprite") as Sprite2D
	_slave = get_node_or_null("Slave") as EgyptSlave
	if _slave:
		_slave.killed.connect(_on_slave_killed)
	var saved: String = ChapterState.get_slave_outcome(self, get_slave_id())
	if not saved.is_empty():
		outcome = saved
		if _slave:
			_slave.apply_resolved(saved)
		_set_open(true)
	set_interaction_enabled(false)


func _process(_delta: float) -> void:
	var can_talk: bool = is_resolved() == false and are_guards_defeated()
	if can_talk != interaction_enabled:
		set_interaction_enabled(can_talk)


func get_slave_id() -> String:
	return _slave.slave_id if _slave else str(name)


func get_slave() -> EgyptSlave:
	return _slave


func is_resolved() -> bool:
	return not outcome.is_empty()


func are_guards_defeated() -> bool:
	for path: NodePath in guard_paths:
		var guard: Node = get_node_or_null(path)
		if is_instance_valid(guard) and not ("is_dead" in guard and guard.is_dead):
			return false
	return true


func free_slave() -> void:
	if is_resolved():
		return
	_set_open(true)
	_play("cage_open")
	if _slave:
		_slave.set_freed()
	_resolve(ChapterState.OUTCOME_FREED)


func drain_slave(target: Node2D) -> int:
	if is_resolved():
		return 0
	var heal: int = 0
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and gs.has_method("register_ally_sacrifice"):
		heal = int(gs.register_ally_sacrifice("slave"))
	if is_instance_valid(target) and target.has_method("heal"):
		target.heal(heal)
	_play("soul_drain")
	if _slave:
		_slave.set_drained()
	_resolve(ChapterState.OUTCOME_DRAINED)
	return heal


func _on_slave_killed(_s: EgyptSlave) -> void:
	if not is_resolved():
		_resolve(ChapterState.OUTCOME_KILLED)


func _resolve(result: String) -> void:
	outcome = result
	set_interaction_enabled(false)
	ChapterState.record_slave_outcome(self, get_slave_id(), result)
	resolved.emit(self, result)


func _set_open(is_open: bool) -> void:
	if _sprite:
		_sprite.texture = TEX_OPEN if is_open else TEX_CLOSED


func _play(key: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d(key, global_position, null, -2.0, 900.0)
