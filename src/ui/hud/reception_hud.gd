extends Control

@onready var badge: TextureRect = $Badge
@onready var badge_details: Control = $BadgeOverlay/BadgeDetails

var _badge_scale: Vector2
var _hover_tween: Tween


func _ready() -> void:
	_badge_scale = badge.scale
	badge.pivot_offset = badge.size * 0.5
	badge.mouse_entered.connect(_on_badge_mouse_entered)
	badge.mouse_exited.connect(_on_badge_mouse_exited)
	badge.gui_input.connect(_on_badge_gui_input)
	badge_details.toggled.connect(_on_badge_toggled)


func set_current_visitor(visitor: Visitor, visit_name: String = "") -> void:
	badge_details.set_visitor(visitor, visit_name)


func _on_badge_mouse_entered() -> void:
	_tween_badge(_badge_scale * 1.15)


func _on_badge_mouse_exited() -> void:
	_tween_badge(_badge_scale)


func _tween_badge(target: Vector2) -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(badge, "scale", target, 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_badge_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		badge.accept_event()
		badge_details.open()


func _on_badge_toggled(is_open: bool) -> void:
	if is_open:
		_tween_badge(_badge_scale)
