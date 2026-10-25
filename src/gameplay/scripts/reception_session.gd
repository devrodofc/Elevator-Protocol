class_name ReceptionSession
extends Node
## Autoridade de dados do atendimento. A apresentação informa os marcos, sem atores aqui.

enum State { IDLE, INTRO, READY, ARRIVING, SERVING, RESOLVED, INTERVAL, RULE, CONCLUDING, FAILED, TRANSITION, CLOSED }

var _schedule: DayScheduleConfig
var _queue: Array[Dictionary] = []
var _entry: Dictionary = {}
var _active_rules: Array[MartaRule] = []
var _rules: Array[MartaRule] = []
var _pending_rule: MartaRule
var _rule_activated: bool = false
var _served: int = 0
var _next_rule: int = 0
var _state: State = State.IDLE
var _generation: int = 0
var _visit_serial: int = 0
var _visit_id: String = ""

var schedule_config: DayScheduleConfig:
	get: return _schedule
var day_number: int:
	get: return _schedule.dia_numero if _schedule else 1
var generation: int:
	get: return _generation
var state: State:
	get: return _state
var current_visit_id: String:
	get: return _visit_id
var current_entry: Dictionary:
	get: return _entry
## Coleções de consulta: não permitem que a apresentação retire visitas ou ative regras.
var queue_data: Array[Dictionary]:
	get:
		var view: Array[Dictionary] = _queue.duplicate()
		view.make_read_only()
		return view
var active_rules: Array[MartaRule]:
	get:
		var view: Array[MartaRule] = _active_rules.duplicate()
		view.make_read_only()
		return view
var rules_today: Array[MartaRule]:
	get:
		var view: Array[MartaRule] = _rules.duplicate()
		view.make_read_only()
		return view
var pending_rule: MartaRule:
	get: return _pending_rule
var served_count: int:
	get: return _served
var next_rule_index: int:
	get: return _next_rule
var is_processing_decision: bool:
	get: return _state in [State.RESOLVED, State.FAILED]


## Uma chamada a montar_dia por início/reinício; nenhum sorteio durante o atendimento.
func start_day(config: DayScheduleConfig) -> void:
	_generation += 1
	_schedule = config
	_queue.clear()
	_entry = {}
	_entry.make_read_only()
	_active_rules.clear()
	_rules.clear()
	_pending_rule = null
	_rule_activated = false
	_served = 0
	_next_rule = 0
	_visit_id = ""
	if config:
		var day: Dictionary = config.montar_dia()
		for generated: Dictionary in day["fila"]:
			# Copia somente os containers, mantendo identidade dos Resources autorais.
			var snapshot: Dictionary = generated.duplicate(true)
			var badge: Dictionary = snapshot.get("cracha", {})
			badge.make_read_only()
			snapshot.make_read_only()
			_queue.append(snapshot)
		_rules.assign(day["regras"])
	_state = State.INTRO


func finish_intro(expected_generation: int) -> bool:
	if expected_generation != _generation or _state != State.INTRO:
		return false
	_state = State.READY
	return true


## Só READY consome a fila. INTERVAL preserva a cadência original, independente da saída física.
func request_next_visit(expected_generation: int) -> Dictionary:
	if expected_generation != _generation or _state != State.READY:
		return {}
	if _queue.is_empty():
		_state = State.CONCLUDING
		return {}
	_entry = _queue.pop_front()
	_visit_serial += 1
	_visit_id = "%d:%d:%d" % [get_instance_id(), _generation, _visit_serial]
	_state = State.ARRIVING
	return _entry


func service_reached(visit_id: String) -> bool:
	if not _matches(visit_id, State.ARRIVING):
		return false
	_state = State.SERVING
	return true


## {} significa comando rejeitado, distinto de uma decisão aceita e incorreta.
func submit_decision(visit_id: String, floor_code: int) -> Dictionary:
	if not _matches(visit_id, State.SERVING) or floor_code not in [1, 2, 3, 4, 5, 6, -1, RuleValidator.DENY_ACTION]:
		return {}
	var visitor: VisitorData = _entry["visitor"]
	var dialogue: NPCDialogue = _entry.get("dialogue")
	var correct: bool = RuleValidator.validar_decisao(visitor, dialogue, floor_code, day_number, _active_rules)
	_state = State.RESOLVED if correct else State.FAILED
	return {"visit_id": visit_id, "floor_code": floor_code, "correct": correct}


## Contabiliza uma vez, no mesmo marco em que o manager original liberava o atendimento.
func complete_visit(visit_id: String) -> bool:
	if not _matches(visit_id, State.RESOLVED):
		return false
	_entry = {}
	_entry.make_read_only()
	_served += 1
	_state = State.INTERVAL
	return true


func take_due_rule(visit_id: String) -> MartaRule:
	if not _matches(visit_id, State.INTERVAL) or _schedule == null or _queue.is_empty():
		return null
	var interval: int = _schedule.intervalo_regras
	if interval <= 0 or _served % interval != 0 or _next_rule >= _rules.size():
		return null
	_pending_rule = _rules[_next_rule]
	_next_rule += 1
	_rule_activated = false
	_state = State.RULE
	return _pending_rule


## A apresentação chama somente após o último avanço da fala de Marta.
func activate_pending_rule(expected_generation: int, rule: MartaRule) -> bool:
	if expected_generation != _generation or _state != State.RULE or rule != _pending_rule or _rule_activated:
		return false
	_active_rules.append(rule)
	_rule_activated = true
	return true


func finish_rule(expected_generation: int, rule: MartaRule) -> bool:
	if expected_generation != _generation or _state != State.RULE or rule != _pending_rule or not _rule_activated:
		return false
	_pending_rule = null
	_state = State.READY
	return true


func finish_interval(visit_id: String) -> bool:
	if not _matches(visit_id, State.INTERVAL):
		return false
	_state = State.READY
	return true


func has_next_day() -> bool:
	return _schedule != null and (_schedule.proximo_dia != null or not _schedule.cena_final.is_empty())


## Invalida inclusive continuações assíncronas que já capturaram a geração anterior.
func begin_transition() -> void:
	if _state in [State.TRANSITION, State.CLOSED]:
		return
	_generation += 1
	_state = State.TRANSITION


func close() -> void:
	if _state == State.CLOSED:
		return
	_generation += 1
	_state = State.CLOSED


func _matches(visit_id: String, expected_state: State) -> bool:
	return not visit_id.is_empty() and visit_id == _visit_id and _state == expected_state


func _exit_tree() -> void:
	close()
