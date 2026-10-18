extends Control

signal toggled(is_open: bool)

const NOT_INFORMED := "Não informado"

var _has_visitor: bool = false

@onready var _photo: TextureRect = $Card/NPCPhoto
@onready var _name: Label = $Card/NPCName
@onready var _age: Label = $Card/NPCAge
@onready var _sex: Label = $Card/NPCSex
@onready var _occupation: Label = $Card/NPCOccupation


func _ready() -> void:
	hide()
	$ClickOutside.gui_input.connect(_on_outside_gui_input)
	# O Card consome cliques, inclusive nos espaços entre seus campos.
	$Card.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in $Card.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_visitor(null)


func set_visitor(visitor: Visitor, visit_name: String = "") -> void:
	_has_visitor = is_instance_valid(visitor) and visitor.current_data != null
	if not _has_visitor:
		_photo.texture = null
		for label in [_name, _age, _sex, _occupation]:
			label.text = ""
		close()
		return
	var data: VisitorData = visitor.current_data
	_photo.texture = visitor.get_badge_photo()
	_name.text = _text_or_default(visit_name if not visit_name.strip_edges().is_empty() else data.nome)
	_age.text = str(data.idade) if data.idade > 0 else NOT_INFORMED
	_sex.text = _text_or_default(data.sexo)
	_occupation.text = _text_or_default(data.ocupacao)


func open() -> void:
	if not _has_visitor or visible:
		return
	show()
	toggled.emit(true)


func close() -> void:
	if not visible:
		return
	hide()
	toggled.emit(false)


func _on_outside_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		close()


func _text_or_default(value: String) -> String:
	return value if not value.strip_edges().is_empty() else NOT_INFORMED
