extends Camera3D

@export_range(0.0, 180.0, 1.0) var rotation_speed: float = 65.0 # Degrees per second.
@export_range(0.0, 30.0, 0.1) var smoothing: float = 8.0 # 0 applies rotation immediately.
@export_range(0.0, 89.0, 1.0) var rotation_limit: float = 55.0 # Degrees from the initial view.
@export_range(0.01, 0.45, 0.01) var edge_width: float = 0.18 # Fraction of each screen edge.
## A/D and the arrow keys also turn the view (3D game scene). Off in the experimental scenes.
@export var keyboard_look: bool = false

var _initial_yaw: float
var _target_yaw: float = 0.0
var debug_exploration_active: bool = false
## Set by the game while the pointer is over something clickable: the edges do not turn the view.
var edge_hold: bool = false
## Extra yaw/pitch/roll added by effects (shake, glances); never accumulates into the player's yaw.
var effect_rotation: Vector3 = Vector3.ZERO
var _base_pitch: float
var _base_roll: float


func _ready() -> void:
	_initial_yaw = rotation.y
	_base_pitch = rotation.x
	_base_roll = rotation.z


func _process(delta: float) -> void:
	if debug_exploration_active:
		return
	# Use the window viewport: the 3D view renders at a fixed 640x360.
	var window := get_tree().root
	var screen := window.get_visible_rect()
	var mouse := window.get_mouse_position()
	var direction := 0.0
	if window.has_focus() and screen.has_point(mouse) and not edge_hold:
		var horizontal := (mouse.x - screen.position.x) / screen.size.x
		if horizontal < edge_width:
			direction = 1.0 - horizontal / edge_width
		elif horizontal > 1.0 - edge_width:
			direction = -(horizontal - (1.0 - edge_width)) / edge_width
	if keyboard_look and window.has_focus():
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			direction = 1.0
		elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			direction = -1.0

	var limit := deg_to_rad(rotation_limit)
	_target_yaw = clampf(_target_yaw + direction * deg_to_rad(rotation_speed) * delta, -limit, limit)
	var weight := 1.0 if smoothing <= 0.0 else 1.0 - exp(-smoothing * delta)
	var yaw := clampf(lerpf(rotation.y - effect_rotation.y - _initial_yaw, _target_yaw, weight), -limit, limit)
	rotation.y = _initial_yaw + yaw + effect_rotation.y
	if keyboard_look:
		rotation.x = _base_pitch + effect_rotation.x
		rotation.z = _base_roll + effect_rotation.z


## Player's yaw relative to the initial view, in radians (positive = looking left).
func look_yaw() -> float:
	return rotation.y - effect_rotation.y - _initial_yaw


## Turns the view back to the counter (smoothly).
func recenter() -> void:
	_target_yaw = 0.0


func reset_debug_exploration() -> void:
	_target_yaw = 0.0
	debug_exploration_active = false
