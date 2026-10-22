extends Node

@export var visitor: Node3D
@export var floor_reference: Marker3D
@export_range(0.1, 10.0, 0.1, "or_greater") var movement_speed: float = 3

var _height_offset: float
var _path: Array[Vector3] = []
var _point_index: int = 0


func _ready() -> void:
	# Keep the validated sprite height, including any offset on its room parent.
	_height_offset = visitor.global_position.y - floor_reference.global_position.y
	set_process(false)


func reset_at(entrance: Marker3D) -> void:
	_path.clear()
	_point_index = 0
	set_process(false)
	visitor.global_position = _sprite_position(entrance)


func start_from(entrance: Marker3D, waypoints: Array[Marker3D]) -> void:
	# Replace the previous run; no timers, duplicate visitors or queued movements.
	reset_at(entrance)
	for waypoint in waypoints:
		_path.append(_sprite_position(waypoint))
	set_process(not _path.is_empty())


func _process(delta: float) -> void:
	var remaining_distance := maxf(movement_speed, 0.0) * delta
	while _point_index < _path.size() and remaining_distance > 0.0:
		var target := _path[_point_index]
		var distance := visitor.global_position.distance_to(target)
		if distance <= remaining_distance:
			visitor.global_position = target
			remaining_distance -= distance
			_point_index += 1
		else:
			visitor.global_position = visitor.global_position.move_toward(target, remaining_distance)
			remaining_distance = 0.0
	if _point_index == _path.size():
		set_process(false)


func _sprite_position(marker: Marker3D) -> Vector3:
	return marker.global_position + Vector3.UP * _height_offset
