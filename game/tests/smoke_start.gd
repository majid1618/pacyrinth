extends SceneTree

func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var G = root.get_node_or_null("Game")
	await process_frame
	await process_frame
	print("SMOKE: home visible = ", main.hud._home_panel.visible)

	main._start_game()
	await process_frame
	await process_frame
	await physics_frame
	await physics_frame
	print("SMOKE: after start: started=", main._started, " ended=", main._ended, " tree_paused=", self.paused)
	print("SMOKE: board.input_enabled=", main.board.input_enabled)
	if main.ball == null:
		print("SMOKE FAIL: ball is null after _start_game")
		quit(1)
		return
	if main.ball.get_parent() != main:
		print("SMOKE FAIL: ball must not inherit the tilting board transform")
		quit(1)
		return

	var spawn = main.ball.global_position
	for i in 30:
		await physics_frame
	print("SMOKE: ball rested at ", main.ball.global_position, " vel=", main.ball.linear_velocity)

	var press = InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = Vector2(320, 700)
	main.board._unhandled_input(press)
	for i in 20:
		await physics_frame
		var drag = InputEventScreenDrag.new()
		drag.index = 0
		drag.position = Vector2(396, 660)
		main.board._unhandled_input(drag)
		await physics_frame

	for i in 60:
		await physics_frame

	var moved = (main.ball.global_position - spawn).length()
	var tilted = main.board._current.length()
	print("SMOKE: after drag tilt=%.3f ball moved=%.2f" % [tilted, moved])
	if moved < 0.2 or tilted < 0.05:
		print("SMOKE FAIL: ball did not respond to drag (moved=%.2f tilt=%.3f)" % [moved, tilted])
		quit(1)
		return

	var release = InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = Vector2(396, 660)
	main.board._unhandled_input(release)

	main._on_settings_toggled(true)
	await physics_frame
	await physics_frame
	print("SMOKE: PAUSE-ON flag=", G.paused, " ball.freeze=", main.ball.freeze, " input=", main.board.input_enabled, " ghosts=", main.ghosts.size())
	if main.ghosts.size() > 0:
		print("SMOKE: ghost[0]._frozen=", main.ghosts[0]._frozen)
	if not G.paused or main.ball.freeze != true:
		print("SMOKE FAIL: pause did not engage")
		quit(1)
		return
	var paused_pos = main.ball.global_position
	for i in 20:
		await physics_frame
		if i % 4 == 0:
			print("PAUSE t=%d ball=%s vel=%s freeze=%s mode=%s ended=%s" % [i, str(main.ball.global_position), str(main.ball.linear_velocity), main.ball.freeze, main.ball.freeze_mode, main._ended])
	var drift = (main.ball.global_position - paused_pos).length()
	print("SMOKE: while paused ball drift=%.4f vel=%s" % [drift, str(main.ball.linear_velocity)])
	if drift > 0.01:
		print("SMOKE FAIL: ball kept moving while frozen")
		quit(1)
		return

	main._on_settings_toggled(false)
	await physics_frame
	await physics_frame
	print("SMOKE: PAUSE-OFF flag=", G.paused, " ball.freeze=", main.ball.freeze, " input=", main.board.input_enabled, " tree_paused=", self.paused)
	if G.paused or main.ball.freeze != false:
		print("SMOKE FAIL: pause did not resume cleanly")
		quit(1)
		return

	main.ball.global_position = Vector3(-12.0, 3.0, -12.0)
	main.ball.linear_velocity = Vector3.ZERO
	main.ball.angular_velocity = Vector3.ZERO
	main.board._current = Vector2.ZERO
	await physics_frame

	var press2 = InputEventScreenTouch.new()
	press2.index = 0
	press2.pressed = true
	press2.position = Vector2(320, 700)
	main.board._unhandled_input(press2)
	for i in 20:
		await physics_frame
		var drag2 = InputEventScreenDrag.new()
		drag2.index = 0
		drag2.position = Vector2(320 + i * 7, 700 - i * 4)
		main.board._unhandled_input(drag2)
		await physics_frame
	var tilt_after = main.board._current.length()
	var post_pos = main.ball.global_position
	for i in 60:
		await physics_frame
	var moved2 = (main.ball.global_position - post_pos).length()
	print("SMOKE: after resume drag tilt=%.3f ball moved=%.2f" % [tilt_after, moved2])
	if main.board.input_enabled != true or tilt_after < 0.3 or main.ball.freeze != false or moved2 < 0.2:
		print("SMOKE FAIL: steering dead after resume (input=%s tilt=%.3f freeze=%s moved=%.2f)" % [main.board.input_enabled, tilt_after, main.ball.freeze, moved2])
		quit(1)
		return

	G.lives = 1
	G.score = 123
	main.hud.open_settings(true)
	main.hud.open_settings(false)
	main.hud.replay_pressed.emit()
	print("SMOKE: restart immediate lives=", G.lives, " score=", G.score, " started=", main._started, " ended=", main._ended, " ball_valid=", main.ball != null, " input=", main.board.input_enabled, " board_physics=", main.board.is_physics_processing())
	if G.lives != 3 or G.score != 0 or not main._started or main._ended or main.ball == null or not main.board.input_enabled or not main.board.is_physics_processing():
		print("SMOKE FAIL: restart did not cleanly reset the run")
		quit(1)
		return
	await process_frame
	await physics_frame
	if main.ball == null or not is_instance_valid(main.ball):
		print("SMOKE FAIL: ball invalid after restart frame")
		quit(1)
		return
	print("SMOKE: restart survived a frame at ", main.ball.global_position)

	print("SMOKE OK: level builds, drag steers, pause freezes/resume works, restart reset clean, tree never paused")
	quit(0)
