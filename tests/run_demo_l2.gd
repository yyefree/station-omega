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

func _run() -> void:
	print("=== 第二关自动演示通关测试 ===")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	scene.switch_level(2)
	await process_frame
	await process_frame
	_check("第二关菜单", scene.level_id == 2 and scene.state == "menu",
			"level=%d state=%s" % [scene.level_id, scene.state])

	scene.start_demo()
	await process_frame
	await process_frame
	_check("演示开始", scene._demo_active and scene.state == "playing",
			"demo=%s state=%s" % [scene._demo_active, scene.state])

	var won := false
	var restarts := 0
	var over_stall := 0
	var last_over := ""
	var st: Dictionary = {}
	for i in 30000:
		await physics_frame
		st = scene.debug_state()
		if i % 500 == 0:
			var p := Vector3.ZERO
			if is_instance_valid(scene.player):
				p = scene.player.global_position
			print("  [t=%d] state=%s hp=%d pos=(%.1f, %.1f) score=%d art=%d exit=%s floor=%s" % [
				i, st.state, int(st.health), p.x, p.z, st.score, st.artifacts, st.exit_open, st.grounded])
		if st.state == "over":
			if String(st.over_reason).contains("成功"):
				won = true
				print("  通关 @ t=%d score=%d artifacts=%d" % [i, st.score, st.artifacts])
				break
			if st.over_reason != last_over:
				print("  死亡 %s @ t=%d score=%d artifacts=%d" % [st.over_reason, i, st.score, st.artifacts])
				last_over = st.over_reason
			over_stall += 1
			if over_stall > 1800:
				print("  卡在结算界面，中止")
				break
		else:
			over_stall = 0
	_check("演示自动通关", won, "restarts=%d last_over=%s" % [restarts, last_over])

	print("===== RESULT: %d checks, %d failures =====" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)
