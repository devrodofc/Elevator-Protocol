class_name MartaRule
extends Resource
## Uma regra que a Marta dita no meio do expediente.
## Pode ser só narrativa (andar_pedido = 0) ou mudar o destino correto de quem pedir um andar.

const SEM_EFEITO: int = 0
const NEGAR: int = 999
const SUBSOLO: int = -1

## O que a Marta fala ao entrar.
@export_multiline var fala: String = ""
## Texto curto anotado na prancheta de regras.
@export var texto_prancheta: String = ""

@export_group("Efeito no jogo")
## Andar pedido pelo visitante que esta regra afeta. 0 = regra só narrativa.
@export var andar_pedido: int = SEM_EFEITO
## Para onde o visitante deve ir: andar, -1 = subsolo, 999 = negar acesso.
@export var andar_destino: int = NEGAR
## Falas que se encaixam nesta regra (pedem o andar_pedido). Uma delas é usada para garantir
## que pelo menos um visitante do dia caia na regra. Sem "= []": com ele o editor descarta a lista.
@export var falas_caso: Array[NPCDialogue]


func tem_efeito() -> bool:
	return andar_pedido != SEM_EFEITO


## Andar correto depois de aplicar esta regra ao pedido do visitante.
func aplicar(andar_solicitado: int, andar_atual: int) -> int:
	if tem_efeito() and andar_solicitado == andar_pedido:
		return andar_destino
	return andar_atual
