extends Node

const VisitorMovement = preload("res://src/gameplay/reception_25d/scripts/visitor_movement.gd")
const VisitorOrientation = preload("res://src/gameplay/reception_25d/scripts/visitor_orientation.gd")
const ElevatorDoor = preload("res://src/gameplay/reception_25d/scripts/elevator_door.gd")

signal availability_changed(available: bool)

enum Stage { IDLE, ARRIVING, AT_SERVICE, TO_ELEVATOR, WAITING_FOR_DOOR, ENTERING_CABIN, IN_CABIN }

@export var movement: VisitorMovement
@export var orientation: VisitorOrientation
@export var service_point: Marker3D
@export var retreat_point: Marker3D
@export var corridor_entry: Marker3D
@export var turn_points: Array[Marker3D]
@export var wait_points: Array[Marker3D]

var stage: Stage = Stage.IDLE
var selected_elevator: int = -1
var can_select: bool = false
var _elevators: Array[ElevatorDoor] = []
var _active_elevator: ElevatorDoor


func _ready() -> void:
	for point in wait_points:
		_elevators.append(point.get_parent() as ElevatorDoor)
	movement.movement_reset.connect(_on_movement_reset)
	movement.route_started.connect(_on_route_started)
	movement.arrived.connect(_on_arrived)
	set_process(false)


func select_elevator(index: int) -> void:
	if not can_select or index < 0 or index >= wait_points.size():
		return
	selected_elevator = index
	_active_elevator = _elevators[index]
	stage = Stage.TO_ELEVATOR
	_set_available(false)
	orientation.face_when_idle(null)
	var route: Array[Marker3D] = [retreat_point, corridor_entry, turn_points[index], wait_points[index]]
	movement.follow_route(route)


func _on_movement_reset() -> void:
	set_process(false)
	_active_elevator = null
	for elevator in _elevators:
		elevator.reset_closed()
	stage = Stage.IDLE
	selected_elevator = -1
	orientation.face_when_idle(null)
	_set_available(false)


func _on_route_started() -> void:
	if stage != Stage.TO_ELEVATOR and stage != Stage.ENTERING_CABIN:
		stage = Stage.ARRIVING
		_set_available(false)


func _on_arrived() -> void:
	if stage == Stage.ARRIVING and movement.visitor.global_position.distance_squared_to(service_point.global_position) < 0.0001:
		stage = Stage.AT_SERVICE
		_set_available(true)
	elif stage == Stage.TO_ELEVATOR:
		stage = Stage.WAITING_FOR_DOOR
		orientation.face_when_idle(_active_elevator)
		_active_elevator.open()
		set_process(true)
	elif stage == Stage.ENTERING_CABIN:
		stage = Stage.IN_CABIN
		orientation.face_when_idle(_active_elevator.cabin_facing_target)


func _process(_delta: float) -> void:
	if stage == Stage.WAITING_FOR_DOOR:
		if _active_elevator.state != ElevatorDoor.State.OPEN:
			return
		stage = Stage.ENTERING_CABIN
		orientation.face_when_idle(null)
		var route: Array[Marker3D] = [_active_elevator.entry_point, _active_elevator.cabin_stop_point]
		movement.follow_route(route)
	if stage == Stage.ENTERING_CABIN or stage == Stage.IN_CABIN:
		if _active_elevator.has_cleared_passage(movement.visitor.global_position):
			_active_elevator.close()
			set_process(false)


func _set_available(available: bool) -> void:
	can_select = available
	availability_changed.emit(available)
