extends RefCounted

## res://scripts/combat/parry_resolver.gd
## Başarılı savuşturmanın saldırgana etkisi (Story 2D-127).
##
## Kural: Kusursuz savuşturma, oyuncunun yakınındaki EN YAKIN savuşturulabilir düşmanı
## kısa süre sersemletir ve karşı saldırı fırsatı açar. Yalnızca o tek düşman etkilenir.
## - Savuşturulabilir düşman: "on_parried(duration)" metodunu uygulayan düşmanlar
##   (normal düşmanlar: canavarlar, raptor).
## - Boss ve mini-boss'lar bağışıktır (is_parry_immune() true döner veya on_parried yoktur):
##   saldırıları savuşturulur (hasar verilmez) ama sersemlemezler. Mermiler ayrıca Player._check_projectile_parry ile yansıtılır.

const STAGGER_RANGE: float = 170.0
const STAGGER_DURATION: float = 0.9


## Savuşturulan saldırının sahibini bulur ve sersemletir. Sersemletilen düşmanı (yoksa null) döndürür.
static func stagger_attacker(player: Node2D) -> Node2D:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return null
	var best: Node2D = null
	var best_distance: float = STAGGER_RANGE
	for node: Node in player.get_tree().get_nodes_in_group("enemies"):
		if not (node is Node2D) or not node.has_method("on_parried"):
			continue
		if "is_dead" in node and node.is_dead:
			continue
		if node.has_method("is_parry_immune") and node.is_parry_immune():
			continue
		var distance: float = player.global_position.distance_to((node as Node2D).global_position)
		if distance <= best_distance:
			best_distance = distance
			best = node as Node2D
	if best:
		best.on_parried(STAGGER_DURATION)
	return best
