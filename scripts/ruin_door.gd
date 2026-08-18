class_name RuinDoor
extends StaticBody3D

var open_state := false
var _base_y := 0.0

func setup(pos: Vector3, size: Vector3, color := Color(0.55, 0.53, 0.48)) -> void:
	_base_y = pos.y
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	add_child(mi)
	var groove := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(size.x + 0.02, 0.08, size.z * 0.6)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.35, 0.33, 0.3)
	groove.mesh = gm
	groove.material_override = gmat
	add_child(groove)
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = size
	col.shape = cs
	add_child(col)
	position = pos
	collision_layer = 1
	collision_mask = 1

func open() -> void:
	if open_state:
		return
	open_state = true
	var tw := create_tween()
	tw.tween_property(self, "position:y", _base_y + 5.5, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: collision_layer = 0)

func close() -> void:
	open_state = false
	position.y = _base_y
	collision_layer = 1
