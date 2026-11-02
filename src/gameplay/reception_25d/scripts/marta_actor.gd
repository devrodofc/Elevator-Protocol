extends Node
## Marta's 2.5D actor: a second floor-anchored sprite with its own movement, orientation and PAPER speech.
## Uses cabin 2 only and is never a queued visit. Every awaited call returns false if cancel() ran meanwhile.

const Movement = preload("res://src/gameplay/reception_25d/scripts/visitor_movement.gd")
const OrientationScript = preload("res://src/gameplay/reception_25d/scripts/visitor_orientation.gd")
const Paper = preload("res://src/gameplay/reception_25d/scripts/paper_dialogue.gd")
const Cabin = preload("res://src/gameplay/reception_25d/scripts/elevator_door.gd")
const Door = preload("res://src/gameplay/reception_25d/scripts/automatic_door.gd")
const CABIN: String = "Elevator02"
const DEFAULT_SPRITE = preload("res://src/npcs/assets/marta/marta_1_frame.png")
const ANGER_SPRITE = preload("res://src/npcs/assets/marta/marta_anger.png")

var presentation: Node2D
var ground: Node3D
var sprite: Sprite3D
var movement: Movement
var orientation: OrientationScript
var paper: Paper
var cabin: Cabin
var busy: bool = false
var _version: int = 0
var _room: Node3D
var _service_point: Marker3D


func setup(owner_scene: Node2D) -> void:
	presentation = owner_scene
	_room = presentation.get_node("RoomViewport/Room")
	_service_point = presentation.service_point
	cabin = _room.get_node("Elevators/" + CABIN)
	# Same sprite and contact shadow as the visitor, without the visitor's runtime children (paper, metadata).
	ground = Node3D.new()
	ground.name = "MartaGround"
	for part in ["TestVisitor", "ContactShadow"]:
		ground.add_child(presentation.actor.get_node(part).duplicate())
	ground.position = _service_point.position
	_room.add_child(ground)
	ground.hide()
	sprite = ground.get_node("TestVisitor")
	sprite.apply_visit_texture(DEFAULT_SPRITE)
	movement = Movement.new()
	movement.visitor = ground
	movement.floor_reference = _service_point
	movement.movement_speed = presentation.movement.movement_speed
	add_child(movement)
	orientation = OrientationScript.new()
	orientation.sprite = sprite
	orientation.movement = movement
	orientation.service_point = _service_point
	orientation.camera = presentation.orientation.camera
	orientation.orientation_mode = presentation.orientation.orientation_mode
	add_child(orientation)
	# Only the visitor's orientation reads P; this one follows it, so the key is never consumed twice.
	orientation.set_process_input(false)
	paper = Paper.new()
	ground.add_child(paper)


func _process(_delta: float) -> void:
	if orientation and orientation.orientation_mode != presentation.orientation.orientation_mode:
		orientation.orientation_mode = presentation.orientation.orientation_mode


## Intro: from the entrance vestibule to the counter, like a visitor.
func arrive_from_entrance(door: Door, entrance: Marker3D) -> bool:
	var version := _version
	busy = true
	sprite.apply_visit_texture(DEFAULT_SPRITE)
	orientation.face_when_idle(null)
	movement.reset_at(door.spawn_point)
	ground.show()
	door.open()
	if not await _until(func(): return door.state == Door.State.OPEN, version):
		return false
	_follow([entrance, _room.get_node("VisitorPositions/QueueJoinPoint") as Marker3D, _service_point])
	var settled := func() -> bool:
		if door.has_cleared_passage(ground.global_position):
			door.close()
		return _at(_service_point) and door.state == Door.State.CLOSED
	return await _finish(settled, version)


## Rules, failure and end of day: out of cabin 2 to the counter. arrival_sprite replaces it on arrival.
func arrive_from_cabin(arrival_sprite: Texture2D = null, start_sprite: Texture2D = null) -> bool:
	var version := _version
	busy = true
	sprite.apply_visit_texture(start_sprite if start_sprite else DEFAULT_SPRITE)
	orientation.face_when_idle(null)
	movement.reset_at(cabin.cabin_stop_point)
	ground.hide()
	cabin.open()
	Audio.play_sfx(Audio.CHEGOU_ELEVADOR, 0.0, 0.7)
	if not await _until(func(): return cabin.state == Cabin.State.OPEN, version):
		return false
	ground.show()
	var routes: Node3D = _room.get_node("ElevatorRoutes")
	_follow([cabin.entry_point, cabin.get_node("ApproachPoint") as Marker3D, routes.get_node(CABIN + "TurnPoint") as Marker3D,
		routes.get_node("CorridorEntry") as Marker3D, routes.get_node("RetreatPoint") as Marker3D, _service_point])
	var settled := func() -> bool:
		if cabin.has_exited_passage(ground.global_position):
			cabin.close()
		return _at(_service_point) and cabin.state == Cabin.State.CLOSED
	if not await _finish(settled, version):
		return false
	if arrival_sprite:
		sprite.apply_visit_texture(arrival_sprite)
	return true


## Skippable speech on her own paper; max_seconds <= 0 waits for the player only.
func speak(speaker: String, text: String, max_seconds: float = 0.0) -> bool:
	var version := _version
	busy = true
	paper.present({"nome": speaker}, ground, sprite, orientation.camera)
	paper.dialogue.display_dialogue(speaker, text, true)
	await paper.dialogue.wait_for_advance(max_seconds)
	if version != _version or not is_inside_tree():
		return false
	paper.clear()
	busy = false
	return true


## From the counter into cabin 2; hidden once the door is closed.
func leave_into_cabin() -> bool:
	var version := _version
	busy = true
	orientation.face_when_idle(null)
	var routes: Node3D = _room.get_node("ElevatorRoutes")
	var approach := cabin.get_node("ApproachPoint") as Marker3D
	_follow([routes.get_node("RetreatPoint") as Marker3D, routes.get_node("CorridorEntry") as Marker3D,
		routes.get_node(CABIN + "TurnPoint") as Marker3D, approach])
	if not await _until(func(): return _at(approach), version):
		return false
	orientation.face_when_idle(cabin)
	cabin.open()
	if not await _until(func(): return cabin.state == Cabin.State.OPEN, version):
		return false
	orientation.face_when_idle(null)
	_follow([cabin.entry_point, cabin.cabin_stop_point])
	var inside := func() -> bool:
		if cabin.has_cleared_passage(ground.global_position):
			cabin.close()
		return _at(cabin.cabin_stop_point) and cabin.state == Cabin.State.CLOSED
	if not await _finish(inside, version):
		return false
	ground.hide()
	return true


func cancel() -> void:
	_version += 1
	busy = false
	if is_instance_valid(movement):
		movement.set_process(false)
	if is_instance_valid(cabin):
		cabin.reset_closed()
	if is_instance_valid(paper):
		paper.clear()
	if is_instance_valid(ground):
		ground.hide()


func _unhandled_input(event: InputEvent) -> void:
	if paper == null or not paper.visible or not event.is_action_pressed("ui_accept"):
		return
	var desk = presentation.desk
	if desk and not desk.modal.kind.is_empty():
		return
	# RoomView does not forward input; same path as the visitor's paper in DeskService.
	paper.forward_input(event)
	get_viewport().set_input_as_handled()


func _follow(route: Array[Marker3D]) -> void:
	movement.follow_route(route)


func _at(target: Marker3D) -> bool:
	var at := ground.global_position
	var goal := target.global_position
	return not movement.is_processing() and Vector2(at.x, at.z).is_equal_approx(Vector2(goal.x, goal.z))


func _until(condition: Callable, version: int) -> bool:
	while version == _version and is_inside_tree() and not condition.call():
		await get_tree().process_frame
	return version == _version and is_inside_tree()


## Last wait of a movement: also clears busy when it succeeds.
func _finish(condition: Callable, version: int) -> bool:
	var ok: bool = await _until(condition, version)
	if ok:
		busy = false
	return ok


func _exit_tree() -> void:
	cancel()
