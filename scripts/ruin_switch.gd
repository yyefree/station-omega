class_name RuinSwitch
extends Node3D

signal triggered(s: RuinSwitch)

var mode := "lever" # lever | plate
var doors: Array[Node] = []
var activated := false
var _arm: Node3D

func setup(mode: String, pos: Vector3) -> void:
	self.mode = mode
	if mode == "lever":
		_build_lever()
	else:
		_build_plate()
	position = pos

func _build_lever() -> void:
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.5
	cm.height = 0.5
	cm.radial_segments = 10
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.5, 0.48, 0.42)
	bmat.roughness = 0.8
	base.mesh = cm
	base.material_override = bmat
	base.position = Vector3(0, 0.25, 0)
	add_child(base)

	_arm = Node3D.new()
	var arm_mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.12, 0.9)
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.35, 0.25, 0.15)
	amat.roughness = 0.6
	arm_mesh.mesh = bm
	arm_mesh.material_override = amat
	arm_mesh.position = Vector3(0, 0, 0.45)
	_arm.add_child(arm_mesh)
	var ball := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.12
	sp.height = 0.24
	var ymat := StandardMaterial3D.new()
	ymat.albedo_color = Color(0.85, 0.6, 0.15)
	ymat.roughness = 0.3
	ymat.emission_enabled = true
	ymat.emission = Color(0.9, 0.5, 0.1) * 0.5
	ball.mesh = sp
	ball.material_override = ymat
	ball.position = Vector3(0, 0, 0.9)
	_arm.add_child(ball)
	_arm.position = Vector3(0, 0.5, 0)
	add_child(_arm)

	var area := Area3D.new()
	area.name = "InteractArea"
	area.collision_layer = 2
	area.collision_mask = 0
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(1.0, 1.4, 1.4)
	col.shape = cs
	area.add_child(col)
	add_child(area)
	area.add_to_group("interactable")

func _build_plate() -> void:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 0.14, 1.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.43, 0.38)
	mat.roughness = 0.7
	mesh.mesh = bm
	mesh.material_override = mat
	mesh.position = Vector3(0, 0.07, 0)
	add_child(mesh)
	_arm = MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(1.0, 0.03, 1.0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.85, 0.6, 0.15)
	rmat.emission_enabled = true
	rmat.emission = Color(0.9, 0.5, 0.1) * 0.5
	_arm.mesh = rm
	_arm.material_override = rmat
	_arm.position = Vector3(0, 0.16, 0)
	add_child(_arm)

func activate() -> void:
	if activated:
		return
	activated = true
	if mode == "lever" and _arm:
		var tw := create_tween()
		tw.tween_property(_arm, "rotation:x", -1.2, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif mode == "plate" and _arm:
		var tw := create_tween()
		tw.tween_property(_arm, "position:y", 0.04, 0.2)
	for d in doors:
		if d and d.has_method("open"):
			d.open()
	emit_signal("triggered", self)

func reset() -> void:
	activated = false
	if _arm:
		_arm.rotation = Vector3.ZERO
		if mode == "plate":
			_arm.position = Vector3(0, 0.16, 0)
