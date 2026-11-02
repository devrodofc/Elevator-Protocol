extends Node3D

enum State { CLOSED, OPENING, OPEN, CLOSING }

@export_range(0.05, 5.0, 0.05, "or_greater", "suffix:s") var opening_duration: float = 0.6
@export_range(0.05, 5.0, 0.05, "or_greater", "suffix:s") var closing_duration: float = 0.6
@export_range(0.1, 3.0, 0.05, "or_greater") var slide_distance: float = 1.1
# Door-local distance behind the leaf plane, including the sprite/shadow footprint.
@export_range(0.1, 3.0, 0.05, "or_greater") var passage_clearance: float = 1.0

var state: State = State.CLOSED
var _openness: float = 0.0
var _tween: Tween
var _closed_positions: Array[Vector3] = []

@onready var entry_point: Marker3D = $EntryPoint
@onready var cabin_stop_point: Marker3D = $CabinStopPoint
@onready var cabin_facing_target: Node3D = $DoorAssembly/RecessBack
@onready var _leaves: Array[Node3D] = [$DoorAssembly/LeftPanel, $DoorAssembly/RightPanel]


func _ready() -> void:
	for leaf in _leaves:
		_closed_positions.append(leaf.position)
	reset_closed()


func open() -> void:
	if state != State.OPEN and state != State.OPENING:
		_animate_to(1.0, State.OPENING, State.OPEN, opening_duration)


func close() -> void:
	if state != State.CLOSED and state != State.CLOSING:
		_animate_to(0.0, State.CLOSING, State.CLOSED, closing_duration)


func reset_closed() -> void:
	_cancel_tween()
	_set_openness(0.0)
	state = State.CLOSED


func has_cleared_passage(world_position: Vector3) -> bool:
	# Visitors enter along local -Z, regardless of the elevator's world rotation.
	return to_local(world_position).z <= _closed_positions[0].z - passage_clearance


func _animate_to(target: float, moving_state: State, final_state: State, duration: float) -> void:
	_cancel_tween()
	state = moving_state
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_openness, _openness, target, maxf(duration, 0.05) * absf(target - _openness))
	_tween.tween_callback(func() -> void: state = final_state)


func _set_openness(value: float) -> void:
	_openness = value
	for index in _leaves.size():
		var direction := -1.0 if index == 0 else 1.0
		_leaves[index].position = _closed_positions[index] + Vector3.RIGHT * direction * slide_distance * value


func _cancel_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
