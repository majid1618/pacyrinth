class_name Ghost
extends CharacterBody3D

const SPEEDS := [1.85, 1.7, 2.0, 1.55]
const CHASE_SECS := 7.0
const SCATTER_SECS := 4.0
const ARRIVE_DIST := 0.18

var ghost_index := 0
var speed := 2.3
var player: PacBall

var _color: Color
var _spawn_cell := Vector2i.ZERO
var _scatter_corner := Vector2i.ZERO
var _next_cell := Vector2i(-99, -99)
var _prev_cell := Vector2i(-99, -99)
var _timer := 0.0
var _chasing := true
var _eyes: Node3D
var _frozen := false
var _stunned := false

func setup(index: int, spawn_cell: Vector2i) -> void:
	ghost_index = index
	_spawn_cell = spawn_cell
	var base_hue := randf()
	var hue := fmod(base_hue + float(index) * 0.618034, 1.0)
	_color = Color.from_hsv(hue, randf_range(0.72, 0.88), randf_range(0.92, 1.0))
	_scatter_corner = MazeData.SCATTER_CORNERS[index % MazeData.SCATTER_CORNERS.size()]
	speed = SPEEDS[index % SPEEDS.size()]
	_timer = float(index) * 2.5
	position = MazeData.cell_to_world(spawn_cell)
	_next_cell = spawn_cell

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.15
	col.shape = cap
	col.position.y = 0.58
	add_child(col)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = _color
	body_mat.emission_enabled = true
	body_mat.emission = _color
	body_mat.emission_energy_multiplier = 0.45
	body_mat.roughness = 0.5
	var body := MeshInstance3D.new()
	var bmesh := CapsuleMesh.new()
	bmesh.radius = 0.42
	bmesh.height = 1.15
	body.mesh = bmesh
	body.material_override = body_mat
	body.position.y = 0.575
	add_child(body)

	var skirt := MeshInstance3D.new()
	var smesh := CylinderMesh.new()
	smesh.top_radius = 0.42
	smesh.bottom_radius = 0.30
	smesh.height = 0.25
	skirt.mesh = smesh
	skirt.material_override = body_mat
	skirt.position.y = 0.12
	add_child(skirt)

	_eyes = Node3D.new()
	add_child(_eyes)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.11
		em.height = 0.22
		eye.mesh = em
		var white := StandardMaterial3D.new()
		white.albedo_color = Color.WHITE
		eye.material_override = white
		eye.position = Vector3(0.17 * side, 0.72, 0.30)
		_eyes.add_child(eye)
		var pupil := MeshInstance3D.new()
		var pu := SphereMesh.new()
		pu.radius = 0.05
		pu.height = 0.1
		pupil.mesh = pu
		var blue := StandardMaterial3D.new()
		blue.albedo_color = Color(0.1, 0.15, 0.6)
		pupil.material_override = blue
		pupil.position = Vector3(0.17 * side, 0.72, 0.39)
		_eyes.add_child(pupil)

	var catch_area := Area3D.new()
	catch_area.collision_layer = 0
	catch_area.collision_mask = 4
	var ccol := CollisionShape3D.new()
	var cshape := SphereShape3D.new()
	cshape.radius = 0.62
	ccol.shape = cshape
	ccol.position.y = 0.58
	catch_area.add_child(ccol)
	add_child(catch_area)
	catch_area.body_entered.connect(_on_body_entered)

func freeze() -> void:
	_frozen = true

func unfreeze() -> void:
	_frozen = false

func _physics_process(delta: float) -> void:
	if _stunned:
		return
	if (_frozen or Game.is_power_active("freeze")) and player != null and is_instance_valid(player):
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return
	if player == null or not is_instance_valid(player):
		return
	_timer += delta
	var cycle := fmod(_timer, CHASE_SECS + SCATTER_SECS)
	_chasing = cycle < CHASE_SECS

	var down := -global_transform.basis.y.normalized()
	if is_on_floor():
		velocity -= global_transform.basis.y.normalized() * velocity.dot(global_transform.basis.y.normalized())
	else:
		velocity += down * 9.8 * delta

	var my_cell := MazeData.world_to_cell(global_position)
	var cell_center := MazeData.cell_to_world(my_cell)
	var flat_pos := Vector3(global_position.x, cell_center.y, global_position.z)
	if flat_pos.distance_to(cell_center) < ARRIVE_DIST or _next_cell == Vector2i(-99, -99):
		_decide_next(my_cell)

	var eff_speed := speed * (0.35 if Game.is_power_active("slow") else 1.0)
	var target_world := MazeData.cell_to_world(_next_cell)
	var to_target := target_world - global_position
	to_target.y = 0.0
	if to_target.length() > 0.05:
		var desired := to_target.normalized() * eff_speed
		desired.y = velocity.y
		velocity.x = lerpf(velocity.x, desired.x, clampf(8.0 * delta, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, desired.z, clampf(8.0 * delta, 0.0, 1.0))

	up_direction = global_transform.basis.y.normalized()
	move_and_slide()

	var hv := Vector3(velocity.x, 0, velocity.z)
	if hv.length() > 0.2:
		var yaw := atan2(-hv.x, -hv.z) + PI
		_eyes.rotation.y = lerp_angle(_eyes.rotation.y, yaw, clampf(8.0 * delta, 0.0, 1.0))
	_eyes.position.y = 0.02 * sin(Time.get_ticks_msec() / 180.0 + ghost_index)

func _decide_next(my_cell: Vector2i) -> void:
	if my_cell == _next_cell:
		_prev_cell = my_cell
	var player_cell := Vector2i(-99, -99)
	if player != null and is_instance_valid(player):
		player_cell = MazeData.world_to_cell(player.global_position)
	if Game.is_power_active("repel") and player_cell.x > -90:
		_next_cell = _pick_evade(my_cell, player_cell)
		return
	var target := _scatter_corner
	if _chasing and player != null and not Game.is_power_active("invis"):
		target = player_cell
	elif Game.is_power_active("invis"):
		target = _scatter_corner
	var step := MazeData.bfs_next_step(my_cell, target)
	if step == my_cell:
		step = _pick_fallback(my_cell, target)
	if step == _prev_cell and my_cell != _prev_cell:
		var alt := _pick_alternative(my_cell, target)
		if alt != my_cell:
			step = alt
	_next_cell = step

func _pick_evade(my_cell: Vector2i, threat: Vector2i) -> Vector2i:
	var best := my_cell
	var best_d := -1
	for n in MazeData.neighbors(my_cell):
		if n == _prev_cell and MazeData.neighbors(my_cell).size() > 1:
			continue
		var d := absi(n.x - threat.x) + absi(n.y - threat.y)
		if d > best_d:
			best_d = d
			best = n
	return best

func _pick_fallback(my_cell: Vector2i, target: Vector2i) -> Vector2i:
	var best := my_cell
	var best_d := 999999
	for n in MazeData.neighbors(my_cell):
		var d := absi(n.x - target.x) + absi(n.y - target.y)
		if d < best_d:
			best_d = d
			best = n
	return best

func _pick_alternative(my_cell: Vector2i, target: Vector2i) -> Vector2i:
	var best := my_cell
	var best_d := 999999
	for n in MazeData.neighbors(my_cell):
		if n == _prev_cell:
			continue
		var d := absi(n.x - target.x) + absi(n.y - target.y)
		if d < best_d:
			best_d = d
			best = n
	return best

func _on_body_entered(body: Node3D) -> void:
	if not body is PacBall:
		return
	if Game.is_power_active("shield") or Game.is_power_active("invis"):
		return
	if Game.is_power_active("giant"):
		get_stunned()
		return
	Game.player_caught()

func get_stunned() -> void:
	if _stunned:
		return
	_stunned = true
	Game.add_score(200)
	Input.vibrate_handheld(50)
	collision_layer = 0
	collision_mask = 1 | 2
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func():
		position = MazeData.cell_to_world(_spawn_cell)
		_next_cell = _spawn_cell
		_prev_cell = _spawn_cell)
	tw.tween_interval(1.5)
	tw.tween_property(self, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func():
		if is_instance_valid(self):
			collision_layer = 8
			collision_mask = 1 | 2 | 4 | 8
			_stunned = false)
