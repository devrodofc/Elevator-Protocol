@tool
class_name DayInteraction
extends Resource

## Uma interação do dia: um visitante sorteado ou um predeterminado.

enum Modo { ALEATORIO, FIXO }

@export var modo: Modo = Modo.ALEATORIO:
	set(value):
		modo = value
		notify_property_list_changed()
## Quantos visitantes seguidos esta interação gera (cada aleatório é sorteado de novo)
@export_range(1, 50) var repeticoes: int = 1

## [Fixo] Visitante que vai aparecer
@export var visitante: VisitorData
## [Fixo] Aparência forçada (opcional). Vazio = sorteia entre os sprites do visitante.
@export var sprite: Texture2D

## [Aleatório] Visitantes possíveis. Vazio = usa o pool padrão do dia.
@export var pool: Array[VisitorData] = []

## Fala forçada (opcional). Vazio = sorteia entre os diálogos do visitante.
@export var dialogo: NPCDialogue


## Gera as entradas da fila para esta interação.
func build_entries(pool_padrao: Array[VisitorData]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for i in range(repeticoes):
		var v: VisitorData = _escolher_visitante(pool_padrao)
		if v == null:
			push_warning("DayInteraction sem visitante: defina 'visitante' (Fixo) ou um pool (Aleatório).")
			continue
		entries.append(v.pick_visit(dialogo, sprite if modo == Modo.FIXO else null))
	return entries


func _escolher_visitante(pool_padrao: Array[VisitorData]) -> VisitorData:
	if modo == Modo.FIXO:
		return visitante
	var opcoes: Array[VisitorData] = pool if not pool.is_empty() else pool_padrao
	return opcoes.pick_random() if not opcoes.is_empty() else null


## Esconde no inspector os campos que não valem para o modo atual.
func _validate_property(property: Dictionary) -> void:
	var so_fixo: bool = property.name in ["visitante", "sprite"]
	var so_aleatorio: bool = property.name == "pool"
	if (so_fixo and modo != Modo.FIXO) or (so_aleatorio and modo != Modo.ALEATORIO):
		property.usage = PROPERTY_USAGE_NO_EDITOR
