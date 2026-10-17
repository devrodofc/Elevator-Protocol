class_name NameList
extends Resource
## Lista de nomes sorteados para os visitantes.

@export var names: PackedStringArray = []


func pick() -> String:
	if names.is_empty():
		return "Visitante"
	return names[randi() % names.size()]
