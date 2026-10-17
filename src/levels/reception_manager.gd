class_name ReceptionManager
extends Node2D

@export_group("Dependencies")
@export var visitor_scene: PackedScene
@export var shift_visitors: Array[VisitorData] = []

@export_group("Queue Settings")
## Tempo de espera para spawnar o próximo da fila se o balcão (Ponto 1) estiver ocupado
@export var queue_delay_when_desk_busy: float = 1.5
## Intervalo mínimo padrão entre a entrada de cada pessoa na fila
@export var default_spawn_interval: float = 0.4

@export_group("Scene References")
@onready var spawn_point: Marker2D = $VisitorSpawnPoint
@onready var desk_points: Array[Marker2D] = [
	$VisitorDeskPoint1,
	$VisitorDeskPoint2,
	$VisitorDeskPoint3,
	$VisitorDeskPoint4,
	$VisitorDeskPoint5
]
@onready var exit_point: Marker2D = $VisitorExitPoint

# Referências de UI
@onready var dialogue_ui: Control = $UI_CanvasLayer/DialogueUI
@onready var elevator_panel: Control = $UI_CanvasLayer/ElevatorPanel
@onready var shift_summary: Control = $UI_CanvasLayer/ShiftSummary

# Estado da Fila
var line_visitors: Array[Visitor] = []
var next_visitor_data_index: int = 0
var is_shift_active: bool = false
var is_filling_queue: bool = false
var correct_decisions: int = 0
var mistakes: int = 0


func _ready() -> void:
	if elevator_panel and elevator_panel.has_signal("decision_made"):
		elevator_panel.connect("decision_made", _on_decision_made)
	
	start_shift()


## Inicia o expediente e inicia o preenchimento da fila
func start_shift() -> void:
	is_shift_active = true
	correct_decisions = 0
	mistakes = 0
	next_visitor_data_index = 0
	
	_fill_queue()


## Completa vagas vazias na fila respeitando o atraso se o posto 1 estiver ocupado
func _fill_queue() -> void:
	if is_filling_queue:
		return
		
	is_filling_queue = true
	
	while line_visitors.size() < desk_points.size() and next_visitor_data_index < shift_visitors.size():
		# Se o primeiro lugar já estiver ocupado, aguarda o tempo configurado
		if not line_visitors.is_empty():
			await get_tree().create_timer(queue_delay_when_desk_busy).timeout
			
			# Revalida se o turno ainda está ativo e se ainda há vaga disponível após o delay
			if not is_shift_active or line_visitors.size() >= desk_points.size() or next_visitor_data_index >= shift_visitors.size():
				break
		
		var data: VisitorData = shift_visitors[next_visitor_data_index]
		next_visitor_data_index += 1
		
		var slot_index: int = line_visitors.size()
		var target_pos: Vector2 = desk_points[slot_index].global_position
		
		var new_visitor: Visitor = visitor_scene.instantiate() as Visitor
		add_child(new_visitor)
		new_visitor.global_position = spawn_point.global_position
		new_visitor.setup(data)
		
		line_visitors.append(new_visitor)
		
		if slot_index == 0:
			new_visitor.move_to_slot(target_pos, _on_first_visitor_ready)
		else:
			new_visitor.move_to_slot(target_pos)
		
		# Intervalo padrão entre spawns consecutivos
		await get_tree().create_timer(default_spawn_interval).timeout
	
	is_filling_queue = false


## Chamado quando o visitante da frente chega ao balcão (DeskPoint1)
func _on_first_visitor_ready() -> void:
	if line_visitors.is_empty():
		return
		
	var active_visitor: Visitor = line_visitors[0]
	
	if dialogue_ui and dialogue_ui.has_method("display_dialogue"):
		dialogue_ui.display_dialogue(active_visitor.get_visitor_name(), active_visitor.get_dialogue_text())
		
	if elevator_panel and elevator_panel.has_method("unlock_controls"):
		elevator_panel.unlock_controls()


## Recebe a decisão tomada no elevador
func _on_decision_made(chosen_floor: int) -> void:
	if line_visitors.is_empty():
		return
		
	if elevator_panel and elevator_panel.has_method("lock_controls"):
		elevator_panel.lock_controls()
		
	if dialogue_ui and dialogue_ui.has_method("clear_dialogue"):
		dialogue_ui.clear_dialogue()
		
	var active_visitor: Visitor = line_visitors.pop_front()
	
	if active_visitor.current_data:
		if chosen_floor == active_visitor.current_data.correct_floor:
			correct_decisions += 1
		else:
			mistakes += 1
			
	active_visitor.leave_to(exit_point.global_position)
	
	_advance_line()


## Faz a fila avançar e reativa o preenchimento de vagas restantes
func _advance_line() -> void:
	for i in range(line_visitors.size()):
		var visitor: Visitor = line_visitors[i]
		var target_pos: Vector2 = desk_points[i].global_position
		
		if i == 0:
			visitor.move_to_slot(target_pos, _on_first_visitor_ready)
		else:
			visitor.move_to_slot(target_pos)
			
	# Reabastece as vagas liberadas
	_fill_queue()
	
	if line_visitors.is_empty() and next_visitor_data_index >= shift_visitors.size():
		_finish_shift()


## Encerramento do turno
func _finish_shift() -> void:
	is_shift_active = false
	if shift_summary:
		shift_summary.visible = true
		if shift_summary.has_method("setup_summary"):
			shift_summary.setup_summary(correct_decisions, mistakes)
