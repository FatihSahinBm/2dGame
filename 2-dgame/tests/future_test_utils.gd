extends RefCounted

## res://tests/future_test_utils.gd
## Bölüm 5 test yardımcıları (Epic 2D-158): "player" grubunda, take_damage çağrılarını sayan
## fizik gövdeli prob; seviye yükleme / boşaltma / diyalog atlama; kayıt yuvası yedekleme.


## Kan Sisi kuralına uyan (sis hâlindeyken hasar almaz), hızı ve canı olan oyuncu probu
static func probe(host: Node, at: Vector2 = Vector2.ZERO) -> CharacterBody2D:
	var body: CharacterBody2D = CharacterBody2D.new()
	var src: GDScript = GDScript.new()
	src.source_code = "extends CharacterBody2D\nvar is_blood_mist_dashing: bool = false\nvar current_health: int = 50\n" \
		+ "var max_health: int = 100\nvar speed: float = 200.0\nvar facing_dir: float = 1.0\nvar current_attack_type: String = \"\"\n" \
		+ "func take_damage(a: int, _s: Variant = null) -> void:\n\tif is_blood_mist_dashing:\n\t\treturn\n" \
		+ "\tset_meta(\"dmg\", int(get_meta(\"dmg\", 0)) + a)\n" \
		+ "func heal(a: int) -> void:\n\tcurrent_health = mini(max_health, current_health + a)\n"
	src.reload()
	body.set_script(src)
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(16, 40)
	cs.shape = rect
	cs.position = Vector2(0, -20)
	body.add_child(cs)
	body.add_to_group("player")
	host.add_child(body)
	body.global_position = at
	return body


static func dmg(p: Node) -> int:
	return int(p.get_meta("dmg", 0))


static func wall(host: Node, at: Vector2, size: Vector2) -> StaticBody2D:
	var w: StaticBody2D = StaticBody2D.new()
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	w.add_child(cs)
	host.add_child(w)
	w.global_position = at
	return w


static func instance(host: Node, path: String, at: Vector2 = Vector2.ZERO) -> Node:
	var n: Node = (load(path) as PackedScene).instantiate()
	host.add_child(n)
	if n is Node2D:
		(n as Node2D).global_position = at
	return n


static func load_level(host: Node, path: String, keep_events: bool = false) -> Node:
	var gs: Node = host.get_node("/root/GameState")
	if not keep_events:
		gs.persistent_events.clear()
		host.get_node("/root/QuestManager").reset_quests()
	var level: Node = (load(path) as PackedScene).instantiate()
	if "autosave_on_complete" in level:
		level.autosave_on_complete = false
	host.add_child(level)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	return level


static func unload(host: Node, level: Node) -> void:
	var dlg: Node = level.get_node_or_null("DialogueBox")
	if dlg and dlg.has_method("skip_dialogue"):
		dlg.skip_dialogue()
	level.queue_free()
	await host.get_tree().process_frame
	var cm: Node = host.get_node_or_null("/root/CinematicManager")
	if cm and cm.has_method("force_reset"):
		cm.force_reset("test")


## Açık diyaloğu kapatır (dialogue_completed yayılır)
static func skip(host: Node, level: Node) -> void:
	var dlg: Node = level.get_node_or_null("DialogueBox")
	if dlg and dlg.has_method("is_dialogue_active") and dlg.is_dialogue_active():
		dlg.skip_dialogue()
	await host.get_tree().process_frame


static func stage_done(host: Node, quest_id: String, stage_id: String) -> bool:
	for st: Variant in host.get_node("/root/QuestManager").get_quest(quest_id).get("stages", []):
		if str((st as Dictionary).get("id", "")) == stage_id:
			return bool((st as Dictionary).get("completed", false))
	return false


static func slot_files(slot: int) -> Array[String]:
	return ["user://savegame_slot_%d.json" % slot, "user://savegame_slot_%d_backup.json" % slot, "user://savegame_slot_%d_tmp.json" % slot]


static func backup_slot(slot: int) -> Dictionary:
	var saved: Dictionary = {}
	for path: String in slot_files(slot):
		saved[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return saved


static func restore_slot(slot: int, saved: Dictionary) -> void:
	for path: String in slot_files(slot):
		var data: Variant = saved.get(path)
		if data == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			f.store_buffer(data as PackedByteArray)
			f.close()
