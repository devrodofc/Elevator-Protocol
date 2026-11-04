extends Node
## A plain sheet of paper on the desk with who may go up to the 6th floor (the names announced by phone).
## Kept apart from Marta's clipboard so the clipboard only has her rules. Built from simple meshes.

const Interactable = preload("res://src/gameplay/reception_25d/scripts/desk_interactable.gd")
const FONT = preload("res://assets/fonts/pixeloid_sans.ttf")
const FONT_BOLD = preload("res://assets/fonts/pixeloid_sans_bold.ttf")
const SIZE := Vector2(0.36, 0.27)
const INK := Color(0.1, 0.16, 0.45)

var body: Interactable
var _sheet: MeshInstance3D
var _title: Label3D
var _rule: Label3D
var _names: Label3D
var _pulse: float = 0.0
var _t: float = 0.0
var _list: Array[String] = []


func build(room: Node3D, desk_top: float) -> void:
	body = Interactable.new()
	body.name = "SixthFloorNote"
	room.get_node("ReceptionDesk").add_child(body)
	# Close to the player, a little crooked, leaning toward the camera.
	body.position = Vector3(0.2, desk_top + 0.1, 1.52)
	body.basis = Basis(Vector3.UP, deg_to_rad(-4)) * Basis(Vector3.RIGHT, deg_to_rad(50))
	var visual := Node3D.new()
	body.add_child(visual)
	var face := Node3D.new()
	face.rotation = Vector3(-PI * 0.5, 0, 0)
	visual.add_child(face)
	_sheet = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SIZE
	_sheet.mesh = quad
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.96, 0.94, 0.86)
	paper.roughness = 1.0
	_sheet.material_override = paper
	face.add_child(_sheet)
	# A piece of tape at the top.
	var tape := MeshInstance3D.new()
	var tape_mesh := QuadMesh.new()
	tape_mesh.size = Vector2(0.09, 0.03)
	tape.mesh = tape_mesh
	tape.position = Vector3(0, SIZE.y * 0.5 - 0.005, 0.001)
	var tape_mat := StandardMaterial3D.new()
	tape_mat.albedo_color = Color(0.92, 0.88, 0.62, 0.85)
	tape_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tape.material_override = tape_mat
	face.add_child(tape)
	_title = _label(face, FONT_BOLD, 50, Color(0.15, 0.15, 0.15), Vector3(0, 0.105, 0.002))
	_title.text = "6º ANDAR · PRESIDÊNCIA"
	_rule = _label(face, FONT, 36, Color(0.22, 0.22, 0.22), Vector3(0, 0.062, 0.002))
	_names = _label(face, FONT_BOLD, 46, INK, Vector3(0, 0.02, 0.002))
	_names.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.configure(visual, Vector3(SIZE.x, 0.03, SIZE.y))
	set_rule("")


func _label(parent: Node3D, font: Font, size: int, color: Color, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.font = font
	label.font_size = size
	label.pixel_size = 0.00042
	label.modulate = color
	label.outline_size = 0
	label.shaded = true
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	label.width = SIZE.x / 0.00042 * 0.92
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = at
	parent.add_child(label)
	return label


## The rule line under the title ("" = nothing written yet).
func set_rule(text: String) -> void:
	_rule.text = text
	_refresh()


## A name written by hand after a call.
func add_name(name: String) -> void:
	if not _list.has(name):
		_list.append(name)
	_refresh()
	pulse()


func _refresh() -> void:
	var lines: PackedStringArray = []
	for name in _list:
		lines.append("✓ " + name if FONT.has_char("✓".unicode_at(0)) else "- " + name)
	_names.text = "\n".join(lines) if not lines.is_empty() else ("(ninguém ainda)" if not _rule.text.is_empty() else "")


## Draws the eye to the sheet for a moment (new rule or name).
func pulse(seconds: float = 2.5) -> void:
	_pulse = seconds


func _process(delta: float) -> void:
	_t += delta
	if _sheet == null:
		return
	var mat := _sheet.material_override as StandardMaterial3D
	var glow := 0.0
	if _pulse > 0.0:
		_pulse -= delta
		glow = 0.5 + 0.5 * sin(_t * 8.0)
	if body.hovered:
		glow = maxf(glow, 0.6)
	# A little self-light so the paper reads as paper (not grey) under the dim office light.
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.95, 0.8).lerp(Color(1.0, 0.85, 0.4), clampf(glow, 0.0, 1.0))
	mat.emission_energy_multiplier = 0.18 + glow * 0.35
