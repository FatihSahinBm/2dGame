extends SceneTree

const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"
const VladSpearProjectile = preload("res://scripts/projectiles/vlad_spear_projectile.gd")

var stage: Node
var player: Player
var vlad: CharacterBody2D
var frame_counter: int = 0
var test_step: int = 0

var passed_checks: Array[int] = [0]
var failed_checks: Array[int] = [0]
var errors: Array[String] = []

var assert_check = func(cond: bool, msg: String) -> void:
	if cond:
		print("  [PASS] ", msg)
		passed_checks[0] += 1
	else:
		printerr("  [FAIL] ", msg)
		failed_checks[0] += 1
		errors.append(msg)

func _init() -> void:
	print("==================================================================")
	print("--- TEST SUITE: VLAD HUMAN FORM SPEAR THROW PLATFORM AUDIT ---")
	print("==================================================================")
	
	var packed: PackedScene = load(STAGE3_PATH) as PackedScene
	if not packed:
		_fail("Could not load stage 3 throne room scene")
		return
	stage = packed.instantiate()
	root.add_child(stage)
	player = stage.get_node_or_null("CombatPlayer") as Player
	vlad = stage.get_node_or_null("VladBoss") as CharacterBody2D
	
	if not player or not vlad:
		_fail("CombatPlayer or VladBoss node not found in stage")
		return
	
	# Sinematik ve diyaloğu devre dışı bırakıp aktif savaşa al
	vlad.is_active = true
	vlad._is_in_cinematic = false
	if stage.dialogue_box:
		stage.dialogue_box.visible = false

func _process(_delta: float) -> bool:
	frame_counter += 1
	if frame_counter < 3:
		return false
	
	run_tests()
	return true

func run_tests() -> void:
	# -----------------------------------------------------------------
	# 1. Zemin Seviyesi Saldırı Davranışının Korunması
	# -----------------------------------------------------------------
	print("\n[TEST 1: Normal Form Ground Melee Combat Preserved]")
	vlad.set_form(0, false)
	player.global_position = Vector2(300, 560)
	vlad.global_position = Vector2(250, 560) # dist_x = 50px, diff_y = 0px
	vlad._attack_timer = 0.0
	vlad._target_node = player
	
	# diff_y <= 35px olduğunda standart thrust veya impale tetiklenmeli
	vlad._chase_normal_form(0.016, 50.0, 50.0, 0.0)
	assert_check.call(vlad.current_state == vlad.State.ATTACK, "Boss enters melee ATTACK state on same ground level")
	assert_check.call(vlad.anim_sprite.animation in [&"attack_thrust", &"attack_impale"], "Boss plays attack_thrust or attack_impale on ground")
	assert_check.call(vlad.get_node_or_null("SpearAimTelegraph") == null, "No spear aim telegraph line spawned during ground melee")
	
	# Toparlanma
	vlad.current_state = vlad.State.CHASE
	vlad._attack_timer = 0.0
	
	# -----------------------------------------------------------------
	# 2. PlatformLeft Üzerindeki Oyuncuya Karşı Mızrak Fırlatma
	# -----------------------------------------------------------------
	print("\n[TEST 2: PlatformLeft Elevated Counter-Attack]")
	vlad.set_form(0, false)
	player.global_position = Vector2(200, 418) # On PlatformLeft
	vlad.global_position = Vector2(360, 560) # In the open to the right of PlatformLeft (80..320)
	vlad._target_node = player
	vlad._attack_timer = 0.0
	
	var diff_y_p1 = player.global_position.y - vlad.global_position.y # -142.0
	var dist_x_p1 = absf(player.global_position.x - vlad.global_position.x) # 160.0
	
	vlad._chase_normal_form(0.016, 214.0, dist_x_p1, diff_y_p1)
	assert_check.call(vlad.current_state == vlad.State.ATTACK, "Boss enters ATTACK state when player is elevated on PlatformLeft")
	assert_check.call(vlad.anim_sprite.animation in [&"attack_throw", &"normal_attack_throw", &"attack_thrust"], "Boss initiates attack_throw animation for spear throw")
	var telegraph_p1 = stage.get_node_or_null("SpearAimTelegraph") as Line2D
	assert_check.call(telegraph_p1 != null, "SpearAimTelegraph Line2D exists during throw preparation")
	if telegraph_p1:
		assert_check.call(telegraph_p1.points.size() == 2, "Telegraph line connects Vlad to locked target position")
	
	# -----------------------------------------------------------------
	# 3. PlatformRight Üzerindeki Oyuncuya Karşı Davranış
	# -----------------------------------------------------------------
	print("\n[TEST 3: PlatformRight Elevated Counter-Attack]")
	vlad._clear_spear_throw_telegraph()
	vlad.current_state = vlad.State.CHASE
	vlad._attack_timer = 0.0
	
	player.global_position = Vector2(980, 418) # On PlatformRight (860..1100)
	vlad.global_position = Vector2(780, 560) # In open center
	vlad._target_node = player
	
	var diff_y_p2 = player.global_position.y - vlad.global_position.y # -142.0
	var dist_x_p2 = absf(player.global_position.x - vlad.global_position.x) # 200.0
	
	vlad._chase_normal_form(0.016, 245.0, dist_x_p2, diff_y_p2)
	assert_check.call(vlad.current_state == vlad.State.ATTACK, "Boss triggers counter-attack when player is on PlatformRight")
	var telegraph_p2 = stage.get_node_or_null("SpearAimTelegraph") as Line2D
	assert_check.call(telegraph_p2 != null, "SpearAimTelegraph appears correctly for PlatformRight")
	
	# -----------------------------------------------------------------
	# 4. Oyuncu Platformdan Zemine İndiğinde Normal Saldırıya Dönüş
	# -----------------------------------------------------------------
	print("\n[TEST 4: Transition from Platform to Ground Combat]")
	vlad._clear_spear_throw_telegraph()
	vlad.current_state = vlad.State.CHASE
	vlad._attack_timer = 0.0
	
	# Oyuncu zemine indi
	player.global_position = Vector2(830, 560) # 50px away from Vlad (780)
	vlad._chase_normal_form(0.016, 50.0, 50.0, 0.0)
	assert_check.call(vlad.current_state == vlad.State.ATTACK, "Boss attacks immediately when player lands on ground")
	assert_check.call(stage.get_node_or_null("SpearAimTelegraph") == null, "Spear telegraph not present for ground player")
	
	# -----------------------------------------------------------------
	# 5. Hazırlık / Telgraf Sırasında Hasar Verilmemesi
	# -----------------------------------------------------------------
	print("\n[TEST 5: No Premature Damage During Telegraph]")
	vlad._clear_spear_throw_telegraph()
	vlad.current_state = vlad.State.CHASE
	vlad._attack_timer = 0.0
	
	player.global_position = Vector2(200, 418)
	vlad.global_position = Vector2(380, 560)
	player.current_health = 100
	
	# Başlat
	vlad._execute_normal_spear_throw()
	assert_check.call(vlad._atk_hit_on == false, "Hitbox is NOT active during windup")
	assert_check.call(player.current_health == 100, "Player has taken 0 damage during telegraph preparation (f 0..8)")
	
	# -----------------------------------------------------------------
	# 6. Etki Alanı Dışındaki Oyuncunun Hasar Almaması
	# -----------------------------------------------------------------
	print("\n[TEST 6: Out of Range / Dodged Projectile Inflicts No Damage]")
	# Mızrağı belirli bir hedefe fırlat
	var initial_hp = player.current_health
	var spear_inst = vlad.spear_scene.instantiate() as VladSpearProjectile
	stage.add_child(spear_inst)
	# Mızrağı oyuncunun uzağına (örneğin yukarı boşluğa) fırlat
	spear_inst.setup(Vector2(500, 500), Vector2(1, 0), 35, vlad)
	# 10 fizik adımı simüle et
	for i in range(10):
		spear_inst._physics_process(0.016)
	assert_check.call(player.current_health == initial_hp, "Player far from spear trajectory receives no damage")
	spear_inst.queue_free()
	
	# -----------------------------------------------------------------
	# 7. Oyuncu Saldırıdan Kaçındığında (Dodge / Jump) Atlatabilme
	# -----------------------------------------------------------------
	print("\n[TEST 7: Evading the Spear with Jump or Movement]")
	var spear_test2 = vlad.spear_scene.instantiate() as VladSpearProjectile
	stage.add_child(spear_test2)
	# Mızrak platform yüksekliğine (Y=418) atılıyor
	spear_test2.setup(Vector2(100, 418), Vector2(1, 0), 35, vlad)
	
	# Oyuncu zıplayarak Y=350 seviyesine yükseldi
	player.global_position = Vector2(160, 340)
	# Mızrak oyuncunun altından geçer
	for i in range(15):
		spear_test2._physics_process(0.016)
	assert_check.call(player.current_health == initial_hp, "Jumping above spear trajectory successfully dodges the attack")
	spear_test2.queue_free()
	
	# -----------------------------------------------------------------
	# 8. Saldırı Cooldown Koruması (Anti-Spam)
	# -----------------------------------------------------------------
	print("\n[TEST 8: Attack Cooldown Integrity & Anti-Spam]")
	vlad.current_state = vlad.State.CHASE
	vlad._attack_timer = 2.0 # Cooldown devam ediyor
	player.global_position = Vector2(200, 418)
	vlad.global_position = Vector2(380, 560)
	
	vlad._chase_normal_form(0.016, 220.0, 180.0, -142.0)
	assert_check.call(vlad.current_state == vlad.State.CHASE, "Boss does NOT attack while cooldown timer is positive")
	assert_check.call(vlad.anim_sprite.animation == &"idle", "Boss holds idle stance during platform cooldown")
	
	# -----------------------------------------------------------------
	# 9. Sersemleme, Ölüm ve Form Geçişinde Temizlenme
	# -----------------------------------------------------------------
	print("\n[TEST 9: Clean Interruption on Stun, Death and Form Change]")
	vlad._execute_normal_spear_throw()
	assert_check.call(stage.get_node_or_null("SpearAimTelegraph") != null, "Telegraph line active before stun")
	
	# Sersemletme çağrısı
	vlad._trigger_groggy_stun()
	assert_check.call(vlad.current_state == vlad.State.GROGGY, "Boss enters GROGGY state")
	assert_check.call(stage.get_node_or_null("SpearAimTelegraph") == null, "Telegraph line cleanly removed upon groggy stun")
	
	# Form dönüşüm çağrısı
	vlad._execute_normal_spear_throw()
	vlad.set_form(1, false) # Vampire
	assert_check.call(stage.get_node_or_null("SpearAimTelegraph") == null, "Telegraph line cleanly removed upon form change")
	
	# -----------------------------------------------------------------
	# 10. Diğer 3 Formun Regresyon Doğrulaması
	# -----------------------------------------------------------------
	print("\n[TEST 10: Multi-Form Regression Verification (Vampire, Werewolf, Bat)]")
	# 10.1 Vampir Formu
	vlad.set_form(1, false)
	assert_check.call(vlad.current_form == vlad.VladForm.VAMPIRE, "Form transitioned to VAMPIRE")
	assert_check.call(vlad.blood_shield_active == true, "Vampire blood shield active")
	assert_check.call(vlad.attack_damage == vlad.vampire_slash_damage, "Vampire attack damage matches (40)")
	
	# 10.2 Kurt Adam Formu
	vlad.set_form(2, false)
	assert_check.call(vlad.current_form == vlad.VladForm.WEREWOLF, "Form transitioned to WEREWOLF")
	assert_check.call(vlad.chase_speed == 160.0, "Werewolf chase speed preserved (160)")
	assert_check.call(vlad.has_method("_execute_werewolf_leap"), "Werewolf leap attack intact")
	
	# 10.3 Dev Yarasa Formu
	vlad.set_form(3, false)
	assert_check.call(vlad.current_form == vlad.VladForm.BAT, "Form transitioned to BAT")
	assert_check.call(vlad.is_flying == true, "Bat form is_flying == true")
	assert_check.call(vlad.has_method("_execute_bat_dive"), "Bat dive attack intact")
	
	print("\n==================================================================")
	print("AUDIT RESULTS: %d PASSED, %d FAILED" % [passed_checks[0], failed_checks[0]])
	print("==================================================================")
	
	if failed_checks[0] > 0:
		print("FAILED TESTS:")
		for err in errors:
			print("  - ", err)
		quit(1)
	else:
		print("ALL 10 TARGET SPEAR THROW PLATFORM TESTS PASSED WITH 0 ERRORS!")
		quit(0)

func _fail(msg: String) -> void:
	print("[FATAL ERROR] ", msg)
	quit(1)
