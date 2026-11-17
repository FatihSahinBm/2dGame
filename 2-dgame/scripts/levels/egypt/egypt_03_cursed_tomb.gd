class_name Egypt03CursedTomb
extends EgyptLevelBase

## res://scripts/levels/egypt/egypt_03_cursed_tomb.gd
## Bölüm 3 — Sahne 3: Lanetli Anıt-Mezar ve Tuzak Koridorları (Epic 2D-143).
## - Kum tuzakları, periyodik güneş ışını tuzakları ve dipsiz çukur (ölüm bölgesi).
## - İki Güneş Mührü anahtarı toplanınca mühür kapısı açılır (bulmaca).
## - Lanetli lahitler (sömür/kır) ve tetik bölgesinde dirilen mumya dalgası.
## - Hiyeroglif tablet: Kalbin kökeni (Codex). Kapıdan sonra taht odasına (Sahne 4) geçiş.

const MummySpawner = preload("res://scripts/enemies/egypt/mummy_spawner.gd")
const WAVE_EVENT: String = "egypt_tomb_mummy_wave"

@onready var seal_door: SunSealDoor = get_node_or_null("SunSealDoor") as SunSealDoor
@onready var wave_trigger: Area2D = get_node_or_null("MummyWaveTrigger") as Area2D
@onready var wave_points: Node2D = get_node_or_null("MummyWavePoints") as Node2D

var wave_mummies: Array[Node2D] = []
var _pending_target: Node = null


func _level_ready() -> void:
	play_story_once(["egypt_tomb_intro"] as Array[String], 0.8, player)
	for pickup: Node in find_children("*", "EgyptPickup", true, false):
		(pickup as EgyptPickup).collected.connect(_on_pickup_collected)
	for tablet: Node in find_children("*", "HieroglyphTablet", true, false):
		(tablet as HieroglyphTablet).read_requested.connect(func(key: String) -> void: play_story([key] as Array[String]))
	for sarc: Node in find_children("*", "CursedSarcophagus", true, false):
		(sarc as CursedSarcophagus).interaction_requested.connect(_on_sarcophagus_interaction)
	if dialogue_box and dialogue_box.has_signal("choice_selected"):
		dialogue_box.choice_selected.connect(_on_choice_selected)
	if wave_trigger:
		wave_trigger.body_entered.connect(_on_wave_trigger)
	if seal_door:
		seal_door.opened.connect(_on_door_opened)
		seal_door.try_open() # kayıttan dönüldüyse anahtarlar zaten toplanmıştır
	_show_seal_progress()


func _on_pickup_collected(kind: String, _item_id: String) -> void:
	if kind != EgyptPickup.KIND_SEAL_KEY:
		if player:
			float_text(tr("EGYPT_FLOAT_POTION"), player.global_position, Color(0.5, 1.0, 0.6))
		return
	_show_seal_progress()
	if seal_door and seal_door.try_open():
		return
	play_story(["egypt_seal_key_found"] as Array[String], player)


func _show_seal_progress() -> void:
	if not seal_door or not hud or not hud.has_method("set_tutorial"):
		return
	var progress: String = tr("EGYPT_SEAL_PROGRESS") % [seal_door.get_collected_count(), seal_door.required_keys.size()]
	hud.set_tutorial(tr("EGYPT_TUT_03_TITLE"), progress, tr("EGYPT_TUT_03_DESC"))


func _on_door_opened() -> void:
	advance_quest("collect_seals")
	play_story(["egypt_seal_door_open"] as Array[String], seal_door)


func _on_wave_trigger(body: Node2D) -> void:
	if body != player or not wave_points:
		return
	var gs: Node = game_state()
	if gs and gs.has_method("is_event_completed") and gs.is_event_completed(WAVE_EVENT):
		return
	if gs and gs.has_method("set_event_completed"):
		gs.set_event_completed(WAVE_EVENT, true)
	spawn_mummy_wave()


func spawn_mummy_wave() -> Array[Node2D]:
	var points: Array[Vector2] = []
	for marker: Node in wave_points.get_children():
		if marker is Node2D:
			points.append((marker as Node2D).global_position)
	wave_mummies = MummySpawner.spawn_wave(self, points, -1)
	play_story(["egypt_mummy_wave"] as Array[String])
	set_tutorial_keys(PackedStringArray(["EGYPT_MUMMY_WAVE_TITLE", "EGYPT_MUMMY_WAVE_SUB", "EGYPT_MUMMY_WAVE_DESC"]))
	return wave_mummies


func _on_sarcophagus_interaction(sarc: Node) -> void:
	_pending_target = sarc
	if not play_story(["egypt_sarcophagus_choice"] as Array[String], sarc as Node2D):
		_pending_target = null


func _on_choice_selected(action: String) -> void:
	var target: CursedSarcophagus = _pending_target as CursedSarcophagus
	_pending_target = null
	if not is_instance_valid(target):
		return
	if action == "drain_sarcophagus":
		target.drain(player)
		float_text(tr("EGYPT_FLOAT_SOULS_DRAINED"), target.global_position, Color(0.6, 0.75, 1.0))
	elif action == "shatter_sarcophagus":
		target.shatter()
		MummySpawner.spawn(self, target.global_position + Vector2(-90.0, 0.0), 1)


func can_exit() -> bool:
	return seal_door == null or seal_door.is_open
