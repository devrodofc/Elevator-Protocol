extends Node2D
## Real visits; optional I3 desk and I4 departure. Without enable_departure, never dispatches the actor.

const Session = preload("res://src/gameplay/scripts/reception_session.gd")
const Movement = preload("res://src/gameplay/reception_25d/scripts/visitor_movement.gd")
const VisitorOrientationScript = preload("res://src/gameplay/reception_25d/scripts/visitor_orientation.gd")
const Door = preload("res://src/gameplay/reception_25d/scripts/automatic_door.gd")
const Cabin = preload("res://src/gameplay/reception_25d/scripts/elevator_door.gd")
const VisitSprite = preload("res://src/gameplay/reception_25d/scripts/test_sprite.gd")
const MartaActor = preload("res://src/gameplay/reception_25d/scripts/marta_actor.gd")
const Effects = preload("res://src/gameplay/reception_25d/scripts/reception_effects.gd")
## Approved pilot: every boarding uses cabin 1. The cabin never depends on the chosen floor.
const PILOT_CABIN: String = "Elevator01"
const DAYS: Array[DayScheduleConfig] = [
	preload("res://src/gameplay/schedules/day1.tres"),
	preload("res://src/gameplay/schedules/day2.tres"),
	preload("res://src/gameplay/schedules/day3.tres"),
]

signal visit_reached_service(visit_id: String)
## I4: the actor physically freed the passage (cabin closed or exit door closed), exactly once per visit.
signal visit_departed(visit_id: String)
signal presentation_failed(reason: String)
## I5: emitted once the rule is active, i.e. after the last Space of Marta's speech.
signal rule_announced(rule: MartaRule)

enum Stage {
	IDLE, WAITING_FOR_DOOR, WALKING, AT_SERVICE, CANCELLED, UNSUPPORTED,
	TO_CABIN, WAITING_FOR_CABIN, ENTERING_CABIN, TO_EXIT, EXITING, CLOSING_EXIT, FAILED, DAY_DONE,
	MARTA, FAILING, CONCLUDING, LEAVING_SCENE,
}

## Day carried across reloads/transitions of this scene (I6). Null: use Test Day.
static var dia_em_andamento: DayScheduleConfig = null

@export var enable_service: bool = false
## I4 (requires enable_service): correct result boards cabin 1 or leaves through the entrance; next visit follows.
@export var enable_departure: bool = false
## I5/I6 (requires enable_departure): full day as in 2D, with Marta's intro, rules, failure and end of day.
@export var enable_marta: bool = false

@export_range(1, 3, 1) var test_day: int = 1
@export_enum("Esquerda", "Direita") var initial_entrance: int = 0

@onready var session: Session = $ReceptionSession
@onready var movement: Movement = $VisitorMovement
@onready var orientation: VisitorOrientationScript = $VisitorOrientation
@onready var actor: Node3D = $RoomViewport/Room/VisitorGround
@onready var visual: VisitSprite = $RoomViewport/Room/VisitorGround/TestVisitor
@onready var service_point: Marker3D = $RoomViewport/Room/VisitorPositions/ServicePoint
@onready var cabin: Cabin = get_node("RoomViewport/Room/Elevators/" + PILOT_CABIN)

var stage: Stage = Stage.IDLE
var desk: Node
var marta: MartaActor
var effects: Effects
var departed_count: int = 0
var presentation_error: String = ""
## Associação da apresentação, não uma segunda fila ou autoridade sobre a visita.
var visit_id: String = ""
var visit_entry: Dictionary:
	get: return actor.get_meta("visit_entry", {})
var _session_generation: int
var _run: int = 0
var _arrival_callback: Callable
var _door: Door
var _entrance: Marker3D
var _issuing_route: bool = false
var _incoming_transition: bool = false
## Accepted correct result waiting for the badge to return before the actor leaves.
var _pending_result: Dictionary = {}


func _ready() -> void:
	_incoming_transition = SceneTransition.is_busy()
	actor.hide()
	var day: DayScheduleConfig = DAYS[clampi(test_day, 1, 3) - 1]
	if _marta_mode() and dia_em_andamento:
		day = dia_em_andamento
	# Explicit preview initialization: no fabricated finish_intro/Marta event.
	if _marta_mode():
		session.start_day(day)
	elif enable_service and enable_departure:
		session.start_dispatch_preview(day)
	elif enable_service:
		session.start_service_preview(day)
	else:
		session.start_arrival_preview(day)
	_session_generation = session.generation
	var side: String = "EntranceLeft" if initial_entrance == 0 else "EntranceRight"
	_door = get_node("RoomViewport/Room/Entrances/" + side) as Door
	_entrance = get_node("RoomViewport/Room/VisitorPositions/" + side) as Marker3D
	movement.movement_reset.connect(_on_movement_reset)
	movement.route_started.connect(_on_route_started)
	if _marta_mode():
		_create_desk()
		Dialogue.clear_dialogue() # nothing from the previous scene stays on screen
		Audio.play_music(Audio.MUSICA_ERRADA if day.dia_numero >= 3 else Audio.MUSICA_GAMEPLAY)
		marta = MartaActor.new()
		marta.name = "Marta"
		add_child(marta)
		marta.setup(self)
		effects = Effects.new()
		effects.name = "Effects"
		add_child(effects)
		effects.setup(self)
		_run_intro()
		return
	if not _begin_visit():
		return
	if enable_service:
		_create_desk()


func _create_desk() -> void:
	desk = load("res://src/gameplay/reception_25d/scripts/desk_service.gd").new()
	desk.name = "DeskService"
	add_child(desk)
	desk.decision_processed.connect(_on_decision_processed)


func _marta_mode() -> bool:
	return enable_marta and enable_service and enable_departure


## Same continuation guard as the 2D _presentation_valid: a reload, cancel or transition stops every await.
func _still(generation: int) -> bool:
	return is_inside_tree() and generation == session.generation and stage not in [Stage.CANCELLED, Stage.UNSUPPORTED]


## I5: Marta comes in through the entrance, speaks, leaves through cabin 2; only then the first visitor.
func _run_intro() -> void:
	var generation: int = session.generation
	stage = Stage.MARTA
	desk.set_marta_present(true)
	if not await marta.arrive_from_entrance(_door, _entrance):
		return
	if not await marta.speak("Marta", session.schedule_config.mensagem_inicio):
		return
	if not await marta.leave_into_cabin():
		return
	if not _still(generation) or not session.finish_intro(generation):
		return
	desk.set_marta_present(false)
	_begin_visit()


## I6: as the 2D fail(), with an angry Marta every day. The visitor leaves through the entrance (never a cabin),
## Marta comes out of cabin 2 once he is past the corridor, and the same day reloads.
func _run_failure() -> void:
	var generation: int = session.generation
	Audio.play_sfx(Audio.ERRO)
	desk.set_marta_present(true)
	await get_tree().create_timer(1.0).timeout
	if not _still(generation):
		return
	effects.fade_red()
	# Same exit route as a refusal; its release finds the session FAILED and never calls the next visitor.
	stage = Stage.TO_EXIT
	orientation.face_when_idle(null)
	_door.open()
	_follow([$RoomViewport/Room/VisitorPositions/QueueJoinPoint as Marker3D, _entrance])
	var retreat_z: float = ($RoomViewport/Room/ElevatorRoutes/RetreatPoint as Marker3D).global_position.z
	while actor.visible and actor.global_position.z > retreat_z - 0.5:
		await get_tree().process_frame
		if not _still(generation):
			return
	if not await marta.arrive_from_cabin(MartaActor.ANGER_SPRITE):
		return
	if not await marta.speak("Marta", session.schedule_config.mensagem_falha, 6.0):
		return
	if not _still(generation):
		return
	dia_em_andamento = session.schedule_config
	stage = Stage.LEAVING_SCENE
	session.begin_transition()
	get_tree().reload_current_scene()


## I6: as the 2D _conclude_day: optional suspense, Marta out of cabin 2 (sprite_marta_fim from the start),
## mensagem_fim, then the next day ("Dia N") or the final scene.
func _run_conclusion() -> void:
	var generation: int = session.generation
	var schedule: DayScheduleConfig = session.schedule_config
	stage = Stage.CONCLUDING
	actor.hide()
	desk.set_marta_present(true)
	var escuro: ColorRect = null
	if schedule.suspense_antes_do_fim > 0.0:
		escuro = await effects.apagar_luzes(schedule.suspense_antes_do_fim, schedule.som_no_escuro)
		if not _still(generation):
			return
	if not await marta.arrive_from_cabin(null, schedule.sprite_marta_fim):
		return
	if escuro and schedule.som_no_escuro:
		# She stops and stares in silence; little red light comes back, pulsing while she speaks.
		effects.stare_red(escuro)
		await get_tree().create_timer(1.8).timeout
		if not _still(generation):
			return
	elif escuro:
		effects.dim_partial(escuro)
	if not session.has_next_day():
		marta.speak("Marta", schedule.mensagem_fim)
		return
	if not await marta.speak("Marta", schedule.mensagem_fim):
		return
	if not _still(generation):
		return
	var proximo: DayScheduleConfig = schedule.proximo_dia
	dia_em_andamento = proximo
	stage = Stage.LEAVING_SCENE
	session.begin_transition()
	SceneTransition.transition_to(scene_file_path if proximo else schedule.cena_final,
		"Dia %d" % proximo.dia_numero if proximo else "")


## I5: the rule only becomes active after the last Space; the clipboard opens by itself while she leaves.
func _announce_rule(rule: MartaRule) -> void:
	var generation: int = session.generation
	stage = Stage.MARTA
	desk.set_marta_present(true)
	if not await marta.arrive_from_cabin():
		return
	if not await marta.speak("Marta", rule.fala):
		return
	if not _still(generation) or not session.activate_pending_rule(generation, rule):
		return
	rule_announced.emit(rule)
	desk.flash_rules(1.8)
	if not await marta.leave_into_cabin():
		return
	if not _still(generation) or not session.finish_rule(generation, rule):
		return
	desk.set_marta_present(false)
	_begin_visit()


## Takes the next visit from the session and walks it in. Serial pilot: only after the previous one departed.
func _begin_visit() -> bool:
	_run += 1
	var entry: Dictionary = session.request_next_visit(_session_generation)
	if entry.is_empty():
		if not visit_id.is_empty() and session.state == Session.State.CONCLUDING and _marta_mode():
			_run_conclusion()
			return false
		if not visit_id.is_empty() and session.state == Session.State.CONCLUDING:
			stage = Stage.DAY_DONE
			actor.hide()
			if desk:
				desk.status.text = "Fila concluída · fim do dia na I6"
			return false
		_reject_presentation("A agenda não forneceu uma visita para a prévia I2.")
		return false
	visit_id = session.current_visit_id
	actor.set_meta("visit_id", visit_id)
	actor.set_meta("visit_entry", entry)
	if not _apply_appearance(entry):
		return false
	if _arrival_callback.is_valid() and movement.arrived.is_connected(_arrival_callback):
		movement.arrived.disconnect(_arrival_callback)
	_arrival_callback = _on_arrived.bind(_run, _session_generation, visit_id)
	movement.arrived.connect(_arrival_callback)
	_issuing_route = true
	movement.reset_at(_door.spawn_point)
	_issuing_route = false
	orientation.face_when_idle(null)
	actor.show()
	stage = Stage.WAITING_FOR_DOOR
	_door.open()
	return true


func _apply_appearance(entry: Dictionary) -> bool:
	var data: VisitorData = entry["visitor"]
	# The 2D renderer prioritizes data.cena. Never substitute a random sprite for it.
	if data.cena != null:
		_reject_presentation("I2 não apresenta cenas visuais 2D: " + data.cena.resource_path)
		return false
	if not visual.apply_visit_texture(entry.get("sprite")):
		_reject_presentation("I2 requer uma textura de visita com pixels visíveis: " + data.resource_path)
		return false
	return true


func _process(_delta: float) -> void:
	if stage in [Stage.CANCELLED, Stage.UNSUPPORTED]:
		return
	if not SceneTransition.is_busy():
		_incoming_transition = false
	elif not _incoming_transition:
		cancel_preview()
		return
	if session.generation != _session_generation or session.current_visit_id != visit_id:
		cancel_preview()
		return
	if stage == Stage.WAITING_FOR_DOOR and _door.state == Door.State.OPEN:
		var join_point: Marker3D = $RoomViewport/Room/VisitorPositions/QueueJoinPoint
		var route: Array[Marker3D] = [_entrance, join_point, service_point]
		stage = Stage.WALKING
		_issuing_route = true
		movement.start_from(_door.spawn_point, route)
		_issuing_route = false
	if stage in [Stage.WALKING, Stage.AT_SERVICE] and _door.has_cleared_passage(actor.global_position):
		_door.close()
	_advance_departure()


## I4 departure, polled so that door state and arrival are confirmed in any order.
func _advance_departure() -> void:
	match stage:
		Stage.AT_SERVICE:
			if not _pending_result.is_empty() and not desk.transfer.collecting:
				_start_departure()
		Stage.TO_CABIN:
			if _route_finished(cabin.get_node("ApproachPoint") as Marker3D):
				stage = Stage.WAITING_FOR_CABIN
				orientation.face_when_idle(cabin)
				cabin.open()
		Stage.WAITING_FOR_CABIN:
			if cabin.state == Cabin.State.OPEN:
				stage = Stage.ENTERING_CABIN
				orientation.face_when_idle(null)
				_follow([cabin.entry_point, cabin.cabin_stop_point])
		Stage.ENTERING_CABIN:
			if cabin.has_cleared_passage(actor.global_position):
				cabin.close()
			# Closing started is not closing finished: wait for both the stop point and CLOSED.
			if _route_finished(cabin.cabin_stop_point):
				orientation.face_when_idle(cabin.cabin_facing_target)
				if cabin.state == Cabin.State.CLOSED:
					_release()
		Stage.TO_EXIT:
			if _route_finished(_entrance) and _door.state == Door.State.OPEN:
				stage = Stage.EXITING
				_follow([_door.spawn_point])
		Stage.EXITING:
			if _route_finished(_door.spawn_point):
				# Hidden in the vestibule before the leaves close, so they never close over the sprite.
				actor.hide()
				stage = Stage.CLOSING_EXIT
				_door.close()
		Stage.CLOSING_EXIT:
			if _door.state == Door.State.CLOSED:
				_release()


func _on_decision_processed(result: Dictionary) -> void:
	if not enable_departure or stage != Stage.AT_SERVICE or result.get("visit_id") != visit_id:
		return
	if not result.correct:
		# Wrong answer is never dispatched as success.
		stage = Stage.FAILED
		if _marta_mode():
			_run_failure()
		else:
			desk.status.text = "Incorreto · falha na I6"
		return
	# Counted at the decision, as in the original; the physical release is a separate milestone.
	if session.complete_visit(visit_id):
		_pending_result = result
		if _marta_mode():
			Audio.play_sfx(Audio.SUCESSO)


func _start_departure() -> void:
	var refused: bool = _pending_result.floor_code == RuleValidator.DENY_ACTION
	_pending_result = {}
	orientation.face_when_idle(null)
	var routes: Node3D = $RoomViewport/Room/ElevatorRoutes
	var route: Array[Marker3D] = []
	if refused:
		# Refused visitors leave through the entrance they used, never through a cabin.
		stage = Stage.TO_EXIT
		_door.open()
		route = [$RoomViewport/Room/VisitorPositions/QueueJoinPoint as Marker3D, _entrance]
	else:
		stage = Stage.TO_CABIN
		route = [routes.get_node("RetreatPoint") as Marker3D, routes.get_node("CorridorEntry") as Marker3D,
			routes.get_node(PILOT_CABIN + "TurnPoint") as Marker3D, cabin.get_node("ApproachPoint") as Marker3D]
	_follow(route)


func _release() -> void:
	actor.hide()
	orientation.face_when_idle(null)
	var released: String = visit_id
	# I5: after the 2nd and 4th service Marta takes the interval; otherwise the next visitor comes in.
	var rule: MartaRule = session.take_due_rule(released) if _marta_mode() else null
	if rule == null and not session.finish_interval(released):
		return
	departed_count += 1
	visit_departed.emit(released)
	desk.prepare_next_visit()
	if rule:
		_announce_rule(rule)
	else:
		_begin_visit()


func _follow(route: Array[Marker3D]) -> void:
	_issuing_route = true
	movement.follow_route(route)
	_issuing_route = false


func _route_finished(target: Marker3D) -> bool:
	var at := actor.global_position
	var goal := target.global_position
	return not movement.is_processing() and Vector2(at.x, at.z).is_equal_approx(Vector2(goal.x, goal.z))


func _on_arrived(run: int, generation: int, arrived_visit_id: String) -> void:
	if is_inside_tree() and SceneTransition.is_busy() and not _incoming_transition:
		cancel_preview()
		return
	if not is_inside_tree() or stage != Stage.WALKING or run != _run \
			or generation != session.generation or arrived_visit_id != session.current_visit_id \
			or arrived_visit_id != visit_id or movement.is_processing() \
			or not actor.global_position.is_equal_approx(service_point.global_position):
		return
	if not session.service_reached(arrived_visit_id):
		return
	stage = Stage.AT_SERVICE
	orientation.face_when_idle(orientation.camera)
	visit_reached_service.emit(arrived_visit_id)


## Unexpected reset/route cannot be mistaken for this occurrence's arrival.
func _on_movement_reset() -> void:
	if not _issuing_route:
		cancel_preview()


func _on_route_started() -> void:
	if not _issuing_route:
		cancel_preview()


func _reject_presentation(reason: String) -> void:
	cancel_preview()
	stage = Stage.UNSUPPORTED
	presentation_error = reason
	visual.apply_visit_texture(null)
	push_warning(reason)
	presentation_failed.emit(reason)


func cancel_preview() -> void:
	if stage != Stage.CANCELLED:
		_run += 1
		stage = Stage.CANCELLED
	if is_instance_valid(movement):
		movement.set_process(false)
		if _arrival_callback.is_valid() and movement.arrived.is_connected(_arrival_callback):
			movement.arrived.disconnect(_arrival_callback)
	if is_instance_valid(actor):
		actor.hide()
	if is_instance_valid(_door):
		_door.reset_closed()
	if is_instance_valid(cabin):
		cabin.reset_closed()
	if is_instance_valid(marta):
		marta.cancel()
	if is_instance_valid(effects):
		effects.cancel()
	_pending_result = {}
	if is_instance_valid(session):
		session.close()


func _exit_tree() -> void:
	cancel_preview()
