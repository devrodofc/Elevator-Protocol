extends CanvasLayer
## Caixa de fala global (autoload "Dialogue"). Só exibe; o jogador não responde.
##   Dialogue.display_dialogue("Carlos", "Andar 2, por favor.")
##   Dialogue.clear_dialogue()
## A fala fica na tela até clear_dialogue(), para o jogador ler enquanto decide.

## Emitido quando o texto termina de aparecer.
signal finished

## Letras por segundo. 0 = o texto aparece inteiro na hora.
@export var chars_per_second: float = 40.0

var _tween: Tween

@onready var _name_label: Label = %NameLabel
@onready var _text_label: Label = %TextLabel


func _ready() -> void:
	clear_dialogue()


func display_dialogue(speaker: String, text: String) -> void:
	_kill_tween()
	_name_label.text = speaker
	_name_label.visible = not speaker.is_empty()
	_text_label.text = text
	visible = true

	var char_count := _text_label.get_total_character_count()
	if chars_per_second <= 0.0 or char_count == 0:
		_on_text_complete()
		return

	_text_label.visible_ratio = 0.0
	_tween = create_tween()
	_tween.tween_property(_text_label, "visible_ratio", 1.0, char_count / chars_per_second)
	_tween.finished.connect(_on_text_complete)


func clear_dialogue() -> void:
	_kill_tween()
	visible = false


func is_open() -> bool:
	return visible


func _on_text_complete() -> void:
	_text_label.visible_ratio = 1.0
	finished.emit()


func _kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null
