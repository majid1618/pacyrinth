class_name MazeData
extends RefCounted

const CELL_SIZE := 2.0
const WALL_HEIGHT := 1.05

const GRID: Array[String] = [
	"###############",
	"#G.....a.....b#",
	"#.###.#.#.###.#",
	"#.#...........#",
	"#.#.##.#.##.#.#",
	"#....#...#....#",
	"###.#.#.#.#.###",
	"#.....#.#.....#",
	"###.#.#.#.#.###",
	"#....#...#....#",
	"#.#.##.#.##.#.#",
	"#.#...........#",
	"#.###.#.#.###.#",
	"#d....c......S#",
	"###############",
]

const GHOST_COLORS: Array[Color] = [
	Color(0.95, 0.22, 0.28),
	Color(1.0, 0.56, 0.78),
	Color(0.25, 0.9, 0.95),
	Color(1.0, 0.62, 0.16),
]

const SCATTER_CORNERS: Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(13, 1),
	Vector2i(1, 13),
	Vector2i(13, 13),
]

static func rows() -> int:
	return GRID.size()

static func cols() -> int:
	return GRID[0].length()

static func is_wall(c: Vector2i) -> bool:
	if c.y < 0 or c.y >= GRID.size() or c.x < 0 or c.x >= GRID[c.y].length():
		return true
	return GRID[c.y][c.x] == "#"

static func is_open(c: Vector2i) -> bool:
	return not is_wall(c)

static func half_extent() -> Vector2:
	return Vector2(cols(), rows()) * CELL_SIZE * 0.5

static func cell_to_world(c: Vector2i) -> Vector3:
	var h := half_extent()
	return Vector3(c.x * CELL_SIZE - h.x + CELL_SIZE * 0.5, 0.0, c.y * CELL_SIZE - h.y + CELL_SIZE * 0.5)

static func world_to_cell(p: Vector3) -> Vector2i:
	var h := half_extent()
	return Vector2i(int(floor((p.x + h.x) / CELL_SIZE)), int(floor((p.z + h.y) / CELL_SIZE)))

static func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n := c + d
		if is_open(n):
			out.append(n)
	return out

static func parse() -> Dictionary:
	var data := {
		"walls": [],
		"dots": [],
		"start": Vector2i(-1, -1),
		"goal": Vector2i(-1, -1),
		"ghosts": [],
	}
	for y in GRID.size():
		for x in GRID[y].length():
			var ch := GRID[y][x]
			var c := Vector2i(x, y)
			match ch:
				"#":
					data.walls.append(c)
				".":
					data.dots.append(c)
				"S":
					data.start = c
				"G":
					data.goal = c
				"a", "b", "c", "d":
					data.ghosts.append(c)
	return data

static func bfs_next_step(from: Vector2i, to: Vector2i) -> Vector2i:
	if from == to or not is_open(to):
		return from
	var queue: Array[Vector2i] = [from]
	var came_from := {from: from}
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for n in neighbors(cur):
			if came_from.has(n):
				continue
			came_from[n] = cur
			if n == to:
				var step := n
				while came_from[step] != from:
					step = came_from[step]
				return step
			queue.append(n)
	return from

static func bfs_reachable(start: Vector2i) -> Dictionary:
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for n in neighbors(cur):
			if not dist.has(n):
				dist[n] = dist[cur] + 1
				queue.append(n)
	return dist
