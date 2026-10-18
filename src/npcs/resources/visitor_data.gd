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
## Aparências possíveis (sorteia uma por visita). Usado só quando "cena" está vazia.
@export var sprites: Array[Texture2D] = []
@export var tags: Array[String] = [] # "delivery", "vip", "intruder", "send_to_basement", etc.
@export var dialogos: Array[NPCDialogue] = []


func has_tag(tag_name: String) -> bool:
	return tags.has(tag_name)


func pick_visit(forced_dialogue: NPCDialogue = null, forced_sprite: Texture2D = null) -> Dictionary:
	var d: NPCDialogue = forced_dialogue
	if d == null and not dialogos.is_empty():
		d = dialogos.pick_random()
	
	return {
		"visitor": self,
		"dialogue": d,
		"nome": _sortear_nome(),
		"sprite": forced_sprite if forced_sprite else (sprites.pick_random() if not sprites.is_empty() else null)
	}


## Nome desta visita: sorteado se nome_aleatorio estiver ligado, senão o "nome" fixo.
func _sortear_nome() -> String:
	if not nome_aleatorio:
		return nome
	var lista: NameList = lista_nomes if lista_nomes else load(NOMES_PADRAO_PATH)
	return lista.pick()
