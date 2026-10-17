extends Control

@onready var _rule_label: Label = %RuleLabel
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_show_default_state()


func show_visitor_guide(visitor_data: VisitorData = null) -> void:
	if visitor_data == null:
		_show_default_state()
		return

	var access_text: String = "respeite o protocolo"
	if visitor_data.correct_floor == VisitorData.DENY:
		access_text = "negue o acesso"
	else:
		access_text = "leve ao andar %s" % visitor_data.correct_floor

	_status_label.text = "%s: %s" % [visitor_data.visitor_name, access_text]
	_rule_label.text = "Desvio permitido: %s\nTeclas: 1, 2, 3 para andares; N para negar" % [str(visitor_data.allowed_floors)]


func _show_default_state() -> void:
	if _status_label:
		_status_label.text = "Balcão em operação"
	if _rule_label:
		_rule_label.text = "Teclas: 1, 2, 3 para andares; N para negar"
