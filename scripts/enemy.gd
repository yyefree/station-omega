class_name Enemy
extends CharacterBody3D

signal hit(e: Enemy, lethal: bool)
signal destroyed(e: Enemy)

enum Kind { BAT, SKELETON }

var kind := Kind.BAT
var variant := 0
var max_health := 40.0
var health := 40.0
var dead := false
var speed := 3.4
var touch_damage := 8.0
var home := Vector3.ZERO
var phase := 0.0

var _t := 0.0
var _touch_cd := 0.0
var _kb := Vector3.ZERO
var _flash := 0.0
var _dying := false
var _freeze_cd := 0.0
var _skin_mats: Array[StandardMaterial3D] = []
var _orig_emit: Array[Color] = []
var _orig_ee: Array[float] = []
var _orig_emitted: Array[bool] = []

const HIT_COLOR := Color(1.0, 0.35, 0.25)

static func make(kind: Kind, home: Vector3, scene_root: Node3D, variant := 0) -> Enemy:
	var e := Enemy.new()
	e.kind = kind
	e.variant = variant
	e.home = home
	e.phase = randf() * TAU
	match kind:
		Kind.BAT:
			e.max_health = 40.0
			e.health = 40.0
			e.speed = 3.4
			e.touch_damage = 8.0
		Kind.SKELETON:
			e.max_health = 60.0
			e.health = 60.0
			e.speed = 2.4
			e.touch_damage = 12.0
	e._build_body()
	scene_root.add_child(e)
	e.global_position = home
	return e

func _build_body() -> void:
	collision_layer = 2
	collision_mask = 1
	var jungle := variant == 1
	match kind:
		Kind.BAT:
			var m := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.28
			sp.height = 0.5
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.24, 0.1, 0.3) if not jungle else Color(0.12, 0.34, 0.14)
			mat.roughness = 0.5
			mat.emission_enabled = true
			mat.emission = Color(0.55, 0.15, 0.7) if not jungle else Color(0.95, 0.65, 0.2)
			mat.emission_energy_multiplier = 1.5
			m.mesh = sp
			m.material_override = mat
			m.position = Vector3(0, 0.2, 0)
			add_child(m)
			_reg_skin(mat)
			var col := CollisionShape3D.new()
			var cs := SphereShape3D.new()
			cs.radius = 0.55
			col.shape = cs
			col.position = Vector3(0, 0.2, 0)
			add_child(col)
		Kind.SKELETON:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.9, 0.88, 0.8) if not jungle else Color(0.35, 0.26, 0.17)
			mat.roughness = 0.6
			var torso := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.3
			cm.bottom_radius = 0.3
			cm.height = 1.2
			torso.mesh = cm
			torso.material_override = mat
			torso.position = Vector3(0, 0.85, 0)
			add_child(torso)
			var head := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.28
			sp.height = 0.56
			head.mesh = sp
			head.material_override = mat
			head.position = Vector3(0, 1.75, 0)
			add_child(head)
			_reg_skin(mat)
			var eye := MeshInstance3D.new()
			var esp := SphereMesh.new()
			esp.radius = 0.05
			esp.height = 0.1
			var emat := StandardMaterial3D.new()
			emat.albedo_color = Color(1.0, 0.15, 0.1) if not jungle else Color(1.0, 0.6, 0.12)
			emat.emission_enabled = true
			emat.emission = Color(1.0, 0.1, 0.05) if not jungle else Color(1.0, 0.55, 0.1)
			emat.emission_energy_multiplier = 3.0
			eye.mesh = esp
			eye.material_override = emat
			eye.position = Vector3(0, 1.75, 0.26)
			add_child(eye)
			_reg_skin(emat)
			var col := CollisionShape3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = 0.42
			cap.height = 1.8
			col.shape = cap
			col.position = Vector3(0, 0.9, 0)
			add_child(col)

func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	_touch_cd = maxf(_touch_cd - delta, 0.0)
	if _freeze_cd > 0.0:
		_freeze_cd = maxf(_freeze_cd - delta, 0.0)
		if _flash > 0.0:
			_flash = maxf(_flash - delta, 0.0)
			var t := clampf(_flash / 0.35, 0.0, 1.0)
			for i in _skin_mats.size():
				var m := _skin_mats[i]
				m.emission_enabled = true
				m.emission = _orig_emit[i].lerp(HIT_COLOR, t)
				m.emission_energy_multiplier = lerpf(_orig_ee[i], 5.0, t)
		return
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		var t := clampf(_flash / 0.35, 0.0, 1.0)
		for i in _skin_mats.size():
			var m := _skin_mats[i]
			m.emission_enabled = true
			m.emission = _orig_emit[i].lerp(HIT_COLOR, t)
			m.emission_energy_multiplier = lerpf(_orig_ee[i], 4.0, t)
		if _flash <= 0.0:
			for i in _skin_mats.size():
				var m := _skin_mats[i]
				m.emission = _orig_emit[i]
				m.emission_energy_multiplier = _orig_ee[i]
				m.emission_enabled = _orig_emitted[i]
	var gm := get_tree().get_first_node_in_group("game_main")
	var player: Node3D = null
	if gm and gm.player:
		player = gm.player
	var dist := INF
	if player:
		dist = global_position.distance_to(player.global_position)
	match kind:
		Kind.BAT:
			var target := home + Vector3(
				sin(_t * 0.9 + phase) * 1.2,
				sin(_t * 1.4 + phase) * 0.8,
				cos(_t * 0.7 + phase) * 1.2
			)
			if player and dist < 14.0:
				target = player.global_position + Vector3(0, 2.0, 0)
			global_position = global_position.move_toward(target, speed * delta)
			if _kb != Vector3.ZERO:
				global_position += _kb * delta
				_kb = _kb.move_toward(Vector3.ZERO, 10.0 * delta)
		Kind.SKELETON:
			var mv := Vector3(sin(_t * 0.5 + phase) * 0.9, 0.0, cos(_t * 0.5 + phase) * 0.9)
			if player and dist < 12.0:
				var d := player.global_position - global_position
				d.y = 0.0
				mv = d.normalized() * speed
			velocity.x = mv.x + _kb.x
			velocity.z = mv.z + _kb.z
			_kb = _kb.move_toward(Vector3.ZERO, 10.0 * delta)
			velocity.y = -16.0 if not is_on_floor() else -1.0
			move_and_slide()
	if player and dist < 2.2 and _touch_cd <= 0.0:
		_touch_cd = 1.0
		if gm and gm.has_method("damage_player"):
			gm.damage_player(touch_damage)

func apply_damage(dmg: float, dir := Vector3.ZERO) -> void:
	if dead:
		return
	health -= dmg
	var lethal := health <= 0.0
	if lethal:
		dead = true
	_flash = 0.35
	_freeze_cd = 0.055
	if dir != Vector3.ZERO:
		_kb = dir * 6.5
		if kind == Kind.BAT:
			global_position += dir * 0.8
	emit_signal("hit", self, lethal)
	if dead:
		emit_signal("destroyed", self)

func _reg_skin(m: StandardMaterial3D) -> void:
	_skin_mats.append(m)
	_orig_emit.append(m.emission)
	_orig_ee.append(m.emission_energy_multiplier)
	_orig_emitted.append(m.emission_enabled)

func play_death() -> void:
	if _dying:
		return
	_dying = true
	var tw := create_tween()
	tw.set_speed_scale(1.0 / maxf(Engine.time_scale, 0.1))
	tw.tween_property(self, "scale", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
