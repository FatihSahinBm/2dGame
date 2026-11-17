class_name Egypt01CrimsonDesert
extends EgyptLevelBase

## res://scripts/levels/egypt/egypt_01_crimson_desert.gd
## Bölüm 3 — Sahne 1: Kızıl Çöl ve Asılı Piramitler (Epic 2D-143).
## - Bölüm 2 çıkışındaki zaman yırtığından düşüş; ruhsuzlaşan kılıcın çığlık tepkisi.
## - Kızıl kum fırtınası, havada asılı piramitler (zaman kırılması atmosferi).
## - İlk Piramit Muhafızı karşılaşması ve kum tuzakları; hiyeroglif tablet (Codex).
## - Muhafızlar temizlenince avluya (Sahne 2) geçiş.

@onready var rift: DimensionalTimeRift = get_node_or_null("DimensionalTimeRift") as DimensionalTimeRift
@onready var enemies: Node2D = get_node_or_null("Enemies") as Node2D
@onready var guard_alert: Area2D = get_node_or_null("GuardAlertZone") as Area2D

var _guards_alerted: bool = false


func _level_ready() -> void:
	if rift and player:
		rift.spawn_completed.connect(_on_player_landed, CONNECT_ONE_SHOT)
		rift.play_player_emerge_sequence(player)
	else:
		_on_player_landed()
	if guard_alert:
		guard_alert.body_entered.connect(_on_guard_alert)
	for trap: Node in get_tree().get_nodes_in_group("egypt_hazards"):
		if trap is SandTrap and is_ancestor_of(trap):
			(trap as SandTrap).player_trapped.connect(_on_player_trapped)
	for tablet: Node in find_children("*", "HieroglyphTablet", true, false):
		(tablet as HieroglyphTablet).read_requested.connect(_on_tablet_read)


func _on_player_landed() -> void:
	sword_scream()
	play_story_once(["egypt_arrival"] as Array[String], 0.6, player)


func _on_guard_alert(body: Node2D) -> void:
	if body != player or _guards_alerted:
		return
	_guards_alerted = true
	var first_guard: Node2D = null
	if enemies and enemies.get_child_count() > 0:
		first_guard = enemies.get_child(0) as Node2D
	play_story(["egypt_first_guard"] as Array[String], first_guard)


func _on_player_trapped(_p: Node2D) -> void:
	play_story_once(["egypt_sand_trap_hint"] as Array[String], 0.1, player)


func _on_tablet_read(key: String) -> void:
	if not key.is_empty():
		play_story([key] as Array[String])


func guards_remaining() -> int:
	if not enemies:
		return 0
	var alive: int = 0
	for e: Node in enemies.get_children():
		if not ("is_dead" in e and e.is_dead):
			alive += 1
	return alive


func can_exit() -> bool:
	return guards_remaining() == 0


func _on_exit_blocked() -> void:
	set_tutorial_keys(PackedStringArray(["EGYPT_EXIT_GUARDS_TITLE", "EGYPT_EXIT_GUARDS_SUB", "EGYPT_EXIT_GUARDS_DESC"]))


func transition_to_next(path: String = "") -> void:
	advance_quest("cross_desert")
	super.transition_to_next(path)
