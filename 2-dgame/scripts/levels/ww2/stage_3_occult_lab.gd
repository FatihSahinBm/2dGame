class_name Ww2Stage3OccultLab
extends Ww2LevelBase

## res://scripts/levels/ww2/stage_3_occult_lab.gd
## Bölüm 4 — Sahne 3: Yeraltı Gizli Silah Laboratuvarı (Epic 2D-144).
## - Zehirli gaz koridoru + güç rölesi bulmacası (doğru sıra → vantilatör, gaz kapanır, kapı açılır).
## - Kafesteki Denekler: esirleri kurtar (Kefaret + arka kapı kartı) / reaktörde feda et (+20).
## - Easter egg: gizli duvarın ardında Geleceğin Damgası Planları; okült mühür (Kalp Rezonansı).
## - Mini-Boss 2: Okült Başhekim (tüpler kırılmadan kalkanı inmez) + Başarısız Deney
##   (yere vurdukça arena daralır). İkisi de ölünce çıkış açılır. Karşılaşma lab_boss bileşenindedir.

const SIDE_QUEST: String = "ww2_caged_subjects"
const LabBoss = preload("res://scripts/levels/ww2/stage_3_lab_boss.gd")

@onready var lab_door: LabDoor = get_node_or_null("LabDoor") as LabDoor
@onready var gas_trigger: Area2D = get_node_or_null("GasHintTrigger") as Area2D

var boss: RefCounted = null
var _pending_target: Node = null


func _level_ready() -> void:
	ensure_quest_started(SIDE_QUEST)
	play_story_once(["ww2_lab_intro"] as Array[String], 0.8, player)
	if gas_trigger:
		gas_trigger.body_entered.connect(func(b: Node2D) -> void:
			if b == player:
				play_story_once(["ww2_gas_hint"] as Array[String], 0.05, player)
				set_tutorial_keys(PackedStringArray(["WW2_RELAY_TITLE", "WW2_RELAY_SUB", "WW2_RELAY_DESC"]))
		)
	for relay: PowerRelay in get_relays():
		relay.toggled.connect(func(_r: PowerRelay, _on: bool) -> void: check_relays())
	if relays_solved():
		_apply_relays_solved(true)
	if dialogue_box and dialogue_box.has_signal("choice_selected"):
		dialogue_box.choice_selected.connect(_on_choice_selected)
	for spot: Node in find_children("*", "RescueSpot", true, false):
		(spot as RescueSpot).interaction_requested.connect(_on_spot_interaction)
		(spot as RescueSpot).resolved.connect(_on_spot_resolved)
	for relic: Node in find_children("*", "LoreRelic", true, false):
		(relic as LoreRelic).story_requested.connect(func(key: String) -> void: play_story([key] as Array[String]))
	for seal: Node in find_children("*", "OccultSeal", true, false):
		(seal as OccultSeal).seal_result.connect(func(opened: bool) -> void:
			play_story(["ww2_occult_seal_open" if opened else "ww2_occult_seal_locked"] as Array[String]))
	boss = LabBoss.new(self)


# ---------------------------------------------------------------------------
# Röle bulmacası
# ---------------------------------------------------------------------------
func get_relays() -> Array[PowerRelay]:
	var relays: Array[PowerRelay] = []
	for n: Node in find_children("*", "PowerRelay", true, false):
		relays.append(n as PowerRelay)
	return relays


func relays_solved() -> bool:
	return LevelStory.has_event(self, "ww2_relays_solved")


func check_relays() -> bool:
	if relays_solved():
		return true
	for relay: PowerRelay in get_relays():
		if not relay.is_correct():
			return false
	LevelStory.set_event(self, "ww2_relays_solved")
	_apply_relays_solved(false)
	return true


func _apply_relays_solved(instant: bool) -> void:
	for relay: PowerRelay in get_relays():
		relay.lock()
	for gas: Node in find_children("*", "ToxicGas", true, false):
		if (gas as ToxicGas).lifetime <= 0.0:
			(gas as ToxicGas).set_active(false)
	if lab_door:
		lab_door.open()
	if not instant:
		play_sfx("relay_switch")
		play_story(["ww2_relay_puzzle_solved"] as Array[String], lab_door)


# ---------------------------------------------------------------------------
# Kafesteki Denekler (ahlaki seçim)
# ---------------------------------------------------------------------------
func _on_spot_interaction(spot: Node) -> void:
	_pending_target = spot
	if not play_story(["ww2_prisoner_plea"] as Array[String], (spot as RescueSpot).get_npc()):
		_pending_target = null


func _on_choice_selected(action: String) -> void:
	var target: Node = _pending_target
	_pending_target = null
	apply_choice(action, target)


func apply_choice(action: String, target: Node) -> void:
	if not (target is RescueSpot):
		return
	match action:
		"free_prisoner":
			(target as RescueSpot).rescue()
		"sacrifice_prisoner":
			(target as RescueSpot).exploit(player)


func _on_spot_resolved(spot: RescueSpot, outcome: String) -> void:
	match outcome:
		ChapterState.OUTCOME_FREED:
			queue_story("ww2_prisoner_freed")
			float_text(tr("WW2_FLOAT_PRISONER_FREED"), spot.global_position, Color(0.5, 1.0, 0.6))
		ChapterState.OUTCOME_DRAINED:
			queue_story("ww2_prisoner_sacrificed")
			float_text(tr("WW2_FLOAT_REACTOR_SACRIFICE"), spot.global_position, Color(1.0, 0.35, 0.35))
		ChapterState.OUTCOME_KILLED:
			queue_story("ww2_prisoner_killed")
			float_text(tr("WW2_FLOAT_INNOCENT_KILLED"), spot.global_position, Color(1.0, 0.3, 0.3))
	var spots: Array[Node] = find_children("*", "RescueSpot", true, false)
	var freed: int = ChapterState.count_outcome(self, ChapterState.KIND_PRISONER, ChapterState.OUTCOME_FREED)
	var unresolved: int = 0
	for s: Node in spots:
		if not (s as RescueSpot).is_resolved():
			unresolved += 1
	if freed >= spots.size():
		advance_quest("free_prisoners", SIDE_QUEST)
	elif unresolved == 0:
		fail_quest(SIDE_QUEST)


# ---------------------------------------------------------------------------
# Çıkış
# ---------------------------------------------------------------------------
func can_exit() -> bool:
	return boss == null or boss.is_cleared()


func _on_exit_blocked() -> void:
	set_tutorial_keys(PackedStringArray(["WW2_EXIT_LAB_TITLE", "WW2_EXIT_LAB_SUB", "WW2_EXIT_LAB_DESC"]))


func get_exit_story_key() -> String:
	return "ww2_lab_exit_corrupted" if ChapterState.has_harmed_innocents(self) else "ww2_lab_exit_redemption"


func _on_exit_started() -> void:
	advance_quest("infiltrate_lab")
