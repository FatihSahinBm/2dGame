extends CanvasLayer
class_name FantasyHUD

## res://scripts/ui/fantasy_hud.gd
## Dark Fantasy Temalı Kapsamlı Oyuncu Arayüzü (HUD)

signal pause_toggled(is_paused: bool)
signal potion_used(potion_type: String)

@export_group("Stats")
@export var max_health: int = 100
@export var current_health: int = 100
@export var max_mana: int = 40
@export var current_mana: int = 40

@export_group("Inventory")
@export var coins: int = 0
@export var keys: int = 0
@export var health_potions: int = 3
@export var mana_potions: int = 2
@export var has_weapon: bool = false
@export var secondary_ammo: int = 5
@export var active_secondary: String = "knife"

# Düğüm Referansları
@onready var health_bar: ProgressBar = $TopLeft/HBoxContainer/BarsVBox/HealthContainer/HealthBar
@onready var health_label: Label = $TopLeft/HBoxContainer/BarsVBox/HealthContainer/HealthLabel
@onready var mana_bar: ProgressBar = $TopLeft/HBoxContainer/BarsVBox/ManaContainer/ManaBar
@onready var mana_label: Label = $TopLeft/HBoxContainer/BarsVBox/ManaContainer/ManaLabel

@onready var coin_label: Label = $TopRight/HBoxContainer/CoinPanel/HBox/CoinLabel
@onready var key_label: Label = $TopRight/HBoxContainer/KeyPanel/HBox/KeyLabel
@onready var quiver_panel: PanelContainer = get_node_or_null("TopRight/HBoxContainer/QuiverPanel") as PanelContainer
@onready var quiver_label: Label = get_node_or_null("TopRight/HBoxContainer/QuiverPanel/HBox/QuiverLabel") as Label
@onready var pause_button: TextureButton = $TopRight/HBoxContainer/PauseButton
@onready var pause_menu: Control = get_node_or_null("PauseMenu") as Control

@onready var sword_slot: TextureRect = $BottomLeft/DiamondContainer/SlotBottom/Icon
@onready var sword_glow: Control = $BottomLeft/DiamondContainer/SlotBottom/ActiveGlow
@onready var potion_red_count: Label = $BottomLeft/DiamondContainer/SlotLeft/CountBadge
@onready var potion_blue_count: Label = $BottomLeft/DiamondContainer/SlotRight/CountBadge
@onready var secondary_slot: Control = get_node_or_null("BottomLeft/DiamondContainer/SlotTop") as Control
@onready var secondary_icon: TextureRect = get_node_or_null("BottomLeft/DiamondContainer/SlotTop/Icon") as TextureRect
@onready var secondary_count: Label = get_node_or_null("BottomLeft/DiamondContainer/SlotTop/CountBadge") as Label
@onready var secondary_key: Label = get_node_or_null("BottomLeft/DiamondContainer/SlotTop/KeyBadge/Label") as Label

# Story 2D-121: Görev ve Hedef Takip Referansları
@onready var objective_tracker: PanelContainer = get_node_or_null("TopLeft/HBoxContainer/BarsVBox/ObjectiveTracker") as PanelContainer
@onready var objective_badge: Label = get_node_or_null("TopLeft/HBoxContainer/BarsVBox/ObjectiveTracker/VBox/HeaderHBox/Badge") as Label
@onready var objective_title: Label = get_node_or_null("TopLeft/HBoxContainer/BarsVBox/ObjectiveTracker/VBox/HeaderHBox/QuestTitle") as Label
@onready var objective_label: Label = get_node_or_null("TopLeft/HBoxContainer/BarsVBox/ObjectiveTracker/VBox/ObjectiveLabel") as Label
@onready var objective_banner: PanelContainer = get_node_or_null("ObjectiveBanner") as PanelContainer
@onready var banner_label: Label = get_node_or_null("ObjectiveBanner/BannerLabel") as Label
@onready var quest_log_dialog: Control = get_node_or_null("QuestLogDialog") as Control

# Story 2D-123: Envanter ve Kalp Parçaları Referansı
@onready var inventory_dialog: Control = get_node_or_null("InventoryDialog") as Control

# Story 2D-122: Düşman Kodeksi ve Bilgi Arşivi Referansı
@onready var codex_dialog: Control = get_node_or_null("CodexDialog") as Control

@onready var tutorial_box: Control = get_node_or_null("BottomRight/TutorialBox") as Control
@onready var tutorial_title: Label = $BottomRight/TutorialBox/HBox/VBox/TitleLabel
@onready var tutorial_key: Label = $BottomRight/TutorialBox/HBox/VBox/KeyContainer/KeyBadge/Label
@onready var tutorial_desc: Label = $BottomRight/TutorialBox/HBox/VBox/KeyContainer/DescLabel

var _health_tween: Tween
var _mana_tween: Tween
var _tutorial_tween: Tween
var _banner_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_pause_system()
	_setup_quest_system()
	_setup_inventory_system()
	update_all()

func _setup_pause_system() -> void:
	if not pause_button:
		pause_button = find_child("PauseButton", true, false) as TextureButton
	if not pause_menu:
		pause_menu = find_child("PauseMenu", true, false) as Control
	if not pause_menu:
		var pause_res = load("res://scenes/ui/pause_menu.tscn")
		if pause_res:
			pause_menu = pause_res.instantiate() as Control
			add_child(pause_menu)
	if pause_menu:
		if pause_menu.has_signal("resumed") and not pause_menu.resumed.is_connected(_on_pause_menu_resumed):
			pause_menu.resumed.connect(_on_pause_menu_resumed)
	if pause_button:
		pause_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pause_button.tooltip_text = "Oyunu Duraklat (ESC / P)"
		if not pause_button.pressed.is_connected(_on_pause_button_pressed):
			pause_button.pressed.connect(_on_pause_button_pressed)

func _on_pause_menu_resumed() -> void:
	pause_toggled.emit(false)

func update_all() -> void:
	update_health(current_health, max_health, false)
	update_mana(current_mana, max_mana, false)
	update_coins(coins)
	update_keys(keys)
	update_weapon_slot(has_weapon)
	update_potion_counts()
	update_secondary_slot(active_secondary, secondary_ammo)

## Can Değerini Güncelle
func update_health(new_health: int, new_max: int = -1, animate: bool = true) -> void:
	if new_max > 0:
		max_health = new_max
	current_health = clampi(new_health, 0, max_health)

	if health_bar:
		health_bar.max_value = max_health
		if animate:
			if _health_tween and _health_tween.is_valid():
				_health_tween.kill()
			_health_tween = create_tween()
			_health_tween.tween_property(health_bar, "value", float(current_health), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			health_bar.value = current_health

	if health_label:
		health_label.text = "%d / %d" % [current_health, max_health]

## Mana Değerini Güncelle
func update_mana(new_mana: int, new_max: int = -1, animate: bool = true) -> void:
	if new_max > 0:
		max_mana = new_max
	current_mana = clampi(new_mana, 0, max_mana)

	if mana_bar:
		mana_bar.max_value = max_mana
		if animate:
			if _mana_tween and _mana_tween.is_valid():
				_mana_tween.kill()
			_mana_tween = create_tween()
			_mana_tween.tween_property(mana_bar, "value", float(current_mana), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			mana_bar.value = current_mana

	if mana_label:
		mana_label.text = "%d / %d" % [current_mana, max_mana]

## Altın Sayısını Güncelle
func update_coins(new_coins: int) -> void:
	coins = maxi(0, new_coins)
	if coin_label:
		coin_label.text = "x %d" % coins

## Anahtar Sayısını Güncelle
func update_keys(new_keys: int) -> void:
	keys = maxi(0, new_keys)
	if key_label:
		key_label.text = "x %d" % keys

## Alevli Sadak Görev Eşyası Görünürlüğü
func set_quiver_visible(show: bool, count: int = 1) -> void:
	if quiver_panel:
		quiver_panel.visible = show
	if quiver_label:
		quiver_label.text = "x %d" % count

## Kılıç / Silah Slotunu Güncelle
func update_weapon_slot(equipped: bool, is_active: bool = true) -> void:
	has_weapon = equipped
	if sword_slot:
		if not equipped:
			sword_slot.modulate = Color(0.4, 0.45, 0.55, 0.6)
		elif is_active:
			sword_slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			sword_slot.modulate = Color(0.75, 0.75, 0.75, 0.8) # Kında (Standby)
	if sword_glow:
		sword_glow.visible = equipped and is_active

## İksir Miktarlarını Güncelle
func update_potion_counts() -> void:
	if potion_red_count:
		potion_red_count.text = str(health_potions)
	if potion_blue_count:
		potion_blue_count.text = str(mana_potions)

## İkincil Fırlatılabilir Eşya Slotunu Güncelle (Story 2D-130)
func update_secondary_slot(item_type: String = "knife", count: int = -1) -> void:
	if count >= 0:
		secondary_ammo = count
	active_secondary = item_type

	if secondary_count:
		secondary_count.text = str(secondary_ammo)
		secondary_count.modulate = Color(1.0, 0.95, 0.7, 1.0) if secondary_ammo > 0 else Color(1.0, 0.35, 0.35, 1.0)

	if secondary_icon:
		match item_type:
			"knife":
				secondary_icon.modulate = Color(0.9, 0.95, 1.0, 1.0)
			"torch":
				secondary_icon.modulate = Color(1.0, 0.65, 0.2, 1.0)
			"holy_water":
				secondary_icon.modulate = Color(0.35, 0.85, 1.0, 1.0)
			_:
				secondary_icon.modulate = Color.WHITE

		if secondary_ammo <= 0:
			secondary_icon.modulate.a = 0.4
		else:
			secondary_icon.modulate.a = 1.0

## Mühimmat Yokken Slot Titremesi ve Kırmızı Flaş (Story 2D-130)
func flash_secondary_empty() -> void:
	if not secondary_slot:
		return

	var orig_pos = secondary_slot.position
	var tw = create_tween()
	tw.tween_property(secondary_slot, "position:x", orig_pos.x - 5.0, 0.04)
	tw.tween_property(secondary_slot, "position:x", orig_pos.x + 5.0, 0.04)
	tw.tween_property(secondary_slot, "position:x", orig_pos.x - 3.0, 0.04)
	tw.tween_property(secondary_slot, "position:x", orig_pos.x, 0.04)
	tw.parallel().tween_property(secondary_slot, "modulate", Color(2.0, 0.4, 0.4, 1.0), 0.08)
	tw.tween_property(secondary_slot, "modulate", Color.WHITE, 0.16)

## İpucu / Görev Kutusunu Güncelle (4 saniye sonra otomatik kaybolur)
func set_tutorial(title: String, key_badge: String, desc: String) -> void:
	if tutorial_title:
		tutorial_title.text = title
	if tutorial_key:
		tutorial_key.text = key_badge
		var key_badge_panel: Control = tutorial_key.get_parent() as Control
		if key_badge_panel:
			key_badge_panel.visible = not key_badge.is_empty()
	if tutorial_desc:
		tutorial_desc.text = desc

	if tutorial_box:
		if _tutorial_tween:
			_tutorial_tween.kill()
		tutorial_box.visible = true
		tutorial_box.modulate.a = 1.0
		_tutorial_tween = create_tween()
		_tutorial_tween.tween_interval(4.0)
		_tutorial_tween.tween_property(tutorial_box, "modulate:a", 0.0, 0.45)
		_tutorial_tween.tween_callback(func():
			if is_instance_valid(tutorial_box):
				tutorial_box.visible = false
		)


func hide_tutorial(immediate: bool = false) -> void:
	if _tutorial_tween:
		_tutorial_tween.kill()
	if not tutorial_box:
		return
	if immediate:
		tutorial_box.visible = false
		tutorial_box.modulate.a = 0.0
	else:
		_tutorial_tween = create_tween()
		_tutorial_tween.tween_property(tutorial_box, "modulate:a", 0.0, 0.25)
		_tutorial_tween.tween_callback(func():
			if is_instance_valid(tutorial_box):
				tutorial_box.visible = false
		)

## Can İksiri Kullan
func use_health_potion() -> void:
	if health_potions > 0 and current_health < max_health:
		health_potions -= 1
		update_health(current_health + 35)
		update_potion_counts()
		potion_used.emit("health")

## Mana İksiri Kullan
func use_mana_potion() -> void:
	if mana_potions > 0 and current_mana < max_mana:
		mana_potions -= 1
		update_mana(current_mana + 20)
		update_potion_counts()
		potion_used.emit("mana")

## Girdi yönetimi: ESC / P / Gamepad START ile duraklatma / devam etme, [J] / [L] ile Görev Günlüğü, [I] / [B] ile Envanter
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var is_escape: bool = event.keycode == KEY_ESCAPE \
			or event.physical_keycode == KEY_ESCAPE \
			or event.is_action_pressed("ui_cancel") \
			or event.is_action_pressed("pause")
		var is_p: bool = event.keycode == KEY_P or event.physical_keycode == KEY_P

		# Envanter açıksa öncelikle onu kapat
		if inventory_dialog and inventory_dialog.visible:
			if is_escape:
				inventory_dialog.close()
				get_viewport().set_input_as_handled()
				return

		# Görev günlüğü açıksa öncelikle onu kapat
		if quest_log_dialog and quest_log_dialog.visible:
			if is_escape:
				quest_log_dialog.close()
				get_viewport().set_input_as_handled()
				return

		# Kodeks açıksa öncelikle onu kapat
		if codex_dialog and codex_dialog.visible:
			if is_escape:
				codex_dialog.close()
				get_viewport().set_input_as_handled()
				return

		if is_escape or is_p:
			toggle_pause()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventJoypadButton and event.pressed and not event.echo:
		if event.button_index == JOY_BUTTON_START:
			toggle_pause()
			get_viewport().set_input_as_handled()
			return

func _unhandled_input(event: InputEvent) -> void:
	# [2] Tuşu ile Can İksiri, [4] Tuşu ile Mana İksiri, [J] / [L] ile Görev Günlüğü, [I] / [B] ile Envanter
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_2 or event.physical_keycode == KEY_2:
			use_health_potion()
		elif event.keycode == KEY_4 or event.physical_keycode == KEY_4:
			use_mana_potion()
		elif event.keycode == KEY_J or event.physical_keycode == KEY_J \
				or event.keycode == KEY_L or event.physical_keycode == KEY_L:
			toggle_quest_log()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_I or event.physical_keycode == KEY_I \
				or event.keycode == KEY_B or event.physical_keycode == KEY_B:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_K or event.physical_keycode == KEY_K \
				or event.keycode == KEY_O or event.physical_keycode == KEY_O:
			toggle_codex()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and not event.echo:
		if event.button_index == JOY_BUTTON_BACK:
			toggle_quest_log()
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_Y:
			toggle_inventory()
			get_viewport().set_input_as_handled()

func _get_scene_tree() -> SceneTree:
	if is_inside_tree() and get_tree():
		return get_tree()
	elif Engine.get_main_loop() is SceneTree:
		return Engine.get_main_loop() as SceneTree
	var p: Node = get_parent()
	while p:
		if p.is_inside_tree() and p.get_tree():
			return p.get_tree()
		if p.has_method("get_tree") and p.get_tree():
			return p.get_tree()
		p = p.get_parent()
	return null

## Oyunu duraklatır veya duraklatmayı kaldırıp devam ettirir
func toggle_pause() -> void:
	_setup_pause_system()
	if pause_menu:
		if pause_menu.visible:
			pause_menu.resume_game()
			pause_toggled.emit(false)
		else:
			pause_menu.open()
			pause_toggled.emit(true)
	else:
		var tree = _get_scene_tree()
		if tree:
			var paused: bool = tree.paused
			tree.paused = not paused
			pause_toggled.emit(not paused)

func _on_pause_button_pressed() -> void:
	toggle_pause()

## Oyunun duraklatılmış olup olmadığını döner
func is_game_paused() -> bool:
	var tree = _get_scene_tree()
	var tree_paused: bool = tree.paused if tree else false
	return tree_paused or (pause_menu != null and pause_menu.visible)


# ==============================================================================
# STORY 2D-121: GÖREV VE HEDEF TAKİP ENTEGRASYONU
# ==============================================================================

func _setup_quest_system() -> void:
	if not quest_log_dialog:
		quest_log_dialog = find_child("QuestLogDialog", true, false) as Control
	if not quest_log_dialog:
		var ql_res = load("res://scenes/ui/quest_log_dialog.tscn")
		if ql_res:
			quest_log_dialog = ql_res.instantiate() as Control
			quest_log_dialog.name = "QuestLogDialog"
			add_child(quest_log_dialog)

	var q_mgr = _get_quest_manager()
	if q_mgr:
		if not q_mgr.tracked_quest_changed.is_connected(_on_tracked_quest_changed):
			q_mgr.tracked_quest_changed.connect(_on_tracked_quest_changed)
		if not q_mgr.objective_completed.is_connected(_on_quest_objective_completed):
			q_mgr.objective_completed.connect(_on_quest_objective_completed)
		if not q_mgr.quest_completed.is_connected(_on_quest_completed_hud):
			q_mgr.quest_completed.connect(_on_quest_completed_hud)
		if not q_mgr.quest_started.is_connected(_on_quest_started_hud):
			q_mgr.quest_started.connect(_on_quest_started_hud)

		update_tracked_objective(q_mgr.get_tracked_quest())
	else:
		if objective_tracker:
			objective_tracker.visible = false


func _get_quest_manager() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		var node = get_tree().root.get_node_or_null("QuestManager")
		if node:
			return node
	if is_inside_tree():
		var fallback = get_node_or_null("/root/QuestManager")
		if fallback:
			return fallback
	return null


## Takip edilen görevin HUD arayüzünü günceller
func update_tracked_objective(quest: Dictionary) -> void:
	if not objective_tracker:
		return
	if quest.is_empty() or quest.get("status") != "active":
		objective_tracker.visible = false
		return

	objective_tracker.visible = true

	var title: String = str(quest.get("title", ""))
	var category: String = str(quest.get("category", "main"))
	if objective_title:
		objective_title.text = title

	if objective_badge:
		if category == "main":
			objective_badge.text = "ANA GÖREV"
		elif category == "side":
			objective_badge.text = "YAN GÖREV"
		else:
			objective_badge.text = category.to_upper()

	var desc: String = ""
	var stages: Array = quest.get("stages", [])
	var curr_idx: int = int(quest.get("current_stage", 0))
	if curr_idx >= 0 and curr_idx < stages.size():
		var st = stages[curr_idx]
		desc = "• " + str(st.get("description", ""))
	elif not stages.is_empty():
		desc = "• " + str(stages[0].get("description", ""))
	else:
		desc = "• " + str(quest.get("description", ""))

	if objective_label:
		objective_label.text = desc


## Ekranın üst-ortasında hedef tamamlama bayrağını (toast) gösterir
func show_objective_complete_banner(text: String, is_quest: bool = false) -> void:
	if not objective_banner:
		return

	if banner_label:
		if is_quest:
			banner_label.text = "🏆 GÖREV TAMAMLANDI!\n" + text
		else:
			banner_label.text = "🎯 HEDEF TAMAMLANDI!\n" + text

	objective_banner.visible = true
	objective_banner.modulate = Color(1, 1, 1, 0)
	objective_banner.position.y = -40.0

	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()

	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(objective_banner, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_property(objective_banner, "position:y", 18.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_banner_tween.chain().tween_interval(2.5)
	_banner_tween.chain().tween_property(objective_banner, "modulate:a", 0.0, 0.4)
	_banner_tween.tween_property(objective_banner, "position:y", -20.0, 0.4)
	_banner_tween.chain().tween_callback(func():
		if is_instance_valid(objective_banner):
			objective_banner.visible = false
	)


## Görev günlüğü penceresini açar veya kapatır
func toggle_quest_log() -> void:
	_setup_quest_system()
	if quest_log_dialog:
		if quest_log_dialog.visible:
			quest_log_dialog.close()
		else:
			quest_log_dialog.open()


func _on_tracked_quest_changed(quest: Dictionary) -> void:
	update_tracked_objective(quest)


func _on_quest_objective_completed(_quest_id: String, _stage_id: String, stage_desc: String) -> void:
	var q_mgr = _get_quest_manager()
	if q_mgr:
		update_tracked_objective(q_mgr.get_tracked_quest())
	show_objective_complete_banner(stage_desc, false)


func _on_quest_completed_hud(quest_id: String, quest: Dictionary) -> void:
	var title = str(quest.get("title", quest_id))
	show_objective_complete_banner(title, true)
	var q_mgr = _get_quest_manager()
	if q_mgr:
		update_tracked_objective(q_mgr.get_tracked_quest())


func _on_quest_started_hud(_quest_id: String, _quest: Dictionary) -> void:
	var q_mgr = _get_quest_manager()
	if q_mgr:
		update_tracked_objective(q_mgr.get_tracked_quest())


# ==============================================================================
# STORY 2D-123: ENVANTER VE KALP PARÇALARI ENTEGRASYONU
# ==============================================================================

func _setup_inventory_system() -> void:
	if not inventory_dialog:
		inventory_dialog = find_child("InventoryDialog", true, false) as Control
	if not inventory_dialog:
		var inv_res = load("res://scenes/ui/inventory_dialog.tscn")
		if inv_res:
			inventory_dialog = inv_res.instantiate() as Control
			inventory_dialog.name = "InventoryDialog"
			add_child(inventory_dialog)

	if inventory_dialog and inventory_dialog.has_signal("item_used"):
		if not inventory_dialog.item_used.is_connected(_on_inventory_item_used):
			inventory_dialog.item_used.connect(_on_inventory_item_used)


## Envanter ve Kalp Parçaları penceresini açar veya kapatır
func toggle_inventory() -> void:
	_setup_inventory_system()
	if inventory_dialog:
		if inventory_dialog.visible:
			inventory_dialog.close()
		else:
			inventory_dialog.open()


func _on_inventory_item_used(_item_id: String) -> void:
	update_all()


# ==============================================================================
# STORY 2D-122: DÜŞMAN KODEKSİ VE DÜNYA BİLGİSİ ENTEGRASYONU
# ==============================================================================

func _setup_codex_system() -> void:
	if not codex_dialog:
		codex_dialog = find_child("CodexDialog", true, false) as Control
	if not codex_dialog:
		var cd_res = load("res://scenes/ui/codex_dialog.tscn")
		if cd_res:
			codex_dialog = cd_res.instantiate() as Control
			codex_dialog.name = "CodexDialog"
			add_child(codex_dialog)


## Düşman kodeksi ve dünya bilgisi arşivini açar veya kapatır
func toggle_codex() -> void:
	_setup_codex_system()
	if codex_dialog:
		if codex_dialog.visible:
			codex_dialog.close()
		else:
			codex_dialog.open()



