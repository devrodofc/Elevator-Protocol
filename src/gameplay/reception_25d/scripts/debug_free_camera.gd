extends Node
## Temporary navigation of an existing reception camera; no physics or gameplay state.

const ReceptionCamera = preload("res://src/gameplay/reception_25d/scripts/reception_camera.gd")
const MOVEMENT_KEYS = [KEY_W, KEY_S, KEY_A, KEY_D, KEY_Q, KEY_E, KEY_SHIFT]

@export var enable_debug_exploration: bool = false:
	set(value):
		enable_debug_exploration = value
		if not value and active:
			_stop_exploration()
@export var camera: ReceptionCamera
## A point on the floor surface, including the room's global offset.
@export var floor_reference: Node3D
@export var indicator: Control
@export_range(0.1, 20.0, 0.1, "or_greater", "suffix:m/s") var movement_speed: float = 3.0
@export_range(1.0, 10.0, 0.1, "or_greater") var fast_speed_multiplier: float = 3.0
@export_range(0.01, 2.0, 0.01, "suffix:°/px") var mouse_sensitivity: float = 0.15
@export_range(0.05, 3.0, 0.05, "or_greater", "suffix:m") var minimum_height: float = 0.25
@export_range(1.0, 89.0, 1.0, "suffix:°") var pitch_limit: float = 85.0
@export_range(1.0, 30.0, 0.5) var movement_response: float = 12.0

var active: bool = false
var _initial_transform: Transform3D
var _velocity: Vector3 = Vector3.ZERO
var _keys: Dictionary = {}
var _yaw: float
var _pitch: float
var _looking: bool = false
var _previous_mouse_mode: Input.MouseMode
var _cursor_position: Vector2


func _ready() -> void:
	# This node lives outside the SubViewport, after the camera's _ready().
	_initial_transform = camera.transform
	if indicator != null:
		indicator.hide()
	set_process(false)


func _input(event: InputEvent) -> void:
	if not enable_debug_exploration:
		return
	if event is InputEventKey:
		var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_F:
			if event.pressed and not event.echo:
				if active:
					_stop_exploration()
				else:
					_start_exploration()
			get_viewport().set_input_as_handled()
		elif active and key in MOVEMENT_KEYS:
			_keys[key] = event.pressed
			get_viewport().set_input_as_handled()
	if not active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			if not _looking:
				_cursor_position = get_viewport().get_mouse_position()
				_previous_mouse_mode = Input.mouse_mode
				_looking = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_release_mouse()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _looking:
		# Unscaled window pixels: independent of the 640x360 SubViewport/stretch.
		_yaw -= deg_to_rad(event.screen_relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - deg_to_rad(event.screen_relative.y * mouse_sensitivity),
			-deg_to_rad(pitch_limit), deg_to_rad(pitch_limit))
		camera.global_rotation = Vector3(_pitch, _yaw, 0.0)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var direction := forward * (_axis(KEY_W, KEY_S)) + right * (_axis(KEY_D, KEY_A))
	direction += Vector3.UP * _axis(KEY_E, KEY_Q)
	var speed := movement_speed * (fast_speed_multiplier if _keys.get(KEY_SHIFT, false) else 1.0)
	var target := direction.limit_length() * speed
	# Integrate exponential velocity smoothing, including its displacement, in seconds.
	var decay := exp(-movement_response * delta)
	camera.global_position += target * delta + (_velocity - target) * (1.0 - decay) / movement_response
	_velocity = target + (_velocity - target) * decay
	var floor_y := floor_reference.global_position.y if floor_reference != null else 0.0
	if camera.global_position.y < floor_y + minimum_height:
		camera.global_position.y = floor_y + minimum_height
		_velocity.y = maxf(_velocity.y, 0.0)


func _axis(positive: Key, negative: Key) -> float:
	return float(_keys.get(positive, false)) - float(_keys.get(negative, false))


func _start_exploration() -> void:
	active = true
	camera.debug_exploration_active = true
	_yaw = camera.global_rotation.y
	_pitch = camera.global_rotation.x
	_velocity = Vector3.ZERO
	_keys.clear()
	if indicator != null:
		indicator.show()
	set_process(true)


func _stop_exploration() -> void:
	active = false
	set_process(false)
	_keys.clear()
	_velocity = Vector3.ZERO
	_release_mouse()
	if is_instance_valid(camera):
		camera.transform = _initial_transform
		camera.reset_debug_exploration()
		camera.reset_physics_interpolation()
	if is_instance_valid(indicator):
		indicator.hide()


func _release_mouse() -> void:
	if not _looking:
		return
	_looking = false
	Input.mouse_mode = _previous_mouse_mode
	if _previous_mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.warp_mouse(_cursor_position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_keys.clear()
		_velocity = Vector3.ZERO
		_release_mouse()


func _exit_tree() -> void:
	if active:
		_stop_exploration()
