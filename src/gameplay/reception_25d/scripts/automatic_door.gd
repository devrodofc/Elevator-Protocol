extends Node3D

enum State { CLOSED, OPENING, OPEN, CLOSING }

@export_range(0.1, 5.0, 0.05, "or_greater") var slide_distance: float = 1.2
@export_range(0.1, 10.0, 0.1, "or_greater") var animation_speed: float = 2.4
# Conservative clearance for the billboard sprite and contact shadow, in door-local units.
@export_range(0.1, 3.0, 0.1, "or_greater") var passage_clearance: float = 1.5

var state: State = State.CLOSED
var _openness: float = 0.0
var _tween: Tween
var _closed_positions: Array[Vector3] = []

@onready var spawn_point: Marker3D = $SpawnPoint
@onready var _leaves: Array[Node3D] = [
	$DoorAssembly/LeftPanel, $DoorAssembly/LeftPanelRail,
	$DoorAssembly/RightPanel, $DoorAssembly/RightPanelRail,
]


func _ready() -> void:
	for leaf in _leaves:
		_closed_positions.append(leaf.position)
	reset_closed()


func open() -> void:
	if state == State.OPEN or state == State.OPENING:
		return
	_animate_to(1.0, State.OPENING, State.OPEN)


func close() -> void:
	if state == State.CLOSED or state == State.CLOSING:
		return
	_animate_to(0.0, State.CLOSING, State.CLOSED)


func reset_closed() -> void:
	_cancel_tween()
	_set_openness(0.0)
	state = State.CLOSED


func has_cleared_passage(world_position: Vector3) -> bool:
	# Reception interior is local +Z. No timer depends on the visitor's walking speed.
	return to_local(world_position).z >= _closed_positions[0].z + passage_clearance


func _animate_to(target: float, moving_state: State, final_state: State) -> void:
	_cancel_tween()
	state = moving_state
	var duration := absf(target - _openness) * slide_distance / maxf(animation_speed, 0.1)
	_tween = create_tween()
	_tween.tween_method(_set_openness, _openness, target, duration)
	_tween.tween_callback(func() -> void: state = final_state)


func _set_openness(value: float) -> void:
	_openness = value
	for index in _leaves.size():
		var direction := -1.0 if index < 2 else 1.0
		_leaves[index].position = _closed_positions[index] + Vector3.RIGHT * direction * slide_distance * value


func _cancel_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
