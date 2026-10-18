extends CanvasLayer
## Caixa de fala global (autoload "Dialogue"). Só exibe; o jogador não responde.
##   Dialogue.display_dialogue("Carlos", "Andar 2, por favor.")
##   Dialogue.clear_dialogue()
## A fala fica na tela até clear_dialogue(), para o jogador ler enquanto decide.
##
## Falas aceleráveis (ex.: Marta) mostram o aviso "[Espaço] acelerar":
##   Dialogue.display_dialogue("Marta", texto, true)
##   await Dialogue.wait_for_advance(10.0)  # termina no tempo ou quando o jogador aperta Espaço

## Emitido quando o texto termina de aparecer.
signal finished

## Letras por segundo. 0 = o texto aparece inteiro na hora.
@export var chars_per_second: float = 40.0
## Ação que acelera a fala (ui_accept = Espaço ou Enter).
@export var skip_action: StringName = &"ui_accept"

var _tween: Tween
var _skippable: bool = false
var _advance_requested: bool = false

@onready var _name_label: Label = %NameLabel
@onready var _text_label: Label = %TextLabel
@onready var _skip_hint: Label = %SkipHint


func _ready() -> void:
	clear_dialogue()


func display_dialogue(speaker: String, text: String, skippable: bool = false) -> void:
	_kill_tween()
	_skippable = skippable
	_skip_hint.visible = skippable
	_skip_hint.text = "[Espaço] acelerar"
	_advance_requested = false
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
	_skippable = false
	visible = false


func is_open() -> bool:
	return visible


## Espera até max_seconds ou até o jogador apertar Espaço com a fala já completa.
## max_seconds <= 0: sem limite de tempo, espera só o jogador.
func wait_for_advance(max_seconds: float = 0.0) -> void:
	_advance_requested = false
	var elapsed := 0.0
	while (max_seconds <= 0.0 or elapsed < max_seconds) and not _advance_requested:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_advance_requested = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _skippable or not event.is_action_pressed(skip_action):
		return
	get_viewport().set_input_as_handled()
	if _is_typing():
		# 1º aperto: completa o texto na hora
		_kill_tween()
		_on_text_complete()
	else:
		# 2º aperto: encerra a espera
		_advance_requested = true


func _on_text_complete() -> void:
	_text_label.visible_ratio = 1.0
	_skip_hint.text = "[Espaço] continuar"
	finished.emit()


func _is_typing() -> bool:
	return _tween != null and _tween.is_running()


func _kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null
