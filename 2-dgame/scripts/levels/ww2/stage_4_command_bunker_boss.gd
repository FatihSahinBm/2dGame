class_name Ww2Stage4CommandBunker
extends Ww2LevelBase

## res://scripts/levels/ww2/stage_4_command_bunker_boss.gd
## Bölüm 4 — Sahne 4: Ana Sığınak Komuta Merkezi — Cani Komutan boss arenası (Epic 2D-144).
## Akış: karşılama (temiz/yozlaşmış) → 3 formlu savaş (form taunt'ları) → 4. Kalp Parçası
## kılıca çekilir → son sözler → Sahne 5 (Anı Kırılması).
## Arena etkileşimleri: yıkılabilir kum torbası siperleri (keskin nişancıya karşı), Form 2
## taret desteği, telsiz topçu çağrısı (Sessiz Batarya %50 azaltır), Form 3 enerji sütunları
## (kırılınca boss sersemler), daralan arena sınırları ve deney askeri çağrısı.
## Easter egg: gizli duvar ardındaki mahzende Ana Karakter'in şövalye arması (bonus ödül).

const Spawner = preload("res://scripts/enemies/ww2/ww2_spawner.gd")
const BossBarScript = preload("res://scripts/ui/egypt_boss_bar.gd")
const FORM_TAUNTS: Dictionary = { 2: "ww2_commander_form_2", 3: "ww2_commander_form_3" }
const TURRET_SUPPORT_TIME: float = 8.0
const MAX_SHRINK: float = 360.0

@onready var boss: CommanderBoss = get_node_or_null("CommanderBoss") as CommanderBoss
@onready var barrage: ArtilleryBarrage = get_node_or_null("ArtilleryBarrage") as ArtilleryBarrage
@onready var heart_piece: Node2D = get_node_or_null("HeartPieceVisual") as Node2D
@onready var remnant_points: Node2D = get_node_or_null("RemnantPoints") as Node2D
@onready var shrink_left: Node2D = get_node_or_null("ShrinkWallLeft") as Node2D
@onready var shrink_right: Node2D = get_node_or_null("ShrinkWallRight") as Node2D
@onready var back_door: LabDoor = get_node_or_null("BackDoor") as LabDoor

var dialogue_state: String = "none"
var boss_defeated: bool = false
var minions: Array[Node2D] = []
var boss_bar: EgyptBossBar = null
var shrink_total: float = 0.0


func _level_ready() -> void:
	if heart_piece:
		heart_piece.visible = false
	_set_shrink_walls(false)
	if back_door:
		back_door.try_open()
	for relic: Node in find_children("*", "LoreRelic", true, false):
		(relic as LoreRelic).story_requested.connect(func(key: String) -> void: play_story([key] as Array[String]))
	for pillar: Node in get_pillars():
		(pillar as EnergyTube).broken.connect(func(_t: EnergyTube) -> void:
			if boss:
				boss.on_pillar_broken()
		)
	if dialogue_box:
		dialogue_box.dialogue_completed.connect(_on_dialogue_completed)
	if boss:
		boss_bar = BossBarScript.new() as EgyptBossBar
		add_child(boss_bar)
		boss_bar.setup("WW2_BOSS_NAME", boss.max_health)
		boss.health_changed.connect(boss_bar.set_health)
		boss.form_changed.connect(_on_form_changed)
		boss.artillery_requested.connect(_on_artillery_requested)
		boss.turret_support_requested.connect(set_turrets_active)
		boss.arena_shrink_requested.connect(shrink_arena)
		boss.summon_requested.connect(spawn_minions)
		boss.boss_defeated.connect(_on_boss_defeated)
	var intro: String = "ww2_commander_taunt_corrupted" if LevelStory.get_alignment(self) == "god_king" or ChapterState.has_harmed_innocents(self) else "ww2_commander_taunt"
	_play_state("intro", [intro])


func _process(_delta: float) -> void:
	if boss and not boss_defeated:
		boss.set_alive_minions(Spawner.count_alive(minions))


func get_pillars() -> Array[Node]:
	return find_children("*", "EnergyTube", true, false)


## Diyalog oynatır; oynatılamazsa durumu hemen tamamlar (savaş asla kilitlenmez)
func _play_state(state: String, keys: Array) -> void:
	dialogue_state = state
	var typed: Array[String] = []
	for k: Variant in keys:
		typed.append(str(k))
	if not play_story(typed, boss):
		_on_dialogue_completed()


func _on_dialogue_completed() -> void:
	var finished: String = dialogue_state
	dialogue_state = "none"
	match finished:
		"intro":
			var am: Node = audio()
			if am and am.has_method("on_boss_started"):
				am.on_boss_started("commander", 1)
			_resume_boss()
		"form":
			_resume_boss()
		"last_words":
			_go_to_memory_rift()


func _resume_boss() -> void:
	if boss and not boss_defeated:
		boss.on_cinematic_ended()


func _on_form_changed(new_form: int) -> void:
	if boss_bar:
		boss_bar.set_phase(new_form)
	if new_form == 3:
		for pillar: Node in get_pillars():
			(pillar as EnergyTube).restore()
	var key: String = str(FORM_TAUNTS.get(new_form, ""))
	if key.is_empty() or dialogue_state != "none":
		_resume_boss()
		return
	_play_state("form", [key])


# ---------------------------------------------------------------------------
# Arena etkileşimleri
# ---------------------------------------------------------------------------
func _on_artillery_requested(count: int) -> void:
	if barrage and player:
		barrage.fire_salvo(player.global_position.x, count)


func set_turrets_active(active: bool) -> void:
	for turret: Node in find_children("*", "BunkerTurret", true, false):
		(turret as BunkerTurret).set_active(active)
	if active:
		get_tree().create_timer(TURRET_SUPPORT_TIME).timeout.connect(set_turrets_active.bind(false))


## Form 3: okült arena sınırları içeri kayar (toplam MAX_SHRINK'e kadar)
func shrink_arena(amount: float) -> void:
	if not shrink_left or not shrink_right or shrink_total >= MAX_SHRINK:
		return
	_set_shrink_walls(true)
	var step: float = minf(amount, MAX_SHRINK - shrink_total) * 0.5
	shrink_total += step * 2.0
	var tw: Tween = create_tween()
	tw.tween_property(shrink_left, "position:x", shrink_left.position.x + step, 0.5)
	tw.parallel().tween_property(shrink_right, "position:x", shrink_right.position.x - step, 0.5)
	if boss:
		boss.arena_bounds = Vector2(shrink_left.position.x + step, shrink_right.position.x - step)


## Okült arena sınırları ilk daralmaya kadar kapalıdır (mahzen ve dolap erişilebilir kalır)
func _set_shrink_walls(enabled: bool) -> void:
	for wall: Node2D in [shrink_left, shrink_right]:
		if wall == null:
			continue
		wall.visible = enabled
		for child: Node in wall.get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred("disabled", not enabled)


func spawn_minions(count: int) -> Array[Node2D]:
	var points: Array[Vector2] = []
	if remnant_points:
		for marker: Node in remnant_points.get_children():
			if marker is Node2D and points.size() < count:
				points.append((marker as Node2D).global_position)
	var wave: Array[Node2D] = Spawner.spawn_wave(self, "occult_remnant", points, -1)
	minions.append_array(wave)
	return wave


# ---------------------------------------------------------------------------
# Final
# ---------------------------------------------------------------------------
func _on_boss_defeated() -> void:
	if boss_defeated:
		return
	boss_defeated = true
	set_turrets_active(false)
	_set_shrink_walls(false)
	for m: Node2D in minions:
		if is_instance_valid(m) and m.has_method("take_damage") and not ("is_dead" in m and m.is_dead):
			m.take_damage(9999)
	var stats: Node = get_node_or_null("/root/PlayStats")
	if stats and stats.has_method("record_boss_defeated"):
		stats.record_boss_defeated("butcher_commander")
	var am: Node = audio()
	if am and am.has_method("on_boss_defeated"):
		am.on_boss_defeated()
	advance_quest("defeat_commander")
	_extract_heart_piece()


## 4. Kalp Parçası Komutan'ın çekirdeğinden sökülüp kılıca çekilir
func _extract_heart_piece() -> void:
	play_sfx("heart_piece_extract")
	if heart_piece and player and boss:
		heart_piece.visible = true
		heart_piece.global_position = boss.global_position + Vector2(0.0, -70.0)
		var tw: Tween = create_tween()
		tw.tween_property(heart_piece, "global_position", player.global_position + Vector2(0.0, -25.0), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(heart_piece, "modulate:a", 0.0, 0.3)
		tw.tween_callback(_on_heart_absorbed)
	else:
		_on_heart_absorbed()


func _on_heart_absorbed() -> void:
	var gs: Node = game_state()
	if gs and "current_heart_pieces" in gs:
		gs.current_heart_pieces = maxi(int(gs.current_heart_pieces), 4)
	var codex: Node = get_node_or_null("/root/CodexManager")
	if codex and codex.has_method("unlock_entry"):
		codex.unlock_entry("ww2_lore_iron_heart")
	advance_quest("claim_heart")
	sword_scream()
	_play_state("last_words", ["ww2_commander_last_words"])


func _go_to_memory_rift() -> void:
	if not next_scene_path.is_empty():
		_exit_story_played = true
		transition_to_next(next_scene_path)
