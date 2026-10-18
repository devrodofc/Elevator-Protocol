class_name ElevatorPanel
extends Control
## Painel do elevador: o jogador seleciona um andar (ou X para negar) e aperta Confirmar.
## A recepção escuta floor_selected e trava/destrava o painel com set_panel_locked().

signal floor_selected(floor_number: int)

const DENY_CODE: int = 999
const SUBSOLO_CODE: int = -1
## Carregado pelo caminho (e não pelo class_name) para não depender do cache de classes do editor.
const ElevatorButtonScript := preload("res://src/ui/hud/elevator_button.gd")

var locked: bool = true

var _selected_code: Variant = null
var _floor_buttons: Array[Control] = []

@onready var _confirm: Control = %ConfirmButton


func _ready() -> void:
	for child in %Buttons.get_children():
		if child.get_script() == ElevatorButtonScript and child != _confirm:
			_floor_buttons.append(child)
			child.pressed.connect(_on_floor_pressed)
	_confirm.pressed.connect(_on_confirm_pressed)
	set_panel_locked(locked)


func set_panel_locked(is_locked: bool) -> void:
	locked = is_locked
	for button in _floor_buttons:
		button.disabled = is_locked
	if is_locked:
		_select(null)
	_confirm.disabled = is_locked or _selected_code == null


func _on_floor_pressed(code: int) -> void:
	if locked:
		return
	# Apertar o botão já selecionado tira a seleção
	_select(null if _selected_code == code else code)


func _select(code: Variant) -> void:
	_selected_code = code
	for button in _floor_buttons:
		button.selected = code != null and button.code == code
	_confirm.disabled = locked or code == null


func _on_confirm_pressed(_code: int) -> void:
	if locked or _selected_code == null:
		return
	var chosen: int = _selected_code
	locked = true # bloqueia cliques enquanto o Confirmar aparece afundado
	_confirm.selected = true
	await get_tree().create_timer(0.15).timeout
	_confirm.selected = false
	set_panel_locked(true)
	floor_selected.emit(chosen)
