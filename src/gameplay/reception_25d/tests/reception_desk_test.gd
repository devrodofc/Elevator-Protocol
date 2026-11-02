extends SceneTree
## Real I3 objects, physics, modal input and session decisions. No fixture rewrites.
const SCENE = "res://src/gameplay/reception_25d/scenes/reception_gameplay_test.tscn"
const Session = preload("res://src/gameplay/scripts/reception_session.gd")
const Validator = preload("res://src/shared/scripts/rule_validator.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(600).timeout.connect(func(): quit(1))
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(n: int) -> void:
	for i in n:
		await process_frame

func until(predicate: Callable) -> void:
	for i in 1800:
		if predicate.call():
			return
		await process_frame
	check(false, "Timed out waiting for real arrival")

func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)

func click(at: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)

func screen_point(scene: Node, point: Vector3) -> Vector2:
	var camera: Camera3D = scene.get_node("RoomViewport/Room/ReceptionCamera")
	return scene.get_node("RoomView").get_global_transform_with_canvas() * camera.unproject_position(point)

func _session_contract() -> void:
	var day: DayScheduleConfig = load("res://src/gameplay/schedules/day1.tres")
	for code in [1, 2, 3, 4, 5, 6, -1, 999]:
		var session := Session.new()
		root.add_child(session)
		session.start_service_preview(day)
		check(session.state == Session.State.READY and session.active_rules.is_empty(), "Service preview does not announce rules")
		check(not session.finish_intro(session.generation), "No fabricated narrative completion")
		var entry := session.request_next_visit(session.generation)
		var id := session.current_visit_id
		check(session.submit_decision(id, code).is_empty(), "No decision during arrival")
		check(session.service_reached(id), "Actual arrival required")
		check(session.submit_decision("old", code).is_empty(), "Old identity rejected")
		check(session.submit_decision(id, 0).is_empty(), "Invalid floor rejected")
		var result := session.submit_decision(id, code)
		check(result.correct == Validator.validar_decisao(entry.visitor, entry.dialogue, code, 1, []), "Original validator decides every code")
		check(session.submit_decision(id, code).is_empty(), "Duplicate decision rejected")
		check(not session.complete_visit(id) and session.served_count == 0 and session.current_entry == entry, "Preview never completes even a correct visit")
		check(session.request_next_visit(session.generation).is_empty(), "No second visit")
		session.start_day(day)
		check(session.state == Session.State.INTRO and session.finish_intro(session.generation), "2D start remains normal")
		var next := session.request_next_visit(session.generation)
		session.service_reached(session.current_visit_id)
		session.submit_decision(session.current_visit_id, Validator.andar_esperado(next.visitor, next.dialogue, 1, []))
		check(session.complete_visit(session.current_visit_id) and session.served_count == 1, "Normal session completion restored")
		session.queue_free()
	await process_frame

func _run() -> void:
	await _session_contract()
	for day in [1, 2, 3]:
		seed(4200 + day)
		var scene = load(SCENE).instantiate()
		scene.test_day = day
		scene.initial_entrance = day % 2
		root.add_child(scene)
		var desk = scene.get_node("DeskService")
		var entry: Dictionary = scene.session.current_entry
		check(not desk.badge.available and not desk.confirm.available, "No badge/panel input before arrival")
		check(desk.result.is_empty() and scene.session.active_rules.is_empty(), "Empty rules and no result at startup")
		await until(func(): return desk.transfer.delivering)
		check(not desk.badge.available and desk.badge.visible, "Badge cannot be clicked in flight")
		check(desk.paper.visible and not root.get_node("Dialogue").visible, "Only PAPER dialogue visible")
		check(desk.paper.dialogue._name_label.text == entry.nome, "Real visitor name")
		check(" ".join(desk.paper.dialogue._pages) == entry.dialogue.texto, "Real snapshot speech with original pagination")
		check(desk.paper.paper.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Paper remains readable independently of NPC yaw")
		await until(func(): return desk.badge.available)
		check(desk.badge.global_position.is_equal_approx(desk.transfer.target.global_position), "Badge rests on configured marker")
		check(not scene.movement.is_processing() and scene.actor.global_position.is_equal_approx(scene.service_point.global_position), "Visitor remains at counter")
		if day == 1:
			await _interaction_checks(scene, desk, entry)
		var snapshot_before: Dictionary = scene.session.current_entry
		var position_before: Vector3 = scene.actor.global_position
		var code: int = Validator.andar_esperado(entry.visitor, entry.dialogue, day, []) if day != 2 else 999
		desk.select_floor(code)
		check(desk.selected_floor == code and desk.confirm.available, "Select floor, not physical cabin")
		desk.confirm_selection()
		desk.confirm_selection()
		check(not desk.confirm.available, "Immediate confirmation lock")
		await frames(15)
		check(not desk.result.is_empty() and desk.result.floor_code == code, "Result available for I4")
		check(desk.result.correct == Validator.validar_decisao(entry.visitor, entry.dialogue, code, day, []), "Correct/incorrect outcome from shared validator")
		check(not desk.badge.available and not desk.paper.visible, "Confirmation closes speech and disables badge")
		await frames(80)
		check(not desk.badge.visible and not desk.transfer.collecting, "Badge collected exactly once")
		desk._open("badge")
		check(desk.modal.kind.is_empty(), "Collected badge cannot reopen")
		check(scene.session.served_count == 0 and scene.session.queue_data.size() == 6 and scene.session.current_entry == snapshot_before, "No count, clear, next visitor, or artificial completion")
		check(scene.actor.global_position == position_before and not scene.movement.is_processing(), "No physical departure after result")
		for elevator in scene.get_node("RoomViewport/Room/Elevators").get_children():
			check(elevator.state == 0, "No cabin opens after decision")
		check(scene.session.submit_decision(scene.visit_id, code).is_empty(), "Second decision rejected by authority")
		scene.queue_free()
		await frames(2)
	await _cancel_checks()
	print("I3_DESK_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _interaction_checks(scene, desk, entry: Dictionary) -> void:
	var picker = desk.picker
	var view: Sprite2D = scene.get_node("RoomView")
	var original_transform := view.transform
	var sample := Vector2(123, 81)
	view.position = Vector2(13, 27)
	view.scale = Vector2(0.7, 1.3)
	view.rotation = 0.12
	check(picker.viewport_position(view.get_global_transform_with_canvas() * sample).is_equal_approx(sample), "Mouse conversion handles translation, nonuniform scale and rotation")
	view.centered = true
	check(picker.viewport_position(view.get_global_transform_with_canvas() * (sample - Vector2(320, 180))).is_equal_approx(sample), "Centered RoomView conversion")
	view.centered = false
	view.transform = original_transform
	check(picker.viewport_position(Vector2(-100, -100)) == Vector2(-1, -1), "Outside texture rejected")
	view.region_enabled = true
	view.region_rect = Rect2(40, 20, 300, 180)
	check(picker.viewport_position(view.get_global_transform_with_canvas() * Vector2(150, 90)).is_equal_approx(Vector2(190, 110)), "Region crop maps back into SubViewport")
	view.region_enabled = false
	var window_size := root.size
	for dimensions in [Vector2i(640, 360), Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = dimensions
		await frames(2)
		check(picker.pick(screen_point(scene, desk.book.global_position)) == desk.book, "Picking survives window resize")
	root.size = window_size
	await frames(2)
	for yaw in [-0.3, 0.0, 0.3]:
		picker.camera.rotation.y = yaw
		check(picker.pick(screen_point(scene, desk.badge.global_position)) == desk.badge, "Picking follows horizontal camera yaw")
	picker.camera.rotation.y = 0
	for code in desk.buttons:
		check(picker.pick(screen_point(scene, desk.buttons[code].global_position)) == desk.buttons[code], "Independent ray region for every floor")
	check(picker.pick(screen_point(scene, desk.confirm.global_position)) == null, "Disabled OK cannot be clicked")
	var back = desk.book.duplicate()
	back.position.z -= 0.2
	desk.book.get_parent().add_child(back)
	await physics_frame
	check(picker.pick(screen_point(scene, desk.book.global_position)) == desk.book, "Closest overlapping body owns the click")
	back.queue_free()
	await frames(2)
	# Disable automatic hover for deterministic material/Tween observations; pick remains real physics.
	picker.set_physics_process(false)
	await physics_frame
	for item in [desk.badge, desk.book, desk.clipboard]:
		var point := screen_point(scene, item.global_position)
		check(picker.pick(point) == item, "Real ray hits nearest desk object")
		item.set_hover(true)
		await frames(20)
		var initial: float = item.glow
		await frames(35)
		check(item.glow != initial and item.glow > 0, "Continuous gentle pulse")
		check(item._materials[0] != item._originals[0], "Material isolated per object")
		check(item._materials[0].emission_enabled, "Hover brightens without bloom")
		item.set_hover(false)
		await frames(20)
		check(item._materials[0].albedo_color == item._originals[0].albedo_color and item.glow == 0, "Exact base material restoration")
	check(desk.clipboard.visual_root.position.is_equal_approx(Vector3.ZERO), "Clipboard returns to rest")
	for i in 5:
		desk.clipboard.set_hover(true)
		await frames(3)
		desk.clipboard.set_hover(false)
		await frames(2)
	await frames(20)
	check(desk.clipboard.visual_root.position.is_equal_approx(Vector3.ZERO), "Interrupted slides do not accumulate")
	desk.clipboard.set_hover(true)
	await frames(25)
	check(desk.clipboard.visual_root.position.is_equal_approx(desk.clipboard.slide_offset), "Clipboard slides in local desk coordinates")
	desk.clipboard.set_hover(false)
	picker.set_physics_process(true)
	# Actual mouse input -> physics query -> modal.
	click(screen_point(scene, desk.badge.global_position))
	await frames(4)
	check(desk.modal.kind == "badge" and picker.blocked, "Raycast click opens one blocking modal")
	check(desk.modal.get_viewport() == root and desk.modal.badge._photo.texture == entry.sprite, "Badge main viewport and matching physical sprite")
	check(desk.modal.badge._name.text == entry.nome and desk.modal.badge._age.text == str(entry.cracha.idade), "Frozen badge data")
	check(desk.modal.badge._sex.text == entry.cracha.sexo and desk.modal.badge._occupation.text == entry.cracha.ocupacao, "Real sex and occupation")
	check(desk.modal.badge.get_node("Card/CardBackground").texture.resource_path.ends_with("cracha_ab_semnada.png"), "Exact original badge art")
	var camera: Camera3D = picker.camera
	var camera_before := camera.transform
	key(KEY_F)
	key(KEY_P)
	key(KEY_SPACE)
	key(KEY_ENTER)
	await frames(10)
	check(camera.transform == camera_before and camera.process_mode == Node.PROCESS_MODE_DISABLED, "Modal suspends edge rotation, free camera and shortcuts")
	check(not paused, "P does not open global cheat behind modal")
	check(picker.pick(screen_point(scene, desk.book.global_position)) == null, "Modal blocks all 3D picks")
	desk.select_floor(1)
	check(desk.selected_floor == 0, "No panel selection during inspection")
	click(Vector2(4, 4))
	await frames(4)
	check(desk.modal.kind.is_empty() and not picker.blocked and camera.process_mode != Node.PROCESS_MODE_DISABLED, "Outside click closes without passing through and restores camera")
	desk._open("badge")
	check(desk.modal.badge._name.text == entry.nome and scene.session.current_entry == entry, "Reopening never rerolls snapshot")
	key(KEY_ESCAPE)
	check(desk.modal.kind.is_empty(), "Escape closes inspection")
	desk._open("book")
	var directory: CompanyDirectory = desk.modal.book.directory
	for i in desk.modal.book.page_count():
		for column in desk.modal.book._columns:
			check(column.get_node("Description").text.is_empty() and not column.get_node("Description").visible, "2.5D never exposes detailed descriptions")
		desk.modal.book.next_page()
	check(desk.modal.book._page == 0 and not directory.empresas[0].descricao.is_empty(), "Original cyclic pages and unmodified directory")
	desk.modal.close()
	desk._open("rules")
	check(desk.modal.rules._rules.is_empty() and desk.modal.rules.get_node("RulesText").text == "Nenhuma regra extra.", "No fictitious Marta rules")
	desk.modal.close()
	key(KEY_F)
	check(scene.get_node("DebugFreeCamera").active, "Free exploration still available outside modal")
	desk._open("book")
	check(scene.get_node("DebugFreeCamera").process_mode == Node.PROCESS_MODE_DISABLED, "Active free camera temporarily suspended")
	desk.modal.close()
	check(scene.get_node("DebugFreeCamera").active, "Free-camera mode preserved after reading")
	key(KEY_F)
	check(not scene.get_node("DebugFreeCamera").active, "F returns to normal camera")
	var speech = desk.paper.dialogue
	var original_rate: float = speech.chars_per_second
	speech.chars_per_second = 0
	speech.display_dialogue(entry.nome, (entry.dialogue.texto + " ").repeat(8).strip_edges())
	check(speech._pages.size() > 1, "Long dialogue retains original pagination")
	key(KEY_SPACE)
	check(speech._page == 1, "Space advances the original PAPER dialogue page")
	desk._open("book")
	key(KEY_ENTER)
	check(speech._page == 1, "Modal prevents Enter advancing speech behind it")
	desk.modal.close()
	key(KEY_ENTER)
	check(speech._page == 2, "Enter also preserves original advance control")
	speech.chars_per_second = original_rate
	speech.display_dialogue(entry.nome, entry.dialogue.texto)
	# Original selection semantics: selecting twice deselects, OK requires a selection.
	for code in [1, 2, 3, 4, 5, 6, -1, 999]:
		desk.select_floor(code)
		check(desk.selected_floor == code and desk.confirm.available, "Every original code selectable")
		desk.select_floor(code)
		check(desk.selected_floor == 0 and not desk.confirm.available, "Same code toggles selection off")

func _cancel_checks() -> void:
	var scene = load(SCENE).instantiate()
	root.add_child(scene)
	var desk = scene.get_node("DeskService")
	await until(func(): return desk.badge.available)
	desk.select_floor(1)
	desk.confirm_selection()
	scene.cancel_preview()
	await frames(20)
	check(desk.result.is_empty() and not desk.badge.visible, "Cancellation invalidates pending confirmation and badge Tween")
	check(not desk.paper.visible and desk.modal.kind.is_empty(), "Cancellation cleans dialogue and modals")
	scene.queue_free()
	await frames(3)

	var replacement = load(SCENE).instantiate()
	root.add_child(replacement)
	var next_desk = replacement.get_node("DeskService")
	await until(func(): return next_desk.badge.available)
	next_desk._open("badge")
	var old_camera: WeakRef = weakref(next_desk.picker.camera)
	replacement.queue_free()
	await frames(3)
	check(old_camera.get_ref() == null and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Scene exit during modal frees old objects and restores mouse")
	var global_dialogue = root.get_node("Dialogue")
	global_dialogue.display_dialogue("Teste 2D", "Fala original")
	check(global_dialogue.is_open(), "Global 2D Dialogue still works after PAPER cleanup")
	global_dialogue.clear_dialogue()
