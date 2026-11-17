extends SceneTree

## res://tools/test_archer_quest_state.gd
## Story 2D-138: Kemankeş görevi veri modeli, kalıcılığı ve köprüdeki ok desteği koşulu.
## Çalıştırma: godot --headless --path . --script res://tools/test_archer_quest_state.gd

const CAMP_PATH: String = "res://scenes/levels/vlad/stage_1_camp.tscn"
const BRIDGE_PATH: String = "res://scenes/levels/vlad/stage_1_bridge_assault.tscn"

var _failed: bool = false
var _gs: Node = null


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Kemankeş Görevi ve Alevli Ok Desteği (2D-138) ===")
	_gs = root.get_node_or_null("GameState")
	if _gs == null:
		_gs = (load("res://scripts/autoloads/game_state.gd") as GDScript).new()
		_gs.name = "GameState"
		root.add_child(_gs)
	_gs.reset_state()

	var camp: Node = await _spawn(CAMP_PATH)
	_check(camp._archer_quest_state == "NOT_STARTED" and not camp._has_arrow_quiver, "Temiz başlangıçta görev başlamamış.")

	# Ret -> kayıt -> yeniden yükleme
	camp._set_archer_state("DECLINED")
	camp = await _reload(camp)
	_check(camp._archer_quest_state == "DECLINED", "Ret durumu yeniden yüklemede korunuyor.")

	# Kabul -> sadak sahnede etkin
	camp._set_archer_state("ACCEPTED")
	camp = await _reload(camp)
	var quiver: Node = camp.get_node_or_null("Environment/BrokenCart/ArrowQuiverItem")
	_check(camp._archer_quest_state == "ACCEPTED" and quiver != null and quiver.is_quest_active, "Kabul durumu korunuyor ve sadak toplanabilir durumda.")

	# Sadak toplandı -> yeniden yüklemede oyuncuda sayılır, sahnede yeniden oluşmaz
	if quiver:
		quiver._on_body_entered(camp.player)
	_check(camp._has_arrow_quiver, "Sadak toplanınca oyuncuda işaretleniyor.")
	camp = await _reload(camp)
	quiver = camp.get_node_or_null("Environment/BrokenCart/ArrowQuiverItem")
	_check(camp._archer_quest_state == "ACCEPTED" and camp._has_arrow_quiver, "Toplanan sadak yeniden yüklemede oyuncuda kalıyor.")
	_check(quiver == null or quiver.is_queued_for_deletion(), "Toplanan sadak sahnede yeniden oluşmuyor (tek seferlik).")

	# Teslim -> ödül yeteneği ve tamamlanma
	camp._deliver_quiver_to_archer()
	_check(_gs.has_ability("flaming_arrows") and camp._archer_quest_state == "COMPLETED" and not camp._has_arrow_quiver, "Teslimde görev tamamlanıyor ve alevli ok desteği açılıyor.")
	camp = await _reload(camp)
	_check(camp._archer_quest_state == "COMPLETED", "Tamamlanma durumu korunuyor; görev yeniden teklif edilmiyor.")
	await _despawn(camp)

	# Eski/eksik kayıt: durum anahtarı yok ama ödül var -> tamamlanmış sayılır
	_gs.persistent_events.erase("archer_quest_state")
	camp = await _spawn(CAMP_PATH)
	_check(camp._archer_quest_state == "COMPLETED", "Durum verisi olmayan eski kayıtta ödül varsa görev tamamlanmış sayılıyor.")
	await _despawn(camp)

	# Bozuk veri: tanınmayan durum güvenle sıfırlanır
	_gs.reset_state()
	_gs.persistent_events["archer_quest_state"] = "bozuk_deger"
	camp = await _spawn(CAMP_PATH)
	_check(camp._archer_quest_state == "NOT_STARTED", "Tanınmayan durum değeri güvenle 'başlamadı' kabul ediliyor.")
	await _despawn(camp)

	# Köprü: destek yalnızca görev tamamlandıysa etkin
	_gs.reset_state()
	var bridge: Node = await _spawn(BRIDGE_PATH)
	_check(not bridge._has_arrow_support, "Görev tamamlanmadıysa köprüde ok desteği yok.")
	await _despawn(bridge)
	_gs.unlock_ability("flaming_arrows")
	bridge = await _spawn(BRIDGE_PATH)
	var timers: int = 0
	for child: Node in bridge.get_children():
		if child is Timer:
			timers += 1
	_check(bridge._has_arrow_support and timers == 1, "Görev tamamlandıysa destek tek bir zamanlayıcıyla etkin (çift tetikleme yok).")
	await _despawn(bridge)

	_gs.reset_state()
	if _failed:
		printerr("SONUÇ: KEMANKEŞ GÖREVİ TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: KEMANKEŞ GÖREVİ TESTİ BAŞARILI")
		quit(0)


func _spawn(path: String) -> Node:
	var level: Node = (load(path) as PackedScene).instantiate()
	root.add_child(level)
	await process_frame
	return level


func _despawn(level: Node) -> void:
	level.queue_free()
	await process_frame
	await process_frame


func _reload(level: Node) -> Node:
	await _despawn(level)
	return await _spawn(CAMP_PATH)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
