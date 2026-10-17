class_name DayScheduleConfig
extends Resource

@export var dia_numero: int = 1

@export_group("Mensagens da Supervisora (Marta)")
@export_multiline var mensagem_inicio: String = "Bom dia! Que alegria ter você aqui na nossa equipe! O trabalho é super tranquilo: tudo o que você precisa fazer é ouvir para onde o visitante quer ir e apertar o botão correto no painel."
@export_multiline var mensagem_fim: String = "Excelente trabalho por hoje! Você pegou o jeito muito rápido. Descanse um pouco e até amanhã!"
@export_multiline var mensagem_falha: String = "Você tinha um trabalho tão simples... mas falhou. Vamos tentar de novo, certo?"

@export_group("Fase 1: Primeiros Normais")
## Quantidade de personagens normais a sortear na primeira leva (ex: 10)
@export var qtd_primeira_fase: int = 10
## Lista de VisitorData permitidos para a primeira fase
@export var pool_primeira_fase: Array[VisitorData] = []

@export_group("Fase 2: Personagem Fixo / Evento")
## O personagem fixo que entra após os primeiros normais (ex: Seu Tião, Lucas, etc.)
@export var npc_fixo: VisitorData
## Diálogo forçado específico (opcional; se vazio, usa os diálogos internos do VisitorData)
@export var dialogo_fixo: NPCDialogue

@export_group("Fase 3: Últimos Normais")
## Quantidade de personagens normais a sortear após o evento fixo (ex: 2)
@export var qtd_segunda_fase: int = 2
## Lista de VisitorData permitidos para a segunda fase
@export var pool_segunda_fase: Array[VisitorData] = []
