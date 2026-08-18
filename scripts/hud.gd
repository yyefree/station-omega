class_name HUD
extends CanvasLayer

var score_label: Label
var best_label: Label
var time_label: Label
var objective_label: Label
var artifact_label: Label
var health_bar: ProgressBar
var health_value: Label
var weapon_label: Label
var interact_label: Label
var crosshair: Control
var hitmarker: Control
var dmg_overlay: TextureRect
var menu_panel: Control
var pause_panel: Control
var over_panel: Control
var over_msg: Label
var over_sub: Label

var _crosshair_spread := 0.0
var _crosshair_target := 0.0
var over_score: Label
var over_best: Label
var demo_label: Label
var obj_arrow_panel: Control
var obj_arrow: Polygon2D
var obj_arrow_dist: Label

var _title := "核心"
var _menu_subtitle: Label
var _menu_rule: Label

var _fade_rect: ColorRect
var _fade_target := 0.0
var _fade_speed := 3.0
var _settings_panel: Control
var _settings_volume: HSlider
var _settings_sens: HSlider

signal start_requested
signal restart_requested
signal resume_requested
signal level_requested(level: int)
signal settings_changed
signal menu_requested

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	dmg_overlay = TextureRect.new()
	dmg_overlay.name = "DamageOverlay"
	dmg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dmg_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gt := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.9, 0.05, 0.05, 1.0))
	grad.set_color(1, Color(0.9, 0.05, 0.05, 1.0))
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	dmg_overlay.texture = gt
	dmg_overlay.modulate.a = 0.0
	root.add_child(dmg_overlay)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeOverlay"
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 0.0
	root.add_child(_fade_rect)

	crosshair = _make_crosshair()
	root.add_child(crosshair)

	hitmarker = _make_hitmarker()
	hitmarker.visible = false
	root.add_child(hitmarker)

	obj_arrow_panel = Control.new()
	obj_arrow_panel.name = "ObjectiveArrow"
	obj_arrow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_arrow_panel.anchor_left = 0.5
	obj_arrow_panel.anchor_right = 0.5
	obj_arrow_panel.anchor_top = 0.5
	obj_arrow_panel.anchor_bottom = 0.5
	obj_arrow_panel.offset_left = -22
	obj_arrow_panel.offset_right = 22
	obj_arrow_panel.offset_top = -22
	obj_arrow_panel.offset_bottom = 22
	obj_arrow_panel.visible = false
	root.add_child(obj_arrow_panel)
	obj_arrow = Polygon2D.new()
	obj_arrow.polygon = PackedVector2Array([Vector2(0, -14), Vector2(10, 11), Vector2(-10, 11)])
	obj_arrow.color = Color(1.0, 0.78, 0.2, 0.95)
	obj_arrow_panel.add_child(obj_arrow)
	obj_arrow_dist = Label.new()
	obj_arrow_dist.text = ""
	obj_arrow_dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj_arrow_dist.add_theme_font_size_override("font_size", 15)
	obj_arrow_dist.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	obj_arrow_dist.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	obj_arrow_dist.add_theme_constant_override("outline_size", 5)
	obj_arrow_dist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_arrow_dist.position = Vector2(-90, 24)
	obj_arrow_dist.size = Vector2(180, 22)
	obj_arrow_panel.add_child(obj_arrow_dist)

	demo_label = _label("演示模式 · 按任意键接管", 18, Color(1.0, 0.9, 0.5), Vector2.ZERO)
	demo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demo_label.anchor_left = 0.5
	demo_label.anchor_right = 0.5
	demo_label.anchor_top = 1.0
	demo_label.anchor_bottom = 1.0
	demo_label.offset_left = -220
	demo_label.offset_right = 220
	demo_label.offset_top = -52
	demo_label.offset_bottom = -32
	demo_label.visible = false
	root.add_child(demo_label)

	# ---- 左上：得分 / 最高 ----
	score_label = _label("得分 0", 22, Color.WHITE, Vector2(24, 20))
	root.add_child(score_label)
	best_label = _label("最高 0", 16, Color(0.75, 0.78, 0.85), Vector2(26, 54))
	root.add_child(best_label)

	# ---- 右上：剩余时间 ----
	time_label = _label("05:00", 26, Color.WHITE, Vector2(0, 20))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.anchor_left = 1.0
	time_label.anchor_right = 1.0
	time_label.offset_left = -240
	time_label.offset_right = -24
	root.add_child(time_label)

	# ---- 顶中：目标面板 ----
	var obj := ColorRect.new()
	obj.name = "ObjectivePanel"
	obj.color = Color(0.06, 0.07, 0.1, 0.55)
	obj.anchor_left = 0.5
	obj.anchor_right = 0.5
	obj.offset_left = -280
	obj.offset_right = 280
	obj.offset_top = 10
	obj.offset_bottom = 92
	obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(obj)
	objective_label = Label.new()
	objective_label.text = ""
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 17)
	objective_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	objective_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	objective_label.add_theme_constant_override("outline_size", 5)
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	objective_label.offset_left = 12
	objective_label.offset_right = -12
	objective_label.offset_top = 12
	objective_label.offset_bottom = -36
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj.add_child(objective_label)
	artifact_label = Label.new()
	artifact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	artifact_label.add_theme_font_size_override("font_size", 20)
	artifact_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	artifact_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	artifact_label.add_theme_constant_override("outline_size", 5)
	artifact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artifact_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	artifact_label.offset_left = 12
	artifact_label.offset_right = -12
	artifact_label.offset_top = 56
	artifact_label.offset_bottom = -8
	obj.add_child(artifact_label)

	# ---- 底中：交互提示 ----
	interact_label = _label("[E] 拉动拉杆", 20, Color(1.0, 0.9, 0.4), Vector2(0, 0))
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.anchor_left = 0.5
	interact_label.anchor_right = 0.5
	interact_label.anchor_top = 1.0
	interact_label.anchor_bottom = 1.0
	interact_label.offset_left = -200
	interact_label.offset_right = 200
	interact_label.offset_top = -150
	interact_label.offset_bottom = -120
	interact_label.visible = false
	root.add_child(interact_label)

	# ---- 底中：血条 ----
	health_bar = ProgressBar.new()
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(300, 18)
	health_bar.anchor_left = 0.5
	health_bar.anchor_right = 0.5
	health_bar.anchor_top = 1.0
	health_bar.anchor_bottom = 1.0
	health_bar.offset_left = -150
	health_bar.offset_right = 150
	health_bar.offset_top = -118
	health_bar.offset_bottom = -100
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb_style := StyleBoxFlat.new()
	hb_style.bg_color = Color(0.12, 0.13, 0.16)
	health_bar.add_theme_stylebox_override("background", hb_style)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.25, 0.25)
	health_bar.add_theme_stylebox_override("fill", fill)
	root.add_child(health_bar)
	health_value = _label("100", 14, Color.WHITE, Vector2(0, 0))
	health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_value.anchor_left = 0.5
	health_value.anchor_right = 0.5
	health_value.anchor_top = 1.0
	health_value.anchor_bottom = 1.0
	health_value.offset_left = -150
	health_value.offset_right = 150
	health_value.offset_top = -96
	health_value.offset_bottom = -74
	root.add_child(health_value)

	# ---- 右下：武器/弹药 ----
	weapon_label = _label("手枪  12/72", 20, Color.WHITE, Vector2(0, 0))
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.anchor_left = 1.0
	weapon_label.anchor_right = 1.0
	weapon_label.anchor_top = 1.0
	weapon_label.anchor_bottom = 1.0
	weapon_label.offset_left = -420
	weapon_label.offset_right = -24
	weapon_label.offset_top = -64
	weapon_label.offset_bottom = -36
	root.add_child(weapon_label)

	# ---- 菜单面板 ----
	menu_panel = _overlay_panel(root)
	var menu_vbox := VBoxContainer.new()
	menu_vbox.set_anchors_preset(Control.PRESET_CENTER)
	menu_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	menu_vbox.add_theme_constant_override("separation", 16)
	menu_panel.add_child(menu_vbox)
	menu_vbox.add_child(_center_label("空间站危机", 48, Color(1.0, 0.9, 0.5)))
	_menu_subtitle = _center_label("深空研究站 Omega 维度裂缝突破收容，探索工程甲板，收集 3 个能源核心，修复电梯前往上层！", 17, Color(0.82, 0.85, 0.92))
	menu_vbox.add_child(_menu_subtitle)
	var menu_hint := _center_label("WASD 移动  ·  Shift 疾跑  ·  Space 跳跃  ·  Ctrl 蹲伏\n鼠标左键 射击  ·  R 换弹  ·  1/2/3 切换武器  ·  E 交互  ·  Esc 暂停", 15, Color(0.7, 0.74, 0.82))
	menu_vbox.add_child(menu_hint)
	var start_btn := _button("开始任务")
	start_btn.pressed.connect(func() -> void: emit_signal("start_requested"))
	menu_vbox.add_child(start_btn)
	var level_row := HBoxContainer.new()
	level_row.alignment = BoxContainer.ALIGNMENT_CENTER
	level_row.add_theme_constant_override("separation", 14)
	menu_vbox.add_child(level_row)
	var lvl1 := _button("第一关 · 工程甲板")
	lvl1.pressed.connect(func() -> void: emit_signal("level_requested", 1))
	level_row.add_child(lvl1)
	var lvl2 := _button("第二关 · 丛林密境")
	lvl2.pressed.connect(func() -> void: emit_signal("level_requested", 2))
	level_row.add_child(lvl2)
	menu_vbox.add_child(_center_label("5 秒后自动进入演示模式", 14, Color(0.6, 0.66, 0.75)))
	_menu_rule = _center_label("无人机 -50  安保机器人 -100  核心 +100  逃出 +500", 14, Color(0.85, 0.7, 0.5))
	menu_vbox.add_child(_menu_rule)
	var quit_btn := _button("退出游戏")
	quit_btn.pressed.connect(_quit_game)
	menu_vbox.add_child(quit_btn)

	# ---- 暂停面板 ----
	pause_panel = _overlay_panel(root)
	var pause_vbox := VBoxContainer.new()
	pause_vbox.set_anchors_preset(Control.PRESET_CENTER)
	pause_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	pause_vbox.add_theme_constant_override("separation", 16)
	pause_panel.add_child(pause_vbox)
	pause_vbox.add_child(_center_label("已暂停", 40, Color.WHITE))
	var resume_btn := _button("继续任务")
	resume_btn.pressed.connect(func() -> void: emit_signal("resume_requested"))
	pause_vbox.add_child(resume_btn)
	var settings_btn := _button("设置")
	settings_btn.pressed.connect(func() -> void: _settings_panel.visible = true; pause_panel.visible = false)
	pause_vbox.add_child(settings_btn)
	var exit_btn := _button("退出到菜单")
	exit_btn.pressed.connect(func() -> void: emit_signal("menu_requested"))
	pause_vbox.add_child(exit_btn)
	var quit_pause_btn := _button("退出游戏")
	quit_pause_btn.pressed.connect(_quit_game)
	pause_vbox.add_child(quit_pause_btn)
	pause_panel.visible = false

	# ---- 设置面板 ----
	_settings_panel = _overlay_panel(root)
	var set_vbox := VBoxContainer.new()
	set_vbox.set_anchors_preset(Control.PRESET_CENTER)
	set_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	set_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	set_vbox.add_theme_constant_override("separation", 14)
	_settings_panel.add_child(set_vbox)
	set_vbox.add_child(_center_label("设置", 36, Color.WHITE))
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	set_vbox.add_child(vol_row)
	vol_row.add_child(_center_label("音量", 18, Color.WHITE))
	_settings_volume = HSlider.new()
	_settings_volume.min_value = 0.0
	_settings_volume.max_value = 1.0
	_settings_volume.value = 0.8
	_settings_volume.custom_minimum_size = Vector2(220, 28)
	_settings_volume.value_changed.connect(func(v: float) -> void: AudioServer.set_bus_volume_linear(0, v); emit_signal("settings_changed"))
	vol_row.add_child(_settings_volume)
	var sens_row := HBoxContainer.new()
	sens_row.add_theme_constant_override("separation", 12)
	set_vbox.add_child(sens_row)
	sens_row.add_child(_center_label("灵敏度", 18, Color.WHITE))
	_settings_sens = HSlider.new()
	_settings_sens.min_value = 0.2
	_settings_sens.max_value = 3.0
	_settings_sens.value = 1.0
	_settings_sens.custom_minimum_size = Vector2(220, 28)
	_settings_sens.value_changed.connect(func(v: float) -> void: emit_signal("settings_changed", v))
	sens_row.add_child(_settings_sens)
	var fullscreen_btn := _button("切换全屏")
	fullscreen_btn.pressed.connect(func() -> void:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN))
	set_vbox.add_child(fullscreen_btn)
	var back_btn := _button("返回")
	back_btn.pressed.connect(func() -> void: _settings_panel.visible = false; pause_panel.visible = true)
	set_vbox.add_child(back_btn)
	_settings_panel.visible = false

	# ---- 结算面板 ----
	over_panel = _overlay_panel(root)
	var over_vbox := VBoxContainer.new()
	over_vbox.set_anchors_preset(Control.PRESET_CENTER)
	over_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	over_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	over_vbox.add_theme_constant_override("separation", 14)
	over_panel.add_child(over_vbox)
	over_msg = _center_label("你成功逃出了遗迹！", 40, Color.WHITE)
	over_vbox.add_child(over_msg)
	over_sub = _center_label("成功", 22, Color(1.0, 0.85, 0.3))
	over_vbox.add_child(over_sub)
	over_score = _center_label("最终得分 0", 26, Color(1.0, 0.85, 0.3))
	over_vbox.add_child(over_score)
	over_best = _center_label("历史最高 0", 18, Color(0.75, 0.78, 0.85))
	over_vbox.add_child(over_best)
	var again_btn := _button("再次冒险")
	again_btn.pressed.connect(func() -> void: emit_signal("restart_requested"))
	over_vbox.add_child(again_btn)
	over_panel.visible = false

	set_playing_visible(false)
	menu_panel.visible = true

func _process(delta: float) -> void:
	_crosshair_spread = move_toward(_crosshair_spread, _crosshair_target, 12.0 * delta)
	if crosshair:
		var s := 1.0 + _crosshair_spread * 0.85
		crosshair.scale = Vector2(s, s)
		crosshair.modulate = Color(1.0, 1.0, 1.0, 1.0 - _crosshair_spread * 0.25)
	if _fade_rect:
		if not is_equal_approx(_fade_rect.modulate.a, _fade_target):
			_fade_rect.modulate.a = move_toward(_fade_rect.modulate.a, _fade_target, _fade_speed * delta)

func fade_in(duration := 0.4) -> void:
	_fade_speed = 1.0 / maxf(duration, 0.01)
	_fade_target = 0.0
	_fade_rect.modulate.a = 1.0

func fade_out(duration := 0.4) -> void:
	_fade_speed = 1.0 / maxf(duration, 0.01)
	_fade_target = 1.0

func set_crosshair_spread(s: float) -> void:
	_crosshair_target = clampf(s, 0.0, 1.0)

func _label(text: String, size: int, color: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = pos
	return l

func _center_label(text: String, size: int, color: Color) -> Label:
	var l := _label(text, size, color, Vector2.ZERO)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b

func _overlay_panel(parent: Control) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)
	return dim

func _make_crosshair() -> Control:
	var c := Control.new()
	c.name = "Crosshair"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = -6
	c.offset_right = 6
	c.offset_top = -6
	c.offset_bottom = 6
	for dir_ in ["left", "right", "up", "down"]:
		var tick := ColorRect.new()
		tick.color = Color(0.9, 0.95, 1.0, 0.9)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.size = Vector2(7, 2) if dir_ in ["left", "right"] else Vector2(2, 7)
		match dir_:
			"left":
				tick.position = Vector2(-8, -1)
			"right":
				tick.position = Vector2(1, -1)
			"up":
				tick.position = Vector2(-1, -8)
			"down":
				tick.position = Vector2(-1, 1)
		c.add_child(tick)
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.7)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.position = Vector2(-1, -1)
	dot.size = Vector2(2, 2)
	c.add_child(dot)
	return c

func _make_hitmarker() -> Control:
	var h := Control.new()
	h.name = "Hitmarker"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.anchor_left = 0.5
	h.anchor_right = 0.5
	h.anchor_top = 0.5
	h.anchor_bottom = 0.5
	h.offset_left = -12
	h.offset_right = 12
	h.offset_top = -12
	h.offset_bottom = 12
	h.pivot_offset = Vector2(12, 12)
	for dir_ in ["tl", "tr", "bl", "br"]:
		var tick := ColorRect.new()
		tick.color = Color(1, 1, 1, 0.95)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match dir_:
			"tl":
				tick.position = Vector2(-12, -12)
				tick.size = Vector2(8, 2)
			"tr":
				tick.position = Vector2(4, -12)
				tick.size = Vector2(8, 2)
			"bl":
				tick.position = Vector2(-12, 10)
				tick.size = Vector2(8, 2)
			"br":
				tick.position = Vector2(4, 10)
				tick.size = Vector2(8, 2)
		h.add_child(tick)
	return h

func set_playing_visible(v: bool) -> void:
	for n in [score_label, best_label, time_label, objective_label, artifact_label,
			health_bar, health_value, weapon_label, crosshair]:
		if n:
			n.visible = v
	if obj_arrow_panel:
		obj_arrow_panel.visible = v

func set_values(score: int, best: int, hp: float, time_left: float, artifacts: int, total: int,
		exit_open: bool, weapon_name: String, mag: int, reserve: int, reloading: bool) -> void:
	score_label.text = "得分 %d" % score
	best_label.text = "最高 %d" % best
	var m := int(time_left) / 60
	var s := int(time_left) % 60
	time_label.text = "%02d:%02d" % [m, s]
	if time_left <= 30.0:
		time_label.modulate = Color(1.0, 0.3, 0.3)
	else:
		time_label.modulate = Color.WHITE
	health_bar.value = hp
	health_value.text = str(ceili(hp))
	var bar_fill := Color(0.85, 0.25, 0.25)
	if hp > 60.0:
		bar_fill = Color(0.3, 0.85, 0.4)
	elif hp > 30.0:
		bar_fill = Color(0.9, 0.7, 0.2)
	var style := StyleBoxFlat.new()
	style.bg_color = bar_fill
	health_bar.add_theme_stylebox_override("fill", style)
	artifact_label.text = "%s %d/%d" % [_title, artifacts, total]
	artifact_label.modulate = Color(1.0, 0.85, 0.35) if exit_open else Color(0.92, 0.94, 1.0)
	if reloading:
		weapon_label.text = "%s  %d/%d  (换弹中…)" % [weapon_name, mag, reserve]
		weapon_label.modulate = Color(1.0, 0.85, 0.4)
	else:
		weapon_label.text = "%s  %d/%d" % [weapon_name, mag, reserve]
		weapon_label.modulate = Color.WHITE

func set_objective(text: String, artifacts: int, total: int, exit_open: bool) -> void:
	objective_label.text = text
	artifact_label.text = "%s %d/%d" % [_title, artifacts, total]
	artifact_label.modulate = Color(1.0, 0.85, 0.35) if exit_open else Color(0.92, 0.94, 1.0)

func set_level_title(t: String) -> void:
	_title = t

func set_interact(text: String) -> void:
	interact_label.text = text
	interact_label.visible = not text.is_empty()

func set_hitmark(v: bool, kill := false) -> void:
	hitmarker.visible = v
	if v:
		hitmarker.rotation = PI / 4.0 if kill else 0.0
		hitmarker.modulate = Color(1.0, 0.35, 0.3) if kill else Color.WHITE

func set_objective_arrow(rel: float, dist: float, label: String) -> void:
	if not obj_arrow_panel:
		return
	obj_arrow_panel.visible = true
	var dir2 := Vector2(sin(rel), -cos(rel))
	var r := 120.0 if absf(rel) < 0.6 else 235.0
	var c := dir2 * r
	obj_arrow_panel.offset_left = c.x - 22
	obj_arrow_panel.offset_right = c.x + 22
	obj_arrow_panel.offset_top = c.y - 22
	obj_arrow_panel.offset_bottom = c.y + 22
	obj_arrow.rotation = rel
	obj_arrow_dist.text = "%s %dm" % [label, int(dist)]

func set_objective_arrow_hidden() -> void:
	if obj_arrow_panel:
		obj_arrow_panel.visible = false

func set_damage_flash(strength: float) -> void:
	dmg_overlay.modulate.a = clampf(strength * 1.2, 0.0, 0.6)

func set_demo(on: bool) -> void:
	demo_label.visible = on

func show_menu(best: int, level := 1) -> void:
	set_playing_visible(false)
	menu_panel.visible = true
	pause_panel.visible = false
	over_panel.visible = false
	if level == 2:
		_menu_subtitle.text = "深入原始丛林，寻找 3 颗神秘宝石，穿过北面巨树间逃出生天"
		_menu_rule.text = "蝙蝠 -50  丛林野兽 -100  宝石 +100  逃出 +500"
	else:
		_menu_subtitle.text = "深空研究站 Omega 维度裂缝突破收容，探索工程甲板，收集 3 个能源核心，修复电梯前往上层！"
		_menu_rule.text = "无人机 -50  安保机器人 -100  核心 +100  逃出 +500"

func show_hud() -> void:
	set_playing_visible(true)
	menu_panel.visible = false
	pause_panel.visible = false
	over_panel.visible = false

func show_pause() -> void:
	pause_panel.visible = true

func hide_pause() -> void:
	pause_panel.visible = false

func show_over(msg: String, score: int, best: int, victory: bool) -> void:
	set_playing_visible(false)
	menu_panel.visible = false
	pause_panel.visible = false
	over_panel.visible = true
	over_msg.text = msg
	over_sub.text = "成功逃离！" if victory else "冒险失败"
	over_sub.modulate = Color(1.0, 0.85, 0.3) if victory else Color(1.0, 0.35, 0.35)
	over_score.text = "最终得分 %d" % score
	over_best.text = "历史最高 %d" % best
	if score >= best and score > 0:
		over_sub.text = "新纪录！"
		over_sub.modulate = Color(1.0, 0.9, 0.2)
		var tw := create_tween()
		tw.set_loops(3)
		tw.tween_property(over_sub, "modulate:a", 0.3, 0.25).set_trans(Tween.TRANS_SINE)
		tw.tween_property(over_sub, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)

func _quit_game() -> void:
	get_tree().quit()
