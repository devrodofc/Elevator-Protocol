extends CanvasLayer
## Caixa de fala global (autoload "Dialogue"). Só exibe; o jogador não responde.
##   Dialogue.display_dialogue("Carlos", "Andar 2, por favor.")
##   Dialogue.clear_dialogue()
## A fala fica na tela até clear_dialogue(), para o jogador ler enquanto decide.
##
## Fala maior que o balão é dividida em páginas: Espaço passa para a próxima.
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
## Páginas da fala atual (cada uma cabe no balão) e a que está na tela
var _pages: PackedStringArray = []
var _page: int = 0

@onready var _name_label: Label = %NameLabel
@onready var _text_label: Label = %TextLabel
@onready var _skip_hint: Label = %SkipHint


func _ready() -> void:
	clear_dialogue()


func display_dialogue(speaker: String, text: String, skippable: bool = false) -> void:
	_kill_tween()
	_skippable = skippable
	_advance_requested = false
	_name_label.text = speaker
	_name_label.visible = not speaker.is_empty()
	visible = true
	_pages = _paginate(text)
	_show_page(0)


func _show_page(index: int) -> void:
	_kill_tween()
	_page = index
	_skip_hint.visible = _skippable
	_skip_hint.text = "[Espaço] acelerar"
	_text_label.text = _pages[index]

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
	_advance_requested = true # encerra qualquer wait_for_advance() em andamento
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
	if not visible or not event.is_action_pressed(skip_action):
		return
	var has_next_page: bool = _page < _pages.size() - 1
	if not _skippable and not has_next_page:
		return
	get_viewport().set_input_as_handled()
	if _is_typing():
		if not _skippable:
			return
		# 1º aperto: completa o texto na hora
		_kill_tween()
		_on_text_complete()
	elif has_next_page:
		# Fala longa: próxima página
		_show_page(_page + 1)
	else:
		# Última página: encerra a espera
		_advance_requested = true


func _on_text_complete() -> void:
	_text_label.visible_ratio = 1.0
	var has_next_page: bool = _page < _pages.size() - 1
	_skip_hint.visible = _skippable or has_next_page
	_skip_hint.text = "[Espaço] continuar"
	# A fala só "termina" na última página
	if not has_next_page:
		finished.emit()


## Divide o texto em páginas que cabem no balão. Cada página termina, se der, no fim de uma
## frase (. ! ? ...); senão, entre palavras.
func _paginate(text: String) -> PackedStringArray:
	var pages: PackedStringArray = []
	_text_label.visible_ratio = 1.0
	_text_label.text = text
	if _text_label.get_line_count() <= _text_label.get_visible_line_count():
		pages.append(text)
		return pages

	var max_lines: int = maxi(1, _text_label.get_visible_line_count())
	var words: PackedStringArray = text.split(" ", false)
	var current: Array[String] = []
	var i := 0
	while i < words.size():
		current.append(words[i])
		_text_label.text = " ".join(current)
		if _text_label.get_line_count() > max_lines and current.size() > 1:
			current.pop_back()
			# Volta até o fim da última frase da página (sem deixar a página quase vazia)
			var cut: int = current.size()
			for j in range(current.size() - 1, current.size() / 2 - 1, -1):
				if current[j].ends_with(".") or current[j].ends_with("!") or current[j].ends_with("?"):
					cut = j + 1
					break
			pages.append(" ".join(current.slice(0, cut)))
			i -= current.size() - cut # as palavras depois do corte vão para a próxima página
			current.clear()
		else:
			i += 1
	if not current.is_empty():
		pages.append(" ".join(current))
	_balance_last_page(pages)
	return pages


## Evita a última página com 1-2 palavras soltas: passa o fim da página anterior para ela,
## cortando de preferência depois de uma vírgula ou fim de frase.
func _balance_last_page(pages: PackedStringArray) -> void:
	const MIN_WORDS := 4
	if pages.size() < 2:
		return
	var last: PackedStringArray = pages[-1].split(" ", false)
	if last.size() >= MIN_WORDS:
		return
	var previous: PackedStringArray = pages[-2].split(" ", false)
	var cut: int = previous.size() - (MIN_WORDS - last.size())
	for j in range(previous.size() - 2, maxi(0, previous.size() - 10), -1):
		var w: String = previous[j]
		if w.ends_with(",") or w.ends_with(".") or w.ends_with("!") or w.ends_with("?") or w.ends_with(":"):
			cut = j + 1
			break
	cut = clampi(cut, 1, previous.size() - 1)
	pages[-2] = " ".join(previous.slice(0, cut))
	pages[-1] = " ".join(previous.slice(cut)) + " " + pages[-1]


func _is_typing() -> bool:
	return _tween != null and _tween.is_running()


func _kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null
