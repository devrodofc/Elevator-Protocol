extends Control

const ElevatorSelection = preload("res://src/gameplay/reception_25d/scripts/elevator_selection.gd")

@export var selection: ElevatorSelection
@export var camera: Camera3D
@export var buttons: Array[Button]

var _camera_blocked: bool = false
var _camera_was_processing: bool


func _ready() -> void:
	for index in buttons.size():
		buttons[index].pressed.connect(selection.select_elevator.bind(index))
	selection.availability_changed.connect(_set_available)
	_set_available(selection.can_select)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_update_camera_hover()


func _process(_delta: float) -> void:
	_update_camera_hover()


func _exit_tree() -> void:
	if _camera_blocked and is_instance_valid(camera):
		camera.set_process(_camera_was_processing)


func _set_available(available: bool) -> void:
	for button in buttons:
		button.disabled = not available


func _update_camera_hover() -> void:
	var over_button := false
	var hovered := get_viewport().gui_get_hovered_control()
	for button in buttons:
		if hovered == button or (hovered != null and button.is_ancestor_of(hovered)):
			over_button = true
			break
	if over_button and not _camera_blocked:
		_camera_was_processing = camera.is_processing()
		camera.set_process(false)
		_camera_blocked = true
	elif not over_button and _camera_blocked:
		camera.set_process(_camera_was_processing)
		_camera_blocked = false
