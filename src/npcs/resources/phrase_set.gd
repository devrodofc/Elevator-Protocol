class_name PhraseSet
extends Resource
## Conjunto de frases que os visitantes falam ao chegar no balcão.
## Marcadores trocados automaticamente: {name} = nome do visitante, {floor} = andar pedido.

## Usadas quando o visitante diz o andar (mentions_floor = true). Use {floor}.
@export_multiline var floor_phrases: PackedStringArray = []
## Usadas quando o visitante NÃO diz o andar (mentions_floor = false).
@export_multiline var no_floor_phrases: PackedStringArray = []


## Sorteia uma frase da lista adequada.
func pick(with_floor: bool) -> String:
	var list := floor_phrases if with_floor else no_floor_phrases
	if list.is_empty():
		return "..."
	return list[randi() % list.size()]
