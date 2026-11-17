class_name FutureStage3ResistanceCitadel
extends FutureLevelBase

## res://scripts/levels/future/stage_3_resistance_citadel.gd
## Bölüm 5 — Sekans 3: Direniş Yeraltı Ağı ve Veri Kalesi (Epic 2D-158).
## - Güç yönlendirme / EMP terminal hack bulmacaları (sıralı terminaller lazer kapılarını söndürür),
##   zaman yavaşlatma odaları ve heart_resonance ile açılan zaman mühürlü kapı.
## - Son İnsanlık Sığınağı (B): mühendisleri ve sivil kapsülleri tahliye et (Kefaret) / güç
##   hücrelerini sömür (+20) / öldür (+12).
## - Siber-Ağ Kesintisi: 3 yardımcı sunucu düğümünü imha et (AI Lord desteği %50 azalır).
## - Easter egg'ler: zaman mühürlü odada Kılıç Damgasının Kökeni hologramı; gizli sığınakta
##   Yamalı Zaman Radyosu (bonus ödül).
## - Veri çekirdeği odasında Mini-Boss 2 AEGIS-09 (çekirdek + ikiz dron); yenilince Erişim Çipi.

const OUTAGE_QUEST: String = "future_network_outage"
const AEGIS_EVENT: String = "fut_aegis_defeated"

@onready var aegis: AegisCore = get_node_or_null("AegisCore") as AegisCore
@onready var aegis_trigger: Area2D = get_node_or_null("AegisTrigger") as Area2D
@onready var slow_room_trigger: Area2D = get_node_or_null("SlowRoomTrigger") as Area2D

var aegis_started: bool = false
var boss_bar: EgyptBossBar = null
var _hints: Dictionary = {}


func _level_ready() -> void:
	ensure_quest_started(SHELTER_QUEST)
	ensure_quest_started(OUTAGE_QUEST)
	advance_quest("breach_citadel")
	play_story_once(["fut_citadel_intro"] as Array[String], 0.6, player)
	connect_rescue_spots("fut_engineer_plea")
	for terminal: Node in find_children("*", "EmpTerminal", true, false):
		var t: EmpTerminal = terminal as EmpTerminal
		t.hacked.connect(func(_t: EmpTerminal) -> void: queue_story("fut_terminal_hacked"))
		t.interaction_requested.connect(func(_s: Node) -> void:
			if not t.prerequisites_met():
				_hint("fut_emp_terminal_hint")
		)
	for node: Node in find_children("*", "ServerNode", true, false):
		(node as ServerNode).destroyed.connect(_on_node_destroyed)
	for door: Node in find_children("*", "FutureResonanceDoor", true, false):
		(door as FutureResonanceDoor).seal_result.connect(func(opened: bool) -> void:
			play_story([("fut_resonance_door_open" if opened else "fut_resonance_door_locked")] as Array[String])
		)
	for lore: Node in find_children("*", "FutureLoreTerminal", true, false):
		(lore as FutureLoreTerminal).story_requested.connect(func(key: String) -> void:
			if not key.is_empty():
				play_story([key] as Array[String])
		)
	if slow_room_trigger:
		slow_room_trigger.body_entered.connect(func(b: Node2D) -> void:
			if b == player:
				_hint("fut_slow_room_hint")
		)
	_refresh_outage_quest()
	if aegis:
		aegis.defeated.connect(_on_aegis_defeated)
		aegis.shield_state_changed.connect(_on_aegis_shield)
		aegis.damage_blocked.connect(func(_r: String) -> void: _hint("fut_aegis_shield_hint"))
		if is_aegis_defeated():
			for d: Node in get_tree().get_nodes_in_group("aegis_drones"):
				d.queue_free()
			aegis.queue_free()
			aegis = null
	if aegis_trigger:
		aegis_trigger.body_entered.connect(_on_aegis_trigger)


func _hint(key: String) -> void:
	if _hints.has(key):
		return
	_hints[key] = true
	play_story_once([key] as Array[String], 0.05, player)


# ---------------------------------------------------------------------------
# Son İnsanlık Sığınağı (B) ve Siber-Ağ Kesintisi
# ---------------------------------------------------------------------------
func _on_rescue_resolved(_spot: FutureRescueSpot, _outcome: String) -> void:
	var spots: Array[FutureRescueSpot] = get_rescue_spots()
	var saved: int = ChapterState.count_outcome(self, ChapterState.KIND_ENGINEER, ChapterState.OUTCOME_FREED)
	var unresolved: int = spots.filter(func(s: FutureRescueSpot) -> bool: return not s.is_resolved()).size()
	if saved >= spots.size() and spots.size() > 0:
		advance_quest("evacuate_engineers", SHELTER_QUEST)
	elif unresolved == 0:
		fail_quest(SHELTER_QUEST)


func _on_node_destroyed(_node_id: String, total: int) -> void:
	float_text(tr("FUT_FLOAT_NODE_DOWN") % [total, ChapterState.NODES_REQUIRED],
		player.global_position if player else Vector2.ZERO, Color(1.0, 0.5, 0.9))
	if total >= ChapterState.NODES_REQUIRED:
		queue_story("fut_network_outage_done", 0.4)
	else:
		queue_story("fut_server_node_destroyed")
	_refresh_outage_quest()


func _refresh_outage_quest() -> void:
	if ChapterState.is_network_down(self):
		advance_quest("destroy_nodes", OUTAGE_QUEST)


# ---------------------------------------------------------------------------
# Mini-Boss 2: AEGIS-09
# ---------------------------------------------------------------------------
func is_aegis_defeated() -> bool:
	return LevelStory.has_event(self, AEGIS_EVENT)


func _on_aegis_trigger(body: Node2D) -> void:
	if body == player and not aegis_started and aegis:
		start_aegis_fight()


func start_aegis_fight() -> void:
	if aegis_started or not aegis:
		return
	aegis_started = true
	boss_bar = make_boss_bar("FUT_AEGIS_NAME", aegis.max_health)
	aegis.health_changed.connect(boss_bar.set_health)
	var am: Node = audio()
	if am and am.has_method("on_boss_started"):
		am.on_boss_started("ai_lord", 1)
	if play_story(["fut_aegis_intro"] as Array[String], aegis):
		dialogue_box.dialogue_completed.connect(aegis.on_cinematic_ended, CONNECT_ONE_SHOT)
	else:
		aegis.on_cinematic_ended()


func _on_aegis_shield(shield_up: bool) -> void:
	if not shield_up and aegis_started:
		_hint("fut_aegis_shield_down")


func _on_aegis_defeated() -> void:
	LevelStory.set_event(self, AEGIS_EVENT)
	advance_quest("defeat_aegis")
	Inventory.add(self, "core_access_chip", 1 - mini(1, Inventory.count(self, "core_access_chip")))
	var am: Node = audio()
	if am and am.has_method("on_boss_defeated"):
		am.on_boss_defeated()
	play_story(["fut_aegis_defeated"] as Array[String], aegis)


func can_exit() -> bool:
	return aegis == null or aegis.is_dead or is_aegis_defeated()


func _on_exit_blocked() -> void:
	set_tutorial_keys(PackedStringArray(["FUT_EXIT_AEGIS_TITLE", "FUT_EXIT_AEGIS_SUB", "FUT_EXIT_AEGIS_DESC"]))


func get_exit_story_key() -> String:
	var corrupted: bool = LevelStory.get_alignment(self) == "god_king" or ChapterState.has_harmed_innocents(self)
	return "fut_citadel_exit_corrupted" if corrupted else "fut_citadel_exit_redemption"
