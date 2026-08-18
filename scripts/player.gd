class_name Player
extends CharacterBody3D

signal fell_hard(dmg: float)

var scene_root: Node3D
var can_control := false
var reloading := false
var crouching := false
var _yaw := 0.0
var _pitch := 0.0
var _camera: Camera3D
var _gun_origin: Node3D
var _gun_mesh: Node3D

var _weapons: Array[Weapon] = []
var _weapon_idx := 0
var _fire_cd := 0.0
var _reload_cd := 0.0

var _fall_vel := 0.0
var _was_on_floor := true
var _test_move := Vector2.ZERO

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
const EYE_STAND := 0.85
const EYE_CROUCH := 0.6
const SPEED := 7.0
const SPRINT_MULT := 1.55
const JUMP_FORCE := 7.5
const GRAVITY := -18.0
const MOUSE_SENS := 0.002

var _shake_amount := 0.0
var _shake_decay := 5.0
var _shake_offset := Vector3.ZERO
var _punch_pitch := 0.0
var _punch_roll := 0.0
var _punch_decay := 8.0

var _sway := Vector2.ZERO
var _bob_t := 0.0
var _bob_offset := Vector3.ZERO
var _gun_rest_pos := Vector3(0.08, -0.08, -0.25)
var _gun_kick := Vector3.ZERO

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = STAND_HEIGHT
	var col := CollisionShape3D.new()
	col.shape = cap
	col.name = "BodyCol"
	add_child(col)
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.position = Vector3(0, EYE_STAND, 0)
	add_child(_camera)
	_gun_origin = Node3D.new()
	_gun_origin.name = "GunOrigin"
	_camera.add_child(_gun_origin)
	_gun_origin.position = _gun_rest_pos
	_weapons.append(Weapon.new({"id":"revolver","display":"左轮","fire_rate":0.32,"mag_size":6,"reserve_size":0,"spread":0.008,"pellets":1,"damage":35.0,"recoil":0.15,"automatic":false}))
	_weapons.append(Weapon.new({"id":"rifle","display":"步枪","fire_rate":0.1,"mag_size":30,"reserve_size":120,"spread":0.018,"pellets":1,"damage":20.0,"recoil":0.07,"automatic":true}))
	_weapons.append(Weapon.new({"id":"shotgun","display":"霰弹枪","fire_rate":0.65,"mag_size":8,"reserve_size":32,"spread":0.06,"pellets":8,"damage":10.0,"recoil":0.25,"automatic":false}))
	_rebuild_gun()

func _physics_process(delta: float) -> void:
	if not can_control:
		velocity = Vector3.ZERO
		move_and_slide()
		_update_camera(delta)
		return
	var input := Vector2.ZERO
	if _test_move != Vector2.ZERO:
		input = _test_move
	else:
		input.x = Input.get_axis("move_left", "move_right")
		input.y = Input.get_axis("move_forward", "move_back")
		input = input.normalized()
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var wish := (forward * -input.y + right * input.x) * SPEED
	if Input.is_action_pressed("sprint") and not crouching:
		wish *= SPRINT_MULT
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y <= 0.0:
		velocity.y = -1.0
	velocity.x = wish.x
	velocity.z = wish.z
	move_and_slide()
	if not _was_on_floor and is_on_floor():
		var impact := absf(_fall_vel)
		if impact > 8.0:
			var dmg := clampf((impact - 8.0) * 0.8, 0.0, 15.0)
			emit_signal("fell_hard", dmg)
	_fall_vel = velocity.y if not is_on_floor() else 0.0
	_was_on_floor = is_on_floor()
	if Input.is_action_just_pressed("jump") and is_on_floor() and not crouching:
		do_jump()
	if Input.is_action_just_pressed("crouch"):
		set_crouch(not crouching)
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_reload_cd = maxf(_reload_cd - delta, 0.0)
	if reloading and _reload_cd <= 0.0:
		_finish_reload()
	var w := current_weapon()
	if can_control and Input.is_action_pressed("fire") and _fire_cd <= 0.0 and not reloading:
		try_fire()
	if can_control and Input.is_action_just_pressed("reload"):
		_start_reload()
	if Input.is_action_just_pressed("weapon_1"):
		set_weapon_index(0)
	elif Input.is_action_just_pressed("weapon_2"):
		set_weapon_index(1)
	elif Input.is_action_just_pressed("weapon_3"):
		set_weapon_index(2)
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	var target_eye := EYE_STAND
	if crouching:
		target_eye = EYE_CROUCH
	_camera.position.y = target_eye
	_camera.rotation.x = _pitch + _punch_pitch
	_camera.rotation.z = _punch_roll
	_punch_pitch = move_toward(_punch_pitch, 0.0, _punch_decay * delta)
	_punch_roll = move_toward(_punch_roll, 0.0, _punch_decay * delta)
	if _shake_amount > 0.001:
		_shake_offset = Vector3(randf_range(-1,1)*_shake_amount, randf_range(-1,1)*_shake_amount, randf_range(-1,1)*_shake_amount*0.3)
		_shake_amount = move_toward(_shake_amount, 0.0, _shake_decay * delta)
	else:
		_shake_offset = Vector3.ZERO
		_shake_amount = 0.0
	_camera.position += _shake_offset
	var speed := Vector2(velocity.x, velocity.z).length()
	var bob_spd := clampf(speed / 5.0, 0.0, 1.0)
	if is_on_floor() and speed > 1.0:
		_bob_t += speed * delta * 1.8
		_bob_offset = Vector3(sin(_bob_t)*0.004*bob_spd, absf(cos(_bob_t))*0.003*bob_spd, 0)
	else:
		_bob_t = 0.0
		_bob_offset = _bob_offset.lerp(Vector3.ZERO, 6.0 * delta)
	var target_sway := Vector2.ZERO
	if can_control:
		target_sway.x = Input.get_axis("move_left", "move_right") * 0.008
		target_sway.y = Input.get_axis("move_forward", "move_back") * 0.006
	_sway = _sway.lerp(target_sway, 5.0 * delta)
	_gun_origin.position = _gun_rest_pos + Vector3(_sway.x, _sway.y, 0) + _bob_offset
	_gun_kick = _gun_kick.lerp(Vector3.ZERO, 12.0 * delta)
	_gun_origin.position += _gun_kick
	_gun_origin.position += _shake_offset

func _unhandled_input(event: InputEvent) -> void:
	if not can_control:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw -= motion.relative.x * MOUSE_SENS
			_pitch -= motion.relative.y * MOUSE_SENS
			_pitch = clampf(_pitch, -PI * 0.48, PI * 0.48)
			rotation.y = _yaw
			_camera.rotation.x = _pitch

func do_jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_FORCE

func set_crouch(v: bool) -> void:
	crouching = v
	var col: CollisionShape3D = get_node_or_null("BodyCol")
	if col and col.shape is CapsuleShape3D:
		var cs: CapsuleShape3D = col.shape
		if crouching:
			cs.height = CROUCH_HEIGHT
		else:
			cs.height = STAND_HEIGHT

func current_weapon() -> Weapon:
	return _weapons[_weapon_idx]

func weapon_id() -> String:
	return current_weapon().id

func mag() -> int:
	return current_weapon().mag

func reserve() -> int:
	return current_weapon().reserve

func add_reserve(amt: int) -> void:
	var w := current_weapon()
	w.reserve = w.reserve + amt

func set_weapon_index(i: int) -> void:
	if i < 0 or i >= _weapons.size() or i == _weapon_idx:
		return
	_weapon_idx = i
	_fire_cd = 0.2
	reloading = false
	_rebuild_gun()

func try_fire() -> bool:
	var w := current_weapon()
	if _fire_cd > 0.0 or reloading:
		return false
	if w.mag <= 0:
		_start_reload()
		return false
	w.mag -= 1
	_fire_cd = w.fire_rate
	_apply_recoil(w)
	_do_ray(w)
	_gun_kick = Vector3(0, 0.015, 0.03)
	_rebuild_gun()
	return true

func _apply_recoil(w: Weapon) -> void:
	_pitch += w.recoil * randf_range(0.8, 1.2)
	_punch_roll += w.recoil * randf_range(-0.3, 0.3) * 0.5
	shake(w.recoil * 0.4)

func _start_reload() -> void:
	var w := current_weapon()
	if reloading or w.mag >= w.mag_size or w.reserve <= 0:
		return
	reloading = true
	_reload_cd = 1.2

func _finish_reload() -> void:
	reloading = false
	var w := current_weapon()
	var need := w.mag_size - w.mag
	var take := mini(need, w.reserve)
	w.mag += take
	w.reserve -= take

func _do_ray(w: Weapon) -> void:
	if not scene_root or not _camera:
		return
	_camera.force_update_transform()
	var muzzle_pos := _gun_origin.global_position - _camera.global_transform.basis.z * 0.65
	FX.muzzle_flash(scene_root, muzzle_pos, -_camera.global_transform.basis.z)
	for p_idx in w.pellets:
		var spread := w.spread
		var dir := -_camera.global_transform.basis.z
		dir += _camera.global_transform.basis.x * randf_range(-spread, spread)
		dir += _camera.global_transform.basis.y * randf_range(-spread, spread)
		dir = dir.normalized()
		var from := _camera.global_position
		var to := from + dir * 200.0
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF)
		q.collide_with_areas = true
		var hit := space.intersect_ray(q)
		if hit:
			var collider: Node3D = hit["collider"]
			var hit_pos: Vector3 = hit["position"]
			var hit_normal: Vector3 = hit["normal"]
			FX.tracer(scene_root, from, hit_pos)
			if collider.has_method("apply_damage"):
				var back_dir := (global_position - collider.global_position).normalized()
				back_dir.y = 0.0
				collider.apply_damage(w.damage, back_dir)
			else:
				FX.bullet_hole(scene_root, hit_pos, hit_normal)
		else:
			FX.tracer(scene_root, from, to)

func shake(amount: float) -> void:
	_shake_amount = maxf(_shake_amount, amount)

func apply_shake(amount: float) -> void:
	shake(amount)

func apply_punch(pitch_amt: float, roll_amt: float) -> void:
	_punch_pitch += pitch_amt
	_punch_roll += roll_amt

func aim_at(pos: Vector3) -> void:
	var dir := pos - global_position - Vector3(0, EYE_STAND if not crouching else EYE_CROUCH, 0)
	if dir.length_squared() < 0.001:
		return
	_pitch = asin(clampf(dir.normalized().y, -1.0, 1.0))
	_pitch = clampf(_pitch, -PI * 0.48, PI * 0.48)
	var flat := Vector2(dir.x, dir.z)
	_yaw = atan2(-flat.x, -flat.y)
	rotation.y = _yaw
	_camera.rotation.x = _pitch

func set_test_move(dir: Vector2) -> void:
	_test_move = dir

func find_interactable() -> Node:
	if not scene_root:
		return null
	var gm: Node = get_tree().get_first_node_in_group("game_main")
	if not gm:
		return null
	var switches = gm._switches
	if not switches:
		return null
	for s in switches:
		if is_instance_valid(s) and s.mode == "lever" and not s.activated:
			if global_position.distance_to(s.global_position) < 3.5:
				return s
	return null

func reset_for_round() -> void:
	for w in _weapons:
		w.mag = w.mag_size
		if w.reserve_size > 0:
			w.reserve = w.reserve_size
	_weapon_idx = 0
	_fire_cd = 0.0
	_reload_cd = 0.0
	reloading = false
	crouching = false
	_yaw = 0.0
	_pitch = 0.0
	_shake_amount = 0.0
	_punch_pitch = 0.0
	_punch_roll = 0.0
	_fall_vel = 0.0
	_was_on_floor = true
	_test_move = Vector2.ZERO
	rotation = Vector3.ZERO
	set_crouch(false)
	_rebuild_gun()

func camera_y() -> float:
	if _camera:
		return _camera.global_position.y
	return global_position.y + EYE_STAND

# ---------------- Gun Model ----------------

func _rebuild_gun() -> void:
	if _gun_mesh:
		_gun_mesh.queue_free()
		_gun_mesh = null
	var holder := Node3D.new()
	holder.name = "GunModel"
	var w := current_weapon()
	match w.id:
		"revolver":
			_part(holder, Vector3(0.08, 0.11, 0.18), Vector3(0, 0.03, -0.06), "gunmetal", 3.0, 0.22, 0.92, Color(0.18, 0.2, 0.28))
			_cyl_part(holder, 0.028, 0.032, 0.16, Vector3(0, 0.02, -0.24), "gunmetal", 3.0, 0.18, 0.95, Color(0.2, 0.22, 0.3))
			_cyl_part(holder, 0.034, 0.038, 0.12, Vector3(0, 0.0, -0.14), "steel", 3.0, 0.35, 0.95, Color(0.3, 0.3, 0.34))
			_part(holder, Vector3(0.05, 0.055, 0.09), Vector3(0, -0.02, 0.03), "knurl", 3.0, 0.65, 0.05, Color(0.22, 0.18, 0.12))
			_part(holder, Vector3(0.05, 0.13, 0.09), Vector3(0, -0.12, 0.07), "knurl", 3.0, 0.68, 0.05, Color(0.2, 0.16, 0.1))
			_part(holder, Vector3(0.05, 0.03, 0.05), Vector3(0, -0.18, 0.07), "steel", 3.0, 0.35, 0.9, Color(0.28, 0.29, 0.33))
			_part(holder, Vector3(0.02, 0.06, 0.04), Vector3(0.035, -0.02, -0.22), "gunmetal", 3.0, 0.25, 0.9, Color(0.22, 0.24, 0.32))
			_part(holder, Vector3(0.015, 0.02, 0.015), Vector3(0, 0.09, -0.34), "steel", 4.0, 0.15, 0.95, Color(0.35, 0.35, 0.4))
			_part(holder, Vector3(0.04, 0.008, 0.06), Vector3(0, 0.08, -0.31), "steel", 4.0, 0.12, 0.95, Color(0.25, 0.25, 0.3))
			_cyl_part(holder, 0.015, 0.015, 0.06, Vector3(0, 0.07, -0.12), "steel", 3.0, 0.28, 0.9, Color(0.26, 0.26, 0.3))
			_glow_dot(holder, Vector3(0, 0.055, -0.24), Color(0.4, 1.0, 0.5))
		"rifle":
			_part(holder, Vector3(0.075, 0.1, 0.34), Vector3(0, -0.02, -0.05), "carbon", 2.0, 0.5, 0.1, Color(0.11, 0.12, 0.13))
			_cyl_part(holder, 0.016, 0.018, 0.38, Vector3(0, 0.01, -0.36), "gunmetal", 4.0, 0.18, 0.95, Color(0.15, 0.17, 0.22))
			_cyl_part(holder, 0.024, 0.024, 0.06, Vector3(0, 0.01, -0.58), "gunmetal", 4.0, 0.18, 0.95, Color(0.18, 0.2, 0.26))
			_part(holder, Vector3(0.07, 0.075, 0.22), Vector3(0, -0.02, -0.26), "carbon", 2.0, 0.55, 0.1, Color(0.12, 0.13, 0.14))
			_part(holder, Vector3(0.06, 0.13, 0.26), Vector3(0, -0.03, 0.24), "carbon", 2.0, 0.55, 0.1, Color(0.11, 0.12, 0.13))
			_part(holder, Vector3(0.05, 0.11, 0.07), Vector3(0, -0.1, 0.06), "knurl", 3.0, 0.65, 0.05, Color(0.16, 0.13, 0.09))
			_part(holder, Vector3(0.05, 0.17, 0.06), Vector3(0, -0.13, -0.03), "steel", 3.0, 0.35, 0.9, Color(0.22, 0.23, 0.27))
			_part(holder, Vector3(0.025, 0.04, 0.12), Vector3(0.042, 0.03, -0.18), "gunmetal", 3.0, 0.22, 0.92, Color(0.16, 0.18, 0.24))
			_part(holder, Vector3(0.015, 0.02, 0.015), Vector3(0, 0.07, -0.58), "steel", 4.0, 0.15, 0.95, Color(0.35, 0.35, 0.4))
			_part(holder, Vector3(0.04, 0.008, 0.08), Vector3(0, 0.06, -0.53), "steel", 4.0, 0.12, 0.95, Color(0.25, 0.25, 0.3))
			_cyl_part(holder, 0.02, 0.02, 0.08, Vector3(-0.035, 0.03, -0.16), "steel", 3.0, 0.3, 0.9, Color(0.25, 0.25, 0.28))
			_glow_dot(holder, Vector3(0, 0.05, -0.02), Color(1.0, 0.2, 0.15))
		"shotgun":
			_cyl_part(holder, 0.022, 0.024, 0.42, Vector3(0.012, 0.025, -0.40), "gunmetal", 3.0, 0.2, 0.95, Color(0.22, 0.24, 0.3))
			_cyl_part(holder, 0.022, 0.024, 0.42, Vector3(-0.012, 0.025, -0.40), "steel", 4.0, 0.18, 0.95, Color(0.3, 0.3, 0.35))
			_part(holder, Vector3(0.08, 0.11, 0.22), Vector3(0, 0.0, -0.08), "gunmetal", 3.0, 0.28, 0.92, Color(0.25, 0.27, 0.34))
			_part(holder, Vector3(0.075, 0.1, 0.17), Vector3(0, 0.02, -0.22), "wood", 2.0, 0.55, 0.0, Color(0.4, 0.28, 0.15))
			_part(holder, Vector3(0.07, 0.12, 0.26), Vector3(0, -0.04, 0.2), "wood", 2.0, 0.5, 0.0, Color(0.42, 0.3, 0.16))
			_part(holder, Vector3(0.07, 0.06, 0.1), Vector3(0, -0.02, -0.16), "steel", 3.0, 0.35, 0.9, Color(0.38, 0.38, 0.42))
			_part(holder, Vector3(0.015, 0.025, 0.015), Vector3(0, 0.08, -0.62), "steel", 4.0, 0.15, 0.95, Color(0.35, 0.35, 0.4))
			_part(holder, Vector3(0.05, 0.008, 0.04), Vector3(0, 0.07, -0.48), "steel", 4.0, 0.12, 0.95, Color(0.25, 0.25, 0.3))
			_cyl_part(holder, 0.012, 0.012, 0.04, Vector3(0.035, -0.01, 0.08), "steel", 3.0, 0.3, 0.9, Color(0.26, 0.26, 0.3))
			_glow_dot(holder, Vector3(0, 0.06, -0.18), Color(0.4, 1.0, 0.5))
	_gun_origin.add_child(holder)
	_gun_mesh = holder

func _part(parent: Node3D, sz: Vector3, pos: Vector3, kind: String, sc: float, rough: float, metal: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	bm.material = TexGen.mat(color, kind, sc, rough, metal, false)
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
	return mi

func _cyl_part(parent: Node3D, top_r: float, bot_r: float, h: float, pos: Vector3, kind: String, sc: float, rough: float, metal: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = 12
	cm.material = TexGen.mat(color, kind, sc, rough, metal, false)
	mi.mesh = cm
	mi.position = pos
	parent.add_child(mi)
	return mi

func _glow_dot(parent: Node3D, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.006
	sp.height = 0.012
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	sp.material = mat
	mi.mesh = sp
	mi.position = pos
	parent.add_child(mi)
	return mi
