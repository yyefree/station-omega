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

func _run() -> void:
	print("=== 第二关「丛林密境」自动运行测试 ===")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# 1. 切换到第二关
	scene.switch_level(2)
	await process_frame
	await process_frame
	var st: Dictionary = scene.debug_state()
	_check("切换到第二关菜单", scene.level_id == 2 and st.state == "menu",
			"level=%d state=%s" % [scene.level_id, st.state])
	_check("第二关世界重建", scene.enemies.size() == 6 and scene.artifacts.size() == 3
			and scene.pickups.size() == 4 and scene.exit_door != null,
			"enemies=%d artifacts=%d pickups=%d" % [scene.enemies.size(), scene.artifacts.size(), scene.pickups.size()])
	_check("无建筑机关", scene._switches.size() == 0 and scene._west_door == null and scene._east_door == null,
			"switches=%d" % scene._switches.size())
	_check("丛林敌人变体", scene.enemies.size() == 6 and scene.enemies[0].variant == 1,
			"variant=%d" % scene.enemies[0].variant)
	_check("丛林水流循环声已启动", scene.audio._loops.has("jungle_water"),
			"loops=" + str(scene.audio._loops.keys()))
	_check("菜单丛林文案", String(scene.hud._menu_subtitle.text).contains("丛林"),
			"sub=" + scene.hud._menu_subtitle.text)

	# 2. 开始游戏
	scene.hud.emit_signal("start_requested")
	await process_frame
	await process_frame
	st = scene.debug_state()
	_check("第二关开始游戏", st.state == "playing" and scene.level_id == 2, "state=%s" % st.state)
	_check("丛林目标提示", String(st.hint).contains("丛林") and String(st.hint).contains("宝石"),
			"hint=%s" % st.hint)
	_check("宝石标题显示", scene.hud.artifact_label.text.contains("宝石"),
			"text=%s" % scene.hud.artifact_label.text)
	_check("出口初始关闭", scene.exit_open == false and scene.exit_door.open_state == false)

	# 3. 出口未开启时无法逃离
	scene.set_player_pos(Vector3(0, 0.1, -31))
	await wait_physics(5)
	st = scene.debug_state()
	_check("出口关闭不可逃离", st.state == "playing", "state=%s" % st.state)

	# 4. 溪流蹚水检测
	scene.set_player_pos(Vector3(0, 0.1, -6))
	await wait_physics(30)
	_check("溪流内检测", scene._in_water == true, "in_water=%s" % scene._in_water)
	scene.set_player_pos(Vector3(0, 0.1, 0))
	await wait_physics(30)
	_check("离开溪流检测", scene._in_water == false, "in_water=%s" % scene._in_water)

	# 5. 收集宝石 1（巨石阵中央）
	scene.set_player_pos(Vector3(-12, 0.1, -10))
	await wait_physics(5)
	st = scene.debug_state()
	_check("收集宝石 1（巨石阵）", st.artifacts == 1 and st.score == 100,
			"artifacts=%d score=%d" % [st.artifacts, st.score])
	_check("宝石 1 目标提示", String(st.hint).contains("还有两颗") and String(st.hint).contains("溪流"),
			"hint=%s" % st.hint)

	# 6. 收集宝石 2（溪流东端）
	scene.set_player_pos(Vector3(20, 0.1, -6))
	await wait_physics(5)
	st = scene.debug_state()
	_check("收集宝石 2（溪流东端）", st.artifacts == 2 and st.score == 200,
			"artifacts=%d score=%d" % [st.artifacts, st.score])
	_check("宝石 2 目标提示", String(st.hint).contains("还差最后一颗"),
			"hint=%s" % st.hint)

	# 7. 收集宝石 3（西北老树下）
	scene.set_player_pos(Vector3(-26, 0.1, 8))
	await wait_physics(5)
	st = scene.debug_state()
	_check("收集宝石 3（老树下）", st.artifacts == 3 and st.score == 300,
			"artifacts=%d score=%d" % [st.artifacts, st.score])
	_check("出口已开启", st.exit_open and scene.exit_door.open_state,
			"exit_open=%s" % st.exit_open)
	_check("出口开启提示", String(st.hint).contains("穿过北面巨树间逃出丛林"),
			"hint=%s" % st.hint)

	# 8. 逃出胜利
	scene.set_player_pos(Vector3(0, 0.1, -31))
	await wait_physics(5)
	st = scene.debug_state()
	_check("逃出丛林胜利结算", st.state == "over", "state=%s" % st.state)
	_check("胜利文案", String(st.over_reason).contains("成功"), "msg=%s" % st.over_reason)
	_check("出口奖励 +500", st.score == 800, "score=%d" % st.score)
	_check("结算面板可见", scene.hud.over_panel.visible)

	# 9. 重新开始（保持第二关）：深潭检测 + 环境音分支
	scene.hud.emit_signal("restart_requested")
	await process_frame
	await process_frame
	st = scene.debug_state()
	_check("第二关再来一局", st.state == "playing" and scene.level_id == 2 and st.score == 0,
			"state=%s level=%d" % [st.state, scene.level_id])
	_check("再来一局出口关闭", scene.exit_open == false and scene.exit_door.open_state == false)
	scene._amb_cd = 0.0
	await wait_physics(40)
	_check("环境音计时未崩溃", scene.state == "playing")
	scene.set_player_pos(Vector3(-6, 0.2, 14))
	await wait_physics(8)
	_check("深潭内检测", scene._in_water == true, "in_water=%s" % scene._in_water)
	scene.set_player_pos(Vector3(-2, 0.3, 14))
	await wait_physics(8)
	_check("离开深潭检测", scene._in_water == false, "in_water=%s" % scene._in_water)

	# 10. 击杀丛林野兽（变体 1）走 beast_dead 分支
	scene.clear_enemies()
	scene.set_weapon(1)
	await wait_physics(15)
	var jskel: Enemy = Enemy.make(Enemy.Kind.SKELETON, Vector3(0, 0, -4), scene.world_root, 1)
	jskel.hit.connect(scene._on_enemy_hit)
	jskel.destroyed.connect(scene._on_enemy_destroyed)
	scene.enemies.append(jskel)
	await wait_physics(2)
	_check("丛林野兽为变体 1", jskel.variant == 1, "variant=%d" % jskel.variant)
	for i in 3:
		scene.aim_at(jskel.global_position + Vector3(0, 0.9, 0))
		scene.shoot()
		await wait_physics(20)
	st = scene.debug_state()
	_check("击杀丛林野兽", (not is_instance_valid(jskel)) and st.enemies == 0,
			"alive=%s enemies=%d" % [is_instance_valid(jskel), st.enemies])
	_check("击杀丛林野兽 +100", st.score == 100, "score=%d" % st.score)

	print("===== RESULT: %d checks, %d failures =====" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)
