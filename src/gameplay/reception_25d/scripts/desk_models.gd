extends RefCounted
## Provisional native meshes only. No authoring assets or room geometry are modified.
const Interactable = preload("res://src/gameplay/reception_25d/scripts/desk_interactable.gd")
const FONT = preload("res://assets/fonts/pixeloid_sans.ttf")

static func box(parent: Node3D, dimensions: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	node.material_override = material
	parent.add_child(node)
	return node


static func object_at(parent: Node3D, kind: String, dimensions: Vector3) -> Interactable:
	var body := Interactable.new()
	body.name = kind
	parent.add_child(body)
	var visual := Node3D.new()
	visual.name = "Model"
	body.add_child(visual)
	var color := Color("609b99") if kind == "Badge" else Color("614943")
	box(visual, dimensions, Vector3.ZERO, color)
	if kind == "Book":
		box(visual, dimensions * Vector3(0.91, 0.65, 0.92), Vector3(0.015, 0.018, 0), Color("ddd2b4"))
		box(visual, Vector3(dimensions.x, 0.014, dimensions.z), Vector3(0, 0.055, 0), color)
		box(visual, Vector3(0.035, 0.09, dimensions.z), Vector3(-dimensions.x * 0.47, 0.015, 0), color)
	else:
		box(visual, dimensions * Vector3(0.85, 0.25, 0.8), Vector3(0, dimensions.y * 0.6, 0.015), Color("d8d4bc"))
		box(visual, Vector3(dimensions.x * 0.4, 0.025, 0.06), Vector3(0, dimensions.y, -dimensions.z * 0.38), Color("858c91"))
	body.configure(visual, dimensions + Vector3(0, 0.12, 0), Vector3(0, 0.008, -0.14) if kind == "Clipboard" else Vector3.ZERO)
	return body


static func button(parent: Node3D, title: String, at: Vector3, dimensions: Vector3) -> Interactable:
	var body := Interactable.new()
	parent.add_child(body)
	body.position = at
	var visual := Node3D.new()
	body.add_child(visual)
	box(visual, dimensions, Vector3.ZERO, Color("606d70"))
	var label := Label3D.new()
	label.text = title
	label.font = FONT
	label.font_size = 24
	label.pixel_size = 0.0045
	label.position.z = dimensions.z * 0.5 + 0.003
	label.modulate = Color("fff4d2")
	label.outline_size = 0
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	visual.add_child(label)
	body.configure(visual, dimensions)
	return body
