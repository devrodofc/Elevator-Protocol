extends Node2D
## One real visit; optional I3 desk presentation. Never dispatches the actor.

const Session = preload("res://src/gameplay/scripts/reception_session.gd")
const Movement = preload("res://src/gameplay/reception_25d/scripts/visitor_movement.gd")
const VisitorOrientationScript = preload("res://src/gameplay/reception_25d/scripts/visitor_orientation.gd")
const Door = preload("res://src/gameplay/reception_25d/scripts/automatic_door.gd")
const VisitSprite = preload("res://src/gameplay/reception_25d/scripts/test_sprite.gd")
const DAYS: Array[DayScheduleConfig] = [
	preload("res://src/gameplay/schedules/day1.tres"),
	preload("res://src/gameplay/schedules/day2.tres"),
	preload("res://src/gameplay/schedules/day3.tres"),
]

signal visit_reached_service(visit_id: String)
signal presentation_failed(reason: String)

enum Stage { IDLE, WAITING_FOR_DOOR, WALKING, AT_SERVICE, CANCELLED, UNSUPPORTED }

@export var enable_service: bool = false

@export_range(1, 3, 1) var test_day: int = 1
@export_enum("Esquerda", "Direita") var initial_entrance: int = 0

@onready var session: Session = $ReceptionSession
@onready var movement: Movement = $VisitorMovement
@onready var orientation: VisitorOrientationScript = $VisitorOrientation
@onready var actor: Node3D = $RoomViewport/Room/VisitorGround
@onready var visual: VisitSprite = $RoomViewport/Room/VisitorGround/TestVisitor
@onready var service_point: Marker3D = $RoomViewport/Room/VisitorPositions/ServicePoint

var stage: Stage = Stage.IDLE
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


func _ready() -> void:
	_incoming_transition = SceneTransition.is_busy()
	actor.hide()
	# Explicit preview initialization: no fabricated finish_intro/Marta event.
	if enable_service:
		session.start_service_preview(DAYS[clampi(test_day, 1, 3) - 1])
	else:
		session.start_arrival_preview(DAYS[clampi(test_day, 1, 3) - 1])
	_session_generation = session.generation
	_run += 1
	var entry: Dictionary = session.request_next_visit(_session_generation)
	if entry.is_empty():
		_reject_presentation("A agenda não forneceu uma visita para a prévia I2.")
		return
	visit_id = session.current_visit_id
	actor.set_meta("visit_id", visit_id)
	actor.set_meta("visit_entry", entry)
	if not _apply_appearance(entry):
		return
	var side: String = "EntranceLeft" if initial_entrance == 0 else "EntranceRight"
	_door = get_node("RoomViewport/Room/Entrances/" + side) as Door
	_entrance = get_node("RoomViewport/Room/VisitorPositions/" + side) as Marker3D
	_arrival_callback = _on_arrived.bind(_run, _session_generation, visit_id)
	movement.arrived.connect(_arrival_callback)
	movement.movement_reset.connect(_on_movement_reset)
	movement.route_started.connect(_on_route_started)
	_issuing_route = true
	movement.reset_at(_door.spawn_point)
	_issuing_route = false
	orientation.face_when_idle(null)
	actor.show()
	stage = Stage.WAITING_FOR_DOOR
	_door.open()
	if enable_service:
		var desk = load("res://src/gameplay/reception_25d/scripts/desk_service.gd").new()
		desk.name = "DeskService"
		add_child(desk)


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
	if is_instance_valid(session):
		session.close()


func _exit_tree() -> void:
	cancel_preview()
