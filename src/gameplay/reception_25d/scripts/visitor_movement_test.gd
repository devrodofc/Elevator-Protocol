extends Node

const VisitorMovement = preload("res://src/gameplay/reception_25d/scripts/visitor_movement.gd")
const AutomaticDoor = preload("res://src/gameplay/reception_25d/scripts/automatic_door.gd")

@export var movement: VisitorMovement
@export var entrance_left: Marker3D
@export var entrance_right: Marker3D
@export var door_left: AutomaticDoor
@export var door_right: AutomaticDoor
@export var join_point: Marker3D
@export var service_point: Marker3D
@export_enum("Left", "Right") var initial_entrance: int = 0

var _selected_entrance: Marker3D
var _selected_door: AutomaticDoor
var _active_door: AutomaticDoor
var _waiting_for_open: bool = false


func _ready() -> void:
	_selected_entrance = entrance_left if initial_entrance == 0 else entrance_right
	_selected_door = door_left if initial_entrance == 0 else door_right
	_reset_test()


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var key: Key = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	match key:
		KEY_1:
			_start_from(entrance_left)
		KEY_2:
			_start_from(entrance_right)
		KEY_R:
			_reset_test()
		_:
			return
	get_viewport().set_input_as_handled()


func _start_from(entrance: Marker3D) -> void:
	_selected_entrance = entrance
	_selected_door = door_left if entrance == entrance_left else door_right
	_reset_test()
	_active_door = _selected_door
	_waiting_for_open = true
	_active_door.open()
	set_process(true)


func _reset_test() -> void:
	set_process(false)
	_active_door = null
	_waiting_for_open = false
	# Hide the visitor and shadow while staged in the shallow vestibule behind the leaves.
	movement.visitor.hide()
	movement.reset_at(_selected_door.spawn_point)
	door_left.reset_closed()
	door_right.reset_closed()


func _process(_delta: float) -> void:
	if _waiting_for_open:
		if _active_door.state != AutomaticDoor.State.OPEN:
			return
		_waiting_for_open = false
		var route: Array[Marker3D] = [_selected_entrance, join_point, service_point]
		movement.start_from(_active_door.spawn_point, route)
		movement.visitor.show()
	if _active_door.has_cleared_passage(movement.visitor.global_position):
		_active_door.close()
		_active_door = null
		set_process(false)
