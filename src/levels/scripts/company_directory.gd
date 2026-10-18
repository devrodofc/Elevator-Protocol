class_name CompanyDirectory
extends Resource
## Lista de andares do livro de empresas, na ordem em que aparecem (2 por página).

## Sem valor padrão "= []": com ele o editor descarta a lista salva no .tres.
@export var empresas: Array[CompanyData]
