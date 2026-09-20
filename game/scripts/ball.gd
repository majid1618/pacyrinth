class_name PacBall
extends RigidBody3D

signal dot_collected
signal star_collected
signal reached_goal

const PICKUP_RADIUS := 0.6
const BASE_MAX_SPEED := 14.0
const ROCKET_MAX_SPEED := 26.0
const BRAKE_MULT := 3.2
const NORMAL_SCALE := 1.0
const GIANT_SCALE := 1.75

var base_damp := 0.38
# The ball must stay outside the tilting board's transform hierarchy.  A
# RigidBody3D owns its transform while physics is running; inheriting the
# board rotation makes the scene tree overwrite that transform every frame.
var steering_source: Node

var _face: Node3D
var _mouth: MeshInstance3D
var _body_mat: StandardMaterial3D
var _alpha_mats: Array[StandardMaterial3D] = []
var _pickup: Area3D
var _chomp_t := 0.0
var _was_giant := false
var _was_invis := false
var _was_rocket := false
var _bounce_cooldown := 0

func _ready() -> void:
	lock_rotation = false
	axis_lock_linear_y = false
	angular_damp = 2.0
	mass = 0.8
	linear_damp = base_damp
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 3
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 1.0
	physics_material_override = pm
	collision_layer = 4
	collision_mask = 1 | 2 | 8

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.42
	col.shape = sphere
	add_child(col)

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(1.0, 0.88, 0.1)
	_body_mat.roughness = 0.35
	_body_mat.metallic = 0.1
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0.55, 0.45, 0.02)
	_body_mat.emission_energy_multiplier = 0.6
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.42
	bm.height = 0.84
	body.mesh = bm
	body.material_override = _body_mat
	add_child(body)
	_alpha_mats.append(_body_mat)

	var spot_mat := StandardMaterial3D.new()
	spot_mat.albedo_color = Color(0.45, 0.30, 0.02)
	spot_mat.roughness = 0.5
	_alpha_mats.append(spot_mat)
	for dir in [
		Vector3(0.3, 0.85, 0.2), Vector3(-0.6, 0.1, 0.5),
		Vector3(0.1, -0.4, 0.8), Vector3(0.7, -0.5, -0.3),
		Vector3(-0.2, 0.6, -0.75), Vector3(-0.75, -0.35, -0.2),
	]:
		var spot := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.085
		sm.height = 0.17
		spot.mesh = sm
		spot.material_override = spot_mat
		spot.position = dir.normalized() * 0.39
		add_child(spot)

	_face = Node3D.new()
	_face.top_level = true
	add_child(_face)

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.09
		em.height = 0.18
		eye.mesh = em
		var white := StandardMaterial3D.new()
		white.albedo_color = Color.WHITE
		eye.material_override = white
		eye.position = Vector3(0.16 * side, 0.18, 0.33)
		_face.add_child(eye)
		var pupil := MeshInstance3D.new()
		var pmesh := SphereMesh.new()
		pmesh.radius = 0.04
		pmesh.height = 0.08
		pupil.mesh = pmesh
		var black := StandardMaterial3D.new()
		black.albedo_color = Color(0.05, 0.05, 0.1)
		pupil.material_override = black
		pupil.position = Vector3(0.16 * side, 0.18, 0.40)
		_face.add_child(pupil)

	_mouth = MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.30
	mm.height = 0.60
	_mouth.mesh = mm
	var mouth_mat := StandardMaterial3D.new()
	mouth_mat.albedo_color = Color(0.35, 0.08, 0.05)
	_mouth.material_override = mouth_mat
	_mouth.position = Vector3(0, -0.02, 0.30)
	_mouth.scale = Vector3(0.9, 0.5, 0.5)
	_face.add_child(_mouth)

	_pickup = Area3D.new()
	_pickup.collision_layer = 0
	_pickup.collision_mask = 16
	var pcol := CollisionShape3D.new()
	var pshape := SphereShape3D.new()
	pshape.radius = PICKUP_RADIUS
	pcol.shape = pshape
	_pickup.add_child(pcol)
	add_child(_pickup)
	_pickup.area_entered.connect(_on_pickup_area_entered)
	body_entered.connect(_on_body_contact)

func apply_stage(s: Dictionary) -> void:
	base_damp = float(s.get("damp", 0.38))
	if physics_material_override != null:
		physics_material_override.friction = 1.0
		physics_material_override.bounce = 1.0
	linear_damp = base_damp

func _physics_process(delta: float) -> void:
	var invis := Game.is_power_active("invis")
	var giant := Game.is_power_active("giant")
	var rocket := Game.is_power_active("rocket")
	if giant != _was_giant:
		_was_giant = giant
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ONE * (GIANT_SCALE if giant else NORMAL_SCALE), 0.25)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if invis != _was_invis:
		_was_invis = invis
		if invis:
			collision_mask = collision_mask & ~1
			for m in _alpha_mats:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_color.a = 0.32
		else:
			collision_mask = collision_mask | 1
			for m in _alpha_mats:
				m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				m.albedo_color.a = 1.0
	if rocket != _was_rocket:
		_was_rocket = rocket
		_body_mat.emission_energy_multiplier = 2.2 if rocket else 0.6
		_body_mat.emission = Color(1.0, 0.35, 0.05) if rocket else Color(0.55, 0.45, 0.02)

	var top_speed := ROCKET_MAX_SPEED if rocket else BASE_MAX_SPEED
	if linear_velocity.length() > top_speed:
		linear_velocity = linear_velocity.normalized() * top_speed
	var steering: bool = steering_source == null or not ("input_active" in steering_source) or bool(steering_source.input_active)
	var damp := base_damp if not rocket else base_damp * 0.22
	linear_damp = damp if steering else damp * BRAKE_MULT
	if angular_velocity.length() > 24.0:
		angular_velocity = angular_velocity.normalized() * 24.0

	_face.global_position = global_position + Vector3(0, 0.03, 0)
	_face.scale = Vector3.ONE * scale.x
	var v := linear_velocity
	v.y = 0.0
	if v.length() > 0.4:
		var yaw := atan2(-v.x, -v.z) + PI
		_face.rotation.y = lerp_angle(_face.rotation.y, yaw, clampf(10.0 * delta, 0.0, 1.0))
	var speed_factor := clampf(v.length() / 6.0, 0.12, 1.0)
	_chomp_t += delta * (2.0 + speed_factor * 10.0)
	var open := absf(sin(_chomp_t)) * speed_factor
	_mouth.scale.z = lerpf(0.12, 0.62, open)
	if Game.is_invulnerable() and Game.state == Game.State.PLAYING and not invis:
		var blink := fmod(Time.get_ticks_msec(), 200) < 100
		set_visible_all(blink)
	else:
		set_visible_all(true)

func set_visible_all(vis: bool) -> void:
	_face.visible = vis

func respawn(at: Vector3) -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	global_position = at
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	await get_tree().create_timer(0.05).timeout
	freeze = false
	Game.grant_invulnerability()

func _on_pickup_area_entered(area: Area3D) -> void:
	if area.has_meta("dot"):
		if area.is_queued_for_deletion():
			return
		area.set_meta("dot", false)
		area.queue_free()
		dot_collected.emit()
	elif area.has_meta("star"):
		if area.is_queued_for_deletion():
			return
		area.set_meta("star", false)
		area.queue_free()
		star_collected.emit()
	elif area.has_meta("goal"):
		reached_goal.emit()

func _on_body_contact(_body: Node) -> void:
	var now := Time.get_ticks_msec()
	if now - _bounce_cooldown < 90:
		return
	_bounce_cooldown = now
	var speed := linear_velocity.length()
	if speed > 1.0:
		Sound.play_bounce(speed)
