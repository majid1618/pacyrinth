extends SceneTree

func _initialize() -> void:
	var data := MazeData.parse()
	var errors: Array[String] = []

	if data.start == Vector2i(-1, -1):
		errors.append("no start cell")
	if data.goal == Vector2i(-1, -1):
		errors.append("no goal cell")
	if data.ghosts.size() != 4:
		errors.append("expected 4 ghosts, got %d" % data.ghosts.size())

	var rows := MazeData.rows()
	var cols := MazeData.cols()
	for y in rows:
		if MazeData.GRID[y].length() != cols:
			errors.append("row %d width mismatch: %d vs %d" % [y, MazeData.GRID[y].length(), cols])
		for x in cols:
			if y == 0 or y == rows - 1 or x == 0 or x == cols - 1:
				if not MazeData.is_wall(Vector2i(x, y)):
					errors.append("border open at (%d,%d)" % [x, y])

	var reach := MazeData.bfs_reachable(data.start)
	if not reach.has(data.goal):
		errors.append("goal unreachable from start")
	for g in data.ghosts:
		if not reach.has(g):
			errors.append("ghost spawn %s unreachable" % str(g))
	for d in data.dots:
		if not reach.has(d):
			errors.append("dot at %s unreachable" % str(d))

	if errors.is_empty():
		print("MAZE OK: %d dots, all reachable; start=%s goal=%s ghosts=%s" % [
			data.dots.size(), data.start, data.goal, str(data.ghosts)])
		quit(0)
	else:
		for e in errors:
			push_error(e)
		print("MAZE FAILED: ", errors)
		quit(1)
