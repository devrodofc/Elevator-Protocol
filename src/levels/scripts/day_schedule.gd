class_name DayScheduleConfig
extends Resource

@export var dia_numero: int = 1

@export_group("Mensagens da Supervisora (Marta)")
@export_multiline var mensagem_inicio: String = "Bom dia! Que alegria ter você aqui na nossa equipe! O trabalho é super tranquilo: tudo o que você precisa fazer é ouvir para onde o visitante quer ir e apertar o botão correto no painel."
@export_multiline var mensagem_fim: String = "Excelente trabalho por hoje! Você pegou o jeito muito rápido. Descanse um pouco e até amanhã!"
@export_multiline var mensagem_falha: String = "Você tinha um trabalho tão simples... mas falhou. Vamos tentar de novo, certo?"

@export_group("Visitantes")
## Sorteio usado pelas interações aleatórias que não têm pool próprio
@export var pool_padrao: Array[VisitorData] = []
## Sequência do dia, na ordem em que os visitantes chegam
@export var interacoes: Array[DayInteraction] = []


## Monta a fila completa do dia: {"visitor", "dialogue", "nome", "sprite"} por visitante.
func build_queue() -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	for interacao in interacoes:
		if interacao:
			queue.append_array(interacao.build_entries(pool_padrao))
	return queue
