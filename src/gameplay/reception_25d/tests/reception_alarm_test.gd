extends SceneTree
## Focused alarm tests: real movement completion, original action, hold/return and scene teardown.

const SCENE = "res://src/gameplay/reception_25d/scenes/reception_3d.tscn"
const TEXTURE = preload("res://src/npcs/assets/npc_male_1/npc_male_1_frame_1.png")
var checks: int = 0
var failures: int = 0
var activations: int = 0


func _initialize() -> void:
	create_timer(60.0).timeout.connect(
		func():
			push_error("Alarm test timed out")
			quit(1)
	)
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for i in count:
		await process_frame


func settled(movement: Node) -> void:
	for i in 600:
		if not movement.is_processing():
			return
		await process_frame
	check(false, "Movement did not confirm arrival")


func isolated_game(hold: float = 5.0):
	var scene = load(SCENE).instantiate()
	scene.alarm_hold_seconds = hold
	root.add_child(scene)
	# Cancel pending intro by generation, retaining the real actors and movement components.
	scene.session.close()
	scene.set_process(false)
	scene.director.set_process(false)
	scene.story.set_process(false)
	scene.marta.cancel()
	scene.story.godofredo.cancel()
	scene.watch.cancel()
	scene.movement.set_process(false)
	scene.stage = scene.Stage.AT_SERVICE
	return scene


func follow(actor: Node, points: Array) -> void:
	var route: Array[Marker3D] = []
	for point in points:
		route.append(point)
	actor._follow(route)


func _activated() -> void:
	activations += 1


func boarding(scene: Node) -> void:
	var devices = scene.devices
	var alarm = devices.alarm
	devices.alarm_clicked.connect(_activated)
	await frames(2)
	check(is_equal_approx(devices.alarm_hold_seconds, 5.0), "Default hold is five seconds")
	var exported := false
	for property in scene.get_property_list():
		if property.name == "alarm_hold_seconds":
			exported = bool(property.usage & PROPERTY_USAGE_EDITOR)
	check(exported, "Hold duration is configurable in the scene Inspector")
	check(not scene._has_elevator_occupant() and not alarm.available, "No occupants blocks alarm")
	alarm.activate()
	alarm.activated.emit()
	check(activations == 0, "Unavailable alarm ignores clicks and direct activation signals")

	scene.actor.global_position = scene.cabin.get_node("ApproachPoint").global_position
	scene.stage = scene.Stage.TO_CABIN
	await frames(2)
	check(not alarm.available, "Walking toward the cabin does not count")
	scene.stage = scene.Stage.WAITING_FOR_CABIN
	await frames(2)
	check(not alarm.available, "Waiting for doors does not count")
	scene.stage = scene.Stage.ENTERING_CABIN
	follow(scene, [scene.cabin.entry_point, scene.cabin.cabin_stop_point])
	await frames(2)
	check(
		scene.movement.is_processing() and not alarm.available,
		"Crossing the entrance does not count"
	)
	await settled(scene.movement)
	await frames(2)
	check(
		scene._route_finished(scene.cabin.cabin_stop_point), "Real I4 movement confirms cabin stop"
	)
	check(alarm.available, "Confirmed cabin arrival enables alarm")


func cooldown(scene: Node) -> void:
	var devices = scene.devices
	var alarm = devices.alarm
	var warnings_before: int = scene.story.warnings
	alarm.activate()
	var motion: Tween = devices._alarm_motion
	check(activations == 1 and not alarm.available, "First click emits once and locks immediately")
	check(
		scene.story.warnings == warnings_before + 1,
		"Original false-alarm consequence still runs once"
	)
	# Subsequent cooldown checks isolate the device from narrative warning escalation.
	devices.alarm_clicked.disconnect(scene.story._on_alarm_clicked)
	for i in 100:
		alarm.activate()
		alarm.activated.emit()
	check(
		activations == 1 and devices._alarm_motion == motion,
		"Rapid clicks cannot duplicate action or tween"
	)
	await create_timer(0.2).timeout
	check(is_equal_approx(devices._dome.position.y, 0.075), "Dome moves down")
	devices.set_ringing(true)
	await create_timer(4.8).timeout
	check(is_equal_approx(devices._dome.position.y, 0.075), "Dome remains down for the full hold")
	check(
		not alarm.available and devices._handset.position != devices._handset_rest,
		"Phone keeps animating while alarm is locked"
	)
	await create_timer(0.4).timeout
	check(is_equal_approx(devices._dome.position.y, 0.095), "Dome returns to rest")
	check(
		devices._alarm_motion == null and alarm.available,
		"Still occupied enables another press after return"
	)

	alarm.activate()
	check(activations == 2, "Next press is accepted after cooldown")
	follow(scene, [scene.cabin.entry_point, scene.cabin.get_node("ApproachPoint")])
	await settled(scene.movement)
	check(not scene._has_elevator_occupant(), "Leaving cabin clears existing movement confirmation")
	await create_timer(0.2).timeout
	check(
		is_equal_approx(devices._dome.position.y, 0.075),
		"Departure does not interrupt the pressed animation"
	)
	await create_timer(5.0).timeout
	check(
		is_equal_approx(devices._dome.position.y, 0.095) and not alarm.available,
		"Empty cabin returns button without re-enabling it"
	)
	alarm.activated.emit()
	check(activations == 2, "Fresh occupancy check rejects a stale activation")


func other_cabins(scene: Node) -> void:
	var alarm = scene.devices.alarm
	for npc in [scene.marta, scene.story.godofredo]:
		npc.ground.global_position = npc.cabin.entry_point.global_position
		follow(npc, [npc.cabin.cabin_stop_point])
		await frames(2)
		check(
			not npc.is_in_cabin() and not alarm.available, "Other NPC still boarding does not count"
		)
		await settled(npc.movement)
		npc.ground.hide()
		await frames(2)
		check(
			npc.is_in_cabin() and not alarm.available,
			"Named cabin occupant never enables the alarm"
		)
		follow(npc, [npc.cabin.entry_point, npc.cabin.get_node("ApproachPoint")])
		var presses_before := activations
		alarm.activate()
		check(
			activations == presses_before, "Departure rejects a click before availability polling"
		)
		await settled(npc.movement)
		await frames(2)
		check(not alarm.available, "Other NPC leaving its cabin disables alarm")

	for npc in [scene.marta, scene.story.godofredo]:
		npc.ground.global_position = npc.cabin.cabin_stop_point.global_position
	await frames(2)
	check(not alarm.available, "Marta and Godofredo together do not count")
	scene.stage = scene.Stage.ENTERING_CABIN
	scene.actor.global_position = scene.cabin.cabin_stop_point.global_position
	await frames(2)
	check(alarm.available, "Common visitor with both named actors counts")
	for npc in [scene.marta, scene.story.godofredo]:
		npc.ground.global_position = scene.service_point.global_position
	for npc in [scene.marta, scene.story.godofredo]:
		npc.ground.global_position = npc.cabin.cabin_stop_point.global_position
		await frames(2)
		check(alarm.available, "Common visitor with one named actor counts")
		npc.ground.global_position = scene.service_point.global_position
	scene.actor.global_position = scene.cabin.get_node("ApproachPoint").global_position
	var texture: Texture2D = TEXTURE
	scene.watch.start_ride(6, texture, "Teste", false)
	await frames(2)
	check(
		scene.watch.has_passenger() and alarm.available,
		"Existing active ride counts as an occupant"
	)
	scene.watch._rider_holder.hide()
	await frames(2)
	check(
		scene.watch.riding and not alarm.available,
		"Ride UI delay after passenger exit does not count"
	)
	scene.watch.cancel()


func ride_alarm(scene: Node) -> void:
	var devices = scene.devices
	devices.alarm_clicked.connect(scene.story._on_alarm_clicked)
	var texture: Texture2D = TEXTURE
	scene.watch.start_ride(6, texture, "Teste", true)
	for i in 600:
		if scene.watch.alarm_open:
			break
		await process_frame
	check(
		scene.watch.alarm_open and devices.alarm.available,
		"Sabotaged ride exposes its original rescue window"
	)
	var warnings_before: int = scene.story.warnings
	var presses_before := activations
	devices.alarm.activate()
	check(
		scene.watch._alarm_hit and not scene.watch.alarm_open,
		"Accepted press still stops the sabotaged ride"
	)
	check(
		scene.story.warnings == warnings_before and activations == presses_before + 1,
		"Valid rescue runs once without false-alarm warning"
	)
	await create_timer(5.4).timeout
	scene.watch.cancel()
	scene.stage = scene.Stage.ENTERING_CABIN
	scene.actor.global_position = scene.cabin.cabin_stop_point.global_position
	scene.story.day = 3
	await frames(2)
	devices.alarm.activate()
	var day3_alarms: int = scene.story._day3_alarms
	for i in 20:
		devices.alarm.activate()
		devices.alarm.activated.emit()
	check(
		scene.story.warnings == warnings_before + 1 and day3_alarms == 1,
		"Day 3 consequence still runs once"
	)
	check(
		scene.story._day3_alarms == day3_alarms,
		"Repeated clicks cannot duplicate day 3 consequences"
	)
	devices.alarm_clicked.disconnect(scene.story._on_alarm_clicked)
	await create_timer(5.4).timeout


func dialogue_lock(scene: Node) -> void:
	var devices = scene.devices
	scene.stage = scene.Stage.ENTERING_CABIN
	scene.actor.global_position = scene.cabin.cabin_stop_point.global_position
	for npc in [scene.marta, scene.story.godofredo]:
		npc.paper.dialogue.chars_per_second = 0
		npc.speak("Teste", "Primeira página. ".repeat(60))
		await frames(2)
		check(not devices.alarm.available, "Character speech blocks occupied alarm")
		var presses := activations
		devices.alarm.activated.emit()
		check(activations == presses, "Speech rejects direct activation")
		var event := InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = true
		npc.paper.forward_input(event)
		await frames(2)
		check(npc.paper.visible and not devices.alarm.available, "Intermediate page stays locked")
		for i in 100:
			if not npc.paper.visible:
				break
			npc.paper.forward_input(event)
			await frames(2)
		check(
			not npc.paper.visible and devices.alarm.available,
			"Last player advance releases speech lock"
		)
	devices.alarm.activate()
	await create_timer(0.2).timeout
	scene.marta.speak("Marta", "Aguarde.")
	await create_timer(5.3).timeout
	check(
		devices._alarm_motion == null and not devices.alarm.available,
		"Speech outlasts cooldown lock"
	)
	check(
		is_equal_approx(devices._dome.position.y, 0.095), "Speech does not interrupt button return"
	)
	scene.marta.paper.forward_input(_advance_event())
	await frames(2)
	check(devices.alarm.available, "Finished speech restores occupied button")
	scene.actor.global_position = scene.service_point.global_position
	scene.marta.speak("Marta", "Sem passageiro.")
	scene.marta.paper.forward_input(_advance_event())
	await frames(2)
	check(not devices.alarm.available, "Finished speech cannot enable an empty cabin")


func _advance_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	return event


func teardown(scene: Node) -> void:
	var devices = scene.devices
	var alarm = devices.alarm
	scene.stage = scene.Stage.ENTERING_CABIN
	scene.actor.global_position = scene.cabin.cabin_stop_point.global_position
	await frames(2)
	alarm.activate()
	await create_timer(0.2).timeout
	var motion: Tween = devices._alarm_motion
	var dome: Node3D = devices._dome
	devices.queue_free()
	await frames(2)
	check(not motion.is_valid(), "Removing device cancels its sole tween")
	check(
		is_equal_approx(dome.position.y, 0.095) and not alarm.available,
		"Removing device restores dome and disables interaction"
	)
	scene.queue_free()
	await frames(3)

	var next = isolated_game(0.25)
	check(
		is_equal_approx(next.devices.alarm_hold_seconds, 0.25), "Inspector value reaches the device"
	)
	next.stage = next.Stage.ENTERING_CABIN
	next.actor.global_position = next.cabin.cabin_stop_point.global_position
	await frames(2)
	next.devices.alarm.activate()
	await create_timer(0.55).timeout
	check(
		next.devices._alarm_motion == null and next.devices.alarm.available,
		"Configured hold duration controls the full cycle"
	)
	next.devices.alarm.activate()
	motion = next.devices._alarm_motion
	next.queue_free()
	await frames(3)
	check(not motion.is_valid(), "Scene replacement cancels pending alarm animation")
	var replacement = isolated_game()
	await frames(2)
	check(
		replacement.devices._alarm_motion == null and not replacement.devices.alarm.available,
		"New scene inherits no cooldown or occupancy"
	)
	replacement.queue_free()
	await frames(3)


func _run() -> void:
	var scene = isolated_game()
	await boarding(scene)
	await cooldown(scene)
	await other_cabins(scene)
	await ride_alarm(scene)
	await dialogue_lock(scene)
	await teardown(scene)
	print("ALARM_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
