extends SceneTree
## I5/I6: Marta's actor, screen effects, intro, rules, failure, end of day and day progression.
const SCENE = "res://src/gameplay/reception_25d/tests/reception_service_fixture.tscn"
const Session = preload("res://src/gameplay/scripts/reception_session.gd")
const Validator = preload("res://src/shared/scripts/rule_validator.gd")
const Cabin = preload("res://src/gameplay/reception_25d/scripts/elevator_door.gd")
const ANGER = preload("res://src/npcs/assets/marta/marta_anger.png")
var Presenter
var MartaActor
var checks: int = 0
var failures: int = 0
## A section aborted by a script error never reaches its last line; _run counts the ones that did.
var sections_done: int = 0

func _initialize() -> void:
	create_timer(1500).timeout.connect(func(): quit(1))
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(n: int) -> void:
	for i in n:
		await process_frame

func until(predicate: Callable, label: String, limit: int = 1800) -> bool:
	for i in limit:
		if predicate.call():
			return true
		await process_frame
	check(false, "Timed out: " + label)
	return false

func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)

func xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

## Scene without Marta orchestration; the actor is driven by hand.
func _plain_scene():
	var scene = load(SCENE).instantiate()
	scene.set("enable_marta", false)
	root.add_child(scene)
	return scene

func _actor_routes() -> void:
	var scene = _plain_scene()
	await until(func(): return scene.desk.badge.available, "visitor at desk")
	var marta = MartaActor.new()
	scene.add_child(marta)
	marta.setup(scene)
	var cabin1: Cabin = scene.get_node("RoomViewport/Room/Elevators/Elevator01")
	var cabin2: Cabin = scene.get_node("RoomViewport/Room/Elevators/Elevator02")
	check(marta.cabin == cabin2 and not marta.ground.visible, "Marta owns cabin 2 and starts hidden")
	var opened := [false]
	var cabin1_opened := [false]
	var watching := [true]
	var watcher := func():
		while watching[0]:
			opened[0] = opened[0] or cabin2.state != Cabin.State.CLOSED
			cabin1_opened[0] = cabin1_opened[0] or cabin1.state != Cabin.State.CLOSED
			await process_frame
	watcher.call()
	var arrived: bool = await marta.arrive_from_cabin(ANGER)
	watching[0] = false
	check(arrived and opened[0], "Arrives through cabin 2")
	check(not cabin1_opened[0], "Cabin 1 stays closed for visitors")
	check(xz(marta.ground.global_position).is_equal_approx(xz(scene.service_point.global_position)), "Stops at the counter")
	check(cabin2.state == Cabin.State.CLOSED and marta.ground.visible, "Cabin 2 closed behind her")
	check(marta.sprite.source_texture == ANGER, "Arrival sprite applied")
	var left: bool = await marta.leave_into_cabin()
	check(left and not marta.ground.visible and cabin2.state == Cabin.State.CLOSED, "Leaves into cabin 2")
	# P toggles both actors once.
	var before: int = scene.orientation.orientation_mode
	key(KEY_P)
	await frames(2)
	check(scene.orientation.orientation_mode != before and marta.orientation.orientation_mode == scene.orientation.orientation_mode, "P switches both actors")
	key(KEY_P)
	await frames(2)
	# Cancel mid-route: no stuck cabin, no visible actor, the await reports false.
	var canceller := func():
		await frames(60)
		marta.cancel()
	canceller.call()
	var result: bool = await marta.arrive_from_cabin()
	check(not result and cabin2.state == Cabin.State.CLOSED and not marta.ground.visible, "Cancel aborts the route cleanly")
	scene.queue_free()
	await frames(3)
	sections_done += 1

func _effects() -> void:
	var scene = _plain_scene()
	var effects = load("res://src/gameplay/reception_25d/scripts/reception_effects.gd").new()
	scene.add_child(effects)
	effects.setup(scene)
	check(effects.layer < scene.get_node("ElevatorUI").layer, "Overlays stay under the elevator UI and modals")
	var red: ColorRect = effects.fade_red()
	await frames(216)
	check(absf(red.color.a - 0.15) < 0.01 and red.color.r > 0.6, "Failure red reaches 0.15 in 3.5 s")
	var dark: ColorRect = await effects.apagar_luzes(0.1)
	check(dark != null and absf(dark.color.a - 0.7) < 0.01, "Lights out without sound settle at 0.7")
	var view: Sprite2D = scene.get_node("RoomView")
	var origin: Vector2 = view.position
	effects.tremer(0.3, 3.0)
	await frames(6)
	check(view.position != origin, "Shake moves the room image")
	await frames(24)
	check(view.position == origin, "Shake returns to the original position")
	effects.cancel()
	await frames(1)
	var visible_layers := 0
	for child in effects.get_children():
		if child is CanvasItem and child.visible:
			visible_layers += 1
	check(visible_layers == 0, "Cancel removes every overlay")
	scene.queue_free()
	await frames(3)
	sections_done += 1

## Full Marta scene as the current scene, so reload/transition behave as in F6.
func _marta_scene(day: int, entrance: int = 0):
	Presenter.dia_em_andamento = null
	var scene = load(SCENE).instantiate()
	scene.test_day = day
	scene.initial_entrance = entrance
	root.add_child(scene)
	current_scene = scene
	return scene

## Presses Space every few frames until Marta's paper closes.
func _advance_marta(scene) -> bool:
	if not await until(func(): return scene.marta.paper.visible, "Marta speaks"):
		return false
	for i in 120:
		# A failure speech ends with a reload: a freed scene means the speech is over.
		if not is_instance_valid(scene) or not scene.marta.paper.visible:
			return true
		key(KEY_SPACE)
		await frames(10)
	check(false, "Marta's speech never closed")
	return false

## Answers the current visitor (correctly unless told otherwise) and waits for the result.
func _serve(scene, correct: bool = true) -> Dictionary:
	var desk = scene.desk
	if not await until(func(): return desk.badge.available and desk.confirm != null, "visitor ready"):
		return {}
	var entry: Dictionary = scene.visit_entry
	var code: int = Validator.andar_esperado(entry.visitor, entry.dialogue, scene.session.day_number, scene.session.active_rules)
	if not correct:
		code = 1 if code != 1 else 2
	desk.select_floor(code)
	desk.confirm_selection()
	await until(func(): return not desk.result.is_empty(), "decision result")
	return desk.result

func _intro_and_rules() -> void:
	seed(4700)
	var scene = _marta_scene(1)
	var day: DayScheduleConfig = load("res://src/gameplay/schedules/day1.tres")
	var announced: Array = []
	scene.rule_announced.connect(func(rule): announced.append(rule))
	await until(func(): return scene.marta.paper.visible, "intro speech")
	check(scene.session.state == Session.State.INTRO and scene.visit_id.is_empty(), "Intro before any visitor")
	check(not scene.desk.confirm.available and not scene.actor.visible, "No visitor nor panel during the intro")
	check(" ".join(scene.marta.paper.dialogue._pages) == day.mensagem_inicio, "Intro text is mensagem_inicio")
	await _advance_marta(scene)
	await until(func(): return scene.stage == Presenter.Stage.WAITING_FOR_DOOR, "first visitor after intro")
	check(not scene.marta.ground.visible and scene.session.state == Session.State.ARRIVING, "Marta gone into cabin 2, visitor arriving")
	var total: int = scene.session.queue_data.size() + 1
	for n in total:
		var entry: Dictionary = scene.visit_entry
		var result: Dictionary = await _serve(scene)
		check(result.get("correct", false), "Correct answer accepted (visit %d)" % n)
		if entry.get("caso_regra", false):
			check(not scene.session.active_rules.is_empty() and result.floor_code != entry.dialogue.andar_desejado, "Rule case decided with the rule active")
		if n == 0:
			await until(func(): return scene.desk.paper.visible or scene.stage == Presenter.Stage.MARTA, "after first")
		if n == 1:
			# Second release: Marta comes out of cabin 2 for the first rule.
			await until(func(): return scene.marta.paper.visible, "rule speech")
			check(scene.session.state == Session.State.RULE and scene.session.active_rules.is_empty(), "Rule not active while she speaks")
			# Review Focus 2: an open consultation keeps Space; the speech waits.
			scene.desk._open("book")
			for i in 3:
				key(KEY_SPACE)
				await frames(5)
			check(scene.marta.paper.visible and scene.session.active_rules.is_empty(), "Space goes to the open book, not to Marta")
			scene.desk.modal.close()
			# Review Focus 1: Space mashing activates the rule exactly once.
			await _advance_marta(scene)
			await until(func(): return scene.desk.modal.kind == "rules", "rules flash")
			check(announced.size() == 1 and scene.session.active_rules.size() == 1, "Rule activated once after the speech")
			var shown := 0
			while scene.desk.modal.kind == "rules" and shown < 200:
				shown += 1
				await process_frame
			check(shown > 90 and shown < 130, "Clipboard stays open about 1.8 s (%d frames)" % shown)
			await until(func(): return scene.desk.paper.visible, "visitor after rule")
			check(scene.desk.paper.dialogue._page == 0 and scene.desk.paper.dialogue._text_label.visible_ratio < 1.0, "No Space carried into the next visitor")
		if n == 3:
			await until(func(): return scene.marta.paper.visible, "second rule speech")
			await _advance_marta(scene)
		if n == total - 1:
			await until(func(): return scene.departed_count == total, "last release")
	await frames(60)
	check(announced.size() == 2, "Rules only after the 2nd and 4th service (%d)" % announced.size())
	# Review Focus 2, second half: the automatic flash never replaces an open consultation.
	scene.desk.modal.close()
	scene.desk._open("book")
	await scene.desk.flash_rules(0.2)
	check(scene.desk.modal.kind == "book", "Flash skipped while another modal is open")
	scene.desk.modal.close()
	current_scene = null
	scene.queue_free()
	await frames(3)
	sections_done += 1

## Waits for the scene that replaced `old_id` (reload or transition) to be ready.
func _next_scene(old_id: int, label: String):
	if not await until(func(): return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready(), label, 2400):
		return null
	return current_scene

func _drop_current() -> void:
	if current_scene:
		var scene = current_scene
		current_scene = null
		scene.queue_free()
	await frames(3)

func _red_overlay(scene) -> ColorRect:
	for child in scene.effects.get_children():
		if child is ColorRect and child.color.r > 0.6:
			return child
	return null

func _failure() -> void:
	# Day 2, wrong answer on the first visitor; no Space during her speech.
	seed(4800)
	var scene = _marta_scene(2)
	var day2: DayScheduleConfig = load("res://src/gameplay/schedules/day2.tres")
	var cabin1: Cabin = scene.get_node("RoomViewport/Room/Elevators/Elevator01")
	await _advance_marta(scene)
	var seen := {"exit": false, "cabin1": false}
	var watching := [true]
	var watcher := func():
		while watching[0] and is_instance_valid(scene) and scene.is_inside_tree():
			seen.exit = seen.exit or scene.stage == Presenter.Stage.TO_EXIT
			seen.cabin1 = seen.cabin1 or cabin1.state != Cabin.State.CLOSED
			await process_frame
	watcher.call()
	var result: Dictionary = await _serve(scene, false)
	check(not result.is_empty() and not result.correct, "Wrong answer registered")
	await until(func(): return scene.marta.paper.visible, "failure speech")
	check(seen.exit and not scene.actor.visible, "Visitor left through the entrance door")
	check(not seen.cabin1, "Cabin 1 never opens during the failure")
	check(scene.marta.sprite.source_texture == ANGER, "Angry Marta on day 2 too")
	check(" ".join(scene.marta.paper.dialogue._pages) == day2.mensagem_falha, "Failure text is mensagem_falha")
	var red := _red_overlay(scene)
	check(red != null and red.color.a > 0.0 and red.color.a <= 0.151, "Screen reddening toward 0.15")
	check(not scene.desk.confirm.available, "Panel locked during the failure")
	watching[0] = false
	var old_id: int = scene.get_instance_id()
	var waited := 0
	while current_scene and current_scene.get_instance_id() == old_id and waited < 600:
		waited += 1
		await process_frame
	check(waited >= 350 and waited <= 420, "Without Space the day restarts after ~6 s (%d frames)" % waited)
	var fresh = await _next_scene(old_id, "reload after failure")
	if fresh:
		check(fresh.session.day_number == 2 and fresh.session.served_count == 0 and fresh.session.active_rules.is_empty(), "Same day, fresh count and rules")
		check(fresh.session.state == Session.State.INTRO and fresh.stage == Presenter.Stage.MARTA, "Day restarts with the intro")
	await _drop_current()

	# Review Focus 3: wrong answer right after the first rule; Space ends her speech early.
	seed(4801)
	scene = _marta_scene(1)
	await _advance_marta(scene)
	await _serve(scene)
	await _serve(scene)
	await _advance_marta(scene) # first rule
	await until(func(): return not scene.session.active_rules.is_empty(), "rule active")
	result = await _serve(scene, false)
	check(not result.correct, "Wrong answer after the rule")
	await until(func(): return scene.marta.paper.visible, "failure speech after rule")
	old_id = scene.get_instance_id()
	await _advance_marta(scene)
	fresh = await _next_scene(old_id, "reload after Space")
	if fresh:
		check(fresh.session.day_number == 1 and fresh.session.active_rules.is_empty() and fresh.session.served_count == 0, "No rule or count survives the reload")
	await _drop_current()

	# Review Focus 4: reload in the middle of a rule speech.
	seed(4802)
	scene = _marta_scene(1)
	await _advance_marta(scene)
	await _serve(scene)
	await _serve(scene)
	await until(func(): return scene.marta.paper.visible, "rule speech before reload")
	old_id = scene.get_instance_id()
	reload_current_scene()
	fresh = await _next_scene(old_id, "manual reload")
	if fresh:
		var leaked := false
		for i in 30:
			leaked = leaked or fresh.marta.paper.visible or root.get_node("Dialogue").visible
			await process_frame
		check(not leaked, "No speech from the old scene after reload")
		check(fresh.get_node("RoomViewport/Room/Elevators/Elevator02").state == Cabin.State.CLOSED and fresh.session.active_rules.is_empty(), "Fresh scene: cabin 2 closed, no rules")
	await _drop_current()
	sections_done += 1

## Plays the current day to its end-of-day speech, answering correctly and advancing every Marta speech.
func _play_to_day_end(scene) -> bool:
	for n in 40:
		if scene.stage == Presenter.Stage.CONCLUDING:
			return true
		if scene.marta.paper.visible:
			await _advance_marta(scene)
		elif scene.desk.badge.available and scene.desk.result.is_empty():
			await _serve(scene)
		await frames(5)
		if not await until(func(): return scene.stage == Presenter.Stage.CONCLUDING or scene.marta.paper.visible \
				or (scene.desk.badge.available and scene.desk.result.is_empty()), "next step of the day"):
			return false
	return scene.stage == Presenter.Stage.CONCLUDING

func _conclusion() -> void:
	seed(4900)
	var scene = _marta_scene(1)
	var bloody: Texture2D = load("res://src/npcs/assets/marta/marta_bloody.png")
	var days := {
		1: load("res://src/gameplay/schedules/day1.tres"),
		2: load("res://src/gameplay/schedules/day2.tres"),
		3: load("res://src/gameplay/schedules/day3.tres"),
	}
	var both_open := [false]
	var watching := [true]
	var watcher := func():
		while watching[0]:
			var current = current_scene
			if current and current.has_node("RoomViewport/Room/Elevators/Elevator01"):
				var c1: Cabin = current.get_node("RoomViewport/Room/Elevators/Elevator01")
				var c2: Cabin = current.get_node("RoomViewport/Room/Elevators/Elevator02")
				both_open[0] = both_open[0] or (c1.state != Cabin.State.CLOSED and c2.state != Cabin.State.CLOSED)
			await process_frame
	watcher.call()
	for day in [1, 2, 3]:
		check(scene.session.day_number == day, "Playing day %d" % day)
		if not await _play_to_day_end(scene):
			break
		if day == 2:
			await until(func(): return scene.effects.get_child_count() > 0, "lights out")
			var dark_max := [0.0]
			while not scene.marta.ground.visible:
				for child in scene.effects.get_children():
					if child is ColorRect:
						dark_max[0] = maxf(dark_max[0], child.color.a)
				await process_frame
			check(dark_max[0] >= 0.9, "Room goes dark before Marta (%.2f)" % dark_max[0])
			check(scene.marta.sprite.source_texture == bloody, "Bloody Marta from the cabin on day 2")
		await until(func(): return scene.marta.paper.visible, "end of day speech")
		check(" ".join(scene.marta.paper.dialogue._pages) == days[day].mensagem_fim, "Day %d ends with mensagem_fim" % day)
		if day == 2:
			var reddish := false
			for child in scene.effects.get_children():
				reddish = reddish or (child is ColorRect and child.color.r > 0.0)
			check(reddish, "Red light while she speaks on day 2")
		var old_id: int = scene.get_instance_id()
		await _advance_marta(scene)
		var next = await _next_scene(old_id, "after day %d" % day)
		if next == null:
			break
		if day < 3:
			scene = next
			await until(func(): return not root.get_node("SceneTransition").is_busy(), "transition finished")
		else:
			check(next.scene_file_path == "res://src/ui/menus/scenes/end_screen.tscn", "Day 3 leads to the end screen")
			check(Presenter.dia_em_andamento == null, "Next F6 starts again from Test Day")
	watching[0] = false
	check(not both_open[0], "Marta and visitors never use both cabins at once")
	await _drop_current()
	sections_done += 1

func _run() -> void:
	Presenter = load("res://src/gameplay/reception_25d/scripts/reception_presentation.gd")
	MartaActor = load("res://src/gameplay/reception_25d/scripts/marta_actor.gd")
	check(MartaActor != null, "marta_actor.gd loads")
	if MartaActor == null:
		print("I5_MARTA_RESULT checks=%d failures=%d" % [checks, failures])
		quit(1)
		return
	await _actor_routes()
	await _effects()
	await _intro_and_rules()
	await _failure()
	await _conclusion()
	check(sections_done == 5, "Every section ran to the end (%d/5)" % sections_done)
	print("I5_MARTA_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
