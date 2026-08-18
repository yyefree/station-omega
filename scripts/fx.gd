class_name FX
extends RefCounted

static var _seq := 0

static func _uniq_name(base: String) -> String:
	_seq += 1
	return "%s%d" % [base, _seq]

# 命中曳光：一条短暂的发光线段
static func tracer(scene_root: Node3D, from: Vector3, to: Vector3, color := Color(1.0, 0.85, 0.4), ttl := 0.06) -> void:
	var line := MeshInstance3D.new()
	line.name = _uniq_name("Tracer")
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	line.mesh = mesh
	line.material_override = mat
	scene_root.add_child(line)
	var timer := scene_root.get_tree().create_timer(ttl)
	timer.timeout.connect(line.queue_free)

# 弹孔残迹：贴在命中面上的小圆片
static func bullet_hole(scene_root: Node3D, point: Vector3, normal: Vector3, ttl := 8.0) -> void:
	var hole := MeshInstance3D.new()
	hole.name = _uniq_name("BulletHole")
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	cyl.height = 0.01
	cyl.radial_segments = 10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.04, 0.05)
	mat.roughness = 1.0
	hole.mesh = cyl
	hole.material_override = mat
	var pos := point + normal * 0.008
	scene_root.add_child(hole)
	hole.global_position = pos
	var up := Vector3.UP
	if absf(normal.dot(up)) > 0.99:
		up = Vector3.FORWARD
	hole.look_at(pos + normal, up)
	var timer := scene_root.get_tree().create_timer(ttl)
	timer.timeout.connect(hole.queue_free)

# 命中火花粒子（GPUParticles3D 一次性爆发）
static func impact(scene_root: Node3D, point: Vector3, normal: Vector3, color := Color(1.0, 0.9, 0.5), count := 12) -> void:
	var gpu := GPUParticles3D.new()
	gpu.name = _uniq_name("Impact")
	gpu.one_shot = true
	gpu.emitting = true
	gpu.amount = count
	gpu.lifetime = 0.5
	gpu.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = normal
	pm.spread = 60.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.02
	pm.scale_max = 0.05
	gpu.process_material = pm
	var emat := StandardMaterial3D.new()
	emat.albedo_color = color
	emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emat.emission_enabled = true
	emat.emission = color
	emat.emission_energy_multiplier = 4.0
	gpu.material_override = emat
	scene_root.add_child(gpu)
	gpu.global_position = point + normal * 0.02
	var timer := scene_root.get_tree().create_timer(1.2)
	timer.timeout.connect(gpu.queue_free)

# 世界空间浮动得分文字
static func floating_text(scene_root: Node3D, world_pos: Vector3, text: String, color := Color.WHITE) -> void:
	var lbl := Label3D.new()
	lbl.name = _uniq_name("FloatText")
	lbl.text = text
	lbl.font_size = 72
	lbl.pixel_size = 0.0025
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0, 0, 0, 0.8)
	lbl.modulate = color
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	scene_root.add_child(lbl)
	lbl.global_position = world_pos
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", world_pos.y + 1.6, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.15)
	tw.chain().tween_callback(lbl.queue_free)

static func add_dust_motes(scene_root: Node3D, center: Vector3, radius := 20.0) -> void:
	var gpu := GPUParticles3D.new()
	gpu.name = "DustMotes"
	gpu.amount = 60
	gpu.lifetime = 6.0
	gpu.explosiveness = 0.0
	gpu.visibility_aabb = AABB(center - Vector3(radius, 4, radius), Vector3(radius * 2, 8, radius * 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3(0, 0.2, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.15
	pm.gravity = Vector3(0, 0.03, 0)
	pm.scale_min = 0.008
	pm.scale_max = 0.025
	pm.color = Color(1.0, 0.95, 0.8, 0.35)
	gpu.process_material = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gpu.material_override = mat
	scene_root.add_child(gpu)
	gpu.global_position = center

static func add_fireflies(scene_root: Node3D, center: Vector3, radius := 15.0, count := 25) -> void:
	var gpu := GPUParticles3D.new()
	gpu.name = "Fireflies"
	gpu.amount = count
	gpu.lifetime = 5.0
	gpu.explosiveness = 0.0
	gpu.visibility_aabb = AABB(center - Vector3(radius, 4, radius), Vector3(radius * 2, 8, radius * 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3(0, 0.3, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3(0, 0.1, 0)
	pm.scale_min = 0.012
	pm.scale_max = 0.025
	pm.color = Color(0.7, 1.0, 0.3, 0.9)
	gpu.process_material = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 1.0, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.7, 1.0, 0.3)
	mat.emission_energy_multiplier = 3.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gpu.material_override = mat
	scene_root.add_child(gpu)
	gpu.global_position = center

static func add_torch_embers(scene_root: Node3D, pos: Vector3, count := 8) -> void:
	var gpu := GPUParticles3D.new()
	gpu.name = "Embers"
	gpu.amount = count
	gpu.lifetime = 1.5
	gpu.one_shot = false
	gpu.emitting = true
	gpu.explosiveness = 0.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0, 0.8, 0)
	pm.scale_min = 0.008
	pm.scale_max = 0.018
	pm.color = Color(1.0, 0.6, 0.15, 0.8)
	gpu.process_material = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.15)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	mat.emission_energy_multiplier = 4.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gpu.material_override = mat
	scene_root.add_child(gpu)
	gpu.global_position = pos

static func muzzle_flash(scene_root: Node3D, pos: Vector3, forward: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = _uniq_name("MuzzleFlash")
	var sp := SphereMesh.new()
	sp.radius = 0.035
	sp.height = 0.07
	sp.radial_segments = 8
	sp.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.3)
	mat.emission_energy_multiplier = 12.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sp.material = mat
	mi.mesh = sp
	mi.position = pos + forward * 0.04
	scene_root.add_child(mi)
	var flash_light := OmniLight3D.new()
	flash_light.position = pos + forward * 0.05
	flash_light.light_color = Color(1.0, 0.85, 0.45)
	flash_light.light_energy = 4.0
	flash_light.omni_range = 5.0
	flash_light.omni_attenuation = 2.5
	scene_root.add_child(flash_light)
	var tw := scene_root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ZERO, 0.06).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.06)
	tw.tween_property(flash_light, "light_energy", 0.0, 0.08)
	tw.chain().tween_callback(mi.queue_free)
	tw.chain().tween_callback(flash_light.queue_free)
