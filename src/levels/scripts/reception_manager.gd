class_name ReceptionManager
extends Node2D

@export_group("Configuração do Turno")
@export var schedule_config: DayScheduleConfig

@export_group("Cadência do Atendimento")
## Tempo de espera antes de o próximo visitante surgir pela porta
@export var delay_between_visitors: float = 2.0

@export_group("Cenas e Instanciação")
## Cena visual da Marta/Clara
@export var marta_scene: PackedScene
## Cena base do visitante comum
@export var visitor_base_scene: PackedScene = preload("res://src/npcs/scenes/visitor.tscn")
## Escala do visitante dentro da janela (3.46 = arte 256 px em tamanho real)
@export var visitor_scale: Vector2 = Vector2.ONE
## Velocidade do visitante ao entrar e sair da janela, em px/s (0 = usa a da cena do visitante)
@export var visitor_move_speed: float = 0.0

@export_group("Escala e Profundidade da Marta")
@export var marta_start_scale: Vector2 = Vector2(0.75, 0.75)
@export var marta_focus_scale: Vector2 = Vector2(3.0, 3.0)

@export_group("Nós do Cenário")
@onready var spawn_point: Node2D = %VisitorSpawnPoint
@onready var marta_point: Node2D = %MartaPoint
## Entrada e saída da Marta na altura dela (opcionais; sem eles usa os pontos do visitante)
@onready var marta_spawn_point: Node2D = get_node_or_null("%MartaSpawnPoint")
@onready var marta_exit_point: Node2D = get_node_or_null("%MartaExitPoint")
## Usamos o DeskPoint1 como o balcão único de atendimento
@onready var desk_point: Node2D = %VisitorDeskPoint1
@onready var exit_point: Node2D = %VisitorExitPoint
## Atores (visitante e Marta) ficam aqui dentro para serem recortados pela janela
@onready var actors_root: Node = get_node_or_null("%Actors")

@export_group("Interface & Áudio")
@onready var ui_canvas_layer: CanvasLayer = $UI_CanvasLayer
@onready var elevator_panel: ElevatorPanel = $UI_CanvasLayer/ElevatorPanel as ElevatorPanel
@onready var reception_hud: Control = $UI_CanvasLayer/ReceptionHUD
@onready var feedback_audio: AudioStreamPlayer2D = $FeedbackAudio

var queue_data: Array[Dictionary] = [] # Lista de dados: {"visitor": VisitorData, "dialogue": NPCDialogue}
var current_entry: Dictionary = {}
var current_visitor_node: Visitor = null
var is_processing_decision: bool = false
var _badge_locked_panel: bool = false
var marta_instance: Node2D = null


func _ready() -> void:
	reception_hud.badge_details.toggled.connect(_on_badge_toggled)
	reception_hud.set_current_visitor(null)
	if elevator_panel:
		elevator_panel.floor_selected.connect(_on_floor_selected)
		elevator_panel.set_panel_locked(true)
		
	_build_schedule_data()
	_start_day_intro()


## Monta a lista completa de atendimentos do dia
func _build_schedule_data() -> void:
	queue_data.clear()
	if schedule_config == null:
		return
		
	# 1. Fase 1: Primeiros normais sorteados
	if not schedule_config.pool_primeira_fase.is_empty():
		for i in range(schedule_config.qtd_primeira_fase):
			var v_rand: VisitorData = schedule_config.pool_primeira_fase.pick_random()
			queue_data.append(v_rand.pick_visit())
			
	# 2. Fase 2: O NPC Fixo obrigatório
	if schedule_config.npc_fixo != null:
		var entry_fixo: Dictionary = schedule_config.npc_fixo.pick_visit(schedule_config.dialogo_fixo)
		queue_data.append(entry_fixo)
		
	# 3. Fase 3: Últimos normais sorteados
	if not schedule_config.pool_segunda_fase.is_empty():
		for i in range(schedule_config.qtd_segunda_fase):
			var v_rand: VisitorData = schedule_config.pool_segunda_fase.pick_random()
			queue_data.append(v_rand.pick_visit())


## Rotina de Introdução da Marta
func _start_day_intro() -> void:
	if marta_scene == null:
		_call_next_visitor()
		return
		
	marta_instance = _spawn_marta(_marta_spawn_pos())
	
	var target_pos: Vector2 = marta_point.global_position if marta_point else desk_point.global_position
	
	_move_actor(marta_instance, target_pos, func():
		var texto_inicio: String = schedule_config.mensagem_inicio if schedule_config else "Bom dia!"
		_show_dialogue_via_autoload("Marta", texto_inicio, true)
		
		await _wait_dialogue(0.0) # sem tempo limite: a Marta só sai quando o jogador aperta Espaço
		_clear_dialogue_via_autoload()
		
		_leave_actor(marta_instance, _marta_exit_pos(), func():
			marta_instance = null
			if delay_between_visitors > 0.0:
				await get_tree().create_timer(delay_between_visitors).timeout
			_call_next_visitor()
		)
	)


## Spawna o próximo visitante e o move diretamente para o balcão
func _call_next_visitor() -> void:
	if queue_data.is_empty():
		_conclude_day()
		return
		
	current_entry = queue_data.pop_front()
	var v_data: VisitorData = current_entry["visitor"]
	
	current_visitor_node = visitor_base_scene.instantiate() as Visitor
	# Na janela o visitante entra de lado: mesma escala na fila e no balcão
	current_visitor_node.queue_scale = visitor_scale
	current_visitor_node.desk_scale = visitor_scale
	if visitor_move_speed > 0.0:
		current_visitor_node.move_speed = visitor_move_speed
	_add_actor(current_visitor_node)
	current_visitor_node.global_position = spawn_point.global_position
	current_visitor_node.setup(v_data)
	# O sinal já existente marca o início do atendimento no balcão.
	current_visitor_node.arrived.connect(_update_badge_visitor)
	
	current_visitor_node.move_to_slot(desk_point.global_position, _on_visitor_arrived_at_desk, true)


## Quando o visitante chega no balcão: mostra fala e libera o elevador
func _on_visitor_arrived_at_desk() -> void:
	if current_entry.is_empty():
		return
		
	var v_data: VisitorData = current_entry["visitor"]
	var d_data: NPCDialogue = current_entry["dialogue"]
	
	var speaker_name: String = current_entry.get("nome", v_data.nome if v_data else "")
	var speech_text: String = d_data.texto if d_data else ""
	
	_show_dialogue_via_autoload(speaker_name, speech_text)
		
	if elevator_panel:
		elevator_panel.set_panel_locked(false)


## Trata o clique do jogador nos botões do elevador
func _on_floor_selected(floor_code: int) -> void:
	if is_processing_decision or current_entry.is_empty() or reception_hud.badge_details.visible:
		return
		
	is_processing_decision = true
	
	if elevator_panel:
		elevator_panel.set_panel_locked(true)
	_clear_dialogue_via_autoload()
		
	var v_data: VisitorData = current_entry["visitor"]
	var d_data: NPCDialogue = current_entry["dialogue"]
	var current_day: int = schedule_config.dia_numero if schedule_config else 1
	
	var success: bool = RuleValidator.validar_decisao(v_data, d_data, floor_code, current_day)
	
	if success:
		_process_success()
	else:
		fail()


## Sucesso: o visitante vai embora e, após o delay, surge o próximo
func _process_success() -> void:
	reception_hud.set_current_visitor(null)
	if is_instance_valid(current_visitor_node):
		current_visitor_node.leave_to(exit_point.global_position)
		current_visitor_node = null
		
	current_entry = {}
	is_processing_decision = false
	
	if delay_between_visitors > 0.0:
		await get_tree().create_timer(delay_between_visitors).timeout
		
	_call_next_visitor()


## Função de falha com transição de tela vermelha lenta e aparição da Marta
func fail() -> void:
	reception_hud.set_current_visitor(null)
	if elevator_panel:
		elevator_panel.set_panel_locked(true)
		
	if feedback_audio and feedback_audio.playing:
		feedback_audio.stop()
		
	# 1. Espera um momento de choque antes da reação
	await get_tree().create_timer(1.0).timeout
	
	# 2. Cria overlay para avermelhar a tela lentamente
	var red_overlay: ColorRect = ColorRect.new()
	red_overlay.color = Color(0.7, 0.0, 0.0, 0.0)
	red_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	red_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if ui_canvas_layer:
		ui_canvas_layer.add_child(red_overlay)
	else:
		add_child(red_overlay)
		
	var red_tween: Tween = create_tween()
	red_tween.tween_property(red_overlay, "color:a", 0.65, 3.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 3. Descarta o visitante que estava no balcão
	if is_instance_valid(current_visitor_node):
		current_visitor_node.queue_free()
		current_visitor_node = null
		
	# 4. Marta entra e assume a posição
	var target_pos: Vector2 = marta_point.global_position if marta_point else desk_point.global_position
	
	if marta_scene != null:
		marta_instance = _spawn_marta(_marta_spawn_pos())
		
		_move_actor(marta_instance, target_pos, func():
			var msg_falha: String = schedule_config.mensagem_falha if schedule_config else "Você falhou. Vamos tentar de novo."
			_show_dialogue_via_autoload("Marta", msg_falha, true)
		)
	else:
		var msg_falha: String = schedule_config.mensagem_falha if schedule_config else "Você falhou. Vamos tentar de novo."
		_show_dialogue_via_autoload("Marta", msg_falha, true)
		
	# 5. Tempo total com a tela avermelhada e diálogo antes de reiniciar a cena
	await _wait_dialogue(6.0) # Espaço encerra antes
	get_tree().reload_current_scene()


## Encerramento do dia
func _conclude_day() -> void:
	reception_hud.set_current_visitor(null)
	if elevator_panel:
		elevator_panel.set_panel_locked(true)
		
	var target_pos: Vector2 = marta_point.global_position if marta_point else desk_point.global_position
	
	if marta_scene != null:
		marta_instance = _spawn_marta(_marta_exit_pos())
		
		_move_actor(marta_instance, target_pos, func():
			var msg_fim: String = schedule_config.mensagem_fim if schedule_config else "Expediente encerrado. Você concluiu o dia!"
			_show_dialogue_via_autoload("Marta", msg_fim, true)
		)
	else:
		var msg_fim: String = schedule_config.mensagem_fim if schedule_config else "Expediente encerrado. Você concluiu o dia!"
		_show_dialogue_via_autoload("Marta", msg_fim, true)
		
	print("Dia concluído com sucesso!")


func _update_badge_visitor() -> void:
	if not is_instance_valid(current_visitor_node) or current_entry.is_empty():
		reception_hud.set_current_visitor(null)
		return
	var data: VisitorData = current_entry["visitor"]
	reception_hud.set_current_visitor(current_visitor_node, current_entry.get("nome", data.nome))


func _on_badge_toggled(is_open: bool) -> void:
	if is_open:
		# Inclui os 0,15 s da animação de confirmação já iniciada no painel.
		if is_processing_decision or not elevator_panel or elevator_panel.locked:
			reception_hud.badge_details.close()
			return
		_badge_locked_panel = true
		elevator_panel.set_panel_locked(true)
	elif _badge_locked_panel:
		_badge_locked_panel = false
		if elevator_panel and not is_processing_decision and not current_entry.is_empty() \
				and is_instance_valid(current_visitor_node) and not current_visitor_node.is_moving:
			elevator_panel.set_panel_locked(false)


## Movimentação de atores auxiliares (Marta) com interpolação de escala
func _move_actor(actor: Node2D, target_pos: Vector2, on_finished: Callable = Callable()) -> void:
	if actor.has_method("move_to_slot"):
		actor.call("move_to_slot", target_pos, on_finished, true)
	else:
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(actor, "global_position", target_pos, 1.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(actor, "scale", marta_focus_scale, 1.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if on_finished.is_valid():
			tween.chain().tween_callback(on_finished)


func _leave_actor(actor: Node2D, target_pos: Vector2, on_finished: Callable = Callable()) -> void:
	if actor.has_method("leave_to"):
		actor.call("leave_to", target_pos)
		if on_finished.is_valid():
			get_tree().create_timer(1.2).timeout.connect(on_finished)
	else:
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(actor, "global_position", target_pos, 1.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(actor, "scale", marta_start_scale, 1.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(func():
			actor.queue_free()
			if on_finished.is_valid():
				on_finished.call()
		)


## skippable: mostra "[Espaço] acelerar" e deixa o jogador apressar a fala (usado pela Marta).
func _show_dialogue_via_autoload(speaker_name: String, speech_text: String, skippable: bool = false) -> void:
	var dialogue_singleton = get_node_or_null("/root/Dialogue")
	if dialogue_singleton == null:
		return
	
	if "visible" in dialogue_singleton:
		dialogue_singleton.visible = true
		
	if dialogue_singleton.has_method("display_dialogue"):
		dialogue_singleton.call("display_dialogue", speaker_name, speech_text, skippable)
	elif dialogue_singleton.has_method("start_dialogue"):
		dialogue_singleton.call("start_dialogue", speech_text)
	elif dialogue_singleton.has_method("show_dialogue"):
		dialogue_singleton.call("show_dialogue", speaker_name, speech_text)
	elif dialogue_singleton.has_method("set_dialogue"):
		dialogue_singleton.call("set_dialogue", speech_text)
	else:
		for child in dialogue_singleton.find_children("*", "Label", true, false):
			if child is Label:
				child.text = speech_text
				child.visible = true
				break
		for child in dialogue_singleton.find_children("*", "RichTextLabel", true, false):
			if child is RichTextLabel:
				child.text = speech_text
				child.visible = true
				break


func _clear_dialogue_via_autoload() -> void:
	var dialogue_singleton = get_node_or_null("/root/Dialogue")
	if dialogue_singleton == null:
		return
		
	if dialogue_singleton.has_method("clear_dialogue"):
		dialogue_singleton.call("clear_dialogue")
	elif dialogue_singleton.has_method("hide_dialogue"):
		dialogue_singleton.call("hide_dialogue")
	elif "visible" in dialogue_singleton:
		dialogue_singleton.visible = false


## Adiciona um ator (visitante/Marta) dentro da janela recortada, ou na raiz se não houver.
func _add_actor(actor: Node) -> void:
	if actors_root:
		actors_root.add_child(actor)
	else:
		add_child(actor)


## Espera a fala acelerável: termina em "seconds" ou quando o jogador aperta Espaço.
## seconds <= 0: espera só o jogador.
func _wait_dialogue(seconds: float) -> void:
	var dialogue_singleton = get_node_or_null("/root/Dialogue")
	if dialogue_singleton and dialogue_singleton.has_method("wait_for_advance"):
		await dialogue_singleton.wait_for_advance(seconds)
	else:
		# Sem a caixa de fala não há como apertar Espaço: usa um tempo fixo
		await get_tree().create_timer(seconds if seconds > 0.0 else 10.0).timeout


## Cria a Marta dentro da janela. Ela usa o script do visitante, que muda de escala sozinho
## entre fila e balcão; aqui a escala fica fixa em marta_focus_scale do começo ao fim.
func _spawn_marta(at_position: Vector2) -> Node2D:
	var marta: Node2D = marta_scene.instantiate() as Node2D
	if "queue_scale" in marta:
		marta.queue_scale = marta_focus_scale
		marta.desk_scale = marta_focus_scale
	_add_actor(marta)
	marta.global_position = at_position
	marta.scale = marta_focus_scale
	return marta


func _marta_spawn_pos() -> Vector2:
	return (marta_spawn_point if marta_spawn_point else spawn_point).global_position


func _marta_exit_pos() -> Vector2:
	return (marta_exit_point if marta_exit_point else exit_point).global_position
