extends Node

## res://scripts/autoloads/codex_manager.gd
## Story 2D-122: Merkezi Düşman Kodeksi ve Dünya Bilgisi Arşivi (Single Source of Truth).
## Karşılaşılan ve yenilen düşmanları, önemli karakterleri, toplanabilir parşömenleri
## ve Kalp Parçası mitolojisini güvenli kilit mekanizması ve kalıcılıkla yönetir.

signal entry_unlocked(entry_id: String, entry_data: Dictionary)
signal entry_updated(entry_id: String, entry_data: Dictionary)
signal kill_count_incremented(entry_id: String, kills: int)

static var instance: Node = null

var _entries: Dictionary = {} # entry_id -> Dictionary


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	instance = self
	init_default_codex()


## Varsayılan kodeks veritabanını ilklendirir
func init_default_codex() -> void:
	_entries.clear()

	# ==========================================================================
	# 1. KATEGORİ: DÜŞMANLAR (ENEMIES)
	# ==========================================================================

	register_entry({
		"id": "basic_enemy",
		"category": "enemies",
		"title": "Eflak Muhafız Piyadesi",
		"subtitle": "Kaledeki Devriye Askerleri",
		"era": "Eflak / Transilvanya — 1462",
		"icon_path": "res://scenes/ui/icons/icon_sword_slot.png",
		"unlocked": true, # İlk haritada doğrudan karşılaşılır
		"encountered": true,
		"kills": 0,
		"description": "Vlad Tepeş'in hizmetindeki zırhlı Eflak askerleri. Kılıç darbeleri ve kalkanlarıyla devriye gezerler. Çapraz saldırılarda savunmasız kalırlar.",
		"tactics": "Saldırı savurduktan sonra arkalarına yuvarlanarak (Roll) kombo vuruşu yapın.",
		"weakness": "Arkadan darbeler ve Fırlatma Bıçağı",
		"stats_summary": "Tehlike: ⭐ | Can: 100 | Hasar Türü: Fiziksel Kesici"
	})

	register_entry({
		"id": "skeleton",
		"category": "enemies",
		"title": "Hortlak İskelet Savaşçı",
		"subtitle": "Mezardan Çıkarılmış Kadim Muhafız",
		"era": "Karanlık Çağlar & Yeraltı Mezarları",
		"icon_path": "res://scenes/ui/icons/icon_sword_slot.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Nekromansi büyüsüyle kemikleri birleştirilmiş savaşçılar. Canları bittiğinde parçalanırlar; kutsal su ve ezici darbeler kemiklerini un ufak eder.",
		"tactics": "Toplu gruplarda meşale veya kutsal su kullanarak tek hamlede temizleyin.",
		"weakness": "Kutsal Su (45 Hasar) ve Yangın",
		"stats_summary": "Tehlike: ⭐⭐ | Can: 80 | Hasar Türü: Delici Kemik Darbesi"
	})

	register_entry({
		"id": "flying_eye",
		"category": "enemies",
		"title": "Uçan İblis Gözü",
		"subtitle": "Karanlık Havadan Gözcü",
		"era": "Bilinmeyen Karanlık Boyut",
		"icon_path": "res://scenes/ui/icons/icon_crystal.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Havada süzülerek hedefe ani dalışlar yapan lanetli gözler. Geniş görüş açısıyla tuzak kurarlar.",
		"tactics": "Dalış anında yukarı zıplayarak savurma yapın veya fırlatma bıçağıyla menzilden vurun.",
		"weakness": "Fırlatma Bıçağı (Tek Atış) ve Alevli Oklar",
		"stats_summary": "Tehlike: ⭐⭐ | Can: 45 | Hasar Türü: Hava Dalışı"
	})

	register_entry({
		"id": "goblin",
		"category": "enemies",
		"title": "Orman Akıncısı Goblin",
		"subtitle": "Sinsi Pusu Yaratığı",
		"era": "Karanlık Orman Derinlikleri",
		"icon_path": "res://scenes/ui/icons/icon_key.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Çalılıklar ve taş aralıklarında saklanıp fırlattıkları hançerlerle zehir bulaştıran sinsi canlılar.",
		"tactics": "Sarmaşıkları meşaleyle yakarak saklandıkları alanları açığa çıkarın.",
		"weakness": "Ateş ve Sarmaşık Temizleme",
		"stats_summary": "Tehlike: ⭐⭐ | Can: 60 | Hasar Türü: Zehirli Hançer"
	})

	register_entry({
		"id": "mushroom",
		"category": "enemies",
		"title": "Zehirli Mahzen Mantarı",
		"subtitle": "Biyolojik Savunma Mantarı",
		"era": "Târgovişte Nemli Mahzenleri",
		"icon_path": "res://scenes/ui/icons/icon_potion_blue.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Yaklaştığınızda çevreye ölümcül spor gazları salan dev mantar kolonileri.",
		"tactics": "Yakın dövüşe girmeden uzaktan alevli meşale fırlatarak patlatın.",
		"weakness": "Meşale Yangın Alanı",
		"stats_summary": "Tehlike: ⭐⭐ | Can: 50 | Hasar Türü: Spor Gazı"
	})

	register_entry({
		"id": "necromancer",
		"category": "enemies",
		"title": "Gölge Nekromanseri",
		"subtitle": "Kara Büyü Rahibi",
		"era": "Eflak Mahzenleri — 1462",
		"icon_path": "res://scenes/ui/icons/icon_crystal.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Ölüleri dirilterek ordular kuran karanlık tarikat üyeleri. Işınlanma yetenekleriyle menzilli büyü küreleri fırlatırlar.",
		"tactics": "Büyü yaparken kılıçla kesintiye (Interrupt) uğratın.",
		"weakness": "Kutsal Su ve Hızlı Kombo",
		"stats_summary": "Tehlike: ⭐⭐⭐ | Can: 160 | Hasar Türü: Kara Büyü"
	})

	register_entry({
		"id": "ceiling_lurker_bat",
		"category": "enemies",
		"title": "Tavan Pusucusu Dev Yarasa",
		"subtitle": "Kan Emici Mağara Canavarı",
		"era": "Karanlık Zindan Tavanları",
		"icon_path": "res://scenes/ui/icons/icon_armor.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Tavan sarkıtlarında uyuyup altından geçen kurbanların üzerine son hızla çullanan devasa yarasalar.",
		"tactics": "Tavana meşale atarak uyandırıp dengesini bozun.",
		"weakness": "Işık, Yangın ve Kutsal Su",
		"stats_summary": "Tehlike: ⭐⭐⭐ | Can: 120 | Hasar Türü: Kan Sömürme"
	})

	# ==========================================================================
	# 2. KATEGORİ: ELEBAŞILAR (BOSSES)
	# ==========================================================================

	register_entry({
		"id": "blood_knight",
		"category": "bosses",
		"title": "Eflak Kan Şövalyesi",
		"subtitle": "Taş Köprü Muhafız Komutanı (Mini-Boss)",
		"era": "Taş Köprü Kuşatması — 1462",
		"icon_path": "res://scenes/ui/icons/icon_armor.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Vlad'ın seçkin muhafız birliğinin başındaki dev kan şövalyesi. 520 cana sahip kalın zırhı ve geniş kılıç savurmalarıyla köprüyü savunur.",
		"tactics": "Kılıç savurduğu an takla atarak arkasına geçin. Kemankeş'in alevli ok desteğiyle zırhını kırın.",
		"weakness": "Alevli Ok Bombardımanı & Kutsal Su",
		"stats_summary": "Tehlike: ⭐⭐⭐⭐ | Can: 520 | Hasar: 24 | Zırh: Ağır Çelik"
	})

	register_entry({
		"id": "ogre_boss",
		"category": "bosses",
		"title": "Dağ Devi (Ogre)",
		"subtitle": "Karanlık Orman Ezicisi",
		"era": "İlk Çağlar — İlkel Vadiler",
		"icon_path": "res://scenes/ui/icons/icon_sword_slot.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Ağaç kütüklerini silah olarak kullanan, yere vurarak şok dalgaları oluşturan muazzam cüsseli dev canavar.",
		"tactics": "Yere vurduğunda havaya zıplayarak şok dalgasından kaçının.",
		"weakness": "Hızlı Atılma (Dash) ve Baş Bölgesine Kombo",
		"stats_summary": "Tehlike: ⭐⭐⭐⭐ | Can: 650 | Hasar Türü: Ezici Şok Dalgası"
	})

	register_entry({
		"id": "trex_boss",
		"category": "bosses",
		"title": "Kadim Apex T-Rex",
		"subtitle": "Taş Devri Zaman Çatlağı Canavarı",
		"era": "Taş Devri — M.Ö. 65 Milyon Yıl",
		"icon_path": "res://scenes/ui/icons/icon_heart.png",
		"unlocked": true, # Taş devri tamamlandığı için kodekste açık başlar
		"encountered": true,
		"kills": 1,
		"description": "Zaman yarığının üzerinde hüküm süren ilk büyük canavar. İlk Kalp Parçası onun bedeninden saçılmıştır.",
		"tactics": "Kuyruk savurması öncesi çömelin, kükreme anında kulakları koruyarak platformlara tırmanın.",
		"weakness": "İlk Kalp Rezonansı",
		"stats_summary": "Tehlike: ⭐⭐⭐⭐⭐ | Can: 1000 | Zafer Ödülü: 1. Kalp Parçası"
	})

	register_entry({
		"id": "vlad_boss",
		"category": "bosses",
		"title": "Vlad Tepeş (Kazıklı Voyvoda)",
		"subtitle": "Eflak Prensi ve Kan Hükümdarı",
		"era": "Eflak Kalesi Taht Odası & Çan Kulesi — 1462",
		"icon_path": "res://scenes/ui/icons/icon_crown.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Dört farklı dönüşüm fazına (İnsan Kılıç Ustası, Vampir, Kurt Adam, Dev Kan Yarasası) sahip baş düşman. İkinci Kalp Parçasını ele geçirmiştir.",
		"tactics": "Kan kalkanını kırın; kurt adam fazında hızını takip edin; son fazda çan kulesi mekanizmalarını kullanın.",
		"weakness": "Kutsal Su, Alevli Oklar ve Padişah Yadigarı Kılıç",
		"stats_summary": "Tehlike: ⭐⭐⭐⭐⭐ | Faz: 4 Aşama | Zafer Ödülü: 2. Kalp Parçası"
	})

	# ==========================================================================
	# 3. KATEGORİ: KARAKTERLER & MÜTTEFİKLER (CHARACTERS)
	# ==========================================================================

	register_entry({
		"id": "fatih_mehmed",
		"category": "characters",
		"title": "Fatih Sultan Mehmed Han",
		"subtitle": "Osmanlı Hükümdarı ve Sefer Serdarı",
		"era": "Otağ-ı Hümayun — 1462",
		"icon_path": "res://scenes/ui/icons/icon_crown.png",
		"unlocked": true,
		"encountered": true,
		"kills": 0,
		"description": "İstanbul Fatihi, Vlad Tepeş'in zulmünü durdurmak için bizzat Eflak seferini yöneten genç hükümdar. Oyuncuya kutsal emanet kılıcı ve sefer fermanını teslim etmiştir.",
		"tactics": "İttifak lideri. Huzurunda felsefi ve tarihi diyaloglar yürütülür.",
		"weakness": "Müttefik",
		"stats_summary": "Rol: Hükümdar / Baş Stratejist | Müttefik"
	})

	register_entry({
		"id": "kemankes",
		"category": "characters",
		"title": "Kemankeş Çavuşu",
		"subtitle": "Osmanlı Keskin Okçusu",
		"era": "Osmanlı Ordugahı — 1462",
		"icon_path": "res://scenes/ui/icons/icon_quiver.png",
		"unlocked": true,
		"encountered": true,
		"kills": 0,
		"description": "Vadide kırılan erzak arabasından alevli sadakları toplayan oyuncuya minnettarlık duyarak köprü taarruzunda alevli ok yağmuru desteği sunan usta yeniçeri.",
		"tactics": "Sadak görevi tamamlandığında köprüdeki düşmanları menzilden bombalar.",
		"weakness": "Müttefik",
		"stats_summary": "Rol: Menzilli Ağır Destek Okçusu | Müttefik"
	})

	register_entry({
		"id": "janissary_commander",
		"category": "characters",
		"title": "Yeniçeri Kumandanı",
		"subtitle": "Öncü Birlik Serdarı",
		"era": "Karanlık Orman ve Ordugah",
		"icon_path": "res://scenes/ui/icons/portrait_knight.png",
		"unlocked": true,
		"encountered": true,
		"kills": 0,
		"description": "Gece baskınında öncü birliği toparlayarak ordugah meydanını savunan tecrübeli yeniçeri subayı.",
		"tactics": "Taarruz hattında askerleri koordine eder.",
		"weakness": "Müttefik",
		"stats_summary": "Rol: Bölük Komutanı | Müttefik"
	})

	# ==========================================================================
	# 4. KATEGORİ: DÜNYA BİLGİSİ & PARŞÖMENLER (LORE)
	# ==========================================================================

	register_entry({
		"id": "world_heart_myth",
		"category": "lore",
		"title": "Dünya Kalbi ve Dört Parça Efsanesi",
		"subtitle": "Zamanın Dokusu ve Kozmik Çatlaklar",
		"era": "Tüm Çağların Başlangıcı",
		"icon_path": "res://scenes/ui/icons/icon_heart.png",
		"unlocked": true,
		"encountered": true,
		"kills": 0,
		"description": "Evrenin zaman dengesini sağlayan Dünya Kalbi dört parçaya bölünerek farklı tarihi çağlara saçılmıştır. Taş Devri, Eflak, Antik Mısır ve Kıyamet Çöküşü. Parçalar birleşmezse evren sonsuz döngüde yok olacaktır.",
		"tactics": "Dört parçayı toplayarak kadranı tamamlayın.",
		"weakness": "Kozmik Bilgi",
		"stats_summary": "İlerleme: 4 Parçalık Kozmik Görev"
	})

	register_entry({
		"id": "vlad_castle_history",
		"category": "lore",
		"title": "Târgovişte ve Kazıklı Savunma Hattı",
		"subtitle": "Eflak Surları ve Kan Hendekleri",
		"era": "Eflak / Transilvanya — 1462",
		"icon_path": "res://scenes/ui/icons/icon_armor.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Vlad Tepeş'in esirleri ve köylüleri kazıklara oturttuğu, sarp kayalıklar üzerine inşa edilmiş geçit vermez taş kale.",
		"tactics": "Köprü üzerindeki barikatlar koçbaşı ve meşalelerle parçalanmalıdır.",
		"weakness": "Tarihi Kayıt",
		"stats_summary": "Konum: Eflak Geçidi"
	})

	register_entry({
		"id": "ancient_heart_relief",
		"category": "lore",
		"title": "Kadim Kemik Kabartması ve Mistik Mührün Sırrı",
		"subtitle": "Zindan Duvarındaki Mistik Gravür",
		"era": "Bilinmeyen Kadim Çağ",
		"icon_path": "res://scenes/ui/icons/icon_crystal.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Zindan mahzenindeki taş kabartmada, Dünya Kalbi'nin gücünü soğuran eski bir medeniyetin çizimleri yer alır.",
		"tactics": "Mahzende [E] ile incelendiğinde yeni bir diyalog ve aydınlanma sağlar.",
		"weakness": "Çevresel Anlatı",
		"stats_summary": "Tür: Arşiv Gravürü"
	})


## Yeni bir kodeks girişi kaydeder
func register_entry(entry_dict: Dictionary) -> void:
	if not entry_dict.has("id"):
		return
	var e_id: String = str(entry_dict["id"])

	var full_entry: Dictionary = {
		"id": e_id,
		"category": entry_dict.get("category", "enemies"),
		"title": entry_dict.get("title", e_id.capitalize()),
		"subtitle": entry_dict.get("subtitle", ""),
		"era": entry_dict.get("era", "Bilinmeyen Çağ"),
		"icon_path": entry_dict.get("icon_path", "res://scenes/ui/icons/icon_sword_slot.png"),
		"unlocked": bool(entry_dict.get("unlocked", false)),
		"encountered": bool(entry_dict.get("encountered", false)),
		"kills": int(entry_dict.get("kills", 0)),
		"description": entry_dict.get("description", ""),
		"tactics": entry_dict.get("tactics", "Özel taktik bulunmuyor."),
		"weakness": entry_dict.get("weakness", "Bilinmiyor"),
		"stats_summary": entry_dict.get("stats_summary", "")
	}

	_entries[e_id] = full_entry


## Düşmanla karşılaşıldığını kaydeder (kilit açılır)
func record_encounter(entry_id: String) -> bool:
	if not _entries.has(entry_id):
		return false

	var e = _entries[entry_id]
	var was_unlocked = e["unlocked"]
	e["encountered"] = true
	e["unlocked"] = true

	if not was_unlocked:
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("codex_unlock", -1.0)
		entry_unlocked.emit(entry_id, e)

	entry_updated.emit(entry_id, e)
	return true


## Düşmanın yenildiğini kaydeder (ölüm sayısı artar ve kilit açılır)
func record_kill(entry_id: String) -> bool:
	if not _entries.has(entry_id):
		return false

	var e = _entries[entry_id]
	var was_unlocked = e["unlocked"]
	e["kills"] += 1
	e["encountered"] = true
	e["unlocked"] = true

	kill_count_incremented.emit(entry_id, e["kills"])

	if not was_unlocked:
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("codex_unlock", -1.0)
		entry_unlocked.emit(entry_id, e)

	entry_updated.emit(entry_id, e)
	return true


## Doğrudan kilidi açar (karakterler, parşömenler vb.)
func unlock_entry(entry_id: String) -> bool:
	return record_encounter(entry_id)


func is_unlocked(entry_id: String) -> bool:
	return _entries.has(entry_id) and bool(_entries[entry_id].get("unlocked", false))


## Ham giriş verisini döner
func get_entry(entry_id: String) -> Dictionary:
	return _entries.get(entry_id, {})


## Güvenli arayüz gösterim verisini döner (Kilitliyse içerik sızdırmaz!)
func get_display_entry(entry_id: String) -> Dictionary:
	if not _entries.has(entry_id):
		return {}

	var raw = _entries[entry_id]
	if raw.get("unlocked", false):
		var copy = raw.duplicate(true)
		copy["is_locked"] = false
		return copy

	# Kilitli gösterim: Bilgileri maskele!
	return {
		"id": entry_id,
		"category": raw.get("category", "enemies"),
		"title": "??? (Bilinmeyen Kayıt)",
		"subtitle": "Henüz Keşfedilmedi",
		"era": "???",
		"icon_path": "res://scenes/ui/icons/icon_key.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Bu varlıkla henüz karşılaşılmadı veya kadim parşömen henüz okunmadı. Dünyayı keşfederek veya düşmanı yenerek kodeks kaydını açın.",
		"tactics": "🔒 Bilgiler Kilitli",
		"weakness": "🔒 Bilinmiyor",
		"stats_summary": "Tehlike: ??? | Durum: Kilitli",
		"is_locked": true
	}


## Kategoriye göre tüm girişleri döner
func get_entries_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e in _entries.values():
		if e.get("category") == category:
			result.append(e)
	return result


## Kodeks keşif ilerlemesini döner
func get_progress(category: String = "") -> Dictionary:
	var total: int = 0
	var unlocked_count: int = 0

	for e in _entries.values():
		if category.is_empty() or e.get("category") == category:
			total += 1
			if e.get("unlocked", false):
				unlocked_count += 1

	var pct: int = int((float(unlocked_count) / float(maxi(1, total))) * 100.0)
	return {
		"unlocked": unlocked_count,
		"total": total,
		"percentage": pct
	}


## SaveManager için dışa aktarma
func export_save_data() -> Dictionary:
	var states: Dictionary = {}
	for k in _entries.keys():
		states[k] = {
			"unlocked": _entries[k].get("unlocked", false),
			"encountered": _entries[k].get("encountered", false),
			"kills": _entries[k].get("kills", 0)
		}
	return states


## SaveManager'dan içe aktarma
func import_save_data(data: Dictionary) -> void:
	if not data is Dictionary:
		return

	for k in data.keys():
		if _entries.has(k) and data[k] is Dictionary:
			var item = data[k]
			_entries[k]["unlocked"] = bool(item.get("unlocked", false))
			_entries[k]["encountered"] = bool(item.get("encountered", false))
			_entries[k]["kills"] = int(item.get("kills", 0))

	entry_updated.emit("", {})


func reset_codex() -> void:
	init_default_codex()
