class_name Ww2Stage1BombedTrenches
extends Ww2LevelBase

## res://scripts/levels/ww2/stage_1_bombed_trenches.gd
## Bölüm 4 — Sahne 1: Bombalanmış Siperler (Epic 2D-144).
## - Bölüm 3 çıkışındaki zaman yırtığından düşüş; kılıcın çığlığı.
## - Zamanlanmış topçu barajı + beton sığınaklarda siper alma; mayın ve dikenli tel engelleri.
## - Siperdeki Yaralılar: iki yaralı askeri kurtar (Kefaret) / sömür (+20) / öldür (+12).
## - Mini-Boss 1 (Alev Makineli Ağır Siper Subayı) kapı karşılaşması; yenilince çıkış açılır.

const SIDE_QUEST: String = "ww2_wounded_in_trench"
const BossBarScript = preload("res://scripts/ui/egypt_boss_bar.gd")

@onready var rift: DimensionalTimeRift = get_node_or_null("DimensionalTimeRift") as DimensionalTimeRift
@onready var barrage: ArtilleryBarrage = get_node_or_null("ArtilleryBarrage") as ArtilleryBarrage
@onready var officer: TrenchOfficer = get_node_or_null("TrenchOfficer") as TrenchOfficer
@onready var officer_trigger: Area2D = get_node_or_null("OfficerTrigger") as Area2D

var officer_started: bool = false
var boss_bar: EgyptBossBar = null
var _pending_target: Node = null
var _wire_hint_shown: bool = false


func _level_ready() -> void:
	ensure_quest_started(SIDE_QUEST)
	if rift and player:
		rift.spawn_completed.connect(_on_player_landed, CONNECT_ONE_SHOT)
		rift.play_player_emerge_sequence(player)
	else:
		_on_player_landed()
	if barrage:
		barrage.salvo_fired.connect(_on_first_salvo, CONNECT_ONE_SHOT)
	for wire: Node in find_children("*", "BarbedWire", true, false):
		(wire as BarbedWire).player_snagged.connect(_on_wire_snag)
	if dialogue_box and dialogue_box.has_signal("choice_selected"):
		dialogue_box.choice_selected.connect(_on_choice_selected)
	for spot: RescueSpot in get_spots():
		spot.interaction_requested.connect(_on_spot_interaction)
		spot.resolved.connect(_on_spot_resolved)
	if officer:
		officer.defeated.connect(_on_officer_defeated)
		officer.armor_blocked.connect(_on_armor_blocked)
		officer.tank_burst.connect(func() -> void: play_story(["ww2_officer_tank_burst"] as Array[String]))
		if is_officer_defeated():
			officer.queue_free()
			officer = null
	if officer_trigger:
		officer_trigger.body_entered.connect(_on_officer_trigger)


func _on_player_landed() -> void:
	sword_scream()
	play_story_once(["ww2_arrival"] as Array[String], 0.6, player)


func _on_first_salvo(_count: int) -> void:
	play_story_once(["ww2_barrage_hint"] as Array[String], 0.05, player)


func _on_wire_snag() -> void:
	if not _wire_hint_shown:
		_wire_hint_shown = true
		play_story_once(["ww2_wire_hint"] as Array[String], 0.05, player)


func get_spots() -> Array[RescueSpot]:
	var spots: Array[RescueSpot] = []
	for n: Node in find_children("*", "RescueSpot", true, false):
		spots.append(n as RescueSpot)
	return spots


func unresolved_spots() -> int:
	var count: int = 0
	for spot: RescueSpot in get_spots():
		if not spot.is_resolved():
			count += 1
	return count


# ---------------------------------------------------------------------------
# Siperdeki Yaralılar (ahlaki seçim)
# ---------------------------------------------------------------------------
func _on_spot_interaction(spot: Node) -> void:
	_pending_target = spot
	if not play_story(["ww2_wounded_plea"] as Array[String], (spot as RescueSpot).get_npc()):
		_pending_target = null


func _on_choice_selected(action: String) -> void:
	var target: Node = _pending_target
	_pending_target = null
	apply_choice(action, target)


## Seçimin oyun durumuna etkisi (testler de doğrudan çağırır)
func apply_choice(action: String, target: Node) -> void:
	if not (target is RescueSpot):
		return
	match action:
		"rescue_wounded":
			(target as RescueSpot).rescue()
		"exploit_wounded":
			(target as RescueSpot).exploit(player)


func _on_spot_resolved(spot: RescueSpot, outcome: String) -> void:
	match outcome:
		ChapterState.OUTCOME_FREED:
			queue_story("ww2_wounded_rescued")
			float_text(tr("WW2_FLOAT_WOUNDED_SAVED"), spot.global_position, Color(0.5, 1.0, 0.6))
		ChapterState.OUTCOME_DRAINED:
			queue_story("ww2_wounded_exploited")
			float_text(tr("WW2_FLOAT_LIFE_DRAINED"), spot.global_position, Color(1.0, 0.4, 0.4))
		ChapterState.OUTCOME_KILLED:
			queue_story("ww2_wounded_killed")
			float_text(tr("WW2_FLOAT_INNOCENT_KILLED"), spot.global_position, Color(1.0, 0.3, 0.3))
	_update_side_quest()


func _update_side_quest() -> void:
	var saved: int = ChapterState.count_outcome(self, ChapterState.KIND_WOUNDED, ChapterState.OUTCOME_FREED)
	if saved >= get_spots().size():
		advance_quest("save_wounded", SIDE_QUEST)
	elif unresolved_spots() == 0:
		fail_quest(SIDE_QUEST)


# ---------------------------------------------------------------------------
# Mini-Boss 1
# ---------------------------------------------------------------------------
func is_officer_defeated() -> bool:
	return LevelStory.has_event(self, "ww2_officer_defeated")


func _on_officer_trigger(body: Node2D) -> void:
	if body != player or officer_started or not officer:
		return
	start_officer_fight()


func start_officer_fight() -> void:
	if officer_started or not officer:
		return
	officer_started = true
	if barrage:
		barrage.active = false
	boss_bar = BossBarScript.new() as EgyptBossBar
	add_child(boss_bar)
	boss_bar.setup("WW2_OFFICER_NAME", officer.max_health)
	officer.health_changed.connect(boss_bar.set_health)
	var am: Node = audio()
	if am and am.has_method("on_boss_started"):
		am.on_boss_started("commander", 1)
	if play_story(["ww2_officer_intro"] as Array[String], officer):
		dialogue_box.dialogue_completed.connect(officer.on_cinematic_ended, CONNECT_ONE_SHOT)
	else:
		officer.on_cinematic_ended()


func _on_armor_blocked() -> void:
	if officer and officer.blocked_hits == 3:
		play_story_once(["ww2_officer_tank_hint"] as Array[String], 0.05, officer)


func _on_officer_defeated() -> void:
	LevelStory.set_event(self, "ww2_officer_defeated")
	var am: Node = audio()
	if am and am.has_method("on_boss_defeated"):
		am.on_boss_defeated()
	play_story(["ww2_officer_defeated"] as Array[String], officer)
	set_tutorial_keys(PackedStringArray(["WW2_TUT_01_DONE_TITLE", "WW2_TUT_01_DONE_SUB", "WW2_TUT_01_DONE_DESC"]))


func can_exit() -> bool:
	return officer == null or officer.is_dead or is_officer_defeated()


func _on_exit_blocked() -> void:
	set_tutorial_keys(PackedStringArray(["WW2_EXIT_OFFICER_TITLE", "WW2_EXIT_OFFICER_SUB", "WW2_EXIT_OFFICER_DESC"]))


func _on_exit_started() -> void:
	advance_quest("cross_trenches")


func get_exit_story_key() -> String:
	return "ww2_trench_exit"
