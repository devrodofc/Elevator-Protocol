extends Node
## I3 presentation: physical consultation + one logical result, never a departure.
signal decision_processed(result: Dictionary)
const Models = preload("res://src/gameplay/reception_25d/scripts/desk_models.gd")
const Picker = preload("res://src/gameplay/reception_25d/scripts/desk_picker.gd")
const Modal = preload("res://src/gameplay/reception_25d/scripts/desk_modal.gd")
const Paper = preload("res://src/gameplay/reception_25d/scripts/paper_dialogue.gd")
const Transfer = preload("res://src/gameplay/reception_25d/scripts/badge_transfer.gd")
const Session = preload("res://src/gameplay/scripts/reception_session.gd")
var presentation: Node2D
var picker: Picker
var modal: Modal
var paper: Paper
var transfer: Transfer
var badge: StaticBody3D
var book: StaticBody3D
var clipboard: StaticBody3D
var buttons: Dictionary = {}
var confirm: StaticBody3D
var selected_floor: int = 0
var result: Dictionary = {}
var _confirming: bool = false
var _confirmation: Tween
var _visit_id: String
var _generation: int
var _camera_mode: int
var _debug_mode: int
var _mouse_mode: Input.MouseMode
var _modal_locked: bool = false
var _cancelled: bool = false
var status: Label3D


func _ready() -> void:
	presentation = get_parent()
	var room: Node3D = presentation.get_node("RoomViewport/Room")
	var anchors: Node3D = room.get_node("ReceptionDesk/ServiceObjects")
	badge = Models.object_at(anchors.get_node("BadgeRest"), "Badge", Vector3(0.28, 0.018, 0.4))
	book = Models.object_at(anchors.get_node("BookRest"), "Book", Vector3(0.55, 0.065, 0.62))
	clipboard = Models.object_at(anchors.get_node("ClipboardRest"), "Clipboard", Vector3(0.48, 0.028, 0.57))
	badge.hide()
	badge.set_available(false)
	picker = Picker.new()
	picker.room_view = presentation.get_node("RoomView")
	picker.room_viewport = presentation.get_node("RoomViewport")
	picker.camera = room.get_node("ReceptionCamera")
	add_child(picker)
	modal = Modal.new()
	add_child(modal)
	modal.changed.connect(_modal_changed)
	badge.activated.connect(func(): _open("badge"))
	book.activated.connect(func(): _open("book"))
	clipboard.activated.connect(func(): _open("rules"))
	paper = Paper.new()
	presentation.actor.add_child(paper)
	transfer = Transfer.new()
	transfer.badge = badge
	transfer.target = anchors.get_node("BadgeRest")
	transfer.actor = presentation.actor
	add_child(transfer)
	_build_panel(anchors.get_node("PanelRest"))
	presentation.visit_reached_service.connect(_arrived)
	presentation.get_node("ElevatorUI/Selection").hide()


func _build_panel(anchor: Node3D) -> void:
	Models.box(anchor, Vector3(1.08, 0.82, 0.065), Vector3.ZERO, Color("303c43"))
	var codes := [5, 6, 3, 4, 1, 2, -1, 999]
	for i in codes.size():
		var code: int = codes[i]
		var title := str(code) if code > 0 and code < 999 else ("-1" if code == -1 else "X")
		var button = Models.button(anchor, title, Vector3(-0.32 + (i % 2) * 0.32, 0.28 - (i / 2) * 0.16, 0.055), Vector3(0.27, 0.135, 0.04))
		button.set_available(false)
		button.activated.connect(select_floor.bind(code))
		buttons[code] = button
	confirm = Models.button(anchor, "OK", Vector3(0.34, 0.0, 0.06), Vector3(0.27, 0.28, 0.045))
	confirm.set_available(false)
	confirm.activated.connect(confirm_selection)
	status = Label3D.new()
	status.font = Models.FONT
	status.font_size = 20
	status.pixel_size = 0.0033
	status.position = Vector3(0, -0.31, 0.045)
	status.outline_size = 0
	status.text = "Aguarde o visitante"
	anchor.add_child(status)


func _arrived(id: String) -> void:
	if _cancelled or not _visit_id.is_empty() or id != presentation.session.current_visit_id:
		return
	_visit_id = id
	_generation = presentation.session.generation
	paper.present(presentation.visit_entry, presentation.actor, presentation.visual, picker.camera)
	transfer.deliver(id)
	status.text = "Escolha · X: recusar · OK"
	_refresh_panel()


func _valid() -> bool:
	return not _cancelled and not _visit_id.is_empty() and _visit_id == presentation.session.current_visit_id \
		and _generation == presentation.session.generation and not SceneTransition.is_busy()


func _can_choose() -> bool:
	return _valid() and presentation.session.state == Session.State.SERVING \
		and modal.kind.is_empty() and not _confirming and result.is_empty()


func select_floor(code: int) -> void:
	if not _can_choose() or not buttons.has(code):
		return
	selected_floor = 0 if selected_floor == code else code
	status.text = "Confirmar %s em OK" % ("recusa" if code == 999 else str(code)) if selected_floor else "Escolha · X: recusar · OK"
	_refresh_panel()


func _refresh_panel() -> void:
	for code in buttons:
		buttons[code].set_available(_can_choose())
		buttons[code].set_selected(selected_floor == code)
	confirm.set_available(_can_choose() and selected_floor != 0)


func confirm_selection() -> void:
	if not _can_choose() or selected_floor == 0:
		return
	_confirming = true
	_refresh_panel()
	# Same 0.15 s confirmation window as the original panel, with identity checks.
	_confirmation = create_tween()
	_confirmation.tween_interval(0.15)
	_confirmation.tween_callback(_resolve.bind(_visit_id, _generation, selected_floor))


func _resolve(id: String, generation: int, code: int) -> void:
	_confirming = false
	if not _valid() or id != _visit_id or generation != _generation or not modal.kind.is_empty():
		_refresh_panel()
		return
	var accepted: Dictionary = presentation.session.submit_decision(id, code)
	if accepted.is_empty():
		_refresh_panel()
		return
	result = accepted.duplicate()
	result.make_read_only()
	modal.close()
	paper.clear()
	transfer.collect(id)
	status.text = "Registrado: %s" % ("correto" if result.correct else "incorreto")
	_refresh_panel()
	decision_processed.emit(result)


func _open(which: String) -> void:
	if _cancelled or SceneTransition.is_busy() or _confirming:
		return
	if which == "badge" and (not _valid() or not result.is_empty() or not badge.available):
		return
	modal.open(which, presentation.visit_entry, presentation.session.active_rules)


func _modal_changed(opened: bool) -> void:
	var camera: Node = picker.camera
	var debug: Node = presentation.get_node("DebugFreeCamera")
	if opened and not _modal_locked:
		_modal_locked = true
		_camera_mode = camera.process_mode
		_debug_mode = debug.process_mode
		debug._release_mouse()
		debug._keys.clear()
		debug._velocity = Vector3.ZERO
		_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		camera.process_mode = Node.PROCESS_MODE_DISABLED
		debug.process_mode = Node.PROCESS_MODE_DISABLED
		presentation.orientation.set_process_input(false)
	elif not opened and _modal_locked:
		_modal_locked = false
		camera.process_mode = _camera_mode
		debug.process_mode = _debug_mode
		presentation.orientation.set_process_input(true)
		Input.mouse_mode = _mouse_mode
	picker.set_blocked(opened or _cancelled)
	paper.modal = opened
	_refresh_panel()


func _process(_delta: float) -> void:
	if _cancelled:
		return
	if presentation.stage in [presentation.Stage.CANCELLED, presentation.Stage.UNSUPPORTED] \
		or (not _visit_id.is_empty() and (_generation != presentation.session.generation or _visit_id != presentation.session.current_visit_id)):
		cancel()


func cancel() -> void:
	if _cancelled:
		return
	_cancelled = true
	if _confirmation:
		_confirmation.kill()
	_confirming = false
	modal.close()
	picker.set_blocked(true)
	paper.clear()
	transfer.cancel()
	book.set_available(false)
	clipboard.set_available(false)
	_refresh_panel()


func _exit_tree() -> void:
	cancel()


func _unhandled_input(event: InputEvent) -> void:
	if not _cancelled and modal.kind.is_empty() and paper.visible and event.is_action_pressed("ui_accept"):
		paper.forward_input(event)
		get_viewport().set_input_as_handled()
