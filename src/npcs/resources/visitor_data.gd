class_name VisitorData
extends Resource

## Valor de correct_floor que significa "Negar acesso".
const DENY := -1
## Andares que existem no prédio.
const BUILDING_FLOORS: Array[int] = [1, 2, 3]
## Frases usadas por todos os visitantes que não têm fala própria.
const STANDARD_PHRASES: PhraseSet = preload("res://src/npcs/resources/standard_phrases.tres")
## Nomes sorteados quando random_name está ligado.
const MALE_NAMES: NameList = preload("res://src/npcs/resources/male_names.tres")

@export var id: String = "001"
@export var visitor_name: String = "Visitante"
## Fala própria (opcional). Vazio = sorteia uma frase padrão.
## Aceita os marcadores {name} e {floor}.
@export_multiline var custom_dialogue: String = ""
## Conjunto de frases deste visitante (opcional). Vazio = standard_phrases.tres.
@export var phrase_set: PhraseSet

## Se verdadeiro, a frase padrão sorteada menciona o andar pedido.
@export var mentions_floor: bool = true
@export var requested_floor: int = 1

@export var correct_floor: int = 1   # Ex: 1, 2, 3 ou DENY (-1) para Negar Acesso
@export var animation_scene: PackedScene
@export var is_anomaly: bool = false

## Lista de categorias/atributos: "funcionario", "visitante", "entregador", "diretoria", etc.
@export var tags: Array[String] = []

@export_group("Aleatório")
## Sorteia um nome a cada visita (ignora visitor_name).
@export var random_name: bool = true
## Lista de nomes deste visitante (opcional). Vazio = male_names.tres.
@export var name_list: NameList
## Sorteia o andar pedido a cada visita e calcula o correct_floor sozinho
## (ignora requested_floor e correct_floor).
@export var random_floor: bool = true
## Sorteia, a cada visita, o único andar onde o visitante pode ir (ignora allowed_floors).
@export var random_allowed_floor: bool = true
## Andares onde este visitante PODE ir. Se pedir outro, o certo é negar acesso.
@export var allowed_floors: Array[int] = [1, 2, 3]
## Chance (0 a 1) de o visitante pedir um andar fora de allowed_floors.
@export_range(0.0, 1.0, 0.05) var wrong_floor_chance: float = 0.3


## Cria uma cópia desta visita com nome, andar e frase sorteados.
## Use ao spawnar: o mesmo .tres pode aparecer várias vezes com dados diferentes.
func create_visit() -> VisitorData:
	var visit: VisitorData = duplicate()

	if random_name:
		visit.visitor_name = (name_list if name_list else MALE_NAMES).pick()

	if random_allowed_floor:
		var allowed: Array[int] = [BUILDING_FLOORS.pick_random()]
		visit.allowed_floors = allowed

	if random_floor:
		var forbidden: Array[int] = []
		for f in BUILDING_FLOORS:
			if f not in visit.allowed_floors:
				forbidden.append(f)
		var wants_wrong_floor := not forbidden.is_empty() and randf() < wrong_floor_chance
		if wants_wrong_floor or visit.allowed_floors.is_empty():
			visit.requested_floor = forbidden.pick_random() if not forbidden.is_empty() else BUILDING_FLOORS.pick_random()
			visit.correct_floor = DENY
		else:
			visit.requested_floor = visit.allowed_floors.pick_random()
			visit.correct_floor = visit.requested_floor

	# Fixa a frase sorteada para ela não mudar durante a visita.
	if visit.custom_dialogue.strip_edges().is_empty():
		visit.custom_dialogue = (phrase_set if phrase_set else STANDARD_PHRASES).pick(mentions_floor)

	return visit


## Verdadeiro se o visitante pediu um andar onde não pode ir.
func is_wrong_floor_request() -> bool:
	return correct_floor == DENY


## Retorna a fala completa: a fala própria ou uma frase padrão sorteada,
## com {name} e {floor} preenchidos.
func get_full_dialogue() -> String:
	var template: String = custom_dialogue.strip_edges()
	if template.is_empty():
		var phrases: PhraseSet = phrase_set if phrase_set else STANDARD_PHRASES
		template = phrases.pick(mentions_floor)
	return template.format({"name": visitor_name, "floor": requested_floor})


## Verifica se o visitante possui uma tag específica (ignora maiúsculas/minúsculas)
func has_tag(target_tag: String) -> bool:
	var clean_target: String = target_tag.strip_edges().to_lower()
	for t in tags:
		if t.strip_edges().to_lower() == clean_target:
			return true
	return false
