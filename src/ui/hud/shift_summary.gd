extends Control

@onready var _correct_label: Label = %CorrectLabel
@onready var _mistakes_label: Label = %MistakesLabel
@onready var _result_label: Label = %ResultLabel


func _ready() -> void:
	visible = false


func setup_summary(correct_decisions: int, mistakes: int) -> void:
	if _correct_label:
		_correct_label.text = "Acertos: %d" % correct_decisions
	if _mistakes_label:
		_mistakes_label.text = "Erros: %d" % mistakes
	if _result_label:
		_result_label.text = "Status: %s" % ("Carga concluída" if mistakes == 0 else "Turno instável")
	visible = true
