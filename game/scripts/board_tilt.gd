extends Node3D

const GRAV := 9.81
const DEADZONE := 0.05
const TOUCH_RADIUS := 160.0
const CAPTURE_FRAMES := 14

@export var max_tilt_deg: float = 22.0
@export var smoothing: float = 7.5

var input_enabled := true
var input_active := false
var sensor_ok := false
var calibrated := false

var _target := Vector2.ZERO
var _current := Vector2.ZERO
var _sensor_logged := false
var _neutral := Vector2.ZERO
var _capturing := false

var _touch_idx := -1
var _anchor := Vector2.ZERO
var _touch_vec := Vector2.ZERO

func _ready() -> void:
	recalibrate()

func recalibrate() -> void:
	if _capturing:
		return
	_capturing = true
	calibrated = false
	var acc := Vector2.ZERO
	var n := 0
	for i in CAPTURE_FRAMES:
		await get_tree().physics_frame
		var g := Input.get_gravity()
		if g.length() < 1.0:
			g = Input.get_accelerometer()
		if g.length() >= 1.0:
			acc += Vector2(g.x, g.y) / GRAV
			n += 1
	if n > 0:
		_neutral = acc / float(n)
		sensor_ok = true
		calibrated = true
	else:
		_neutral = Vector2.ZERO
		calibrated = false
	_capturing = false

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_idx == -1:
			_touch_idx = event.index
			_anchor = event.position
			_touch_vec = Vector2.ZERO
		elif not event.pressed and event.index == _touch_idx:
			_touch_idx = -1
			_touch_vec = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == _touch_idx:
		var drag := event as InputEventScreenDrag
		var d: Vector2 = (drag.position - _anchor) / float(TOUCH_RADIUS)
		_touch_vec = d.clamp(Vector2.ONE * -1.0, Vector2.ONE)

func _physics_process(delta: float) -> void:
	if input_enabled:
		_target = _read_tilt()
	else:
		_target = Vector2.ZERO
	input_active = _target.length() > DEADZONE
	if Game.mirror_lr:
		_target.x = -_target.x
	var k := clampf(smoothing * delta, 0.0, 1.0)
	_current = _current.lerp(_target, k)
	var ang := max_tilt_deg + (12.0 if Game.is_power_active("rocket") else 0.0)
	var rad := deg_to_rad(ang)
	rotation.z = lerpf(rotation.z, -_current.x * rad, k)
	rotation.x = lerpf(rotation.x, -_current.y * rad, k)

func _read_tilt() -> Vector2:
	var mode := Game.control_mode
	if mode == "touch":
		return _scaled_touch()
	var t := _sensor_delta()
	t += Input.get_vector("tilt_left", "tilt_right", "tilt_down", "tilt_up")
	t = t.clamp(Vector2.ONE * -1.0, Vector2.ONE)
	if mode == "auto" and t.length() < DEADZONE:
		return _scaled_touch()
	if t.length() < DEADZONE:
		return Vector2.ZERO
	return t

func _scaled_touch() -> Vector2:
	if _touch_vec.length() < DEADZONE:
		return Vector2.ZERO
	return (_touch_vec * minf(Game.sensitivity, 2.2)).clamp(Vector2.ONE * -1.0, Vector2.ONE)

func _sensor_delta() -> Vector2:
	var g := Input.get_gravity()
	if g.length() < 1.0:
		g = Input.get_accelerometer()
	if g.length() < 1.0:
		return Vector2.ZERO
	sensor_ok = true
	if not _sensor_logged:
		_sensor_logged = true
		print("tilt sensor active, raw=", g)
	var n := Vector2(g.x, g.y) / GRAV
	var flip := -1.0 if Game.reverse_tilt else 1.0
	return (((n - _neutral) * Game.sensitivity) * flip).clamp(Vector2.ONE * -1.0, Vector2.ONE)
