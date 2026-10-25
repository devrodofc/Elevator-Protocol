extends Node
## Mouse positions are viewport logical pixels (Godot already applies window stretch).
const Interactable = preload("res://src/gameplay/reception_25d/scripts/desk_interactable.gd")
var room_view: Sprite2D
var room_viewport: SubViewport
var camera: Camera3D
var blocked: bool = false
var hovered: Interactable
var _pending_click: bool = false
var _click_position: Vector2


func viewport_position(main_position: Vector2) -> Vector2:
	var local := room_view.get_global_transform_with_canvas().affine_inverse() * main_position
	var rect := room_view.get_rect()
	if not rect.has_point(local) or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector2(-1, -1)
	var uv := (local - rect.position) / rect.size
	if room_view.flip_h:
		uv.x = 1.0 - uv.x
	if room_view.flip_v:
		uv.y = 1.0 - uv.y
	# A region displays a crop of the SubViewport texture.
	if room_view.region_enabled:
		return room_view.region_rect.position + uv * room_view.region_rect.size
	return uv * Vector2(room_viewport.size)


func pick(main_position: Vector2) -> Interactable:
	if blocked or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return null
	var point := viewport_position(main_position)
	if not Rect2(Vector2.ZERO, Vector2(room_viewport.size)).has_point(point):
		return null
	var origin := camera.project_ray_origin(point)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(point) * camera.far, Interactable.PICK_LAYER)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	# Nearest body wins. A disabled object still occludes objects behind it.
	var target: Interactable = hit.get("collider") as Interactable
	return target if target and target.available and target.is_visible_in_tree() else null


func set_blocked(value: bool) -> void:
	blocked = value
	_pending_click = false
	if value:
		_set_hover(null)


func _physics_process(_delta: float) -> void:
	_set_hover(pick(get_viewport().get_mouse_position()))
	if _pending_click:
		_pending_click = false
		var target := pick(_click_position)
		if target:
			target.activate()


func _unhandled_input(event: InputEvent) -> void:
	if blocked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click_position = event.position
		_pending_click = true
		get_viewport().set_input_as_handled()


func _set_hover(target: Interactable) -> void:
	if hovered == target:
		return
	if is_instance_valid(hovered):
		hovered.set_hover(false)
	hovered = target
	if hovered:
		hovered.set_hover(true)
