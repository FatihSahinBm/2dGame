extends RefCounted

## res://scripts/components/future_chapter_state.gd
## Bölüm 5 (Distopik Gelecek) ahlaki seçim ve yan görev bayrakları (Epic 2D-158).
## Tümü GameState.persistent_events içinde tutulur; kayıt dosyasına yazılır ve sahne
## yeniden yüklenince korunur.
##   future_survivor|<id>      -> "freed" | "drained" | "killed"   (Son İnsanlık Sığınağı — metro)
##   future_engineer|<id>      -> "freed" | "drained" | "killed"   (Son İnsanlık Sığınağı — Veri Kalesi)
##   future_node|<id>          -> true  (Siber-Ağ Kesintisi: yok edilen sunucu düğümü)
##   future_scan|<id>          -> true  (Geçmişe Düşen Enkaz: taranan şema)
##   future_terminal|<id>      -> true  (hacklenen EMP terminali)

const KIND_SURVIVOR: String = "survivor"
const KIND_ENGINEER: String = "engineer"
const OUTCOME_FREED: String = "freed"
const OUTCOME_DRAINED: String = "drained"
const OUTCOME_KILLED: String = "killed"
const NODES_REQUIRED: int = 3
const SCAN_IDS: Array[String] = ["socket", "harness"]
## Siber-Ağ Kesintisi tamamlandıysa AI Lord dron/taret desteği bu oranla çarpılır
const OUTAGE_SUPPORT_FACTOR: float = 0.5


static func _gs(node: Node) -> Node:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return null
	var gs: Node = node.get_node_or_null("/root/GameState")
	return gs if gs and "persistent_events" in gs else null


static func _key(kind: String, id: String) -> String:
	return "future_%s|%s" % [kind, id]


static func record_outcome(node: Node, kind: String, id: String, outcome: String) -> void:
	var gs: Node = _gs(node)
	if gs:
		gs.persistent_events[_key(kind, id)] = outcome


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
	var prefix: String = "future_%s|" % kind
	var total: int = 0
	for key: Variant in gs.persistent_events.keys():
		if str(key).begins_with(prefix) and str(gs.persistent_events[key]) == outcome:
			total += 1
	return total


## Bölümde en az bir direnişçi/mühendis sömürüldü ya da öldürüldüyse true
static func has_harmed_innocents(node: Node) -> bool:
	for kind: String in [KIND_SURVIVOR, KIND_ENGINEER]:
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


# ---------------------------------------------------------------------------
# Siber-Ağ Kesintisi
# ---------------------------------------------------------------------------
static func mark_node_destroyed(node: Node, node_id: String) -> int:
	set_flag(node, _key("node", node_id), true)
	return nodes_destroyed(node)


static func is_node_destroyed(node: Node, node_id: String) -> bool:
	return has_flag(node, _key("node", node_id))


static func nodes_destroyed(node: Node) -> int:
	var gs: Node = _gs(node)
	if gs == null:
		return 0
	var total: int = 0
	for key: Variant in gs.persistent_events.keys():
		if str(key).begins_with("future_node|") and bool(gs.persistent_events[key]):
			total += 1
	return total


static func is_network_down(node: Node) -> bool:
	return nodes_destroyed(node) >= NODES_REQUIRED


## AI Lord dron çağrısı / taret desteği çarpanı: Siber-Ağ Kesintisi tamamlandıysa %50
static func support_factor(node: Node) -> float:
	return OUTAGE_SUPPORT_FACTOR if is_network_down(node) else 1.0


## Çarpanı bir adede uygular (en az 1, yukarı yuvarlamasız): 4 dron -> 2, 3 dron -> 1
static func scaled_count(node: Node, base_count: int) -> int:
	return maxi(1, int(floor(float(base_count) * support_factor(node))))


# ---------------------------------------------------------------------------
# Geçmişe Düşen Enkazın Sırrı
# ---------------------------------------------------------------------------
static func mark_scanned(node: Node, scan_id: String) -> bool:
	set_flag(node, _key("scan", scan_id), true)
	return all_scanned(node)


static func is_scanned(node: Node, scan_id: String) -> bool:
	return has_flag(node, _key("scan", scan_id))


static func all_scanned(node: Node) -> bool:
	for scan_id: String in SCAN_IDS:
		if not is_scanned(node, scan_id):
			return false
	return true
