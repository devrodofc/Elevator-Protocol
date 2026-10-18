extends Control
## Prancheta de regras na mesa: fica quase toda escondida embaixo da tela, mostrando só a parte de cima.
## Um clique faz ela subir inteira; outro clique (ou Esc) faz ela descer de novo.

signal toggled(is_open: bool)

## Quantos pixels da prancheta ficam visíveis quando ela está abaixada.
@export var peek_height: float = 46.0
## Distância da base da prancheta até a borda de baixo da tela quando ela está levantada.
@export var open_margin: float = 4.0
@export var slide_time: float = 0.25

var is_open: bool = false

var _tween: Tween


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	position.y = _closed_y()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	_slide_to(_open_y(), true)


func close() -> void:
	_slide_to(_closed_y(), false)


func _closed_y() -> float:
	return _screen_height() - peek_height


func _open_y() -> float:
	return _screen_height() - size.y - open_margin


func _screen_height() -> float:
	return get_viewport_rect().size.y


func _slide_to(target_y: float, opening: bool) -> void:
	if is_open == opening and is_equal_approx(position.y, target_y):
		return
	is_open = opening
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position:y", target_y, slide_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	toggled.emit(is_open)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		toggle()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
