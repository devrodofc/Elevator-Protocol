extends Control

@onready var badge: TextureRect = $Badge
@onready var badge_details: Control = $BadgeOverlay/BadgeDetails

var _badge_scale: Vector2
var _hover_tween: Tween
var _badge_position: Vector2
var _transfer_tween: Tween
var _badge_interactive: bool = false
var _current_visitor: Visitor

const TRANSFER_DURATION: float = 0.5
const VISITOR_BADGE_OFFSET := Vector2(0.0, -24.0)


func _ready() -> void:
	_badge_scale = badge.scale
	badge.pivot_offset = badge.size * 0.5
	_badge_position = badge.position
	badge.hide()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.mouse_entered.connect(_on_badge_mouse_entered)
	badge.mouse_exited.connect(_on_badge_mouse_exited)
	badge.gui_input.connect(_on_badge_gui_input)
	badge_details.toggled.connect(_on_badge_toggled)


func set_current_visitor(visitor: Visitor, visit_name: String = "", cracha: Dictionary = {}) -> void:
	if visitor == null:
		if is_instance_valid(_current_visitor) and badge.visible:
			_collect_badge(_current_visitor)
		else:
			badge_details.set_visitor(null)
		_current_visitor = null
		return
	_cancel_badge_tweens()
	_current_visitor = visitor
	badge_details.set_visitor(visitor, visit_name, cracha)
	badge.position = _visitor_badge_position(visitor)
	badge.scale = _badge_scale * 0.3
	badge.show()
	_transfer_tween = create_tween().set_parallel(true)
	_transfer_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transfer_tween.tween_property(badge, "position", _badge_position, TRANSFER_DURATION)
	_transfer_tween.tween_property(badge, "scale", _badge_scale, TRANSFER_DURATION)
	_transfer_tween.chain().tween_callback(func():
		_badge_interactive = true
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
	)


func _cancel_badge_tweens() -> void:
	_badge_interactive = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	if _transfer_tween and _transfer_tween.is_valid():
		_transfer_tween.kill()
	badge_details.close()


func _visitor_badge_position(visitor: Visitor) -> Vector2:
	# Passa pelo espaço do viewport para respeitar câmera e CanvasLayer.
	var viewport_position: Vector2 = visitor.get_global_transform_with_canvas() * VISITOR_BADGE_OFFSET
	return get_global_transform_with_canvas().affine_inverse() * viewport_position - badge.pivot_offset


func _collect_badge(visitor: Visitor) -> void:
	_cancel_badge_tweens()
	badge.scale = _badge_scale
	var start_position: Vector2 = badge.position
	var target_position: Vector2 = _visitor_badge_position(visitor)
	var visitor_ref: WeakRef = weakref(visitor)
	_transfer_tween = create_tween().set_parallel(true)
	_transfer_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transfer_tween.tween_method(func(weight: float):
		var moving_visitor: Visitor = visitor_ref.get_ref() as Visitor
		if is_instance_valid(moving_visitor):
			target_position = _visitor_badge_position(moving_visitor)
		badge.position = start_position.lerp(target_position, weight)
	, 0.0, 1.0, TRANSFER_DURATION)
	_transfer_tween.tween_property(badge, "scale", _badge_scale * 0.3, TRANSFER_DURATION)
	_transfer_tween.chain().tween_callback(func():
		badge.hide()
		badge.position = _badge_position
		badge.scale = _badge_scale
		badge_details.set_visitor(null)
	)


func _on_badge_mouse_entered() -> void:
	_tween_badge(_badge_scale * 1.15)


func _on_badge_mouse_exited() -> void:
	_tween_badge(_badge_scale)


func _tween_badge(target: Vector2) -> void:
	if not _badge_interactive:
		return
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(badge, "scale", target, 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_badge_gui_input(event: InputEvent) -> void:
	if not _badge_interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		badge.accept_event()
		badge_details.open()


func _on_badge_toggled(is_open: bool) -> void:
	if is_open:
		_tween_badge(_badge_scale)
