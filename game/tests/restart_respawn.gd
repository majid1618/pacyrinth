extends SceneTree

func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var G = root.get_node_or_null("Game")
	await process_frame
	await process_frame

	main._start_game()
	for i in 60:
		await physics_frame
	var first_rest: Vector3 = main.ball.global_position
	print("R1 first-start ball rests at ", first_rest, " lives=", G.lives)
	if main.ball == null or not is_instance_valid(main.ball) or first_rest.y < 1.5:
		print("FAIL: first-start ball did not rest on table")
		quit(1)
		return

	G.lives = 1
	G.score = 123
	main.hud.open_settings(true)
	main.hud.open_settings(false)
	main.hud.replay_pressed.emit()
	print("R2 restart immediate lives=", G.lives, " score=", G.score, " ball_valid=", main.ball != null)
	if G.lives != 3 or G.score != 0 or main.ball == null:
		print("FAIL: restart did not reset")
		quit(1)
		return
	await process_frame
	for i in 60:
		await physics_frame
	var restart_rest: Vector3 = main.ball.global_position
	print("R3 restarted ball rests at ", restart_rest, " vel=", main.ball.linear_velocity, " freeze=", main.ball.freeze)
	if restart_rest.y < 1.5:
		print("FAIL: restarted ball did not rest on table (fell through = ", restart_rest, ")")
		quit(1)
		return
	if main.ball.freeze == true:
		print("FAIL: restarted ball is frozen")
		quit(1)
		return

	main.ball.global_position = Vector3(-10, 0.3, -6)
	main.ball.linear_velocity = Vector3.ZERO
	main.board._current = Vector2.ZERO
	await physics_frame
	G.player_caught()
	await physics_frame
	for i in 90:
		await physics_frame
	var respawn_rest: Vector3 = main.ball.global_position
	var start_world: Vector3 = main._playground.to_global(MazeData.cell_to_world(MazeData.parse().start) + Vector3(0, 0.55, 0))
	var dist: float = (respawn_rest - start_world).length()
	print("R4 after caught lives=", G.lives, " ball at ", respawn_rest, " dist_to_start=", dist)
	if G.lives != 2 or respawn_rest.y < 1.5 or dist > 4.0:
		print("FAIL: respawn corrupt (lives=", G.lives, " y=", respawn_rest.y, " dist=", dist, ")")
		quit(1)
		return

	print("OK: first start, restart, and respawn all rest on the table")
	quit(0)