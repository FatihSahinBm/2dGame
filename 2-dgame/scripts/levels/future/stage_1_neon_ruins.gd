class_name FutureStage1NeonRuins
extends FutureLevelBase

## res://scripts/levels/future/stage_1_neon_ruins.gd
## Bölüm 5 — Sekans 1: Neon Enkazı ve Gökdelen Yıkıntıları (Epic 2D-158).
## - Bölüm 4 sonundaki zaman yırtığından neon yağmuruna düşüş; kılıcın çığlığı.
## - Uzun çatı geçişleri: lazer tarama tuzakları (siper blokları / Kan Sisi), lazer kapıları,
##   çöken gökdelen köprüleri, neon devriye androidleri, siber böcekler ve mekanik tazılar.
## - Yeraltı metro sığınağı: direniş öncüleri — Son İnsanlık Sığınağı (A) ilk ahlaki seçim:
##   tahliye kapsülü (Kefaret) / enerji sömürüsü (+20) / öldürme (+12).

@onready var rift: DimensionalTimeRift = get_node_or_null("DimensionalTimeRift") as DimensionalTimeRift
@onready var shelter_trigger: Area2D = get_node_or_null("ShelterTrigger") as Area2D

var _laser_hint_shown: bool = false
var _shelter_intro_done: bool = false


func _level_ready() -> void:
	ensure_quest_started(SHELTER_QUEST)
	if rift and player:
		rift.spawn_completed.connect(_on_player_landed, CONNECT_ONE_SHOT)
		rift.play_player_emerge_sequence(player)
	else:
		_on_player_landed()
	for trap: Node in find_children("*", "FutureLaserTrap", true, false):
		(trap as FutureLaserTrap).fired.connect(_on_laser_fired)
	for gate: Node in find_children("*", "LaserGate", true, false):
		(gate as LaserGate).player_burned.connect(func(_d: int) -> void: _show_laser_hint())
	connect_rescue_spots("fut_survivor_plea")
	if shelter_trigger:
		shelter_trigger.body_entered.connect(_on_shelter_entered)


func _on_player_landed() -> void:
	sword_scream()
	play_story_once(["fut_arrival"] as Array[String], 0.6, player)


func _on_laser_fired(_dir: int, _range: float) -> void:
	if player and is_inside_tree():
		var nearest: float = INF
		for trap: Node in find_children("*", "FutureLaserTrap", true, false):
			nearest = minf(nearest, (trap as Node2D).global_position.distance_to(player.global_position))
		if nearest < 520.0:
			_show_laser_hint()


func _show_laser_hint() -> void:
	if _laser_hint_shown:
		return
	_laser_hint_shown = true
	play_story_once(["fut_laser_scan_hint"] as Array[String], 0.05, player)


func _on_shelter_entered(body: Node2D) -> void:
	if body != player or _shelter_intro_done:
		return
	_shelter_intro_done = true
	play_story_once(["fut_shelter_intro"] as Array[String], 0.1, player)


func _on_rescue_resolved(_spot: FutureRescueSpot, _outcome: String) -> void:
	update_shelter_quest()


## Sığınak (A) aşaması: tüm direnişçiler kurtarıldıysa ilerler; biri bile sömürülür/öldürülürse
## yan görev başarısız olur (Son İnsanlık Sığınağı).
func update_shelter_quest() -> void:
	var spots: Array[FutureRescueSpot] = get_rescue_spots()
	var saved: int = ChapterState.count_outcome(self, ChapterState.KIND_SURVIVOR, ChapterState.OUTCOME_FREED)
	var unresolved: int = spots.filter(func(s: FutureRescueSpot) -> bool: return not s.is_resolved()).size()
	if saved >= spots.size() and spots.size() > 0:
		advance_quest("save_survivors", SHELTER_QUEST)
	elif unresolved == 0:
		fail_quest(SHELTER_QUEST)


func _on_exit_started() -> void:
	advance_quest("cross_neon_ruins")


func get_exit_story_key() -> String:
	return "fut_ruins_exit"
