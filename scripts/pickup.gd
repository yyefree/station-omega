class_name Pickup
extends Area3D

signal collected(p: Pickup)

var ptype := "ammo"
var ttl := 20.0
var _base_y := 0.0
var _t := 0.0

func setup(pos: Vector3, type: String) -> void:
	ptype = type
	_base_y = pos.y
	position = pos

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	if ptype == "ammo":
		box.size = Vector3(0.5, 0.3, 0.4)
	else:
		box.size = Vector3(0.5, 0.35, 0.5)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.2) if ptype == "ammo" else Color(0.9, 0.2, 0.2)
	mat.roughness = 0.4
	mat.metallic = 0.3
	mat.emission_enabled = true
	mat.emission = (Color(1.0, 0.82, 0.2) if ptype == "ammo" else Color(0.9, 0.2, 0.2)) * 0.3
	mesh.material_override = mat
	add_child(mesh)

	if ptype == "med":
		var cross := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.1, 0.4, 0.02)
		cross.mesh = cm
		cross.position = Vector3(0, 0, 0.26)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color.WHITE
		cmat.roughness = 0.5
		cross.material_override = cmat
		add_child(cross)

	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.4, 1.4, 1.4)
	col.shape = sh
	add_child(col)
	collision_layer = 0
	collision_mask = 1
	add_to_group("pickups")

func _physics_process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 2.0
	global_position.y = _base_y + sin(_t * 3.0) * 0.12
	ttl -= delta
	if ttl <= 0.0:
		queue_free()
