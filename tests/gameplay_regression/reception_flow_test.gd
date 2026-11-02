extends SceneTree
## I0: drive the unchanged 2D scene, its real UI handlers, signals, timers and tweens.
## No actor teleportation, fake manager, shortened timings or edited day resources.

const RECEPTION := "res://src/gameplay/reception/scenes/reception.tscn"
const END_SCREEN := "res://src/ui/menus/scenes/end_screen.tscn"
const Validator = preload("res://src/shared/scripts/rule_validator.gd")
const VisitorResource = preload("res://src/npcs/resources/scripts/visitor_data.gd")
const DialogueResource = preload("res://src/npcs/dialogue/npc_dialogue.gd")

var checks: int = 0
var failures: int = 0
var decisions: int = 0
var denials: int = 0
var announcements: int = 0
var confirmations: int = 0
var scenario: String = "progression"
var dialogue: Node


func _initialize() -> void:
	create_timer(1800.0).timeout.connect(func():
		push_error("I0 flow watchdog: no completed result")
		quit(1)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _wait_until(predicate: Callable, description: String, max_frames: int = 6000) -> bool:
	for frame in max_frames:
		if predicate.call():
			return true
		await process_frame
	_check(false, "Timeout: " + description)
	return false


func _frames(count: int) -> void:
	for frame in count:
		await process_frame


func _mouse_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _accept_dialogue() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = pressed
		root.push_input(event)


func _normal_text(value: String) -> String:
	return " ".join(value.replace("\n", " ").replace("\r", " ").replace("\t", " ").split(" ", false))


func _dialogue_is(text: String) -> bool:
	return dialogue.visible and _normal_text(" ".join(dialogue._pages)) == _normal_text(text)


func _finish_marta(scene: Node, text: String, kind: String) -> bool:
	if not await _wait_until(func(): return _dialogue_is(text), "Marta dialogue: " + kind):
		return false
	var actor = scene.marta_instance
	_check(is_instance_valid(actor) and not actor.is_moving, "Marta at focus before dialogue: " + kind)
	if is_instance_valid(actor):
		_check(actor.global_position.is_equal_approx(scene.marta_point.global_position), "Marta reaches actual marker")
	_check(scene.elevator_panel.locked, "Panel locked during Marta: " + kind)
	var active_before: int = scene.active_rules.size()
	var pending: Resource
	if kind == "rule":
		pending = scene._rules_today[active_before]
		_check(not scene.active_rules.has(pending), "Announced rule is not active at dialogue start")
		_check(scene._served_count == 2 or scene._served_count == 4, "Announcements occur after 2/4 served visitors")
		_check(scene.current_entry.is_empty() and scene.queue_data.size() == 7 - scene._served_count, "Marta does not consume visitor queue")
	# Advance real pages, but withhold the final accept after text is complete.
	var complete := false
	for frame in range(600):
		if dialogue._page == dialogue._pages.size() - 1 and not dialogue._is_typing():
			complete = true
			break
		_accept_dialogue()
		await _frames(2)
	_check(complete, "Marta reaches last fully typed page")
	await _frames(10)
	_check(scene.active_rules.size() == active_before, "Text completion alone never activates a rule")
	if kind == "rule" and pending.tem_efeito():
		var visitor = VisitorResource.new()
		var request = DialogueResource.new()
		request.andar_desejado = pending.andar_pedido
		_check(Validator.andar_esperado(visitor, request, scene.schedule_config.dia_numero, scene.active_rules)
			== request.andar_desejado, "Pending effect absent before final player advance")
	if kind != "failure-timeout":
		_accept_dialogue()
	if kind == "rule":
		if not await _wait_until(func(): return scene.active_rules.size() == active_before + 1, "Rule activated after advance"):
			return false
		_check(scene.active_rules[active_before] == pending, "Exactly the announced resource becomes active")
		if pending.tem_efeito():
			var visitor = VisitorResource.new()
			var request = DialogueResource.new()
			request.andar_desejado = pending.andar_pedido
			_check(Validator.andar_esperado(visitor, request, scene.schedule_config.dia_numero, scene.active_rules)
				== pending.andar_destino, "Actual active list changes destination only after announcement")
		var board = scene.reception_hud.get_node("RulesBoard")
		var board_text: String = pending.texto_prancheta if not pending.texto_prancheta.is_empty() else pending.fala
		_check(board._rules.has(board_text), "Rule copied to actual board only after announcement")
		announcements += 1
		print("I0_RULE day=%d served=%d active=%d" % [scene.schedule_config.dia_numero, scene._served_count, scene.active_rules.size()])
	elif kind == "intro":
		_check(scene.active_rules.is_empty() and scene._served_count == 0, "Introduction neither activates rule nor serves visitor")
	return true


func _entry_value(entry: Dictionary) -> String:
	return JSON.stringify({"visitor": entry.visitor.resource_path, "nome": entry.nome,
		"sprite": entry.sprite.resource_path if entry.sprite else "", "cracha": entry.cracha,
		"dialogue": entry.dialogue.resource_path, "texto": entry.dialogue.texto,
		"andar": entry.dialogue.andar_desejado, "fixo": entry.fixo})


func _arrival(scene: Node, expected: Dictionary) -> Node:
	if not await _wait_until(func(): return is_instance_valid(scene.current_visitor_node), "Visitor instantiated"):
		return null
	var actor = scene.current_visitor_node
	_check(actor.is_moving and scene.elevator_panel.locked, "Panel remains locked during real arrival movement")
	_check(_entry_value(scene.current_entry) == _entry_value(expected), "FIFO entry preserved from initial queue")
	_check(actor.current_data == expected.visitor and actor.current_sprite == expected.sprite, "Actor uses exact visitor and sampled sprite")
	if not await _wait_until(func(): return not actor.is_moving, "Real actor arrival tween"):
		return null
	_check(actor.global_position.is_equal_approx(scene.desk_point.global_position), "Visitor reaches DeskPoint")
	_check(not scene.elevator_panel.locked and _dialogue_is(expected.dialogue.texto), "Arrival opens dialogue and unlocks panel")
	_check(dialogue._name_label.text == expected.nome, "Dialogue uses sampled visit name")
	var hud = scene.reception_hud
	_check(hud._current_visitor == actor and hud.badge.visible, "Arrival associates visible badge with actor")
	if not await _wait_until(func(): return hud._badge_interactive, "Badge transfer tween"):
		return null
	var badge = hud.badge_details
	_check(badge._photo.texture == actor.get_badge_photo() and badge._photo.texture != null, "Badge photo follows actual visitor")
	_check(badge._name.text == expected.nome, "Badge preserves sampled name including authored whitespace")
	var expected_age: String = str(expected.cracha.idade) if expected.cracha.idade > 0 else "Não informado"
	_check(badge._age.text == expected_age, "Badge preserves sampled/unspecified age")
	for field in ["sexo", "ocupacao"]:
		var value: String = expected.cracha[field]
		var label = badge._sex if field == "sexo" else badge._occupation
		_check(label.text == (value if not value.strip_edges().is_empty() else "Não informado"), "Badge field: " + field)
	hud._on_badge_gui_input(_mouse_click())
	_check(badge.visible and scene.elevator_panel.locked, "Actual badge open handler locks panel")
	var count_before: int = scene._served_count
	# A click on a disabled floor control must not submit or change visitor.
	scene.elevator_panel._floor_buttons[0]._gui_input(_mouse_click())
	_check(scene._served_count == count_before and scene.current_visitor_node == actor, "No decision while inspecting badge")
	badge._on_outside_gui_input(_mouse_click())
	_check(not badge.visible and not scene.elevator_panel.locked, "Outside-close handler restores panel")
	_check(_entry_value(scene.current_entry) == _entry_value(expected), "Inspection does not resample visit")
	return actor


func _submit(scene: Node, code: int) -> void:
	var panel = scene.elevator_panel
	var chosen: Control
	for button in panel._floor_buttons:
		if button.code == code:
			chosen = button
	_check(chosen != null, "Panel contains requested decision code %d" % code)
	if chosen == null:
		return
	chosen._gui_input(_mouse_click())
	_check(panel._selected_code == code and not panel._confirm.disabled, "Selection enables confirmation")
	chosen._gui_input(_mouse_click())
	_check(panel._selected_code == null and panel._confirm.disabled, "Repeated floor click deselects")
	chosen._gui_input(_mouse_click())
	panel._confirm._gui_input(_mouse_click())
	_check(panel.locked, "Confirm locks synchronously before its 0.15s delay")
	# Repeat through the real confirmation handler while the first confirmation is pending.
	panel._confirm._gui_input(_mouse_click())
	panel._on_confirm_pressed(0)
	_check(panel.locked, "Repeated confirmation cannot unlock/reenter")


func _new_scene(day_number: int, random_seed: int) -> Node:
	# Dynamic loading after autoload initialization, as documented in CLAUDE section 12.
	var manager_script = load("res://src/gameplay/reception/scripts/reception_manager.gd")
	manager_script.dia_em_andamento = load("res://src/gameplay/schedules/day%d.tres" % day_number) if day_number != 1 else null
	seed(random_seed)
	_check(change_scene_to_file(RECEPTION) == OK, "Original scene loads")
	if not await _wait_until(func(): return current_scene != null and current_scene.scene_file_path == RECEPTION, "Original scene ready"):
		return null
	return current_scene


func _check_day_start(scene: Node, number: int) -> Array:
	_check(scene.schedule_config.dia_numero == number and scene.queue_data.size() == 7, "Day starts with configured seven visits")
	_check(scene.current_entry.is_empty() and scene.active_rules.is_empty() and scene._served_count == 0, "Day starts with no service/count/active rules")
	_check(scene.elevator_panel.locked and not scene.reception_hud.badge.visible, "Initial panel/badge state")
	_check(scene._rules_today.size() == 2, "Rules selected but not active at day start")
	scene.elevator_panel.floor_selected.connect(func(_code: int): confirmations += 1)
	# Keep the actual generated queue. Never call montar_dia() again for comparison.
	return scene.queue_data.duplicate(true)


func _success_day(scene: Node, number: int) -> bool:
	var entries := _check_day_start(scene, number)
	if not await _finish_marta(scene, scene.schedule_config.mensagem_inicio, "intro"):
		return false
	var intro_actor = weakref(scene.marta_instance)
	var departing_actors: Array[WeakRef] = []
	for index in range(7):
		var actor = await _arrival(scene, entries[index])
		if actor == null:
			return false
		_check(intro_actor.get_ref() == null, "Introduction Marta really exits before first service")
		_check(scene._served_count == index, "No count before decision")
		_check(scene.active_rules.size() == mini(index / 2, 2), "Active rules match completed announcement count")
		if index == 0:
			var book = scene.reception_hud.get_node("CompanyBook")
			var page_before: int = book._page
			book.next_page()
			_check(book._page == (page_before + 1) % book.page_count(), "Real book changes page")
			book.previous_page()
			_check(book._page == page_before, "Real book returns to previous page")
			var board = scene.reception_hud.get_node("RulesBoard")
			board.open()
			_check(board.is_open, "Rule board opens without changing visit")
			board.close()
			_check(not board.is_open, "Rule board closes")
		var code: int = Validator.andar_esperado(entries[index].visitor, entries[index].dialogue, number, scene.active_rules)
		if index == 6:
			_check(code == (3 if number == 1 else -1), "Concrete final visitor destination")
		var sent_before := confirmations
		departing_actors.append(weakref(actor))
		_submit(scene, code)
		scene.reception_hud.badge_details.open()
		_check(not scene.reception_hud.badge_details.visible, "Badge cannot reopen during pending confirmation")
		if not await _wait_until(func(): return scene._served_count == index + 1, "Successful decision processed"):
			return false
		_check(confirmations == sent_before + 1, "Duplicate confirmation emits one floor_selected")
		_check(scene.current_entry.is_empty() and scene.current_visitor_node == null, "Successful decision clears current service")
		_check(not dialogue.visible and scene.elevator_panel.locked, "Successful decision clears speech and locks panel")
		_check(not actor.arrived.is_connected(scene._update_badge_visitor), "Departure no longer updates another visitor's badge")
		if code == 999:
			denials += 1
			var departed: Array = []
			actor.departed.connect(func(): departed.append(actor.global_position))
			if not await _wait_until(func(): return not departed.is_empty(), "Refused visitor leaves naturally"):
				return false
			_check(departed[0].is_equal_approx(scene.spawn_point.global_position), "Correct refusal returns to original entrance")
		else:
			_check(scene.elevator.is_busy() and actor.is_moving, "Authorized visitor uses real elevator receive")
		decisions += 1
		if index == 1 or index == 3:
			if not await _finish_marta(scene, scene._rules_today[index / 2].fala, "rule"):
				return false
		await _frames(2)
	_check(scene._served_count == 7 and scene.queue_data.is_empty(), "Day consumes seven visits")
	_check(scene.active_rules.size() == 2 and scene._next_rule_index == 2, "No extra announcement after final visitor")
	if not await _finish_marta(scene, scene.schedule_config.mensagem_fim, "ending"):
		return false
	for actor_ref in departing_actors:
		_check(actor_ref.get_ref() == null, "All seven outgoing actors are actually freed by day ending")
	if number == 2:
		_check(scene.marta_instance.get_node("Sprite2D").texture == scene.schedule_config.sprite_marta_fim, "Day-two Marta uses configured final sprite")
	print("I0_DAY_COMPLETED day=%d decisions=7 active_rules=2" % number)
	return true


func _failure_case(number: int, automatic_timeout: bool = false) -> void:
	var scene = await _new_scene(number, 4300 + number)
	if scene == null:
		return
	var entries := _check_day_start(scene, number)
	if not await _finish_marta(scene, scene.schedule_config.mensagem_inicio, "intro"):
		return
	var actor = await _arrival(scene, entries[0])
	if actor == null:
		return
	var correct: int = Validator.andar_esperado(entries[0].visitor, entries[0].dialogue, number, scene.active_rules)
	var wrong := 999 if correct != 999 else 1
	var original_id := scene.get_instance_id()
	_submit(scene, wrong)
	if not await _wait_until(func(): return scene.is_processing_decision, "Failure enters processing state"):
		return
	_check(scene._served_count == 0 and scene.elevator_panel.locked, "Wrong decision does not count as success")
	var departed: Array = []
	var actor_ref: WeakRef = weakref(actor)
	actor.departed.connect(func(): departed.append(actor.global_position))
	if not await _finish_marta(scene, scene.schedule_config.mensagem_falha, "failure-timeout" if automatic_timeout else "failure"):
		return
	_check(not departed.is_empty() and departed[0].is_equal_approx(scene.spawn_point.global_position), "Failure sends visitor back through entrance")
	_check(scene.current_visitor_node == null and scene._served_count == 0, "Failure removes actor without serving visit")
	if number == 1:
		_check(scene.marta_instance.get_node("Sprite2D").texture.resource_path == "res://src/npcs/assets/marta/marta_anger.png", "Day-one failure shows angry Marta")
	if not await _wait_until(func(): return current_scene != null and current_scene.get_instance_id() != original_id, "Actual same-day scene reload"):
		return
	_check(current_scene.scene_file_path == RECEPTION and current_scene.schedule_config.dia_numero == number, "Reload stays on same day/presentation")
	_check(current_scene.queue_data.size() == 7 and current_scene.active_rules.is_empty()
		and current_scene._served_count == 0 and current_scene.current_entry.is_empty(), "Reload rebuilds queue and clears transient state")
	_check(current_scene.elevator_panel.locked and not current_scene.reception_hud.badge.visible, "Reload restarts introduction with locked UI")
	_check(actor_ref.get_ref() == null, "Failed visitor was freed before reloaded session")
	print("I0_FAILURE_RELOAD day=%d automatic_timeout=%s" % [number, automatic_timeout])


func _run() -> void:
	dialogue = root.get_node("Dialogue")
	var version := Engine.get_version_info()
	_check(version.major == 4 and version.minor == 7 and version.patch == 2, "Pinned engine 4.7.2")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scenario="):
			scenario = argument.trim_prefix("--scenario=")
	if scenario.begins_with("failure-timeout-"):
		var number := scenario.trim_prefix("failure-timeout-").to_int()
		_check(number in [1, 2, 3], "Known timeout failure scenario")
		if number in [1, 2, 3]:
			await _failure_case(number, true)
	elif scenario.begins_with("failure-"):
		var number := scenario.trim_prefix("failure-").to_int()
		_check(number in [1, 2, 3], "Known failure scenario")
		if number in [1, 2, 3]:
			await _failure_case(number)
	elif scenario == "progression" or scenario == "denial":
		var first_day := 3 if scenario == "denial" else 1
		var scene = await _new_scene(first_day, 4203 if scenario == "denial" else 4201)
		if scene != null:
			for number in range(first_day, 4):
				if not await _success_day(scene, number):
					break
				var old_id: int = scene.get_instance_id()
				if not await _wait_until(func(): return current_scene != null and current_scene.get_instance_id() != old_id, "Natural day transition"):
					break
				if number < 3:
					scene = current_scene
					_check(scene.scene_file_path == RECEPTION and scene.schedule_config.dia_numero == number + 1, "Natural progression preserves 2D scene and next day")
				else:
					_check(current_scene.scene_file_path == END_SCREEN, "Third day opens actual final scene")
					var manager_script = load("res://src/gameplay/reception/scripts/reception_manager.gd")
					_check(manager_script.dia_em_andamento == null, "Final transition clears static day")
		_check(decisions == (7 if scenario == "denial" else 21), "All planned decisions completed")
		_check(announcements == (2 if scenario == "denial" else 6), "All planned announcements completed")
		if scenario == "denial":
			_check(denials > 0, "Dedicated seeded scenario exercises real correct refusal")
	else:
		_check(false, "Unknown scenario: " + scenario)
	dialogue.clear_dialogue()
	await _wait_until(func(): return not root.get_node("SceneTransition").is_busy(), "Final fade completed")
	# Teardown only, after all gameplay assertions: release headless audio playbacks.
	for type in ["AudioStreamPlayer", "AudioStreamPlayer2D"]:
		for player in root.find_children("*", type, true, false):
			player.stop()
	if current_scene != null:
		current_scene.queue_free()
	await _frames(3)
	OS.delay_msec(50) # Allow the audio mixing thread to process the stop commands.
	print("I0_FLOW_RESULT scenario=%s checks=%d failures=%d decisions=%d denials=%d announcements=%d" % [scenario, checks, failures, decisions, denials, announcements])
	quit(1 if failures else 0)
