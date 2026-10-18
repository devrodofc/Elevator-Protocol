class_name CompanyData
extends Resource
## Um andar/setor do prédio, mostrado no livro de empresas da recepção.

## Número do andar. Use -1 para o subsolo.
@export var andar: int = 1
@export var setor: String = ""
@export_multiline var descricao: String = ""
## Logo do setor (opcional). Vazio = o livro mostra só o texto.
@export var logo: Texture2D


## Texto do andar como aparece no livro: "1º andar" ou "Subsolo".
func andar_texto() -> String:
	if andar < 0:
		return "Subsolo"
	return "%dº andar" % andar
