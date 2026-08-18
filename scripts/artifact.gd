class_name Artifact
extends Node3D

var _orb: MeshInstance3D
var _t := 0.0

func setup(pos: Vector3) -> void:
	var ped := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.55
	cm.height = 0.7
	cm.radial_segments = 10
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.6, 0.58, 0.5)
	pmat.roughness = 0.85
	ped.mesh = cm
	ped.material_override = pmat
	ped.position = Vector3(0, -0.35, 0)
	add_child(ped)

	_orb = MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.22
	sp.height = 0.44
	sp.radial_segments = 14
	var omat := StandardMaterial3D.new()
	omat.albedo_color = Color(1.0, 0.8, 0.25)
	omat.roughness = 0.3
	omat.emission_enabled = true
	omat.emission = Color(1.0, 0.75, 0.2)
	omat.emission_energy_multiplier = 1.8
	_orb.mesh = sp
	_orb.material_override = omat
	_orb.position = Vector3(0, 0.35, 0)
	add_child(_orb)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.3)
	light.light_energy = 2.4
	light.omni_range = 5.0
	light.position = Vector3(0, 0.8, 0)
	add_child(light)

	position = pos

func _physics_process(delta: float) -> void:
	_t += delta
	if _orb:
		_orb.rotation.y += delta * 2.2
		_orb.position.y = 0.35 + sin(_t * 2.0) * 0.06
