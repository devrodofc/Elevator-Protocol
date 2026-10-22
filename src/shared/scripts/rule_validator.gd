class_name RuleValidator
extends RefCounted

const DENY_ACTION: int = 999


## Destino correto do visitante: andar, -1 (subsolo) ou DENY_ACTION (negar).
## regras: regras da Marta já ditadas no dia (MartaRule), aplicadas por último.
static func andar_esperado(visitor: VisitorData, dialogo: NPCDialogue, dia: int, regras: Array = []) -> int:
	# Intruso/recusa: o certo é negar o acesso
	if visitor.has_tag("intruder") or visitor.has_tag("deny_access"):
		return DENY_ACTION

	var andar_pedido: int = dialogo.andar_desejado if dialogo != null else 1
	var andar_correto: int = andar_pedido

	# REGRA DO DIA 2+: Entregadores sempre vão para o 1º Andar (Área Comum)
	if dia >= 2 and (visitor.has_tag("delivery") or visitor.has_tag("generic_delivery")):
		andar_correto = 1

	# REGRA DE EVENTO: Seu Tião/Subsolo (-1 / Pavimento Não Atribuído)
	if visitor.has_tag("send_to_basement"):
		andar_correto = -1

	# REGRAS DA MARTA: valem a partir do momento em que ela as dita
	for regra in regras:
		if regra != null and regra.has_method("aplicar"):
			andar_correto = regra.aplicar(andar_pedido, andar_correto)

	return andar_correto


static func validar_decisao(visitor: VisitorData, dialogo: NPCDialogue, decisao: int, dia: int, regras: Array = []) -> bool:
	return decisao == andar_esperado(visitor, dialogo, dia, regras)
