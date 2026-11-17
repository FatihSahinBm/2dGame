class_name Ww2Stage5MemoryRift
extends Ww2LevelBase

## res://scripts/levels/ww2/stage_5_memory_rift.gd
## Bölüm 4 — Sahne 5: 4. Kalp Parçası ve Anı Kırılması (Epic 2D-144).
## Akış: zaman yırtığına düşüş → 4. Anı Kırılması flashback'i (Büyücünün ruhunu kılıca
## kendi elleriyle hapsetme ve intikam yemini) → kılıç evrimi (kızıl-altın aura, HUD rozeti)
## → eğilime göre outro → bölüm tamamlanır, kayıt alınır → Bölüm 5 Zaman Yırtığı çıkışı.
## Sonuç ekranı gösterilir; Bölüm 5 sahnesi varsa "Zaman Yırtığına Gir" düğmesi ona götürür.

signal finale_finished(alignment: String)

const ResultsScreen = preload("res://scripts/ui/results_screen.gd")

## Bölüm 5 (Distopik Gelecek) giriş sahnesi — sonuç ekranındaki "Zaman Yırtığına Gir" düğmesi buraya götürür
@export var next_chapter_scene: String = ""
## Bölüm sonunda aktif kayıt yuvasına yazılır (doğrulama testleri kapatır)
@export var autosave_on_complete: bool = true

@onready var flashback: FlashbackOverlay = get_node_or_null("FlashbackOverlay") as FlashbackOverlay
@onready var exit_rift: Node2D = get_node_or_null("ExitRift") as Node2D

var dialogue_state: String = "none"
var chapter_completed: bool = false


func _level_ready() -> void:
	if exit_rift:
		exit_rift.visible = false
	if dialogue_box:
		dialogue_box.dialogue_completed.connect(_on_dialogue_completed)
	if flashback:
		flashback.flashback_finished.connect(_on_flashback_finished)
	var gs: Node = game_state()
	if gs and "current_heart_pieces" in gs:
		gs.current_heart_pieces = maxi(int(gs.current_heart_pieces), 4)
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_inside_tree():
			_play_state("intro", ["ww2_memory_rift_intro"])
	)


func _play_state(state: String, keys: Array) -> void:
	dialogue_state = state
	var typed: Array[String] = []
	for k: Variant in keys:
		typed.append(str(k))
	if not play_story(typed, player):
		_on_dialogue_completed()


func _on_dialogue_completed() -> void:
	var finished: String = dialogue_state
	dialogue_state = "none"
	match finished:
		"intro":
			start_memory_flashback()
		"evolution":
			_play_outro()
		"outro":
			_complete_chapter()


## 4. Anı Kırılması: ruhu kılıca hapsetme ve intikam yemini
func start_memory_flashback() -> void:
	if flashback:
		flashback.memory_key = "ww2_memory_flashback"
		flashback.ability_id = VOW_ABILITY
		flashback.ability_data_key = "ability_unlock_ww2"
		flashback.ability_chapter_path = CHAPTER_PATH
		flashback.ability_tag_key = "WW2_ABILITY_TAG"
		flashback.play_vlad_memory_sequence()
	else:
		_on_flashback_finished()


func _on_flashback_finished() -> void:
	var gs: Node = game_state()
	if gs and gs.has_method("unlock_ability"):
		gs.unlock_ability(VOW_ABILITY)
	refresh_sword_state()
	play_sfx("mage_vengeance_whisper", player.global_position if player else Vector2.INF, -4.0)
	_play_state("evolution", ["ww2_sword_evolution"])


func _play_outro() -> void:
	var alignment: String = LevelStory.get_alignment(self)
	var gs: Node = game_state()
	if gs and gs.has_method("record_ending"):
		alignment = gs.record_ending()
	if exit_rift:
		exit_rift.visible = true
	_play_state("outro", ["ww2_outro_god_king" if alignment == "god_king" else "ww2_outro_redemption"])


func _complete_chapter() -> void:
	if chapter_completed:
		return
	chapter_completed = true
	var gs: Node = game_state()
	if gs and gs.has_method("complete_chapter"):
		gs.complete_chapter("ww2")
		gs.complete_chapter("chapter_4")
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if autosave_on_complete and save_mgr and save_mgr.has_method("save_game"):
		save_mgr.save_game(int(save_mgr.active_slot) if "active_slot" in save_mgr else 1)
	set_tutorial_keys(PackedStringArray(["WW2_CHAPTER_DONE_TITLE", "WW2_CHAPTER_DONE_SUB", "WW2_CHAPTER_DONE_DESC"]))
	finale_finished.emit(LevelStory.get_alignment(self))
	var next_chapter: String = next_chapter_scene if ResourceLoader.exists(next_chapter_scene) else ""
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_inside_tree():
			ResultsScreen.show_for(self, next_chapter)
	)
