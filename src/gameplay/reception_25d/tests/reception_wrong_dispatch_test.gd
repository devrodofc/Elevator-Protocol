extends SceneTree

const GAME = "res://src/gameplay/reception_25d/scenes/reception_3d.tscn"
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	create_timer(400).timeout.connect(func(): quit(1))
	call_deferred("run")


func advance(scene: Node) -> void:
	for npc in [scene.marta, scene.story.godofredo]:
		if npc.paper.visible:
			var event := InputEventAction.new()
			event.action = &"ui_accept"
			event.pressed = true
			npc.paper.forward_input(event)


func run() -> void:
	var session = load("res://src/gameplay/scripts/reception_session.gd").new()
	var validator = load("res://src/shared/scripts/rule_validator.gd")
	var day = load("res://src/gameplay/schedules/day1.tres")
	root.add_child(session)
	for mode in [false, true]:
		session.allow_wrong_dispatches = mode
		session.start_day(day)
		session.finish_intro(session.generation)
		var entry: Dictionary = session.request_next_visit(session.generation)
		var id: String = session.current_visit_id
		check(session.submit_decision(id, -1).is_empty(), "Unconfirmed arrival cannot count")
		session.service_reached(id)
		var right: int = validator.andar_esperado(entry.visitor, entry.dialogue, 1, [])
		var result: Dictionary = session.submit_decision(id, right)
		check(
			result.correct and session.wrong_dispatches == 0, "Correct destination does not count"
		)
		check(session.submit_decision(id, -1).is_empty(), "Duplicate rejected")
		session.start_dispatch_preview(day)
		entry = session.request_next_visit(session.generation)
		id = session.current_visit_id
		session.service_reached(id)
		session.submit_decision(id, 999)
		check(session.wrong_dispatches == 0, "Refusal never counts")
		session.start_dispatch_preview(day)
		entry = session.request_next_visit(session.generation)
		id = session.current_visit_id
		session.service_reached(id)
		var wrong := -1
		if validator.validar_decisao(entry.visitor, entry.dialogue, wrong, 1, []):
			wrong = 6
		session.submit_decision(id, wrong)
		check(session.wrong_dispatches == (1 if mode else 0), "Only opted-in 3D counts errors")
		check(
			session.state == (session.State.RESOLVED if mode else session.State.FAILED),
			"Legacy session still fails immediately"
		)
		session.start_day(day)
		check(session.wrong_dispatches == 0, "New day resets counter")
	session.queue_free()

	var scene = load(GAME).instantiate()
	var args := OS.get_cmdline_user_args()
	var selected_day := int(args[0]) if not args.is_empty() else 1
	scene.test_day = selected_day
	root.add_child(scene)
	current_scene = scene
	scene.story.set_process(false)
	var rules := [0]
	scene.rule_announced.connect(func(_rule): rules[0] += 1)
	for count in [1, 2, 3]:
		for frame in 12000:
			if scene.desk.badge.available and scene.stage == scene.Stage.AT_SERVICE:
				break
			if frame % 3 == 0:
				advance(scene)
			await process_frame
		check(scene.stage == scene.Stage.AT_SERVICE, "Visitor reaches service")
		var entry: Dictionary = scene.session.current_entry
		var wrong := -1
		if validator.validar_decisao(
			entry.visitor,
			entry.dialogue,
			wrong,
			scene.session.day_number,
			scene.session.active_rules,
			entry
		):
			wrong = 6
		scene.desk.select_floor(wrong)
		check(scene.session.wrong_dispatches == count - 1, "Selection alone does not count")
		scene.desk.confirm_selection()
		for i in 12:
			await process_frame
		check(scene.session.wrong_dispatches == count, "Confirmed error increments once")
		check(
			scene.session.submit_decision(scene.visit_id, wrong).is_empty(),
			"Duplicate decision rejected"
		)
		check(
			scene.hud.wrong_dispatches_label.text.ends_with("%d/3" % count),
			"HUD updates immediately"
		)
		check(scene.story.warnings == 0, "Warnings remain independent")
	check(rules[0] >= 1, "Normal Marta rule appearance remains functional")
	var original_id: int = scene.get_instance_id()
	for i in 6000:
		if scene.marta.paper.visible:
			break
		await process_frame
	check(
		scene.stage == scene.Stage.FAILING and scene.desk._cancelled,
		"Third error locks all decisions"
	)
	var speech_version: int = scene.marta.paper.dialogue._dialogue_version
	scene._run_dispatch_failure()
	check(
		scene.marta.paper.dialogue._dialogue_version == speech_version,
		"Failure cannot trigger twice"
	)
	for i in 120:
		await process_frame
	check(current_scene.get_instance_id() == original_id, "Complaint waits for player")
	for i in 12000:
		if current_scene.get_instance_id() != original_id:
			break
		if i % 3 == 0:
			advance(scene)
		await process_frame
	check(current_scene.get_instance_id() != original_id, "Last complaint page reloads scene")
	check(current_scene.session.day_number == selected_day, "Same day restarted")
	check(current_scene.session.wrong_dispatches == 0, "Retry resets counter")
	current_scene.queue_free()
	current_scene = null
	await process_frame
	print("WRONG_DISPATCH_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
