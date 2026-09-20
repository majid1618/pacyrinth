extends Node3D

const WALL_COLOR := Color(0.13, 0.22, 0.85)
const FLOOR_COLOR := Color(0.045, 0.055, 0.12)
const DOT_COLOR := Color(1.0, 0.9, 0.25)

const RESCUE_HOLD_SECS := 0.9
const RESCUE_RADIUS_PX := 170.0
const RESCUE_MOVE_CANCEL_PX := 60.0
const STARS_PER_LEVEL := 4
const MAGNET_RANGE := 4.0
const MAGNET_PULL := 8.0
const RAISE_TABLE := 2.0

@onready var board: Node3D = $Board
@onready var cam_rig: Node3D = $CameraRig
@onready var hud: CanvasLayer = $HUD

var ball: PacBall
var ghosts: Array[Ghost] = []
var _dots_left := 0
var _dots_holder: Node3D
var _wall_mat: StandardMaterial3D
var _floor_mat: StandardMaterial3D
var _dot_mat: StandardMaterial3D
var _hole_ring: MeshInstance3D
var _ended := false
var _started := false
var _stage: Dictionary = {}
var _playground: Node3D

var _rescue_idx := -1
var _rescue_pos := Vector2.ZERO
var _rescue_anchor := Vector2.ZERO
var _rescue_t := 0.0

func _ready() -> void:
	Game.reset()
	Game.set_paused(false)
	var stage := Game.stage_data()
	_build_environment(stage)
	_make_materials(stage)
	_wire_hud()
	hud.set_stage(Game.stage, stage.get("name", "?"))
	hud.show_home(true)

func _wire_hud() -> void:
	Game.player_hit.connect(_on_player_hit)
	Game.game_over.connect(_on_game_over)
	Game.level_won.connect(_on_level_won)
	hud.calibrate_pressed.connect(_on_calibrate)
	hud.next_stage_pressed.connect(_on_next_stage)
	hud.replay_pressed.connect(_restart_run)
	hud.play_pressed.connect(_start_game)
	hud.menu_pressed.connect(func(): get_tree().reload_current_scene())
	hud.settings_toggled.connect(_on_settings_toggled)
	hud.shop_toggled.connect(_on_shop_toggled)
	hud.shop_buy_pressed.connect(_on_shop_buy)

func _clear_level() -> void:
	# PacBall is intentionally a sibling of Board rather than a child of the
	# rotating playground, so it needs explicit cleanup with each level.
	if ball != null and is_instance_valid(ball):
		ball.queue_free()
	if _playground != null and is_instance_valid(_playground):
		_playground.queue_free()
	_playground = null
	ball = null
	ghosts.clear()
	_dots_holder = null
	_dots_left = 0
	_started = false
	_ended = false
	_reset_rescue()
	board.input_enabled = false

func _restart_run() -> void:
	_start_game()

func _start_game() -> void:
	_clear_level()
	Game.reset()
	get_tree().paused = false
	Game.set_paused(false)
	_started = true
	_playground = Node3D.new()
	_playground.name = "Playground"
	_playground.position.y = RAISE_TABLE
	board.add_child(_playground)
	var stage := Game.stage_data()
	_make_materials(stage)
	board.input_enabled = true
	var data := MazeData.parse()
	_build_floor(data)
	_build_walls(data.walls)
	_build_rim(data)
	_build_dots(data.dots)
	_build_goal(data.goal)
	_spawn_ball(data.start)
	ball.star_collected.connect(_on_star_collected)
	for i in data.ghosts.size():
		_spawn_ghost(i, data.ghosts[i])
	cam_rig.follow_target = ball
	if ball == null:
		return
	hud.set_dots_total(_dots_left)
	hud.set_power("", 0.0)
	_sensor_fallback_check()
	hud.flash_message("GO! TILT OR DRAG TO MOVE", 2.2)

func _on_shop_buy(id: String) -> void:
	var p: Dictionary = Game.POWERS.get(id, {})
	var pname := str(p.get("name", id))
	if Game.try_purchase(id):
		hud.flash_message("★ %s ACTIVATED!" % pname, 2.0)
		Input.vibrate_handheld(60)
		Sound.play("power")
	else:
		hud.flash_message("NEED %d BANK POINTS FOR %s" % [int(p.get("cost", 0)), pname], 1.8)

func _on_settings_toggled(open: bool) -> void:
	_set_game_paused(open)

func _on_shop_toggled(open: bool) -> void:
	_set_game_paused(open)

func _set_game_paused(p: bool) -> void:
	if _ended:
		return
	Game.set_paused(p)
	board.input_enabled = not p
	board.set_physics_process(not p)
	if ball != null and is_instance_valid(ball):
		if p:
			ball.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			ball.freeze = true
			ball.linear_velocity = Vector3.ZERO
			ball.angular_velocity = Vector3.ZERO
		else:
			ball.freeze = false
	for g in ghosts:
		if p:
			g.freeze()
		else:
			g.unfreeze()

func _on_star_collected() -> void:
	var id := Game.random_core_power()
	Game.start_power(id)
	var p: Dictionary = Game.POWERS.get(id, {})
	hud.flash_message("★ STAR POWER: %s" % str(p.get("name", id)), 2.5)
	Input.vibrate_handheld([40, 60, 90][randi() % 3])
	Sound.play("star")
	Sound.play("power")

func _apply_magnet(delta: float) -> void:
	if _dots_holder == null or ball == null or not is_instance_valid(ball):
		return
	for area in _dots_holder.get_children():
		if not area is Area3D or not area.has_meta("dot") or not bool(area.get_meta("dot")):
			continue
		if area.global_position.distance_to(ball.global_position) < MAGNET_RANGE * scale_factor():
			area.global_position = area.global_position.lerp(ball.global_position, clampf(MAGNET_PULL * delta, 0.0, 1.0))

func scale_factor() -> float:
	return ball.scale.x if ball != null and is_instance_valid(ball) else 1.0

func _sensor_fallback_check() -> void:
	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(hud) or not is_instance_valid(board):
		return
	if not board.sensor_ok:
		hud.flash_message("NO TILT SENSOR — DRAG ANYWHERE TO MOVE", 4.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		if _started:
			_restart_run()
		return
	if Game.paused or Game.state != Game.State.PLAYING:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _rescue_idx == -1:
			_rescue_idx = event.index
			_rescue_pos = event.position
			_rescue_anchor = event.position
			_rescue_t = 0.0
		elif not event.pressed and event.index == _rescue_idx:
			_reset_rescue()
	elif event is InputEventScreenDrag and event.index == _rescue_idx:
		var drag := event as InputEventScreenDrag
		_rescue_pos = drag.position

func _process(delta: float) -> void:
	if not _started:
		return
	if _playground != null:
		_playground.rotation.y = PI if Game.rotate180 else 0.0
		_playground.position.y = RAISE_TABLE
	if Game.paused:
		return
	if not _ended:
		var pid := Game.current_power()
		hud.set_power(str(Game.POWERS.get(pid, {}).get("name", "")), Game.power_left_secs())
		if pid == "magnet":
			_apply_magnet(delta)
	if _rescue_idx == -1 or Game.state != Game.State.PLAYING:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or ball == null or not is_instance_valid(ball):
		return
	if _rescue_pos.distance_to(_rescue_anchor) > RESCUE_MOVE_CANCEL_PX:
		_reset_rescue()
		return
	var ball_screen := cam.unproject_position(ball.global_position)
	if _rescue_pos.distance_to(ball_screen) > RESCUE_RADIUS_PX:
		_reset_rescue()
		return
	_rescue_t += delta
	hud.set_rescue_progress(_rescue_t / RESCUE_HOLD_SECS)
	if _rescue_t >= RESCUE_HOLD_SECS:
		_do_rescue()

func _reset_rescue() -> void:
	_rescue_t = 0.0
	hud.set_rescue_progress(0.0)

func _do_rescue() -> void:
	_rescue_idx = -1
	_reset_rescue()
	hud.flash_message("RESCUED!", 1.2)
	Input.vibrate_handheld(80)
	_respawn_deferred.call_deferred()

func _on_calibrate() -> void:
	board.recalibrate()
	hud.flash_message("CALIBRATING...", 1.0)

func _on_next_stage() -> void:
	Game.advance_stage()
	_start_game()

func _physics_process(_delta: float) -> void:
	if _started and not Game.paused and Game.state == Game.State.PLAYING and ball != null and is_instance_valid(ball):
		var p := ball.global_position
		if p.y < -4.0 or Vector2(p.x, p.z).length() > 30.0:
			hud.flash_message("LOST IN THE VOID! RESTART VIA SETTINGS", 2.0)
			Game.player_caught()

func _build_environment(stage: Dictionary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.045, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.60, 0.78)
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.07, 0.14)
	env.fog_density = 0.005
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_build_surroundings()
	_add_lamp(Vector3(0, 13, -3.5), Vector3(0, 0, 2.5), Color(1.0, 0.93, 0.82), 3.8, true)
	_add_lamp(Vector3(0, 11, 7.5), Vector3(0, 0, -3.0), Color(0.78, 0.85, 1.0), 2.4, false)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.50
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = false
	sun.name = "Sun"
	add_child(sun)

func _build_surroundings() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _noise_tex("stone", 77)
	mat.albedo_color = Color(0.24, 0.26, 0.3, 0.05)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = Vector3(24, 24, 1)
	mat.roughness = 0.55
	mat.roughness_texture = mat.albedo_texture
	ground.material_override = mat
	ground.position.y = -3.5
	add_child(ground)

func _add_lamp(pos: Vector3, aim: Vector3, tint: Color, energy: float, with_shadow: bool) -> void:
	var spot := SpotLight3D.new()
	spot.position = pos
	spot.look_at_from_position(pos, aim, Vector3.BACK)
	spot.spot_angle = 58.0
	spot.spot_range = 42.0
	spot.light_energy = energy
	spot.light_color = tint
	spot.shadow_enabled = with_shadow
	add_child(spot)

func _noise_tex(kind: String, seed_val: int = 0) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.fractal_octaves = 5
	match kind:
		"wood":
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
			noise.frequency = 0.008
			noise.fractal_octaves = 6
			noise.domain_warp_enabled = true
			noise.domain_warp_amplitude = 18.0
			noise.domain_warp_frequency = 0.015
		"stone":
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
			noise.frequency = 0.012
			noise.fractal_octaves = 6
		"marble":
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
			noise.frequency = 0.004
			noise.fractal_octaves = 7
			noise.domain_warp_enabled = true
			noise.domain_warp_amplitude = 40.0
			noise.domain_warp_frequency = 0.006
		"iron":
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
			noise.frequency = 0.03
			noise.fractal_octaves = 4
		"ice":
			noise.noise_type = FastNoiseLite.TYPE_PERLIN
			noise.frequency = 0.003
			noise.fractal_octaves = 3
		"neon":
			noise.noise_type = FastNoiseLite.TYPE_CELLULAR
			noise.frequency = 0.02
			noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
			noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = noise
	var g := Gradient.new()
	g.set_color(0, Color(0.35, 0.35, 0.35))
	g.set_color(1, Color(1.0, 1.0, 1.0))
	if kind == "marble":
		g.set_color(0, Color(0.55, 0.55, 0.58))
		g.add_point(0.12, Color(0.75, 0.75, 0.78))
	elif kind == "wood":
		g.set_color(0, Color(0.42, 0.42, 0.42))
		g.add_point(0.45, Color(0.85, 0.85, 0.85))
	elif kind == "iron":
		g.set_color(0, Color(0.55, 0.55, 0.55))
		g.add_point(0.5, Color(0.8, 0.8, 0.8))
	tex.color_ramp = g
	return tex

func _make_materials(stage: Dictionary) -> void:
	_stage = stage
	var kind := str(stage.get("tex", "stone"))
	var wall_tex := _noise_tex(kind, 11)
	var floor_tex := _noise_tex(kind, 29)
	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_color = stage.get("wall", Color(0.13, 0.22, 0.85))
	_wall_mat.albedo_texture = wall_tex
	_wall_mat.uv1_scale = Vector3(1.4, 1.0, 1.4)
	_wall_mat.emission_enabled = true
	_wall_mat.emission = stage.get("wall_emit", Color(0.05, 0.09, 0.3))
	_wall_mat.emission_energy_multiplier = 0.35
	_wall_mat.roughness = float(stage.get("rough", 0.6))
	_wall_mat.roughness_texture = wall_tex
	_wall_mat.metallic = float(stage.get("metal", 0.0))
	_wall_mat.detail_enabled = false
	_floor_mat = StandardMaterial3D.new()
	_floor_mat.albedo_color = stage.get("floor", Color(0.045, 0.055, 0.12))
	_floor_mat.albedo_texture = floor_tex
	_floor_mat.uv1_scale = Vector3(5, 5, 1)
	_floor_mat.roughness = clampf(float(stage.get("rough", 0.8)) + 0.1, 0.05, 1.0)
	_floor_mat.roughness_texture = floor_tex
	_dot_mat = StandardMaterial3D.new()
	_dot_mat.albedo_color = DOT_COLOR
	_dot_mat.emission_enabled = true
	_dot_mat.emission = DOT_COLOR
	_dot_mat.emission_energy_multiplier = 1.6

func _stage_physics() -> PhysicsMaterial:
	var pm := PhysicsMaterial.new()
	pm.friction = float(_stage.get("friction", 0.1))
	pm.bounce = float(_stage.get("bounce", 0.1))
	return pm

func _build_floor(data: Dictionary) -> void:
	var w := float(MazeData.cols()) * MazeData.CELL_SIZE
	var d := float(MazeData.rows()) * MazeData.CELL_SIZE
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.physics_material_override = _stage_physics()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w + 2.0, 0.5, d + 2.0)
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w + 2.0, 0.5, d + 2.0)
	mesh.mesh = box
	mesh.material_override = _floor_mat
	body.add_child(mesh)
	body.position.y = -0.25
	_playground.add_child(body)

func _build_walls(walls: Array) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.physics_material_override = _stage_physics()
	for c in walls:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(MazeData.CELL_SIZE, MazeData.WALL_HEIGHT, MazeData.CELL_SIZE)
		col.shape = shape
		col.position = MazeData.cell_to_world(c)
		col.position.y = MazeData.WALL_HEIGHT * 0.5
		body.add_child(col)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(MazeData.CELL_SIZE, MazeData.WALL_HEIGHT, MazeData.CELL_SIZE)
		mesh.mesh = box
		mesh.material_override = _wall_mat
		mesh.position = col.position
		body.add_child(mesh)
	_playground.add_child(body)

func _build_rim(data: Dictionary) -> void:
	var w := float(MazeData.cols()) * MazeData.CELL_SIZE
	var d := float(MazeData.rows()) * MazeData.CELL_SIZE
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var sides := [
		[Vector3(w + MazeData.CELL_SIZE, 3.0, MazeData.CELL_SIZE), Vector3(0, 1.5, -d * 0.5)],
		[Vector3(w + MazeData.CELL_SIZE, 3.0, MazeData.CELL_SIZE), Vector3(0, 1.5, d * 0.5)],
		[Vector3(MazeData.CELL_SIZE, 3.0, d + MazeData.CELL_SIZE), Vector3(-w * 0.5, 1.5, 0)],
		[Vector3(MazeData.CELL_SIZE, 3.0, d + MazeData.CELL_SIZE), Vector3(w * 0.5, 1.5, 0)],
	]
	for s in sides:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = s[0]
		col.shape = shape
		col.position = s[1] + Vector3(0, 0, 0)
		body.add_child(col)
	_playground.add_child(body)

func _build_dots(cells: Array) -> void:
	_dots_holder = Node3D.new()
	_dots_holder.name = "Dots"
	_playground.add_child(_dots_holder)
	var star_cells := {}
	var pool := cells.duplicate()
	pool.shuffle()
	for i in mini(STARS_PER_LEVEL, pool.size()):
		star_cells[pool[i]] = true
	_dots_left = 0
	for c in cells:
		if star_cells.has(c):
			continue
		_dots_left += 1
		_dots_holder.add_child(_make_pickup(c, "dot"))
	for c in star_cells:
		_dots_holder.add_child(_make_star(c))

func _make_pickup(cell: Vector2i, kind: String) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 16
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.set_meta(kind, true)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.34 if kind == "dot" else 0.5
	col.shape = shape
	area.add_child(col)
	var mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.28
	mesh.mesh = sm
	mesh.material_override = _dot_mat
	area.add_child(mesh)
	area.position = MazeData.cell_to_world(cell)
	area.position.y = 0.45
	return area

func _make_star(cell: Vector2i) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 16
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.set_meta("star", true)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	col.shape = shape
	area.add_child(col)

	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.85, 0.15)
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.75, 0.1)
	gold.emission_energy_multiplier = 2.2
	gold.metallic = 0.6
	gold.roughness = 0.25

	var spinner := Node3D.new()
	area.add_child(spinner)
	for i in 5:
		var spike := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.09, 0.09, 0.52)
		spike.mesh = bm
		spike.material_override = gold
		spike.rotation.y = deg_to_rad(72.0 * float(i))
		spike.position = Vector3(sin(spike.rotation.y), 0, cos(spike.rotation.y)) * 0.22
		spinner.add_child(spike)
	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.16
	cm.height = 0.32
	core.mesh = cm
	core.material_override = gold
	spinner.add_child(core)

	area.position = MazeData.cell_to_world(cell)
	area.position.y = 0.6
	var tw := area.create_tween().set_loops()
	tw.tween_property(spinner, "rotation:y", TAU, 2.2)
	tw.parallel().tween_property(area, "position:y", 0.85, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_property(area, "position:y", 0.35, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return area

func _build_goal(cell: Vector2i) -> void:
	var pos := MazeData.cell_to_world(cell)
	var pit := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.62
	cyl.bottom_radius = 0.62
	cyl.height = 0.12
	pit.mesh = cyl
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.01, 0.01, 0.02)
	dark.roughness = 1.0
	pit.material_override = dark
	pit.position = pos + Vector3(0, 0.061, 0)
	_playground.add_child(pit)

	_hole_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.58
	torus.outer_radius = 0.72
	_hole_ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.2, 1.0, 0.4)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.2, 1.0, 0.4)
	ring_mat.emission_energy_multiplier = 1.4
	_hole_ring.material_override = ring_mat
	_hole_ring.position = pos + Vector3(0, 0.05, 0)
	_playground.add_child(_hole_ring)
	var tw := _hole_ring.create_tween().set_loops()
	tw.tween_property(_hole_ring, "scale", Vector3(1.15, 1.15, 1.15), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_hole_ring, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_SINE)

	var area := Area3D.new()
	area.collision_layer = 16
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.set_meta("goal", true)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.55
	shape.height = 1.2
	col.shape = shape
	area.add_child(col)
	area.position = pos + Vector3(0, 0.6, 0)
	_playground.add_child(area)

func _spawn_ball(start_cell: Vector2i) -> void:
	ball = PacBall.new()
	ball.steering_source = board
	# Keep the dynamic body out of the rotating board hierarchy.  Static maze
	# colliders may move and tilt underneath it, while physics retains ownership
	# of the ball transform and can therefore roll it downhill.
	add_child(ball)
	ball.global_position = _playground.to_global(MazeData.cell_to_world(start_cell) + Vector3(0, 0.55, 0))
	ball.apply_stage(_stage)
	ball.dot_collected.connect(_on_dot_collected)
	ball.reached_goal.connect(_on_goal_reached)

func _spawn_ghost(index: int, spawn_cell: Vector2i) -> void:
	var g := Ghost.new()
	g.name = "Ghost%d" % index
	g.setup(index, spawn_cell)
	g.speed += Game.stage * 0.05
	_playground.add_child(g)
	g.player = ball
	ghosts.append(g)

func _on_dot_collected() -> void:
	_dots_left -= 1
	Game.add_score(20 if Game.is_power_active("fever") else 10)
	hud.set_dots_left(_dots_left)
	Input.vibrate_handheld(25)
	Sound.play("dot")

func _on_goal_reached() -> void:
	if _ended or Game.state != Game.State.PLAYING:
		return
	board.input_enabled = false
	ball.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	ball.freeze = true
	Sound.play("finish")
	var tw := create_tween()
	tw.tween_property(ball, "scale", Vector3(0.15, 0.15, 0.15), 0.8).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(ball, "global_position:y", ball.global_position.y - 0.45, 0.8)
	tw.tween_callback(func():
		Game.add_time_bonus(30)
		Game.level_complete())

func _on_player_hit() -> void:
	Sound.play("hurt")
	if Game.lives > 0:
		Input.vibrate_handheld(120)
		_respawn_deferred.call_deferred()
	else:
		_end_gameplay()

func _respawn_deferred() -> void:
	if ball == null or not is_instance_valid(ball) or _playground == null:
		return
	var data := MazeData.parse()
	ball.respawn(_playground.to_global(MazeData.cell_to_world(data.start) + Vector3(0, 0.55, 0)))
	hud.flash_message("OUCH! %d lives left" % Game.lives, 1.4)

func _on_game_over() -> void:
	_end_gameplay()
	Game.submit_score()
	hud.show_game_over(Game.score)

func _on_level_won() -> void:
	_end_gameplay()
	Game.submit_score()
	hud.show_win(Game.score)

func _end_gameplay() -> void:
	_ended = true
	board.input_enabled = false
	for g in ghosts:
		g.freeze()
