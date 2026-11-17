class_name FutureStage5SwordShattering
extends FutureLevelBase

## res://scripts/levels/future/stage_5_sword_shattering.gd
## Bölüm 5 — Sekans 5: 5. Kalp Parçası, Mührün Çatlaması ve Kılıcın Kırılışı (Epic 2D-158).
## Akış: AI Lord'un çöken gövdesi -> 5. Kalp Parçası göğüs çekirdeğinden sökülür ve kılıca çekilir
## (current_heart_pieces = 5) -> 6. çekirdek uyanır -> anı kırılması (mührün yalanı) -> tam ekran
## kabuk parçalanması (vfx_sword_shell_shatter, beyaz flaş, sarsıntı, çatlama sesi) -> Büyücünün
## gölgesi ve kahkahası -> eğilime göre outro (GameState.record_ending: <50 Kefaret / >=50 veya
## >=3 kurban Tanrı-Kral) -> bölüm tamamlanır, kayıt alınır -> Bölüm 6 Hiçlik Arenası zaman yırtığı açılır.

signal finale_finished(alignment: String)
signal shell_shattered()

const ResultsScreen = preload("res://scripts/ui/results_screen.gd")
const HEART_INDEX: int = 5

## Bölüm 6 (Hiçlik Arenası) giriş sahnesi (henüz yok — boşken yalnızca sonuç ekranı)
@export var next_chapter_scene: String = ""
## Bölüm sonunda aktif kayıt yuvasına yazılır (doğrulama testleri kapatır)
@export var autosave_on_complete: bool = true

@onready var flashback: FlashbackOverlay = get_node_or_null("FlashbackOverlay") as FlashbackOverlay
@onready var void_rift: Node2D = get_node_or_null("VoidRift") as Node2D
@onready var heart_piece: Node2D = get_node_or_null("HeartPieceVisual") as Node2D
@onready var lord_remains: Node2D = get_node_or_null("AiLordRemains") as Node2D
@onready var wizard_shadow: CanvasItem = get_node_or_null("WizardShadow") as CanvasItem

var dialogue_state: String = "none"
var chapter_completed: bool = false
var shell_broken: bool = false


func _level_ready() -> void:
	if void_rift:
		void_rift.visible = false
	if wizard_shadow:
		wizard_shadow.modulate.a = 0.0
	if dialogue_box:
		dialogue_box.dialogue_completed.connect(_on_dialogue_completed)
	if flashback:
		flashback.flashback_finished.connect(_on_flashback_finished)
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_inside_tree():
			_play_state("intro", ["fut_shatter_intro"])
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
			extract_heart_piece()
		"heart":
			_play_state("core", ["fut_sixth_core_awakens"])
		"core":
			start_memory_flashback()
		"shatter":
			_summon_wizard_shadow()
		"wizard":
			_play_outro()
		"outro":
			_complete_chapter()


## 5. Kalp Parçası AI Lord'un göğüs çekirdeğinden sökülüp kılıca çekilir
func extract_heart_piece() -> void:
	play_sfx("heart_piece_extract")
	var origin: Vector2 = lord_remains.global_position + Vector2(0.0, -60.0) if lord_remains else Vector2.ZERO
	if heart_piece and player:
		heart_piece.visible = true
		heart_piece.global_position = origin
		var tw: Tween = create_tween()
		tw.tween_property(heart_piece, "global_position", player.global_position + Vector2(0.0, -25.0), 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(heart_piece, "modulate:a", 0.0, 0.3)
		tw.tween_callback(_on_heart_absorbed)
	else:
		_on_heart_absorbed()


func _on_heart_absorbed() -> void:
	var gs: Node = game_state()
	if gs and "current_heart_pieces" in gs:
		gs.current_heart_pieces = maxi(int(gs.current_heart_pieces), HEART_INDEX)
	var codex: Node = get_node_or_null("/root/CodexManager")
	if codex and codex.has_method("unlock_entry"):
		codex.unlock_entry("future_lore_processor_heart")
	advance_quest("claim_heart")
	sword_scream()
	_play_state("heart", ["fut_heart_extract"])


## Anı kırılması: mührün yalanı; ardından kabuk parçalanır
func start_memory_flashback() -> void:
	if flashback:
		flashback.memory_key = "fut_memory_flashback"
		flashback.ability_id = SIXTH_CORE_ABILITY
		flashback.ability_data_key = "ability_unlock_future"
		flashback.ability_chapter_path = CHAPTER_PATH
		flashback.ability_tag_key = "FUT_ABILITY_TAG"
		flashback.play_vlad_memory_sequence()
	else:
		_on_flashback_finished()


func _on_flashback_finished() -> void:
	shatter_sword_shell()


## Tam ekran kabuk parçalanması: VFX + beyaz flaş + sarsıntı + çatlama sesi; 6. çekirdek aurası
func shatter_sword_shell() -> void:
	if shell_broken:
		return
	shell_broken = true
	var gs: Node = game_state()
	if gs and gs.has_method("unlock_ability"):
		gs.unlock_ability(SIXTH_CORE_ABILITY)
	var at: Vector2 = player.global_position + Vector2(0.0, -30.0) if player else Vector2.ZERO
	play_sfx("sfx_sword_shell_crack", at, 0.0)
	FutureFx.play_vfx(self, FutureFx.VFX_SHELL_SHATTER, at, 2.0, 60)
	FutureFx.shake(self, 10.0, 1.0, "fut_sword_shatter")
	_screen_flash()
	refresh_sword_state()
	shell_shattered.emit()
	_play_state("shatter", ["fut_sword_shatter"])


func _screen_flash() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 90
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(0.85, 0.8, 1.0, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	var cm: Node = get_node_or_null("/root/CinematicManager")
	var peak: float = 0.35 if cm and "reduce_flashing" in cm and bool(cm.reduce_flashing) else 0.9
	var tw: Tween = create_tween()
	tw.tween_property(rect, "color:a", peak, 0.08)
	tw.tween_property(rect, "color:a", 0.0, 0.9)
	tw.tween_callback(layer.queue_free)


func _summon_wizard_shadow() -> void:
	play_sfx("sfx_sword_shatter_wizard_laugh", Vector2.INF, 0.0)
	if wizard_shadow:
		create_tween().tween_property(wizard_shadow, "modulate:a", 0.75, 1.4)
	_play_state("wizard", ["fut_wizard_shadow"])


func _play_outro() -> void:
	var alignment: String = LevelStory.get_alignment(self)
	var gs: Node = game_state()
	if gs and gs.has_method("record_ending"):
		alignment = gs.record_ending()
	open_void_rift()
	_play_state("outro", ["fut_outro_god_king" if alignment == "god_king" else "fut_outro_redemption"])


## Bölüm 6 Hiçlik Arenası zaman yırtığı
func open_void_rift() -> void:
	if void_rift:
		void_rift.visible = true
		if void_rift.has_method("open_rift"):
			void_rift.call("open_rift")
	if wizard_shadow:
		create_tween().tween_property(wizard_shadow, "modulate:a", 0.0, 1.2)


func _complete_chapter() -> void:
	if chapter_completed:
		return
	chapter_completed = true
	var gs: Node = game_state()
	if gs and gs.has_method("complete_chapter"):
		gs.complete_chapter("future")
		gs.complete_chapter("chapter_5")
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if autosave_on_complete and save_mgr and save_mgr.has_method("save_game"):
		save_mgr.save_game(int(save_mgr.active_slot) if "active_slot" in save_mgr else 1)
	set_tutorial_keys(PackedStringArray(["FUT_CHAPTER_DONE_TITLE", "FUT_CHAPTER_DONE_SUB", "FUT_CHAPTER_DONE_DESC"]))
	finale_finished.emit(LevelStory.get_alignment(self))
	var next_chapter: String = next_chapter_scene if ResourceLoader.exists(next_chapter_scene) else ""
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_inside_tree():
			ResultsScreen.show_for(self, next_chapter)
	)
