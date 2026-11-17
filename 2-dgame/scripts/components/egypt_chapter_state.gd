extends RefCounted

## res://scripts/components/egypt_chapter_state.gd
## Bölüm 3 ahlaki seçim bayrakları (Epic 2D-143). Tümü GameState.persistent_events içinde
## tutulur, bu yüzden kayıt dosyasına yazılır ve sahne yeniden yüklenince korunur.
##   egypt_slave|<id>      -> "freed" | "drained" | "killed"
##   egypt_ally_nefer      -> true (en az bir köle kurtarıldıysa Yaşlı Nefer müttefik olur)
##   egypt_redemption_path -> true (avluda hiç köle sömürülmeden/öldürülmeden kurtarma yapıldı)

const SLAVE_PREFIX: String = "egypt_slave|"
const OUTCOME_FREED: String = "freed"
const OUTCOME_DRAINED: String = "drained"
const OUTCOME_KILLED: String = "killed"
const FLAG_ALLY_NEFER: String = "egypt_ally_nefer"
const FLAG_REDEMPTION: String = "egypt_redemption_path"


static func _gs(node: Node) -> Node:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return null
	return node.get_node_or_null("/root/GameState")


static func record_slave_outcome(node: Node, slave_id: String, outcome: String) -> void:
	var gs: Node = _gs(node)
	if gs == null or not ("persistent_events" in gs):
		return
	gs.persistent_events[SLAVE_PREFIX + slave_id] = outcome
	_refresh_flags(gs)


static func get_slave_outcome(node: Node, slave_id: String) -> String:
	var gs: Node = _gs(node)
	if gs == null or not ("persistent_events" in gs):
		return ""
	var value: Variant = gs.persistent_events.get(SLAVE_PREFIX + slave_id, "")
	return value if value is String else ""


static func count_outcome(node: Node, outcome: String) -> int:
	var gs: Node = _gs(node)
	if gs == null or not ("persistent_events" in gs):
		return 0
	var total: int = 0
	for key: Variant in gs.persistent_events.keys():
		if str(key).begins_with(SLAVE_PREFIX) and str(gs.persistent_events[key]) == outcome:
			total += 1
	return total


static func is_redemption_path(node: Node) -> bool:
	var gs: Node = _gs(node)
	return gs != null and bool(gs.persistent_events.get(FLAG_REDEMPTION, false))


static func _refresh_flags(gs: Node) -> void:
	var freed: int = 0
	var harmed: int = 0
	for key: Variant in gs.persistent_events.keys():
		if not str(key).begins_with(SLAVE_PREFIX):
			continue
		var outcome: String = str(gs.persistent_events[key])
		if outcome == OUTCOME_FREED:
			freed += 1
		else:
			harmed += 1
	gs.persistent_events[FLAG_ALLY_NEFER] = freed > 0
	gs.persistent_events[FLAG_REDEMPTION] = freed > 0 and harmed == 0
