class_name RuleValidator
extends RefCounted

const DENY_ACTION: int = 999


static func validar_decisao(visitor: VisitorData, dialogo: NPCDialogue, decisao: int, dia: int) -> bool:
	# Verificação de ação de Recusa/Negar Acesso
	if decisao == DENY_ACTION:
		return visitor.has_tag("intruder") or visitor.has_tag("deny_access")
	
	# Se era um intruso/recusa e o jogador tentou mandar para algum andar, errou
	if visitor.has_tag("intruder") or visitor.has_tag("deny_access"):
		return false
	
	var andar_correto: int = dialogo.andar_desejado if dialogo != null else 1
	
	# REGRA DO DIA 2+: Entregadores sempre vão para o 1º Andar (Área Comum)
	if dia >= 2 and (visitor.has_tag("delivery") or visitor.has_tag("generic_delivery")):
		andar_correto = 1
	
	# REGRA DE EVENTO: Seu Tião/Subsolo (-1 / Pavimento Não Atribuído)
	if visitor.has_tag("send_to_basement"):
		andar_correto = -1
		
	return decisao == andar_correto
