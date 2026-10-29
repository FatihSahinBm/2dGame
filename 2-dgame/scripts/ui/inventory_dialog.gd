class_name InventoryDialog
extends Control

## res://scripts/ui/inventory_dialog.gd
## Story 2D-123: Kapsamlı Envanter ve Kalp Parçaları Arayüzü (Inventory & World Heart Dialog).
## Tüketilebilir iksirler, ikincil fırlatılabilir silahlar, anahtarlar, akçeler ve
## toplanan Kalp Parçalarının (World Heart Fragments) görsel kadranını yönetir.

signal opened()
signal closed()
signal item_selected(item_id: String, item_data: Dictionary)
signal item_used(item_id: String)
signal secondary_equipped(type: String)

@onready var btn_items_tab: Button = get_node_or_null("Panel/VBox/TabsContainer/BtnItems")
@onready var btn_heart_tab: Button = get_node_or_null("Panel/VBox/TabsContainer/BtnHeart")
@onready var btn_close: Button = get_node_or_null("Panel/VBox/Footer/BtnClose")

# Sol Liste Paneli
@onready var list_scroll: ScrollContainer = get_node_or_null("Panel/VBox/MainSplit/LeftPane/VBox/Scroll")
@onready var item_list_container: VBoxContainer = get_node_or_null("Panel/VBox/MainSplit/LeftPane/VBox/Scroll/ItemList")
@onready var left_title_label: Label = get_node_or_null("Panel/VBox/MainSplit/LeftPane/VBox/HeaderLabel")

# Sağ Detay Paneli
@onready var right_pane: PanelContainer = get_node_or_null("Panel/VBox/MainSplit/RightPane")
@onready var title_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/Header/TitleLabel")
@onready var category_badge: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/Header/CategoryBadge")
@onready var icon_rect: TextureRect = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/IconContainer/ItemIcon")
@onready var count_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/CountHBox/CountLabel")
@onready var desc_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/DescScroll/DescLabel")
@onready var effect_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/EffectLabel")
@onready var shortcut_badge: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/ShortcutContainer/ShortcutBadge")
@onready var shortcut_desc: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/ShortcutContainer/ShortcutDesc")
@onready var action_button: Button = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/ActionContainer/BtnAction")

# Kalp Parçaları Kadranı Paneli
@onready var heart_quadrant_container: Control = get_node_or_null("Panel/VBox/MainSplit/LeftPane/VBox/HeartQuadrantContainer")
@onready var heart_progress_label: Label = get_node_or_null("Panel/VBox/MainSplit/LeftPane/VBox/HeartProgressLabel")

var _current_tab: String = "items" # "items" or "heart"
var _selected_id: String = ""
var _was_paused_before_open: bool = false

# Canlı veriler sözlüğü
var _cached_items: Array[Dictionary] = []
var _cached_heart_pieces: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if btn_items_tab:
		btn_items_tab.pressed.connect(func(): switch_tab("items"))
	if btn_heart_tab:
		btn_heart_tab.pressed.connect(func(): switch_tab("heart"))
	if btn_close:
		btn_close.pressed.connect(close)
	if action_button:
		action_button.pressed.connect(_on_action_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		# [I] veya [B] tuşları ile Envanteri Aç
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_I or event.physical_keycode == KEY_I \
					or event.keycode == KEY_B or event.physical_keycode == KEY_B:
				open()
				get_viewport().set_input_as_handled()
		return

	# Envanter açıkken: Kapatma ve Sekme Kontrolleri ([ESC], [I], [B], [TAB], Gamepad)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE \
				or event.keycode == KEY_I or event.physical_keycode == KEY_I \
				or event.keycode == KEY_B or event.physical_keycode == KEY_B:
			close()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB:
			switch_tab("heart" if _current_tab == "items" else "items")
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventJoypadButton and event.pressed and not event.echo:
		if event.button_index == JOY_BUTTON_B or event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_BACK:
			close()
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == JOY_BUTTON_Y:
			switch_tab("heart" if _current_tab == "items" else "items")
			get_viewport().set_input_as_handled()
			return


## Envanter penceresini açar ve oyunu duraklatır
func open() -> void:
	_was_paused_before_open = get_tree().paused
	get_tree().paused = true
	visible = true

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("inventory_open", -1.0)

	refresh_inventory()
	opened.emit()


## Envanter penceresini kapatır ve duraklatma durumunu geri yükler
func close() -> void:
	if not _was_paused_before_open:
		get_tree().paused = false
	visible = false

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("inventory_close", -1.0)

	closed.emit()


## Sekmeler arası geçiş yapar ("items" veya "heart")
func switch_tab(tab_name: String) -> void:
	if _current_tab == tab_name:
		return
	_current_tab = tab_name
	_selected_id = ""

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", -3.0)

	_update_tab_buttons_style()
	refresh_inventory()


func _update_tab_buttons_style() -> void:
	if btn_items_tab:
		if _current_tab == "items":
			btn_items_tab.modulate = Color(1.2, 1.1, 0.7, 1.0)
		else:
			btn_items_tab.modulate = Color(0.8, 0.85, 0.9, 0.8)

	if btn_heart_tab:
		if _current_tab == "heart":
			btn_heart_tab.modulate = Color(1.2, 0.8, 0.8, 1.0)
		else:
			btn_heart_tab.modulate = Color(0.8, 0.85, 0.9, 0.8)


## Tüm envanter ve Kalp Parçaları verilerini derler ve arayüzü günceller
func refresh_inventory() -> void:
	_fetch_live_data()

	if _current_tab == "items":
		if list_scroll: list_scroll.visible = true
		if heart_quadrant_container: heart_quadrant_container.visible = false
		if heart_progress_label: heart_progress_label.visible = false
		if left_title_label: left_title_label.text = "ÇANTA VE DONANIM"
		_populate_items_list()
	else:
		if list_scroll: list_scroll.visible = false
		if heart_quadrant_container: heart_quadrant_container.visible = true
		if heart_progress_label: heart_progress_label.visible = true
		if left_title_label: left_title_label.text = "DÜNYA KALBİ KADRANI"
		_populate_heart_quadrant()


## HUD, Player ve GameState üzerinden canlı oyun verilerini toplar
func _fetch_live_data() -> void:
	_cached_items.clear()
	_cached_heart_pieces.clear()

	var hud = _find_hud()
	var player = _find_player()
	var game_state = get_node_or_null("/root/GameState")

	# 1. Tüketilebilir İksirler
	var health_pots: int = hud.health_potions if (hud and "health_potions" in hud) else 3
	var mana_pots: int = hud.mana_potions if (hud and "mana_potions" in hud) else 2
	var cur_hp: int = hud.current_health if (hud and "current_health" in hud) else 100
	var max_hp: int = hud.max_health if (hud and "max_health" in hud) else 100
	var cur_mp: int = hud.current_mana if (hud and "current_mana" in hud) else 40
	var max_mp: int = hud.max_mana if (hud and "max_mana" in hud) else 40

	_cached_items.append({
		"id": "health_potion",
		"category": "consumable",
		"title": "Kırmızı Can İksiri",
		"icon_path": "res://scenes/ui/icons/icon_potion_red.png",
		"count": health_pots,
		"description": "Simyacılar tarafından yabani dağ otları ve nehir suyuyla kaynatılmış şifalı karışım. İçildiğinde bedeni canlandırır.",
		"effect": "+35 Can Puanı (Mevcut Can: %d / %d)" % [cur_hp, max_hp],
		"shortcut": "[2]",
		"can_use": (health_pots > 0 and cur_hp < max_hp),
		"action_text": "İksiri İç (+35 Can)"
	})

	_cached_items.append({
		"id": "mana_potion",
		"category": "consumable",
		"title": "Mavi Mana İksiri",
		"icon_path": "res://scenes/ui/icons/icon_potion_blue.png",
		"count": mana_pots,
		"description": "Yeraltı mağaralarından çıkarılan safir kristalleri özü. Büyülü enerjiyi ve ruhani gücü tazeler.",
		"effect": "+20 Mana Puanı (Mevcut Mana: %d / %d)" % [cur_mp, max_mp],
		"shortcut": "[4]",
		"can_use": (mana_pots > 0 and cur_mp < max_mp),
		"action_text": "İksiri İç (+20 Mana)"
	})

	# 2. Fırlatılabilir İkincil Silahlar
	var sec_inv: Dictionary = {"knife": 5, "torch": 3, "holy_water": 2}
	var active_sec: String = "knife"
	if player:
		if "secondary_inventory" in player and player.secondary_inventory is Dictionary:
			sec_inv = player.secondary_inventory
		if "active_secondary_type" in player:
			active_sec = str(player.active_secondary_type)

	_cached_items.append({
		"id": "secondary_knife",
		"category": "secondary",
		"sec_type": "knife",
		"title": "Fırlatma Bıçağı",
		"icon_path": "res://scenes/ui/icons/icon_sword_slot.png",
		"count": int(sec_inv.get("knife", 0)),
		"description": "Dengeli dövme çelik bıçak. Hızlı doğrusal uçuşla zırhsız hedeflere ve hortlaklara doğrudan hasar verir. Katı ahşap ve taş duvarlara saplanır.",
		"effect": "30 Delici Hasar (Duvara Saplanabilir)",
		"shortcut": "[5] / [F]",
		"is_equipped": (active_sec == "knife"),
		"can_use": true,
		"action_text": "Kuşanılmış (Aktif)" if active_sec == "knife" else "Hızlı Yuvaya Ata ([F])"
	})

	_cached_items.append({
		"id": "secondary_torch",
		"category": "secondary",
		"sec_type": "torch",
		"title": "Alevli Meşale",
		"icon_path": "res://scenes/ui/icons/icon_potion_red.png",
		"count": int(sec_inv.get("torch", 0)),
		"description": "Zift ve kuru bezle sarılmış el meşalesi. Parabolik yayla fırlatılır; yanabilir sarmaşıkları ve barikatları kül eder, zeminde geçici alev alanı bırakır.",
		"effect": "25 Ateş Hasarı + Zemin Yangını + Barikat Yıkımı",
		"shortcut": "[6] / [F]",
		"is_equipped": (active_sec == "torch"),
		"can_use": true,
		"action_text": "Kuşanılmış (Aktif)" if active_sec == "torch" else "Hızlı Yuvaya Ata ([F])"
	})

	_cached_items.append({
		"id": "secondary_holy_water",
		"category": "secondary",
		"sec_type": "holy_water",
		"title": "Kutsal Su Şişesi",
		"icon_path": "res://scenes/ui/icons/icon_crystal.png",
		"count": int(sec_inv.get("holy_water", 0)),
		"description": "Mabette kutsanmış saf gümüş şişe. Çarptığı yerde kutsanmış zemin alanı açar; yalnızca vampir, undead ve Vlad'ın kan hizmetkarlarına ağır hasar verir.",
		"effect": "45 Kutsal Hasar (Yalnızca Unholy/Vampir Düşmanlar)",
		"shortcut": "[7] / [F]",
		"is_equipped": (active_sec == "holy_water"),
		"can_use": true,
		"action_text": "Kuşanılmış (Aktif)" if active_sec == "holy_water" else "Hızlı Yuvaya Ata ([F])"
	})

	# 3. Değerli Eşyalar ve Anahtarlar
	var coins: int = hud.coins if (hud and "coins" in hud) else 0
	var keys: int = hud.keys if (hud and "keys" in hud) else 0

	_cached_items.append({
		"id": "coins",
		"category": "currency",
		"title": "Osmanlı Akçesi",
		"icon_path": "res://scenes/ui/icons/icon_coin.png",
		"count": coins,
		"description": "Gümüş Osmanlı sikkeleri. Ordugah ikmalcilerinden ve seyyar dervişlerden erzak, iksir ve cephane temin etmek için kullanılır.",
		"effect": "Harcanabilir Para Birimi",
		"shortcut": "",
		"can_use": false,
		"action_text": "Pasif Eşya"
	})

	_cached_items.append({
		"id": "keys",
		"category": "key",
		"title": "Zindan Demir Anahtarı",
		"icon_path": "res://scenes/ui/icons/icon_key.png",
		"count": keys,
		"description": "Eflak kalesinin kalın demir parmaklıklarını ve zindan hücre kapılarını açan ağır döküm anahtar.",
		"effect": "Kilitli Geçitleri Açar",
		"shortcut": "",
		"can_use": false,
		"action_text": "Pasif Eşya"
	})

	var has_sword: bool = (player and player.get("has_sword")) or (hud and hud.get("has_weapon"))
	_cached_items.append({
		"id": "weapon_sword",
		"category": "equipment",
		"title": "Padişah Yadigarı Kılıç",
		"icon_path": "res://scenes/ui/icons/icon_sword_slot.png",
		"count": 1 if has_sword else 0,
		"description": "Fatih Sultan Mehmed Han tarafından sefer öncesi hediye edilen çift ağızlı çelik pala. Hafif ve keskin.",
		"effect": "Temel Silah — 3 Aşamalı Kombo Saldırısı",
		"shortcut": "[Sol Tık / X]",
		"can_use": false,
		"action_text": "Kuşanılmış Silah"
	})

	# 4. Kalp Parçaları Verileri (4 Parçalı Kadran)
	var heart_count: int = game_state.current_heart_pieces if (game_state and "current_heart_pieces" in game_state) else 1

	_cached_heart_pieces = [
		{
			"id": "heart_fragment_1",
			"index": 1,
			"title": "1. Kadim Yankı (Taş Devri)",
			"era": "Taş Devri — T-Rex Krateri",
			"ability": "Kalp Rezonansı (Heart Resonance)",
			"unlocked": (heart_count >= 1),
			"icon_path": "res://scenes/ui/icons/icon_heart.png",
			"description": "Taş Devri'nde zaman çatlağını bekleyen kadim T-Rex'in ruhundan saçılan ilk Kalp Parçası. Taşıyıcısına zaman yankılarını algılama ve mistik rezonans yeteneği bahşeder.",
			"bonus_text": "⚡ Pasif Bonus: Çevre sırlarını algılama ve çatlak titreşimi"
		},
		{
			"id": "heart_fragment_2",
			"index": 2,
			"title": "2. Kan Mührü (Eflak Kalesi)",
			"era": "Orta Çağ — Vlad Tepeş'in Mahzenleri",
			"ability": "Gölge Adımı & Kan Kalkanı (Blood Veil)",
			"unlocked": (heart_count >= 2),
			"icon_path": "res://scenes/ui/icons/icon_heart.png",
			"description": "Vlad Tepeş'in zindanlarında ve taht odasında vampir kanıyla mühürlenmiş ikinci parça. Karanlık güçlere karşı yüksek mukavemet ve gölge atılması sağlar.",
			"bonus_text": "🛡️ Pasif Bonus: +%10 Maksimum Can ve Kutsal Hasar Direnci"
		},
		{
			"id": "heart_fragment_3",
			"index": 3,
			"title": "3. Güneş Çarkı (Antik Dünya)",
			"era": "Antik Çağ — Ra Mabedi ve Piramitler",
			"ability": "Güneş Patlaması (Solar Flare)",
			"unlocked": (heart_count >= 3),
			"icon_path": "res://scenes/ui/icons/icon_heart.png",
			"description": "Güneş ışınlarının ilk piramit zirvesine vurduğu anda kristalleşen üçüncü Kalp Parçası. Zamandaki sıcaklık dalgalanmalarını durdurur.",
			"bonus_text": "☀️ Pasif Bonus: Mana yenilenme hızında +%25 artış"
		},
		{
			"id": "heart_fragment_4",
			"index": 4,
			"title": "4. Sonsuzluk Çekirdeği (Zamanın Sonu)",
			"era": "Kozmik Çağ — Çöküşün Eşiği",
			"ability": "Dünya Kalbi Birleşimi (World Heart Rebirth)",
			"unlocked": (heart_count >= 4),
			"icon_path": "res://scenes/ui/icons/icon_heart.png",
			"description": "Tüm zaman çizgilerini birbirine bağlayan nihai çekirdek. Dört parça bir araya geldiğinde Dünya Kalbi yeniden dövülür ve kıyamet engellenir.",
			"bonus_text": "👑 Nihai Yetenek: Zamanı Bükme ve Sonsuz Yaşam"
		}
	]


## Eşyalar listesini oluşturur
func _populate_items_list() -> void:
	if not item_list_container:
		return

	for ch in item_list_container.get_children():
		ch.queue_free()

	if _cached_items.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Çantanızda henüz eşya bulunmuyor."
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7, 0.8))
		item_list_container.add_child(empty_lbl)
		_show_item_detail({})
		return

	# Eğer seçili eşya yoksa veya geçersizse ilkini seç
	var found_selected: bool = false
	for item in _cached_items:
		if item["id"] == _selected_id:
			found_selected = true
			break
	if not found_selected:
		_selected_id = str(_cached_items[0]["id"])

	# Butonları oluştur
	for item in _cached_items:
		var btn = Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 36)

		var prefix = ""
		match item.get("category", ""):
			"consumable": prefix = "🧪 "
			"secondary": prefix = "🗡️ "
			"currency": prefix = "🪙 "
			"key": prefix = "🗝️ "
			"equipment": prefix = "⚔️ "

		var count_str = ""
		if item.has("count"):
			count_str = " (x%d)" % int(item["count"])

		var equip_str = " [KUŞANILDI]" if item.get("is_equipped", false) else ""

		btn.text = prefix + str(item.get("title", "")) + count_str + equip_str
		btn.add_theme_font_size_override("font_size", 11)

		if item["id"] == _selected_id:
			btn.modulate = Color(1.2, 1.1, 0.6, 1.0)
		else:
			btn.modulate = Color(0.9, 0.92, 0.96, 0.9)

		var itm_id = item["id"]
		btn.pressed.connect(func():
			select_item(itm_id)
		)

		item_list_container.add_child(btn)

	var cur_data = get_item_data(_selected_id)
	_show_item_detail(cur_data)


## Kalp Parçaları Kadranını oluşturur
func _populate_heart_quadrant() -> void:
	var game_state = get_node_or_null("/root/GameState")
	var heart_count: int = game_state.current_heart_pieces if (game_state and "current_heart_pieces" in game_state) else 1

	if heart_progress_label:
		var pct = int((float(heart_count) / 4.0) * 100.0)
		heart_progress_label.text = "Dünya Kalbi Bütünlüğü: %d / 4 Parça (%%%d)" % [heart_count, pct]

	if heart_quadrant_container:
		for i in range(1, 5):
			var slot_btn: Button = heart_quadrant_container.get_node_or_null("QuadrantSlot%d" % i) as Button
			if slot_btn:
				var is_unlocked: bool = (i <= heart_count)
				var mark = "💎" if is_unlocked else "🔒"
				slot_btn.text = "%s Parça %d" % [mark, i]
				slot_btn.modulate = Color(1.2, 0.9, 0.3, 1.0) if is_unlocked else Color(0.5, 0.55, 0.6, 0.7)

				var piece_id = "heart_fragment_%d" % i
				if not slot_btn.pressed.is_connected(select_item.bind(piece_id)):
					slot_btn.pressed.connect(select_item.bind(piece_id))

	if _selected_id.is_empty() or not _selected_id.begins_with("heart_fragment_"):
		_selected_id = "heart_fragment_1"

	var cur_data = get_heart_piece_data(_selected_id)
	_show_heart_piece_detail(cur_data)


## Eşya seçer ve detayları tazeler
func select_item(item_id: String) -> void:
	_selected_id = item_id

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", -4.0)

	if _current_tab == "items":
		_populate_items_list()
	else:
		_populate_heart_quadrant()

	var data = get_item_data(item_id) if _current_tab == "items" else get_heart_piece_data(item_id)
	item_selected.emit(item_id, data)


func get_item_data(item_id: String) -> Dictionary:
	for item in _cached_items:
		if item.get("id") == item_id:
			return item
	return {}


func get_heart_piece_data(piece_id: String) -> Dictionary:
	for hp in _cached_heart_pieces:
		if hp.get("id") == piece_id:
			return hp
	return {}


func _show_item_detail(item: Dictionary) -> void:
	if item.is_empty():
		if title_label: title_label.text = "Eşya Seçilmedi"
		if category_badge: category_badge.visible = false
		if desc_label: desc_label.text = ""
		if effect_label: effect_label.text = ""
		if count_label: count_label.text = ""
		if shortcut_badge: shortcut_badge.visible = false
		if shortcut_desc: shortcut_desc.text = ""
		if action_button: action_button.visible = false
		return

	if title_label:
		title_label.text = str(item.get("title", ""))

	if category_badge:
		category_badge.visible = true
		match item.get("category", ""):
			"consumable":
				category_badge.text = "🧪 TÜKETİLEBİLİR İKSİR"
				category_badge.modulate = Color(0.4, 0.9, 1.0, 1.0)
			"secondary":
				category_badge.text = "🗡️ FIRLATILABİLİR İKİNCİL SİLAH"
				category_badge.modulate = Color(1.0, 0.75, 0.3, 1.0)
			"currency":
				category_badge.text = "🪙 DEĞERLİ PARA"
				category_badge.modulate = Color(1.0, 0.9, 0.2, 1.0)
			"key":
				category_badge.text = "🗝️ ÖZEL GÖREV / ZİNDAN ANAHTARI"
				category_badge.modulate = Color(0.8, 0.6, 1.0, 1.0)
			"equipment":
				category_badge.text = "⚔️ KUŞANILABİLİR ANA SİLAH"
				category_badge.modulate = Color(0.9, 0.4, 0.4, 1.0)

	if count_label:
		count_label.text = "Taşınan Miktar: %d" % int(item.get("count", 0))

	if desc_label:
		desc_label.text = str(item.get("description", ""))

	if effect_label:
		effect_label.text = "⚡ Etki: %s" % str(item.get("effect", ""))

	var sc = str(item.get("shortcut", ""))
	if shortcut_badge and shortcut_desc:
		if not sc.is_empty():
			shortcut_badge.visible = true
			shortcut_badge.text = sc
			shortcut_desc.visible = true
			shortcut_desc.text = "Klavye Kısayolu"
		else:
			shortcut_badge.visible = false
			shortcut_desc.visible = false

	if action_button:
		var cat = item.get("category", "")
		if cat in ["consumable", "secondary"]:
			action_button.visible = true
			action_button.text = str(item.get("action_text", "Kullan"))
			action_button.disabled = not bool(item.get("can_use", false))
		else:
			action_button.visible = false

	if icon_rect and item.has("icon_path"):
		var icon_res = load(item["icon_path"])
		if icon_res is Texture2D:
			icon_rect.texture = icon_res


func _show_heart_piece_detail(hp: Dictionary) -> void:
	if hp.is_empty():
		return

	var is_unlocked = bool(hp.get("unlocked", false))

	if title_label:
		title_label.text = str(hp.get("title", ""))

	if category_badge:
		category_badge.visible = true
		if is_unlocked:
			category_badge.text = "💎 KALINTI PARÇASI (TOPLANDI)"
			category_badge.modulate = Color(1.0, 0.85, 0.2, 1.0)
		else:
			category_badge.text = "🔒 KİLİTLİ KALINTI (HENÜZ BULUNMADI)"
			category_badge.modulate = Color(0.6, 0.65, 0.7, 0.8)

	if count_label:
		count_label.text = "Çağ: %s" % str(hp.get("era", ""))

	if desc_label:
		desc_label.text = str(hp.get("description", ""))

	if effect_label:
		effect_label.text = str(hp.get("bonus_text", ""))

	if shortcut_badge and shortcut_desc:
		shortcut_badge.visible = is_unlocked
		shortcut_badge.text = str(hp.get("ability", ""))
		shortcut_desc.visible = is_unlocked
		shortcut_desc.text = "Kazanılan Yetenek"

	if action_button:
		action_button.visible = true
		if is_unlocked:
			action_button.text = "✨ Rezonans Aktif"
			action_button.disabled = true
		else:
			action_button.text = "🔒 Parça Kilitli"
			action_button.disabled = true

	if icon_rect:
		var heart_tex = load("res://scenes/ui/icons/icon_heart.png")
		if heart_tex is Texture2D:
			icon_rect.texture = heart_tex
			icon_rect.modulate = Color(1.3, 0.4, 0.4, 1.0) if is_unlocked else Color(0.3, 0.35, 0.4, 0.6)


## Aksiyon butonuna tıklandığında (İksir iç veya ikincil silah seç)
func _on_action_pressed() -> void:
	if _current_tab != "items" or _selected_id.is_empty():
		return

	var itm = get_item_data(_selected_id)
	if itm.is_empty() or not itm.get("can_use", false):
		return

	var hud = _find_hud()
	var player = _find_player()
	var audio_mgr = get_node_or_null("/root/AudioManager")

	if _selected_id == "health_potion":
		if hud and hud.has_method("use_health_potion"):
			hud.use_health_potion()
		elif player and "current_health" in player and "max_health" in player:
			player.current_health = mini(player.current_health + 35, player.max_health)
			if player.has_signal("player_damaged"):
				player.player_damaged.emit(player.current_health, player.max_health)

		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("potion_drink", 0.0)

		item_used.emit("health_potion")
		refresh_inventory()

	elif _selected_id == "mana_potion":
		if hud and hud.has_method("use_mana_potion"):
			hud.use_mana_potion()

		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("potion_drink", 0.0)

		item_used.emit("mana_potion")
		refresh_inventory()

	elif itm.get("category") == "secondary":
		var sec_type = str(itm.get("sec_type", ""))
		if player and player.has_method("select_secondary"):
			player.select_secondary(sec_type)
		elif hud and hud.has_method("update_secondary_slot"):
			hud.update_secondary_slot(sec_type, int(itm.get("count", 0)))

		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("item_equip", 0.0)

		secondary_equipped.emit(sec_type)
		refresh_inventory()


func _find_hud() -> CanvasLayer:
	if is_inside_tree() and get_tree():
		var huds = get_tree().get_nodes_in_group("hud")
		if not huds.is_empty():
			return huds[0] as CanvasLayer
		var scene = get_tree().current_scene if get_tree().current_scene else get_tree().root
		if scene:
			if scene is FantasyHUD:
				return scene
			var hud_node = scene.get_node_or_null("FantasyHUD")
			if hud_node: return hud_node as CanvasLayer
			hud_node = scene.find_child("FantasyHUD", true, false)
			if hud_node: return hud_node as CanvasLayer
			for ch in scene.get_children():
				if ch is FantasyHUD:
					return ch
	var p = get_parent()
	if p is FantasyHUD:
		return p
	return null


func _find_player() -> CharacterBody2D:
	if is_inside_tree() and get_tree():
		var p_nodes = get_tree().get_nodes_in_group("player")
		if not p_nodes.is_empty():
			return p_nodes[0] as CharacterBody2D
		var scene = get_tree().current_scene if get_tree().current_scene else get_tree().root
		if scene:
			var player_node = scene.get_node_or_null("CombatPlayer")
			if player_node: return player_node as CharacterBody2D
			player_node = scene.find_child("CombatPlayer", true, false)
			if player_node: return player_node as CharacterBody2D
			for ch in scene.get_children():
				if ch.is_in_group("player") or "secondary_inventory" in ch:
					return ch as CharacterBody2D
	return null
