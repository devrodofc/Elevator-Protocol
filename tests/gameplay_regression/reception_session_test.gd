extends SceneTree
## I1: dados reais e comandos fora de ordem, sem depender de uma apresentação.

const Session := preload("res://src/gameplay/scripts/reception_session.gd")
const Validator := preload("res://src/shared/scripts/rule_validator.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _snapshot(session: Node) -> Dictionary:
	var visits: Array = []
	for entry: Dictionary in session.queue_data:
		visits.append({"visitor": entry.visitor.resource_path, "visitor_id": entry.visitor.id,
			"nome": entry.nome, "sprite": entry.sprite.resource_path if entry.sprite else "",
			"cracha": entry.cracha, "dialogue": entry.dialogue.resource_path,
			"texto": entry.dialogue.texto, "andar": entry.dialogue.andar_desejado,
			"fixo": entry.fixo, "caso_regra": entry.get("caso_regra", false)})
	var rules: Array = []
	for rule: MartaRule in session.rules_today:
		rules.append({"path": rule.resource_path, "fala": rule.fala,
			"texto_prancheta": rule.texto_prancheta, "pedido": rule.andar_pedido,
			"destino": rule.andar_destino})
	return {"day": session.day_number, "visits": visits, "rules": rules}


func _real_day(number: int, fixture: Dictionary) -> void:
	var day: DayScheduleConfig = load("res://src/gameplay/schedules/day%d.tres" % number)
	# Repetição determinística da mesma seed, não dois sorteios sucessivos para fila/regras.
	seed(4200 + number)
	var expected: Dictionary = day.montar_dia()
	var random_after_schedule: int = randi()
	seed(4200 + number)
	var session := Session.new()
	root.add_child(session)
	_check(session.state == Session.State.IDLE, "Session starts idle")
	session.start_day(day)
	_check(randi() == random_after_schedule, "Initialization consumes exactly the original schedule RNG")
	_check(JSON.parse_string(JSON.stringify(_snapshot(session))) == fixture, "Session matches frozen I0 snapshot for day %d" % number)
	_check(session.get_parent() == root and session.get_child_count() == 0, "Local Node without presentation children")
	_check(session.schedule_config == day and session.day_number == number, "Session owns current day")
	_check(session.queue_data == expected.fila and session.rules_today == expected.regras, "Original agenda and rules preserved")
	_check(session.queue_data.is_read_only() and session.rules_today.is_read_only() and session.active_rules.is_read_only(), "Collection views cannot advance queue or activate rules")
	_check(session.active_rules.is_empty() and session.served_count == 0, "Selected rules are inactive at startup")
	var generation: int = session.generation
	_check(session.request_next_visit(generation).is_empty(), "Cannot skip introduction")
	_check(not session.finish_intro(generation - 1), "Old introduction rejected")
	_check(session.finish_intro(generation) and not session.finish_intro(generation), "Introduction completes once")
	var ids: Array[String] = []
	for index in 7:
		var entry: Dictionary = session.request_next_visit(generation)
		var visit_id: String = session.current_visit_id
		_check(not visit_id.is_empty() and not ids.has(visit_id), "Occurrence has a fresh identity")
		ids.append(visit_id)
		_check(entry == expected.fila[index] and session.current_entry == entry, "FIFO snapshot preserved")
		_check(entry.visitor == expected.fila[index].visitor and entry.dialogue == expected.fila[index].dialogue
			and entry.sprite == expected.fila[index].sprite, "Original Resource identities preserved")
		_check(entry.is_read_only() and entry.cracha.is_read_only(), "Visit and badge snapshots are read only")
		_check(session.queue_data.size() == 6 - index and session.state == Session.State.ARRIVING, "Only one queue entry selected")
		_check(session.request_next_visit(generation).is_empty(), "Repeated next cannot skip an arriving visit")
		var rng_before_arrival: int = randi()
		seed(rng_before_arrival)
		var next_random: int = randi()
		seed(rng_before_arrival)
		_check(session.submit_decision(visit_id, 1).is_empty(), "Decision before arrival rejected")
		_check(not session.service_reached("old-visit"), "Foreign arrival rejected")
		_check(session.service_reached(visit_id) and not session.service_reached(visit_id), "Arrival accepted exactly once")
		_check(randi() == next_random and session.current_entry == entry, "Arrival never resamples visit data")
		_check(session.state == Session.State.SERVING and not session.is_processing_decision, "Decision opens only at service")
		_check(session.submit_decision("old-visit", 1).is_empty(), "Foreign decision rejected")
		_check(session.submit_decision(visit_id, 0).is_empty(), "Invalid code is not a confirmed wrong answer")
		_check(not session.complete_visit(visit_id) and not session.finish_interval(visit_id), "Cannot complete or advance undecided visit")
		var code: int = Validator.andar_esperado(entry.visitor, entry.dialogue, number, session.active_rules)
		if index == 6:
			_check(code == (3 if number == 1 else -1), "Lucas/entregador/Tiao literal destination")
		var result: Dictionary = session.submit_decision(visit_id, code)
		_check(result == {"visit_id": visit_id, "floor_code": code, "correct": true}, "Original validator resolves the visit")
		_check(session.is_processing_decision and session.state == Session.State.RESOLVED, "Resolution closes decisions")
		_check(session.submit_decision(visit_id, code).is_empty(), "Duplicate decision rejected")
		_check(session.served_count == index, "No count before completion milestone")
		_check(session.complete_visit(visit_id) and not session.complete_visit(visit_id), "Completion counts once")
		_check(session.current_entry.is_empty() and session.served_count == index + 1, "Only successful completed visits count")
		_check(session.request_next_visit(generation).is_empty(), "Interval cannot be skipped")
		_check(session.active_rules.size() == mini(index / 2, 2), "No rule active ahead of its announcement")
		var rule: MartaRule = session.take_due_rule(visit_id)
		if index in [1, 3]:
			var rule_index: int = index / 2
			_check(rule == expected.regras[rule_index] and session.pending_rule == rule, "Correct pending rule at original cadence")
			_check(session.state == Session.State.RULE and session.take_due_rule(visit_id) == null, "Announcement reserved once")
			_check(not session.active_rules.has(rule), "Reservation never activates rule")
			_check(not session.finish_rule(generation, rule), "Marta cannot finish before activation")
			_check(not session.activate_pending_rule(generation - 1, rule)
				and not session.activate_pending_rule(generation, MartaRule.new()), "Wrong generation/rule cannot activate")
			_check(session.request_next_visit(generation).is_empty() and not session.finish_interval(visit_id), "No visit during Marta")
			_check(session.activate_pending_rule(generation, rule), "Last dialogue advance activates the reserved rule")
			_check(not session.activate_pending_rule(generation, rule), "Duplicate activation rejected")
			_check(session.active_rules[rule_index] == rule, "Exactly the announced Resource becomes active")
			_check(session.finish_rule(generation, rule) and not session.finish_rule(generation, rule), "Marta departure releases next visit once")
		else:
			_check(rule == null and session.finish_interval(visit_id), "No additional announcement, interval releases next visit")
		_check(not session.service_reached(visit_id) and session.submit_decision(visit_id, code).is_empty(), "Old visit cannot reopen after completion")
	_check(session.request_next_visit(generation).is_empty() and session.state == Session.State.CONCLUDING, "Only exhausted queue concludes day")
	_check(session.served_count == 7 and session.next_rule_index == 2, "Seven services and two announcements")
	_check(session.has_next_day(), "Progression data available for each configured day")
	session.close()
	_check(session.state == Session.State.CLOSED and not session.finish_intro(generation), "Closed scene invalidates callbacks")
	session.free()


func _restarts_and_codes() -> void:
	# Mesmo Resource e mesmo VisitorData.id em duas ocorrências distintas.
	var visitor := VisitorData.new()
	visitor.id = "same-resource"
	visitor.nome = "Fixed snapshot"
	var request := NPCDialogue.new()
	var interaction := DayInteraction.new()
	interaction.modo = DayInteraction.Modo.FIXO
	interaction.visitante = visitor
	interaction.dialogo = request
	interaction.repeticoes = 2
	var day := DayScheduleConfig.new()
	day.interacoes = [interaction]
	day.regras_por_dia = 0
	var session := Session.new()
	var replacement := Session.new()
	root.add_child(session)
	root.add_child(replacement)
	for code in [1, 2, 3, 4, 5, 6, -1, 999]:
		request.andar_desejado = code
		session.start_day(day)
		var generation: int = session.generation
		session.finish_intro(generation)
		session.request_next_visit(generation)
		var first_id: String = session.current_visit_id
		session.service_reached(first_id)
		_check(session.submit_decision(first_id, code).get("correct", false), "All panel floor codes including basement/refusal remain valid")
		session.complete_visit(first_id)
		session.finish_interval(first_id)
		session.request_next_visit(generation)
		var second_id: String = session.current_visit_id
		_check(first_id != second_id and session.current_entry.visitor == visitor, "VisitorData.id never identifies an occurrence")
		_check(not session.service_reached(first_id) and not session.complete_visit(first_id)
			and not session.finish_interval(first_id), "Previous visit cannot affect the next")
		session.service_reached(second_id)
		var wrong: int = 1 if code != 1 else 999
		var failure: Dictionary = session.submit_decision(second_id, wrong)
		_check(not failure.is_empty() and not failure.correct and session.state == Session.State.FAILED, "Wrong valid decision enters failure")
		_check(session.is_processing_decision and session.served_count == 1, "Failure is locked and never counted")
		_check(session.submit_decision(second_id, code).is_empty() and not session.complete_visit(second_id)
			and session.request_next_visit(generation).is_empty(), "Failure cannot be corrected or advanced by duplicate callbacks")
		session.start_day(day)
		_check(session.generation != generation and session.served_count == 0 and session.active_rules.is_empty()
			and session.current_entry.is_empty() and session.queue_data.size() == 2, "Restart resets logical state and rebuilds agenda")
		_check(not session.finish_intro(generation) and not session.service_reached(second_id), "Pre-restart callbacks rejected")
		session.finish_intro(session.generation)
		session.request_next_visit(session.generation)
		_check(session.current_visit_id not in [first_id, second_id], "Restart does not reuse identities")
		replacement.start_day(day)
		replacement.finish_intro(replacement.generation)
		replacement.request_next_visit(replacement.generation)
		_check(replacement.current_visit_id != session.current_visit_id
			and not replacement.service_reached(session.current_visit_id), "Reloaded instance rejects old scene identities")
		var current_id: String = session.current_visit_id
		generation = session.generation
		session.begin_transition()
		var transition_generation: int = session.generation
		session.begin_transition()
		_check(session.generation == transition_generation and transition_generation != generation, "Transition invalidation is idempotent")
		_check(not session.service_reached(current_id) and session.submit_decision(current_id, code).is_empty()
			and session.request_next_visit(generation).is_empty(), "Transition rejects all gameplay commands")
	# Interromper regra pendente também invalida uma confirmação que já estava aguardando.
	day = load("res://src/gameplay/schedules/day1.tres")
	session.start_day(day)
	var generation: int = session.generation
	session.finish_intro(generation)
	for index in 2:
		var entry: Dictionary = session.request_next_visit(generation)
		var visit_id: String = session.current_visit_id
		session.service_reached(visit_id)
		session.submit_decision(visit_id, Validator.andar_esperado(entry.visitor, entry.dialogue, 1))
		session.complete_visit(visit_id)
		if index == 0:
			session.finish_interval(visit_id)
	var pending: MartaRule = session.take_due_rule(session.current_visit_id)
	_check(pending != null, "Pending rule exists before reset test")
	session.start_day(day)
	_check(not session.activate_pending_rule(generation, pending) and not session.finish_rule(generation, pending)
		and session.active_rules.is_empty() and session.pending_rule == null, "Reset cancels pending announcement")
	session.start_day(null)
	_check(session.day_number == 1 and session.queue_data.is_empty() and not session.has_next_day(), "Null configuration preserves empty-day fallback")
	session.free()
	replacement.free()


func _run() -> void:
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/gameplay_regression/fixtures/schedule_snapshots.json"))
	for number in range(1, 4):
		_real_day(number, fixtures.sessions[number - 1].snapshot)
	_restarts_and_codes()
	print("I1_SESSION_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
