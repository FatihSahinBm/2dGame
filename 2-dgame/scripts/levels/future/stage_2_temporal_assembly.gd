class_name FutureStage2TemporalAssembly
extends FutureLevelBase

## res://scripts/levels/future/stage_2_temporal_assembly.gd
## Bölüm 5 — Sekans 2: Zaman Fırtınası Viyadüğü ve Sibernetik Montaj Hattı (Epic 2D-158).
## - Hareketli konveyör bantları (terminal ile yön tersine çevrilir), ritmik hidrolik presler,
##   plazma kanalları ve zaman yarıkları (yavaşlatan/hızlandıran alanlar).
## - Büyük Keşif Anı: T-Rex zırhlarının üretim hattı ve kılıç kabzasıyla aynı damgayı taşıyan kalıp;
##   kılıçtaki çatlaklar şiddetle titrer.
## - Geçmişe Düşen Enkazın Sırrı (lore yan görevi): omuz soketi + T-Rex zırh şeması taranır.
## - Easter egg: gizli kırılabilir duvarın ardında Unit-REX-01 telemetri terminali.
## - Sekans sonu: Mini-Boss 1 Krono-Muhafız kapı kilidi savaşı; yenilince kapı açılır.

const WRECKAGE_QUEST: String = "future_fallen_wreckage"
const WARDEN_EVENT: String = "fut_warden_defeated"

@onready var warden: ChronoWarden = get_node_or_null("ChronoWarden") as ChronoWarden
@onready var warden_trigger: Area2D = get_node_or_null("WardenTrigger") as Area2D
@onready var mold_trigger: Area2D = get_node_or_null("MoldTrigger") as Area2D
@onready var gate_lock: StaticBody2D = get_node_or_null("GateLock") as StaticBody2D

var warden_started: bool = false
var mold_seen: bool = false
var boss_bar: EgyptBossBar = null
var _hints: Dictionary = {}


func _level_ready() -> void:
	ensure_quest_started(WRECKAGE_QUEST)
	play_story_once(["fut_assembly_intro"] as Array[String], 0.6, player)
	for belt: Node in find_children("*", "ConveyorBelt", true, false):
		(belt as ConveyorBelt).direction_changed.connect(func(_d: int) -> void: _hint("fut_conveyor_hint"))
	for press: Node in find_children("*", "HydraulicPress", true, false):
		(press as HydraulicPress).slammed.connect(_on_press_slammed)
	for terminal: Node in find_children("*", "FutureLoreTerminal", true, false):
		var t: FutureLoreTerminal = terminal as FutureLoreTerminal
		t.story_requested.connect(func(key: String) -> void:
			if not key.is_empty():
				play_story([key] as Array[String])
		)
		t.scanned.connect(_on_scanned)
	if mold_trigger:
		mold_trigger.body_entered.connect(_on_mold_entered)
	mold_seen = LevelStory.has_event(self, "story|fut_mold_discovery")
	if warden:
		warden.defeated.connect(_on_warden_defeated)
		warden.armor_blocked.connect(func() -> void:
			if warden.blocked_hits == 3:
				_hint("fut_warden_cooling_hint")
		)
		if is_warden_defeated():
			warden.queue_free()
			warden = null
			_open_gate()
	if warden_trigger:
		warden_trigger.body_entered.connect(_on_warden_trigger)


func _hint(key: String) -> void:
	if _hints.has(key):
		return
	_hints[key] = true
	play_story_once([key] as Array[String], 0.05, player)


func _on_press_slammed(pos: Vector2) -> void:
	if player and pos.distance_to(player.global_position) < 360.0:
		_hint("fut_press_hint")


# ---------------------------------------------------------------------------
# Büyük Keşif Anı ve Geçmişe Düşen Enkaz
# ---------------------------------------------------------------------------
func _on_mold_entered(body: Node2D) -> void:
	if body != player or mold_seen:
		return
	trigger_mold_discovery()


func trigger_mold_discovery() -> void:
	mold_seen = true
	advance_quest("reach_assembly")
	sword_scream()
	FutureFx.shake(self, 8.0, 1.2, "fut_mold_sword_tremble")
	if player:
		var tw: Tween = create_tween().set_loops(8)
		tw.tween_property(player, "rotation", 0.03, 0.05)
		tw.tween_property(player, "rotation", -0.03, 0.05)
		tw.finished.connect(func() -> void: if is_instance_valid(player): player.rotation = 0.0)
	play_story_once(["fut_mold_discovery"] as Array[String], 0.2, player)


func _on_scanned(scan_id: String, all_done: bool) -> void:
	advance_quest("scan_" + scan_id, WRECKAGE_QUEST)
	if all_done:
		var codex: Node = get_node_or_null("/root/CodexManager")
		if codex and codex.has_method("unlock_entry"):
			codex.unlock_entry("future_lore_fallen_wreckage")
		if not Inventory.has_item(self, "stamped_prototype_part"):
			Inventory.add(self, "stamped_prototype_part", 1)
		queue_story("fut_wreckage_secret_done", 1.2)


# ---------------------------------------------------------------------------
# Mini-Boss 1: Krono-Muhafız
# ---------------------------------------------------------------------------
func is_warden_defeated() -> bool:
	return LevelStory.has_event(self, WARDEN_EVENT)


func _on_warden_trigger(body: Node2D) -> void:
	if body == player and not warden_started and warden:
		start_warden_fight()


func start_warden_fight() -> void:
	if warden_started or not warden:
		return
	warden_started = true
	boss_bar = make_boss_bar("FUT_WARDEN_NAME", warden.max_health)
	warden.health_changed.connect(boss_bar.set_health)
	var am: Node = audio()
	if am and am.has_method("on_boss_started"):
		am.on_boss_started("ai_lord", 1)
	if play_story(["fut_warden_intro"] as Array[String], warden):
		dialogue_box.dialogue_completed.connect(warden.on_cinematic_ended, CONNECT_ONE_SHOT)
	else:
		warden.on_cinematic_ended()


func _on_warden_defeated() -> void:
	LevelStory.set_event(self, WARDEN_EVENT)
	advance_quest("defeat_chrono_warden")
	var am: Node = audio()
	if am and am.has_method("on_boss_defeated"):
		am.on_boss_defeated()
	_open_gate()
	play_story(["fut_warden_defeated"] as Array[String], warden)


func _open_gate() -> void:
	if not gate_lock:
		return
	for child: Node in gate_lock.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)
	create_tween().tween_property(gate_lock, "modulate:a", 0.0, 0.8)


func can_exit() -> bool:
	return warden == null or warden.is_dead or is_warden_defeated()


func _on_exit_blocked() -> void:
	set_tutorial_keys(PackedStringArray(["FUT_EXIT_WARDEN_TITLE", "FUT_EXIT_WARDEN_SUB", "FUT_EXIT_WARDEN_DESC"]))


func get_exit_story_key() -> String:
	return "fut_assembly_exit"
