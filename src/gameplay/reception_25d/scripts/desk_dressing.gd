extends Node
## Dresses the I3 desk objects with the team's 2D HUD art (no new assets): the elevator panel uses the
## original plate and button sprites (pressed state, light, click sound), the book, clipboard and badge
## use their HUD pictures. Also adds the desk lamp and a small monitor. The logic (picking, selection,
## session) stays in desk_service.gd; this node only replaces visuals and reads the objects' state.

const ART := "res://src/gameplay/hud/assets/"
const FONT_BOLD = preload("res://assets/fonts/pixeloid_sans_bold.ttf")
const FONT = preload("res://assets/fonts/pixeloid_sans.ttf")
## Panel plate: 384x624 px of 4x art.
const PLATE_PX := Vector2(384, 624)
const PLATE_WIDTH: float = 0.44
## Button rectangles in plate pixels (same layout as elevator_panel.tscn).
const BUTTON_RECTS := {
	5: Rect2(56, 36, 100, 96), 6: Rect2(228, 36, 100, 96),
	3: Rect2(56, 150, 100, 96), 4: Rect2(228, 150, 100, 96),
	1: Rect2(56, 262, 100, 96), 2: Rect2(228, 262, 100, 96),
	-1: Rect2(56, 374, 100, 96), 999: Rect2(228, 374, 100, 96),
}
const CONFIRM_RECT := Rect2(56, 491, 272, 89)
## Counter height in the game (the experimental room uses 1.15 m): lower, so the visitors' chibi
## bodies show above it and the player looks down at the work surface.
const DESK_TOP: float = 0.93

var presentation: Node2D
var desk: Node
var lamp: OmniLight3D
var lamp_bulb: MeshInstance3D
var monitor_label: Label3D
var monitor_sub: Label3D
var monitor_screen: MeshInstance3D
var _textures: Dictionary = {}
## Interactable -> {kind, mat: Array[StandardMaterial3D], normal, selected, quad, label, label_y, press}
var _skins: Dictionary = {}
var _highlight: String = ""
var _highlight_t: float = 0.0
var _scale: float


func dress(owner_scene: Node2D, service: Node) -> void:
	presentation = owner_scene
	desk = service
	_scale = PLATE_WIDTH / PLATE_PX.x
	var room: Node3D = presentation.get_node("RoomViewport/Room")
	var anchors: Node3D = room.get_node("ReceptionDesk/ServiceObjects")
	_dress_counter(room)
	# The player's own work surface: items lie close, under the visitor, like at a real desk.
	_place(anchors.get_node("ClipboardRest"), Vector3(-0.98, 0, 1.12), 30.0, 0.27)
	_place(anchors.get_node("BookRest"), Vector3(-0.4, 0, 1.2), 20.0, 0.24)
	_place(anchors.get_node("BadgeRest"), Vector3(0.2, 0, 1.08), 16.0, 0.18)
	_place(anchors.get_node("PanelRest"), Vector3(0.8, 0, 1.12), 48.0, PLATE_PX.y * _scale * 0.5)
	_skin_object(desk.clipboard, "rules", "rules/regras.png", Vector2(0.42, 0.547), Color("6b4a2f"))
	_skin_object(desk.book, "book", "company_book/livro.png", Vector2(0.66, 0.486), Color("4a2c1f"))
	_skin_object(desk.badge, "badge", "badge/cracha.png", Vector2(0.17, 0.364), Color(0, 0, 0, 0))
	_skin_panel(anchors.get_node("PanelRest"))
	desk.status.hide()
	_build_lamp(room)
	_build_monitor(room)


## Anchor on the counter, leaning toward the player by tilt_deg, its lower edge resting on the top.
func _place(anchor: Node3D, at: Vector3, tilt_deg: float, half_depth: float) -> void:
	var tilt := deg_to_rad(tilt_deg)
	var top: float = DESK_TOP + 0.005
	anchor.position = Vector3(at.x, top + sin(tilt) * half_depth + 0.012, at.z)
	anchor.basis = Basis(Vector3.RIGHT, tilt)


func _texture(path: String, mipmaps: bool = true) -> Texture2D:
	var key := path + str(mipmaps)
	if _textures.has(key):
		return _textures[key]
	# Runtime copy: Godot never re-imports the 2D asset as a 3D texture.
	var image: Image = (load(ART + path) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	if mipmaps:
		image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture


func _material(texture: Texture2D, emission: float = 0.0, color: Color = Color.WHITE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.albedo_color = color
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.roughness = 0.9
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission_texture = texture
		mat.emission = Color.WHITE
		mat.emission_energy_multiplier = emission
	return mat


func _quad(parent: Node3D, texture: Texture2D, size: Vector2, at: Vector3, emission: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = _material(texture, emission)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	node.material_override = mat
	parent.add_child(node)
	return node


## Hides the provisional boxes of an Interactable and returns its visual root.
func _hide_original(body: Node3D) -> Node3D:
	var root: Node3D = body.visual_root
	for child in root.get_children():
		if child is MeshInstance3D or child is Label3D:
			child.hide()
	return root


func _resize_hitbox(body: Node3D, size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	for child in body.get_children():
		if child is CollisionShape3D:
			(child.shape as BoxShape3D).size = size
			child.position = offset


## Book, clipboard and badge: a thin back (cover/board) plus the HUD picture on top.
func _skin_object(body: Node3D, kind: String, path: String, size: Vector2, back: Color) -> void:
	var root := _hide_original(body)
	var holder := Node3D.new()
	# Pictures face +Y of the (tilted) anchor: lay the quad flat, top of the picture away from the player.
	holder.rotation = Vector3(-PI * 0.5, 0, 0)
	root.add_child(holder)
	var mats: Array[StandardMaterial3D] = []
	if back.a > 0.0:
		var board := _box(root, Vector3(size.x + 0.03, 0.022, size.y + 0.03), Vector3(0, -0.012, 0), back)
		mats.append(board.material_override)
	var quad := _quad(holder, _texture(path), size, Vector3(0, 0, 0.002), 0.06)
	mats.append(quad.material_override)
	if kind == "badge":
		# Badge flips over in the air: picture on both sides.
		(quad.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	_resize_hitbox(body, Vector3(size.x + 0.04, 0.09, size.y + 0.04), body.slide_offset * 0.5)
	_skins[body] = {"kind": kind, "mats": mats, "press": 0.0}


## Elevator panel: the original plate and button sprites, sharp now that the 3D renders at full size.
func _skin_panel(anchor: Node3D) -> void:
	for child in anchor.get_children():
		if child is MeshInstance3D:
			child.hide()
	var holder := Node3D.new()
	holder.rotation = Vector3(-PI * 0.5, 0, 0)
	anchor.add_child(holder)
	var plate_size := PLATE_PX * _scale
	# Metal case behind the plate, so it reads as a real panel.
	_box(anchor, Vector3(plate_size.x + 0.03, 0.04, plate_size.y + 0.03), Vector3(0, -0.022, 0), Color("2a3034"))
	var plate := _quad(holder, _texture("Elevador/painel elevador.png"), plate_size, Vector3.ZERO, 0.12)
	plate.name = "Plate"
	for code in desk.buttons:
		_skin_button(desk.buttons[code], holder, BUTTON_RECTS[code], code)
	_skin_button(desk.confirm, holder, CONFIRM_RECT, 0)


func _skin_button(body: Node3D, holder: Node3D, rect: Rect2, code: int) -> void:
	var root := _hide_original(body)
	# The body keeps its parent (the anchor); its position follows the art layout on the plate.
	var center := (rect.position + rect.size * 0.5 - PLATE_PX * 0.5) * _scale
	body.position = Vector3(center.x, 0.0, center.y)
	root.position = Vector3.ZERO
	var face := Node3D.new()
	face.rotation = Vector3(-PI * 0.5, 0, 0)
	root.add_child(face)
	var normal: Texture2D
	var selected: Texture2D
	var text := ""
	match code:
		999:
			normal = _atlas("Elevador/painel elevador botões.png", rect)
			selected = _texture("Elevador/botão de negar.png")
		0:
			normal = _atlas("Elevador/painel elevador botões.png", rect)
			selected = _texture("Elevador/confirmar pressionado.png")
		_:
			normal = _texture("Elevador/botão elevador.png")
			selected = _texture("Elevador/botão elevador pressionado.png")
			text = "S" if code == -1 else str(code)
	var size := rect.size * _scale
	var quad := _quad(face, normal, size, Vector3(0, 0, 0.004), 0.18)
	var label: Label3D = null
	var label_y := size.y * 0.04
	if not text.is_empty():
		label = Label3D.new()
		label.text = text
		label.font = FONT_BOLD
		label.font_size = 52
		label.pixel_size = _scale * 0.95
		label.modulate = Color(0.16, 0.16, 0.16)
		label.outline_size = 0
		label.shaded = false
		label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		label.position = Vector3(0, label_y, 0.008)
		face.add_child(label)
	_resize_hitbox(body, Vector3(size.x, 0.05, size.y))
	_skins[body] = {"kind": "button", "mats": [quad.material_override], "normal": normal, "selected": selected,
		"quad": quad, "label": label, "label_y": label_y, "size": size, "press": 0.0, "code": code}
	body.activated.connect(_on_button_activated.bind(body))


func _atlas(path: String, rect: Rect2) -> Texture2D:
	var key := path + str(rect)
	if _textures.has(key):
		return _textures[key]
	var image: Image = (load(ART + path) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var region := image.get_region(Rect2i(rect))
	region.generate_mipmaps()
	var texture := ImageTexture.create_from_image(region)
	_textures[key] = texture
	return texture


func _on_button_activated(body: Node3D) -> void:
	_skins[body]["press"] = 1.0
	Audio.play_sfx(Audio.BOTAO)


## Tutorial: pulses one object red ("book", "rules", "badge", "panel"); "" clears.
func highlight(kind: String) -> void:
	_highlight = kind
	_highlight_t = 0.0


func _process(delta: float) -> void:
	_highlight_t += delta
	var pulse := 0.5 + 0.5 * sin(_highlight_t * 6.0)
	for body in _skins:
		if not is_instance_valid(body):
			continue
		var skin: Dictionary = _skins[body]
		var lit: bool = body.hovered
		var sel: bool = body.selected
		var available: bool = body.available
		skin["press"] = maxf(0.0, skin["press"] - delta * 5.0)
		var highlighted: bool = (_highlight == skin["kind"]) or (_highlight == "panel" and skin["kind"] == "button")
		var glow: float = 0.0
		if lit:
			glow = 0.55
		if highlighted:
			glow = maxf(glow, 0.25 + 0.6 * pulse)
		if skin["kind"] == "button":
			_update_button(skin, sel, available, glow, highlighted)
		else:
			for mat in skin["mats"]:
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.25, 0.2) if highlighted else Color(1.0, 0.9, 0.6)
				mat.emission_energy_multiplier = 0.06 + glow * 0.5
				if mat.emission_texture == null:
					mat.emission_energy_multiplier = glow * 0.25


func _update_button(skin: Dictionary, sel: bool, available: bool, glow: float, highlighted: bool) -> void:
	var quad: MeshInstance3D = skin["quad"]
	var mat: StandardMaterial3D = quad.material_override
	var size: Vector2 = skin["size"]
	var pressed: bool = sel or skin["press"] > 0.0
	var texture: Texture2D = skin["selected"] if pressed else skin["normal"]
	if mat.albedo_texture != texture:
		mat.albedo_texture = texture
		mat.emission_texture = texture
		# Pressed sprite is shorter: keep it on the base, as the 2D button does.
		var tex_size := texture.get_size() * _scale
		if skin["code"] in [0]:
			tex_size = Vector2(size.x, size.x * texture.get_size().y / texture.get_size().x)
		(quad.mesh as QuadMesh).size = tex_size
		quad.position.y = (tex_size.y - size.y) * 0.5 if pressed else 0.0
	# Always in front of the plate (z 0); pressed sits lower, almost flush.
	quad.position.z = 0.0015 if pressed else 0.006
	var label: Label3D = skin["label"]
	if label:
		label.position.y = (skin["label_y"] - size.y * 0.09) if pressed else skin["label_y"]
		label.position.z = quad.position.z + 0.004
	var dim := 1.0 if available or sel else 0.62
	mat.albedo_color = Color(dim, dim, dim)
	mat.emission = Color(1.0, 0.3, 0.25) if highlighted else (Color(1.0, 0.92, 0.55) if (glow > 0.0 or sel) else Color.WHITE)
	mat.emission_energy_multiplier = 0.18 * dim + glow * 0.7 + (0.35 if sel else 0.0)


func _dress_counter(room: Node3D) -> void:
	# Only the inside of the HUD desk picture: its outline would repeat as stripes on the counter.
	var wood := _atlas("main_hud/mesa.png", Rect2(260, 90, 2100, 480))
	var top: MeshInstance3D = room.get_node("ReceptionDesk/Countertop")
	top.position.y = DESK_TOP - 0.075
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = wood
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = 0.55
	top.material_override = mat
	var body: MeshInstance3D = room.get_node("ReceptionDesk/Desk")
	body.scale.y = (DESK_TOP - 0.15) / 1.0
	body.position.y = (DESK_TOP - 0.15) * 0.5
	var dark := mat.duplicate() as StandardMaterial3D
	dark.albedo_color = Color(0.42, 0.3, 0.24)
	body.material_override = dark
	# Receptionist's work surface, from the counter to the player: fills the lower part of the view.
	var work := MeshInstance3D.new()
	var work_mesh := BoxMesh.new()
	work_mesh.size = Vector3(4.4, 0.15, 1.5)
	work.mesh = work_mesh
	work.position = Vector3(0, DESK_TOP - 0.075, 1.9)
	work.material_override = mat
	room.get_node("ReceptionDesk").add_child(work)
	# Front edge of the counter: a darker strip where the visitor side begins.
	_box(room.get_node("ReceptionDesk"), Vector3(4.4, 0.012, 0.05), Vector3(0, DESK_TOP + 0.006, 0.08), Color("4a2e1d"))


func _build_lamp(room: Node3D) -> void:
	var desk_node: Node3D = room.get_node("ReceptionDesk")
	# Banker's lamp at the back-left corner of the work surface, shade over the papers.
	var base := Vector3(-1.7, DESK_TOP + 0.005, 0.75)
	var lamp_root := Node3D.new()
	lamp_root.position = base
	lamp_root.rotation.y = deg_to_rad(-25)
	desk_node.add_child(lamp_root)
	_box(lamp_root, Vector3(0.2, 0.03, 0.16), Vector3(0, 0.015, 0), Color("2a2622"))
	_box(lamp_root, Vector3(0.025, 0.34, 0.025), Vector3(0, 0.2, 0), Color("b59a5a"))
	_box(lamp_root, Vector3(0.42, 0.09, 0.15), Vector3(0.12, 0.4, 0.05), Color("1f4d34"))
	lamp_bulb = _box(lamp_root, Vector3(0.36, 0.015, 0.1), Vector3(0.12, 0.35, 0.05), Color(1.0, 0.86, 0.6), 3.0)
	lamp = OmniLight3D.new()
	lamp.name = "DeskLamp"
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 0.75
	lamp.omni_range = 3.6
	lamp.omni_attenuation = 1.3
	lamp.shadow_enabled = true
	lamp.position = Vector3(-1.45, DESK_TOP + 0.85, 0.7)
	desk_node.add_child(lamp)
	# Soft fill from behind the player so the visitor's face reads.
	var fill := OmniLight3D.new()
	fill.name = "FaceFill"
	fill.light_color = Color(0.85, 0.88, 1.0)
	fill.light_energy = 0.55
	fill.omni_range = 6.0
	fill.position = Vector3(0.4, 2.1, 1.0)
	desk_node.add_child(fill)


## A small CRT-like monitor at the right corner: shift clock and system messages (the director writes).
func _build_monitor(room: Node3D) -> void:
	var desk_node: Node3D = room.get_node("ReceptionDesk")
	var holder := Node3D.new()
	holder.position = Vector3(1.55, DESK_TOP + 0.005, 0.72)
	holder.rotation = Vector3(0, deg_to_rad(-32), 0)
	desk_node.add_child(holder)
	_box(holder, Vector3(0.12, 0.08, 0.12), Vector3(0, 0.04, 0), Color("22282b"))
	_box(holder, Vector3(0.5, 0.38, 0.32), Vector3(0, 0.3, -0.04), Color("30383c"))
	monitor_screen = _box(holder, Vector3(0.42, 0.3, 0.01), Vector3(0, 0.31, 0.125), Color(0.05, 0.16, 0.1), 0.8)
	monitor_label = _screen_label(holder, Vector3(0, 0.36, 0.132), 30)
	monitor_sub = _screen_label(holder, Vector3(0, 0.27, 0.132), 16)


func _screen_label(holder: Node3D, at: Vector3, size: int) -> Label3D:
	var label := Label3D.new()
	label.font = FONT
	label.font_size = size
	label.pixel_size = 0.0026
	label.modulate = Color(0.45, 1.0, 0.6)
	label.outline_size = 0
	label.shaded = false
	label.position = at
	label.width = 150
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	holder.add_child(label)
	return label


func set_monitor(text: String, sub: String = "", color: Color = Color(0.45, 1.0, 0.6)) -> void:
	if monitor_label == null:
		return
	monitor_label.text = text
	monitor_sub.text = sub
	monitor_label.modulate = color
	monitor_sub.modulate = color
	var screen := monitor_screen.material_override as StandardMaterial3D
	screen.emission = color.darkened(0.82)
	screen.albedo_color = color.darkened(0.85)
