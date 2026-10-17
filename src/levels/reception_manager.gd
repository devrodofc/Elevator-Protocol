class_name ReceptionManager
extends Node2D

@export_group("Configuração do Turno")
@export var schedule_config: DayScheduleConfig

@export_group("Instanciação do NPC")
@export var visitor_base_scene: PackedScene = preload("res://src/npcs/scenes/visitor.tscn")

# Nós do Cenário mapeados diretamente da árvore
@onready var spawn_point: Node2D = $VisitorSpawnPoint
@onready var desk_points: Array[Node2D] = [
	$VisitorDeskPoint1,
	$VisitorDeskPoint2,
	$VisitorDeskPoint3,
	$VisitorDeskPoint4,
	$VisitorDeskPoint5
]
@onready var exit_point: Node2D = $VisitorExitPoint

# Nós de Interface e Áudio mapeados da árvore
@onready var elevator_panel: ElevatorPanel = $UI_CanvasLayer/ElevatorPanel as ElevatorPanel
@onready var feedback_audio: AudioStreamPlayer2D = $FeedbackAudio

@export_group("Supervisão Clara (Opcional)")
@export var clara_game_over_panel: Control
@export var clara_dialogue_label: Label

var active_queue: Array[Dictionary] = [] # {"visitor": VisitorData, "dialogue": NPCDialogue, "node": Visitor}
var current_visita: Dictionary = {}
var is_processing_decision: bool = false


func _ready() -> void:
	if clara_game_over_panel:
		clara_game_over_panel.visible = false
		
	if elevator_panel:
		elevator_panel.floor_selected.connect(_on_floor_selected)
		elevator_panel.set_panel_locked(true)
		
	_build_day_queue()
	_fill_desk_slots()


func _build_day_queue() -> void:
	active_queue.clear()
	if schedule_config == null:
		return
		
	# 1. Fase 1: Primeiros normais do pool inicial
	if not schedule_config.pool_primeira_fase.is_empty():
		for i in range(schedule_config.qtd_primeira_fase):
			var v_rand: VisitorData = schedule_config.pool_primeira_fase.pick_random()
			var entry: Dictionary = v_rand.pick_visit()
			entry["node"] = null
			active_queue.append(entry)
			
	# 2. Fase 2: O NPC Fixo obrigatório
	if schedule_config.npc_fixo != null:
		var entry_fixo: Dictionary = schedule_config.npc_fixo.pick_visit(schedule_config.dialogo_fixo)
		entry_fixo["node"] = null
		active_queue.append(entry_fixo)
		
	# 3. Fase 3: Últimos normais do pool final
	if not schedule_config.pool_segunda_fase.is_empty():
		for i in range(schedule_config.qtd_segunda_fase):
			var v_rand: VisitorData = schedule_config.pool_segunda_fase.pick_random()
			var entry: Dictionary = v_rand.pick_visit()
			entry["node"] = null
			active_queue.append(entry)


func _fill_desk_slots() -> void:
	var total_slots: int = mini(active_queue.size(), desk_points.size())
	
	for i in range(total_slots):
		if active_queue[i]["node"] == null:
			var v_data: VisitorData = active_queue[i]["visitor"]
			var visitor_instance: Visitor = visitor_base_scene.instantiate() as Visitor
			add_child(visitor_instance)
			
			visitor_instance.global_position = spawn_point.global_position
			visitor_instance.setup(v_data)
			active_queue[i]["node"] = visitor_instance
			
			var target_pos: Vector2 = desk_points[i].global_position
			if i == 0:
				visitor_instance.move_to_slot(target_pos, _on_first_visitor_arrived_at_desk)
			else:
				visitor_instance.move_to_slot(target_pos)


func _on_first_visitor_arrived_at_desk() -> void:
	if active_queue.is_empty():
		_conclude_day()
		return
		
	current_visita = active_queue[0]
	var v_data: VisitorData = current_visita["visitor"]
	var d_data: NPCDialogue = current_visita["dialogue"]
	
	var speaker_name: String = current_visita.get("nome", v_data.nome if v_data else "")
	var speech_text: String = d_data.texto if d_data else ""
	
	_show_dialogue_via_autoload(speaker_name, speech_text)
		
	if elevator_panel:
		elevator_panel.set_panel_locked(false)


func _on_floor_selected(floor_code: int) -> void:
	if is_processing_decision or current_visita.is_empty():
		return
		
	is_processing_decision = true
	
	if elevator_panel:
		elevator_panel.set_panel_locked(true)
	_clear_dialogue_via_autoload()
		
	var v_data: VisitorData = current_visita["visitor"]
	var d_data: NPCDialogue = current_visita["dialogue"]
	var current_day: int = schedule_config.dia_numero if schedule_config else 1
	
	var success: bool = RuleValidator.validar_decisao(v_data, d_data, floor_code, current_day)
	
	if success:
		_advance_queue()
	else:
		_trigger_clara_game_over()


func _advance_queue() -> void:
	var finished: Dictionary = active_queue.pop_front()
	current_visita = {}
	
	if finished and finished["node"]:
		(finished["node"] as Visitor).leave_to(exit_point.global_position)
		
	for i in range(active_queue.size()):
		if i < desk_points.size() and active_queue[i]["node"] != null:
			var target_pos: Vector2 = desk_points[i].global_position
			var vis_node: Visitor = active_queue[i]["node"] as Visitor
			
			if i == 0:
				vis_node.move_to_slot(target_pos, _on_first_visitor_arrived_at_desk)
			else:
				vis_node.move_to_slot(target_pos)
				
	_fill_desk_slots()
	is_processing_decision = false
	
	if active_queue.is_empty():
		_conclude_day()


func _trigger_clara_game_over() -> void:
	if elevator_panel:
		elevator_panel.set_panel_locked(true)
		
	if feedback_audio and feedback_audio.playing:
		feedback_audio.stop()
		
	if clara_game_over_panel:
		clara_game_over_panel.visible = true
	if clara_dialogue_label:
		clara_dialogue_label.text = "Você tinha um trabalho tão simples... mas falhou. Vamos tentar de novo, certo?"
	else:
		_show_dialogue_via_autoload("Marta", "Você tinha um trabalho tão simples... mas falhou. Vamos tentar de novo, certo?")
		
	await get_tree().create_timer(5.0).timeout
	get_tree().reload_current_scene()


func _conclude_day() -> void:
	_show_dialogue_via_autoload("Sistema", "Expediente encerrado. Você concluiu o dia!")
	if elevator_panel:
		elevator_panel.set_panel_locked(true)
	print("Dia concluído com sucesso!")


## Comunicação com o Autoload Dialogue
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
