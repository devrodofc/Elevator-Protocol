extends SceneTree
## I4: real decisions resolve to cabin 1 or to the entrance; one release per visit; serial next visit.
const SCENE = "res://src/gameplay/reception_25d/scenes/reception_gameplay_test.tscn"
const Session = preload("res://src/gameplay/scripts/reception_session.gd")
const Validator = preload("res://src/shared/scripts/rule_validator.gd")
const Door = preload("res://src/gameplay/reception_25d/scripts/automatic_door.gd")
const Cabin = preload("res://src/gameplay/reception_25d/scripts/elevator_door.gd")
var Presenter
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(900).timeout.connect(func(): quit(1))
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(n: int) -> void:
	for i in n:
		await process_frame

func until(predicate: Callable, label: String) -> bool:
	for i in 1800:
		if predicate.call():
			return true
		await process_frame
	check(false, "Timed out: " + label)
	return false

func _session_contract() -> void:
	var day: DayScheduleConfig = load("res://src/gameplay/schedules/day1.tres")
	var session := Session.new()
	root.add_child(session)
	session.start_dispatch_preview(day)
	check(session.state == Session.State.READY and session.active_rules.is_empty(), "Dispatch preview starts without Marta")
	var total := session.queue_data.size()
	for i in total:
		var entry := session.request_next_visit(session.generation)
		var id := session.current_visit_id
		check(not entry.is_empty(), "Every queued visit is served")
		check(session.service_reached(id), "Arrival milestone")
		var code := Validator.andar_esperado(entry.visitor, entry.dialogue, 1, [])
		check(session.submit_decision(id, code).correct, "Shared validator decides")
		check(session.complete_visit(id) and session.served_count == i + 1, "Counted once per correct decision")
		check(not session.complete_visit(id), "No double count")
		check(session.take_due_rule(id) == null, "No Marta rule in I4")
		check(session.request_next_visit(session.generation).is_empty(), "Serial: no next visit before release")
		check(session.finish_interval(id), "Release reopens the queue")
	check(session.request_next_visit(session.generation).is_empty() and session.state == Session.State.CONCLUDING, "Queue ends in CONCLUDING")
	session.start_day(day)
	check(session.state == Session.State.INTRO, "2D start remains normal")
	session.queue_free()
	await process_frame

func _all_elevators_closed(scene) -> bool:
	for elevator in scene.get_node("RoomViewport/Room/Elevators").get_children():
		if elevator.state != Cabin.State.CLOSED:
			return false
	return true

## Plays a whole day answering correctly. Returns [boardings, refusals].
func _play_day(day: int, entrance: int, refusal_rule: MartaRule) -> Array:
	seed(4400 + day)
	var scene = load(SCENE).instantiate()
	scene.enable_marta = false
	scene.test_day = day
	scene.initial_entrance = entrance
	root.add_child(scene)
	var session = scene.session
	var desk = scene.desk
	if refusal_rule:
		# Stands in for a rule Marta already announced (I5). The validator still decides alone.
		session._active_rules.append(refusal_rule)
	var departed: Array[String] = []
	scene.visit_departed.connect(func(id: String): departed.append(id))
	var total: int = session.queue_data.size() + 1
	var boardings := 0
	var refusals := 0
	for n in total:
		var id: String = scene.visit_id
		var entry: Dictionary = scene.visit_entry
		if not await until(func(): return desk.badge.available, "badge of visit %d" % n):
			break
		check(desk.result.is_empty() and desk.selected_floor == 0, "Fresh desk for each visit")
		check(desk.paper.visible and desk.paper.dialogue._name_label.text == entry.nome, "Speech of the current visit")
		check(session.served_count == n and departed.size() == n, "Counts before decision")
		check(scene.actor.global_position.is_equal_approx(scene.service_point.global_position), "At the counter")
		var code: int = Validator.andar_esperado(entry.visitor, entry.dialogue, day, session.active_rules)
		desk.select_floor(code)
		desk.confirm_selection()
		if not await until(func(): return not desk.result.is_empty(), "result %d" % n):
			break
		check(desk.result.correct and desk.result.floor_code == code, "Correct floor code, not a cabin index")
		check(session.served_count == n + 1, "Counted at the decision, before the release")
		check(scene.stage == Presenter.Stage.AT_SERVICE and desk.transfer.collecting, "Waits for the badge to return")
		if code == Validator.DENY_ACTION:
			refusals += 1
			await until(func(): return scene.stage == Presenter.Stage.TO_EXIT, "exit route")
			check(scene._door.state != Door.State.CLOSED, "Exit door opens for the refused visitor")
			await until(func(): return scene.stage == Presenter.Stage.CLOSING_EXIT, "exit closing")
			check(not scene.actor.visible, "Hidden in the vestibule before the leaves close")
			check(departed.size() == n, "Closing started is not a release")
		else:
			boardings += 1
			await until(func(): return scene.stage == Presenter.Stage.ENTERING_CABIN, "cabin entry")
			check(scene.cabin.state == Cabin.State.OPEN, "Cabin 1 open before entering")
			check(scene._door.state == Door.State.CLOSED, "Entrance stays closed while boarding")
			await until(func(): return scene.cabin.state == Cabin.State.CLOSING, "cabin closing")
			check(departed.size() == n, "Closing started is not a release")
		if not await until(func(): return departed.size() == n + 1, "release %d" % n):
			break
		check(departed[n] == id, "Release belongs to this visit")
		check(_all_elevators_closed(scene), "All cabins closed at release")
		if n < total - 1:
			check(scene.visit_id != id and scene.stage == Presenter.Stage.WAITING_FOR_DOOR, "Next visit only after release")
			check(scene.cabin.state == Cabin.State.CLOSED, "Cabin closed when the next visit enters")
			check(not desk.badge.visible and desk.result.is_empty() and not desk.paper.visible and desk.selected_floor == 0,
				"No inherited badge, result, speech or selection")
			check(session.submit_decision(id, code).is_empty(), "Old identity rejected")
	await frames(5)
	check(scene.stage == Presenter.Stage.DAY_DONE and session.state == Session.State.CONCLUDING, "Day ends after the queue")
	check(session.served_count == total and departed.size() == total and scene.departed_count == total, "One count and one release per visit")
	check(not scene.actor.visible and _all_elevators_closed(scene) and scene._door.state == Door.State.CLOSED, "Room settled at the end")
	scene.queue_free()
	await frames(3)
	return [boardings, refusals]

func _wrong_answer() -> void:
	seed(4500)
	var scene = load(SCENE).instantiate()
	scene.enable_marta = false
	root.add_child(scene)
	var desk = scene.desk
	var entry: Dictionary = scene.visit_entry
	await until(func(): return desk.badge.available, "badge before error")
	var code: int = Validator.andar_esperado(entry.visitor, entry.dialogue, 1, [])
	var wrong: int = 1 if code != 1 else 2
	desk.select_floor(wrong)
	desk.confirm_selection()
	await until(func(): return not desk.result.is_empty(), "wrong result")
	check(not desk.result.correct and scene.stage == Presenter.Stage.FAILED, "Wrong answer holds for I6")
	var position: Vector3 = scene.actor.global_position
	await frames(240)
	check(scene.actor.global_position == position and not scene.movement.is_processing(), "Wrong answer never departs")
	check(_all_elevators_closed(scene) and scene.session.served_count == 0 and scene.departed_count == 0, "No cabin, count or release on error")
	check(scene.session.queue_data.size() == 6 and scene.session.state == Session.State.FAILED, "No next visit after error")
	scene.queue_free()
	await frames(3)

func _cancel_during_departure() -> void:
	seed(4600)
	var scene = load(SCENE).instantiate()
	scene.enable_marta = false
	root.add_child(scene)
	var desk = scene.desk
	var departed: Array = []
	scene.visit_departed.connect(func(id): departed.append(id))
	var entry: Dictionary = scene.visit_entry
	await until(func(): return desk.badge.available, "badge before cancel")
	desk.select_floor(Validator.andar_esperado(entry.visitor, entry.dialogue, 1, []))
	desk.confirm_selection()
	await until(func(): return scene.stage == Presenter.Stage.ENTERING_CABIN, "boarding before cancel")
	scene.cancel_preview()
	await frames(90)
	check(scene.stage == Presenter.Stage.CANCELLED and departed.is_empty(), "Cancelled boarding never releases")
	check(scene.cabin.state == Cabin.State.CLOSED and not scene.movement.is_processing() and not scene.actor.visible, "Cancel resets cabin and actor")
	check(scene.session.state == Session.State.CLOSED, "Cancel closes the session")
	scene.queue_free()
	await frames(3)

func _run() -> void:
	Presenter = load("res://src/gameplay/reception_25d/scripts/reception_presentation.gd")
	await _session_contract()
	var day1: DayScheduleConfig = load("res://src/gameplay/schedules/day1.tres")
	var deny_fourth: MartaRule
	for rule in day1.regras_marta:
		if rule.andar_pedido == 4 and rule.andar_destino == Validator.DENY_ACTION:
			deny_fourth = rule
	check(deny_fourth != null, "Day 1 has the real 4th-floor refusal rule")
	var totals := [0, 0]
	for setup in [[1, 0, deny_fourth], [2, 1, null], [3, 0, null], [1, 1, deny_fourth]]:
		var counts: Array = await _play_day(setup[0], setup[1], setup[2])
		totals[0] += counts[0]
		totals[1] += counts[1]
	check(totals[0] > 0 and totals[1] > 0, "Both cabin boarding and entrance refusal exercised")
	await _wrong_answer()
	await _cancel_during_departure()
	print("I4_DISPATCH_RESULT checks=%d failures=%d boardings=%d refusals=%d" % [checks, failures, totals[0], totals[1]])
	quit(1 if failures else 0)
