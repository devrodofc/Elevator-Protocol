extends GutTest


class RegraDeTeste:
	extends RefCounted

	func aplicar(_andar_pedido: int, _andar_correto: int) -> int:
		return 6


func _criar_visitante(tags: Array[String] = []) -> VisitorData:
	var visitante := VisitorData.new()
	visitante.tags = tags
	return visitante


func _criar_dialogo(andar: int) -> NPCDialogue:
	var dialogo := NPCDialogue.new()
	dialogo.andar_desejado = andar
	return dialogo


func test_visitante_comum_vai_para_andar_solicitado() -> void:
	var visitante := _criar_visitante()
	var dialogo := _criar_dialogo(3)

	assert_eq(RuleValidator.andar_esperado(visitante, dialogo, 1), 3)


func test_dialogo_nulo_utiliza_primeiro_andar() -> void:
	var visitante := _criar_visitante()

	assert_eq(RuleValidator.andar_esperado(visitante, null, 1), 1)


func test_intruso_tem_acesso_negado() -> void:
	var visitante := _criar_visitante(["intruder"])
	var dialogo := _criar_dialogo(3)

	assert_eq(RuleValidator.andar_esperado(visitante, dialogo, 1), RuleValidator.DENY_ACTION)


func test_tag_deny_access_nega_acesso() -> void:
	var visitante := _criar_visitante(["deny_access"])
	var dialogo := _criar_dialogo(4)

	assert_eq(RuleValidator.andar_esperado(visitante, dialogo, 1), RuleValidator.DENY_ACTION)


func test_entregador_dia_1_utiliza_andar_solicitado() -> void:
	var visitante := _criar_visitante(["delivery"])
	var dialogo := _criar_dialogo(4)

	assert_eq(RuleValidator.andar_esperado(visitante, dialogo, 1), 4)


func test_entregador_dia_2_vai_para_primeiro_andar() -> void:
	var visitante := _criar_visitante(["delivery"])
	var dialogo := _criar_dialogo(4)

	assert_eq(RuleValidator.andar_esperado(visitante, dialogo, 2), 1)


func test_entregador_generico_dia_2_vai_para_primeiro_andar() -> void:
	var visitante := _criar_visitante(["generic_delivery"])
	var dialogo := _criar_dialogo(5)

	assert_eq(RuleValidator.andar_esperado(visitante, dialogo, 2), 1)


func test_entregador_dia_3_continua_no_primeiro_andar() -> void:
	var visitante := _criar_visitante(["delivery"])
	var dialogo := _criar_dialogo(6)

	assert_eq(RuleValidator.andar_esperado(visitante, dialogo, 3), 1)


func test_visitante_marcado_para_subsolo() -> void:
	var visitante := _criar_visitante(["send_to_basement"])
	var dialogo := _criar_dialogo(3)

	assert_eq(RuleValidator.andar_esperado(visitante, dialogo, 1), -1)


func test_subsolo_tem_prioridade_sobre_regra_de_entregador() -> void:
	var visitante := _criar_visitante(["delivery", "send_to_basement"])
	var dialogo := _criar_dialogo(4)

	assert_eq(RuleValidator.andar_esperado(visitante, dialogo, 2), -1)


func test_validar_decisao_aceita_andar_correto() -> void:
	var visitante := _criar_visitante()
	var dialogo := _criar_dialogo(3)

	assert_true(RuleValidator.validar_decisao(visitante, dialogo, 3, 1))


func test_validar_decisao_rejeita_andar_incorreto() -> void:
	var visitante := _criar_visitante()
	var dialogo := _criar_dialogo(3)

	assert_false(RuleValidator.validar_decisao(visitante, dialogo, 5, 1))


func test_regra_adicional_e_aplicada_por_ultimo() -> void:
	var visitante := _criar_visitante(["delivery"])
	var dialogo := _criar_dialogo(4)
	var regras: Array = [RegraDeTeste.new()]

	assert_eq(RuleValidator.andar_esperado(visitante, dialogo, 2, regras), 6)


func test_intruso_continua_negado_com_regra_adicional() -> void:
	var visitante := _criar_visitante(["intruder"])
	var dialogo := _criar_dialogo(4)
	var regras: Array = [RegraDeTeste.new()]

	assert_eq(
		RuleValidator.andar_esperado(visitante, dialogo, 2, regras), RuleValidator.DENY_ACTION
	)
