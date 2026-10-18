class_name DayScheduleConfig
extends Resource

@export var dia_numero: int = 1

@export_group("Mensagens da Supervisora (Marta)")
@export_multiline var mensagem_inicio: String = "Bom dia! Que alegria ter você aqui na nossa equipe! O trabalho é super tranquilo: tudo o que você precisa fazer é ouvir para onde o visitante quer ir e apertar o botão correto no painel."
@export_multiline var mensagem_fim: String = "Excelente trabalho por hoje! Você pegou o jeito muito rápido. Descanse um pouco e até amanhã!"
@export_multiline var mensagem_falha: String = "Você tinha um trabalho tão simples... mas falhou. Vamos tentar de novo, certo?"

@export_group("Regras da Marta")
## A cada quantos atendimentos a Marta aparece para ditar uma regra. 0 = não aparece.
@export_range(0, 20) var intervalo_regras: int = 2
## Regras na ordem em que ela dita. Sem valor padrão "= []": com ele o editor descarta a lista salva.
@export var regras_marta: Array[MartaRule]

@export_group("Visitantes")
## Sorteio usado pelas interações aleatórias que não têm pool próprio
@export var pool_padrao: Array[VisitorData] = []
## Sequência do dia, na ordem em que os visitantes chegam
@export var interacoes: Array[DayInteraction] = []


## Monta a fila completa do dia: {"visitor", "dialogue", "nome", "sprite", "fixo"} por visitante.
func build_queue() -> Array[Dictionary]:
	return montar_dia()["fila"]


## Monta o dia inteiro:
## - "fila": visitantes na ordem, sem repetir fala no mesmo dia;
## - "regras": regras da Marta na ordem em que ela vai ditar, com pelo menos uma
##   regra com efeito tendo um visitante depois dela que se encaixa (regra sorteada).
func montar_dia() -> Dictionary:
	var textos_usados: Dictionary = {}
	var fila: Array[Dictionary] = []
	for interacao in interacoes:
		if interacao:
			fila.append_array(interacao.build_entries(pool_padrao, textos_usados))
	var regras: Array[MartaRule] = []
	for regra in regras_marta:
		if regra:
			regras.append(regra)
	_garantir_caso_de_regra(fila, regras, textos_usados)
	return {"fila": fila, "regras": regras}


## Sorteia uma regra com efeito, coloca ela numa aparição da Marta que ainda tenha visitantes
## comuns depois, e troca a fala de um desses visitantes por uma das falas_caso da regra.
func _garantir_caso_de_regra(fila: Array[Dictionary], regras: Array[MartaRule], textos_usados: Dictionary) -> void:
	if intervalo_regras <= 0:
		return

	# A regra da posição k é dita depois de (k + 1) * intervalo atendimentos e vale para quem vem depois.
	# Só servem aparições com algum visitante não fixo depois (o fixo mantém a própria fala).
	var aparicoes: Array[Dictionary] = []
	var k: int = 0
	while k < regras.size() and (k + 1) * intervalo_regras < fila.size():
		var vagas: Array[int] = []
		for i in range((k + 1) * intervalo_regras, fila.size()):
			if not fila[i].get("fixo", false):
				vagas.append(i)
		if not vagas.is_empty():
			aparicoes.append({"posicao": k, "vagas": vagas})
		k += 1

	var candidatas: Array[MartaRule] = []
	for regra in regras:
		if regra.tem_efeito() and not regra.falas_caso.is_empty():
			candidatas.append(regra)
	if aparicoes.is_empty() or candidatas.is_empty():
		return

	var regra: MartaRule = candidatas.pick_random()
	var aparicao: Dictionary = aparicoes.pick_random()

	# Coloca a regra sorteada nessa aparição (troca de lugar com a que estava lá)
	var de: int = regras.find(regra)
	var para: int = aparicao["posicao"]
	regras[de] = regras[para]
	regras[para] = regra

	# Um visitante comum depois dela passa a pedir o andar da regra
	var livres: Array[NPCDialogue] = []
	for fala in regra.falas_caso:
		if fala and not textos_usados.has(fala.texto):
			livres.append(fala)
	var fala_caso: NPCDialogue = livres.pick_random() if not livres.is_empty() else regra.falas_caso.pick_random()
	var vagas_aparicao: Array[int] = aparicao["vagas"]
	var indice: int = vagas_aparicao.pick_random()
	var anterior: NPCDialogue = fila[indice].get("dialogue")
	if anterior:
		textos_usados.erase(anterior.texto)
	fila[indice]["dialogue"] = fala_caso
	fila[indice]["caso_regra"] = true
	textos_usados[fala_caso.texto] = true
