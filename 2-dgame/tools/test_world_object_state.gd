extends SceneTree

## res://tools/test_world_object_state.gd
## Story 2D-156: Dünya nesnelerinin benzersiz kimliği ve kalıcı durumu.
## Çalıştırma: godot --headless --path . --script res://tools/test_world_object_state.gd

const WorldObjectState = preload("res://scripts/components/world_object_state.gd")
const DUNGEON_PATH: String = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"
const CAMP_PATH: String = "res://scenes/levels/vlad/stage_1_camp.tscn"

var _failed: bool = false
var _game_state: Node = null


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Dünya Nesnesi Kalıcı Durumu (2D-156) ===")
	_game_state = root.get_node_or_null("GameState")
	if _game_state == null:
		_game_state = (load("res://scripts/autoloads/game_state.gd") as GDScript).new()
		_game_state.name = "GameState"
		root.add_child(_game_state)
	_game_state.reset_state()

	await _test_dungeon_round_trip()
	await _test_scene_isolation()
	_test_unstable_nodes_not_persisted()

	_game_state.reset_state()
	if _failed:
		printerr("SONUÇ: DÜNYA NESNESİ DURUM TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: DÜNYA NESNESİ DURUM TESTİ BAŞARILI")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)


func _spawn(path: String) -> Node:
	var level: Node = (load(path) as PackedScene).instantiate()
	root.add_child(level)
	await process_frame
	return level


func _despawn(level: Node) -> void:
	level.queue_free()
	await process_frame
	await process_frame


func _level_braziers(level: Node) -> Array[Node]:
	var result: Array[Node] = []
	for b: Node in get_nodes_in_group("braziers"):
		if level.is_ancestor_of(b):
			result.append(b)
	return result


func _test_dungeon_round_trip() -> void:
	var level: Node = await _spawn(DUNGEON_PATH)
	var lever: Node = level.get_node_or_null("EntranceMechanism/ChainLever")
	var braziers: Array[Node] = _level_braziers(level)
	_check(lever != null and braziers.size() >= 3, "Zindanda zincir kolu ve en az 3 mangal bulundu.")
	if lever == null or braziers.size() < 3:
		await _despawn(level)
		return

	var ids: Dictionary = {}
	for node: Node in braziers + [lever]:
		ids[WorldObjectState.make_id(node)] = true
	_check(ids.size() == braziers.size() + 1 and not ids.has(""), "Her nesnenin kimliği benzersiz ve dolu.")
	_check(WorldObjectState.make_id(lever).contains(DUNGEON_PATH), "Kimlik sahne dosyasını içeriyor.")
	_check(not level._outer_gate_unlocked and not level._gate_unlocked, "Temiz başlangıçta iki kapı da kapalı.")

	lever.activate_lever()
	braziers[0].ignite_brazier()
	braziers[1].ignite_brazier()
	_check(level._outer_gate_unlocked and level._braziers_lit == 2 and not level._gate_unlocked, "Kol çekildi, 2 mangal yakıldı; sunak kapısı hâlâ kapalı.")

	# Kayıt/yükleme benzetimi: durum sözlüğü JSON'dan geçirilip sıfırlanmış GameState'e geri konur
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_game_state.persistent_events))
	await _despawn(level)
	_game_state.reset_state()
	_game_state.persistent_events = saved

	level = await _spawn(DUNGEON_PATH)
	lever = level.get_node("EntranceMechanism/ChainLever")
	_check(lever.is_pulled and level._outer_gate_unlocked, "Yükleme sonrası kol çekili ve dış kapı açık.")
	_check(level._braziers_lit == 2 and not level._gate_unlocked, "Yükleme sonrası 2 mangal yanık, sunak kapısı kapalı.")

	var emitted: Array[int] = [0]
	lever.lever_activated.connect(func() -> void: emitted[0] += 1)
	lever.activate_lever()
	_check(emitted[0] == 0, "Çekilmiş kol yeniden tetiklenemiyor (tek seferlik olay).")

	for b: Node in _level_braziers(level):
		if not b.is_ignited:
			b.ignite_brazier()
			break
	_check(level._braziers_lit == 3 and level._gate_unlocked, "Kalan mangal yakılınca sunak kapısı açıldı (sayım kaldığı yerden sürdü).")
	await _despawn(level)

	level = await _spawn(DUNGEON_PATH)
	_check(level._gate_unlocked and level._braziers_lit == 3, "Tamamlanan bulmaca yeniden yüklemede açık kalıyor.")
	await _despawn(level)


func _test_scene_isolation() -> void:
	# Zindan durumu kayıtlıyken başka bir sahnedeki nesneler etkilenmemeli
	var camp: Node = await _spawn(CAMP_PATH)
	var leaked: bool = false
	for node: Node in get_nodes_in_group("barricades") + get_nodes_in_group("collectibles") + get_nodes_in_group("braziers"):
		if camp.is_ancestor_of(node):
			for state: String in ["lit", "pulled", "destroyed", "collected", "examined"]:
				if WorldObjectState.is_set(node, state):
					leaked = true
	_check(not leaked, "Bir sahnenin kayıtlı durumu başka sahnedeki nesnelere uygulanmıyor.")
	await _despawn(camp)

	var had_world_state: bool = false
	for key: Variant in _game_state.persistent_events.keys():
		if str(key).begins_with("wo|"):
			had_world_state = true
	_game_state.set_event_completed("boss_defeated_test", true)
	WorldObjectState.clear_all(_game_state)
	var remaining: int = 0
	for key: Variant in _game_state.persistent_events.keys():
		if str(key).begins_with("wo|"):
			remaining += 1
	_check(had_world_state and remaining == 0 and _game_state.is_event_completed("boss_defeated_test"), "clear_all yalnızca dünya nesnesi durumlarını temizliyor.")


func _test_unstable_nodes_not_persisted() -> void:
	var holder: Node2D = Node2D.new()
	holder.scene_file_path = CAMP_PATH
	root.add_child(holder)
	var runtime_node: Node2D = Node2D.new()
	holder.add_child(runtime_node, false)
	_check(str(runtime_node.name).begins_with("@") and WorldObjectState.make_id(runtime_node).is_empty(), "Otomatik adlı çalışma anı düğümü kimlik almıyor (yanlış eşleşme riski yok).")
	runtime_node.set_meta("persistent_id", "runtime_chest_1")
	_check(WorldObjectState.make_id(runtime_node).ends_with("|runtime_chest_1"), "persistent_id metası verilince açık kimlik kullanılıyor.")
	holder.queue_free()
