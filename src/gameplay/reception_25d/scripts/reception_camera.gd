extends Camera3D

@export_range(0.0, 180.0, 1.0) var rotation_speed: float = 65.0 # Degrees per second.
@export_range(0.0, 30.0, 0.1) var smoothing: float = 8.0 # 0 applies rotation immediately.
@export_range(0.0, 89.0, 1.0) var rotation_limit: float = 55.0 # Degrees from the initial view.
@export_range(0.01, 0.45, 0.01) var edge_width: float = 0.18 # Fraction of each screen edge.

var _initial_yaw: float
var _target_yaw: float = 0.0
var debug_exploration_active: bool = false


func _ready() -> void:
	_initial_yaw = rotation.y


func _process(delta: float) -> void:
	if debug_exploration_active:
		return
	# Use the window viewport: the 3D view renders at a fixed 640x360.
	var window := get_tree().root
	var screen := window.get_visible_rect()
	var mouse := window.get_mouse_position()
	var direction := 0.0
	if window.has_focus() and screen.has_point(mouse):
		var horizontal := (mouse.x - screen.position.x) / screen.size.x
		if horizontal < edge_width:
			direction = 1.0 - horizontal / edge_width
		elif horizontal > 1.0 - edge_width:
			direction = -(horizontal - (1.0 - edge_width)) / edge_width

	var limit := deg_to_rad(rotation_limit)
	_target_yaw = clampf(_target_yaw + direction * deg_to_rad(rotation_speed) * delta, -limit, limit)
	var weight := 1.0 if smoothing <= 0.0 else 1.0 - exp(-smoothing * delta)
	rotation.y = _initial_yaw + clampf(lerpf(rotation.y - _initial_yaw, _target_yaw, weight), -limit, limit)


func reset_debug_exploration() -> void:
	_target_yaw = 0.0
	debug_exploration_active = false
