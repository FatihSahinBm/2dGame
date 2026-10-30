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
		"title_en": "Wallachian Guard Infantry",
		"subtitle": "Kaledeki Devriye Askerleri",
		"subtitle_en": "Citadel Patrol Guards",
		"era": "Eflak / Transilvanya — 1462",
		"era_en": "Wallachia / Transylvania — 1462",
		"icon_path": "res://assets/ui/portraits/portrait_blood_knight.png",
		"unlocked": true, # İlk haritada doğrudan karşılaşılır
		"encountered": true,
		"kills": 0,
		"description": "Vlad Tepeş'in hizmetindeki zırhlı Eflak askerleri. Kılıç darbeleri ve kalkanlarıyla devriye gezerler. Çapraz saldırılarda savunmasız kalırlar.",
		"description_en": "Armored Wallachian infantry loyal to Vlad the Impaler. They patrol with broadswords and shields, vulnerable to flank attacks.",
		"tactics": "Saldırı savurduktan sonra arkalarına yuvarlanarak (Roll) kombo vuruşu yapın.",
		"tactics_en": "Evade their slash with a dodge roll, then counterattack from behind.",
		"weakness": "Arkadan darbeler ve Fırlatma Bıçağı",
		"weakness_en": "Backstabs & Throwing Knives",
		"stats_summary": "Tehlike: ⭐ | Can: 100 | Hasar Türü: Fiziksel Kesici",
		"stats_summary_en": "Threat: ⭐ | HP: 100 | Damage: Slashing Physical"
	})

	register_entry({
		"id": "skeleton",
		"category": "enemies",
		"title": "Hortlak İskelet Savaşçı",
		"title_en": "Restless Skeleton Warrior",
		"subtitle": "Mezardan Çıkarılmış Kadim Muhafız",
		"subtitle_en": "Exhumed Ancient Sentinel",
		"era": "Karanlık Çağlar & Yeraltı Mezarları",
		"era_en": "Dark Ages & Catacombs",
		"icon_path": "res://assets/ui/portraits/portrait_skeleton.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Nekromansi büyüsüyle kemikleri birleştirilmiş savaşçılar. Canları bittiğinde parçalanırlar; kutsal su ve ezici darbeler kemiklerini un ufak eder.",
		"description_en": "Skeletal warriors reassembled through dark necromancy. Holy water and blunt concussions shatter their fragile bones to powder.",
		"tactics": "Toplu gruplarda meşale veya kutsal su kullanarak tek hamlede temizleyin.",
		"tactics_en": "Hurl torches or holy water flasks into clusters to purge them in a single strike.",
		"weakness": "Kutsal Su (45 Hasar) ve Yangın",
		"weakness_en": "Holy Water (45 Dmg) & Fire",
		"stats_summary": "Tehlike: ⭐⭐ | Can: 80 | Hasar Türü: Delici Kemik Darbesi",
		"stats_summary_en": "Threat: ⭐⭐ | HP: 80 | Damage: Piercing Bone Thrust"
	})

	register_entry({
		"id": "flying_eye",
		"category": "enemies",
		"title": "Uçan İblis Gözü",
		"title_en": "Flying Demon Eye",
		"subtitle": "Karanlık Havadan Gözcü",
		"subtitle_en": "Aerial Abyssal Scout",
		"era": "Bilinmeyen Karanlık Boyut",
		"era_en": "Unknown Nether Dimension",
		"icon_path": "res://assets/ui/portraits/portrait_flying_eye.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Havada süzülerek hedefe ani dalışlar yapan lanetli gözler. Geniş görüş açısıyla tuzak kurarlar.",
		"description_en": "Cursed floating eyeballs that swoop down upon prey at high velocity. Their wide vision warns nearby packs.",
		"tactics": "Dalış anında yukarı zıplayarak savurma yapın veya fırlatma bıçağıyla menzilden vurun.",
		"tactics_en": "Leap upward during their dive to counter-slash, or shoot them down from afar with throwing daggers.",
		"weakness": "Fırlatma Bıçağı (Tek Atış) ve Alevli Oklar",
		"weakness_en": "Throwing Knives (One-shot) & Fire Arrows",
		"stats_summary": "Tehlike: ⭐⭐ | Can: 45 | Hasar Türü: Hava Dalışı",
		"stats_summary_en": "Threat: ⭐⭐ | HP: 45 | Damage: Aerial Dive"
	})

	register_entry({
		"id": "goblin",
		"category": "enemies",
		"title": "Orman Akıncısı Goblin",
		"title_en": "Forest Raider Goblin",
		"subtitle": "Sinsi Pusu Yaratığı",
		"subtitle_en": "Cunning Ambush Skulker",
		"era": "Karanlık Orman Derinlikleri",
		"era_en": "Dark Forest Depths",
		"icon_path": "res://assets/ui/portraits/portrait_goblin.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Çalılıklar ve taş aralıklarında saklanıp fırlattıkları hançerlerle zehir bulaştıran sinsi canlılar.",
		"description_en": "Devious scavengers lurking in brush and crags, hurling envenomed daggers from concealment.",
		"tactics": "Sarmaşıkları meşaleyle yakarak saklandıkları alanları açığa çıkarın.",
		"tactics_en": "Ignite undergrowth with torches to expose their hiding positions.",
		"weakness": "Ateş ve Sarmaşık Temizleme",
		"weakness_en": "Fire & Brush Clearing",
		"stats_summary": "Tehlike: ⭐⭐ | Can: 60 | Hasar Türü: Zehirli Hançer",
		"stats_summary_en": "Threat: ⭐⭐ | HP: 60 | Damage: Poisoned Dagger"
	})

	register_entry({
		"id": "mushroom",
		"category": "enemies",
		"title": "Zehirli Mahzen Mantarı",
		"title_en": "Toxic Dungeon Fungus",
		"subtitle": "Biyolojik Savunma Mantarı",
		"subtitle_en": "Biological Spore Hazard",
		"era": "Târgovişte Nemli Mahzenleri",
		"era_en": "Târgovişte Damp Crypts",
		"icon_path": "res://assets/ui/portraits/portrait_mushroom.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Yaklaştığınızda çevreye ölümcül spor gazları salan dev mantar kolonileri.",
		"description_en": "Colossal fungal colonies that detonate in clouds of deadly spores upon close approach.",
		"tactics": "Yakın dövüşe girmeden uzaktan alevli meşale fırlatarak patlatın.",
		"tactics_en": "Ignite them safely from range using thrown torches before walking past.",
		"weakness": "Meşale Yangın Alanı",
		"weakness_en": "Torch Fire & Range",
		"stats_summary": "Tehlike: ⭐⭐ | Can: 50 | Hasar Türü: Spor Gazı",
		"stats_summary_en": "Threat: ⭐⭐ | HP: 50 | Damage: Spore Gas"
	})

	register_entry({
		"id": "necromancer",
		"category": "enemies",
		"title": "Gölge Nekromanseri",
		"title_en": "Shadow Necromancer",
		"subtitle": "Kara Büyü Rahibi",
		"subtitle_en": "Dark Magic Priest",
		"era": "Eflak Mahzenleri — 1462",
		"era_en": "Wallachian Vaults — 1462",
		"icon_path": "res://assets/ui/portraits/portrait_necromancer.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Ölüleri dirilterek ordular kuran karanlık tarikat üyeleri. Işınlanma yetenekleriyle menzilli büyü küreleri fırlatırlar.",
		"description_en": "Cultists who reanimate the dead to form legions, blinking away to cast piercing dark arcane spheres.",
		"tactics": "Büyü yaparken kılıçla kesintiye (Interrupt) uğratın.",
		"tactics_en": "Interrupt their incantations with fast sword slashes before they release arcane volleys.",
		"weakness": "Kutsal Su ve Hızlı Kombo",
		"weakness_en": "Holy Water & Rapid Combos",
		"stats_summary": "Tehlike: ⭐⭐⭐ | Can: 160 | Hasar Türü: Kara Büyü",
		"stats_summary_en": "Threat: ⭐⭐⭐ | HP: 160 | Damage: Dark Arcane"
	})

	register_entry({
		"id": "ceiling_lurker_bat",
		"category": "enemies",
		"title": "Tavan Pusucusu Dev Yarasa",
		"title_en": "Ceiling Lurker Bat",
		"subtitle": "Kan Emici Mağara Canavarı",
		"subtitle_en": "Blood-Gorging Vault Beast",
		"era": "Karanlık Zindan Tavanları",
		"era_en": "Gothic Dungeon Ceilings",
		"icon_path": "res://assets/ui/portraits/portrait_vlad_bat.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Tavan sarkıtlarında uyuyup altından geçen kurbanların üzerine son hızla çullanan devasa yarasalar.",
		"description_en": "Giant predatory bats hanging from cavern stalactites that dive onto unwary wanderers.",
		"tactics": "Tavana meşale atarak uyandırıp dengesini bozun.",
		"tactics_en": "Hurl a torch at the ceiling to break their grip and destabilize their flight path.",
		"weakness": "Işık, Yangın ve Kutsal Su",
		"weakness_en": "Light, Fire & Holy Water",
		"stats_summary": "Tehlike: ⭐⭐⭐ | Can: 120 | Hasar Türü: Kan Sömürme",
		"stats_summary_en": "Threat: ⭐⭐⭐ | HP: 120 | Damage: Sanguine Leech"
	})

	# ==========================================================================
	# 2. KATEGORİ: ELEBAŞILAR (BOSSES)
	# ==========================================================================

	register_entry({
		"id": "blood_knight",
		"category": "bosses",
		"title": "Eflak Kan Şövalyesi",
		"title_en": "Wallachian Blood Knight",
		"subtitle": "Taş Köprü Muhafız Komutanı (Mini-Boss)",
		"subtitle_en": "Stone Bridge Guard Commander (Mini-Boss)",
		"era": "Taş Köprü Kuşatması — 1462",
		"era_en": "Bridge Siege — 1462",
		"icon_path": "res://assets/ui/portraits/portrait_blood_knight.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Vlad'ın seçkin muhafız birliğinin başındaki dev kan şövalyesi. 520 cana sahip kalın zırhı ve geniş kılıç savurmalarıyla köprüyü savunur.",
		"description_en": "The towering champion commanding Vlad's elite vanguard. Encased in 520 HP heavy plate, defending the bridge with sweeping cleaves.",
		"tactics": "Kılıç savurduğu an takla atarak arkasına geçin. Kemankeş'in alevli ok desteğiyle zırhını kırın.",
		"tactics_en": "Roll through his cleave to strike from behind, coordinating with the archer's fire arrows to crack his plate.",
		"weakness": "Alevli Ok Bombardımanı & Kutsal Su",
		"weakness_en": "Flaming Arrow Barrage & Holy Water",
		"stats_summary": "Tehlike: ⭐⭐⭐⭐ | Can: 520 | Hasar: 24 | Zırh: Ağır Çelik",
		"stats_summary_en": "Threat: ⭐⭐⭐⭐ | HP: 520 | Attack: 24 | Armor: Heavy Steel"
	})

	register_entry({
		"id": "ogre_boss",
		"category": "bosses",
		"title": "Dağ Devi (Ogre)",
		"title_en": "Mountain Ogre",
		"subtitle": "Karanlık Orman Ezicisi",
		"subtitle_en": "Deep Forest Crusher",
		"era": "İlk Çağlar — İlkel Vadiler",
		"era_en": "Primeval Era — Ancient Valleys",
		"icon_path": "res://assets/ui/portraits/portrait_blood_knight.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Ağaç kütüklerini silah olarak kullanan, yere vurarak şok dalgaları oluşturan muazzam cüsseli dev canavar.",
		"description_en": "A titanic brute wielding petrified tree trunks, slamming the bedrock to trigger devastating ground shockwaves.",
		"tactics": "Yere vurduğunda havaya zıplayarak şok dalgasından kaçının.",
		"tactics_en": "Jump into the air during ground slams to evade the tremor, then combo its head.",
		"weakness": "Hızlı Atılma (Dash) ve Baş Bölgesine Kombo",
		"weakness_en": "Dash Evasions & Head Combos",
		"stats_summary": "Tehlike: ⭐⭐⭐⭐ | Can: 650 | Hasar Türü: Ezici Şok Dalgası",
		"stats_summary_en": "Threat: ⭐⭐⭐⭐ | HP: 650 | Damage: Crushing Shockwave"
	})

	register_entry({
		"id": "trex_boss",
		"category": "bosses",
		"title": "Kadim Apex T-Rex",
		"title_en": "Ancient Cyber Apex T-Rex",
		"subtitle": "Taş Devri Zaman Çatlağı Canavarı",
		"subtitle_en": "Stone Age Rift Monstrosity",
		"era": "Taş Devri — M.Ö. 65 Milyon Yıl",
		"era_en": "Stone Age — 65 Million BC",
		"icon_path": "res://assets/ui/portraits/portrait_skeleton.png",
		"unlocked": true,
		"encountered": true,
		"kills": 1,
		"description": "Zaman yarığının üzerinde hüküm süren ilk büyük canavar. İlk Kalp Parçası onun bedeninden saçılmıştır.",
		"description_en": "The sovereign apex beast of the primeval canyon, mutated with future cybernetics. Harboring the 1st World Heart Shard.",
		"tactics": "Kuyruk savurması öncesi çömelin, kükreme anında kulakları koruyarak platformlara tırmanın.",
		"tactics_en": "Evade the tail sweep and take high ground on rock platforms when laser energy charges.",
		"weakness": "İlk Kalp Rezonansı",
		"weakness_en": "1st Heart Resonance",
		"stats_summary": "Tehlike: ⭐⭐⭐⭐⭐ | Can: 1000 | Zafer Ödülü: 1. Kalp Parçası",
		"stats_summary_en": "Threat: ⭐⭐⭐⭐⭐ | HP: 1000 | Reward: 1st Heart Shard"
	})

	register_entry({
		"id": "vlad_boss",
		"category": "bosses",
		"title": "Vlad Tepeş (Kazıklı Voyvoda)",
		"title_en": "Vlad III Dracula (The Impaler)",
		"subtitle": "Eflak Prensi ve Kan Hükümdarı",
		"subtitle_en": "Prince of Wallachia & Sovereign of Blood",
		"era": "Eflak Kalesi Taht Odası & Çan Kulesi — 1462",
		"era_en": "Throne Room & Bell Tower — 1462",
		"icon_path": "res://assets/ui/portraits/portrait_vlad.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Dört farklı dönüşüm fazına (İnsan Kılıç Ustası, Vampir, Kurt Adam, Dev Kan Yarasası) sahip baş düşman. İkinci Kalp Parçasını ele geçirmiştir.",
		"description_en": "The ultimate nemesis possessing four terrifying transformations: Master Duelist, Sanguine Vampire, Lycanthrope, and Abyssal Bat.",
		"tactics": "Kan kalkanını kırın; kurt adam fazında hızını takip edin; son fazda çan kulesi mekanizmalarını kullanın.",
		"tactics_en": "Shatter blood wards with Holy Water; anticipate ferocious wolf lunges; drop bell counterweights in the bell tower.",
		"weakness": "Kutsal Su, Alevli Oklar ve Padişah Yadigarı Kılıç",
		"weakness_en": "Holy Water, Fire Arrows & Sovereign Blade",
		"stats_summary": "Tehlike: ⭐⭐⭐⭐⭐ | Faz: 4 Aşama | Zafer Ödülü: 2. Kalp Parçası",
		"stats_summary_en": "Threat: ⭐⭐⭐⭐⭐ | Phases: 4 Stages | Reward: 2nd Heart Shard"
	})

	# ==========================================================================
	# 3. KATEGORİ: KARAKTERLER & MÜTTEFİKLER (CHARACTERS)
	# ==========================================================================

	register_entry({
		"id": "fatih_mehmed",
		"category": "characters",
		"title": "Fatih Sultan Mehmed Han",
		"title_en": "Sultan Mehmed II (The Conqueror)",
		"subtitle": "Osmanlı Hükümdarı ve Sefer Serdarı",
		"subtitle_en": "Ottoman Emperor & Supreme Commander",
		"era": "Otağ-ı Hümayun — 1462",
		"era_en": "Imperial War Pavilion — 1462",
		"icon_path": "res://assets/ui/portraits/portrait_fatih.png",
		"unlocked": true,
		"encountered": true,
		"kills": 0,
		"description": "İstanbul Fatihi, Vlad Tepeş'in zulmünü durdurmak için bizzat Eflak seferini yöneten genç hükümdar. Oyuncuya kutsal emanet kılıcı ve sefer fermanını teslim etmiştir.",
		"description_en": "The young conqueror of Constantinople, commanding the Wallachian campaign in person to halt Dracula's slaughter.",
		"tactics": "İttifak lideri. Huzurunda felsefi ve tarihi diyaloglar yürütülür.",
		"tactics_en": "Alliance Leader. Counsel him with historical insight during war council audiences.",
		"weakness": "Müttefik",
		"weakness_en": "Imperial Ally",
		"stats_summary": "Rol: Hükümdar / Baş Stratejist | Müttefik",
		"stats_summary_en": "Role: Sovereign / Grand Strategist | Ally"
	})

	register_entry({
		"id": "kemankes",
		"category": "characters",
		"title": "Kemankeş Çavuşu",
		"title_en": "Janissary Archer Sergeant",
		"subtitle": "Osmanlı Keskin Okçusu",
		"subtitle_en": "Ottoman Master Marksman",
		"era": "Osmanlı Ordugahı — 1462",
		"era_en": "Ottoman Encampment — 1462",
		"icon_path": "res://assets/ui/portraits/portrait_kemankes.png",
		"unlocked": true,
		"encountered": true,
		"kills": 0,
		"description": "Vadide kırılan erzak arabasından alevli sadakları toplayan oyuncuya minnettarlık duyarak köprü taarruzunda alevli ok yağmuru desteği sunan usta yeniçeri.",
		"description_en": "Master marksman who rains down flaming barrages on the citadel bridge once his flame quivers are recovered.",
		"tactics": "Sadak görevi tamamlandığında köprüdeki düşmanları menzilden bombalar.",
		"tactics_en": "Completing his sidequest grants heavy ranged flame support during the bridge assault.",
		"weakness": "Müttefik",
		"weakness_en": "Loyal Ally",
		"stats_summary": "Rol: Menzilli Ağır Destek Okçusu | Müttefik",
		"stats_summary_en": "Role: Heavy Ranged Flame Archer | Ally"
	})

	register_entry({
		"id": "janissary_commander",
		"category": "characters",
		"title": "Yeniçeri Kumandanı",
		"title_en": "Janissary Vanguard Commander",
		"subtitle": "Öncü Birlik Serdarı",
		"subtitle_en": "Vanguard Officer",
		"era": "Karanlık Orman ve Ordugah",
		"era_en": "Dark Forest & Camp",
		"icon_path": "res://assets/ui/portraits/portrait_commander.png",
		"unlocked": true,
		"encountered": true,
		"kills": 0,
		"description": "Gece baskınında öncü birliği toparlayarak ordugah meydanını savunan tecrübeli yeniçeri subayı.",
		"description_en": "A seasoned Janissary officer holding the forest pass and orchestrating encampment defenses.",
		"tactics": "Taarruz hattında askerleri koordine eder.",
		"tactics_en": "Coordinates infantry lines across the battlefield.",
		"weakness": "Müttefik",
		"weakness_en": "Loyal Ally",
		"stats_summary": "Rol: Bölük Komutanı | Müttefik",
		"stats_summary_en": "Role: Vanguard Commander | Ally"
	})

	# ==========================================================================
	# 4. KATEGORİ: DÜNYA BİLGİSİ & PARŞÖMENLER (LORE)
	# ==========================================================================

	register_entry({
		"id": "world_heart_myth",
		"category": "lore",
		"title": "Dünya Kalbi ve Dört Parça Efsanesi",
		"title_en": "Myth of the World Heart & Four Shards",
		"subtitle": "Zamanın Dokusu ve Kozmik Çatlaklar",
		"subtitle_en": "Fabric of Time & Cosmic Fissures",
		"era": "Tüm Çağların Başlangıcı",
		"era_en": "Genesis of All Eras",
		"icon_path": "res://assets/ui/portraits/portrait_world_heart.png",
		"unlocked": true,
		"encountered": true,
		"kills": 0,
		"description": "Evrenin zaman dengesini sağlayan Dünya Kalbi dört parçaya bölünerek farklı tarihi çağlara saçılmıştır. Parçalar birleşmezse evren sonsuz döngüde yok olacaktır.",
		"description_en": "The World Heart upholding temporal harmony was shattered across four distinct epochs. Unless reunited, the continuum collapses into void.",
		"tactics": "Dört parçayı toplayarak kadranı tamamlayın.",
		"tactics_en": "Reclaim all four fragments to restore the primordial chronometer.",
		"weakness": "Kozmik Bilgi",
		"weakness_en": "Cosmic Lore",
		"stats_summary": "İlerleme: 4 Parçalık Kozmik Görev",
		"stats_summary_en": "Progress: 4-Shard Cosmic Quest"
	})

	register_entry({
		"id": "vlad_castle_history",
		"category": "lore",
		"title": "Târgovişte ve Kazıklı Savunma Hattı",
		"title_en": "Târgovişte & Impalement Ramparts",
		"subtitle": "Eflak Surları ve Kan Hendekleri",
		"subtitle_en": "Wallachian Walls & Blood Trenches",
		"era": "Eflak / Transilvanya — 1462",
		"era_en": "Wallachia / Transylvania — 1462",
		"icon_path": "res://assets/ui/portraits/portrait_castle_targoviste.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Vlad Tepeş'in esirleri ve köylüleri kazıklara oturttuğu, sarp kayalıklar üzerine inşa edilmiş geçit vermez taş kale.",
		"description_en": "The forbidding fortress perched on sharp cliffs where Dracula impaled thousands to ward off foes.",
		"tactics": "Köprü üzerindeki barikatlar koçbaşı ve meşalelerle parçalanmalıdır.",
		"tactics_en": "Shatter heavy barricades on the stone bridge with battering rams and flame.",
		"weakness": "Tarihi Kayıt",
		"weakness_en": "Historical Record",
		"stats_summary": "Konum: Eflak Geçidi",
		"stats_summary_en": "Location: Wallachian Pass"
	})

	register_entry({
		"id": "ancient_heart_relief",
		"category": "lore",
		"title": "Kadim Kemik Kabartması ve Mistik Mührün Sırrı",
		"title_en": "Ancient Bone Relief & The Arcane Seal",
		"subtitle": "Zindan Duvarındaki Mistik Gravür",
		"subtitle_en": "Crypt Wall Sacred Engraving",
		"era": "Bilinmeyen Kadim Çağ",
		"era_en": "Unknown Primordial Epoch",
		"icon_path": "res://assets/ui/portraits/portrait_ancient_relief.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Zindan mahzenindeki taş kabartmada, Dünya Kalbi'nin gücünü soğuran eski bir medeniyetin çizimleri yer alır.",
		"description_en": "Carved into deep crypt walls, an ancient relief depicts a lost civilization siphoning the World Heart's primordial energy.",
		"tactics": "Mahzende [E] ile incelendiğinde yeni bir diyalog ve aydınlanma sağlar.",
		"tactics_en": "Inspect with [E] in the vault to trigger deep lore dialogue and revelations.",
		"weakness": "Çevresel Anlatı",
		"weakness_en": "Environmental Lore",
		"stats_summary": "Tür: Arşiv Gravürü",
		"stats_summary_en": "Type: Archival Engraving"
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
		"title_en": entry_dict.get("title_en", ""),
		"subtitle": entry_dict.get("subtitle", ""),
		"subtitle_en": entry_dict.get("subtitle_en", ""),
		"era": entry_dict.get("era", "Bilinmeyen Çağ"),
		"era_en": entry_dict.get("era_en", ""),
		"icon_path": entry_dict.get("icon_path", "res://scenes/ui/icons/icon_sword_slot.png"),
		"unlocked": bool(entry_dict.get("unlocked", false)),
		"encountered": bool(entry_dict.get("encountered", false)),
		"kills": int(entry_dict.get("kills", 0)),
		"description": entry_dict.get("description", ""),
		"description_en": entry_dict.get("description_en", ""),
		"tactics": entry_dict.get("tactics", "Özel taktik bulunmuyor."),
		"tactics_en": entry_dict.get("tactics_en", ""),
		"weakness": entry_dict.get("weakness", "Bilinmiyor"),
		"weakness_en": entry_dict.get("weakness_en", ""),
		"stats_summary": entry_dict.get("stats_summary", ""),
		"stats_summary_en": entry_dict.get("stats_summary_en", "")
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
		"title_en": "??? (Unknown Entry)",
		"subtitle": "Henüz Keşfedilmedi",
		"subtitle_en": "Not Yet Discovered",
		"era": "???",
		"era_en": "???",
		"icon_path": "res://scenes/ui/icons/icon_key.png",
		"unlocked": false,
		"encountered": false,
		"kills": 0,
		"description": "Bu varlıkla henüz karşılaşılmadı veya kadim parşömen henüz okunmadı. Dünyayı keşfederek veya düşmanı yenerek kodeks kaydını açın.",
		"description_en": "This entity has not been encountered or scroll not yet deciphered. Explore the realm or defeat foes to unlock this codex entry.",
		"tactics": "🔒 Bilgiler Kilitli",
		"tactics_en": "🔒 Information Locked",
		"weakness": "🔒 Bilinmiyor",
		"weakness_en": "🔒 Unknown",
		"stats_summary": "Tehlike: ??? | Durum: Kilitli",
		"stats_summary_en": "Threat: ??? | Status: Locked",
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

