class_name Ww2Stage2RuinedCityViaduct
extends Ww2LevelBase

## res://scripts/levels/ww2/stage_2_ruined_city_viaduct.gd
## Bölüm 4 — Sahne 2: Yıkık Şehir & Hareketli Zırhlı Tren Viyadüğü (Epic 2D-144).
## - Dikey yıkık bina platformları; projektör tarama alanları (yakalanınca alarm + takviye).
## - Viyadükte gidip gelen zırhlı tren vagonları üzerinde çatışma ve geçiş.
## - Sessiz Batarya: Şifreli Telsiz Kodları → sahra telsizinden topçu koordinatlarını boz.
## - Easter egg: Kırık Telsiz Frekansı (çağların yankısı).

const SIDE_QUEST: String = "ww2_silent_battery"
const Spawner = preload("res://scripts/enemies/ww2/ww2_spawner.gd")
const MAX_REINFORCEMENT_WAVES: int = 3

@onready var reinforcement_points: Node2D = get_node_or_null("ReinforcementPoints") as Node2D
@onready var train_trigger: Area2D = get_node_or_null("TrainTrigger") as Area2D

var reinforcement_waves: int = 0
var reinforcements: Array[Node2D] = []


func _level_ready() -> void:
	ensure_quest_started(SIDE_QUEST)
	play_story_once(["ww2_city_intro"] as Array[String], 0.8, player)
	for light: Node in find_children("*", "Searchlight", true, false):
		(light as Searchlight).player_spotted.connect(_on_player_spotted)
	for pickup: Node in find_children("*", "Ww2Pickup", true, false):
		(pickup as Ww2Pickup).collected.connect(_on_pickup_collected)
	for radio: Node in find_children("*", "FieldRadio", true, false):
		(radio as FieldRadio).story_requested.connect(func(key: String) -> void: play_story([key] as Array[String]))
		(radio as FieldRadio).battery_sabotaged.connect(_on_battery_sabotaged)
	if train_trigger:
		train_trigger.body_entered.connect(func(b: Node2D) -> void:
			if b == player:
				play_story_once(["ww2_train_intro"] as Array[String], 0.05, player)
				var am: Node = audio()
				if am and am.has_method("play_sound_2d"):
					am.play_sound_2d("train_rail_loop", player.global_position, null, -6.0, 1600.0)
		)
	if Inventory.has_item(self, "radio_codes"):
		advance_quest("find_codes", SIDE_QUEST)


## Projektör yakaladı: alarm hikâyesi + sınırlı sayıda takviye dalgası
func _on_player_spotted(_p: Node2D) -> void:
	play_story_once(["ww2_searchlight_spotted"] as Array[String], 0.05, player)
	if reinforcement_waves >= MAX_REINFORCEMENT_WAVES or Spawner.count_alive(reinforcements) >= 2:
		return
	spawn_reinforcements()


func spawn_reinforcements() -> Array[Node2D]:
	reinforcement_waves += 1
	var points: Array[Vector2] = []
	if reinforcement_points and player:
		var best: Array = reinforcement_points.get_children()
		best.sort_custom(func(a: Node, b: Node) -> bool:
			return absf((a as Node2D).global_position.x - player.global_position.x) < absf((b as Node2D).global_position.x - player.global_position.x))
		for marker: Node in best.slice(0, 2):
			points.append((marker as Node2D).global_position)
	var wave: Array[Node2D] = Spawner.spawn_wave(self, "trench_infantry", points, -1)
	reinforcements.append_array(wave)
	set_tutorial_keys(PackedStringArray(["WW2_ALARM_TITLE", "WW2_ALARM_SUB", "WW2_ALARM_DESC"]))
	return wave


func _on_pickup_collected(item_id: String, _amount: int) -> void:
	if item_id == "radio_codes":
		advance_quest("find_codes", SIDE_QUEST)
		play_story(["ww2_radio_codes_found"] as Array[String], player)


func _on_battery_sabotaged() -> void:
	advance_quest("sabotage_radio", SIDE_QUEST)
	if player:
		float_text(tr("WW2_FLOAT_BATTERY_SILENCED"), player.global_position, Color(0.6, 0.85, 1.0))


func _on_exit_started() -> void:
	advance_quest("cross_viaduct")


func get_exit_story_key() -> String:
	return "ww2_viaduct_exit"
