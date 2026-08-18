extends Node

signal game_started
signal game_over(final_score: int, reason: String)
signal score_changed(score: int)

const ROUND_TIME := 300.0
const ARTIFACTS_TOTAL := 3
const SAVE_PATH := "user://settings.cfg"
const SPAWN := Vector3(0, 0.1, 18)

var state := "menu" # menu | playing | over
var level_id := 1 # 1=远古废墟 2=丛林密境
var paused := false
var score := 0
var best := 0
var health := 100.0
var time_left := ROUND_TIME
var artifacts_collected := 0
var exit_open := false
var over_reason := ""
var hint := ""

var player: Player
var hud: HUD
var audio: AudioManager
var world_root: Node3D
var enemies: Array[Enemy] = []
var artifacts: Array[Artifact] = []
var pickups: Array[Pickup] = []
var exit_door: RuinDoor
var checkpoint := SPAWN

var _elapsed := 0.0
var _hitmark_cd := 0.0
var _dmg_flash := 0.0
var _enemies_defeated := 0
var _doors: Array[RuinDoor] = []
var _switches: Array[RuinSwitch] = []
var _west_door: RuinDoor
var _east_door: RuinDoor
var _demo_active := false
var _demo_enabled := true
var _menu_idle := 0.0
var _over_idle := 0.0
var _demo_fire_cd := 0.0
var _last_hit_kill := false
var _heart_cd := 0.0
var _amb_cd := 0.0
var _in_water := false
var _autostart := false
var _autostart_demo := false
var _slowmo_cd := 0.0

func _ready() -> void:
	add_to_group("game_main")
	_parse_launch_args()
	_build_input()
	best = _load_best()
	_build_scene()
	_build_hud()
	_build_audio()
	_demo_enabled = DisplayServer.get_name() != "headless"
	_spawn_player()
	_apply_level_audio()
	_reset_world()
	_update_objective()
	hud.show_menu(best, level_id)
	hud.fade_in(0.3)
	if _autostart:
		start_game()
	if _autostart_demo:
		start_demo()

func _parse_launch_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var a := String(args[i])
		if a == "--level" and i + 1 < args.size():
			level_id = clampi(int(args[i + 1]), 1, 2)
		elif a.begins_with("--level="):
			level_id = clampi(int(a.get_slice("=", 1)), 1, 2)
		elif a == "--autostart":
			_autostart = true
		elif a == "--demo":
			_autostart_demo = true

func _build_input() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("crouch", KEY_CTRL)
	_add_key_action("crouch", KEY_C)
	_add_key_action("reload", KEY_R)
	_add_key_action("weapon_1", KEY_1)
	_add_key_action("weapon_2", KEY_2)
	_add_key_action("weapon_3", KEY_3)
	_add_key_action("interact", KEY_E)
	_add_key_action("pause", KEY_ESCAPE)
	var fire := InputEventMouseButton.new()
	fire.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		InputMap.action_add_event("fire", fire)

func _add_key_action(name: String, key: Key) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(name, ev)

# ---------------- 场景构建 ----------------

func _build_scene() -> void:
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)

	var env := WorldEnvironment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.008, 0.008, 0.02)
	sky_mat.sky_horizon_color = Color(0.015, 0.02, 0.04)
	sky_mat.sky_curve = 0.08
	sky_mat.sky_energy_multiplier = 0.6
	sky_mat.ground_bottom_color = Color(0.005, 0.005, 0.01)
	sky_mat.ground_horizon_color = Color(0.01, 0.012, 0.03)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_energy = 0.8
	e.ambient_light_color = Color(0.25, 0.28, 0.38)
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.4
	e.fog_enabled = true
	e.fog_light_color = Color(0.12, 0.15, 0.22)
	e.fog_density = 0.018
	e.fog_sun_scatter = 0.0
	e.fog_aerial_perspective = 0.3
	e.fog_sky_affect = 0.1
	e.glow_enabled = true
	e.glow_intensity = 0.8
	e.glow_strength = 1.0
	e.glow_bloom = 0.15
	e.glow_hdr_threshold = 0.6
	e.adjustment_enabled = true
	e.adjustment_saturation = 0.9
	e.adjustment_contrast = 1.1
	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 3.0
	e.ssao_power = 2.0
	e.ssao_sharpness = 0.98
	e.ssao_detail = 0.5
	e.ssao_horizon = 0.06
	e.ssao_ao_channel_affect = 1.0
	e.ssr_enabled = true
	e.ssr_max_steps = 32
	e.ssr_fade_in = 0.12
	e.ssr_fade_out = 1.0
	e.ssr_depth_tolerance = 0.1
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.02
	e.volumetric_fog_length = 50.0
	e.volumetric_fog_detail_spread = 3.0
	e.volumetric_fog_ambient_inject = 0.5
	e.volumetric_fog_sky_affect = 0.2
	e.volumetric_fog_anisotropy = 0.5
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 0.0
	sun.light_color = Color(1.0, 0.95, 0.82)
	sun.shadow_enabled = false
	world_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-55, 148, 0)
	fill.light_energy = 0.0
	fill.light_color = Color(0.62, 0.72, 0.95)
	world_root.add_child(fill)

	var cloud_mesh := MeshInstance3D.new()
	var cloud_pm := PlaneMesh.new()
	cloud_pm.size = Vector2(200, 200)
	cloud_pm.subdivide_width = 24
	cloud_pm.subdivide_depth = 24
	cloud_mesh.mesh = cloud_pm
	cloud_mesh.position = Vector3(0, 6, 0)
	cloud_mesh.rotation_degrees.x = 90
	var csh := Shader.new()
	csh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

uniform float alpha = 0.92;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float n = fbm(uv * 6.0);
	float n2 = fbm(uv * 12.0 + 5.0);
	float panel = step(0.48, fract(uv.x * 8.0)) + step(0.48, fract(uv.y * 8.0));
	panel = clamp(panel, 0.0, 1.0);
	float base = 0.08 + n * 0.04 + panel * 0.03;
	float vent = smoothstep(0.42, 0.44, fract(uv.x * 16.0)) * step(0.3, uv.y) * step(uv.y, 0.7);
	ALBEDO = vec3(base * 0.7, base * 0.75, base * 0.85) - vec3(0.0, 0.0, vent * 0.02);
	ALPHA = alpha;
}
"""
	var cmat := ShaderMaterial.new()
	cmat.shader = csh
	cloud_mesh.material_override = cmat
	cloud_mesh.cast_shadow = 0
	world_root.add_child(cloud_mesh)

	if level_id == 2:
		sun.light_energy = 1.8
		sun.shadow_enabled = true
		sun.shadow_blur = 2.5
		sun.shadow_bias = 0.04
		sun.shadow_normal_bias = 0.6
		sun.light_size = 0.6
		fill.light_energy = 0.35
		_build_jungle_lights()
	else:
		for cfg in [
			[Vector3(-6, 5.8, 6), Color(1.0, 0.35, 0.12), 4.0, 22.0],
			[Vector3(7, 5.8, 6), Color(1.0, 0.35, 0.12), 4.0, 22.0],
			[Vector3(-18, 5.8, -3), Color(1.0, 0.38, 0.14), 3.5, 20.0],
			[Vector3(18, 5.8, -10), Color(1.0, 0.38, 0.14), 3.5, 20.0],
			[Vector3(0, 5.5, -22), Color(1.0, 0.32, 0.1), 3.8, 20.0],
		]:
			var pos: Vector3 = cfg[0]
			var col: Color = cfg[1]
			var energy: float = cfg[2]
			var rng: float = cfg[3]
			var omni := OmniLight3D.new()
			omni.position = pos
			omni.light_color = col
			omni.light_energy = energy * 0.6
			omni.omni_range = rng * 0.7
			world_root.add_child(omni)
			var spot := SpotLight3D.new()
			spot.position = pos
			spot.rotation_degrees.x = 90
			spot.light_color = col
			spot.light_energy = energy * 1.2
			spot.spot_range = rng
			spot.spot_angle = 80.0
			spot.spot_attenuation = 1.5
			spot.shadow_enabled = false
			world_root.add_child(spot)

		for cfg in [
			[Vector3(-12, 5.8, -8), Color(0.55, 0.7, 1.0), 3.0, 18.0],
			[Vector3(12, 5.8, 2), Color(0.55, 0.7, 1.0), 3.0, 18.0],
			[Vector3(0, 5.8, 12), Color(0.55, 0.7, 1.0), 2.8, 16.0],
			[Vector3(-24, 5.8, 8), Color(0.45, 0.6, 0.95), 2.5, 16.0],
			[Vector3(24, 5.8, -4), Color(0.45, 0.6, 0.95), 2.5, 16.0],
			[Vector3(-10, 5.8, 18), Color(0.5, 0.65, 0.95), 2.5, 15.0],
			[Vector3(10, 5.8, -18), Color(0.5, 0.65, 0.95), 2.5, 15.0],
			[Vector3(0, 5.8, -8), Color(0.5, 0.65, 0.95), 2.5, 15.0],
		]:
			var pos: Vector3 = cfg[0]
			var col: Color = cfg[1]
			var energy: float = cfg[2]
			var rng: float = cfg[3]
			var omni := OmniLight3D.new()
			omni.position = pos
			omni.light_color = col
			omni.light_energy = energy * 0.5
			omni.omni_range = rng * 0.6
			world_root.add_child(omni)

		var exit_light := OmniLight3D.new()
		exit_light.position = Vector3(0, 3.2, -29)
		exit_light.light_color = Color(0.2, 0.9, 0.6)
		exit_light.light_energy = 3.0
		exit_light.omni_range = 20.0
		world_root.add_child(exit_light)

		var pit_light := OmniLight3D.new()
		pit_light.position = Vector3(0, -3.2, -17.5)
		pit_light.light_color = Color(1.0, 0.22, 0.05)
		pit_light.light_energy = 4.0
		pit_light.omni_range = 12.0
		pit_light.shadow_enabled = false
		world_root.add_child(pit_light)
		var pit_spot := SpotLight3D.new()
		pit_spot.position = Vector3(0, -1.5, -17.5)
		pit_spot.rotation_degrees.x = 90
		pit_spot.light_color = Color(1.0, 0.15, 0.02)
		pit_spot.light_energy = 5.0
		pit_spot.spot_range = 10.0
		pit_spot.spot_angle = 60.0
		pit_spot.spot_attenuation = 2.0
		pit_spot.shadow_enabled = false
		world_root.add_child(pit_spot)

	if level_id == 2:
		sky_mat.sky_top_color = Color(0.14, 0.36, 0.22)
		sky_mat.sky_horizon_color = Color(0.72, 0.68, 0.5)
		sky_mat.sky_energy_multiplier = 1.3
		sky_mat.ground_bottom_color = Color(0.14, 0.22, 0.12)
		sky_mat.ground_horizon_color = Color(0.45, 0.52, 0.38)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		e.ambient_light_energy = 1.25
		e.ambient_light_sky_contribution = 1.0
		e.fog_light_color = Color(0.5, 0.6, 0.42)
		e.fog_density = 0.012
		e.fog_sun_scatter = 1.0
		e.fog_aerial_perspective = 0.5
		e.fog_sky_affect = 0.4
		e.volumetric_fog_density = 0.02
		e.volumetric_fog_sky_affect = 0.6
		e.tonemap_exposure = 1.1
		e.adjustment_saturation = 1.06
		sun.light_color = Color(1.0, 0.92, 0.76)

	if level_id == 2:
		_build_jungle_terrain()
		_build_jungle_flora()
		FX.add_dust_motes(world_root, Vector3(0, 2.0, 0), 30.0)
		FX.add_fireflies(world_root, Vector3(0, 1.5, -5), 25.0, 30)
	else:
		_build_terrain()
		_build_ruins()
		_build_shrines_and_puzzles()
		FX.add_dust_motes(world_root, Vector3(0, 2.0, -4), 28.0)
		FX.add_torch_embers(world_root, Vector3(-8, 1.0, -2), 10)
		FX.add_torch_embers(world_root, Vector3(8, 1.0, -2), 10)

func _build_terrain() -> void:
	var ground_mat := _tex_mat(Color(0.22, 0.24, 0.28), "gunmetal", 0.3, 0.7, 0.5)
	# 地面分块，中央留出尖刺坑洞 (x -5..5, z -16..-19)
	_make_box_static(world_root, Vector3(0, -0.5, 2), Vector3(90, 1, 36), ground_mat)
	_make_box_static(world_root, Vector3(0, -0.5, -25.5), Vector3(90, 1, 13), ground_mat)
	_make_box_static(world_root, Vector3(-25, -0.5, -17.5), Vector3(40, 1, 3), ground_mat)
	_make_box_static(world_root, Vector3(25, -0.5, -17.5), Vector3(40, 1, 3), ground_mat)

	var wall_mat := _tex_mat(Color(0.3, 0.32, 0.38), "steel", 0.3, 0.65, 0.55)
	_make_box_static(world_root, Vector3(-32, 3, -4), Vector3(1, 6, 56), wall_mat)
	_make_box_static(world_root, Vector3(32, 3, -4), Vector3(1, 6, 56), wall_mat)
	_make_box_static(world_root, Vector3(0, 3, 24), Vector3(64, 6, 1), wall_mat)
	_make_box_static(world_root, Vector3(0, 3, -32), Vector3(64, 6, 1), wall_mat)

	# 尖刺坑
	var pit_mat := _tex_mat(Color(0.15, 0.16, 0.19), "metal", 0.4, 0.8, 0.4)
	_make_box_static(world_root, Vector3(-5.5, -2, -17.5), Vector3(1, 4, 3), pit_mat)
	_make_box_static(world_root, Vector3(5.5, -2, -17.5), Vector3(1, 4, 3), pit_mat)
	_make_box_static(world_root, Vector3(0, -2, -15.5), Vector3(10, 4, 1), pit_mat)
	_make_box_static(world_root, Vector3(0, -2, -19.5), Vector3(10, 4, 1), pit_mat)
	var dark_mat := _tex_mat(Color(0.06, 0.06, 0.08), "metal", 0.5, 0.9)
	_make_box_static(world_root, Vector3(0, -4.7, -17.5), Vector3(10, 0.6, 3), dark_mat)
	var spike_mat := _tex_mat(Color(0.45, 0.48, 0.55), "steel", 0.5, 0.3, 0.7)
	for sx in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		for sz in [-16.7, -17.5, -18.3]:
			_make_cylinder_static(world_root, Vector3(sx, -4.4, sz), Vector3(0.12, 0.9, 0.12), spike_mat)

func _build_ruins() -> void:
	# 庭院立柱 → 工业支撑柱
	var pillar_mat := _tex_mat(Color(0.35, 0.38, 0.42), "steel", 0.3, 0.6, 0.6)
	_make_pillar(world_root, Vector3(-10, 0, 4), 3.5, 0.8, true)
	_make_pillar(world_root, Vector3(10, 0, 4), 4.0, 0.8, false)
	_make_pillar(world_root, Vector3(-10, 0, -4), 4.0, 0.8, false)
	_make_pillar(world_root, Vector3(10, 0, -4), 3.0, 0.8, true)
	_make_pillar(world_root, Vector3(0, 0, -10), 4.5, 0.9, false)
	_make_pillar(world_root, Vector3(-16, 0, 12), 3.2, 0.7, true)
	_make_pillar(world_root, Vector3(16, 0, 12), 3.6, 0.7, true)
	_make_pillar(world_root, Vector3(-16, 0, -6), 4.2, 0.8, false)
	_make_pillar(world_root, Vector3(16, 0, -6), 3.8, 0.8, false)
	# 中央断裂拱门 → 损坏的管线桥架
	var arch_mat := _tex_mat(Color(0.3, 0.32, 0.36), "gunmetal", 0.3, 0.65, 0.5)
	_make_box_static(world_root, Vector3(-3.5, 3.0, -10), Vector3(0.6, 0.5, 3.0), arch_mat)
	_make_box_static(world_root, Vector3(3.5, 3.0, -10), Vector3(0.6, 0.5, 3.0), arch_mat)
	# 碎石 → 散落的金属碎片
	var rubble_mat := _tex_mat(Color(0.28, 0.3, 0.34), "metal", 0.5, 0.75, 0.45)
	var rubble_spots := [
		[-18.0, 3.0], [18.0, -12.0], [-6.0, 7.0], [14.0, 6.0],
		[-24.0, -2.0], [-2.0, 4.0], [2.0, 14.0], [22.0, -6.0],
	]
	for spot in rubble_spots:
		_make_box_static(world_root, Vector3(spot[0], 0.18, spot[1]),
				Vector3(0.8, 0.35, 0.8), rubble_mat)
	# 藤蔓 → 电缆和管线
	var vine_mat := _tex_mat(Color(0.12, 0.14, 0.16), "carbon", 0.5, 0.6)
	_make_box_static(world_root, Vector3(-10, 2.0, 4.6), Vector3(0.1, 2.2, 0.1), vine_mat)
	_make_box_static(world_root, Vector3(10, 1.6, 4.6), Vector3(0.1, 1.6, 0.1), vine_mat)
	_make_box_static(world_root, Vector3(0, 2.4, -10.5), Vector3(0.1, 2.4, 0.1), vine_mat)

func _build_shrines_and_puzzles() -> void:
	var shrine_mat := _tex_mat(Color(0.28, 0.3, 0.35), "gunmetal", 0.3, 0.7, 0.5)
	var door_mat := _tex_mat(Color(0.22, 0.25, 0.3), "gunmetal", 0.25, 0.65, 0.55)

	# ---- 西侧设备间外墙（入口处留门洞）----
	_make_box_static(world_root, Vector3(-25, 1.5, 14), Vector3(10, 3, 1), shrine_mat)
	_make_box_static(world_root, Vector3(-25, 1.5, 2), Vector3(10, 3, 1), shrine_mat)
	_make_box_static(world_root, Vector3(-30, 1.5, 8), Vector3(1, 3, 12), shrine_mat)
	_make_box_static(world_root, Vector3(-20, 1.5, 4.15), Vector3(1, 3, 4.3), shrine_mat)
	_make_box_static(world_root, Vector3(-20, 1.5, 11.85), Vector3(1, 3, 4.3), shrine_mat)
	_west_door = _make_door(Vector3(-20, 1.6, 8), Vector3(0.5, 3.2, 3.4), door_mat)
	var rp_west := ReflectionProbe.new()
	rp_west.position = Vector3(-25, 1.5, 8)
	rp_west.extents = Vector3(5.5, 2.0, 6.5)
	rp_west.mesh_lod_threshold = 2.0
	world_root.add_child(rp_west)

	# ---- 西侧高台与开关（跳跃平台）----
	var crate_mat := _tex_mat(Color(0.32, 0.34, 0.38), "polymer", 0.6, 0.6)
	_make_box_static(world_root, Vector3(-10, 0.4, 10), Vector3(0.8, 0.8, 0.8), crate_mat)
	_make_box_static(world_root, Vector3(-12, 1.2, 10), Vector3(0.8, 0.8, 0.8), crate_mat)
	_make_box_static(world_root, Vector3(-14, 0.8, 10), Vector3(1, 1.6, 1), shrine_mat)
	_make_box_static(world_root, Vector3(-14, 1.45, 10), Vector3(3, 0.3, 3), shrine_mat)
	var lever := _make_switch("lever", Vector3(-14, 1.6, 10))
	lever.doors = [_west_door]

	# ---- 东侧设备间 ----
	_make_box_static(world_root, Vector3(25, 1.5, 4), Vector3(10, 3, 1), shrine_mat)
	_make_box_static(world_root, Vector3(25, 1.5, -8), Vector3(10, 3, 1), shrine_mat)
	_make_box_static(world_root, Vector3(30, 1.5, -2), Vector3(1, 3, 12), shrine_mat)
	_make_box_static(world_root, Vector3(20, 1.5, -5.85), Vector3(1, 3, 4.3), shrine_mat)
	_make_box_static(world_root, Vector3(20, 1.5, 1.85), Vector3(1, 3, 4.3), shrine_mat)
	_east_door = _make_door(Vector3(20, 1.6, -2), Vector3(0.5, 3.2, 3.4), door_mat)
	var rp_east := ReflectionProbe.new()
	rp_east.position = Vector3(25, 1.5, -2)
	rp_east.extents = Vector3(5.5, 2.0, 6.5)
	rp_east.mesh_lod_threshold = 2.0
	world_root.add_child(rp_east)

	# ---- 东侧压力板与高台 ----
	_make_box_static(world_root, Vector3(7, 0.4, -8), Vector3(0.8, 0.8, 0.8), crate_mat)
	_make_box_static(world_root, Vector3(9.5, 1.2, -8), Vector3(0.8, 0.8, 0.8), crate_mat)
	_make_box_static(world_root, Vector3(12, 1.1, -8), Vector3(1.5, 2.2, 2), shrine_mat)
	_make_box_static(world_root, Vector3(12, 2.05, -8), Vector3(3, 0.3, 4), shrine_mat)
	var plate := _make_switch("plate", Vector3(16, 0, -2))
	plate.doors = [_east_door]

	# ---- 出口气密闸门 ----
	exit_door = _make_door(Vector3(0, 2.2, -28), Vector3(7, 4.4, 0.5), door_mat)
	var arch_mat := _tex_mat(Color(0.32, 0.34, 0.38), "steel", 0.3, 0.6, 0.55)
	_make_pillar(world_root, Vector3(-3.5, 0, -28), 4.4, 0.7, false)
	_make_pillar(world_root, Vector3(3.5, 0, -28), 4.4, 0.7, false)

# ---------------- 丛林关卡（第二关） ----------------

func _build_jungle_lights() -> void:
	var glows := [
		[Vector3(-12, 2.2, -10), Color(0.5, 1.0, 0.6), 1.8, 12.0],
		[Vector3(18, 2.6, 8), Color(1.0, 0.72, 0.32), 1.7, 11.0],
		[Vector3(0, 2.0, -6), Color(0.45, 0.95, 0.8), 1.5, 11.0],
		[Vector3(-6, 2.2, 14), Color(0.6, 1.0, 0.7), 1.4, 9.0],
		[Vector3(0, 2.8, -26), Color(1.0, 0.78, 0.4), 2.0, 13.0],
	]
	for cfg in glows:
		var pos: Vector3 = cfg[0]
		var col: Color = cfg[1]
		var energy: float = cfg[2]
		var rng: float = cfg[3]
		var omni := OmniLight3D.new()
		omni.position = pos
		omni.light_color = col
		omni.light_energy = energy * 0.5
		omni.omni_range = rng * 0.6
		omni.shadow_enabled = false
		world_root.add_child(omni)
		var spot := SpotLight3D.new()
		spot.position = pos
		spot.rotation_degrees.x = -90
		spot.light_color = col
		spot.light_energy = energy
		spot.spot_range = rng
		spot.spot_angle = 50.0
		spot.spot_attenuation = 1.8
		spot.shadow_enabled = false
		world_root.add_child(spot)
	var ravine := OmniLight3D.new()
	ravine.position = Vector3(0, -3.6, -17.5)
	ravine.light_color = Color(0.2, 0.5, 0.45)
	ravine.light_energy = 1.6
	ravine.omni_range = 8.0
	ravine.shadow_enabled = false
	world_root.add_child(ravine)

func _build_jungle_terrain() -> void:
	var grass_mat := _tex_mat(Color(0.3, 0.5, 0.24), "grass", 0.25, 0.9)
	# 中央草面按河道切开，留出溪流槽（z -7.5..-4.5）
	_make_box_static(world_root, Vector3(0, -0.5, -11.75), Vector3(90, 1, 8.5), grass_mat)
	_make_box_static(world_root, Vector3(0, -0.5, 7.75), Vector3(90, 1, 24.5), grass_mat)
	_make_box_static(world_root, Vector3(0, -0.5, -25.5), Vector3(90, 1, 13), grass_mat)
	_make_box_static(world_root, Vector3(-25, -0.5, -17.5), Vector3(40, 1, 3), grass_mat)
	_make_box_static(world_root, Vector3(25, -0.5, -17.5), Vector3(40, 1, 3), grass_mat)

	var cliff_mat := _tex_mat(Color(0.42, 0.46, 0.36), "stone", 0.5, 0.9)
	_make_box_static(world_root, Vector3(-32, 3.2, -4), Vector3(1, 6.4, 56), cliff_mat)
	_make_box_static(world_root, Vector3(32, 3.2, -4), Vector3(1, 6.4, 56), cliff_mat)
	_make_box_static(world_root, Vector3(0, 3.2, 24), Vector3(64, 6.4, 1), cliff_mat)
	_make_box_static(world_root, Vector3(0, 3.2, -32), Vector3(64, 6.4, 1), cliff_mat)
	# 岩壁垂藤
	for vz in range(-30, 26, 8):
		_make_vine_hanging(Vector3(-31.9, 6.3, vz), randf_range(3.0, 5.0))
		_make_vine_hanging(Vector3(31.9, 6.3, vz + 4), randf_range(3.0, 5.0))

	# 浅溪（横穿 z=-6，可蹚水）
	var stream_mat := _tex_mat(Color(0.36, 0.34, 0.3), "stone", 0.5, 0.9)
	_make_box_static(world_root, Vector3(0, -0.6, -6), Vector3(48, 0.5, 3), stream_mat)
	_make_water_plane(Vector3(0, -0.15, -6), Vector2(48, 2.8), Color(0.14, 0.4, 0.42, 0.7))
	for i in 18:
		var sx := randf_range(-22.0, 22.0)
		var sz := randf_range(-7.0, -5.0)
		if absf(sx) < 5.0:
			continue
		_make_boulder(Vector3(sx, -0.25, sz), Vector3(randf_range(0.2, 0.45), randf_range(0.12, 0.28), randf_range(0.2, 0.45)))

	# 深潭（西南，微凹避免与草地共面）
	var pool_mat := _tex_mat(Color(0.2, 0.25, 0.22), "stone", 0.6, 0.9)
	_make_box_static(world_root, Vector3(-6, -0.9, 14), Vector3(5, 1.5, 4), pool_mat)
	_make_water_plane(Vector3(-6, 0.06, 14), Vector2(4.6, 3.6), Color(0.12, 0.38, 0.42, 0.85))
	_make_boulder(Vector3(-9.3, 0.2, 14), Vector3(1.3, 0.6, 1.1))
	_make_boulder(Vector3(-2.9, 0.2, 14.8), Vector3(1.1, 0.5, 1.0))

	# 峡谷（陷阱，z=-17.5）：水潭与尖石
	var ravine_mat := _tex_mat(Color(0.3, 0.36, 0.32), "stone", 0.45, 0.9)
	_make_box_static(world_root, Vector3(-5.5, -2, -17.5), Vector3(1, 4, 3), ravine_mat)
	_make_box_static(world_root, Vector3(5.5, -2, -17.5), Vector3(1, 4, 3), ravine_mat)
	_make_box_static(world_root, Vector3(0, -2, -15.5), Vector3(10, 4, 1), ravine_mat)
	_make_box_static(world_root, Vector3(0, -2, -19.5), Vector3(10, 4, 1), ravine_mat)
	var dark_mat := _tex_mat(Color(0.1, 0.12, 0.12), "stone", 0.5, 0.9)
	_make_box_static(world_root, Vector3(0, -4.7, -17.5), Vector3(10, 0.6, 3), dark_mat)
	_make_water_plane(Vector3(0, -3.7, -17.5), Vector2(9.4, 2.4), Color(0.1, 0.32, 0.36, 0.8))
	var spike_mat := _tex_mat(Color(0.5, 0.52, 0.5), "stone", 0.8, 0.85)
	for sx in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		for sz in [-16.7, -17.5, -18.3]:
			_make_cylinder_static(world_root, Vector3(sx, -4.4, sz), Vector3(0.14, 0.9, 0.14), spike_mat)

	# 岩石露头（起伏感）
	_make_boulder(Vector3(-2, 0.2, -20), Vector3(2.4, 1.1, 2.0))
	_make_boulder(Vector3(24, 0.2, -16), Vector3(2.0, 1.0, 1.6))
	_make_boulder(Vector3(18, 0.2, 18), Vector3(2.2, 1.0, 1.8))

func _build_jungle_flora() -> void:
	# 巨石阵（北部，中央藏宝石）
	var ring_angles := [0.0, 0.6, 1.5, 2.4, 3.4, 4.6]
	for a in ring_angles:
		var px := -12.0 + cos(a) * 3.2
		var pz := -10.0 + sin(a) * 3.2
		_make_boulder(Vector3(px, 0.25, pz), Vector3(1.7, randf_range(1.1, 1.6), 1.5))

	# 高大乔木（覆盖丛林）
	_make_tree(Vector3(18, 0, 6), 7.0, 0.7)
	_make_tree(Vector3(-24, 0, 10), 7.5, 0.75)
	_make_tree(Vector3(-24, 0, -4), 6.5, 0.6)
	_make_tree(Vector3(-20, 0, 18), 7.0, 0.7)
	_make_tree(Vector3(22, 0, 18), 6.8, 0.65)
	_make_tree(Vector3(6, 0, -20), 7.2, 0.7)
	_make_tree(Vector3(-14, 0, -22), 6.8, 0.6)
	_make_tree(Vector3(2, 0, -24), 6.5, 0.6)
	# 出口两侧巨树（夹出天然通道）
	_make_tree(Vector3(-4.5, 0, -28), 7.0, 0.7)
	_make_tree(Vector3(4.5, 0, -28), 7.0, 0.7)

	# 棕榈点缀
	var palm_spots := [
		[-28, 8], [-28, -20], [28, -10], [28, 14], [-10, 22], [16, 22], [-2, -2],
	]
	for s in palm_spots:
		_make_palm(Vector3(s[0], 0, s[1]), randf_range(3.0, 4.6))

	# 树冠垂藤
	_make_vine_hanging(Vector3(18, 5.2, 6), 3.0)
	_make_vine_hanging(Vector3(-24, 5.6, 10), 3.5)
	_make_vine_hanging(Vector3(-24, 4.8, -4), 2.5)

	# 倒木
	_make_fallen_log(Vector3(-8, 0.32, 8), 4.0, 0.3, 0.6)
	_make_fallen_log(Vector3(10, 0.32, -18), 5.0, 0.34, 1.2)
	_make_fallen_log(Vector3(-22, 0.32, 18), 4.0, 0.28, -0.4)

	# 灌木丛
	_make_bush(Vector3(-4, 0.3, 6), 0.55)
	_make_bush(Vector3(6, 0.3, -10), 0.6)
	_make_bush(Vector3(-14, 0.3, -6), 0.5)
	_make_bush(Vector3(2, 0.3, 14), 0.5)
	_make_bush(Vector3(22, 0.3, -16), 0.55)
	_make_bush(Vector3(-2, 0.3, -14), 0.5)
	_make_bush(Vector3(10, 0.3, 4), 0.6)

	# 出口巨木屏障（天然倒木门）
	var barrier_mat := _tex_mat(Color(0.4, 0.32, 0.2), "wood", 1.0, 0.8)
	exit_door = _make_door(Vector3(0, 1.2, -28), Vector3(7, 2.4, 0.5), barrier_mat)

func _make_water_plane(pos: Vector3, size: Vector2, color: Color) -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 32
	pm.subdivide_depth = 32
	m.mesh = pm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 water_color = vec3(0.15, 0.35, 0.45);
uniform float alpha_deep = 0.75;
uniform float alpha_shallow = 0.55;
uniform float speed = 0.6;
uniform float wave_amp = 0.025;
uniform float wave_freq = 4.0;
uniform vec2 scroll1 = vec2(0.04, 0.02);
uniform vec2 scroll2 = vec2(-0.03, 0.035);

float wave(vec2 uv, vec2 dir, float freq, float amp, float t) {
	return amp * sin(dot(uv, dir) * freq + t);
}

void fragment() {
	float t = TIME;
	vec2 uv = UV;

	float w1 = wave(uv, vec2(1.0, 0.3), wave_freq, wave_amp, t * speed);
	float w2 = wave(uv, vec2(-0.4, 1.0), wave_freq * 1.7, wave_amp * 0.6, t * speed * 1.3);
	float w3 = wave(uv, vec2(0.7, -0.5), wave_freq * 2.9, wave_amp * 0.35, t * speed * 0.8);

	vec2 scrolled1 = uv + scroll1 * t * speed;
	vec2 scrolled2 = uv + scroll2 * t * speed;
	float pattern1 = sin(scrolled1.x * 14.0 + w1 * 18.0) * sin(scrolled1.y * 11.0 + w2 * 14.0);
	float pattern2 = sin(scrolled2.x * 17.0 - w3 * 20.0) * cos(scrolled2.y * 13.0 + w1 * 12.0);
	float ripples = pattern1 * 0.5 + pattern2 * 0.5;

	ALBEDO = water_color + vec3(ripples * 0.06);
	ALPHA = mix(alpha_deep, alpha_shallow, ripples * 0.5 + 0.5);

	float edge_detect = fwidth(length(UV - 0.5) * 2.0);
	ALPHA = mix(ALPHA, 0.88, clamp(edge_detect * 6.0, 0.0, 0.4));

	ROUGHNESS = 0.04 + abs(ripples) * 0.1;
	METALLIC = 0.35;
	SPECULAR = 0.7;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("water_color", Vector3(color.r, color.g, color.b))
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = Vector3(-90, 0, 0)
	m.cast_shadow = 0
	world_root.add_child(m)

func _make_palm(pos: Vector3, h: float) -> void:
	var trunk_mat := _tex_mat(Color(0.4, 0.3, 0.18), "wood", 0.9, 0.82)
	var trunk_r := 0.14
	_make_cylinder_static(world_root, pos + Vector3(0, h * 0.35, 0), Vector3(trunk_r * 1.1, h * 0.7, trunk_r * 1.1), trunk_mat)
	_make_cylinder_static(world_root, pos + Vector3(0.08, h * 0.78, 0), Vector3(trunk_r * 0.7, h * 0.35, trunk_r * 0.7), trunk_mat)
	var leaf_dark := _tex_mat(Color(0.12, 0.45, 0.14), "leaf", 0.5, 0.82)
	var leaf_bright := _tex_mat(Color(0.22, 0.58, 0.2), "leaf", 0.4, 0.78)
	var top := pos + Vector3(0.08, h, 0)
	for i in 8:
		var ang := TAU * float(i) / 8.0 + randf_range(-0.2, 0.2)
		var len_f := randf_range(1.4, 2.2)
		var frond := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.28, 0.04, len_f)
		frond.mesh = fm
		frond.material_override = leaf_dark if i % 2 == 0 else leaf_bright
		frond.position = top + Vector3(cos(ang) * len_f * 0.48, 0.12, sin(ang) * len_f * 0.48)
		frond.rotation = Vector3(-0.5, ang, -0.15)
		world_root.add_child(frond)

func _make_tree(pos: Vector3, h: float, r: float) -> void:
	var bark_dark := _tex_mat(Color(0.32, 0.24, 0.15), "wood", 1.2, 0.9)
	var bark_light := _tex_mat(Color(0.42, 0.34, 0.22), "wood", 1.0, 0.85)
	var crown_dark := _tex_mat(Color(0.14, 0.42, 0.12), "leaf", 0.7, 0.85)
	var crown_mid := _tex_mat(Color(0.2, 0.52, 0.18), "leaf", 0.6, 0.82)
	var crown_light := _tex_mat(Color(0.28, 0.58, 0.22), "leaf", 0.5, 0.8)
	_make_cylinder_static(world_root, pos + Vector3(0, h * 0.3, 0), Vector3(r * 1.3, h * 0.6, r * 1.3), bark_dark)
	_make_cylinder_static(world_root, pos + Vector3(0, h * 0.72, 0), Vector3(r * 0.8, h * 0.42, r * 0.8), bark_light)
	for i in 4:
		var ra := TAU * float(i) / 4.0 + randf_range(-0.3, 0.3)
		var rl := r * randf_range(0.9, 1.5)
		var root_m := MeshInstance3D.new()
		var root_cyl := CylinderMesh.new()
		root_cyl.top_radius = r * 0.3
		root_cyl.bottom_radius = r * 0.7
		root_cyl.height = rl
		root_m.mesh = root_cyl
		root_m.material_override = bark_dark
		root_m.position = pos + Vector3(cos(ra) * rl * 0.5, rl * 0.15, sin(ra) * rl * 0.5)
		root_m.rotation_degrees.z = rad_to_deg(ra) + 90
		root_m.rotation_degrees.x = 15
		world_root.add_child(root_m)
	var rng_t := RandomNumberGenerator.new()
	rng_t.seed = int(pos.x * 100 + pos.z * 7)
	for i in 6:
		var ca := TAU * float(i) / 6.0 + rng_t.randf_range(-0.4, 0.4)
		var cd := r * rng_t.randf_range(1.0, 2.5)
		var cr := r * rng_t.randf_range(1.4, 2.2)
		var ch := h * rng_t.randf_range(0.55, 0.82)
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = cr
		sm.height = cr * 1.6
		sm.radial_segments = 12
		sm.rings = 8
		m.mesh = sm
		m.material_override = crown_dark if i < 3 else crown_mid
		m.position = pos + Vector3(cos(ca) * cd * 0.35, ch, sin(ca) * cd * 0.35)
		world_root.add_child(m)
	for i in 3:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r * rng_t.randf_range(1.6, 2.0)
		sm.height = sm.radius * 1.3
		sm.radial_segments = 10
		sm.rings = 6
		m.mesh = sm
		m.material_override = crown_light
		m.position = pos + Vector3(rng_t.randf_range(-0.8, 0.8), h * rng_t.randf_range(0.82, 0.95), rng_t.randf_range(-0.8, 0.8))
		world_root.add_child(m)

func _make_fallen_log(pos: Vector3, len: float, r: float, yaw: float) -> void:
	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = len
	mesh.mesh = cm
	mesh.material_override = _tex_mat(Color(0.4, 0.32, 0.2), "wood", 0.9, 0.8)
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = len
	col.shape = shape
	body.add_child(col)
	body.position = pos
	body.rotation.y = yaw
	world_root.add_child(body)
	body.collision_layer = 1
	body.collision_mask = 1

func _make_vine_hanging(pos: Vector3, len: float) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.07
	cm.height = len
	m.mesh = cm
	m.material_override = _tex_mat(Color(0.22, 0.48, 0.2), "vine", 0.5, 0.8)
	m.position = pos + Vector3(0, -len * 0.5, 0)
	world_root.add_child(m)

func _make_boulder(pos: Vector3, size: Vector3) -> void:
	_make_box_static(world_root, pos, size, _tex_mat(Color(0.42, 0.46, 0.38), "stone", 0.7, 0.9))

func _make_bush(pos: Vector3, r: float) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	m.mesh = sm
	m.material_override = _tex_mat(Color(0.2, 0.55, 0.22), "leaf", 0.7, 0.85)
	m.position = pos
	world_root.add_child(m)

func _make_vine_column(pos: Vector3, h: float) -> void:
	var mat := _tex_mat(Color(0.2, 0.5, 0.2), "vine", 0.5, 0.8)
	_make_box_static(world_root, pos + Vector3(0, h * 0.5, 0), Vector3(0.12, h, 0.12), mat)

# ---------------- 场景元素工厂 ----------------

func _stone_mat(color: Color) -> StandardMaterial3D:
	return TexGen.mat(color, "stone", 0.3, 0.85)

func _tex_mat(color: Color, kind: String, scale: float, rough: float,
		metallic := 0.0) -> StandardMaterial3D:
	return TexGen.mat(color, kind, scale, rough, metallic)

func _make_door(pos: Vector3, size: Vector3, mat: Material) -> RuinDoor:
	var d := RuinDoor.new()
	d.setup(pos, size)
	for mi in d.get_children():
		if mi is MeshInstance3D:
			mi.material_override = mat
	world_root.add_child(d)
	_doors.append(d)
	return d

func _make_switch(mode: String, pos: Vector3) -> RuinSwitch:
	var s := RuinSwitch.new()
	s.setup(mode, pos)
	s.triggered.connect(_on_switch_triggered)
	world_root.add_child(s)
	_switches.append(s)
	return s

func _on_switch_triggered(sw: RuinSwitch) -> void:
	audio.play("lever" if sw.mode == "lever" else "plate", -6.0)
	audio.play("door", -9.0)

func _make_pillar(parent: Node3D, pos: Vector3, h: float, w: float, broken: bool) -> void:
	_make_box_static(parent, pos + Vector3(0, h * 0.5, 0), Vector3(w, h, w), _tex_mat(Color(0.35, 0.38, 0.42), "steel", 0.3, 0.6, 0.55))
	if broken:
		_make_box_static(parent, pos + Vector3(w * 0.35, h + 0.25, w * 0.1), Vector3(w * 0.4, 0.5, w * 0.4),
				_tex_mat(Color(0.3, 0.32, 0.36), "metal", 0.4, 0.7, 0.5))

func _make_box_static(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = mat
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = pos
	parent.add_child(body)
	body.collision_layer = 1
	body.collision_mask = 1

func _make_cylinder_static(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = size.x
	cm.bottom_radius = size.x
	cm.height = size.y
	mesh.mesh = cm
	mesh.material_override = mat
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = size.x
	shape.height = size.y
	col.shape = shape
	body.add_child(col)
	body.position = pos
	parent.add_child(body)
	body.collision_layer = 1
	body.collision_mask = 1

# ---------------- HUD / 音频 / 玩家 ----------------

func _build_hud() -> void:
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.start_requested.connect(_on_start_requested)
	hud.restart_requested.connect(_on_start_requested)
	hud.resume_requested.connect(_on_resume_requested)
	hud.level_requested.connect(_on_level_requested)
	hud.menu_requested.connect(_on_menu_requested)

func _build_audio() -> void:
	audio = AudioManager.new()
	audio.name = "Audio"
	add_child(audio)
	audio.add_to_group("audio_manager")
	audio.play_loop("wind", -20.0)

func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	world_root.add_child(player)
	player.scene_root = world_root
	player.global_position = SPAWN
	player.can_control = false
	player.fell_hard.connect(_on_player_fell)

func _on_start_requested() -> void:
	_demo_active = false
	_menu_idle = 0.0
	_over_idle = 0.0
	if hud:
		hud.set_demo(false)
	start_game()

func _on_resume_requested() -> void:
	resume_game()

func _on_level_requested(id: int) -> void:
	switch_level(id)
	audio.play("select", -8.0)

func _on_menu_requested() -> void:
	_demo_stop()
	state = "menu"
	Engine.time_scale = 1.0
	audio.stop_loop("ambient")
	paused = false
	if is_instance_valid(player):
		player.can_control = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.fade_in(0.3)
	hud.show_menu(best, level_id)
	audio.play("click", -8.0)

func switch_level(id: int) -> void:
	if id < 1 or id > 2 or id == level_id:
		return
	_demo_stop()
	level_id = id
	state = "menu"
	Engine.time_scale = 1.0
	audio.stop_loop("ambient")
	paused = false
	over_reason = ""
	if player:
		player.queue_free()
		player = null
	enemies.clear()
	artifacts.clear()
	pickups.clear()
	_doors.clear()
	_switches.clear()
	_west_door = null
	_east_door = null
	exit_door = null
	if world_root:
		world_root.free()
		world_root = null
	_build_scene()
	_spawn_player()
	_apply_level_audio()
	_reset_world()
	_update_objective()
	if hud:
		hud.show_menu(best, level_id)
		hud.fade_in(0.3)

func _apply_level_audio() -> void:
	if not audio:
		return
	audio.stop_loop("jungle_water")
	if level_id == 2:
		audio.play_loop("jungle_water", -22.0)
	if hud:
		hud.set_level_title("宝石" if level_id == 2 else "核心")

func _check_water() -> void:
	if level_id != 2 or not is_instance_valid(player):
		_in_water = false
		return
	var p: Vector3 = player.global_position
	var inw := (absf(p.x + 6.0) < 2.3 and absf(p.z - 14.0) < 1.8 and p.y < 1.2) \
			or (absf(p.x) < 23.0 and absf(p.z + 6.0) < 1.8 and p.y < 1.2)
	if inw and not _in_water:
		audio.play("splash", -7.0)
	_in_water = inw

func _jungle_amb_pos() -> Vector3:
	var a := randf() * TAU
	var d := randf_range(15.0, 28.0)
	return player.global_position + Vector3(cos(a) * d, randf_range(1.0, 5.0), sin(a) * d)

func _on_player_fell(dmg: float) -> void:
	if dmg > 5.0:
		damage_player(dmg)
		audio.play("land", -4.0)
		audio.play("hurt", -8.0)

# ---------------- 刷敌 / 文物 / 拾取 ----------------

func _spawn_enemies() -> void:
	var spots: Array[Array]
	if level_id == 2:
		spots = [
			[Enemy.Kind.BAT, Vector3(0, 4.0, -8)],
			[Enemy.Kind.BAT, Vector3(-18, 4.5, -6)],
			[Enemy.Kind.BAT, Vector3(18, 4.5, 8)],
			[Enemy.Kind.SKELETON, Vector3(8, 0, -14)],
			[Enemy.Kind.SKELETON, Vector3(26, 0, 8)],
			[Enemy.Kind.SKELETON, Vector3(-2, 0, 18)],
		]
	else:
		spots = [
			[Enemy.Kind.BAT, Vector3(0, 3.5, 2)],
			[Enemy.Kind.BAT, Vector3(-25, 3.5, 9)],
			[Enemy.Kind.BAT, Vector3(12, 3.5, -8)],
			[Enemy.Kind.SKELETON, Vector3(10, 0, 4)],
			[Enemy.Kind.SKELETON, Vector3(-3, 0, -22)],
			[Enemy.Kind.SKELETON, Vector3(25, 0, -4)],
		]
	var variant := 1 if level_id == 2 else 0
	for spot in spots:
		var e := Enemy.make(spot[0], spot[1], world_root, variant)
		e.hit.connect(_on_enemy_hit)
		e.destroyed.connect(_on_enemy_destroyed)
		enemies.append(e)

func _spawn_artifacts() -> void:
	var spots: Array[Vector3]
	if level_id == 2:
		spots = [
			Vector3(-12, 0.8, -10),
			Vector3(20, 0.8, -6),
			Vector3(-26, 0.8, 8),
		]
	else:
		spots = [
			Vector3(-25, 0.7, 8),
			Vector3(12, 2.9, -8),
			Vector3(25, 0.7, -2),
		]
	for pos in spots:
		var a := Artifact.new()
		a.setup(pos)
		world_root.add_child(a)
		artifacts.append(a)

func _spawn_pickups() -> void:
	if level_id == 2:
		place_pickup("med", Vector3(0, 0.6, 16))
		place_pickup("med", Vector3(-26, 0.6, 5))
		place_pickup("ammo", Vector3(26, 0.6, 3))
		place_pickup("ammo", Vector3(-5, 0.6, -16))
	else:
		place_pickup("med", Vector3(0, 0.6, 16))
		place_pickup("med", Vector3(-27, 0.6, 5))
		place_pickup("ammo", Vector3(27, 0.6, 1))
		place_pickup("ammo", Vector3(-6, 0.6, -14))

func place_pickup(type: String, pos: Vector3) -> Pickup:
	var p := Pickup.new()
	p.setup(pos, type)
	world_root.add_child(p)
	pickups.append(p)
	return p

# ---------------- 游戏流程 ----------------

func _physics_process(delta: float) -> void:
	if _demo_enabled:
		_demo_auto(delta)
	if state == "playing" and not paused:
		_elapsed += delta
		time_left = maxf(ROUND_TIME - _elapsed, 0.0)
		if _demo_active:
			_demo_tick(delta)
			health = minf(health + 4.0 * delta, 100.0)
		_check_pit()
		_check_artifacts()
		_check_plates()
		_check_pickups()
		_check_exit()
		_check_water()
		if level_id == 2:
			_amb_cd -= delta
			if _amb_cd <= 0.0:
				_amb_cd = randf_range(8.0, 15.0)
				if randf() < 0.45:
					audio.play3d("beast_roar", world_root, _jungle_amb_pos(), -18.0)
				else:
					audio.play3d("insect", world_root, _jungle_amb_pos(), -13.0)
		if time_left <= 0.0:
			end_game("时间耗尽，系统崩溃")
	_hitmark_cd = maxf(_hitmark_cd - delta, 0.0)
	_dmg_flash = maxf(_dmg_flash - delta, 0.0)
	if _slowmo_cd > 0.0:
		_slowmo_cd -= delta
		if _slowmo_cd <= 0.0:
			Engine.time_scale = 1.0
	if state == "playing" and not paused and health < 30.0:
		_heart_cd -= delta
		if _heart_cd <= 0.0:
			_heart_cd = lerpf(1.1, 0.5, 1.0 - health / 30.0)
			audio.play("heartbeat", -8.0)
			_dmg_flash = maxf(_dmg_flash, 0.24)
	if hud:
		if is_instance_valid(player):
			var spd := Vector2(player.velocity.x, player.velocity.z).length()
			var ch_spread := clampf(spd / 8.5, 0.0, 1.0) * 0.45
			if _hitmark_cd > 0.0:
				ch_spread += 0.35
			hud.set_crosshair_spread(ch_spread)
		hud.set_hitmark(_hitmark_cd > 0.0, _last_hit_kill)
		hud.set_damage_flash(_dmg_flash)
		if player:
			var w := player.current_weapon()
			hud.set_values(score, best, health, time_left, artifacts_collected, ARTIFACTS_TOTAL,
					exit_open, w.display, w.mag, w.reserve, player.reloading)
			hud.set_interact(_interact_prompt())
			if state == "playing" and not paused:
				hud.set_objective_arrow(_objective_angle(), _objective_distance(), "出口" if exit_open else "目标")
			else:
				hud.set_objective_arrow_hidden()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventJoypadButton \
			or (event is InputEventMouseMotion and (event.relative.x != 0 or event.relative.y != 0)):
		if _demo_active:
			_demo_stop()
		elif state == "menu":
			_menu_idle = 0.0
	if event.is_action_pressed("interact"):
		if state == "playing" and not paused:
			interact()
	if event.is_action_pressed("pause"):
		if state == "playing":
			if paused:
				resume_game()
			else:
				pause_game()

func start_game() -> void:
	score = 0
	health = 100.0
	_elapsed = 0.0
	time_left = ROUND_TIME
	over_reason = ""
	paused = false
	state = "playing"
	Engine.time_scale = 1.0
	_reset_world()
	player.reset_for_round()
	player.can_control = true
	player.global_position = SPAWN
	player.rotation = Vector3.ZERO
	_update_objective()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_hud()
	hud.fade_in(0.35)
	audio.play("start", -4.0)
	audio.play_loop("ambient", -24.0)
	emit_signal("game_started")

func pause_game() -> void:
	paused = true
	player.can_control = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_pause()

func resume_game() -> void:
	if state != "playing":
		return
	paused = false
	player.can_control = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.hide_pause()
	audio.play("click", -8.0)

func end_game(reason: String, victory := false) -> void:
	if state != "playing":
		return
	state = "over"
	Engine.time_scale = 1.0
	audio.stop_loop("ambient")
	over_reason = reason
	player.can_control = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.fade_out(0.5)
	if victory:
		score += 500
		audio.play("victory", -6.0)
	else:
		audio.play("gameover", -10.0)
	if score > best:
		best = score
		_save_best()
	hud.show_over(reason, score, best, victory)
	emit_signal("game_over", score, reason)

func _reset_world() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for a in artifacts:
		if is_instance_valid(a):
			a.queue_free()
	artifacts.clear()
	for p in pickups:
		if is_instance_valid(p):
			p.queue_free()
	pickups.clear()
	for s in _switches:
		s.reset()
	for d in _doors:
		d.close()
	artifacts_collected = 0
	exit_open = false
	checkpoint = SPAWN
	_enemies_defeated = 0
	_spawn_enemies()
	_spawn_artifacts()
	_spawn_pickups()

# ---------------- 演示（自动游玩）模式 ----------------

func _demo_auto(delta: float) -> void:
	if state == "menu" and not _demo_active:
		_menu_idle += delta
		if _menu_idle >= 5.0:
			_demo_start()
	elif state == "over" and _demo_active:
		_over_idle += delta
		if _over_idle >= 5.0:
			_demo_active = false
			_demo_start()

func _demo_start() -> void:
	if _demo_active:
		return
	_demo_active = true
	_demo_fire_cd = 0.0
	_menu_idle = 0.0
	_over_idle = 0.0
	start_game()
	if hud:
		hud.set_demo(true)

func _demo_stop() -> void:
	if not _demo_active:
		return
	_demo_active = false
	_menu_idle = 0.0
	_over_idle = 0.0
	if player:
		player.set_test_move(Vector2.ZERO)
	if hud:
		hud.set_demo(false)

func _demo_tick(delta: float) -> void:
	_demo_fire_cd = maxf(_demo_fire_cd - delta, 0.0)
	if not is_instance_valid(player):
		return
	var enemy := _demo_nearest_enemy()
	if enemy != null and health > 40.0 and player.global_position.distance_to(enemy.global_position) < 18.0:
		player.aim_at(enemy.global_position + Vector3(0, 1.0, 0))
		if _demo_fire_cd <= 0.0:
			if player.try_fire():
				_demo_fire_cd = 0.36
		player.set_test_move(Vector2(0.35 * sin(_elapsed * 0.8), 0))
		return
	player.aim_at(_demo_goal() + Vector3(0, 1.0, 0))
	_demo_steer()

func _demo_goal() -> Vector3:
	if health < 75.0:
		var m := _demo_nearest_pickup("med")
		if m != null:
			return m.global_position
	elif player.reserve() + player.mag() < 12:
		var a := _demo_nearest_pickup("ammo")
		if a != null:
			return a.global_position
	if not exit_open:
		var art := _demo_nearest_artifact()
		if art != null:
			return art.global_position
	return Vector3(0, 0.1, -34)

func _demo_nearest_enemy() -> Enemy:
	var best: Enemy = null
	var bd := INF
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			var d := player.global_position.distance_squared_to(e.global_position)
			if d < bd:
				bd = d
				best = e
	return best

func _demo_nearest_pickup(type: String) -> Pickup:
	var best: Pickup = null
	var bd := INF
	for p in pickups:
		if is_instance_valid(p) and p.ptype == type:
			var d := player.global_position.distance_squared_to(p.global_position)
			if d < bd:
				bd = d
				best = p
	return best

func _demo_nearest_artifact() -> Artifact:
	var best: Artifact = null
	var bd := INF
	for a in artifacts:
		if is_instance_valid(a):
			var d := player.global_position.distance_squared_to(a.global_position)
			if d < bd:
				bd = d
				best = a
	return best

func _demo_steer() -> void:
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var from := player.global_position + Vector3(0, 1.1, 0)
	var space := player.get_world_3d().direct_space_state
	var move := Vector2(0, -1)
	if _demo_ray_blocked(space, from, fwd, 1.6):
		var right := fwd.cross(Vector3.UP)
		if not _demo_ray_blocked(space, from, right, 1.2):
			move = Vector2(1, -0.6)
		elif not _demo_ray_blocked(space, from, -right, 1.2):
			move = Vector2(-1, -0.6)
		else:
			move = Vector2(0, 0.6)
	if player.is_on_floor() and _demo_gap_ahead(space, from, fwd):
		player.do_jump()
	player.set_test_move(move)

func _demo_gap_ahead(space: PhysicsDirectSpaceState3D, from: Vector3, fwd: Vector3) -> bool:
	var ahead := player.global_position + Vector3(0, 0.4, 0) + fwd * 1.4
	var q := PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3(0, -1.8, 0), 0xFFFFFFFF, [player])
	q.collide_with_areas = true
	return space.intersect_ray(q).is_empty()

func _demo_ray_blocked(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, dist: float) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * dist, 0xFFFFFFFF, [player])
	q.collide_with_areas = true
	return not space.intersect_ray(q).is_empty()

func _update_objective() -> void:
	if level_id == 2:
		if exit_open:
			hint = "宝石已集齐！穿过北面巨树间逃出丛林！"
		elif artifacts_collected <= 0:
			hint = "深入原始丛林，寻找散落的 3 颗神秘宝石！小心丛林野兽"
		elif artifacts_collected == 1:
			hint = "宝石 1/%d：还有两颗。巨石阵与溪流尽头各有藏匿" % ARTIFACTS_TOTAL
		else:
			hint = "宝石 2/%d：还差最后一颗，它藏在西北的老树之下" % ARTIFACTS_TOTAL
	elif exit_open:
		hint = "气密闸门已开启！穿过北面通道前往上层甲板！"
	elif artifacts_collected <= 0:
		hint = "搜索工程甲板：西侧高台有电源开关，东侧地面有传感器"
	elif artifacts_collected == 1:
		hint = "核心 1/%d：还有两件。西侧设备间、东侧高台上各有一件" % ARTIFACTS_TOTAL
	else:
		hint = "核心 2/%d：还差最后一件，四处找找" % ARTIFACTS_TOTAL
	if hud:
		hud.set_objective(hint, artifacts_collected, ARTIFACTS_TOTAL, exit_open)

# ---------------- 交互 / 收集 ----------------

func interact() -> bool:
	var s: Node = player.find_interactable()
	if s is RuinSwitch:
		s.activate()
		audio.play("lever", -6.0)
		return true
	return false

func _interact_prompt() -> String:
	if state != "playing" or paused:
		return ""
	var s: Node = player.find_interactable()
	if s is RuinSwitch and s.mode == "lever":
		return "[E] 启动拉杆开关"
	return ""

func _check_pit() -> void:
	if player and player.global_position.y < -2.5:
		damage_player(20.0)
		player.global_position = checkpoint
		player.velocity = Vector3.ZERO
		FX.floating_text(world_root, checkpoint + Vector3(0, 1.5, 0), "坠落受伤 -20", Color(1.0, 0.35, 0.3))
		audio.play("fall", -6.0)
		audio.play("hurt", -6.0)

func _check_artifacts() -> void:
	if not player:
		return
	for a in artifacts.duplicate():
		if not is_instance_valid(a):
			artifacts.erase(a)
			continue
		if player.global_position.distance_to(a.global_position) < 1.5:
			_collect_artifact(a)

func _check_plates() -> void:
	if not player:
		return
	for s in _switches:
		if s.mode == "plate" and not s.activated:
			if player.global_position.distance_to(s.global_position) < 1.6:
				s.activate()

func _check_pickups() -> void:
	if not player:
		return
	var stale := false
	for p in pickups.duplicate():
		if not is_instance_valid(p):
			stale = true
			continue
		if player.global_position.distance_to(p.global_position) < 1.5:
			_collect_pickup(p)
	if stale:
		var keep: Array[Pickup] = []
		for p in pickups:
			if is_instance_valid(p):
				keep.append(p)
		pickups = keep

func _check_exit() -> void:
	if not exit_open or not player:
		return
	if player.global_position.z < -30.5 and absf(player.global_position.x) < 4.5:
		end_game("你成功逃出了空间站！" if level_id == 2 else "你成功抵达了上层甲板！", true)

func _collect_artifact(a: Artifact) -> void:
	artifacts.erase(a)
	artifacts_collected += 1
	score += 100
	FX.floating_text(world_root, a.global_position + Vector3(0, 1.0, 0),
			"宝石 +100" if level_id == 2 else "能源核心 +100", Color(1.0, 0.85, 0.3))
	audio.play("artifact", -6.0)
	_update_objective()
	emit_signal("score_changed", score)
	a.queue_free()
	if artifacts_collected >= ARTIFACTS_TOTAL and not exit_open:
		exit_open = true
		exit_door.open()
		audio.play("door", -6.0)
		FX.floating_text(world_root, Vector3(0, 2.5, -27), "闸门已开启！前往上层！", Color(0.2, 0.9, 0.6))
		_update_objective()

func _collect_pickup(p: Pickup) -> void:
	pickups.erase(p)
	if p.ptype == "ammo":
		player.add_reserve(30)
		FX.floating_text(world_root, p.global_position + Vector3(0, 0.6, 0), "+30 弹药", Color(1.0, 0.85, 0.4))
		audio.play("pickup", -6.0)
	else:
		heal_player(25.0)
		FX.floating_text(world_root, p.global_position + Vector3(0, 0.6, 0), "+25 生命", Color(0.4, 1.0, 0.5))
		audio.play("pickup", -6.0)
	p.queue_free()

func _on_enemy_hit(e: Enemy, lethal: bool) -> void:
	_hitmark_cd = 0.22 if lethal else 0.12
	_last_hit_kill = lethal
	if not lethal:
		audio.play3d("grunt" if level_id == 2 else "hit", world_root, e.global_position, -12.0)
	if is_instance_valid(player):
		player.apply_shake(0.012 if not lethal else 0.025)

func _on_enemy_destroyed(e: Enemy) -> void:
	enemies.erase(e)
	_enemies_defeated += 1
	var pts := 50 if e.kind == Enemy.Kind.BAT else 100
	score += pts
	FX.floating_text(world_root, e.global_position + Vector3(0, 1.4, 0), "+%d" % pts, Color(1.0, 0.9, 0.4))
	FX.impact(world_root, e.global_position + Vector3(0, 1.0, 0), Vector3.UP, Color(0.9, 0.2, 0.2), 20)
	if level_id == 2:
		audio.play3d("beast_dead", world_root, e.global_position, -6.0)
	elif e.kind == Enemy.Kind.BAT:
		audio.play3d("screech", world_root, e.global_position, -12.0)
	else:
		audio.play3d("enemy_dead", world_root, e.global_position, -6.0)
	if is_instance_valid(player):
		player.apply_shake(0.05)
		_slowmo_cd = 0.04
		Engine.time_scale = 0.3
	emit_signal("score_changed", score)
	e.play_death()

func _objective_pos() -> Variant:
	if exit_open:
		return Vector3(0, 0.1, -34)
	var art := _demo_nearest_artifact()
	if art != null:
		return art.global_position
	return null

func _objective_angle() -> float:
	var goal: Variant = _objective_pos()
	if goal == null or not is_instance_valid(player):
		return 0.0
	var gp: Vector3 = goal
	var d := gp - player.global_position
	d.y = 0.0
	if d.length_squared() < 0.01:
		return 0.0
	return wrapf(atan2(-d.x, -d.z) - player._yaw, -PI, PI)

func _objective_distance() -> float:
	var goal: Variant = _objective_pos()
	if goal == null or not is_instance_valid(player):
		return 0.0
	var gp: Vector3 = goal
	var d := gp - player.global_position
	d.y = 0.0
	return d.length()

# ---------------- 生命 ----------------

func damage_player(amount: float) -> void:
	if state != "playing":
		return
	health = maxf(health - amount, 0.0)
	_dmg_flash = 0.5
	audio.play("hurt", -6.0)
	if is_instance_valid(player):
		player.apply_shake(0.04)
		player.apply_punch(randf_range(0.06, 0.12), randf_range(-0.08, 0.08))
	if health <= 0.0:
		end_game("你被空间站安保系统击杀了…")

func heal_player(amount: float) -> void:
	health = minf(health + amount, 100.0)

# ---------------- 存档 ----------------

func _load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return int(cfg.get_value("game", "best", 0))
	return 0

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", best)
	cfg.save(SAVE_PATH)

# ---------------- 测试/调试接口 ----------------

func start_demo() -> void:
	_demo_enabled = true
	_demo_start()

func debug_state() -> Dictionary:
	return {
		"state": state,
		"running": state == "playing",
		"paused": paused,
		"score": score,
		"best": best,
		"health": health,
		"time_left": time_left,
		"artifacts": artifacts_collected,
		"exit_open": exit_open,
		"over_reason": over_reason,
		"hint": hint,
		"weapon": player.weapon_id(),
		"mag": player.mag(),
		"reserve": player.reserve(),
		"reloading": player.reloading,
		"crouching": player.crouching,
		"grounded": player.is_on_floor(),
		"camera_y": player.camera_y(),
		"enemies": enemies.size(),
		"tracers": _count_named("Tracer"),
		"holes": _count_named("BulletHole"),
	}

func _count_named(name: String) -> int:
	var c := 0
	if world_root:
		for n in world_root.get_children():
			if String(n.name).contains(name):
				c += 1
	return c

func set_weapon(i: int) -> void:
	player.set_weapon_index(i)

func set_ammo(mag: int, reserve: int) -> void:
	var w := player.current_weapon()
	w.mag = mag
	w.reserve = reserve

func set_time_left(t: float) -> void:
	_elapsed = ROUND_TIME - t
	time_left = maxf(t, 0.0)

func set_health(h: float) -> void:
	health = clampf(h, 0.0, 100.0)

func set_crouch(v: bool) -> void:
	player.set_crouch(v)

func do_jump() -> void:
	player.do_jump()

func aim_at(pos: Vector3) -> void:
	player.aim_at(pos)

func shoot() -> bool:
	return player.try_fire()

func shoot_at(pos: Vector3) -> bool:
	aim_at(pos)
	return player.try_fire()

func set_player_pos(pos: Vector3) -> void:
	player.global_position = pos
	player.set_test_move(Vector2.ZERO)

func set_move(dir: Vector2) -> void:
	player.set_test_move(dir)

func force_enemy(kind: String, pos: Vector3) -> Enemy:
	var e := Enemy.make(Enemy.Kind.BAT if kind == "bat" else Enemy.Kind.SKELETON, pos, world_root)
	e.hit.connect(_on_enemy_hit)
	e.destroyed.connect(_on_enemy_destroyed)
	enemies.append(e)
	return e

func force_artifact(pos: Vector3) -> Artifact:
	var a := Artifact.new()
	a.setup(pos)
	world_root.add_child(a)
	artifacts.append(a)
	return a

func force_switch(mode: String, pos: Vector3) -> RuinSwitch:
	var s := RuinSwitch.new()
	s.setup(mode, pos)
	s.triggered.connect(_on_switch_triggered)
	world_root.add_child(s)
	_switches.append(s)
	return s

func force_door(pos: Vector3, size: Vector3) -> RuinDoor:
	var d := RuinDoor.new()
	d.setup(pos, size)
	world_root.add_child(d)
	_doors.append(d)
	return d

func clear_enemies() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()

func clear_artifacts() -> void:
	for a in artifacts:
		a.queue_free()
	artifacts.clear()
