extends SceneTree

var _checks := 0
var _fails := 0

func _initialize() -> void:
	_run()

func _check(label: String, cond: bool, info := "") -> void:
	_checks += 1
	if cond:
		print("PASS ", label, info if info.is_empty() else "  (" + info + ")")
	else:
		_fails += 1
		print("FAIL ", label, info if info.is_empty() else "  (" + info + ")")

func wait_physics(n: int) -> void:
	for i in n:
		await physics_frame

func wait_sec(sec: float) -> void:
	await create_timer(sec).timeout

func _run() -> void:
	print("=== 空间站危机 测试 ===")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# 1. 菜单初始状态
	_check("菜单初始状态", scene.state == "menu", "state=%s" % scene.state)
	_check("HUD 已创建", scene.hud != null)
	_check("玩家已创建", scene.player != null, "pos=%s" % scene.player.global_position)
	_check("世界已生成", scene.enemies.size() == 6 and scene.artifacts.size() == 3 and scene.pickups.size() == 4,
			"enemies=%d artifacts=%d pickups=%d" % [scene.enemies.size(), scene.artifacts.size(), scene.pickups.size()])
	_check("菜单面板可见", scene.hud.menu_panel.visible)
	_check("出口初始关闭", scene.exit_open == false and scene.exit_door.open_state == false)

	# 2. 开始游戏
	scene.hud.emit_signal("start_requested")
	await process_frame
	var st: Dictionary = scene.debug_state()
	_check("开始按钮进入游戏", scene.state == "playing", "state=%s" % scene.state)
	_check("游戏运行中", st.running)
	_check("初始得分 0", st.score == 0, "score=%d" % st.score)
	_check("初始血量 100", st.health == 100.0, "health=%.0f" % st.health)
	_check("剩余时间充足", st.time_left >= 290.0, "time=%.1f" % st.time_left)

	# 3. 移动
	scene.clear_enemies()
	scene.set_move(Vector2(0, -1))
	await wait_physics(30)
	var z0: float = scene.player.global_position.z
	_check("向前移动", z0 < 17.0, "z=%.2f" % z0)
	scene.set_move(Vector2.ZERO)
	await wait_physics(5)
	st = scene.debug_state()
	_check("站立视角高度", absf(st.camera_y - 1.7) < 0.12, "y=%.2f" % st.camera_y)

	# 4. 跳跃
	scene.do_jump()
	await wait_physics(4)
	st = scene.debug_state()
	_check("跳跃离地", st.camera_y > 1.9 and st.grounded == false,
			"y=%.2f grounded=%s" % [st.camera_y, st.grounded])
	await wait_physics(70)
	st = scene.debug_state()
	_check("落地回到地面", st.grounded and absf(st.camera_y - 1.7) < 0.2,
			"y=%.2f grounded=%s" % [st.camera_y, st.grounded])

	# 5. 蹲伏
	scene.set_crouch(true)
	await wait_physics(15)
	st = scene.debug_state()
	_check("蹲伏降低视角", absf(st.camera_y - 1.1) < 0.08, "y=%.2f" % st.camera_y)
	scene.set_crouch(false)
	await wait_physics(15)

	# 6. 武器切换
	scene.set_weapon(1)
	await wait_physics(2)
	st = scene.debug_state()
	_check("切换到步枪", st.weapon == "rifle", "weapon=%s" % st.weapon)
	_check("步枪弹药 30/120", st.mag == 30 and st.reserve == 120, "%d/%d" % [st.mag, st.reserve])
	scene.set_weapon(0)
	await wait_physics(15)
	st = scene.debug_state()
	_check("切回左轮", st.weapon == "revolver", "weapon=%s" % st.weapon)

	# 7. 左轮开火
	var before: int = scene.debug_state().tracers
	scene.aim_at(Vector3(0, 8, -12))
	var fired: bool = scene.shoot()
	st = scene.debug_state()
	_check("左轮开火成功", fired)
	_check("左轮单发耗 1 弹", st.mag == 5, "mag=%d" % st.mag)
	_check("曳光 +1", st.tracers - before == 1, "tracers +%d" % (st.tracers - before))

	# 7b. 输入路径：模拟鼠标左键（fire 动作）开火
	await wait_physics(40)
	var mag_before: int = scene.debug_state().mag
	Input.action_press("fire")
	await wait_physics(2)
	Input.action_release("fire")
	await wait_physics(2)
	st = scene.debug_state()
	_check("鼠标左键输入开火", st.mag == mag_before - 1, "mag %d -> %d" % [mag_before, st.mag])

	# 8. 射杀蝙蝠（2 发，+50）
	await wait_physics(20)
	scene.clear_enemies()
	scene.set_weapon(1)
	await wait_physics(15)
	var bat: Enemy = scene.force_enemy("bat", Vector3(2, 2.5, -6))
	await wait_physics(2)
	scene.aim_at(bat.global_position + Vector3(0, 0.2, 0))
	scene.shoot()
	await wait_physics(2)
	st = scene.debug_state()
	_check("蝙蝠首击未死", bat.dead == false and st.enemies == 1, "health=%.0f" % bat.health)
	_check("命中标记显示", scene.hud.hitmarker.visible)
	await wait_physics(20)
	scene.aim_at(bat.global_position + Vector3(0, 0.2, 0))
	scene.shoot()
	await wait_physics(2)
	st = scene.debug_state()
	_check("蝙蝠被击杀", st.enemies == 0, "enemies=%d" % st.enemies)
	_check("击杀蝙蝠 +50", st.score == 50, "score=%d" % st.score)

	# 9. 射杀骷髅（3 发，+100）
	await wait_physics(20)
	scene.clear_enemies()
	var skel: Enemy = scene.force_enemy("skeleton", Vector3(2, 0, -6))
	await wait_physics(2)
	for i in 3:
		scene.aim_at(skel.global_position + Vector3(0, 0.9, 0))
		scene.shoot()
		await wait_physics(20)
	st = scene.debug_state()
	_check("骷髅被击杀", st.enemies == 0, "enemies=%d" % st.enemies)
	_check("击杀骷髅 +100", st.score == 150, "score=%d" % st.score)

	# 10. 收集 3 件文物开启出口
	scene.clear_artifacts()
	scene.force_artifact(Vector3(0, 0.6, 3))
	scene.set_player_pos(Vector3(0, 0.1, 3))
	await wait_physics(3)
	st = scene.debug_state()
	_check("收集第 1 件文物", st.artifacts == 1, "artifacts=%d" % st.artifacts)
	_check("文物得分 +100", st.score == 250, "score=%d" % st.score)
	scene.force_artifact(Vector3(1, 0.6, 3))
	scene.force_artifact(Vector3(2, 0.6, 3))
	scene.set_player_pos(Vector3(1, 0.1, 3))
	await wait_physics(3)
	st = scene.debug_state()
	_check("收集齐 3 件文物", st.artifacts == 3, "artifacts=%d" % st.artifacts)
	_check("出口已开启", st.exit_open and scene.exit_door.open_state, "exit_open=%s" % st.exit_open)
	_check("三件文物 +300", st.score == 450, "score=%d" % st.score)

	# 11. 抵达出口胜利
	scene.set_player_pos(Vector3(0, 0.1, -31))
	await wait_physics(3)
	st = scene.debug_state()
	_check("逃出成功进入结算", st.state == "over", "state=%s" % st.state)
	_check("胜利文案", String(st.over_reason).contains("成功"), "msg=%s" % st.over_reason)
	_check("出口奖励 +500", st.score == 950, "score=%d" % st.score)
	_check("结算面板可见", scene.hud.over_panel.visible)

	# 12. 重新开局重置
	scene.hud.emit_signal("restart_requested")
	await process_frame
	st = scene.debug_state()
	_check("再来一局分数归零", st.score == 0, "score=%d" % st.score)
	_check("再来一局时间重置", st.time_left >= 290.0, "time=%.1f" % st.time_left)
	_check("再来一局血量重置", st.health == 100.0, "health=%.0f" % st.health)
	_check("再来一局刷敌", st.enemies == 6, "enemies=%d" % st.enemies)
	_check("再来一局出口关闭", st.exit_open == false and scene.exit_door.open_state == false)

	# 13. 暂停 / 恢复
	var t_before_pause: float = scene.time_left
	scene.pause_game()
	await wait_physics(10)
	var st_pause: Dictionary = scene.debug_state()
	_check("暂停生效", st_pause.paused and absf(scene.time_left - t_before_pause) < 0.01,
			"paused=%s time_delta=%.3f" % [st_pause.paused, scene.time_left - t_before_pause])
	scene.resume_game()
	await process_frame
	st = scene.debug_state()
	_check("恢复游戏", not st.paused and st.running)

	# 14. 尖刺坑：坠落扣血并传送回检查点
	scene.set_player_pos(Vector3(0, 0.2, -17.5))
	await wait_physics(60)
	st = scene.debug_state()
	_check("尖刺坑扣 20 血", st.health == 80.0, "health=%.0f" % st.health)
	_check("传送回检查点", scene.player.global_position.distance_to(Vector3(0, 0.1, 18)) < 1.0,
			"pos=%s" % scene.player.global_position)

	# 15. 敌人近身掉血
	scene.force_enemy("bat", Vector3(0, 2.0, 17.9))
	await wait_physics(70)
	st = scene.debug_state()
	_check("敌人近身掉血", st.health < 80.0 and st.health > 50.0, "health=%.0f" % st.health)
	scene.clear_enemies()

	# 16. 坠落伤害
	var hp_before: float = scene.health
	scene.set_player_pos(Vector3(0, 9, 4))
	await wait_physics(90)
	st = scene.debug_state()
	_check("高处坠落受伤", st.grounded and st.health < hp_before - 5.0 and st.health >= hp_before - 12.0,
			"hp %.0f -> %.0f" % [hp_before, st.health])

	# 17. 西侧拉杆：交互提示 + 打开石门
	scene.set_player_pos(Vector3(-14, 1.8, 10))
	await wait_physics(25)
	var lever: RuinSwitch = scene._switches[0]
	scene.player.aim_at(lever.global_position)
	await wait_physics(2)
	_check("交互提示显示", scene.hud.interact_label.visible and String(scene.hud.interact_label.text).contains("拉杆"),
			"text=%s" % scene.hud.interact_label.text)
	var interacted: bool = scene.interact()
	await wait_physics(2)
	_check("拉杆交互成功", interacted and lever.activated, "ok=%s activated=%s" % [interacted, lever.activated])
	_check("西侧石门开启", scene._west_door.open_state, "open=%s" % scene._west_door.open_state)

	# 18. 东侧压力板：踩踏开启石门
	scene.set_player_pos(Vector3(16, 0.2, -2))
	await wait_physics(5)
	var plate: RuinSwitch = scene._switches[1]
	_check("压力板被踩激活", plate.activated, "activated=%s" % plate.activated)
	_check("东侧石门开启", scene._east_door.open_state, "open=%s" % scene._east_door.open_state)

	# 19. 出口未开启时无法逃离
	scene.set_player_pos(Vector3(0, 0.1, -31))
	await wait_physics(3)
	st = scene.debug_state()
	_check("出口关闭不可逃离", st.state == "playing", "state=%s" % st.state)
	scene.set_player_pos(Vector3(0, 0.1, 18))
	await wait_physics(3)

	# 20. 时间耗尽失败
	scene.set_time_left(0.05)
	await wait_physics(8)
	st = scene.debug_state()
	_check("时间到进入结算", st.state == "over", "state=%s" % st.state)
	_check("失败文案", String(st.over_reason).contains("时间"), "msg=%s" % st.over_reason)

	# 21. 关卡切换：第二关（丛林）
	scene.switch_level(2)
	await process_frame
	await process_frame
	st = scene.debug_state()
	_check("切换到第二关", scene.level_id == 2 and st.state == "menu",
			"level=%d state=%s" % [scene.level_id, st.state])
	_check("第二关世界重建", scene.enemies.size() == 6 and scene.artifacts.size() == 3
			and scene.pickups.size() == 4 and scene.exit_door != null
			and scene._switches.size() == 0 and scene._west_door == null and scene._east_door == null,
			"enemies=%d artifacts=%d pickups=%d switches=%d" % [scene.enemies.size(), scene.artifacts.size(), scene.pickups.size(), scene._switches.size()])
	_check("第二关丛林敌人变体", scene.enemies.size() == 6 and scene.enemies[0].variant == 1,
			"variant=%d" % scene.enemies[0].variant)
	_check("第二关出口关闭", scene.exit_open == false and scene.exit_door.open_state == false)

	# 22. 第二关游玩：收集宝石
	scene.hud.emit_signal("start_requested")
	await process_frame
	st = scene.debug_state()
	_check("第二关开始游戏", st.state == "playing" and scene.level_id == 2,
			"state=%s" % st.state)
	_check("第二关宝石标题", scene.hud.artifact_label.text.contains("宝石"),
			"text=%s" % scene.hud.artifact_label.text)
	scene.set_player_pos(Vector3(-12, 0.1, -10))
	await wait_physics(5)
	st = scene.debug_state()
	_check("收集第 1 颗宝石", st.artifacts == 1 and st.score == 100,
			"artifacts=%d score=%d" % [st.artifacts, st.score])
	_check("宝石未集齐出口关闭", st.exit_open == false)

	# 23. 切回第一关并还原
	scene.switch_level(1)
	await process_frame
	await process_frame
	_check("切回第一关", scene.level_id == 1 and scene.state == "menu",
			"level=%d state=%s" % [scene.level_id, scene.state])
	_check("第一关世界还原", scene.enemies.size() == 6 and scene.artifacts.size() == 3
			and scene._switches.size() == 2 and scene._switches[0].mode == "lever"
			and scene.exit_door != null,
			"enemies=%d artifacts=%d switches=%d" % [scene.enemies.size(), scene.artifacts.size(), scene._switches.size()])

	print("===== RESULT: %d checks, %d failures =====" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)
