extends SceneTree

func _initialize() -> void:
	create_freezer(1, Vector3(0, 6, 0))
	await process_frame
	for i in 12:
		await physics_frame
	create_freezer(0, Vector3(8, 6, 0))
	for i in 20:
		await physics_frame
	quit(0)

func create_freezer(mode: int, at: Vector3) -> void:
	var body := RigidBody3D.new()
	body.freeze = true
	body.freeze_mode = mode
	body.global_position = at
	body.mass = 0.8
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.4
	col.shape = sh
	body.add_child(col)
	root.add_child(body)
	var base := at.y
	await physics_frame
	await physics_frame
	print("FREEZE%d: before force vel=", body.linear_velocity)
	body.apply_central_impulse(Vector3(0, -3, 0))
	body.freeze = false
	for i in 5:
		await physics_frame
	print("FREEZE%d: mid-fall pos_y=%.2f vel=%s" % [mode, body.global_position.y, str(body.linear_velocity)])
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	var p = body.global_position
	var max_drift := 0.0
	for i in 30:
		await physics_frame
		max_drift = maxf(max_drift, (body.global_position - p).length())
	print("FREEZE%d: after freeze max_drift=%.4f pos_y=%.2f vel=%s" % [mode, max_drift, body.global_position.y, str(body.linear_velocity)])