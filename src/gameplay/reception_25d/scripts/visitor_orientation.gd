extends Node

const VisitorMovement = preload("res://src/gameplay/reception_25d/scripts/visitor_movement.gd")

enum Mode { BILLBOARD, PAPER }

@export var orientation_mode: Mode = Mode.PAPER
@export_range(1.0, 720.0, 1.0, "or_greater", "suffix:°/s") var rotation_speed: float = 180.0
@export var sprite: Sprite3D
@export var movement: VisitorMovement
@export var service_point: Marker3D
@export var camera: Camera3D

var _previous_position: Vector3
var _target_yaw: float
var _original_billboard: int
var _original_rotation: Vector3
var _original_global_scale: Vector3
var _applied_mode: int = -1
var _idle_facing_target: Node3D


func _ready() -> void:
	_original_billboard = sprite.billboard
	_original_rotation = sprite.rotation
	_original_global_scale = sprite.global_basis.get_scale()
	_previous_position = movement.visitor.global_position
	_apply_mode()


func _input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var key: Key = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	if key == KEY_P:
		# Consume P locally before the global cheat menu; other scenes keep their shortcut.
		orientation_mode = Mode.PAPER if orientation_mode == Mode.BILLBOARD else Mode.BILLBOARD
		_apply_mode()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _applied_mode != orientation_mode:
		_apply_mode()
	var position := movement.visitor.global_position
	var direction := position - _previous_position
	_previous_position = position
	direction.y = 0.0
	if orientation_mode == Mode.BILLBOARD:
		return
	if movement.visitor.is_visible_in_tree() and movement.is_processing():
		if direction.length_squared() > 0.000001:
			# Sprite3D's front is local +Z. Observe movement without changing its path.
			_target_yaw = atan2(direction.x, direction.z)
	else:
		var target: Node3D = _idle_facing_target
		if target == null and position.distance_squared_to(service_point.global_position) < 0.0001:
			target = camera
		if is_instance_valid(target):
			var facing := target.global_position - position
			if Vector2(facing.x, facing.z).length_squared() > 0.000001:
				_target_yaw = atan2(facing.x, facing.z)
	# Rotate only the visual around world Y; its height and the ground anchor stay untouched.
	var yaw := rotate_toward(sprite.global_rotation.y, _target_yaw, deg_to_rad(rotation_speed) * delta)
	_set_visual_yaw(yaw)


func face_when_idle(target: Node3D) -> void:
	_idle_facing_target = target


func _set_visual_yaw(yaw: float) -> void:
	# Rebuild from the saved scale instead of accumulating basis decomposition error.
	sprite.global_basis = Basis(Vector3.UP, yaw).scaled(_original_global_scale)


func _apply_mode() -> void:
	if orientation_mode == Mode.BILLBOARD:
		sprite.billboard = _original_billboard
		sprite.rotation = _original_rotation
	else:
		# Start at the fixed-Y billboard's current camera-facing angle to avoid a visual snap.
		var facing := camera.global_basis.z
		_target_yaw = atan2(facing.x, facing.z)
		_set_visual_yaw(_target_yaw)
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_applied_mode = orientation_mode
