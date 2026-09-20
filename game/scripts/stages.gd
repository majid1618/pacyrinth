class_name StagesData
extends RefCounted

const LIST: Array[Dictionary] = [
	{
		"name": "WOOD",
		"tex": "wood",
		"wall": Color(0.62, 0.42, 0.20),
		"wall_emit": Color(0.08, 0.04, 0.01),
		"floor": Color(0.30, 0.19, 0.09),
		"damp": 0.38,
		"friction": 0.25,
		"bounce": 0.32,
		"rough": 0.85,
		"metal": 0.0,
	},
	{
		"name": "STONE",
		"tex": "stone",
		"wall": Color(0.52, 0.54, 0.58),
		"wall_emit": Color(0.04, 0.04, 0.05),
		"floor": Color(0.22, 0.23, 0.26),
		"damp": 0.31,
		"friction": 0.18,
		"bounce": 0.40,
		"rough": 0.78,
		"metal": 0.0,
	},
	{
		"name": "MARBLE",
		"tex": "marble",
		"wall": Color(0.88, 0.90, 0.95),
		"wall_emit": Color(0.06, 0.06, 0.08),
		"floor": Color(0.42, 0.44, 0.50),
		"damp": 0.26,
		"friction": 0.10,
		"bounce": 0.46,
		"rough": 0.28,
		"metal": 0.05,
	},
	{
		"name": "IRON",
		"tex": "iron",
		"wall": Color(0.60, 0.64, 0.70),
		"wall_emit": Color(0.05, 0.05, 0.07),
		"floor": Color(0.26, 0.28, 0.32),
		"damp": 0.21,
		"friction": 0.07,
		"bounce": 0.55,
		"rough": 0.32,
		"metal": 0.85,
	},
	{
		"name": "ICE",
		"tex": "ice",
		"wall": Color(0.65, 0.90, 1.0),
		"wall_emit": Color(0.08, 0.22, 0.30),
		"floor": Color(0.24, 0.40, 0.50),
		"damp": 0.14,
		"friction": 0.03,
		"bounce": 0.60,
		"rough": 0.10,
		"metal": 0.1,
	},
	{
		"name": "NEON",
		"tex": "neon",
		"wall": Color(0.95, 0.20, 0.75),
		"wall_emit": Color(0.45, 0.03, 0.35),
		"floor": Color(0.10, 0.03, 0.16),
		"damp": 0.10,
		"friction": 0.03,
		"bounce": 0.72,
		"rough": 0.25,
		"metal": 0.3,
	},
]

static func count() -> int:
	return LIST.size()

static func get_stage(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]
