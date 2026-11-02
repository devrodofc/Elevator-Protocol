extends SceneTree
## Run with --headless --path <temporary project> -s res://src/gameplay/reception_25d/tests/debug_free_camera_test.gd

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _key(code: Key, pressed: bool = true, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	root.push_input(event)


func _toggle() -> void:
	_key(KEY_F)
	_key(KEY_F, false)


func _right_mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	root.push_input(event)


func _look(displacement: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.screen_relative = displacement
	# Deliberately different from screen_relative: viewport scaling must not affect looking.
	event.relative = displacement * 0.25
	root.push_input(event)


func _run() -> void:
	var scene = load("res://src/gameplay/reception_25d/scenes/reception.tscn").instantiate()
	root.add_child(scene)
	var camera = scene.get_node("RoomViewport/Room/ReceptionCamera")
	var debug = scene.get_node("DebugFreeCamera")
	var indicator = scene.get_node("ElevatorUI/ExplorationIndicator")
	var initial: Transform3D = camera.transform
	var initial_global: Transform3D = camera.global_transform
	# Control integration deterministically; automatic callbacks are tested separately below.
	camera.set_process(false)
	_check(not debug.active and not indicator.visible, "Must start at reception with no indicator")
	_check(debug.enable_debug_exploration and camera.fov == 70.0, "Debug enabled; original FOV")
	_check(scene.get_node("RoomViewport").size == Vector2i(640, 360), "Original viewport size")
	camera.rotation.y = 0.3
	camera._target_yaw = 0.5
	_toggle()
	debug.set_process(false)
	_check(debug.active and camera.debug_exploration_active and indicator.visible, "F activates exploration")
	var before: Transform3D = camera.transform
	camera._process(0.5)
	_check(camera.transform == before, "Edge controller suspended even if UI enables processing")
	_key(KEY_F, true, true)
	_check(debug.active, "Key repeat must not toggle")
	_right_mouse(true)
	_look(Vector2(400, -10000))
	_check(is_equal_approx(camera.global_rotation.x, deg_to_rad(debug.pitch_limit)), "Pitch clamped")
	_check(is_equal_approx(camera.global_rotation.y, 0.3 - deg_to_rad(400 * debug.mouse_sensitivity)), "Unscaled mouse yaw")
	_right_mouse(false)
	_check(not debug._looking and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse released")
	before = camera.transform
	_look(Vector2(200, 200))
	_check(camera.transform == before, "Mouse without RMB must not turn")
	var start: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	_key(KEY_W)
	debug._process(1.0)
	_key(KEY_W, false)
	var distance: float = camera.global_position.distance_to(start)
	_check(is_equal_approx(camera.global_position.y, start.y), "W never changes height while pitched")
	_check((camera.global_position - start).normalized().is_equal_approx(forward.normalized()), "W follows view projected on XZ")
	_toggle()
	_check(camera.transform == initial and camera.global_transform == initial_global, "Restore exact initial local/global transform, not pre-entry yaw")
	_check(camera._target_yaw == 0.0 and not camera.debug_exploration_active, "Clear normal interpolation state")
	_check(not indicator.visible and debug._velocity == Vector3.ZERO, "Hide indicator and clear velocity")
	_toggle()
	debug.set_process(false)
	_key(KEY_W)
	_key(KEY_SHIFT)
	start = camera.global_position
	debug._process(1.0)
	_check(is_equal_approx(camera.global_position.distance_to(start), distance * debug.fast_speed_multiplier), "Shift multiplies speed")
	_key(KEY_W, false)
	_key(KEY_SHIFT, false)
	_key(KEY_Q)
	debug._process(10.0)
	_check(is_equal_approx(camera.global_position.y, debug.floor_reference.global_position.y + debug.minimum_height), "Minimum height uses actual global floor")
	_key(KEY_Q, false)
	_key(KEY_E)
	debug._process(1.0)
	_check(camera.global_position.y > start.y, "E raises camera")
	_key(KEY_E, false)
	_right_mouse(true)
	debug._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(not debug._looking and debug._keys.is_empty(), "Focus loss clears held input and capture")
	_toggle()
	# Exact integration should match across frame rates, including acceleration/coasting.
	var positions: Array[Vector3] = []
	for fps in [30, 144]:
		_toggle()
		debug.set_process(false)
		_key(KEY_D)
		for frame in range(fps):
			debug._process(1.0 / fps)
		_key(KEY_D, false)
		for frame in range(fps):
			debug._process(1.0 / fps)
		positions.append(camera.global_position)
		_toggle()
	_check(positions[0].distance_to(positions[1]) < 0.0001, "Frame independent smoothing/displacement")
	for iteration in range(20):
		_toggle()
		debug.set_process(false)
		camera.global_position += Vector3(4, 2, -6)
		_right_mouse(true)
		_look(Vector2(-2000, 1000))
		_toggle()
		_check(camera.transform == initial and camera.global_transform == initial_global, "Repeated exact restoration %d" % iteration)
		_check(not debug._looking and camera._target_yaw == 0.0, "Repeated controller/mouse reset")
	_toggle()
	debug.enable_debug_exploration = false
	_check(not debug.active and camera.transform == initial, "Disabling while active restores camera")
	_toggle()
	_key(KEY_W)
	_right_mouse(true)
	_look(Vector2(300, 300))
	_check(not debug.active and camera.transform == initial and not debug._looking, "Disabled controls have no effect")
	_right_mouse(false)
	_key(KEY_W, false)
	debug.enable_debug_exploration = true
	_toggle()
	# Exercise preserved shortcuts, buttons, NPC motion and door states during exploration.
	var harness = scene.get_node("VisitorMovementTest")
	var selection = scene.get_node("ElevatorSelection")
	var orientation = scene.get_node("VisitorOrientation")
	_key(KEY_P)
	_check(orientation.orientation_mode == 0 and not paused, "P still toggles billboard without global cheat menu")
	_key(KEY_P)
	_check(orientation.orientation_mode == 1, "P returns to PAPER")
	for entrance in [KEY_1, KEY_2]:
		_key(entrance)
		_check(harness._waiting_for_open, "Entrance shortcut preserved")
		_key(KEY_R)
		_check(not harness._waiting_for_open and debug.active, "R resets visitor without leaving exploration")
	_key(KEY_2)
	var frames := 0
	while not selection.can_select and frames < 2400:
		await process_frame
		frames += 1
	_check(selection.can_select, "Visitor reaches service during exploration")
	var button = scene.get_node("ElevatorUI/Selection/Elevator1")
	_check(not button.disabled, "Elevator button available")
	button.pressed.emit()
	frames = 0
	var door = scene.get_node("RoomViewport/Room/Elevators/Elevator01")
	while frames < 2400 and not (selection.stage == 6 and door.state == 0):
		await process_frame
		frames += 1
	_check(selection.stage == 6 and door.state == 0, "Visitor boards and elevator closes during exploration")
	_check(scene.get_node("VisitorMovement").movement_speed == 3.0, "NPC speed preserved")
	_toggle()
	camera.set_process(true)
	camera._target_yaw = 0.2
	camera._process(0.01)
	_check(camera.rotation.y != initial.basis.get_euler().y, "Normal camera controller resumes")
	scene.queue_free()
	await process_frame
	print("DEBUG_FREE_CAMERA_TEST failures=", failures)
	quit(1 if failures else 0)
