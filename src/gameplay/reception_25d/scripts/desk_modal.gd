extends CanvasLayer
signal changed(opened: bool)
const Badge = preload("res://src/gameplay/reception_25d/scripts/inspection_badge.gd")
const Book = preload("res://src/gameplay/reception_25d/scripts/inspection_book.gd")
const Rules = preload("res://src/gameplay/reception_25d/scripts/inspection_rules.gd")
var kind: String = ""
var surface: Control
var content: Control
var badge: Control
var book: Control
var rules: Control


func _ready() -> void:
	layer = 20
	surface = Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(surface)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(shade)
	shade.gui_input.connect(_outside)
	badge = load("res://src/gameplay/hud/scenes/badge_details.tscn").instantiate()
	badge.set_script(Badge)
	surface.add_child(badge)
	badge.toggled.connect(func(opened: bool):
		if not opened and kind == "badge":
			close()
	)
	book = load("res://src/gameplay/hud/scenes/company_book.tscn").instantiate()
	var original_directory: CompanyDirectory = book.directory
	book.set_script(Book)
	book.directory = original_directory
	surface.add_child(book)
	book.mouse_filter = Control.MOUSE_FILTER_STOP
	book.hide()
	rules = load("res://src/gameplay/hud/scenes/rules_board.tscn").instantiate()
	rules.set_script(Rules)
	surface.add_child(rules)
	rules.mouse_filter = Control.MOUSE_FILTER_STOP
	rules.hide()
	get_viewport().size_changed.connect(_layout)
	surface.hide()


func open(which: String, entry: Dictionary, active_rules: Array[MartaRule]) -> bool:
	if not kind.is_empty() or which not in ["badge", "book", "rules"]:
		return false
	kind = which
	content = badge if which == "badge" else (book if which == "book" else rules)
	if which == "badge":
		badge.set_snapshot(entry)
		badge.open()
	elif which == "rules":
		rules.clear_rules()
		for rule in active_rules:
			rules.add_rule(rule.texto_prancheta)
	surface.show()
	content.show()
	_layout()
	changed.emit(true)
	return true


func close() -> void:
	if kind.is_empty():
		return
	kind = ""
	badge.close()
	book.hide()
	rules.hide()
	surface.hide()
	changed.emit(false)


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	for item in [book, rules]:
		var factor: float = minf(2.0 if item == book else 1.8, minf((viewport_size.x - 24) / item.size.x, (viewport_size.y - 24) / item.size.y))
		item.scale = Vector2.ONE * factor
		item.position = (viewport_size - item.size * factor) * 0.5


func _outside(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		surface.accept_event()
		close()


func _input(event: InputEvent) -> void:
	if kind.is_empty():
		return
	if event is InputEventKey:
		if event.is_action_pressed("ui_cancel"):
			close()
		# UI owns keyboard while reading: no F/P or dialogue advance underneath.
		get_viewport().set_input_as_handled()
