class_name Egypt02MonumentCourtyard
extends EgyptLevelBase

## res://scripts/levels/egypt/egypt_02_monument_courtyard.gd
## Bölüm 3 — Sahne 2: Köle Kampı / Anıt-Mezar Avlusu (Seçim Alanı) (Epic 2D-143).
## - Muhafız kuşatması altındaki üç köle kafesi: muhafızları yen, sonra köleyi kurtar (Kefaret)
##   ya da ruhunu sömür (+20 Yozlaşma, kurban sayacı). Köleyi kılıçla öldürmek +12 Yozlaşma.
## - Lanetli lahitler: ruh enerjisini sömür (+20) ya da kırıp ruhları serbest bırak (mumya uyanır).
## - Tüm kafesler karara bağlanınca anıt-mezara (Sahne 3) geçilir; çıkış anlatımı seçime göre değişir.

const ChapterState = preload("res://scripts/components/egypt_chapter_state.gd")
const MummySpawner = preload("res://scripts/enemies/egypt/mummy_spawner.gd")
const SIDE_QUEST: String = "egypt_break_the_chains"

var _pending_target: Node = null
var _exit_story_played: bool = false


func _level_ready() -> void:
	play_story_once(["egypt_courtyard_intro"] as Array[String], 0.8, player)
	ensure_quest_started(SIDE_QUEST)
	if dialogue_box and dialogue_box.has_signal("choice_selected"):
		dialogue_box.choice_selected.connect(_on_choice_selected)
	for cage: SlaveCage in get_cages():
		cage.interaction_requested.connect(_on_cage_interaction)
		cage.resolved.connect(_on_cage_resolved)
	for sarc: Node in find_children("*", "CursedSarcophagus", true, false):
		(sarc as CursedSarcophagus).interaction_requested.connect(_on_sarcophagus_interaction)
		(sarc as CursedSarcophagus).shattered.connect(_on_sarcophagus_shattered)
	for tablet: Node in find_children("*", "HieroglyphTablet", true, false):
		(tablet as HieroglyphTablet).read_requested.connect(func(key: String) -> void: play_story([key] as Array[String]))


func get_cages() -> Array[SlaveCage]:
	var cages: Array[SlaveCage] = []
	for n: Node in find_children("*", "SlaveCage", true, false):
		cages.append(n as SlaveCage)
	return cages


func unresolved_cages() -> int:
	var count: int = 0
	for cage: SlaveCage in get_cages():
		if not cage.is_resolved():
			count += 1
	return count


# ---------------------------------------------------------------------------
# Seçimler
# ---------------------------------------------------------------------------
func _on_cage_interaction(cage: Node) -> void:
	_pending_target = cage
	if not play_story(["egypt_slave_plea"] as Array[String], (cage as SlaveCage).get_slave()):
		_pending_target = null


func _on_sarcophagus_interaction(sarc: Node) -> void:
	_pending_target = sarc
	if not play_story(["egypt_sarcophagus_choice"] as Array[String], sarc as Node2D):
		_pending_target = null


## Diyalog seçim düğmelerinden gelen eylemler
func _on_choice_selected(action: String) -> void:
	var target: Node = _pending_target
	_pending_target = null
	apply_choice(action, target)


## Seçimin oyun durumuna etkisi (testler de doğrudan çağırır)
func apply_choice(action: String, target: Node) -> void:
	if not is_instance_valid(target):
		return
	match action:
		"free_slave":
			(target as SlaveCage).free_slave()
		"drain_slave":
			(target as SlaveCage).drain_slave(player)
		"drain_sarcophagus":
			(target as CursedSarcophagus).drain(player)
			_queue_story("egypt_sarcophagus_drained")
			float_text(tr("EGYPT_FLOAT_SOULS_DRAINED"), (target as Node2D).global_position, Color(0.6, 0.75, 1.0))
		"shatter_sarcophagus":
			(target as CursedSarcophagus).shatter()


func _on_cage_resolved(cage: SlaveCage, outcome: String) -> void:
	match outcome:
		ChapterState.OUTCOME_FREED:
			_queue_story("egypt_slave_freed")
			float_text(tr("EGYPT_FLOAT_SLAVE_FREED"), cage.global_position, Color(0.5, 1.0, 0.6))
		ChapterState.OUTCOME_DRAINED:
			_queue_story("egypt_slave_drained")
			float_text(tr("EGYPT_FLOAT_SOULS_DRAINED"), cage.global_position, Color(0.6, 0.75, 1.0))
		ChapterState.OUTCOME_KILLED:
			_queue_story("egypt_slave_killed")
			float_text(tr("EGYPT_FLOAT_SLAVE_KILLED"), cage.global_position, Color(1.0, 0.3, 0.3))
	_update_side_quest()
	if unresolved_cages() == 0:
		advance_quest("decide_courtyard")
		set_tutorial_keys(PackedStringArray(["EGYPT_TUT_02_DONE_TITLE", "EGYPT_TUT_02_DONE_SUB", "EGYPT_TUT_02_DONE_DESC"]))


func _update_side_quest() -> void:
	var q_mgr: Node = quest_manager()
	if q_mgr == null:
		return
	var freed: int = ChapterState.count_outcome(self, ChapterState.OUTCOME_FREED)
	if freed >= get_cages().size() and q_mgr.has_method("advance_quest"):
		q_mgr.advance_quest(SIDE_QUEST, "free_slaves")
	elif unresolved_cages() == 0 and freed < get_cages().size() and q_mgr.has_method("fail_quest"):
		q_mgr.fail_quest(SIDE_QUEST)


func _on_sarcophagus_shattered(at: Vector2) -> void:
	_queue_story("egypt_sarcophagus_shattered")
	MummySpawner.spawn(self, at + Vector2(90.0, 0.0), -1)


## Seçim diyaloğu kapanırken yeni bir diyalog açmak için bir kare bekle
func _queue_story(key: String) -> void:
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		if is_inside_tree():
			play_story([key] as Array[String])
	)


# ---------------------------------------------------------------------------
# Çıkış
# ---------------------------------------------------------------------------
func can_exit() -> bool:
	return unresolved_cages() == 0


func _on_exit_blocked() -> void:
	set_tutorial_keys(PackedStringArray(["EGYPT_EXIT_CAGES_TITLE", "EGYPT_EXIT_CAGES_SUB", "EGYPT_EXIT_CAGES_DESC"]))


func get_exit_story_key() -> String:
	if ChapterState.count_outcome(self, ChapterState.OUTCOME_FREED) > 0:
		return "egypt_courtyard_exit_redemption"
	return "egypt_courtyard_exit_corrupted"


func transition_to_next(path: String = "") -> void:
	if not _exit_story_played and dialogue_box:
		_exit_story_played = true
		if play_story([get_exit_story_key()] as Array[String], player):
			dialogue_box.dialogue_completed.connect(_base_transition.bind(path), CONNECT_ONE_SHOT)
			return
	_base_transition(path)


func _base_transition(path: String) -> void:
	super.transition_to_next(path)
