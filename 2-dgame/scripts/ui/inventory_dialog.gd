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

const HEART_PIECE_TOTAL: int = 6
const Ww2Items = preload("res://scripts/ui/ww2_inventory_items.gd")
const FutureItems = preload("res://scripts/ui/future_inventory_items.gd")

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

	var loc_mgr = get_node_or_null("/root/LocalizationManager")
	if loc_mgr and loc_mgr.has_signal("locale_changed"):
		if not loc_mgr.locale_changed.is_connected(_on_locale_changed):
			loc_mgr.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_new_locale: String) -> void:
	if visible:
		refresh_inventory()


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
			if get_viewport():
				get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB:
			switch_tab("heart" if _current_tab == "items" else "items")
			if get_viewport():
				get_viewport().set_input_as_handled()
			return
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B or event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_BACK:
			close()
			if get_viewport():
				get_viewport().set_input_as_handled()
			return
		elif event.button_index == JOY_BUTTON_Y or event.button_index == JOY_BUTTON_LEFT_SHOULDER or event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			switch_tab("heart" if _current_tab == "items" else "items")
			if get_viewport():
				get_viewport().set_input_as_handled()
			return


## Envanter penceresini açar ve oyunu duraklatır
func open() -> void:
	if get_tree():
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
	if not _was_paused_before_open and get_tree():
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


func _is_english() -> bool:
	var loc_mgr = get_node_or_null("/root/LocalizationManager")
	if loc_mgr and loc_mgr.has_method("get_current_locale"):
		if str(loc_mgr.get_current_locale()).to_lower().begins_with("en"):
			return true
	if TranslationServer.has_method("get_locale"):
		if str(TranslationServer.get_locale()).to_lower().begins_with("en"):
			return true
	return false


func _update_tab_buttons_style() -> void:
	var is_en: bool = _is_english()
	if btn_items_tab:
		btn_items_tab.text = "🎒 Satchel & Gear" if is_en else "🎒 Çanta ve Donanım"
		if _current_tab == "items":
			btn_items_tab.modulate = Color(1.2, 1.1, 0.7, 1.0)
		else:
			btn_items_tab.modulate = Color(0.8, 0.85, 0.9, 0.8)

	if btn_heart_tab:
		btn_heart_tab.text = "💖 World Heart" if is_en else "💖 Dünya Kalbi Kadranı"
		if _current_tab == "heart":
			btn_heart_tab.modulate = Color(1.2, 0.8, 0.8, 1.0)
		else:
			btn_heart_tab.modulate = Color(0.8, 0.85, 0.9, 0.8)


## Tüm envanter ve Kalp Parçaları verilerini derler ve arayüzü günceller
func refresh_inventory() -> void:
	_fetch_live_data()
	var is_en: bool = _is_english()

	var main_title = get_node_or_null("Panel/VBox/HeaderBar/MainTitle") as Label
	if main_title:
		main_title.text = "🎒 TRAVELER'S LEATHER SATCHEL" if is_en else "🎒 GEZGİNİN DERİ SIRT ÇANTASI & ENVANTER"
	var key_hint = get_node_or_null("Panel/VBox/HeaderBar/KeyHint") as Label
	if key_hint:
		var input_mgr = get_node_or_null("/root/InputControllerManager")
		var is_gamepad: bool = (input_mgr != null and int(input_mgr.get("current_scheme")) == 1)
		var is_ps: bool = (input_mgr != null and int(input_mgr.get("current_gamepad_type")) == 2)
		if is_gamepad:
			var close_str := "[◯ / OPTIONS]" if is_ps else "[B / MENU]"
			var tab_str := "[L1 / R1 / △]" if is_ps else "[LB / RB / Y]"
			key_hint.text = "%s Close  |  %s Switch Tab" % [close_str, tab_str] if is_en else "%s Kapat  |  %s Sekme Değiştir" % [close_str, tab_str]
		else:
			key_hint.text = "[I / B / ESC] Close  |  [TAB] Switch Tab" if is_en else "[I / B / ESC] Kapat  |  [TAB] Sekme Değiştir"
	if btn_close:
		btn_close.text = "✖ Close (ESC)" if is_en else "✖ Kapat (ESC)"

	if _current_tab == "items":
		if list_scroll: list_scroll.visible = true
		if heart_quadrant_container: heart_quadrant_container.visible = false
		if heart_progress_label: heart_progress_label.visible = false
		if left_title_label: left_title_label.text = "SATCHEL & GEAR" if is_en else "ÇANTA VE DONANIM"
		_populate_items_list()
	else:
		if list_scroll: list_scroll.visible = false
		if heart_quadrant_container: heart_quadrant_container.visible = true
		if heart_progress_label: heart_progress_label.visible = true
		if left_title_label: left_title_label.text = "WORLD HEART CHRONOMETER" if is_en else "DÜNYA KALBİ KADRANI"
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
		"title_en": "Crimson Health Potion",
		"icon_path": "res://scenes/ui/icons/icon_potion_red.png",
		"count": health_pots,
		"description": "Simyacılar tarafından yabani dağ otları ve nehir suyuyla kaynatılmış şifalı karışım. İçildiğinde bedeni canlandırır.",
		"description_en": "Alchemical draught brewed from crimson wild roots and mountain spring water. Restores vitality instantly.",
		"effect": "+35 Can Puanı (Mevcut Can: %d / %d)" % [cur_hp, max_hp],
		"effect_en": "+35 Health Points (Current HP: %d / %d)" % [cur_hp, max_hp],
		"shortcut": "[2]",
		"can_use": (health_pots > 0 and cur_hp < max_hp),
		"action_text": "İksiri İç (+35 Can)",
		"action_text_en": "Drink Potion (+35 HP)"
	})

	_cached_items.append({
		"id": "mana_potion",
		"category": "consumable",
		"title": "Mavi Mana İksiri",
		"title_en": "Azure Mana Potion",
		"icon_path": "res://scenes/ui/icons/icon_potion_blue.png",
		"count": mana_pots,
		"description": "Yeraltı mağaralarından çıkarılan safir kristalleri özü. Büyülü enerjiyi ve ruhani gücü tazeler.",
		"description_en": "Distilled sapphire crystal essence extracted from cavern deeps. Refreshes magical and spiritual power.",
		"effect": "+20 Mana Puanı (Mevcut Mana: %d / %d)" % [cur_mp, max_mp],
		"effect_en": "+20 Mana Points (Current Mana: %d / %d)" % [cur_mp, max_mp],
		"shortcut": "[4]",
		"can_use": (mana_pots > 0 and cur_mp < max_mp),
		"action_text": "İksiri İç (+20 Mana)",
		"action_text_en": "Drink Potion (+20 Mana)"
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
		"title_en": "Throwing Knife",
		"icon_path": "res://scenes/ui/icons/icon_sword_slot.png",
		"count": int(sec_inv.get("knife", 0)),
		"description": "Dengeli dövme çelik bıçak. Hızlı doğrusal uçuşla zırhsız hedeflere ve hortlaklara doğrudan hasar verir. Katı ahşap ve taş duvarlara saplanır.",
		"description_en": "Balanced forged steel blade. Delivers swift piercing damage in straight flight. Embeds firmly into wooden and stone walls.",
		"effect": "30 Delici Hasar (Duvara Saplanabilir)",
		"effect_en": "30 Piercing Damage (Embeds into walls)",
		"shortcut": "[5] / [F]",
		"is_equipped": (active_sec == "knife"),
		"can_use": true,
		"action_text": "Kuşanılmış (Aktif)" if active_sec == "knife" else "Hızlı Yuvaya Ata ([F])",
		"action_text_en": "Equipped (Active)" if active_sec == "knife" else "Assign to Quick Slot ([F])"
	})

	_cached_items.append({
		"id": "secondary_torch",
		"category": "secondary",
		"sec_type": "torch",
		"title": "Alevli Meşale",
		"title_en": "Flaming Torch",
		"icon_path": "res://scenes/ui/icons/icon_potion_red.png",
		"count": int(sec_inv.get("torch", 0)),
		"description": "Zift ve kuru bezle sarılmış el meşalesi. Parabolik yayla fırlatılır; yanabilir sarmaşıkları ve barikatları kül eder, zeminde geçici alev alanı bırakır.",
		"description_en": "Hand torch bound with pitch and linen. Thrown in a high arc; incinerates dry vines and barricades, creating a fiery ground patch.",
		"effect": "25 Ateş Hasarı + Zemin Yangını + Barikat Yıkımı",
		"effect_en": "25 Fire Damage + Ground Blaze + Barricade Breaker",
		"shortcut": "[6] / [F]",
		"is_equipped": (active_sec == "torch"),
		"can_use": true,
		"action_text": "Kuşanılmış (Aktif)" if active_sec == "torch" else "Hızlı Yuvaya Ata ([F])",
		"action_text_en": "Equipped (Active)" if active_sec == "torch" else "Assign to Quick Slot ([F])"
	})

	_cached_items.append({
		"id": "secondary_holy_water",
		"category": "secondary",
		"sec_type": "holy_water",
		"title": "Kutsal Su Şişesi",
		"title_en": "Holy Water Flask",
		"icon_path": "res://scenes/ui/icons/icon_crystal.png",
		"count": int(sec_inv.get("holy_water", 0)),
		"description": "Mabette kutsanmış saf gümüş şişe. Çarptığı yerde kutsanmış zemin alanı açar; yalnızca vampir, undead ve Vlad'ın kan hizmetkarlarına ağır hasar verir.",
		"description_en": "Sanctified pure silver flask. Spreads hallowed ground on impact; deals crushing holy damage exclusively to vampires, undead, and thralls.",
		"effect": "45 Kutsal Hasar (Yalnızca Unholy/Vampir Düşmanlar)",
		"effect_en": "45 Holy Damage (Unholy / Vampire Foes Only)",
		"shortcut": "[7] / [F]",
		"is_equipped": (active_sec == "holy_water"),
		"can_use": true,
		"action_text": "Kuşanılmış (Aktif)" if active_sec == "holy_water" else "Hızlı Yuvaya Ata ([F])",
		"action_text_en": "Equipped (Active)" if active_sec == "holy_water" else "Assign to Quick Slot ([F])"
	})

	# 3. Değerli Eşyalar ve Anahtarlar
	var coins: int = hud.coins if (hud and "coins" in hud) else 0
	var keys: int = hud.keys if (hud and "keys" in hud) else 0

	_cached_items.append({
		"id": "coins",
		"category": "currency",
		"title": "Osmanlı Akçesi",
		"title_en": "Ottoman Akche",
		"icon_path": "res://scenes/ui/icons/icon_coin.png",
		"count": coins,
		"description": "Gümüş Osmanlı sikkeleri. Ordugah ikmalcilerinden ve seyyar dervişlerden erzak, iksir ve cephane temin etmek için kullanılır.",
		"description_en": "Silver Ottoman coins. Used to purchase supplies, potions, and secondary ammunition from encampment quartermasters.",
		"effect": "Harcanabilir Para Birimi",
		"effect_en": "Spendable Currency",
		"shortcut": "",
		"can_use": false,
		"action_text": "Pasif Eşya",
		"action_text_en": "Passive Item"
	})

	_cached_items.append({
		"id": "keys",
		"category": "key",
		"title": "Zindan Demir Anahtarı",
		"title_en": "Dungeon Iron Key",
		"icon_path": "res://scenes/ui/icons/icon_key.png",
		"count": keys,
		"description": "Eflak kalesinin kalın demir parmaklıklarını ve zindan hücre kapılarını açan ağır döküm anahtar.",
		"description_en": "Heavy cast-iron key opening the thick iron grates and cell gates of the Wallachian castle dungeons.",
		"effect": "Kilitli Geçitleri Açar",
		"effect_en": "Unlocks Sealed Passages",
		"shortcut": "",
		"can_use": false,
		"action_text": "Pasif Eşya",
		"action_text_en": "Passive Item"
	})

	var has_sword: bool = (player and player.get("has_sword")) or (hud and hud.get("has_weapon"))
	_cached_items.append({
		"id": "weapon_sword",
		"category": "equipment",
		"title": "Padişah Yadigarı Kılıç",
		"title_en": "Sultan's Heirloom Blade",
		"icon_path": "res://scenes/ui/icons/icon_sword_slot.png",
		"count": 1 if has_sword else 0,
		"description": "Fatih Sultan Mehmed Han tarafından sefer öncesi hediye edilen çift ağızlı çelik pala. Hafif ve keskin.",
		"description_en": "Double-edged steel scimitar presented by Sultan Mehmed II before the campaign. Balanced, nimble, and razor sharp.",
		"effect": "Temel Silah — 3 Aşamalı Kombo Saldırısı",
		"effect_en": "Primary Weapon — 3-Hit Melee Combo",
		"shortcut": "[Sol Tık / X]",
		"can_use": false,
		"action_text": "Kuşanılmış Silah",
		"action_text_en": "Equipped Weapon"
	})

	Ww2Items.append_items(self, _cached_items) # Bölüm 4 eşyaları (2D-144)
	FutureItems.append_items(self, _cached_items) # Bölüm 5 eşyaları (2D-158)

	# 4. Kalp Parçaları Verileri (6 parça — güncel hikâye)
	var heart_count: int = game_state.current_heart_pieces if (game_state and "current_heart_pieces" in game_state) else 1

	_cached_heart_pieces = [
		{
			"id": "heart_fragment_1",
			"index": 1,
			"title": "1. Kadim Yankı (Taş Devri)",
			"title_en": "1. Primeval Echo (Stone Age)",
			"era": "Taş Devri — T-Rex Krateri",
			"era_en": "Stone Age — T-Rex Crater",
			"ability": "Kalp Rezonansı (Heart Resonance)",
			"ability_en": "Heart Resonance",
			"unlocked": (heart_count >= 1),
			"icon_path": "res://scenes/ui/icons/icon_heart.png",
			"description": "Taş Devri'nde zaman çatlağını bekleyen kadim T-Rex'in ruhundan saçılan ilk Kalp Parçası. Taşıyıcısına zaman yankılarını algılama ve mistik rezonans yeteneği bahşeder.",
			"description_en": "The first Heart Shard emanating from the cybernetic titan guarding the prehistoric rift. Grants temporal echo detection.",
			"bonus_text": "⚡ Pasif Bonus: Çevre sırlarını algılama ve çatlak titreşimi",
			"bonus_text_en": "⚡ Passive Bonus: Environmental secret detection and rift resonance"
		},
		{
			"id": "heart_fragment_2",
			"index": 2,
			"title": "2. Kan Mührü (Eflak Kalesi)",
			"title_en": "2. Blood Sigil (Wallachian Keep)",
			"era": "Orta Çağ — Vlad Tepeş'in Mahzenleri",
			"era_en": "Middle Ages — Vlad's Catacombs",
			"ability": "Gölge Adımı & Kan Kalkanı (Blood Veil)",
			"ability_en": "Shadow Step & Blood Veil",
			"unlocked": (heart_count >= 2),
			"icon_path": "res://scenes/ui/icons/icon_heart.png",
			"description": "Vlad Tepeş'in zindanlarında ve taht odasında vampir kanıyla mühürlenmiş ikinci parça. Karanlık güçlere karşı yüksek mukavemet ve gölge atılması sağlar.",
			"description_en": "The second shard consecrating Vlad the Impaler's throne. Provides dark resistance and spectral shadow dash.",
			"bonus_text": "🛡️ Pasif Bonus: +%10 Maksimum Can ve Kutsal Hasar Direnci",
			"bonus_text_en": "🛡️ Passive Bonus: +10% Max Health & Holy Damage Resistance"
		},
		{
			"id": "heart_fragment_3",
			"index": 3,
			"title": "3. Güneş Asası (Antik Mısır)",
			"title_en": "3. Sun Sceptre (Ancient Egypt)",
			"era": "Antik Mısır — Firavun Kral'ın Anıt-Mezarı",
			"era_en": "Ancient Egypt — The Pharaoh King's Tomb",
			"ability": "Güneş Patlaması (Solar Flare)",
			"ability_en": "Solar Flare",
			"unlocked": (heart_count >= 3),
			"icon_path": "res://scenes/ui/icons/icon_heart.png",
			"description": "Ölümü reddeden Firavun Kral'ın Güneş Asası'na ve altın maskesine mühürlediği üçüncü Kalp Parçası.",
			"description_en": "The third shard, sealed by the death-defying Pharaoh King into his Sun Sceptre and golden mask.",
			"bonus_text": "☀️ Pasif Bonus: Mana yenilenme hızında +%25 artış",
			"bonus_text_en": "☀️ Passive Bonus: +25% Mana Recovery Rate"
		},
		{
			"id": "heart_fragment_4",
			"index": 4,
			"title": "4. Demir Çekirdek (2. Dünya Savaşı)",
			"title_en": "4. Iron Core (World War II)",
			"era": "20. Yüzyıl — Cani Komutan'ın Sığınağı",
			"era_en": "20th Century — The Butcher Commander's Bunker",
			"ability": "İntikam Yemini (Kızıl-Altın Aura)",
			"ability_en": "Vow of Vengeance (Crimson-Gold Aura)",
			"unlocked": (heart_count >= 4),
			"icon_path": "res://assets/items/ww2/heart_piece_4.png",
			"description": "Cani Komutan'ın savaş makinelerine ve okült silahlarına güç verdiği dördüncü Kalp Parçası.",
			"description_en": "The fourth shard, powering the Butcher Commander's war machines and occult weapons.",
			"bonus_text": "🔥 Mühür son günlerini sayıyor: kılıç kızıl-altın bir aleve büründü",
			"bonus_text_en": "🔥 The seal counts its final days: the blade is wreathed in crimson-gold flame"
		},
		{
			"id": "heart_fragment_5",
			"index": 5,
			"title": "5. İşlemci Kalbi (Distopik Gelecek)",
			"title_en": "5. Processor Heart (Dystopian Future)",
			"era": "Uzak Gelecek — AI Lord'un Çekirdeği",
			"era_en": "Far Future — The AI Lord's Core",
			"ability": "Altıncı Çekirdek (Kabuksuz Kılıç)",
			"ability_en": "The Sixth Core (Shell-less Blade)",
			"unlocked": (heart_count >= 5),
			"icon_path": "res://assets/items/future/heart_piece_5.png",
			"description": "AI Lord'un ana çekirdek olarak kullandığı beşinci Kalp Parçası. Taş Devri'ne yağan mekanik enkazın kaynağı bu çağdır.",
			"description_en": "The fifth shard, used by the AI Lord as its main core. The mechanical wreckage that rained on the Stone Age came from this era.",
			"bonus_text": "💠 Beş dış parça birleşti: kılıcın kabuğu paramparça oldu, altıncı çekirdek uyandı",
			"bonus_text_en": "💠 Five outer shards joined: the blade's shell shattered and the sixth core awoke"
		},
		{
			"id": "heart_fragment_6",
			"index": 6,
			"title": "6. Mührün Kalbi (Kılıç)",
			"title_en": "6. Heart of the Seal (The Sword)",
			"era": "Zamanın Dışı — Kılıcın Mührü",
			"era_en": "Outside Time — The Sword's Seal",
			"ability": "Henüz bilinmiyor",
			"ability_en": "Not yet known",
			"unlocked": (heart_count >= 6),
			"icon_path": "res://scenes/ui/icons/icon_heart.png",
			"description": "Son parça başından beri seninle: kılıcın mührünün tam kalbinde. Diğer beşi bir araya gelmeden uyanmaz.",
			"description_en": "The last shard has been with you all along: at the very heart of the sword's seal. It will not wake until the other five are joined.",
			"bonus_text": "🔒 Beş parça toplanmadan açılmaz",
			"bonus_text_en": "🔒 Sealed until five shards are gathered"
		}
	]


## Eşyalar listesini oluşturur
func _populate_items_list() -> void:
	if not item_list_container:
		return

	for ch in item_list_container.get_children():
		ch.queue_free()

	var is_en: bool = _is_english()

	if _cached_items.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No items in your satchel." if is_en else "Çantanızda henüz eşya bulunmuyor."
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

		var equip_str = (" [EQUIPPED]" if is_en else " [KUŞANILDI]") if item.get("is_equipped", false) else ""
		var title_str = str(item.get("title_en", "")) if (is_en and not str(item.get("title_en", "")).is_empty()) else str(item.get("title", ""))

		btn.text = prefix + title_str + count_str + equip_str
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
	var is_en: bool = _is_english()

	if heart_progress_label:
		var pct = int((float(heart_count) / float(HEART_PIECE_TOTAL)) * 100.0)
		heart_progress_label.text = ("World Heart Integrity: %d / %d Shards (%d%%)" if is_en else "Dünya Kalbi Bütünlüğü: %d / %d Parça (%%%d)") % [heart_count, HEART_PIECE_TOTAL, pct]

	if heart_quadrant_container:
		for i in range(1, HEART_PIECE_TOTAL + 1):
			var slot_btn: Button = heart_quadrant_container.get_node_or_null("QuadrantSlot%d" % i) as Button
			if slot_btn == null:
				# Sahnede 4 yuva var; kalan parçalar için aynı görünümde yuva çoğaltılır
				var template: Button = heart_quadrant_container.get_node_or_null("QuadrantSlot1") as Button
				if template:
					slot_btn = template.duplicate(0) as Button
					slot_btn.name = "QuadrantSlot%d" % i
					heart_quadrant_container.add_child(slot_btn)
			if slot_btn:
				var is_unlocked: bool = (i <= heart_count)
				var mark = "💎" if is_unlocked else "🔒"
				slot_btn.text = ("%s Shard %d" if is_en else "%s Parça %d") % [mark, i]
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
	var is_en: bool = _is_english()
	if item.is_empty():
		if title_label: title_label.text = "No Item Selected" if is_en else "Eşya Seçilmedi"
		if category_badge: category_badge.visible = false
		if desc_label: desc_label.text = ""
		if effect_label: effect_label.text = ""
		if count_label: count_label.text = ""
		if shortcut_badge: shortcut_badge.visible = false
		if shortcut_desc: shortcut_desc.text = ""
		if action_button: action_button.visible = false
		return

	if title_label:
		title_label.text = str(item.get("title_en", "")) if (is_en and not str(item.get("title_en", "")).is_empty()) else str(item.get("title", ""))

	if category_badge:
		category_badge.visible = true
		match item.get("category", ""):
			"consumable":
				category_badge.text = "🧪 CONSUMABLE POTION" if is_en else "🧪 TÜKETİLEBİLİR İKSİR"
				category_badge.modulate = Color(0.4, 0.9, 1.0, 1.0)
			"secondary":
				category_badge.text = "🗡️ THROWABLE WEAPON" if is_en else "🗡️ FIRLATILABİLİR İKİNCİL SİLAH"
				category_badge.modulate = Color(1.0, 0.75, 0.3, 1.0)
			"currency":
				category_badge.text = "🪙 CURRENCY" if is_en else "🪙 DEĞERLİ PARA"
				category_badge.modulate = Color(1.0, 0.9, 0.2, 1.0)
			"key":
				category_badge.text = "🗝️ SPECIAL KEY" if is_en else "🗝️ ÖZEL GÖREV / ZİNDAN ANAHTARI"
				category_badge.modulate = Color(0.8, 0.6, 1.0, 1.0)
			"equipment":
				category_badge.text = "⚔️ MAIN WEAPON" if is_en else "⚔️ KUŞANILABİLİR ANA SİLAH"
				category_badge.modulate = Color(0.9, 0.4, 0.4, 1.0)

	if count_label:
		count_label.text = ("Carried: %d" if is_en else "Taşınan Miktar: %d") % int(item.get("count", 0))

	if desc_label:
		desc_label.text = str(item.get("description_en", "")) if (is_en and not str(item.get("description_en", "")).is_empty()) else str(item.get("description", ""))

	if effect_label:
		var eff_str = str(item.get("effect_en", "")) if (is_en and not str(item.get("effect_en", "")).is_empty()) else str(item.get("effect", ""))
		effect_label.text = ("⚡ Effect: %s" if is_en else "⚡ Etki: %s") % eff_str

	var sc = str(item.get("shortcut", ""))
	if shortcut_badge and shortcut_desc:
		if not sc.is_empty():
			shortcut_badge.visible = true
			shortcut_badge.text = sc
			shortcut_desc.visible = true
			shortcut_desc.text = "Shortcut" if is_en else "Klavye Kısayolu"
		else:
			shortcut_badge.visible = false
			shortcut_desc.visible = false

	if action_button:
		var cat = item.get("category", "")
		if cat in ["consumable", "secondary"]:
			action_button.visible = true
			var act_txt = str(item.get("action_text_en", "")) if (is_en and not str(item.get("action_text_en", "")).is_empty()) else str(item.get("action_text", "Use" if is_en else "Kullan"))
			action_button.text = act_txt
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

	var is_en: bool = _is_english()
	var is_unlocked = bool(hp.get("unlocked", false))

	if title_label:
		title_label.text = str(hp.get("title_en", "")) if (is_en and not str(hp.get("title_en", "")).is_empty()) else str(hp.get("title", ""))

	if category_badge:
		category_badge.visible = true
		if is_unlocked:
			category_badge.text = "💎 RELIC SHARD (ACQUIRED)" if is_en else "💎 KALINTI PARÇASI (TOPLANDI)"
			category_badge.modulate = Color(1.0, 0.85, 0.2, 1.0)
		else:
			category_badge.text = "🔒 LOCKED RELIC (NOT FOUND)" if is_en else "🔒 KİLİTLİ KALINTI (HENÜZ BULUNMADI)"
			category_badge.modulate = Color(0.6, 0.65, 0.7, 0.8)

	if count_label:
		var era_str = str(hp.get("era_en", "")) if (is_en and not str(hp.get("era_en", "")).is_empty()) else str(hp.get("era", ""))
		count_label.text = ("Era: %s" if is_en else "Çağ: %s") % era_str

	if desc_label:
		desc_label.text = str(hp.get("description_en", "")) if (is_en and not str(hp.get("description_en", "")).is_empty()) else str(hp.get("description", ""))

	if effect_label:
		effect_label.text = str(hp.get("bonus_text_en", "")) if (is_en and not str(hp.get("bonus_text_en", "")).is_empty()) else str(hp.get("bonus_text", ""))

	if shortcut_badge and shortcut_desc:
		shortcut_badge.visible = is_unlocked
		shortcut_badge.text = str(hp.get("ability_en", "")) if (is_en and not str(hp.get("ability_en", "")).is_empty()) else str(hp.get("ability", ""))
		shortcut_desc.visible = is_unlocked
		shortcut_desc.text = "Acquired Ability" if is_en else "Kazanılan Yetenek"

	if action_button:
		action_button.visible = true
		if is_unlocked:
			action_button.text = "✨ Resonance Active" if is_en else "✨ Rezonans Aktif"
			action_button.disabled = true
		else:
			action_button.text = "🔒 Shard Locked" if is_en else "🔒 Parça Kilitli"
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

	if Ww2Items.handle_action(self, _selected_id, player) or FutureItems.handle_action(self, _selected_id, player):
		item_used.emit(_selected_id)
		refresh_inventory()
	elif _selected_id == "health_potion":
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
