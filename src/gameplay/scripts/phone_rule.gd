extends "res://src/gameplay/scripts/marta_rule.gd"
## Regra que chega por telefone (recepção 3D), criada em código pela história do dia.
## GUARDA: quem pedir o andar (6º) só sobe se o nome foi anunciado; os outros, negar.
## CONVIDADO: o nome anunciado sobe ao andar, acima de qualquer outra regra (final = true).
## Fica nas regras ativas da sessão (ReceptionSession.add_extra_rule) e aparece na prancheta.

enum Modo { GUARDA, CONVIDADO }

var modo: Modo = Modo.GUARDA
var andar: int = 6
## CONVIDADO: nome exato da visita (o mesmo do balão e do crachá).
var nome: String = ""
## GUARDA: nomes já anunciados (os CONVIDADO se registram aqui).
var convidados: Array[String] = []
## Lida pelo RuleValidator: regras finais valem depois de todas as outras.
var final: bool = false


static func guarda(texto: String, numero_andar: int = 6) -> Resource:
	var regra = load("res://src/gameplay/scripts/phone_rule.gd").new()
	regra.modo = Modo.GUARDA
	regra.andar = numero_andar
	regra.texto_prancheta = texto
	return regra


static func convidado(guarda_do_andar: Resource, nome_convidado: String, texto: String) -> Resource:
	var regra = load("res://src/gameplay/scripts/phone_rule.gd").new()
	regra.modo = Modo.CONVIDADO
	regra.andar = guarda_do_andar.andar
	regra.nome = nome_convidado
	regra.final = true
	regra.texto_prancheta = texto
	if not guarda_do_andar.convidados.has(nome_convidado):
		guarda_do_andar.convidados.append(nome_convidado)
	return regra


## Sem efeito por andar: só aplicar_visita (precisa do nome).
func tem_efeito() -> bool:
	return false


func aplicar(_andar_solicitado: int, andar_atual: int) -> int:
	return andar_atual


func aplicar_visita(visita: Dictionary, andar_solicitado: int, andar_atual: int) -> int:
	var quem: String = str(visita.get("nome", ""))
	match modo:
		Modo.GUARDA:
			# Só quem ainda está indo para o andar (Seu Tião, entregas etc. já têm outro destino).
			if andar_solicitado == andar and andar_atual == andar:
				return andar if convidados.has(quem) else NEGAR
		Modo.CONVIDADO:
			if andar_solicitado == andar and quem == nome:
				return andar
	return andar_atual
