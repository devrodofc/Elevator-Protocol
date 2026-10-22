extends Control
## Tela de fim de jogo: epílogo narrado em tela escura, "Fim", créditos subindo e volta ao menu.
## Espaço acelera/continua o epílogo; Esc pula direto para o fim dos créditos.
## Aberta pela recepção quando o último dia termina (DayScheduleConfig.cena_final).

const MENU_SCENE := "res://src/ui/menus/scenes/menu.tscn"

## Epílogo (cada item é uma tela de narração). Constante, e não @export, para o editor não
## descartar a lista (ver CLAUDE.md, problema 1).
const EPILOGO := [
	"Três dias de trabalho. Três dias de visitantes, regras estranhas e um elevador que insistia em descer.",
	"Na sexta-feira, um e-mail: \"Parabéns! Seu período de experiência foi concluído. Bem-vindo à família. — Marta\"",
	"O entregador nunca mais apareceu. O Seu Tião também não. Ninguém no prédio parecia se lembrar deles.",
	"Mas o salário caiu na conta, certinho. E, depois de seis meses sem emprego... quem é você para fazer perguntas?",
	"Segunda-feira, oito horas. A Marta está esperando.",
]

## Créditos, de cima para baixo: [estilo, texto]. Estilos: titulo, sub, secao, nome, espaco.
const CREDITOS := [
	["titulo", "Elevator Protocol"],
	["sub", "Coffee & Games Studios"],
	["espaco", ""],
	["secao", "Arte e Sprites"],
	["nome", "Clara"],
	["espaco", ""],
	["secao", "Interface (UI/UX)"],
	["nome", "Mari"],
	["espaco", ""],
	["secao", "Música e efeitos sonoros"],
	["nome", "Daniel"],
	["espaco", ""],
	["secao", "Game Design"],
	["nome", "Rodrigo"],
	["espaco", ""],
	["secao", "Programação"],
	["nome", "Daniel"],
	["nome", "Gustavo"],
	["nome", "Rodrigo"],
	["espaco", ""],
	["secao", "Feito para a"],
	["nome", "GameJamPlus 2026/27"],
	["nome", "Tema: Something's Off"],
	["espaco", ""],
	["secao", "Feito com"],
	["nome", "Godot Engine"],
	["espaco", ""],
	["secao", "Nenhum entregador foi ferido na produção deste jogo."],
	["nome", "(A Marta garante.)"],
	["espaco", ""],
	["espaco", ""],
	["titulo", "Obrigado por jogar!"],
]

@export var chars_per_second: float = 35.0
## Quanto tempo os créditos levam para subir até o fim.
@export var duracao_creditos: float = 24.0

var _avancar: bool = false
var _digitando: Tween
var _rolagem: Tween
var _na_narracao: bool = false
var _nos_creditos: bool = false
var _terminou: bool = false
var _pulou: bool = false

@onready var _narracao: Label = %Narracao
@onready var _dica: Label = %Dica
@onready var _fim: Label = %Fim
@onready var _creditos: VBoxContainer = %Creditos
@onready var _voltar: LinkButton = %Voltar


func _ready() -> void:
	# Jogo novo depois daqui começa do dia 1
	ReceptionManager.dia_em_andamento = null
	var dialogo = get_node_or_null("/root/Dialogue")
	if dialogo:
		dialogo.clear_dialogue()
	var audio = get_node_or_null("/root/Audio")
	if audio:
		audio.fade_out_music(2.0)
		audio.stop_loop()

	_narracao.text = ""
	_dica.text = ""
	_fim.modulate.a = 0.0
	_voltar.visible = false
	_voltar.pressed.connect(_voltar_ao_menu)
	_montar_creditos()
	_rodar()


func _rodar() -> void:
	await get_tree().create_timer(1.0).timeout
	for texto in EPILOGO:
		if _nos_creditos:
			break
		await _narrar(texto)
	await _mostrar_fim()
	await _rolar_creditos()


## Uma tela de narração: digita o texto; Espaço completa e depois avança.
func _narrar(texto: String) -> void:
	_na_narracao = true
	_avancar = false
	_narracao.text = texto
	_narracao.visible_ratio = 0.0
	_narracao.modulate.a = 1.0
	_dica.text = "[Espaço] acelerar"
	_digitando = create_tween()
	_digitando.tween_property(_narracao, "visible_ratio", 1.0, texto.length() / chars_per_second)
	_digitando.tween_callback(func(): _dica.text = "[Espaço] continuar")
	while not _avancar and not _nos_creditos:
		await get_tree().process_frame
	_na_narracao = false
	_dica.text = ""
	var some := create_tween()
	some.tween_property(_narracao, "modulate:a", 0.0, 0.5)
	await some.finished


func _mostrar_fim() -> void:
	if _nos_creditos:
		return
	var tween := create_tween()
	tween.tween_property(_fim, "modulate:a", 1.0, 1.5)
	tween.tween_interval(2.0)
	tween.tween_property(_fim, "modulate:a", 0.0, 1.5)
	await tween.finished


func _rolar_creditos() -> void:
	_nos_creditos = true
	var musica = get_node_or_null("/root/MusicMenu")
	if musica and musica.has_method("play_if_stopped"):
		musica.play_if_stopped()
	_dica.text = "[Esc] pular"
	# Começa logo abaixo da tela e sobe até "Obrigado por jogar!" ficar no meio
	await get_tree().process_frame
	var altura_tela: float = size.y
	_creditos.position.y = altura_tela
	var ultimo: Control = _creditos.get_child(_creditos.get_child_count() - 1)
	var destino: float = altura_tela * 0.42 - ultimo.position.y
	if _pulou:
		_creditos.position.y = destino
		_mostrar_voltar()
		return
	_rolagem = create_tween()
	_rolagem.tween_property(_creditos, "position:y", destino, duracao_creditos)
	await _rolagem.finished
	_mostrar_voltar()


func _mostrar_voltar() -> void:
	if _terminou:
		return
	_terminou = true
	_dica.text = ""
	_voltar.visible = true
	_voltar.modulate.a = 0.0
	create_tween().tween_property(_voltar, "modulate:a", 1.0, 0.8)


## Esc: pula o que faltar e deixa os créditos parados no fim.
func _pular() -> void:
	_pulou = true
	_nos_creditos = true
	_avancar = true
	if _digitando:
		_digitando.kill()
	_narracao.modulate.a = 0.0
	_fim.modulate.a = 0.0
	if _rolagem and _rolagem.is_running():
		_rolagem.custom_step(duracao_creditos) # termina a subida na hora


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _terminou:
			_voltar_ao_menu()
		else:
			_pular()
		return
	if _na_narracao and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _digitando and _digitando.is_running():
			_digitando.custom_step(9999.0) # completa o texto
		else:
			_avancar = true


func _voltar_ao_menu() -> void:
	var transicao = get_node_or_null("/root/SceneTransition")
	if transicao:
		transicao.transition_to(MENU_SCENE)
	else:
		get_tree().change_scene_to_file(MENU_SCENE)


func _montar_creditos() -> void:
	var fonte: Font = load("res://assets/fonts/pixeloid_sans.ttf")
	var negrito: Font = load("res://assets/fonts/pixeloid_sans_bold.ttf")
	for item in CREDITOS:
		var estilo: String = item[0]
		var label := Label.new()
		label.text = item[1]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		match estilo:
			"titulo":
				label.add_theme_font_override("font", negrito)
				label.add_theme_font_size_override("font_size", 26)
				label.add_theme_color_override("font_color", Color(0.94, 0.5, 0.5))
			"sub":
				label.add_theme_font_override("font", fonte)
				label.add_theme_font_size_override("font_size", 14)
			"secao":
				label.add_theme_font_override("font", fonte)
				label.add_theme_font_size_override("font_size", 10)
				label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
			"nome":
				label.add_theme_font_override("font", negrito)
				label.add_theme_font_size_override("font_size", 14)
			_:
				label.custom_minimum_size.y = 12
		_creditos.add_child(label)
