extends StaticBody3D
## Picking-only body. Each visual gets a private material; no shared asset is edited.
signal activated

const PICK_LAYER: int = 1 << 19
var available: bool = true
var hovered: bool = false
var selected: bool = false
var visual_root: Node3D
var slide_offset: Vector3 = Vector3.ZERO
var _materials: Array[StandardMaterial3D] = []
var _originals: Array[StandardMaterial3D] = []
var _pulse: Tween
var _slide: Tween
var _rest: Vector3
var glow: float = 0.0:
	set(value):
		glow = value
		for i in _materials.size():
			var mat := _materials[i]
			var original := _originals[i]
			mat.albedo_color = original.albedo_color.lerp(Color(1.0, 0.88, 0.45), value * 0.18)
			mat.emission_enabled = original.emission_enabled or value > 0.0
			mat.emission = original.emission.lerp(Color(0.32, 0.23, 0.04), value)


func configure(root: Node3D, bounds: Vector3, slide: Vector3 = Vector3.ZERO) -> void:
	collision_layer = PICK_LAYER
	collision_mask = 0
	input_ray_pickable = false
	visual_root = root
	_rest = root.position
	slide_offset = slide
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Stable swept hit region prevents hover jitter while the clipboard moves.
	box.size = bounds + slide.abs()
	shape.shape = box
	shape.position = slide * 0.5
	add_child(shape)
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
		if material == null:
			continue
		_originals.append(material)
		var private_material: StandardMaterial3D = material.duplicate()
		mesh.material_override = private_material
		_materials.append(private_material)


func set_hover(value: bool) -> void:
	value = value and available
	if hovered == value:
		return
	hovered = value
	_refresh_glow()
	if _slide:
		_slide.kill()
	_slide = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_slide.tween_property(visual_root, "position", _rest + (slide_offset if value else Vector3.ZERO), 0.22)


func set_selected(value: bool) -> void:
	selected = value
	_refresh_glow()


func _refresh_glow() -> void:
	if _pulse:
		_pulse.kill()
	if hovered:
		_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(self, "glow", 0.9, 0.7)
		_pulse.tween_property(self, "glow", 0.35, 0.7)
	else:
		glow = 0.5 if selected else 0.0


func activate() -> void:
	if available and is_visible_in_tree():
		activated.emit()


func set_available(value: bool) -> void:
	available = value
	if not value:
		set_hover(false)
		set_selected(false)


func _exit_tree() -> void:
	if _pulse:
		_pulse.kill()
	if _slide:
		_slide.kill()
