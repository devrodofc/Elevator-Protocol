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

@export_group("Escala e Profundidade da Marta")
@export var marta_start_scale: Vector2 = Vector2(0.75, 0.75)
@export var marta_focus_scale: Vector2 = Vector2(3.0, 3.0)

@export_group("Nós do Cenário")
@onready var spawn_point: Node2D = $VisitorSpawnPoint
@onready var marta_point: Node2D = $MartaPoint
## Usamos o DeskPoint1 como o balcão único de atendimento
@onready var desk_point: Node2D = $VisitorDeskPoint1
@onready var exit_point: Node2D = $VisitorExitPoint

@export_group("Interface & Áudio")
@onready var ui_canvas_layer: CanvasLayer = $UI_CanvasLayer
@onready var elevator_panel: ElevatorPanel = $UI_CanvasLayer/ElevatorPanel as ElevatorPanel
@onready var feedback_audio: AudioStreamPlayer2D = $FeedbackAudio

var queue_data: Array[Dictionary] = [] # Lista de dados: {"visitor": VisitorData, "dialogue": NPCDialogue}
var current_entry: Dictionary = {}
var current_visitor_node: Visitor = null
var is_processing_decision: bool = false
var marta_instance: Node2D = null


func _ready() -> void:
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
		
	marta_instance = marta_scene.instantiate() as Node2D
	add_child(marta_instance)
	marta_instance.global_position = spawn_point.global_position
	marta_instance.scale = marta_start_scale
	
	var target_pos: Vector2 = marta_point.global_position if marta_point else desk_point.global_position
	
	_move_actor(marta_instance, target_pos, func():
		var texto_inicio: String = schedule_config.mensagem_inicio if schedule_config else "Bom dia!"
		_show_dialogue_via_autoload("Marta", texto_inicio)
		
		await get_tree().create_timer(10.0).timeout
		_clear_dialogue_via_autoload()
		
		_leave_actor(marta_instance, exit_point.global_position, func():
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
	add_child(current_visitor_node)
	current_visitor_node.global_position = spawn_point.global_position
	current_visitor_node.setup(v_data)
	
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
	if is_processing_decision or current_entry.is_empty():
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
		marta_instance = marta_scene.instantiate() as Node2D
		add_child(marta_instance)
		marta_instance.global_position = spawn_point.global_position
		marta_instance.scale = marta_start_scale
		
		_move_actor(marta_instance, target_pos, func():
			var msg_falha: String = schedule_config.mensagem_falha if schedule_config else "Você falhou. Vamos tentar de novo."
			_show_dialogue_via_autoload("Marta", msg_falha)
		)
	else:
		var msg_falha: String = schedule_config.mensagem_falha if schedule_config else "Você falhou. Vamos tentar de novo."
		_show_dialogue_via_autoload("Marta", msg_falha)
		
	# 5. Tempo total com a tela avermelhada e diálogo antes de reiniciar a cena
	await get_tree().create_timer(6.0).timeout
	get_tree().reload_current_scene()


## Encerramento do dia
func _conclude_day() -> void:
	if elevator_panel:
		elevator_panel.set_panel_locked(true)
		
	var target_pos: Vector2 = marta_point.global_position if marta_point else desk_point.global_position
	
	if marta_scene != null:
		marta_instance = marta_scene.instantiate() as Node2D
		add_child(marta_instance)
		marta_instance.global_position = exit_point.global_position
		marta_instance.scale = marta_start_scale
		
		_move_actor(marta_instance, target_pos, func():
			var msg_fim: String = schedule_config.mensagem_fim if schedule_config else "Expediente encerrado. Você concluiu o dia!"
			_show_dialogue_via_autoload("Marta", msg_fim)
		)
	else:
		var msg_fim: String = schedule_config.mensagem_fim if schedule_config else "Expediente encerrado. Você concluiu o dia!"
		_show_dialogue_via_autoload("Marta", msg_fim)
		
	print("Dia concluído com sucesso!")


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


func _show_dialogue_via_autoload(speaker_name: String, speech_text: String) -> void:
	var dialogue_singleton = get_node_or_null("/root/Dialogue")
	if dialogue_singleton == null:
		return
	
	if "visible" in dialogue_singleton:
		dialogue_singleton.visible = true
		
	if dialogue_singleton.has_method("display_dialogue"):
		dialogue_singleton.call("display_dialogue", speaker_name, speech_text)
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
