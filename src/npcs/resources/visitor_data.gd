class_name VisitorData
extends Resource

const NOMES_PADRAO_PATH := "res://src/npcs/resources/male_names.tres"

@export var id: String = ""
@export var nome: String = ""
## Sorteia um nome diferente a cada visita (para NPCs comuns). Desligado = usa "nome".
@export var nome_aleatorio: bool = false
## Lista de nomes para o sorteio (opcional). Vazio = male_names.tres.
@export var lista_nomes: NameList
@export var cena: PackedScene # Instância com arte/animação em Pixel Art
@export var tags: Array[String] = [] # "delivery", "vip", "intruder", "send_to_basement", etc.
@export var dialogos: Array[NPCDialogue] = []

@export_group("Crachá")
## Zero indica idade não informada.
@export_range(0, 150, 1) var idade: int = 0
@export var sexo: String = ""
@export var ocupacao: String = ""
## Opcional. Sem retrato, o crachá usa a textura do sprite do visitante.
@export var retrato: Texture2D


func has_tag(tag_name: String) -> bool:
	return tags.has(tag_name)


func pick_visit(forced_dialogue: NPCDialogue = null) -> Dictionary:
	var d: NPCDialogue = forced_dialogue
	if d == null and not dialogos.is_empty():
		d = dialogos.pick_random()
	
	return {
		"visitor": self,
		"dialogue": d,
		"nome": _sortear_nome()
	}


## Nome desta visita: sorteado se nome_aleatorio estiver ligado, senão o "nome" fixo.
func _sortear_nome() -> String:
	if not nome_aleatorio:
		return nome
	var lista: NameList = lista_nomes if lista_nomes else load(NOMES_PADRAO_PATH)
	return lista.pick()
