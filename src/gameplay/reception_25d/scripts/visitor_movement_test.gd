extends Node

const VisitorMovement = preload("res://src/gameplay/reception_25d/scripts/visitor_movement.gd")

@export var movement: VisitorMovement
@export var entrance_left: Marker3D
@export var entrance_right: Marker3D
@export var join_point: Marker3D
@export var service_point: Marker3D
@export_enum("Left", "Right") var initial_entrance: int = 0

var _selected_entrance: Marker3D


func _ready() -> void:
	_selected_entrance = entrance_left if initial_entrance == 0 else entrance_right
	movement.reset_at(_selected_entrance)


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
			movement.reset_at(_selected_entrance)
		_:
			return
	get_viewport().set_input_as_handled()


func _start_from(entrance: Marker3D) -> void:
	_selected_entrance = entrance
	var route: Array[Marker3D] = [join_point, service_point]
	movement.start_from(entrance, route)
