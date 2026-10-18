class_name DayScheduleConfig
extends Resource

@export var dia_numero: int = 1
## Dia que começa quando este termina (depois da fala de fim da Marta). Vazio = último dia.
@export var proximo_dia: DayScheduleConfig

@export_group("Mensagens da Supervisora (Marta)")
@export_multiline var mensagem_inicio: String = "Bom dia! Que alegria ter você aqui na nossa equipe! O trabalho é super tranquilo: tudo o que você precisa fazer é ouvir para onde o visitante quer ir e apertar o botão correto no painel."
@export_multiline var mensagem_fim: String = "Excelente trabalho por hoje! Você pegou o jeito muito rápido. Descanse um pouco e até amanhã!"
## Sprite da Marta só na fala de fim do dia (ex.: dia 2, ensanguentada). Vazio = o da cena Marta.tscn.
@export var sprite_marta_fim: Texture2D
@export_multiline var mensagem_falha: String = "Você tinha um trabalho tão simples... mas falhou. Vamos tentar de novo, certo?"

@export_group("Regras da Marta")
## A cada quantos atendimentos a Marta aparece para ditar uma regra. 0 = não aparece.
@export_range(0, 20) var intervalo_regras: int = 2
## Quantas regras a Marta dita por dia. Elas são sorteadas da lista abaixo
## (pelo menos uma que muda o jogo) e a ordem também é sorteada.
@export_range(0, 10) var regras_por_dia: int = 2
## Banco de regras do dia. Sem valor padrão "= []": com ele o editor descarta a lista salva.
@export var regras_marta: Array[MartaRule]
## Regras ditas todo dia, além do sorteio (contam em regras_por_dia). Ex.: dia 2, entrega para a Marta.
@export var regras_obrigatorias: Array[MartaRule]

@export_group("Visitantes")
## Sorteio usado pelas interações aleatórias que não têm pool próprio
@export var pool_padrao: Array[VisitorData] = []
## Sequência do dia, na ordem em que os visitantes chegam
@export var interacoes: Array[DayInteraction] = []
## Andares que os visitantes aleatórios pedem. Todos aparecem pelo menos uma vez no dia
## (se houver visitantes aleatórios suficientes), em ordem sorteada.
## Dia 1: sem o 3º andar, que fica só para o entregador.
@export var andares_do_dia: PackedInt32Array = PackedInt32Array([1, 2, 3, 4, 5, 6])
## Falas que qualquer visitante aleatório pode usar, além das dele. O andar de cada fala
## (andar_desejado) decide em qual sorteio ela entra. Sem "= []" pelo mesmo motivo acima.
@export var falas_comuns: Array[NPCDialogue]
## Desligado: os aleatórios só usam falas_comuns (ex.: dia 2 com falas próprias, sem repetir
## as falas que ficam no recurso de cada visitante).
@export var usar_falas_do_visitante: bool = true


## Monta a fila completa do dia: {"visitor", "dialogue", "nome", "sprite", "fixo"} por visitante.
func build_queue() -> Array[Dictionary]:
	return montar_dia()["fila"]


## Monta o dia inteiro:
## - "fila": visitantes na ordem. Os aleatórios cobrem todos os andares_do_dia em ordem sorteada,
##   cada um com uma fala sorteada daquele andar, sem repetir fala no mesmo dia. Fixos (ex.:
##   entregador) mantêm a fala definida na interação.
## - "regras": regras_por_dia regras sorteadas, na ordem em que a Marta vai ditar. Pelo menos uma
##   muda o jogo e tem um visitante depois dela pedindo o andar afetado (caso garantido).
##   O visitante logo depois de uma regra nunca é o caso dela: o caso vem mais tarde.
func montar_dia() -> Dictionary:
	var fila: Array[Dictionary] = []
	for interacao in interacoes:
		if interacao:
			fila.append_array(interacao.build_entries(pool_padrao, {}))

	var livres: Array[int] = [] # índices da fila dos visitantes que recebem andar e fala sorteados
	for i in fila.size():
		if not fila[i].get("fixo", false):
			livres.append(i)

	var regras: Array[MartaRule] = _sortear_regras(fila)
	var plano: Array[int] = _plano_de_andares(livres.size())
	var caso: Dictionary = _garantir_caso_de_regra(regras, plano, livres)
	_evitar_caso_no_proximo(regras, plano, livres, caso)
	_aplicar_falas(fila, livres, plano, caso)
	return {"fila": fila, "regras": regras}


## Quantas vezes a Marta consegue aparecer: depois de cada intervalo, se ainda houver visitante.
func _aparicoes_possiveis(tamanho_fila: int) -> int:
	if intervalo_regras <= 0:
		return 0
	return maxi(0, ceili(float(tamanho_fila) / intervalo_regras) - 1)


## Sorteia as regras do dia: uma com efeito garantida + o resto aleatório, em ordem aleatória.
## Regras que mudariam o destino de um visitante fixo (ex.: entregador) ficam de fora no dia,
## para não alterar eventos roteirizados.
func _sortear_regras(fila: Array[Dictionary]) -> Array[MartaRule]:
	var quantidade: int = mini(regras_por_dia, _aparicoes_possiveis(fila.size()))
	var escolhidas: Array[MartaRule] = []
	if quantidade <= 0:
		return escolhidas

	for regra in regras_obrigatorias:
		if regra and escolhidas.size() < quantidade:
			escolhidas.append(regra)

	var com_efeito: Array[MartaRule] = []
	var restantes: Array[MartaRule] = []
	var andares_fixos: Dictionary = {}
	for entry in fila:
		if entry.get("fixo", false) and entry.get("dialogue"):
			andares_fixos[entry["dialogue"].andar_desejado] = true
	for regra in regras_marta:
		if regra and not (regra.tem_efeito() and andares_fixos.has(regra.andar_pedido)):
			restantes.append(regra)
			if regra.tem_efeito():
				com_efeito.append(regra)
	var ja_tem_efeito: bool = false
	for regra in escolhidas:
		ja_tem_efeito = ja_tem_efeito or regra.tem_efeito()
	if not com_efeito.is_empty() and not ja_tem_efeito and escolhidas.size() < quantidade:
		var garantida: MartaRule = com_efeito.pick_random()
		escolhidas.append(garantida)
		restantes.erase(garantida)

	restantes.shuffle()
	while escolhidas.size() < quantidade and not restantes.is_empty():
		escolhidas.append(restantes.pop_back())
	escolhidas.shuffle()
	return escolhidas


## Lista de andares para os visitantes aleatórios: cada andar_do_dia aparece uma vez em ordem
## sorteada; se houver mais visitantes que andares, começa outra rodada sorteada.
func _plano_de_andares(quantidade: int) -> Array[int]:
	var plano: Array[int] = []
	var rodada: Array[int] = []
	while plano.size() < quantidade and not andares_do_dia.is_empty():
		if rodada.is_empty():
			for andar in andares_do_dia:
				rodada.append(andar)
			rodada.shuffle()
		plano.append(rodada.pop_back())
	return plano


## Garante que uma regra com efeito (sorteada) tenha um visitante, depois de ser dita, pedindo o
## andar que ela afeta. Ajusta a ordem das regras e do plano de andares.
## Devolve {"posicao_livre": j, "regra": regra} do visitante que é o caso, ou {} se não deu.
func _garantir_caso_de_regra(regras: Array[MartaRule], plano: Array[int], livres: Array[int]) -> Dictionary:
	if intervalo_regras <= 0 or regras.is_empty() or plano.is_empty():
		return {}

	# A regra da posição k é dita depois de (k + 1) * intervalo atendimentos e vale para quem vem depois.
	# O caso não pode ser o visitante logo em seguida (índice "limite"): fica previsível demais.
	var aparicoes: Array[Dictionary] = []
	for k in regras.size():
		var limite: int = (k + 1) * intervalo_regras
		var vagas: Array[int] = [] # posições em "livres" (e em "plano") depois do próximo visitante
		for j in livres.size():
			if livres[j] > limite:
				vagas.append(j)
		if not vagas.is_empty():
			aparicoes.append({"posicao": k, "vagas": vagas})

	var candidatas: Array[MartaRule] = []
	for regra in regras:
		if regra.tem_efeito():
			candidatas.append(regra)
	if aparicoes.is_empty() or candidatas.is_empty():
		return {}

	var regra: MartaRule = candidatas.pick_random()
	var aparicao: Dictionary = aparicoes.pick_random()

	# Coloca a regra sorteada nessa aparição (troca de lugar com a que estava lá)
	var de: int = regras.find(regra)
	var para: int = aparicao["posicao"]
	regras[de] = regras[para]
	regras[para] = regra

	# O andar da regra tem de cair numa vaga depois da aparição
	var vagas_aparicao: Array[int] = aparicao["vagas"]
	var alvo: int = -1
	for j in vagas_aparicao:
		if plano[j] == regra.andar_pedido:
			alvo = j
			break
	if alvo == -1:
		alvo = vagas_aparicao.pick_random()
		var atual: int = plano.find(regra.andar_pedido)
		if atual != -1:
			plano[atual] = plano[alvo] # troca: o andar continua aparecendo no dia
		plano[alvo] = regra.andar_pedido
	return {"posicao_livre": alvo, "regra": regra}


## O visitante logo depois de cada regra com efeito não pede o andar dela: troca o andar dele
## com o de outro visitante aleatório (que não seja o caso garantido nem o próximo de outra regra).
func _evitar_caso_no_proximo(regras: Array[MartaRule], plano: Array[int], livres: Array[int], caso: Dictionary) -> void:
	if intervalo_regras <= 0:
		return
	var proibido: Dictionary = {} # posição em "plano" -> andar que ela não pode pedir
	for k in regras.size():
		if regras[k].tem_efeito():
			var j: int = livres.find((k + 1) * intervalo_regras)
			if j != -1 and j < plano.size():
				proibido[j] = regras[k].andar_pedido

	for j in proibido:
		if plano[j] != proibido[j]:
			continue
		var trocas: Array[int] = []
		for t in plano.size():
			if t == j or plano[t] == plano[j] or proibido.has(t):
				continue
			if not caso.is_empty() and caso["posicao_livre"] == t:
				continue
			trocas.append(t)
		if not trocas.is_empty():
			var t: int = trocas.pick_random()
			var andar: int = plano[j]
			plano[j] = plano[t]
			plano[t] = andar


## Dá a cada visitante aleatório uma fala do andar planejado, sem repetir texto no dia.
func _aplicar_falas(fila: Array[Dictionary], livres: Array[int], plano: Array[int], caso: Dictionary) -> void:
	var usados: Dictionary = {}
	for entry in fila:
		if entry.get("fixo", false) and entry.get("dialogue"):
			usados[entry["dialogue"].texto] = true

	for j in livres.size():
		if j >= plano.size():
			break
		var entry: Dictionary = fila[livres[j]]
		var preferidas: Array[NPCDialogue] = []
		if not caso.is_empty() and caso["posicao_livre"] == j:
			entry["caso_regra"] = true
			preferidas = caso["regra"].falas_caso
		var fala: NPCDialogue = _sortear_fala(entry["visitor"], plano[j], usados, preferidas)
		if fala:
			entry["dialogue"] = fala
			usados[fala.texto] = true


## Fala para o andar pedido: primeiro as preferidas, depois as do visitante (se usar_falas_do_visitante)
## + falas_comuns.
## Evita textos já usados; se todas daquele andar já saíram, repete uma delas.
func _sortear_fala(visitante: VisitorData, andar: int, usados: Dictionary, preferidas: Array[NPCDialogue]) -> NPCDialogue:
	var do_dia: Array[NPCDialogue] = falas_comuns.duplicate()
	if usar_falas_do_visitante:
		do_dia = visitante.dialogos + falas_comuns
	var grupos: Array = [preferidas, do_dia]
	for grupo in grupos:
		var livres: Array[NPCDialogue] = []
		var do_andar: Array[NPCDialogue] = []
		for fala in grupo:
			if fala and fala.andar_desejado == andar:
				do_andar.append(fala)
				if not usados.has(fala.texto):
					livres.append(fala)
		if not livres.is_empty():
			return livres.pick_random()
		if grupo != preferidas and not do_andar.is_empty():
			return do_andar.pick_random()
	return null
