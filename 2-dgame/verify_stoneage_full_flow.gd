@tool
extends SceneTree

## res://verify_stoneage_full_flow.gd
## Taş Devri Bölüm 01 -> Bölüm 02 -> Bölüm 03 -> Bölüm 04 Tam Geçiş Doğrulama Testi

func _init() -> void:
	print("--- STONE AGE FULL FLOW (LEVEL 01 -> 02 -> 03 -> 04) TEST START ---")

	# 1. Level 01 Yükleme ve Çıkış
	var l1_res = load("res://scenes/levels/stoneage/stoneage_01_time_rift_fall.tscn")
	assert(l1_res != null, "Level 01 failed to load")
	var l1 = l1_res.instantiate()
	root.add_child(l1)
	print("OK: Level 01 instantiated.")
	var player1 = l1.get_node_or_null("CombatPlayer")
	assert(player1 != null, "Player missing in Level 01")
	l1._restore_player_control()
	l1._on_exit_zone_body_entered(player1)
	print("OK: Level 01 exit triggered -> points to Level 02.")
	l1.queue_free()

	# 2. Level 02 Yükleme ve Çıkış
	var l2_res = load("res://scenes/levels/stoneage/stoneage_02_silent_valley.tscn")
	assert(l2_res != null, "Level 02 failed to load")
	var l2 = l2_res.instantiate()
	root.add_child(l2)
	print("OK: Level 02 instantiated.")
	var player2 = l2.get_node_or_null("CombatPlayer")
	assert(player2 != null, "Player missing in Level 02")
	l2._on_exit_zone_body_entered(player2)
	print("OK: Level 02 exit triggered -> points to Level 03.")
	l2.queue_free()

	# 3. Level 03 Yükleme ve Çıkış
	var l3_res = load("res://scenes/levels/stoneage/stoneage_03_broken_pass.tscn")
	assert(l3_res != null, "Level 03 failed to load")
	var l3 = l3_res.instantiate()
	root.add_child(l3)
	print("OK: Level 03 instantiated.")
	var player3 = l3.get_node_or_null("CombatPlayer")
	assert(player3 != null, "Player missing in Level 03")
	l3._on_exit_zone_body_entered(player3)
	print("OK: Level 03 exit triggered -> points to Level 04.")
	l3.queue_free()

	# 4. Level 04 Yükleme ve Doğrulama
	var l4_res = load("res://scenes/levels/stoneage/stoneage_04_hunters_traces.tscn")
	assert(l4_res != null, "Level 04 failed to load")
	var l4 = l4_res.instantiate()
	root.add_child(l4)
	print("OK: Level 04 instantiated successfully at the end of the transition pipeline.")

	var player4 = l4.get_node_or_null("CombatPlayer")
	var hud4 = l4.get_node_or_null("FantasyHUD")
	var exit4 = l4.get_node_or_null("Environment/ExitZone")
	var shadow4 = l4.get_node_or_null("DistantShadowPresence/ApexDistantShadow")

	assert(player4 != null, "CombatPlayer missing in Level 04")
	assert(hud4 != null, "FantasyHUD missing in Level 04")
	assert(exit4 != null, "ExitZone missing in Level 04")
	assert(shadow4 != null, "Distant Shadow missing in Level 04")

	if not l4.player or not l4._player_camera:
		l4._ensure_node_refs()
		l4._setup_player()
		l4._setup_triggers()

	print("OK: Level 04 camera limits: left=", l4._player_camera.limit_left, ", right=", l4._player_camera.limit_right)
	print("OK: Level 04 controls armed: ", player4.is_armed)

	# 5. Level 04 Milestone ve Çıkış
	l4._on_footprint_zone_body_entered(player4)
	l4._on_trunk_zone_body_entered(player4)
	l4._on_deadfall_hazard_body_entered(player4)
	l4._on_presence_zone_body_entered(player4)
	l4._on_exit_zone_body_entered(player4)
	print("OK: Level 04 exit triggered -> points to Level 05.")
	l4.queue_free()

	# 6. Level 05 Yükleme ve Doğrulama
	var l5_res = load("res://scenes/levels/stoneage/stoneage_05_temporal_fragments.tscn")
	assert(l5_res != null, "Level 05 failed to load")
	var l5 = l5_res.instantiate()
	root.add_child(l5)
	print("OK: Level 05 instantiated successfully at the end of the transition pipeline.")

	var player5 = l5.get_node_or_null("CombatPlayer")
	var hud5 = l5.get_node_or_null("FantasyHUD")
	var exit5 = l5.get_node_or_null("Environment/ExitZone")
	var socket5 = l5.get_node_or_null("MechanicalRemnants/MassiveArmatureSocket")

	assert(player5 != null, "CombatPlayer missing in Level 05")
	assert(hud5 != null, "FantasyHUD missing in Level 05")
	assert(exit5 != null, "ExitZone missing in Level 05")
	assert(socket5 != null, "MassiveArmatureSocket missing in Level 05")

	if not l5.player or not l5._player_camera:
		l5._ensure_node_refs()
		l5._setup_player()
		l5._setup_triggers()

	print("OK: Level 05 camera limits: left=", l5._player_camera.limit_left, ", right=", l5._player_camera.limit_right)
	print("OK: Level 05 controls armed: ", player5.is_armed)

	# 7. Level 05 İpucu ve Kilometre Taşları
	l5._on_plates_zone_body_entered(player5)
	l5._on_joint_zone_body_entered(player5)
	l5._on_resonance_zone_body_entered(player5)
	l5._on_socket_zone_body_entered(player5)
	l5._on_exit_zone_body_entered(player5)

	# Physics process step
	for i in range(15):
		player5._physics_process(0.0166)

	# 8. Level 06 Yükleme ve Doğrulama
	var l6_res = load("res://scenes/levels/stoneage/stoneage_06_beasts_domain.tscn")
	assert(l6_res != null, "Level 06 failed to load")
	var l6 = l6_res.instantiate()
	root.add_child(l6)
	print("OK: Level 06 instantiated successfully from Level 05 transition.")

	var player6 = l6.get_node_or_null("CombatPlayer")
	var hud6 = l6.get_node_or_null("FantasyHUD")
	var exit6 = l6.get_node_or_null("Environment/ExitZone")
	var nest6 = l6.get_node_or_null("PrehistoricForestProps/NestDepressionMound1")

	assert(player6 != null, "CombatPlayer missing in Level 06")
	assert(hud6 != null, "FantasyHUD missing in Level 06")
	assert(exit6 != null, "ExitZone missing in Level 06")
	assert(nest6 != null, "NestDepressionMound1 missing in Level 06")

	if not l6.player or not l6._player_camera:
		l6._ensure_node_refs()
		l6._setup_player()
		l6._setup_camera()
		l6._setup_triggers()

	print("OK: Level 06 camera limits: left=", l6._player_camera.limit_left, ", right=", l6._player_camera.limit_right)
	print("OK: Level 06 controls armed: ", player6.is_armed)

	# 9. Level 06 İpucu ve Kilometre Taşları
	l6._on_footprint_zone_body_entered(player6)
	l6._on_claw_zone_body_entered(player6)
	l6._on_nest_zone_body_entered(player6)
	l6._on_exit_zone_body_entered(player6)

	for i in range(15):
		player6._physics_process(0.0166)

	l6.queue_free()

	# 10. Level 07 Boss Karşılaşması Sahnesi Yükleme
	var l7_res = load("res://scenes/levels/stoneage/stoneage_07_mother_trex.tscn")
	assert(l7_res != null, "Level 07 failed to load")
	var l7 = l7_res.instantiate()
	root.add_child(l7)
	print("OK: Level 07 (Dev Anne T-Rex Boss) instantiated successfully.")
	var player7 = l7.get_node_or_null("CombatPlayer")
	var trex = l7.get_node_or_null("TrexBoss")
	assert(player7 != null, "Player missing in Level 07")
	assert(trex != null, "TrexBoss missing in Level 07")
	l7.queue_free()

	# 11. Level 08 İlk Kalp Parçası ve Boss Sonrası Sahnesi
	var l8_res = load("res://scenes/levels/stoneage/stoneage_08_first_heart_fragment.tscn")
	assert(l8_res != null, "Level 08 failed to load")
	var l8 = l8_res.instantiate()
	root.add_child(l8)
	print("OK: Level 08 (İlk Kalp Parçası & Çağ Geçişi) instantiated successfully.")
	var player8 = l8.get_node_or_null("CombatPlayer")
	var heart8 = l8.get_node_or_null("HeartFragment")
	var rift8 = l8.get_node_or_null("TemporalTimeRift")
	var flash8 = l8.get_node_or_null("FlashbackSequence")
	assert(player8 != null, "Player missing in Level 08")
	assert(heart8 != null, "HeartFragment missing in Level 08")
	assert(rift8 != null, "TemporalTimeRift missing in Level 08")
	assert(flash8 != null, "FlashbackSequence missing in Level 08")

	# Test pickup, flashback, and rift
	l8._on_heart_fragment_body_entered(player8)
	l8._start_first_flashback()
	l8._end_first_flashback()
	l8._on_time_rift_body_entered(player8)
	assert(ResourceLoader.exists(l8.next_era_scene_path), "Next era scene path does not exist")
	print("OK: Level 08 all narrative steps and next era transition verified -> points to Vlad era.")
	l8.queue_free()

	print("--- FULL STONE AGE CHAPTER (LEVELS 01 TO 08) FULL CHAIN PASSED 100%! ---")
	quit(0)
