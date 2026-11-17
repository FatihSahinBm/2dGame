class_name Egypt04SunThrone
extends EgyptLevelBase

## res://scripts/levels/egypt/egypt_04_sun_throne.gd
## Bölüm 3 — Sahne 4: Güneş Taht Odası (Boss Arenası) ve Çıkış (Epic 2D-143).
## Akış: karşılama (temiz/yozlaşmış) → 3 fazlı Firavun Kral savaşı (faz taunt'ları, mumya
## çağrısı) → 3. Kalp Parçası kılıca çekilir → son sözler → 3. Anı Kırılması flashback'i →
## kılıç evrimi (kızıl-mavi sızıntı) → eğilime göre outro → Bölüm 4'e açılan zaman yırtığı.

signal finale_finished(alignment: String)

const MummySpawner = preload("res://scripts/enemies/egypt/mummy_spawner.gd")
const BossBarScript = preload("res://scripts/ui/egypt_boss_bar.gd")
const ResultsScreen = preload("res://scripts/ui/results_screen.gd")
const PHASE_TAUNTS: Dictionary = { 2: "egypt_pharaoh_phase_2", 3: "egypt_pharaoh_phase_3" }

## Bölüm 4 (2. Dünya Savaşı) giriş sahnesi; sonuç ekranındaki "Zaman Yırtığına Gir" düğmesi buraya götürür
@export var next_chapter_scene: String = ""
## Bölüm sonunda aktif kayıt yuvasına yazılır (doğrulama testleri kapatır)
@export var autosave_on_complete: bool = true

@onready var boss: PharaohBoss = get_node_or_null("PharaohBoss") as PharaohBoss
@onready var flashback: FlashbackOverlay = get_node_or_null("FlashbackOverlay") as FlashbackOverlay
@onready var heart_piece: Node2D = get_node_or_null("HeartPieceVisual") as Node2D
@onready var mummy_points: Node2D = get_node_or_null("MummyPoints") as Node2D
@onready var exit_rift: Node2D = get_node_or_null("ExitRift") as Node2D

var dialogue_state: String = "none"
var boss_defeated: bool = false
var minions: Array[Node2D] = []
var boss_bar: EgyptBossBar = null


func _level_ready() -> void:
	if heart_piece:
		heart_piece.visible = false
	if exit_rift:
		exit_rift.visible = false
	boss_bar = BossBarScript.new() as EgyptBossBar
	add_child(boss_bar)
	if boss:
		boss_bar.setup("EGYPT_BOSS_NAME", boss.max_health)
		boss.health_changed.connect(boss_bar.set_health)
		boss.phase_changed.connect(_on_boss_phase_changed)
		boss.summon_requested.connect(spawn_minions)
		boss.boss_defeated.connect(_on_boss_defeated)
	if dialogue_box:
		dialogue_box.dialogue_completed.connect(_on_dialogue_completed)
	if flashback:
		flashback.flashback_finished.connect(_on_flashback_finished)
	var intro: String = "egypt_pharaoh_taunt_corrupted" if LevelStory.get_alignment(self) == "god_king" else "egypt_pharaoh_taunt"
	_play_state("intro", [intro])


func _process(_delta: float) -> void:
	if boss and not boss_defeated:
		boss.set_alive_minions(MummySpawner.count_alive(minions))


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
				am.on_boss_started("pharaoh")
			_resume_boss()
		"phase":
			_resume_boss()
		"last_words":
			start_memory_flashback()
		"evolution":
			_play_outro()
		"outro":
			_complete_chapter()


func _resume_boss() -> void:
	if boss and not boss_defeated:
		boss.on_cinematic_ended()


func _on_boss_phase_changed(new_phase: int) -> void:
	if boss_bar:
		boss_bar.set_phase(new_phase)
	var key: String = str(PHASE_TAUNTS.get(new_phase, ""))
	if key.is_empty() or dialogue_state != "none":
		_resume_boss()
		return
	_play_state("phase", [key])


## Firavun'un mumya çağrısı: işaretçilerden en fazla `count` mumya kalkar
func spawn_minions(count: int) -> Array[Node2D]:
	var points: Array[Vector2] = []
	if mummy_points:
		for marker: Node in mummy_points.get_children():
			if marker is Node2D and points.size() < count:
				points.append((marker as Node2D).global_position)
	var wave: Array[Node2D] = MummySpawner.spawn_wave(self, points, -1)
	minions.append_array(wave)
	return wave


# ---------------------------------------------------------------------------
# Final sekansı
# ---------------------------------------------------------------------------
func _on_boss_defeated() -> void:
	if boss_defeated:
		return
	boss_defeated = true
	for m: Node2D in minions:
		if is_instance_valid(m) and m.has_method("take_damage") and not ("is_dead" in m and m.is_dead):
			m.take_damage(9999)
	var stats: Node = get_node_or_null("/root/PlayStats")
	if stats and stats.has_method("record_boss_defeated"):
		stats.record_boss_defeated("pharaoh")
	var am: Node = audio()
	if am and am.has_method("on_boss_defeated"):
		am.on_boss_defeated()
	advance_quest("defeat_pharaoh")
	_extract_heart_piece()


## 3. Kalp Parçası Firavun'un asasından sökülüp kılıca çekilir
func _extract_heart_piece() -> void:
	play_sfx("heart_piece_extract")
	if heart_piece and player and boss:
		heart_piece.visible = true
		heart_piece.global_position = boss.global_position + Vector2(0.0, -60.0)
		var tw: Tween = create_tween()
		tw.tween_property(heart_piece, "global_position", player.global_position + Vector2(0.0, -25.0), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(heart_piece, "modulate:a", 0.0, 0.3)
		tw.tween_callback(_on_heart_absorbed)
	else:
		_on_heart_absorbed()


func _on_heart_absorbed() -> void:
	var gs: Node = game_state()
	if gs and "current_heart_pieces" in gs:
		gs.current_heart_pieces = maxi(int(gs.current_heart_pieces), 3)
	advance_quest("claim_heart")
	sword_scream()
	_play_state("last_words", ["egypt_pharaoh_last_words"])


## 3. Anı Kırılması: Büyücü dostun sırtından vurulduğu anı
func start_memory_flashback() -> void:
	if flashback:
		flashback.memory_key = "egypt_memory_flashback"
		flashback.ability_id = SEAL_ABILITY
		flashback.ability_data_key = "ability_unlock_egypt"
		flashback.ability_chapter_path = CHAPTER_PATH
		flashback.ability_tag_key = "EGYPT_ABILITY_TAG"
		flashback.play_vlad_memory_sequence()
	else:
		_on_flashback_finished()


func _on_flashback_finished() -> void:
	# Mühür yarı yarıya zayıfladı: yetenek açık değilse (flashback yoksa) burada açılır
	var gs: Node = game_state()
	if gs and gs.has_method("unlock_ability"):
		gs.unlock_ability(SEAL_ABILITY)
	refresh_sword_seal_state()
	_play_state("evolution", ["egypt_sword_evolution"])


func _play_outro() -> void:
	var alignment: String = LevelStory.get_alignment(self)
	var gs: Node = game_state()
	if gs and gs.has_method("record_ending"):
		alignment = gs.record_ending()
	var key: String = "egypt_outro_god_king" if alignment == "god_king" else "egypt_outro_redemption"
	if exit_rift:
		exit_rift.visible = true
	_play_state("outro", [key])


func _complete_chapter() -> void:
	var gs: Node = game_state()
	if gs and gs.has_method("complete_chapter"):
		gs.complete_chapter("egypt")
		gs.complete_chapter("chapter_3")
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if autosave_on_complete and save_mgr and save_mgr.has_method("save_game"):
		save_mgr.save_game(int(save_mgr.active_slot) if "active_slot" in save_mgr else 1)
	set_tutorial_keys(PackedStringArray(["EGYPT_CHAPTER_DONE_TITLE", "EGYPT_CHAPTER_DONE_SUB", "EGYPT_CHAPTER_DONE_DESC"]))
	finale_finished.emit(LevelStory.get_alignment(self))
	var next_chapter: String = next_chapter_scene if ResourceLoader.exists(next_chapter_scene) else ""
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_inside_tree():
			ResultsScreen.show_for(self, next_chapter)
	)
