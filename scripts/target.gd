class_name Target
extends Area3D

signal hit(t: Target)
signal destroyed(t: Target)

enum Pattern { HOVER, ORBIT, SWEEP, APPROACH }

var color_type := "red"
var pattern := Pattern.HOVER
var slot := -1
var health := 1.0
var dead := false
var speed_mult := 1.0
var home := Vector3.ZERO
var center := Vector3.ZERO
var orbit_radius := 3.5
var sweep_range := 6.0
var _t := 0.0
var _phase := 0.0

func setup(main: Node, slot_i: int, base_pos: Vector3, ctype: String, tier_i: int) -> void:
	slot = slot_i
	color_type = ctype
	home = base_pos
	center = base_pos
	speed_mult = 1.0 + (tier_i - 1) * 0.22
	_phase = randf() * TAU
	health = 1.0
	var cfg: Dictionary = main.TARGET_TYPES[ctype]
	var mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55
	sm.height = 1.1
	mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cfg.color
	mat.roughness = 0.55
	mat.emission_enabled = true
	mat.emission = cfg.color * 0.35
	mesh.material_override = mat
	add_child(mesh)
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.7
	col.shape = sh
	add_child(col)
	collision_layer = 2
	collision_mask = 0
	monitorable = true
	monitoring = false
	add_to_group("targets")

func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta * speed_mult
	_apply_pattern_position(_t)

func _apply_pattern_position(t: float) -> void:
	match pattern:
		Pattern.HOVER:
			global_position = home + Vector3(0.0, sin(t * 2.0 + _phase) * 1.2, 0.0)
		Pattern.ORBIT:
			var a := t * 0.8 + _phase
			global_position = center + Vector3(
				cos(a) * orbit_radius,
				sin(t * 1.6 + _phase) * 0.8,
				sin(a) * orbit_radius
			)
		Pattern.SWEEP:
			global_position = center + Vector3(
				sin(t * 1.4 + _phase) * sweep_range,
				sin(t * 2.2 + _phase) * 0.6,
				0.0
			)
		Pattern.APPROACH:
			var wob := pow(absf(sin(t * 0.6 + _phase)), 1.5)
			global_position = Vector3(
				center.x + sin(t * 1.8 + _phase) * 2.0,
				center.y + sin(t * 3.0) * 0.5,
				center.z - 26.0 * wob
			)

func apply_damage(dmg: float) -> void:
	if dead:
		return
	health -= dmg
	emit_signal("hit", self)
	if health <= 0.0:
		dead = true
		emit_signal("destroyed", self)

func despawn() -> void:
	dead = true
	queue_free()
