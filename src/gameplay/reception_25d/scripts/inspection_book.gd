extends "res://src/gameplay/hud/scripts/company_book.gd"
## Same real directory and cyclic navigation; no detailed descriptions in 2.5D.
func _fill_column(column: Control, company: CompanyData) -> void:
	super._fill_column(column, company)
	column.get_node("Description").text = ""
	column.get_node("Description").hide()
