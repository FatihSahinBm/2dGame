class_name FutureLevelBase
extends FutureLevelCore

## res://scripts/levels/future/future_level_base.gd
## Bölüm 5 (Distopik Gelecek) seviyelerinin ortak tabanı — Epic 2D-158. Çekirdek akış
## FutureLevelCore'dadır; burada eşya kısayolları, kılıç durumu (6. çekirdek / intikam aurası /
## mühür sızıntısı), kılıç çığlığı ve Son İnsanlık Sığınağı ahlaki seçim yönlendirmesi bulunur.
## Kısayollar: [T] EMP El Bombası, [H] Nano-Tamir Kiti, [V] Faz Kalkanı, [B] Plazma Kesici Fişek,
## [J] Krono-Enjektör. Metinler data/story/chapter_5_future.json ve data/translations altındadır.

const ChapterState = preload("res://scripts/components/future_chapter_state.gd")
const Inventory = preload("res://scripts/components/future_inventory.gd")
const VowAura = preload("res://scripts/effects/sword_vow_aura_vfx.gd")
const SealLeakVfx = preload("res://scripts/effects/sword_seal_leak_vfx.gd")
const SixthCore = preload("res://scripts/effects/sword_sixth_core_vfx.gd")
const SHELTER_QUEST: String = "future_last_shelter"
const PREV_VOW_ABILITY: String = "vengeance_vow_aura"
const PREV_SEAL_ABILITY: String = "sun_seal_fracture"
const SIXTH_CORE_ABILITY: String = "sixth_core_awakening"
const ITEM_KEYS: Dictionary = {
	KEY_T: "emp_grenade", KEY_H: "nano_repair_kit", KEY_V: "phase_shield_capsule",
	KEY_B: "plasma_cutter_flare", KEY_J: "chrono_injector",
}

var _pending_target: Node = null


func _core_ready() -> void:
	refresh_sword_state()
	if dialogue_box and dialogue_box.has_signal("choice_selected"):
		dialogue_box.choice_selected.connect(_on_choice_selected)


## Kılıcın algoritmik çığlığı: SFX + rastgele çığlık metni
func sword_scream() -> void:
	if not player:
		return
	play_sfx("steel_scream", player.global_position, -4.0)
	var lines: Array = LevelStory.StoryLoader.get_dialogue_sequence("fut_sword_scream_texts")
	if not lines.is_empty():
		var pick: Variant = lines.pick_random()
		var text: String = str((pick as Dictionary).get("text", "")) if pick is Dictionary else str(pick)
		float_text(text, player.global_position, Color(0.5, 0.8, 1.0))


## Önceki bölümlerden gelen kılıç durumu (6. çekirdek > intikam aurası > mühür sızıntısı)
func refresh_sword_state() -> void:
	var gs: Node = game_state()
	if not player or gs == null or not gs.has_method("has_ability"):
		return
	if gs.has_ability(SIXTH_CORE_ABILITY):
		SixthCore.attach_to(player, hud)
	elif gs.has_ability(PREV_VOW_ABILITY):
		VowAura.attach_to(player, hud)
	elif gs.has_ability(PREV_SEAL_ABILITY):
		SealLeakVfx.attach_to(player, hud)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or not player or is_transitioning:
		return
	var item_id: String = str(ITEM_KEYS.get((event as InputEventKey).keycode, ""))
	if item_id.is_empty():
		return
	get_viewport().set_input_as_handled()
	use_item(item_id)


func use_item(item_id: String) -> bool:
	var ok: bool = Inventory.use(self, item_id, player)
	if player:
		var def: Dictionary = Inventory.get_definition(item_id)
		var title: String = str(def.get("title_en" if TranslationServer.get_locale().begins_with("en") else "title", item_id))
		float_text(("%s (%d)" % [title, Inventory.count(self, item_id)]) if ok else tr("FUT_FLOAT_NO_ITEM") % title, player.global_position,
			Color(0.6, 1.0, 0.8) if ok else Color(0.8, 0.8, 0.8))
	return ok


# ---------------------------------------------------------------------------
# Son İnsanlık Sığınağı — ahlaki seçim yönlendirmesi (alt sınıflar sonuçları işler)
# ---------------------------------------------------------------------------
func get_rescue_spots() -> Array[FutureRescueSpot]:
	var spots: Array[FutureRescueSpot] = []
	for n: Node in find_children("*", "FutureRescueSpot", true, false):
		spots.append(n as FutureRescueSpot)
	return spots


func connect_rescue_spots(plea_key: String) -> void:
	for spot: FutureRescueSpot in get_rescue_spots():
		spot.interaction_requested.connect(func(s: Node) -> void:
			_pending_target = s
			if not play_story([plea_key] as Array[String], (s as FutureRescueSpot).get_npc()):
				_pending_target = null
		)
		spot.resolved.connect(_on_spot_resolved)


func _on_choice_selected(action: String) -> void:
	var target: Node = _pending_target
	_pending_target = null
	apply_choice(action, target)


## Seçimin oyun durumuna etkisi (testler de doğrudan çağırır)
func apply_choice(action: String, target: Node) -> void:
	if not (target is FutureRescueSpot):
		return
	if action.begins_with("rescue_") or action.begins_with("evacuate_"):
		(target as FutureRescueSpot).rescue()
	elif action.begins_with("exploit_"):
		(target as FutureRescueSpot).exploit(player)


func _on_spot_resolved(spot: FutureRescueSpot, outcome: String) -> void:
	var prefix: String = "fut_survivor" if spot.kind == ChapterState.KIND_SURVIVOR else "fut_engineer"
	match outcome:
		ChapterState.OUTCOME_FREED:
			queue_story(prefix + ("_rescued" if spot.kind == ChapterState.KIND_SURVIVOR else "_evacuated"))
			float_text(tr("FUT_FLOAT_SURVIVOR_SAVED"), spot.global_position, Color(0.5, 1.0, 0.7))
		ChapterState.OUTCOME_DRAINED:
			queue_story(prefix + "_exploited")
			float_text(tr("FUT_FLOAT_LIFE_DRAINED"), spot.global_position, Color(1.0, 0.4, 0.4))
		ChapterState.OUTCOME_KILLED:
			queue_story(prefix + "_killed")
			float_text(tr("FUT_FLOAT_INNOCENT_KILLED"), spot.global_position, Color(1.0, 0.3, 0.3))
	_on_rescue_resolved(spot, outcome)


func _on_rescue_resolved(_spot: FutureRescueSpot, _outcome: String) -> void:
	pass
