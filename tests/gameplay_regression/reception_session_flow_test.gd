extends "res://tests/gameplay_regression/reception_flow_test.gd"
## I1: contratos da sessão no manager real e interrupções pelos caminhos existentes.

const Session := preload("res://src/gameplay/scripts/reception_session.gd")


func _wait_new_scene(old_id: int, path: String) -> Node:
	if not await _wait_until(func(): return current_scene != null and current_scene.get_instance_id() != old_id, "I1 actual scene replacement"):
		return null
	_check(current_scene.scene_file_path == path, "Existing scene destination preserved")
	return current_scene


func _manager_contracts() -> void:
	var scene = await _new_scene(1, 4201)
	if scene == null:
		return
	var session: Node = scene.session
	_check(session is Session and session.get_parent() == scene, "2D owns one local ReceptionSession")
	_check(root.get_node_or_null("ReceptionSession") == null, "Session is not an autoload")
	_check(scene.queue_data == session.queue_data and scene.queue_data.is_read_only(), "Manager exposes only session's queue view")
	_check(scene._rules_today == session.rules_today and scene.active_rules == session.active_rules, "Rules delegate to session")
	var entries := _check_day_start(scene, 1)
	scene._call_next_visitor()
	_check(scene.queue_data.size() == 7 and scene.current_visitor_node == null, "Manager cannot skip intro")
	if not await _finish_marta(scene, scene.schedule_config.mensagem_inicio, "intro"):
		return
	if not await _wait_until(func(): return is_instance_valid(scene.current_visitor_node), "I1 arrival starts"):
		return
	var first_id: String = session.current_visit_id
	var first_actor: Node = scene.current_visitor_node
	var first_badge_callback: Callable = scene._badge_arrival_callback
	var first_decision_callback: Callable = scene._decision_callback
	scene._on_floor_selected(1, first_id)
	scene._call_next_visitor()
	_check(session.state == Session.State.ARRIVING and session.served_count == 0 and scene.queue_data.size() == 6, "Manager rejects decision/advance during arrival")
	var actor = await _arrival(scene, entries[0])
	if actor == null:
		return
	_check(scene.current_entry == session.current_entry and scene._served_count == session.served_count, "Current visit/count have one owner")
	_check(first_actor.arrived.is_connected(first_badge_callback), "Arrival signal carries occurrence identity")
	var code: int = Validator.andar_esperado(entries[0].visitor, entries[0].dialogue, 1)
	_submit(scene, code)
	if not await _wait_until(func(): return session.served_count == 1, "I1 first actual UI decision"):
		return
	_check(not first_actor.arrived.is_connected(first_badge_callback), "Bound badge callback is really disconnected on departure")
	first_decision_callback.call(code)
	scene._process_success(code, first_id)
	scene._call_next_visitor()
	_check(session.served_count == 1 and session.state == Session.State.INTERVAL and scene.queue_data.size() == 6, "Duplicates cannot recount or skip interval")
	actor = await _arrival(scene, entries[1])
	if actor == null:
		return
	var second_id: String = session.current_visit_id
	var current_hud_actor = scene.reception_hud._current_visitor
	first_badge_callback.call()
	scene._on_visitor_arrived_at_desk(first_id)
	first_decision_callback.call(code)
	_check(session.current_visit_id == second_id and session.state == Session.State.SERVING
		and scene._served_count == 1 and scene.reception_hud._current_visitor == current_hud_actor,
		"Old actor/decision callbacks cannot alter next visit or badge")
	# Confirmar de verdade e apertar F9 durante os 0,15 s pendentes.
	code = Validator.andar_esperado(entries[1].visitor, entries[1].dialogue, 1)
	_submit(scene, code)
	var old_scene_id: int = scene.get_instance_id()
	var old_generation: int = session.generation
	var key := InputEventKey.new()
	key.keycode = KEY_F9
	key.pressed = true
	scene._unhandled_key_input(key)
	_check(session.state == Session.State.TRANSITION and session.generation != old_generation, "F9 invalidates old session immediately")
	await _frames(15)
	_check(session.served_count == 1 and scene.elevator_panel.locked, "Pending confirm cannot count during fade")
	scene = await _wait_new_scene(old_scene_id, RECEPTION)
	if scene == null:
		return
	_check(scene.session.day_number == 2 and scene.schedule_config == scene.session.schedule_config, "Static day and session preserve F9 day progression")
	_check(not scene.session.service_reached(second_id) and scene.session.served_count == 0, "New day rejects previous scene identity")
	# Cheat original durante a fala da introdução do dia 2.
	if not await _wait_until(func(): return _dialogue_is(scene.schedule_config.mensagem_inicio) and not root.get_node("SceneTransition").is_busy(), "I1 intro ready for cheat"):
		return
	old_scene_id = scene.get_instance_id()
	session = scene.session
	root.get_node("CheatMenu").go_to_day(3)
	await _frames(2)
	_check(session.state == Session.State.TRANSITION and scene._saindo, "External cheat fade cancels async intro")
	scene = await _wait_new_scene(old_scene_id, RECEPTION)
	if scene == null:
		return
	_check(scene.session.day_number == 3 and scene.queue_data.size() == 7, "Cheat still opens original 2D with fresh day-three session")
	entries = _check_day_start(scene, 3)
	if not await _finish_marta(scene, scene.schedule_config.mensagem_inicio, "intro"):
		return
	for index in 2:
		actor = await _arrival(scene, entries[index])
		if actor == null:
			return
		code = Validator.andar_esperado(entries[index].visitor, entries[index].dialogue, 3, scene.active_rules)
		_submit(scene, code)
		if not await _wait_until(func(): return scene._served_count == index + 1, "I1 service before rule interruption"):
			return
	if not await _wait_until(func(): return _dialogue_is(scene._rules_today[0].fala), "I1 pending rule dialogue"):
		return
	session = scene.session
	var pending: MartaRule = session.pending_rule
	old_generation = session.generation
	old_scene_id = scene.get_instance_id()
	_check(session.state == Session.State.RULE and session.active_rules.is_empty(), "Real pending announcement is still inactive")
	# Caminho do pause, não uma troca de cena fabricada pelo teste.
	var pause_menu: Node = scene.get_node("Pause")
	pause_menu.pause_game()
	pause_menu.go_to_main_menu()
	_check(session.state == Session.State.CLOSED and not session.activate_pending_rule(old_generation, pending), "Pause/menu cancels pending rule activation")
	_check(session.active_rules.is_empty(), "Cancelled narrative continuation never activates rule")
	scene = await _wait_new_scene(old_scene_id, "res://src/ui/menus/scenes/menu.tscn")
	if scene != null:
		await _frames(30)
		_check(not dialogue.visible, "No previous reception dialogue survives on menu")
		var manager_script = load("res://src/gameplay/reception/scripts/reception_manager.gd")
		# O tutorial continua zerando o mesmo campo estático ao entrar pelo menu.
		old_scene_id = scene.get_instance_id()
		scene._on_play_pressed()
		scene = await _wait_new_scene(old_scene_id, "res://src/gameplay/tutorial/scenes/tutorial.tscn")
		if scene != null:
			_check(manager_script.dia_em_andamento == null, "Tutorial still resets static day")


func _run() -> void:
	dialogue = root.get_node("Dialogue")
	await _manager_contracts()
	dialogue.clear_dialogue()
	await _wait_until(func(): return not root.get_node("SceneTransition").is_busy(), "I1 final fade")
	for type in ["AudioStreamPlayer", "AudioStreamPlayer2D"]:
		for player in root.find_children("*", type, true, false):
			player.stop()
	if current_scene != null:
		current_scene.queue_free()
	await _frames(3)
	OS.delay_msec(50)
	print("I1_FLOW_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
