class_name TutorialStep
extends Resource
## Um passo do tutorial: uma fala da narração ou de um personagem.

enum Destaque { NENHUM, FALA, LIVRO, REGRAS, CRACHA, PAINEL }

## Quem fala. Vazio = narração (tela escura, sem personagem).
@export var falante: String = ""
@export_multiline var texto: String = ""
## Elemento da recepção que pisca enquanto a fala aparece.
@export var destaque: Destaque = Destaque.NENHUM
