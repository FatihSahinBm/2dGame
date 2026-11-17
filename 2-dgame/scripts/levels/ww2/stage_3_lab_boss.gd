extends RefCounted

## res://scripts/levels/ww2/stage_3_lab_boss.gd
## Mini-Boss 2 karşılaşması (Epic 2D-144) — Okült Başhekim & Başarısız Deney çift hedefli savaş.
## - Tetik alanına girilince giriş diyaloğu, boss barları ve okült arena duvarları.
## - Enerji tüplerinin hepsi kırılınca Başhekim'in okült kalkanı iner.
## - Deney her yere vuruşunda arena duvarlarını içeri çeker (en fazla MAX_SHRINK adım).
## - Biri ölünce diğeri öfkelenir; ikisi de ölünce duvarlar kalkar ve çıkış açılır.

const BossBarScript = preload("res://scripts/ui/egypt_boss_bar.gd")
const LevelStory = preload("res://scripts/components/level_story.gd")
const CLEARED_EVENT: String = "ww2_lab_minibosses_defeated"
const SHRINK_STEP: float = 40.0
const MAX_SHRINK: int = 4

var level: Node2D = null
var doctor: OccultDoctor = null
var beast: FailedExperiment = null
var wall_left: Node2D = null
var wall_right: Node2D = null
var started: bool = false
var shrink_steps: int = 0
var bars: Array[EgyptBossBar] = []
var _wall_origin: Vector2 = Vector2.ZERO


func _init(owner_level: Node2D) -> void:
	level = owner_level
	doctor = level.get_node_or_null("OccultDoctor") as OccultDoctor
	beast = level.get_node_or_null("FailedExperiment") as FailedExperiment
	wall_left = level.get_node_or_null("ArenaWallLeft") as Node2D
	wall_right = level.get_node_or_null("ArenaWallRight") as Node2D
	if wall_left and wall_right:
		_wall_origin = Vector2(wall_left.position.x, wall_right.position.x)
	if is_cleared():
		_remove_bosses()
		return
	_set_walls(false)
	var trigger: Area2D = level.get_node_or_null("BossTrigger") as Area2D
	if trigger:
		trigger.body_entered.connect(_on_trigger)
	for tube: Node in level.find_children("*", "EnergyTube", true, false):
		(tube as EnergyTube).broken.connect(_on_tube_broken)
	if doctor:
		doctor.defeated.connect(_on_one_defeated.bind("doctor"))
		doctor.damage_blocked.connect(_on_shield_blocked)
	if beast:
		beast.defeated.connect(_on_one_defeated.bind("beast"))
		beast.slam_landed.connect(_on_slam)


func is_cleared() -> bool:
	return LevelStory.has_event(level, CLEARED_EVENT) or (doctor != null and beast != null and doctor.is_dead and beast.is_dead)


func _on_trigger(body: Node2D) -> void:
	if started or not body.is_in_group("player"):
		return
	start()


func start() -> void:
	if started:
		return
	started = true
	_set_walls(true)
	var titles: Array[Array] = [["WW2_DOCTOR_NAME", doctor], ["WW2_EXPERIMENT_NAME", beast]]
	for i: int in titles.size():
		var boss: Ww2BossBase = titles[i][1] as Ww2BossBase
		if boss == null:
			continue
		var bar: EgyptBossBar = BossBarScript.new() as EgyptBossBar
		level.add_child(bar)
		bar.setup(str(titles[i][0]), boss.max_health)
		bar.offset = Vector2(0.0, 46.0 * float(i))
		boss.health_changed.connect(bar.set_health)
		bars.append(bar)
	var am: Node = level.get_node_or_null("/root/AudioManager")
	if am and am.has_method("on_boss_started"):
		am.on_boss_started("commander", 2)
	var box: Node = level.get_node_or_null("DialogueBox")
	if level.call("play_story", ["ww2_doctor_intro"] as Array[String], doctor) and box:
		box.dialogue_completed.connect(_activate, CONNECT_ONE_SHOT)
	else:
		_activate()


func _activate() -> void:
	for boss: Ww2BossBase in [doctor, beast] as Array[Ww2BossBase]:
		if boss and not boss.is_dead:
			boss.on_cinematic_ended()
	level.call("set_tutorial_keys", PackedStringArray(["WW2_TUBES_TITLE", "WW2_TUBES_SUB", "WW2_TUBES_DESC"]))


func intact_tubes() -> int:
	var count: int = 0
	for tube: Node in level.find_children("*", "EnergyTube", true, false):
		if not (tube as EnergyTube).is_broken:
			count += 1
	return count


func _on_tube_broken(_tube: EnergyTube) -> void:
	if intact_tubes() == 0 and doctor and doctor.shielded:
		doctor.set_shielded(false)
		level.call("play_story", ["ww2_doctor_shield_down"] as Array[String], doctor)


func _on_shield_blocked(_reason: String) -> void:
	LevelStory.play_delayed(level, ["ww2_doctor_shield_hint"] as Array[String], 0.05, doctor)


## Deney yere vurdu: okült duvarlar bir adım içeri
func _on_slam(_at: Vector2) -> void:
	if shrink_steps >= MAX_SHRINK or not wall_left or not wall_right:
		return
	shrink_steps += 1
	var tw: Tween = level.create_tween()
	tw.tween_property(wall_left, "position:x", wall_left.position.x + SHRINK_STEP, 0.4)
	tw.parallel().tween_property(wall_right, "position:x", wall_right.position.x - SHRINK_STEP, 0.4)


func _on_one_defeated(which: String) -> void:
	var other: Ww2BossBase = beast if which == "doctor" else doctor
	if other and not other.is_dead:
		other.call("set_enraged")
		return
	LevelStory.set_event(level, CLEARED_EVENT)
	_set_walls(false)
	var am: Node = level.get_node_or_null("/root/AudioManager")
	if am and am.has_method("on_boss_defeated"):
		am.on_boss_defeated()
	level.call("play_story", ["ww2_doctor_defeated"] as Array[String], doctor)
	level.call("set_tutorial_keys", PackedStringArray(["WW2_TUT_03_DONE_TITLE", "WW2_TUT_03_DONE_SUB", "WW2_TUT_03_DONE_DESC"]))


func _set_walls(closed: bool) -> void:
	for wall: Node2D in [wall_left, wall_right]:
		if wall == null:
			continue
		wall.visible = closed
		for child: Node in wall.get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred("disabled", not closed)
	if not closed and wall_left and wall_right:
		wall_left.position.x = _wall_origin.x
		wall_right.position.x = _wall_origin.y
		shrink_steps = 0


func _remove_bosses() -> void:
	for boss: Node in [doctor, beast]:
		if boss:
			boss.queue_free()
	doctor = null
	beast = null
	_set_walls(false)
