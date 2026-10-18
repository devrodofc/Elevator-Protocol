@tool
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

@export_group("Crachá")
## Sorteia a idade entre idade_min e idade_max a cada visita. Desligado = usa "idade".
@export var idade_aleatoria: bool = false:
	set(value):
		idade_aleatoria = value
		notify_property_list_changed()
## Zero indica idade não informada.
@export_range(0, 150, 1) var idade: int = 0
@export_range(0, 150, 1) var idade_min: int = 18
@export_range(0, 150, 1) var idade_max: int = 65

## Sorteia o sexo entre as opções a cada visita. Desligado = usa "sexo".
@export var sexo_aleatorio: bool = false:
	set(value):
		sexo_aleatorio = value
		notify_property_list_changed()
@export var sexo: String = ""
@export var opcoes_sexo: PackedStringArray = ["Masculino", "Feminino"]

## Sorteia a ocupação entre as opções a cada visita. Desligado = usa "ocupacao".
@export var ocupacao_aleatoria: bool = false:
	set(value):
		ocupacao_aleatoria = value
		notify_property_list_changed()
@export var ocupacao: String = ""
@export var opcoes_ocupacao: PackedStringArray = []

## Opcional. Sem retrato, o crachá usa a textura do sprite do visitante.
@export var retrato: Texture2D


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
		"sprite": forced_sprite if forced_sprite else (sprites.pick_random() if not sprites.is_empty() else null),
		"cracha": _sortear_cracha()
	}


## Dados do crachá desta visita: cada campo usa o valor fixo ou é sorteado.
func _sortear_cracha() -> Dictionary:
	return {
		"idade": randi_range(mini(idade_min, idade_max), maxi(idade_min, idade_max)) if idade_aleatoria else idade,
		"sexo": _sortear_opcao(opcoes_sexo, sexo) if sexo_aleatorio else sexo,
		"ocupacao": _sortear_opcao(opcoes_ocupacao, ocupacao) if ocupacao_aleatoria else ocupacao,
	}


func _sortear_opcao(opcoes: PackedStringArray, padrao: String) -> String:
	return opcoes[randi() % opcoes.size()] if not opcoes.is_empty() else padrao


## Mostra no inspector só os campos do modo (fixo ou aleatório) de cada informação do crachá.
func _validate_property(property: Dictionary) -> void:
	var escondido: bool = false
	match property.name:
		"idade": escondido = idade_aleatoria
		"idade_min", "idade_max": escondido = not idade_aleatoria
		"sexo": escondido = sexo_aleatorio
		"opcoes_sexo": escondido = not sexo_aleatorio
		"ocupacao": escondido = ocupacao_aleatoria
		"opcoes_ocupacao": escondido = not ocupacao_aleatoria
	if escondido:
		property.usage = PROPERTY_USAGE_NO_EDITOR


## Nome desta visita: sorteado se nome_aleatorio estiver ligado, senão o "nome" fixo.
func _sortear_nome() -> String:
	if not nome_aleatorio:
		return nome
	var lista: NameList = lista_nomes if lista_nomes else load(NOMES_PADRAO_PATH)
	return lista.pick()
