extends Node3D

@export var offset := Vector3(0, 15.5, 9.0)
@export var follow_speed := 4.0

var follow_target: Node3D

func _ready() -> void:
	var cam := Camera3D.new()
	cam.fov = 52
	add_child(cam)
	cam.make_current()

func _process(delta: float) -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		return
	var goal := follow_target.global_position + offset
	global_position = global_position.lerp(goal, clampf(follow_speed * delta, 0.0, 1.0))
	look_at(follow_target.global_position, Vector3.BACK)
