extends Node2D
## Tutorial antes da recepção: narração da história do protagonista e a Marta explicando o trabalho.
## Espaço acelera/continua cada fala; o botão "Pular tutorial" (ou Esc) vai direto para a recepção.

const RECEPTION_SCENE := "res://src/levels/scenes/reception.tscn"

@export var roteiro: TutorialScript
@export var marta_scene: PackedScene
@export var chars_per_second: float = 40.0
## Título mostrado na transição para a recepção.
@export var titulo_dia: String = "Dia 1"

var _finished: bool = false
var _narration_active: bool = false
var _advance_requested: bool = false
var _narration_tween: Tween
var _highlight_tween: Tween
var _marta: Node2D = null

@onready var _narration: ColorRect = %Narration
@onready var _narration_label: Label = %NarrationLabel
@onready var _narration_hint: Label = %NarrationHint
@onready var _highlight: Panel = %Highlight
@onready var _elevator_panel: ElevatorPanel = %ElevatorPanel


func _ready() -> void:
	%SkipButton.pressed.connect(_go_to_reception)
	_elevator_panel.set_panel_locked(true)
	_highlight.visible = false
	Dialogue.clear_dialogue()
	_run()


func _run() -> void:
	if roteiro == null:
		_go_to_reception()
		return

	for step in roteiro.passos:
		if _finished:
			return
		if step.falante.is_empty():
			await _show_narration(step.texto)
		else:
			if _narration.visible:
				await _enter_reception()
			if _finished:
				return
			_set_highlight(step.destaque)
			Dialogue.display_dialogue(step.falante, step.texto, true)
			await Dialogue.wait_for_advance(0.0)

	_go_to_reception()


## Narração em tela escura, com o mesmo esquema de Espaço da caixa de fala.
func _show_narration(text: String) -> void:
	_narration.visible = true
	_narration.modulate.a = 1.0
	_narration_label.text = text
	_narration_hint.text = "[Espaço] acelerar"
	_narration_active = true
	_advance_requested = false

	_narration_label.visible_ratio = 0.0
	_narration_tween = create_tween()
	_narration_tween.tween_property(_narration_label, "visible_ratio", 1.0, text.length() / chars_per_second)
	_narration_tween.finished.connect(_on_narration_typed)

	while not _advance_requested and not _finished:
		await get_tree().process_frame
	_narration_active = false


func _on_narration_typed() -> void:
	_narration_label.visible_ratio = 1.0
	_narration_hint.text = "[Espaço] continuar"


## Fim da narração: a tela escura some e a Marta entra na janela.
func _enter_reception() -> void:
	var fade := create_tween()
	fade.tween_property(_narration, "modulate:a", 0.0, 0.6)
	await fade.finished
	_narration.visible = false

	if marta_scene == null or _finished:
		return
	_marta = marta_scene.instantiate() as Node2D
	# A Marta usa o script do visitante: mesma escala do começo ao fim (arte 256 px em tamanho real)
	_marta.queue_scale = Vector2.ONE
	_marta.desk_scale = Vector2.ONE
	%Actors.add_child(_marta)
	_marta.global_position = %MartaSpawnPoint.global_position

	var arrived := [false]
	_marta.move_to_slot(%MartaPoint.global_position, func(): arrived[0] = true, true)
	while not arrived[0] and not _finished:
		await get_tree().process_frame


func _set_highlight(destaque: int) -> void:
	if _highlight_tween:
		_highlight_tween.kill()
	var target: Control = _highlight_target(destaque)
	if target == null:
		_highlight.visible = false
		return
	# Lê a posição real do elemento: se a HUD mudar de lugar, o destaque acompanha
	var rect: Rect2 = target.get_global_rect()
	_highlight.position = rect.position - Vector2(2, 2)
	_highlight.size = rect.size + Vector2(4, 4)
	_highlight.visible = true
	_highlight.modulate.a = 1.0
	_highlight_tween = create_tween().set_loops()
	_highlight_tween.tween_property(_highlight, "modulate:a", 0.25, 0.5)
	_highlight_tween.tween_property(_highlight, "modulate:a", 1.0, 0.5)


## Elemento da tela que cada destaque contorna.
func _highlight_target(destaque: int) -> Control:
	match destaque:
		TutorialStep.Destaque.FALA:
			return Dialogue.get_node_or_null("Board")
		TutorialStep.Destaque.LIVRO:
			return %ReceptionHUD.get_node_or_null("CompanyBook")
		TutorialStep.Destaque.REGRAS:
			return %ReceptionHUD.get_node_or_null("RulesBoard")
		TutorialStep.Destaque.CRACHA:
			return %ReceptionHUD.get_node_or_null("Badge")
		TutorialStep.Destaque.PAINEL:
			return _elevator_panel.get_node_or_null("Panel")
	return null


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_to_reception()
		return
	if not _narration_active or not event.is_action_pressed("ui_accept"):
		return
	get_viewport().set_input_as_handled()
	if _narration_tween and _narration_tween.is_running():
		# 1º aperto: completa o texto na hora
		_narration_tween.kill()
		_on_narration_typed()
	else:
		# 2º aperto: próxima fala
		_advance_requested = true


func _go_to_reception() -> void:
	if _finished:
		return
	_finished = true
	Dialogue.clear_dialogue() # também encerra a espera de Espaço em andamento
	_set_highlight(TutorialStep.Destaque.NENHUM)
	# Escurece, mostra o título do dia e clareia já na recepção
	SceneTransition.transition_to(RECEPTION_SCENE, titulo_dia)
