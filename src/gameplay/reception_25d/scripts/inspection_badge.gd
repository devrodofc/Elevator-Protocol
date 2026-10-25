extends "res://src/gameplay/hud/scripts/badge_details.gd"
## Keeps the original card art/layout, without requiring a Visitor Node2D.
func set_snapshot(entry: Dictionary) -> void:
	var data: VisitorData = entry.get("visitor")
	_has_visitor = data != null
	if not _has_visitor:
		set_visitor(null)
		return
	var badge: Dictionary = entry.get("cracha", {})
	_photo.texture = entry.get("sprite")
	_name.text = _text_or_default(entry.get("nome", data.nome))
	var age: int = badge.get("idade", data.idade)
	_age.text = str(age) if age > 0 else NOT_INFORMED
	_sex.text = _text_or_default(badge.get("sexo", data.sexo))
	_occupation.text = _text_or_default(badge.get("ocupacao", data.ocupacao))
