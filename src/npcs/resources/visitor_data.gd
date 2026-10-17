class_name VisitorData
extends Resource

@export var id: String = ""
@export var nome: String = ""
@export var cena: PackedScene # Instância com arte/animação em Pixel Art
@export var tags: Array[String] = [] # "delivery", "vip", "intruder", "send_to_basement", etc.
@export var dialogos: Array[NPCDialogue] = []


func has_tag(tag_name: String) -> bool:
	return tags.has(tag_name)


func pick_visit(forced_dialogue: NPCDialogue = null) -> Dictionary:
	var d: NPCDialogue = forced_dialogue
	if d == null and not dialogos.is_empty():
		d = dialogos.pick_random()
	
	return {
		"visitor": self,
		"dialogue": d
	}
