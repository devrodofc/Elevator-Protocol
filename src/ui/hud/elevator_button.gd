class_name ElevatorButton
extends Control
## Botão do painel do elevador, desenhado com os sprites da arte.
## Estados: normal, selecionado (afundado, com borda amarela) e travado (escurecido).

signal pressed(code: int)

## Código enviado ao apertar: andar (1 a 6), -1 = subsolo, 999 = negar.
@export var code: int = 1
## Texto desenhado por cima do sprite (vazio quando o sprite já tem o desenho, ex.: X e Confirmar).
@export var texto: String = ""
@export var normal_texture: Texture2D
## Sprite do botão afundado. Fica alinhado pela base do normal.
@export var selected_texture: Texture2D

var selected: bool = false: set = set_selected
var disabled: bool = false: set = set_disabled

@onready var _normal: TextureRect = $Normal
@onready var _selected: TextureRect = $Selected
@onready var _label: Label = $Label


func _ready() -> void:
	_normal.texture = normal_texture
	_selected.texture = selected_texture
	var normal_size: Vector2 = normal_texture.get_size() if normal_texture else size
	var selected_size: Vector2 = selected_texture.get_size() if selected_texture else normal_size
	size = normal_size
	# O sprite afundado é mais baixo (sem a sombra): alinha pela base
	_selected.position = Vector2(0, normal_size.y - selected_size.y)
	_label.size = Vector2(normal_size.x, selected_size.y)
	_label.text = texto
	_refresh()


func set_selected(value: bool) -> void:
	selected = value
	if is_node_ready():
		_refresh()


func set_disabled(value: bool) -> void:
	disabled = value
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	_normal.visible = not selected
	_selected.visible = selected
	_label.position.y = _selected.position.y if selected else 0.0
	modulate = Color(0.72, 0.72, 0.72) if disabled else Color.WHITE
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Audio.play_sfx(Audio.BOTAO)
		pressed.emit(code)
