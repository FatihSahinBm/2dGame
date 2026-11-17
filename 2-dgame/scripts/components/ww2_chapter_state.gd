extends RefCounted

## res://scripts/components/ww2_chapter_state.gd
## Bölüm 4 (2. Dünya Savaşı) ahlaki seçim ve yan görev bayrakları (Epic 2D-144).
## Tümü GameState.persistent_events içinde tutulur; kayıt dosyasına yazılır ve
## sahne yeniden yüklenince korunur.
##   ww2_wounded|<id>        -> "freed" | "drained" | "killed"   (Siperdeki Yaralılar)
##   ww2_prisoner|<id>       -> "freed" | "drained" | "killed"   (Kafesteki Denekler; drained = reaktörde feda)
##   ww2_battery_silenced    -> true (Sessiz Batarya: topçu koordinatları bozuldu)
##   ww2_backdoor_key        -> true (esir kurtarıldı: sığınak arka kapı anahtarı)
##   ww2_reactor_sacrifices  -> int  (reaktöre feda edilen esir sayısı)

const KIND_WOUNDED: String = "wounded"
const KIND_PRISONER: String = "prisoner"
const OUTCOME_FREED: String = "freed"
const OUTCOME_DRAINED: String = "drained"
const OUTCOME_KILLED: String = "killed"
const FLAG_BATTERY_SILENCED: String = "ww2_battery_silenced"
const FLAG_BACKDOOR_KEY: String = "ww2_backdoor_key"
const FLAG_REACTOR_SACRIFICES: String = "ww2_reactor_sacrifices"
## Sessiz Batarya tamamlandıysa Komutan'ın topçu bombardımanı bu oranla çarpılır
const SILENCED_ARTILLERY_FACTOR: float = 0.5


static func _gs(node: Node) -> Node:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return null
	var gs: Node = node.get_node_or_null("/root/GameState")
	return gs if gs and "persistent_events" in gs else null


static func _key(kind: String, id: String) -> String:
	return "ww2_%s|%s" % [kind, id]


static func record_outcome(node: Node, kind: String, id: String, outcome: String) -> void:
	var gs: Node = _gs(node)
	if gs == null:
		return
	gs.persistent_events[_key(kind, id)] = outcome
	if kind == KIND_PRISONER and outcome == OUTCOME_FREED:
		gs.persistent_events[FLAG_BACKDOOR_KEY] = true
	if kind == KIND_PRISONER and outcome == OUTCOME_DRAINED:
		gs.persistent_events[FLAG_REACTOR_SACRIFICES] = int(gs.persistent_events.get(FLAG_REACTOR_SACRIFICES, 0)) + 1


static func get_outcome(node: Node, kind: String, id: String) -> String:
	var gs: Node = _gs(node)
	if gs == null:
		return ""
	var value: Variant = gs.persistent_events.get(_key(kind, id), "")
	return value if value is String else ""


static func count_outcome(node: Node, kind: String, outcome: String) -> int:
	var gs: Node = _gs(node)
	if gs == null:
		return 0
	var prefix: String = "ww2_%s|" % kind
	var total: int = 0
	for key: Variant in gs.persistent_events.keys():
		if str(key).begins_with(prefix) and str(gs.persistent_events[key]) == outcome:
			total += 1
	return total


## Bölümde en az bir yaralı/esir sömürüldü ya da öldürüldüyse true
static func has_harmed_innocents(node: Node) -> bool:
	for kind: String in [KIND_WOUNDED, KIND_PRISONER]:
		if count_outcome(node, kind, OUTCOME_DRAINED) + count_outcome(node, kind, OUTCOME_KILLED) > 0:
			return true
	return false


static func set_flag(node: Node, flag: String, value: Variant = true) -> void:
	var gs: Node = _gs(node)
	if gs:
		gs.persistent_events[flag] = value


static func has_flag(node: Node, flag: String) -> bool:
	var gs: Node = _gs(node)
	return gs != null and bool(gs.persistent_events.get(flag, false))


static func is_battery_silenced(node: Node) -> bool:
	return has_flag(node, FLAG_BATTERY_SILENCED)


## Topçu barajı çarpanı: Sessiz Batarya tamamlandıysa %50
static func artillery_factor(node: Node) -> float:
	return SILENCED_ARTILLERY_FACTOR if is_battery_silenced(node) else 1.0


static func reactor_sacrifices(node: Node) -> int:
	var gs: Node = _gs(node)
	return int(gs.persistent_events.get(FLAG_REACTOR_SACRIFICES, 0)) if gs else 0
