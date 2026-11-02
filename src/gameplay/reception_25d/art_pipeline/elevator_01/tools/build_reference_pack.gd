extends SceneTree
## Developer utility. Run in a temporary project copy; never attached to gameplay.
## Without --render-references: templates + UV audit (headless).
## With --render-references: also captures the real 640x360 room and guide sheets.

const BASE := "res://src/gameplay/reception_25d/art_pipeline/elevator_01/"
const TEMPLATES := {
	"ep_e01_door_left_albedo_template.png": Vector2i(36, 86),
	"ep_e01_door_right_albedo_template.png": Vector2i(36, 86),
	"ep_e01_display_albedo_template.png": Vector2i(38, 12),
	"ep_e01_metal_tile_albedo_template.png": Vector2i(16, 16),
	"ep_e01_floor_tile_albedo_template.png": Vector2i(16, 16),
}

var scene: Node
var camera: Camera3D
var viewport: SubViewport
var elevator: Node3D
var overlay: Control
var report: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for filename in TEMPLATES:
		var size: Vector2i = TEMPLATES[filename]
		var image := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
		image.fill(Color(0.5, 0.5, 0.5)) # Neutral canvas, not an art palette.
		assert(image.save_png(BASE + "templates/" + filename) == OK)
	scene = load("res://src/gameplay/reception_25d/scenes/reception.tscn").instantiate()
	root.add_child(scene)
	viewport = scene.get_node("RoomViewport")
	camera = scene.get_node("RoomViewport/Room/ReceptionCamera")
	elevator = scene.get_node("RoomViewport/Room/Elevators/Elevator01")
	camera.set_process(false)
	report["godot"] = Engine.get_version_info().string
	report["purpose"] = "Technical guidance only; existing provisional art, not final art."
	report["uv_samples"] = {}
	for path in ["DoorAssembly/LeftPanel/PixelFaceLeft", "VisualDetails/PixelDisplay", "FrameLeft", "Cabin/Floor", "Cabin/WallLeft", "DoorAssembly/RecessBack"]:
		var mesh: PrimitiveMesh = elevator.get_node(path).mesh
		var arrays := mesh.get_mesh_arrays()
		var samples: Array = []
		for index in arrays[Mesh.ARRAY_VERTEX].size():
			samples.append({"vertex": str(arrays[Mesh.ARRAY_VERTEX][index]),
				"normal": str(arrays[Mesh.ARRAY_NORMAL][index]),
				"uv": str(arrays[Mesh.ARRAY_TEX_UV][index])})
		report.uv_samples[path] = {"size": str(mesh.size), "vertices": samples}
	if "--render-references" in OS.get_cmdline_user_args():
		assert(DisplayServer.get_name() != "headless", "Use a real rendering driver for references")
		await _render_references()
	var file := FileAccess.open(BASE + "references/measurements.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	scene.queue_free()
	await process_frame
	print("REFERENCE_PACK_OK templates=5; render=", "--render-references" in OS.get_cmdline_user_args())
	quit()


func _label(parent: Node, text: String, position: Vector2, font_size: int = 12) -> Label:
	var label := Label.new()
	label.position = position
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label


func _new_overlay(title: String) -> void:
	if is_instance_valid(overlay):
		overlay.free()
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(overlay)
	_label(overlay, "REFERÊNCIA TÉCNICA / ARTE PROVISÓRIA", Vector2(8, 5))
	_label(overlay, title, Vector2(8, 23))


func _callout(number: String, local_point: Vector3, label_position: Vector2, text: String) -> void:
	var target := camera.unproject_position(elevator.to_global(local_point))
	var line := Line2D.new()
	line.width = 1.0
	line.default_color = Color(1.0, 0.85, 0.3)
	line.points = PackedVector2Array([label_position + Vector2(0, 16), target])
	overlay.add_child(line)
	_label(overlay, number + " " + text, label_position)
	_label(overlay, number, target, 11)


func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	assert(image.get_size() == Vector2i(640, 360))
	assert(image.save_png(BASE + "references/" + filename) == OK)


func _projected_size(path: String) -> Vector2:
	var node: MeshInstance3D = elevator.get_node(path)
	var size: Vector2 = node.mesh.size
	var bounds := Rect2()
	var first := true
	for x in [-0.5, 0.5]:
		for y in [-0.5, 0.5]:
			var point := camera.unproject_position(node.to_global(Vector3(x * size.x, y * size.y, 0)))
			if first:
				bounds = Rect2(point, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)
	return bounds.size


func _render_references() -> void:
	camera.rotation.y = deg_to_rad(-55.0)
	_new_overlay("Posto normal: limite direito; captura nativa 640×360")
	report["projected_bounds_at_reception_right_limit_px"] = {
		"left_door": str(_projected_size("DoorAssembly/LeftPanel/PixelFaceLeft")),
		"display": str(_projected_size("VisualDetails/PixelDisplay")),
		"note": "Geometric bounding boxes; do not account for occlusion by desk/frame.",
	}
	await _capture("ref_reception_closed_640x360.png")
	elevator.open()
	await create_timer(1.2).timeout
	await _capture("ref_reception_open_640x360.png")
	elevator.reset_closed()
	camera.global_position = elevator.to_global(Vector3(0, 1.6, 3.2))
	camera.look_at(elevator.to_global(Vector3(0, 1.6, -0.6)))
	_new_overlay("Frente aproximada; câmera reposicionada só nesta captura")
	_callout("1", Vector3(-0.545, 1.3, -0.576), Vector2(15, 170), "porta esq./dir.")
	_callout("2", Vector3(-1.2, 2.0, 0.325), Vector2(15, 85), "moldura / metal")
	_callout("3", Vector3(0, 2.7, 0.424), Vector2(420, 72), "visor 0,76 × 0,24 m")
	_callout("4", Vector3(0, 3.05, 0.335), Vector2(420, 50), "placa + Label3D")
	_callout("5", Vector3(0, 0.003, 0.24), Vector2(420, 310), "soleira / frisos")
	await _capture("ref_surface_map_front_640x360.png")
	elevator.open()
	await create_timer(1.2).timeout
	camera.global_position = elevator.to_global(Vector3(0.55, 1.8, -0.85))
	camera.look_at(elevator.to_global(Vector3(-0.25, 1.15, -3.15)))
	_new_overlay("Cabine aberta; materiais e luzes atuais, sem retoque")
	_callout("6", Vector3(-0.3, 1.8, -3.24), Vector2(25, 75), "fundo / metal")
	_callout("7", Vector3(-1.14, 1.45, -2.0), Vector2(20, 160), "lateral / metal")
	_callout("8", Vector3(0, 0, -3.0), Vector2(420, 306), "piso / tile")
	_callout("9", Vector3(0, 0.6, -3.2), Vector2(420, 230), "lambril / cor sólida")
	await _capture("ref_surface_map_cabin_640x360.png")
	# Technical 2D sheets, rendered separately from the unchanged world.
	camera.cull_mask = 0
	_new_overlay("GUIA DE TEMPLATE — linhas e rótulos não são arte")
	var background := ColorRect.new()
	background.color = Color(0.08, 0.1, 0.13)
	background.size = Vector2(640, 360)
	overlay.add_child(background)
	overlay.move_child(background, 0)
	_label(overlay, "Portas: 36×86 px cada\n1,08×2,58 m\n33,33 px/m\n\nCima = topo da folha\nCentro = encontro\nSem espelhar a direita\n\nToda a tela é útil.\nSem margem externa.\nGuias só nesta prancha.", Vector2(12, 70))
	_template_preview("ep_e01_door_left_albedo_template.png", Vector2(220, 68), 3)
	_template_preview("ep_e01_door_right_albedo_template.png", Vector2(350, 68), 3)
	_label(overlay, "ESQUERDA", Vector2(218, 47))
	_label(overlay, "DIREITA", Vector2(350, 47))
	_label(overlay, "← ENCONTRO →", Vector2(290, 331))
	_label(overlay, "Frontal\nlocal +Z\n\nU →\nV ↓\n\nNão usar\nesta prancha\ncomo textura.", Vector2(485, 100))
	await _capture("guide_doors_640x360.png")
	_new_overlay("GUIA DE TEMPLATE — visor e padrões repetíveis")
	background = ColorRect.new()
	background.color = Color(0.08, 0.1, 0.13)
	background.size = Vector2(640, 360)
	overlay.add_child(background)
	overlay.move_child(background, 0)
	_label(overlay, "VISOR 38×12 px = 0,76×0,24 m; 50 px/m; U → / V ↓", Vector2(12, 48))
	_template_preview("ep_e01_display_albedo_template.png", Vector2(12, 70), 8)
	_label(overlay, "METAL: tile 16×16", Vector2(12, 180))
	_template_preview("ep_e01_metal_tile_albedo_template.png", Vector2(12, 203), 7)
	_label(overlay, "PISO: tile 16×16", Vector2(195, 180))
	_template_preview("ep_e01_floor_tile_albedo_template.png", Vector2(195, 203), 7)
	_label(overlay, "Tiles: repetição em X/Y\n0,667 m por repetição\n24 px/m na escala atual\n\nSem borda desenhada.\nConectar lados opostos.\nCinza = tela neutra,\nnão paleta aprovada.", Vector2(370, 180))
	_label(overlay, "PNG de trabalho em templates/ — sem linhas; prancha apenas para orientação.", Vector2(12, 334))
	await _capture("guide_display_tiles_640x360.png")


func _template_preview(filename: String, position: Vector2, zoom: int) -> void:
	var image := Image.load_from_file(BASE + "templates/" + filename)
	var texture := TextureRect.new()
	texture.texture = ImageTexture.create_from_image(image)
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture.position = position
	texture.size = Vector2(image.get_size()) * zoom
	overlay.add_child(texture)
	for axis in [0, 1]:
		var extent := image.get_width() if axis == 0 else image.get_height()
		for index in range(0, extent + 1):
			var line := Line2D.new()
			line.width = 1.0
			line.default_color = Color(0.16, 0.2, 0.26, 0.7 if index % 4 == 0 else 0.25)
			var start := position + (Vector2(index * zoom, 0) if axis == 0 else Vector2(0, index * zoom))
			line.points = PackedVector2Array([start, start + (Vector2(0, texture.size.y) if axis == 0 else Vector2(texture.size.x, 0))])
			overlay.add_child(line)
