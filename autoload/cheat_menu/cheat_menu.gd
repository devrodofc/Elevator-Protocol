extends CanvasLayer
## Tela de cheat (autoload "CheatMenu"): a tecla P abre e fecha em qualquer cena.
## Pula para pontos-chave do jogo: Dia 1, Dia 2, Dia 3 e menu inicial.
## Enquanto está aberta o jogo fica pausado; P ou Esc fecham e devolvem o estado anterior.
## A interface é montada em código (sem .tscn) para não depender de uid.

const RECEPTION_SCENE := "res://src/gameplay/reception/scenes/reception.tscn"
const MENU_SCENE := "res://src/ui/menus/scenes/menu.tscn"
const RECEPTION_SCRIPT := "res://src/gameplay/reception/scripts/reception_manager.gd"
const DIAS: Array[String] = [
	"res://src/gameplay/schedules/day1.tres",
	"res://src/gameplay/schedules/day2.tres",
	"res://src/gameplay/schedules/day3.tres",
]
const FONTE := preload("res://assets/fonts/pixeloid_sans.ttf")
const FONTE_BOLD := preload("res://assets/fonts/pixeloid_sans_bold.ttf")

var _root: Control
var _first_button: Button
## Estado de pausa antes de abrir (ex.: aberta por cima do menu de pause)
var _was_paused: bool = false


func _ready() -> void:
	layer = 100 # acima do pause (10) e da transição (50)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_P:
		get_viewport().set_input_as_handled()
		if is_open():
			close()
		else:
			open()
	elif event.keycode == KEY_ESCAPE and is_open():
		# Não deixa o Esc chegar ao menu de pause enquanto a tela de cheat está aberta
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	if is_open() or SceneTransition.is_busy():
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	_root.visible = true
	_first_button.grab_focus()


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	get_tree().paused = _was_paused


## dia: 1 a 3. Recarrega a recepção com a agenda do dia (mesmo caminho do fim de dia).
func go_to_day(dia: int) -> void:
	load(RECEPTION_SCRIPT).dia_em_andamento = load(DIAS[dia - 1])
	_go(RECEPTION_SCENE, "Dia %d" % dia)


func go_to_menu() -> void:
	_go(MENU_SCENE, "")


func _go(scene_path: String, title: String) -> void:
	if SceneTransition.is_busy():
		return
	_root.visible = false
	get_tree().paused = false
	# Encerra falas e esperas pendentes da cena atual e os sons que não são da próxima
	Dialogue.clear_dialogue()
	Audio.stop_loop()
	if scene_path != MENU_SCENE:
		MusicMenu.stop_music()
	var cena_antiga: int = get_tree().current_scene.get_instance_id() if get_tree().current_scene else 0
	SceneTransition.transition_to(scene_path, title)
	# Durante o escurecimento a cena antiga ainda roda e pode abrir outra fala (ex.: a Marta chegando):
	# limpa de novo assim que a cena nova entra
	while get_tree().current_scene == null or get_tree().current_scene.get_instance_id() == cena_antiga:
		await get_tree().process_frame
	Dialogue.clear_dialogue()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP # bloqueia cliques no jogo por baixo
	add_child(_root)

	var fundo := ColorRect.new()
	fundo.color = Color(0.0, 0.0, 0.0, 0.75)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centro)

	var painel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.08, 0.08, 0.1)
	estilo.border_color = Color(0.75, 0.1, 0.1)
	estilo.set_border_width_all(2)
	estilo.set_content_margin_all(14)
	painel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(painel)

	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 6)
	painel.add_child(lista)

	var titulo := Label.new()
	titulo.text = "CHEATS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_override("font", FONTE_BOLD)
	titulo.add_theme_font_size_override("font_size", 16)
	titulo.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	lista.add_child(titulo)

	_first_button = _add_button(lista, "Primeira fase (Dia 1)", go_to_day.bind(1))
	_add_button(lista, "Segunda fase (Dia 2)", go_to_day.bind(2))
	_add_button(lista, "Terceira fase (Dia 3)", go_to_day.bind(3))
	_add_button(lista, "Menu inicial", go_to_menu)

	var dica := Label.new()
	dica.text = "[P] ou [Esc] fechar"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.add_theme_font_override("font", FONTE)
	dica.add_theme_font_size_override("font_size", 8)
	dica.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	lista.add_child(dica)


func _add_button(parent: Control, texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size = Vector2(170, 22)
	botao.focus_mode = Control.FOCUS_ALL
	botao.add_theme_font_override("font", FONTE)
	botao.add_theme_font_size_override("font_size", 10)
	botao.pressed.connect(acao)
	parent.add_child(botao)
	return botao
