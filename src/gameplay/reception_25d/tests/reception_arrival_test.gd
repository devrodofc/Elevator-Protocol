extends SceneTree
## I2: portas, percurso e orientação reais; chamadas inválidas são testes negativos.

const INTEGRATED := "res://src/gameplay/reception_25d/tests/reception_arrival_fixture.tscn"
const ORIGINAL := "res://src/gameplay/reception_25d/scenes/reception.tscn"
const Session := preload("res://src/gameplay/scripts/reception_session.gd")
const SpriteScript := preload("res://src/gameplay/reception_25d/scripts/test_sprite.gd")
const Door := preload("res://src/gameplay/reception_25d/scripts/automatic_door.gd")

var checks: int = 0
var failures: int = 0
var real_arrivals: int = 0
var Presenter: GDScript


func _initialize() -> void:
	create_timer(600.0).timeout.connect(func():
		push_error("I2 watchdog: no completed result")
		quit(1)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _wait_until(predicate: Callable, message: String, max_frames: int = 2400) -> bool:
	for frame in max_frames:
		if predicate.call():
			return true
		await process_frame
	_check(false, "Timeout: " + message)
	return false


func _frames(count: int) -> void:
	for frame in count:
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)


func _foot_at_anchor(sprite: Sprite3D, anchor: Node3D) -> bool:
	var image := sprite.texture.get_image()
	var bottom: float = (image.get_height() * 0.5 - image.get_used_rect().end.y) * sprite.pixel_size
	return is_equal_approx(sprite.to_global(Vector3(0, bottom, 0)).y, anchor.global_position.y)


func _sprite_cases() -> void:
	var anchor := Node3D.new()
	root.add_child(anchor)
	anchor.position.y = 0.84453654
	var sprite := SpriteScript.new()
	anchor.add_child(sprite)
	var sources: Array[Texture2D] = []
	for resource_path in ["res://src/npcs/resources/Day1/common_npc_male1.tres",
			"res://src/npcs/resources/Day1/common_npc_female1.tres", "res://src/npcs/resources/Day3/tiao.tres"]:
		var data: VisitorData = load(resource_path)
		sources.append_array(data.sprites)
	sources.append(load("res://src/npcs/assets/npc_male_1/npc_male_1_frame_1.png"))
	var distinct_bottoms: Dictionary = {}
	for source in sources:
		var original_hash: String = source.get_image().get_data().hex_encode().sha256_text()
		_check(sprite.apply_visit_texture(source), "Real visitor texture applies")
		_check(sprite.source_texture == source and sprite.texture != source and sprite.texture is ImageTexture, "Separate runtime texture retains source identity")
		_check(sprite.texture.get_image().get_data() == source.get_image().get_data(), "Pixels including transparency preserved")
		_check(_foot_at_anchor(sprite, anchor), "Visible feet align with actual global floor")
		_check(source.get_image().get_data().hex_encode().sha256_text() == original_hash, "Source image remains unchanged")
		distinct_bottoms[source.get_image().get_used_rect().end.y] = true
	_check(is_equal_approx(sprite.position.y, 1.04), "Original experimental sprite retains validated 1.04m alignment")
	# Diferentes dimensões, margens inferiores e escalas; imagens existem só em memória.
	for spec in [Vector3i(17, 41, 31), Vector3i(64, 128, 120), Vector3i(32, 20, 9)]:
		var image := Image.create_empty(spec.x, spec.y, false, Image.FORMAT_RGBA8)
		image.fill_rect(Rect2i(1, 2, spec.x - 2, spec.z - 2), Color.WHITE)
		sprite.scale = Vector3(1.2, 1.6, 1.0)
		sprite.position.y = 99.0
		_check(sprite.apply_visit_texture(ImageTexture.create_from_image(image)), "Different image dimensions apply dynamically")
		_check(_foot_at_anchor(sprite, anchor), "Replacement recomputes transparent foot margin with scale")
		_check(sprite.scale == Vector3(1.2, 1.6, 1.0), "Appearance does not overwrite visual scale")
		distinct_bottoms[spec.z] = true
	_check(distinct_bottoms.size() >= 3, "Foot cases cover different visible bottoms")
	var empty := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	_check(not sprite.apply_visit_texture(ImageTexture.create_from_image(empty)) and sprite.texture == null, "Fully transparent image clears old appearance safely")
	_check(not sprite.apply_visit_texture(null) and sprite.source_texture == null, "Missing texture never reuses previous visitor")
	anchor.free()


func _preview_contract() -> void:
	var day: DayScheduleConfig = load("res://src/gameplay/schedules/day1.tres")
	var session := Session.new()
	root.add_child(session)
	seed(4201)
	var original: Dictionary = day.montar_dia()
	var rng_after: int = randi()
	seed(4201)
	session.start_arrival_preview(day)
	_check(randi() == rng_after, "Preview generates the agenda exactly once")
	_check(session.is_arrival_preview and session.state == Session.State.READY, "Explicit preview starts ready without a narrative intro")
	_check(not session.finish_intro(session.generation), "Preview cannot report a fictional intro completion")
	var entry: Dictionary = session.request_next_visit(session.generation)
	_check(entry == original.fila[0] and session.queue_data.size() == 6, "Preview selects the actual first FIFO visit")
	_check(session.service_reached(session.current_visit_id), "Preview still uses shared arrival contract")
	for code in [1, 2, 3, 4, 5, 6, -1, 999]:
		_check(session.submit_decision(session.current_visit_id, code).is_empty(), "Preview blocks every decision code")
	_check(not session.complete_visit(session.current_visit_id) and not session.finish_interval(session.current_visit_id), "Preview cannot count or advance service")
	_check(session.take_due_rule(session.current_visit_id) == null and session.active_rules.is_empty(), "Preview never announces/activates rules")
	_check(session.request_next_visit(session.generation).is_empty() and session.served_count == 0, "Exactly one preview visit")
	var old_id: String = session.current_visit_id
	session.start_day(day)
	_check(not session.is_arrival_preview and session.state == Session.State.INTRO, "Normal gameplay initialization clears preview mode")
	_check(not session.service_reached(old_id) and session.finish_intro(session.generation), "Old preview cannot interfere with a real day")
	entry = session.request_next_visit(session.generation)
	session.service_reached(session.current_visit_id)
	var correct: int = RuleValidator.andar_esperado(entry.visitor, entry.dialogue, 1)
	_check(session.submit_decision(session.current_visit_id, correct).get("correct", false), "Real day decisions remain enabled")
	session.free()


func _arrival(number: int, side: int) -> void:
	var day: DayScheduleConfig = load("res://src/gameplay/schedules/day%d.tres" % number)
	seed(4200 + number)
	var expected: Dictionary = day.montar_dia()
	var rng_after: int = randi()
	seed(4200 + number)
	var scene = load(INTEGRATED).instantiate()
	scene.test_day = number
	scene.initial_entrance = side
	root.add_child(scene)
	var notifications: Array[String] = []
	scene.visit_reached_service.connect(func(id: String): notifications.append(id))
	var session: Node = scene.session
	var actor: Node3D = scene.actor
	var visual: Sprite3D = scene.visual
	var movement: Node = scene.movement
	var orientation: Node = scene.orientation
	var visit_id: String = session.current_visit_id
	var camera: Camera3D = orientation.camera
	var initial_camera: Transform3D = camera.transform
	var shadow: Node3D = actor.get_node("ContactShadow")
	var initial_shadow: Transform3D = shadow.transform
	var callback: Callable = scene._arrival_callback
	var door: Node3D = scene._door
	var other: Node3D = scene.get_node("RoomViewport/Room/Entrances/" + ("EntranceRight" if side == 0 else "EntranceLeft"))
	_check(randi() == rng_after, "Scene consumes no extra gameplay RNG")
	_check(session.get_parent() == scene and session.day_number == number and session.is_arrival_preview, "Integrated scene owns configured local session")
	_check(scene.stage == Presenter.Stage.WAITING_FOR_DOOR and session.state == Session.State.ARRIVING, "Physical opening is distinct from logical arrival")
	_check(scene.visit_entry == expected.fila[0] and scene.visit_entry == session.current_entry, "Adapter retains exact original snapshot")
	_check(actor.get_meta("visit_id") == visit_id and not visit_id.is_empty(), "Actor carries session occurrence identity")
	_check(scene.visit_entry.nome == expected.fila[0].nome and scene.visit_entry.cracha == expected.fila[0].cracha
		and scene.visit_entry.dialogue == expected.fila[0].dialogue and scene.visit_entry.visitor == expected.fila[0].visitor, "Name, badge, dialogue and data references preserved")
	_check(visual.source_texture == expected.fila[0].sprite and visual.texture is ImageTexture, "Sprite3D uses the scheduled texture")
	_check(visual.texture.get_image().get_data() == expected.fila[0].sprite.get_image().get_data(), "Scene's visible pixels match the snapshot")
	_check(visual.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and visual.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "Nearest and transparency settings preserved")
	_check(orientation.orientation_mode == 1 and visual.billboard == BaseMaterial3D.BILLBOARD_DISABLED, "PAPER remains the initial orientation")
	_check(movement.movement_speed == 3.0 and actor.global_position.is_equal_approx(door.spawn_point.global_position), "Actor starts at selected spawn with speed 3")
	_check(actor.visible and not movement.is_processing() and door.state == Door.State.OPENING, "Visitor waits at spawn while door opens")
	_check(_foot_at_anchor(visual, actor) and shadow.transform == initial_shadow, "Initial floor contact and shadow preserved")
	_check(not scene.get_node("VisitorMovementTest").enabled and not scene.get_node("ElevatorSelection").enabled, "Legacy owners disabled only in inherited scene")
	var original_position := actor.global_position
	for key in [KEY_1, KEY_2, KEY_R]:
		_key(key)
	_check(actor.global_position == original_position and scene.stage == Presenter.Stage.WAITING_FOR_DOOR, "1/2/R cannot reset or replace session visitor")
	callback.call() # Negative: completion callback before door/movement finish.
	_check(session.state == Session.State.ARRIVING and notifications.is_empty(), "Early callback never reports a visit at service")
	var seen_states: Dictionary = {door.state: true}
	var previous: Vector3 = actor.global_position
	var previous_yaw: float = visual.global_rotation.y
	var bounded_speed: bool = true
	var bounded_rotation: bool = true
	var saw_rotation: bool = false
	var stayed_grounded: bool = true
	var route_checked: bool = false
	var free_camera_checked: bool = false
	var walked: float = 0.0
	for frame in 900:
		if scene.stage == Presenter.Stage.AT_SERVICE:
			break
		await process_frame
		seen_states[door.state] = true
		var distance: float = actor.global_position.distance_to(previous)
		walked += distance
		bounded_speed = bounded_speed and distance <= 3.0 / 60.0 + 0.0001
		var turn: float = absf(angle_difference(previous_yaw, visual.global_rotation.y))
		bounded_rotation = bounded_rotation and turn <= deg_to_rad(orientation.rotation_speed) / 60.0 + 0.0001
		saw_rotation = saw_rotation or turn > 0.001
		stayed_grounded = stayed_grounded and _foot_at_anchor(visual, actor) and is_equal_approx(actor.global_position.y, scene.service_point.global_position.y)
		previous = actor.global_position
		previous_yaw = visual.global_rotation.y
		if scene.stage == Presenter.Stage.WALKING and not route_checked:
			route_checked = true
			var join: Marker3D = scene.get_node("RoomViewport/Room/VisitorPositions/QueueJoinPoint")
			_check(movement._path == [scene._entrance.global_position, join.global_position, scene.service_point.global_position], "Original entrance/join/service route reused")
			callback.call()
			_check(session.state == Session.State.ARRIVING and notifications.is_empty(), "Mid-route callback cannot pretend service reached")
			_key(KEY_F)
			_check(scene.get_node("DebugFreeCamera").active, "Free camera available during real visitor route")
			_key(KEY_F)
			free_camera_checked = camera.transform == initial_camera
	_check(scene.stage == Presenter.Stage.AT_SERVICE and session.state == Session.State.SERVING, "Real movement reaches shared service state")
	_check(actor.global_position.is_equal_approx(scene.service_point.global_position) and not movement.is_processing(), "Visitor stops exactly at ServicePoint")
	_check(notifications == [visit_id], "Exactly one notification contains the real visit identity")
	_check(bounded_speed and walked > 10.0 and route_checked, "Entire route walked at original speed without teleport")
	_check(bounded_rotation and saw_rotation, "PAPER rotates smoothly along the actual route")
	_check(stayed_grounded and shadow.transform == initial_shadow, "Feet and shadow stay at floor throughout movement")
	_check(free_camera_checked and camera.position == initial_camera.origin, "Debug camera restore does not change session or camera position")
	for key in [KEY_1, KEY_2, KEY_R]:
		_key(key)
	var selection: Node = scene.get_node("ElevatorSelection")
	for index in 3:
		var button: Button = scene.get_node("ElevatorUI/Selection/Elevator%d" % (index + 1))
		_check(button.disabled and button.pressed.get_connections().is_empty(), "Cabin button is disabled and disconnected")
		button.pressed.emit()
		selection.select_elevator(index)
	callback.call()
	scene._on_arrived(scene._run - 1, session.generation, visit_id)
	scene._on_arrived(scene._run, session.generation - 1, visit_id)
	scene._on_arrived(scene._run, session.generation, "previous-visit")
	_check(notifications == [visit_id] and not session.service_reached(visit_id), "Duplicate/stale generation/visit arrivals rejected")
	await _frames(150)
	seen_states[door.state] = true
	var facing: Vector3 = camera.global_position - actor.global_position
	_check(absf(angle_difference(visual.global_rotation.y, atan2(facing.x, facing.z))) < 0.001, "Visitor faces receptionist after stopping")
	_check(actor.global_position.is_equal_approx(scene.service_point.global_position) and not movement.is_processing(), "No automatic departure after waiting")
	_check(session.current_visit_id == visit_id and session.current_entry == expected.fila[0]
		and session.queue_data.size() == 6 and session.served_count == 0, "Arrival never counts, resamples or advances queue")
	_check(session.active_rules.is_empty() and session.pending_rule == null and session.next_rule_index == 0, "Selected rules stay inactive without fictional announcements")
	_check(session.submit_decision(visit_id, 1).is_empty() and session.state == Session.State.SERVING, "No decision accepted in I2 scene")
	_check(not selection.can_select and selection.selected_elevator == -1 and selection.stage == 0, "Experimental dispatch never owns arrival")
	for index in 3:
		_check(scene.get_node("RoomViewport/Room/Elevators/Elevator%02d" % (index + 1)).state == 0, "Cabin remains closed")
	_check(seen_states.has(Door.State.OPENING) and seen_states.has(Door.State.OPEN)
		and seen_states.has(Door.State.CLOSING) and door.state == Door.State.CLOSED and other.state == Door.State.CLOSED, "Selected entrance opens and closes; other entrance stays closed")
	_check(scene.visit_entry == expected.fila[0] and scene.visit_entry.is_read_only(), "Immutable snapshot survives full arrival")
	real_arrivals += notifications.size()
	print("I2_ARRIVAL day=%d entrance=%d sprite=%s" % [number, side, visual.source_texture.resource_path])
	scene.queue_free()
	await _frames(2)


func _reload_during(walking: bool) -> void:
	change_scene_to_file(INTEGRATED)
	if not await _wait_until(func(): return current_scene != null, "Preview scene ready for reload"):
		return
	var old = current_scene
	if walking and not await _wait_until(func(): return old.stage == Presenter.Stage.WALKING, "Walking before reload"):
		return
	var old_id: String = old.visit_id
	var old_generation: int = old.session.generation
	var old_run: int = old._run
	var old_instance: int = old.get_instance_id()
	var old_ref: WeakRef = weakref(old)
	var old_session: Node = old.session
	reload_current_scene()
	_check(old_session.state == Session.State.CLOSED and old.stage == Presenter.Stage.CANCELLED, "Scene removal cancels preview during door/route")
	if not await _wait_until(func(): return current_scene != null and current_scene.get_instance_id() != old_instance, "Actual preview scene reload"):
		return
	_check(old_ref.get_ref() == null, "Previous scene was actually freed")
	var scene = current_scene
	var notifications: Array[String] = []
	scene.visit_reached_service.connect(func(id: String): notifications.append(id))
	_check(scene.visit_id != old_id and scene.session.served_count == 0, "Reload assigns distinct occurrence without old count")
	scene._on_arrived(old_run, old_generation, old_id)
	_check(scene.session.state == Session.State.ARRIVING and notifications.is_empty(), "Previous run event cannot arrive in reloaded session")
	if await _wait_until(func(): return scene.stage == Presenter.Stage.AT_SERVICE, "Reloaded real route"):
		_check(notifications == [scene.visit_id] and scene.session.queue_data.size() == 6, "Reloaded arrival completes once and stops")
	current_scene = null
	scene.queue_free()
	await _frames(2)


func _cancel_and_unsupported() -> void:
	var scene = load(INTEGRATED).instantiate()
	root.add_child(scene)
	if not await _wait_until(func(): return scene.stage == Presenter.Stage.WALKING, "Route before foreign reset"):
		return
	var callback: Callable = scene._arrival_callback
	var entry: Dictionary = scene.session.current_entry
	scene.movement.reset_at(scene._door.spawn_point)
	callback.call()
	_check(scene.stage == Presenter.Stage.CANCELLED and scene.session.state == Session.State.CLOSED
		and not scene.movement.is_processing() and not scene.actor.visible, "Foreign reset cancels route instead of creating arrival")
	var foreign_route: Array[Marker3D] = [scene.service_point]
	scene.movement.start_from(scene._door.spawn_point, foreign_route)
	_check(not scene.movement.is_processing() and scene.stage == Presenter.Stage.CANCELLED, "Foreign start_from cannot restart movement after cancellation")
	_check(scene.session.current_entry == entry and scene.session.queue_data.size() == 6 and scene.session.served_count == 0, "Cancelled callback preserves snapshot without advancing")
	scene.free()
	# Formato legado realmente existente: AnimatedSprite2D em uma cena própria.
	for missing_texture in [false, true]:
		scene = load(INTEGRATED).instantiate()
		root.add_child(scene)
		entry = scene.session.current_entry
		var bad_entry: Dictionary = entry.duplicate(true)
		if missing_texture:
			bad_entry.sprite = null
		else:
			bad_entry.visitor = load("res://src/npcs/resources/visitors/common_npc_male1.tres")
		_check(not scene._apply_appearance(bad_entry), "Unsupported visual format fails explicitly")
		_check(scene.stage == Presenter.Stage.UNSUPPORTED and not scene.presentation_error.is_empty()
			and scene.session.state == Session.State.CLOSED and not scene.actor.visible and scene.visual.texture == null, "Unsupported format hides placeholder and cancels safely")
		_check(scene.session.current_entry == entry and scene.session.queue_data.size() == 6
			and scene.session.served_count == 0, "Unsupported format never silently skips the visit")
		scene.free()


func _transition_during_route() -> void:
	change_scene_to_file(INTEGRATED)
	if not await _wait_until(func(): return current_scene != null, "Preview before external fade"):
		return
	var scene = current_scene
	if not await _wait_until(func(): return scene.stage == Presenter.Stage.WALKING, "Route before fade"):
		return
	var session: Node = scene.session
	var callback: Callable = scene._arrival_callback
	var notifications: Array[String] = []
	scene.visit_reached_service.connect(func(id: String): notifications.append(id))
	var old_instance: int = scene.get_instance_id()
	var transition: Node = root.get_node("SceneTransition")
	transition.transition_to(ORIGINAL)
	callback.call()
	_check(scene.stage == Presenter.Stage.CANCELLED and session.state == Session.State.CLOSED,
		"External fade invalidates arrival before next presentation process")
	_check(not scene.actor.visible and not scene.movement.is_processing() and notifications.is_empty()
		and session.served_count == 0, "Callback during transition cannot move, arrive or count")
	if await _wait_until(func(): return current_scene != null and current_scene.get_instance_id() != old_instance, "External fade changes scene"):
		_check(current_scene.scene_file_path == ORIGINAL and current_scene.get_node_or_null("ReceptionSession") == null,
			"External transition preserves original scene destination")
	await _wait_until(func(): return not transition.is_busy(), "External fade finishes")
	var original: Node = current_scene
	current_scene = null
	original.queue_free()
	await _frames(2)


func _original_routes() -> void:
	var scene = load(ORIGINAL).instantiate()
	root.add_child(scene)
	var harness: Node = scene.get_node("VisitorMovementTest")
	var selection: Node = scene.get_node("ElevatorSelection")
	var orientation: Node = scene.get_node("VisitorOrientation")
	_check(harness.enabled and selection.enabled and scene.get_node_or_null("ReceptionSession") == null, "Original experiment retains its independent controls")
	_key(KEY_P)
	_check(orientation.orientation_mode == 0 and not paused, "Original P comparison still consumes shortcut")
	_key(KEY_P)
	_check(orientation.orientation_mode == 1, "Original returns to PAPER")
	for side in 2:
		for index in 3:
			_key(KEY_1 if side == 0 else KEY_2)
			_check(harness._waiting_for_open, "Original 1/2 still starts entry")
			if not await _wait_until(func(): return selection.can_select, "Original service for cabin"):
				break
			var button: Button = scene.get_node("ElevatorUI/Selection/Elevator%d" % (index + 1))
			_check(not button.disabled, "Original cabin button remains connected and available")
			button.pressed.emit()
			var door: Node = scene.get_node("RoomViewport/Room/Elevators/Elevator%02d" % (index + 1))
			if await _wait_until(func(): return selection.stage == 6 and door.state == 0, "Original cabin boarding"):
				_check(selection.selected_elevator == index, "Original selected cabin boards and closes naturally")
			_key(KEY_R)
			_check(selection.stage == 0 and not harness.movement.is_processing() and not harness.movement.visitor.visible, "Original R still resets route, actor and cabin selection")
	scene.queue_free()
	await _frames(2)


func _run() -> void:
	# Load presentation after Autoloads, following CLAUDE.md section 12.
	Presenter = load("res://src/gameplay/reception_25d/scripts/reception_presentation.gd")
	_check(Presenter.can_instantiate(), "Presentation compiles after autoload initialization")
	if not Presenter.can_instantiate():
		quit(1)
		return
	var version := Engine.get_version_info()
	_check(version.major == 4 and version.minor == 7 and version.patch == 2, "Pinned Godot version")
	_sprite_cases()
	_preview_contract()
	for number in range(1, 4):
		for side in 2:
			await _arrival(number, side)
	await _reload_during(false)
	await _reload_during(true)
	await _cancel_and_unsupported()
	await _transition_during_route()
	await _original_routes()
	for type in ["AudioStreamPlayer", "AudioStreamPlayer2D"]:
		for player in root.find_children("*", type, true, false):
			player.stop()
	await _frames(3)
	OS.delay_msec(50)
	print("I2_ARRIVAL_RESULT checks=%d failures=%d real_arrivals=%d" % [checks, failures, real_arrivals])
	quit(1 if failures else 0)
