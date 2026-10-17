class_name VisitorData
extends Resource

@export var id: String = "001"
@export var visitor_name: String = "Visitante"
@export_multiline var dialogue_prefix: String = "Olá, gostaria de subir para o andar"

## Se verdadeiro, concatena o requested_floor ao final da fala. Se falso, usa apenas dialogue_prefix.
@export var mentions_floor: bool = true
@export var requested_floor: int = 1

@export var correct_floor: int = 1   # Ex: 1, 2, 3 ou -1 para Negar Acesso
@export var animation_scene: PackedScene
@export var is_anomaly: bool = false

## Lista de categorias/atributos: "funcionario", "visitante", "entregador", "diretoria", etc.
@export var tags: Array[String] = []


## Retorna a fala completa montada
func get_full_dialogue() -> String:
	var clean_text: String = dialogue_prefix.strip_edges()
	
	if mentions_floor:
		return "%s %d." % [clean_text, requested_floor]
	
	return clean_text


## Verifica se o visitante possui uma tag específica (ignora maiúsculas/minúsculas)
func has_tag(target_tag: String) -> bool:
	var clean_target: String = target_tag.strip_edges().to_lower()
	for t in tags:
		if t.strip_edges().to_lower() == clean_target:
			return true
	return false
