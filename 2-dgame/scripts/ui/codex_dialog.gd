class_name CodexDialog
extends Control

## res://scripts/ui/codex_dialog.gd
## Story 2D-122: Düşman Kodeksi ve Dünya Bilgisi Arşivi Arayüzü (Codex Dialog UI).
## Düşmanları, elebaşıları, karakterleri ve dünya mitolojisini listeler;
## kilitli içerikleri spoiler sızdırmadan güvenli şekilde gösterir.

signal opened()
signal closed()
signal entry_selected(entry_id: String)

const CATEGORIES: Array[String] = ["enemies", "bosses", "characters", "lore"]

@onready var btn_enemies: Button = get_node_or_null("Panel/VBox/TabsContainer/BtnEnemies")
@onready var btn_bosses: Button = get_node_or_null("Panel/VBox/TabsContainer/BtnBosses")
@onready var btn_characters: Button = get_node_or_null("Panel/VBox/TabsContainer/BtnCharacters")
@onready var btn_lore: Button = get_node_or_null("Panel/VBox/TabsContainer/BtnLore")

@onready var progress_label: Label = get_node_or_null("Panel/VBox/MainSplit/LeftPane/VBox/ProgressBox/ProgressLabel")
@onready var progress_bar: ProgressBar = get_node_or_null("Panel/VBox/MainSplit/LeftPane/VBox/ProgressBar")
@onready var entry_list: VBoxContainer = get_node_or_null("Panel/VBox/MainSplit/LeftPane/VBox/Scroll/EntryList")

@onready var title_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/HeaderBox/TitleBox/TitleLabel")
@onready var subtitle_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/HeaderBox/TitleBox/SubtitleLabel")
@onready var category_badge: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/HeaderBox/BadgesBox/CategoryBadge")
@onready var era_badge: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/HeaderBox/BadgesBox/EraBadge")

@onready var icon_texture: TextureRect = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/VisualAndStats/IconContainer/IconTexture")
@onready var stats_summary_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/VisualAndStats/StatsVBox/StatsSummaryLabel")
@onready var kill_count_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/VisualAndStats/StatsVBox/KillCountLabel")
@onready var status_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/VisualAndStats/StatsVBox/StatusLabel")

@onready var desc_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/DescScroll/DescLabel")
@onready var tactics_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/TacticsBox/TacticsLabel")
@onready var weakness_label: Label = get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/WeaknessBox/WeaknessLabel")

@onready var btn_close: Button = get_node_or_null("Panel/VBox/Footer/BtnClose")

var _current_category: String = "enemies"
var _selected_entry_id: String = ""
var _was_paused_before_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if btn_enemies:
		btn_enemies.pressed.connect(func(): _switch_category("enemies"))
	if btn_bosses:
		btn_bosses.pressed.connect(func(): _switch_category("bosses"))
	if btn_characters:
		btn_characters.pressed.connect(func(): _switch_category("characters"))
	if btn_lore:
		btn_lore.pressed.connect(func(): _switch_category("lore"))
	if btn_close:
		btn_close.pressed.connect(close)

	var codex_mgr = _get_codex_manager()
	if codex_mgr:
		if codex_mgr.has_signal("entry_unlocked"):
			codex_mgr.entry_unlocked.connect(func(_id, _data): _on_codex_data_changed())
		if codex_mgr.has_signal("entry_updated"):
			codex_mgr.entry_updated.connect(func(_id, _data): _on_codex_data_changed())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_K or event.physical_keycode == KEY_K \
					or event.keycode == KEY_O or event.physical_keycode == KEY_O:
				open()
				get_viewport().set_input_as_handled()
		return

	# Kodeks açıkken giriş kontrolleri
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE \
				or event.keycode == KEY_K or event.physical_keycode == KEY_K \
				or event.keycode == KEY_O or event.physical_keycode == KEY_O:
			close()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB:
			_cycle_category()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventJoypadButton and event.pressed and not event.echo:
		if event.button_index == JOY_BUTTON_B or event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_BACK:
			close()
			get_viewport().set_input_as_handled()
			return


func open() -> void:
	_was_paused_before_open = get_tree().paused
	get_tree().paused = true
	visible = true

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("codex_open", -1.0)

	_refresh_ui()
	opened.emit()


func close() -> void:
	if not _was_paused_before_open:
		get_tree().paused = false
	visible = false

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("codex_close", -1.0)

	closed.emit()


func _switch_category(cat: String) -> void:
	_current_category = cat
	_selected_entry_id = ""
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("page_turn", -2.0)
	_refresh_ui()


func _cycle_category() -> void:
	var idx = CATEGORIES.find(_current_category)
	if idx == -1:
		idx = 0
	else:
		idx = (idx + 1) % CATEGORIES.size()
	_switch_category(CATEGORIES[idx])


func _on_codex_data_changed() -> void:
	if visible:
		_refresh_ui()


func _refresh_ui() -> void:
	var is_en: bool = _is_english()
	var main_title = get_node_or_null("Panel/VBox/HeaderBar/MainTitle") as Label
	if main_title:
		main_title.text = "📖 ANCIENT BESTIARY & CHRONICLES" if is_en else "📖 DÜŞMAN KODEKSİ VE BİLGİ ARŞİVİ"
	var key_hint = get_node_or_null("Panel/VBox/HeaderBar/KeyHint") as Label
	if key_hint:
		key_hint.text = "[K / O] Close | [TAB] Category | [ESC] Exit" if is_en else "[K / O] Kapat | [TAB] Kategori | [ESC] Çıkış"
	if btn_close:
		btn_close.text = "✖ Close (ESC)" if is_en else "✖ Kapat (ESC)"

	_update_tab_buttons()
	_update_progress()
	_populate_entry_list()
	_display_selected_entry()


func _is_english() -> bool:
	var loc_mgr = get_node_or_null("/root/LocalizationManager")
	if loc_mgr and loc_mgr.has_method("get_current_locale"):
		if str(loc_mgr.get_current_locale()).to_lower().begins_with("en"):
			return true
	if TranslationServer.has_method("get_locale"):
		if str(TranslationServer.get_locale()).to_lower().begins_with("en"):
			return true
	return false


func _update_tab_buttons() -> void:
	var is_en: bool = _is_english()

	if btn_enemies:
		btn_enemies.text = "⚔️ Enemies" if is_en else "⚔️ Düşmanlar"
	if btn_bosses:
		btn_bosses.text = "👑 Bosses" if is_en else "👑 Elebaşılar"
	if btn_characters:
		btn_characters.text = "👥 Allies & NPCs" if is_en else "👥 Karakterler"
	if btn_lore:
		btn_lore.text = "📜 World Lore" if is_en else "📜 Dünya Bilgisi"

	var map = {
		"enemies": btn_enemies,
		"bosses": btn_bosses,
		"characters": btn_characters,
		"lore": btn_lore
	}

	for cat in map.keys():
		var btn: Button = map[cat]
		if not btn:
			continue
		if cat == _current_category:
			btn.modulate = Color(1.0, 0.95, 0.5, 1.0)
		else:
			btn.modulate = Color(0.7, 0.75, 0.8, 0.9)


func _update_progress() -> void:
	var codex_mgr = _get_codex_manager()
	if not codex_mgr or not codex_mgr.has_method("get_progress"):
		return

	var is_en: bool = _is_english()

	var prog: Dictionary = codex_mgr.get_progress(_current_category)
	var unlocked_count: int = int(prog.get("unlocked", 0))
	var total_count: int = int(prog.get("total", 0))
	var pct: int = int(prog.get("percentage", 0))

	if progress_label:
		if is_en:
			progress_label.text = "Discovered: %d / %d (%d%%)" % [unlocked_count, total_count, pct]
		else:
			progress_label.text = "Keşif: %d / %d (%%%d)" % [unlocked_count, total_count, pct]
	if progress_bar:
		progress_bar.max_value = float(maxi(1, total_count))
		progress_bar.value = float(unlocked_count)


func _populate_entry_list() -> void:
	if not entry_list:
		return

	for child in entry_list.get_children():
		entry_list.remove_child(child)
		child.queue_free()

	var codex_mgr = _get_codex_manager()
	if not codex_mgr:
		return

	var is_en: bool = _is_english()

	var entries: Array[Dictionary] = codex_mgr.get_entries_by_category(_current_category)
	if entries.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No records found in this category." if is_en else "Bu kategoride kayıt bulunamadı."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry_list.add_child(empty_lbl)
		return

	# İlk girişi varsayılan olarak seçili yap (seçim yoksa)
	if _selected_entry_id.is_empty() and not entries.is_empty():
		_selected_entry_id = str(entries[0].get("id", ""))

	for e in entries:
		var e_id: String = str(e.get("id", ""))
		var display_data = codex_mgr.get_display_entry(e_id)
		var is_locked: bool = bool(display_data.get("is_locked", false))

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var prefix = "🔒 " if is_locked else "📖 "
		var title_text: String = str(display_data.get("title_en", "")) if (is_en and not str(display_data.get("title_en", "")).is_empty()) else str(display_data.get("title", e_id))
		btn.text = " %s %s" % [prefix, title_text]

		if is_locked:
			btn.modulate = Color(0.65, 0.68, 0.75, 0.7)
		else:
			if e_id == _selected_entry_id:
				btn.modulate = Color(1.0, 0.92, 0.55, 1.0)
			else:
				btn.modulate = Color(0.9, 0.92, 0.95, 1.0)

		# Güvenli ikon yüklemesi
		var icon_path = str(display_data.get("icon_path", ""))
		if not is_locked and not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			var tex = load(icon_path)
			if tex is Texture2D:
				btn.icon = tex
				btn.expand_icon = true

		btn.pressed.connect(func():
			_selected_entry_id = e_id
			var audio_mgr = get_node_or_null("/root/AudioManager")
			if audio_mgr and audio_mgr.has_method("play_sfx"):
				audio_mgr.play_sfx("page_turn", -3.0)
			entry_selected.emit(e_id)
			_refresh_ui()
		)

		entry_list.add_child(btn)


func _display_selected_entry() -> void:
	if _selected_entry_id.is_empty():
		return

	var codex_mgr = _get_codex_manager()
	if not codex_mgr:
		return

	var data: Dictionary = codex_mgr.get_display_entry(_selected_entry_id)
	if data.is_empty():
		return

	var is_en: bool = _is_english()
	var is_locked: bool = bool(data.get("is_locked", false))

	if title_label:
		var t_val := str(data.get("title_en", "")) if (is_en and not str(data.get("title_en", "")).is_empty()) else str(data.get("title", "???"))
		title_label.text = t_val
		title_label.modulate = Color(0.7, 0.75, 0.82, 1.0) if is_locked else Color(1, 0.95, 0.7, 1)

	if subtitle_label:
		var sub_val := str(data.get("subtitle_en", "")) if (is_en and not str(data.get("subtitle_en", "")).is_empty()) else str(data.get("subtitle", ""))
		subtitle_label.text = sub_val

	if category_badge:
		var cat_name = str(data.get("category", "")).to_upper()
		var badge_str = "ENTRY" if is_en else "KAYIT"
		match cat_name:
			"ENEMIES": badge_str = "⚔️ ENEMY" if is_en else "⚔️ DÜŞMAN"
			"BOSSES": badge_str = "👑 BOSS" if is_en else "👑 ELEBAŞI"
			"CHARACTERS": badge_str = "👥 ALLY / NPC" if is_en else "👥 KARAKTER"
			"LORE": badge_str = "📜 WORLD LORE" if is_en else "📜 DÜNYA BİLGİSİ"
		category_badge.text = " %s " % badge_str

	if era_badge:
		var era_val := str(data.get("era_en", "")) if (is_en and not str(data.get("era_en", "")).is_empty()) else str(data.get("era", "Bilinmeyen Çağ"))
		era_badge.text = era_val

	if desc_label:
		var d_val := str(data.get("description_en", "")) if (is_en and not str(data.get("description_en", "")).is_empty()) else str(data.get("description", ""))
		desc_label.text = d_val

	if tactics_label:
		var default_tac := "No special tactics." if is_en else "Özel taktik bulunmuyor."
		var tac_val := str(data.get("tactics_en", "")) if (is_en and not str(data.get("tactics_en", "")).is_empty()) else str(data.get("tactics", default_tac))
		tactics_label.text = tac_val

	if weakness_label:
		var default_weak := "Unknown" if is_en else "Bilinmiyor"
		var w_val := str(data.get("weakness_en", "")) if (is_en and not str(data.get("weakness_en", "")).is_empty()) else str(data.get("weakness", default_weak))
		weakness_label.text = w_val

	if stats_summary_label:
		var s_val := str(data.get("stats_summary_en", "")) if (is_en and not str(data.get("stats_summary_en", "")).is_empty()) else str(data.get("stats_summary", ""))
		stats_summary_label.text = s_val

	if kill_count_label:
		if is_locked:
			kill_count_label.text = "Encounter: None" if is_en else "Karşılaşma: Henüz Yok"
		else:
			var kills: int = int(data.get("kills", 0))
			var cat = str(data.get("category", ""))
			if cat == "enemies" or cat == "bosses":
				kill_count_label.text = ("Defeated: %d" if is_en else "Yenilme Sayısı: %d") % kills
			else:
				kill_count_label.text = "Status: Discovered" if is_en else "Durum: Keşfedildi"

	if status_label:
		if is_locked:
			status_label.text = "🔒 Not Yet Discovered" if is_en else "🔒 Henüz Keşfedilmedi"
			status_label.modulate = Color(0.85, 0.45, 0.45, 1.0)
		else:
			status_label.text = "✓ Archive Unlocked" if is_en else "✓ Kayıt Açıldı"
			status_label.modulate = Color(0.4, 0.9, 0.5, 1.0)

	# İkon yüklemesi (Kilitliyse kilit simgesi veya karartılmış)
	if icon_texture:
		var icon_path = str(data.get("icon_path", ""))
		if is_locked:
			icon_texture.texture = null
			icon_texture.modulate = Color(0.4, 0.4, 0.5, 0.5)
		elif not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			var tex = load(icon_path)
			if tex is Texture2D:
				icon_texture.texture = tex
				icon_texture.modulate = Color.WHITE
			else:
				icon_texture.texture = null
		else:
			icon_texture.texture = null


func _get_codex_manager() -> Node:
	return get_node_or_null("/root/CodexManager")
