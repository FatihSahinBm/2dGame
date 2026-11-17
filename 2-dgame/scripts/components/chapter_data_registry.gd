extends RefCounted

## res://scripts/components/chapter_data_registry.gd
## Bölüm JSON dosyalarındaki "quests" ve "codex" bloklarını QuestManager / CodexManager'a kaydeder
## (Epic 2D-143). Görev ve Codex metinleri koda gömülmez; data/story/chapter_*.json içinde durur.
## Kullanım: yöneticinin init_default_* fonksiyonunun sonunda
##   ChapterDataRegistry.register_quests(self) / ChapterDataRegistry.register_codex(self)

const DATA_DRIVEN_CHAPTERS: Array[String] = [
	"res://data/story/chapter_3_egypt.json",
	"res://data/story/chapter_4_ww2.json",
	"res://data/story/chapter_5_future.json",
]


static func register_quests(manager: Object) -> int:
	return _register(manager, "quests", "register_quest")


static func register_codex(manager: Object) -> int:
	return _register(manager, "codex", "register_entry")


## Verilen bölüm dosyasından ilgili blok (yoksa boş dizi)
static func load_block(path: String, block: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_warning("ChapterDataRegistry: %s okunamadı." % path)
		return []
	var items: Variant = (parsed as Dictionary).get(block, [])
	return items as Array if items is Array else []


static func _register(manager: Object, block: String, method: String) -> int:
	if manager == null or not manager.has_method(method):
		return 0
	var count: int = 0
	for path: String in DATA_DRIVEN_CHAPTERS:
		for item: Variant in load_block(path, block):
			if item is Dictionary:
				manager.call(method, (item as Dictionary).duplicate(true))
				count += 1
	return count
