extends Control
## Painel do elevador: o jogador escolhe um andar ou nega o acesso.
## A recepção escuta decision_made e chama unlock_controls() quando o visitante chega ao balcão.
## Atalhos de teclado: 1, 2, 3 = andares; N = negar.

signal decision_made(chosen_floor: int)

@onready var _buttons: Array[Button] = [%Floor1Button, %Floor2Button, %Floor3Button, %DenyButton]


func _ready() -> void:
	%Floor1Button.pressed.connect(_choose.bind(1))
	%Floor2Button.pressed.connect(_choose.bind(2))
	%Floor3Button.pressed.connect(_choose.bind(3))
	%DenyButton.pressed.connect(_choose.bind(VisitorData.DENY))
	lock_controls()


func unlock_controls() -> void:
	for button in _buttons:
		button.disabled = false


func lock_controls() -> void:
	for button in _buttons:
		button.disabled = true


func _choose(chosen_floor: int) -> void:
	lock_controls() # evita clique duplo antes da recepção processar
	decision_made.emit(chosen_floor)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or %DenyButton.disabled:
		return
	match event.keycode:
		KEY_1: _choose(1)
		KEY_2: _choose(2)
		KEY_3: _choose(3)
		KEY_N: _choose(VisitorData.DENY)
		_: return
	get_viewport().set_input_as_handled()
