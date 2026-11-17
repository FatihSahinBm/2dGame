class_name FutureStage4AiLordCitadel
extends FutureLevelBase

## res://scripts/levels/future/stage_4_ai_lord_citadel.gd
## Bölüm 5 — Sekans 4: AI Lord Ana Çekirdek Kulesi (Epic 2D-158).
## - Dikey tırmanış: dron dalgaları (tetik alanları), kırılan lazer köprüleri (CollapsingPlatform),
##   Kan Sisi Atılması ile geçilen sürekli lazer ızgaraları.
## - Çekirdek Taht Odası: 3 formlu AI Lord. Form 1 dron çağrısı ve Form 2 taret desteği
##   Siber-Ağ Kesintisi tamamlandıysa %50 azalır (FutureChapterState.support_factor).
## - Boss yenilince sekans 5'e (Kılıcın Kırılışı) geçilir; 5. Kalp Parçası orada sökülür.

const Spawner = preload("res://scripts/enemies/future/future_spawner.gd")
const Phases = preload("res://scripts/enemies/future/ai_lord_phases.gd")
const FORM_TAUNTS: Dictionary = { 2: "fut_ai_lord_form_2", 3: "fut_ai_lord_form_3" }
const BOSS_EVENT: String = "fut_ai_lord_defeated"

@onready var boss: AiLordBoss = get_node_or_null("AiLordBoss") as AiLordBoss
@onready var throne_trigger: Area2D = get_node_or_null("ThroneTrigger") as Area2D
@onready var drone_points: Node2D = get_node_or_null("DronePoints") as Node2D
@onready var arena_turrets: Node2D = get_node_or_null("ArenaTurrets") as Node2D

var dialogue_state: String = "none"
var boss_started: bool = false
var boss_defeated: bool = false
var boss_bar: EgyptBossBar = null
var minions: Array[Node2D] = []
var active_turrets: int = 0
var _hints: Dictionary = {}


func _level_ready() -> void:
	play_story_once(["fut_tower_intro"] as Array[String], 0.6, player)
	for gate: Node in find_children("*", "LaserGate", true, false):
		(gate as LaserGate).player_burned.connect(func(_d: int) -> void: _hint("fut_laser_grid_hint"))
	for wave: Node in find_children("WaveTrigger*", "Area2D", true, false):
		(wave as Area2D).body_entered.connect(_on_wave_trigger.bind(wave))
	set_turrets_active(0, false)
	if dialogue_box:
		dialogue_box.dialogue_completed.connect(_on_dialogue_completed)
	if boss:
		boss.form_changed.connect(_on_form_changed)
		boss.drones_requested.connect(spawn_drones)
		boss.turret_support_requested.connect(set_turrets_active)
		boss.boss_defeated.connect(_on_boss_defeated)
		if LevelStory.has_event(self, BOSS_EVENT):
			boss.queue_free()
			boss = null
	if throne_trigger:
		throne_trigger.body_entered.connect(_on_throne_entered)


func _hint(key: String) -> void:
	if _hints.has(key):
		return
	_hints[key] = true
	play_story_once([key] as Array[String], 0.05, player)


## Tırmanış dron dalgası: tetik alanının "kind"/"count" metasına göre (tek seferlik)
func _on_wave_trigger(body: Node2D, wave: Area2D) -> void:
	if body != player or wave.has_meta("fired"):
		return
	wave.set_meta("fired", true)
	var kind: String = str(wave.get_meta("kind", "chrono_drone"))
	var points: Array[Vector2] = Spawner.points_from(wave.get_node_or_null("Points"), int(wave.get_meta("count", 2)))
	minions.append_array(Spawner.spawn_wave(self, kind, points, -1))


func _on_throne_entered(body: Node2D) -> void:
	if body != player or boss_started or not boss:
		return
	start_boss_fight()


func start_boss_fight() -> void:
	if boss_started or not boss:
		return
	boss_started = true
	advance_quest("ascend_tower")
	boss_bar = make_boss_bar("FUT_BOSS_NAME", boss.max_health)
	boss.health_changed.connect(boss_bar.set_health)
	var corrupted: bool = LevelStory.get_alignment(self) == "god_king" or ChapterState.has_harmed_innocents(self)
	_play_state("intro", ["fut_ai_lord_taunt_corrupted" if corrupted else "fut_ai_lord_taunt"])


func _play_state(state: String, keys: Array) -> void:
	dialogue_state = state
	var typed: Array[String] = []
	for k: Variant in keys:
		typed.append(str(k))
	if not play_story(typed, boss if is_instance_valid(boss) else player):
		_on_dialogue_completed()


func _on_dialogue_completed() -> void:
	var finished: String = dialogue_state
	dialogue_state = "none"
	match finished:
		"intro":
			var am: Node = audio()
			if am and am.has_method("on_boss_started"):
				am.on_boss_started("ai_lord", 1)
			_resume_boss()
		"form":
			_resume_boss()


func _resume_boss() -> void:
	if boss and not boss_defeated:
		boss.on_cinematic_ended()


func _on_form_changed(new_form: int) -> void:
	if boss_bar:
		boss_bar.set_phase(new_form)
	var key: String = str(FORM_TAUNTS.get(new_form, ""))
	if key.is_empty() or dialogue_state != "none":
		_resume_boss()
		return
	_play_state("form", [key])


# ---------------------------------------------------------------------------
# Arena destekleri (Siber-Ağ Kesintisi ile yarıya iner)
# ---------------------------------------------------------------------------
func spawn_drones(count: int) -> Array[Node2D]:
	var points: Array[Vector2] = Spawner.points_from(drone_points, count)
	var wave: Array[Node2D] = Spawner.spawn_wave(self, "chrono_drone", points, -1)
	minions.append_array(wave)
	return wave


func set_turrets_active(count: int, active: bool) -> void:
	active_turrets = 0
	if arena_turrets == null:
		return
	var i: int = 0
	for turret: Node in arena_turrets.get_children():
		var on: bool = active and i < count
		if turret.has_method("set_powered"):
			turret.set_powered(on)
			turret.visible = on
		if on:
			active_turrets += 1
		i += 1
	if active:
		get_tree().create_timer(Phases.TURRET_TIME).timeout.connect(set_turrets_active.bind(0, false))


func _on_boss_defeated() -> void:
	if boss_defeated:
		return
	boss_defeated = true
	LevelStory.set_event(self, BOSS_EVENT)
	set_turrets_active(0, false)
	for m: Node2D in minions:
		if is_instance_valid(m) and m.has_method("take_damage") and not ("is_dead" in m and m.is_dead):
			m.take_damage(9999)
	var stats: Node = get_node_or_null("/root/PlayStats")
	if stats and stats.has_method("record_boss_defeated"):
		stats.record_boss_defeated("ai_lord")
	var am: Node = audio()
	if am and am.has_method("on_boss_defeated"):
		am.on_boss_defeated()
	advance_quest("defeat_ai_lord")
	if play_story(["fut_ai_lord_last_words"] as Array[String], boss):
		dialogue_box.dialogue_completed.connect(_go_to_shattering, CONNECT_ONE_SHOT)
	else:
		_go_to_shattering()


func _go_to_shattering() -> void:
	if not next_scene_path.is_empty():
		_exit_story_played = true
		transition_to_next(next_scene_path)


func can_exit() -> bool:
	return boss == null or boss_defeated
