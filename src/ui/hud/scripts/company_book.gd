extends Control
## Livro de empresas da recepção: mostra 2 andares por página.
## A seta ">" passa para a próxima página e a "<" volta uma; nas pontas, dá a volta no livro.


@export var directory: CompanyDirectory

var _page: int = 0

@onready var _columns: Array[Control] = [%LeftColumn, %RightColumn]


func _ready() -> void:
	%NextButton.pressed.connect(next_page)
	%PrevButton.pressed.connect(previous_page)
	_show_page()


func page_count() -> int:
	if directory == null or directory.empresas.is_empty():
		return 1
	return ceili(directory.empresas.size() / 2.0)


func next_page() -> void:
	Audio.play_sfx(Audio.PASSANDO_PAGINA)
	_page = (_page + 1) % page_count()
	_show_page()


func previous_page() -> void:
	Audio.play_sfx(Audio.PASSANDO_PAGINA)
	_page = (_page - 1 + page_count()) % page_count()
	_show_page()


func _show_page() -> void:
	for i in _columns.size():
		var index: int = _page * 2 + i
		var has_company: bool = directory != null and index < directory.empresas.size()
		_columns[i].visible = has_company
		if has_company:
			_fill_column(_columns[i], directory.empresas[index])


func _fill_column(column: Control, company: CompanyData) -> void:
	column.get_node("Title").text = company.setor
	# Sem logo próprio, o espaço vai para o texto (o livro é pequeno em 640x360)
	var logo: TextureRect = column.get_node("Logo")
	logo.texture = company.logo
	logo.visible = company.logo != null
	column.get_node("Floor").text = company.andar_texto()
	column.get_node("Description").text = company.descricao
