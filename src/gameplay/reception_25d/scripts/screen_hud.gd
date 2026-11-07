extends CanvasLayer
## Sharp 2D HUD of the 3D reception (drawn at window resolution, above the 3D image):
## status bar, day/progress, tooltip of the hovered object, controls hint and the tutorial narration.

const FONT = preload("res://assets/fonts/pixeloid_sans.ttf")
const FONT_BOLD = preload("res://assets/fonts/pixeloid_sans_bold.ttf")

## desk_service status text -> what the player reads.
const STATUS := {
	"Aguarde o visitante": "Aguarde o próximo visitante...",
	"Escolha · X: recusar · OK": "Escolha o andar no painel  ·  X nega o acesso  ·  Confirmar envia",
	"Marta está falando": "A Marta está falando  ·  [Espaço] continuar",
	"Registrado: correto": "",
	"Registrado: incorreto": "",
}

var status_label: Label
var day_label: Label
var tooltip: Label
var hint: Label
var skip_label: Label
var narration: ColorRect
var narration_label: Label
var narration_hint: Label
var _status_box: PanelContainer
var _tooltip_box: PanelContainer
var _narration_tween: Tween
var _narration_done: bool = false
var _advance: bool = false
var _hint_time: float = 14.0
var warnings_label: Label
var wrong_dispatches_label: Label
var _call_box: PanelContainer
var _call_title: Label
var _call_text: Label
var _call_skip: bool = false
var _toast_box: PanelContainer
var _toast: Label
var _toast_time: float = 0.0
var _report: ColorRect
var _report_text: Label
var _report_done: bool = false


func _ready() -> void:
	layer = 6
	_status_box = _pill(Color(0.03, 0.03, 0.05, 0.72))
	add_child(_status_box)
	status_label = _label(FONT, 9, Color(0.93, 0.9, 0.82))
	_status_box.add_child(status_label)
	day_label = _label(FONT_BOLD, 9, Color(0.93, 0.88, 0.75))
	day_label.position = Vector2(8, 6)
	add_child(day_label)
	_tooltip_box = _pill(Color(0.05, 0.04, 0.03, 0.85))
	add_child(_tooltip_box)
	tooltip = _label(FONT_BOLD, 8, Color(1.0, 0.92, 0.6))
	_tooltip_box.add_child(tooltip)
	_tooltip_box.hide()
	hint = _label(FONT, 7, Color(0.8, 0.8, 0.8, 0.85))
	hint.text = "[A/D ou ←/→] olhar ao redor   [Clique] usar   [Espaço] falas   [Esc] pausa"
	hint.position = Vector2(8, 20)
	add_child(hint)
	skip_label = _label(FONT, 8, Color(0.85, 0.85, 0.85))
	skip_label.text = "Pular tutorial [Esc]"
	skip_label.hide()
	add_child(skip_label)
	narration = ColorRect.new()
	narration.color = Color(0.0, 0.0, 0.0, 1.0)
	narration.set_anchors_preset(Control.PRESET_FULL_RECT)
	narration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narration.hide()
	add_child(narration)
	narration_label = _label(FONT, 12, Color(0.9, 0.9, 0.88))
	narration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	narration_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	narration_label.offset_left = 90
	narration_label.offset_right = -90
	narration.add_child(narration_label)
	narration_hint = _label(FONT, 8, Color(0.6, 0.6, 0.6))
	narration_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	narration_hint.offset_left = -110
	narration_hint.offset_top = -22
	narration_hint.offset_right = -10
	narration_hint.offset_bottom = -8
	narration_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	narration.add_child(narration_hint)
	warnings_label = _label(FONT_BOLD, 8, Color(1.0, 0.45, 0.35))
	warnings_label.position = Vector2(8, 32)
	add_child(warnings_label)
	wrong_dispatches_label = _label(FONT_BOLD, 8, Color(1.0, 0.45, 0.35))
	wrong_dispatches_label.position = Vector2(8, 44)
	add_child(wrong_dispatches_label)
	set_wrong_dispatches(0)
	_call_box = _pill(Color(0.06, 0.02, 0.02, 0.88))
	_call_box.position = Vector2(8, 58)
	var call_list := VBoxContainer.new()
	call_list.add_theme_constant_override("separation", 1)
	call_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_call_box.add_child(call_list)
	_call_title = _label(FONT_BOLD, 8, Color(1.0, 0.6, 0.45))
	call_list.add_child(_call_title)
	_call_text = _label(FONT, 9, Color(0.95, 0.92, 0.86))
	_call_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_call_text.custom_minimum_size = Vector2(205, 0)
	call_list.add_child(_call_text)
	var call_hint := _label(FONT, 6, Color(0.7, 0.7, 0.7))
	call_hint.text = "[Espaço] próxima fala"
	call_list.add_child(call_hint)
	_call_box.hide()
	add_child(_call_box)
	_toast_box = _pill(Color(0.35, 0.03, 0.02, 0.9))
	_toast = _label(FONT_BOLD, 9, Color(1.0, 0.92, 0.85))
	_toast_box.add_child(_toast)
	_toast_box.hide()
	add_child(_toast_box)
	_report = ColorRect.new()
	_report.color = Color(0.02, 0.02, 0.03, 0.94)
	_report.set_anchors_preset(Control.PRESET_FULL_RECT)
	_report.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_report.hide()
	add_child(_report)
	_report_text = _label(FONT, 11, Color(0.92, 0.9, 0.84))
	_report_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_report_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_report_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_report_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report_text.offset_left = 110
	_report_text.offset_right = -110
	_report.add_child(_report_text)
	set_status("")


func _pill(color: Color) -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


func _label(font: Font, size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func set_status(text: String) -> void:
	var shown: String = STATUS.get(text, text)
	if text.begins_with("Confirmar "):
		var what := text.trim_prefix("Confirmar ").trim_suffix(" em OK")
		shown = "Aperte Confirmar para %s" % ("negar o acesso" if what == "recusa" else
			("mandar ao subsolo" if what == "-1" else "mandar ao %sº andar" % what))
	status_label.text = shown
	_status_box.visible = not shown.is_empty()


func set_day(text: String) -> void:
	day_label.text = text


func set_tooltip(text: String) -> void:
	tooltip.text = text
	_tooltip_box.visible = not text.is_empty()


func _process(delta: float) -> void:
	var rect := get_viewport().get_visible_rect()
	_status_box.reset_size()
	_status_box.position = Vector2((rect.size.x - _status_box.size.x) * 0.5, rect.size.y - _status_box.size.y - 6)
	if _tooltip_box.visible:
		_tooltip_box.reset_size()
		var mouse := get_viewport().get_mouse_position()
		var at := mouse + Vector2(10, -18)
		at.x = clampf(at.x, 4, rect.size.x - _tooltip_box.size.x - 4)
		at.y = clampf(at.y, 4, rect.size.y - _tooltip_box.size.y - 4)
		_tooltip_box.position = at
	skip_label.position = Vector2(rect.size.x - 100, 6)
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast_box.reset_size()
		_toast_box.position = Vector2((rect.size.x - _toast_box.size.x) * 0.5, rect.size.y * 0.62)
		_toast_box.modulate.a = clampf(_toast_time * 2.0, 0.0, 1.0)
		_toast_box.visible = _toast_time > 0.0
	if _hint_time > 0.0:
		_hint_time -= delta
		hint.modulate.a = clampf(_hint_time / 2.0, 0.0, 1.0)


## Dark screen with typed text (tutorial). Space completes, then continues.
func show_narration(text: String, chars_per_second: float = 40.0) -> void:
	narration.show()
	narration.modulate.a = 1.0
	narration_label.text = text
	narration_label.visible_ratio = 0.0
	narration_hint.text = "[Espaço] acelerar"
	_narration_done = false
	_advance = false
	if _narration_tween:
		_narration_tween.kill()
	_narration_tween = create_tween()
	_narration_tween.tween_property(narration_label, "visible_ratio", 1.0, text.length() / chars_per_second)
	_narration_tween.finished.connect(_typed)
	Audio.start_loop(Audio.DIGITANDO)
	while not _advance and is_inside_tree():
		await get_tree().process_frame


func _typed() -> void:
	Audio.stop_loop()
	narration_label.visible_ratio = 1.0
	narration_hint.text = "[Espaço] continuar"
	_narration_done = true


func hide_narration(seconds: float = 0.6) -> void:
	if not narration.visible:
		return
	var fade := create_tween()
	fade.tween_property(narration, "modulate:a", 0.0, seconds)
	await fade.finished
	narration.hide()


func set_warnings(count: int, maximum: int) -> void:
	warnings_label.text = "Advertências: %d/%d" % [count, maximum] if count > 0 else ""


## Short message in the middle of the screen.
func toast(text: String, seconds: float = 3.0) -> void:
	_toast.text = text
	_toast_time = seconds
	_toast_box.show()


## Phone call box (top left, under the day). Types the line, then waits for Space or its reading time.
## Returns false if the box was closed from outside.
func show_call(caller: String, text: String, spooky: bool = false) -> bool:
	_call_box.show()
	_call_title.text = "TELEFONE · " + caller
	_call_title.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2) if spooky else Color(1.0, 0.6, 0.45))
	_call_text.text = text
	_call_text.visible_ratio = 0.0
	_call_skip = false
	var typing := create_tween()
	typing.tween_property(_call_text, "visible_ratio", 1.0, text.length() / 45.0)
	while typing.is_running() and not _call_skip and is_inside_tree():
		await get_tree().process_frame
	typing.kill()
	_call_text.visible_ratio = 1.0
	_call_skip = false
	var hold := maxf(2.5, text.length() * 0.06)
	while hold > 0.0 and not _call_skip and is_inside_tree():
		hold -= get_process_delta_time()
		await get_tree().process_frame
	_call_skip = false
	return is_inside_tree() and _call_box.visible


func hide_call() -> void:
	_call_box.hide()


## Full-screen shift report; Space (or 9 s) continues.
func show_report(text: String) -> void:
	_report_text.text = text
	_report.modulate.a = 0.0
	_report.show()
	_report_done = false
	var fade := create_tween()
	fade.tween_property(_report, "modulate:a", 1.0, 0.5)
	var time := 0.0
	while not _report_done and time < 9.0 and is_inside_tree():
		time += get_process_delta_time()
		await get_tree().process_frame


func _unhandled_input(event: InputEvent) -> void:
	if _report.visible and event.is_action_pressed("ui_accept"):
		_report_done = true
		get_viewport().set_input_as_handled()
		return
	if _call_box.visible and event.is_action_pressed("ui_accept"):
		_call_skip = true
		get_viewport().set_input_as_handled()
		return
	if not narration.visible or not event.is_action_pressed("ui_accept"):
		return
	get_viewport().set_input_as_handled()
	if not _narration_done:
		if _narration_tween:
			_narration_tween.kill()
		_typed()
	else:
		_advance = true


func set_wrong_dispatches(count: int) -> void:
	wrong_dispatches_label.text = "Encaminhamentos incorretos: %d/3" % count if count > 0 else ""
