extends CanvasLayer
## Transição de cena global (autoload "SceneTransition"):
## escurece a tela, mostra um título opcional (ex.: "Dia 1"), troca a cena e clareia de novo.
##   SceneTransition.transition_to("res://src/gameplay/reception/scenes/reception.tscn", "Dia 1")

## Emitido quando a nova cena já está totalmente visível.
signal finished

@export var fade_time: float = 0.6
@export var title_time: float = 1.6

var _busy: bool = false

@onready var _fade: ColorRect = %Fade
@onready var _title: Label = %Title


func _ready() -> void:
	_fade.visible = false
	_title.modulate.a = 0.0


func is_busy() -> bool:
	return _busy


func transition_to(scene_path: String, title: String = "") -> void:
	if _busy:
		return
	_busy = true
	_fade.visible = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP # bloqueia cliques durante a troca
	_fade.color.a = 0.0
	_title.text = title
	_title.modulate.a = 0.0

	await _tween_property(_fade, "color:a", 1.0, fade_time)

	if not title.is_empty():
		await _tween_property(_title, "modulate:a", 1.0, fade_time)
		await get_tree().create_timer(title_time).timeout
		await _tween_property(_title, "modulate:a", 0.0, fade_time)

	get_tree().change_scene_to_file(scene_path)
	# Espera a cena nova entrar na árvore antes de clarear
	await get_tree().process_frame
	await get_tree().process_frame

	await _tween_property(_fade, "color:a", 0.0, fade_time)
	_fade.visible = false
	_busy = false
	finished.emit()


func _tween_property(target: Object, property: String, value: Variant, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(target, property, value, duration)
	await tween.finished
