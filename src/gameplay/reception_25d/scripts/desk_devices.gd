extends Node
## Two new desk objects of the 3D game, built from simple meshes (no new assets):
## - the desk phone (rings, shakes, LED; click to answer / hang up);
## - the elevator ALARM button (big red button; click to stop a cabin that is going down on its own).
## Both are desk_interactable bodies, so the existing picker hovers and clicks them.

signal phone_clicked
signal alarm_clicked

const Interactable = preload("res://src/gameplay/reception_25d/scripts/desk_interactable.gd")
const FONT_BOLD = preload("res://assets/fonts/pixeloid_sans_bold.ttf")

var phone: Interactable
var alarm: Interactable
var ringing: bool = false
var off_hook: bool = false
var _handset: Node3D
var _handset_rest: Vector3
var _led: MeshInstance3D
var _dome: MeshInstance3D
var _alarm_light: OmniLight3D
var _alarm_flash: float = 0.0
var _press: float = 0.0
var _t: float = 0.0


func build(room: Node3D) -> void:
	var anchors: Node3D = room.get_node("ReceptionDesk/ServiceObjects")
	_build_phone(anchors.get_node("PhoneRest"))
	_build_alarm(anchors.get_node("AlarmRest"))


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	node.material_override = mat
	parent.add_child(node)
	return node


func _build_phone(anchor: Node3D) -> void:
	phone = Interactable.new()
	phone.name = "DeskPhone"
	anchor.add_child(phone)
	var visual := Node3D.new()
	phone.add_child(visual)
	# Body with a sloped front, keypad and cradle.
	_box(visual, Vector3(0.3, 0.07, 0.24), Vector3(0, 0.035, 0), Color("3b1414"))
	_box(visual, Vector3(0.26, 0.04, 0.1), Vector3(0, 0.075, 0.06), Color("4a1a1a"))
	for row in 3:
		for col in 3:
			_box(visual, Vector3(0.04, 0.012, 0.025), Vector3(-0.055 + col * 0.055, 0.1, 0.03 + row * 0.03), Color("d9d1c0"))
	_box(visual, Vector3(0.05, 0.03, 0.05), Vector3(-0.1, 0.085, -0.07), Color("2a0d0d"))
	_box(visual, Vector3(0.05, 0.03, 0.05), Vector3(0.1, 0.085, -0.07), Color("2a0d0d"))
	_led = _box(visual, Vector3(0.025, 0.012, 0.012), Vector3(0.12, 0.072, 0.12), Color(1.0, 0.15, 0.1), 3.0)
	_handset = Node3D.new()
	_handset.position = Vector3(0, 0.115, -0.07)
	visual.add_child(_handset)
	_handset_rest = _handset.position
	_box(_handset, Vector3(0.34, 0.035, 0.06), Vector3.ZERO, Color("4a1a1a"))
	_box(_handset, Vector3(0.07, 0.05, 0.08), Vector3(-0.15, 0.0, 0), Color("4a1a1a"))
	_box(_handset, Vector3(0.07, 0.05, 0.08), Vector3(0.15, 0.0, 0), Color("4a1a1a"))
	phone.configure(visual, Vector3(0.36, 0.2, 0.28))
	phone.activated.connect(func(): phone_clicked.emit())


func _build_alarm(anchor: Node3D) -> void:
	alarm = Interactable.new()
	alarm.name = "AlarmButton"
	anchor.add_child(alarm)
	var visual := Node3D.new()
	alarm.add_child(visual)
	# Yellow/black hazard base, red dome, label.
	_box(visual, Vector3(0.22, 0.04, 0.22), Vector3(0, 0.02, 0), Color("c9a227"))
	for i in 4:
		_box(visual, Vector3(0.025, 0.041, 0.225), Vector3(-0.08 + i * 0.053, 0.02, 0), Color("161616"))
	_box(visual, Vector3(0.16, 0.03, 0.16), Vector3(0, 0.055, 0), Color("2b2b2b"))
	_dome = MeshInstance3D.new()
	var dome_mesh := CylinderMesh.new()
	dome_mesh.top_radius = 0.055
	dome_mesh.bottom_radius = 0.065
	dome_mesh.height = 0.05
	dome_mesh.radial_segments = 16
	_dome.mesh = dome_mesh
	_dome.position = Vector3(0, 0.095, 0)
	var dome_mat := StandardMaterial3D.new()
	dome_mat.albedo_color = Color(0.85, 0.05, 0.04)
	dome_mat.emission_enabled = true
	dome_mat.emission = Color(1.0, 0.1, 0.05)
	dome_mat.emission_energy_multiplier = 0.4
	dome_mat.roughness = 0.3
	_dome.material_override = dome_mat
	visual.add_child(_dome)
	var label := Label3D.new()
	label.text = "ALARME"
	label.font = FONT_BOLD
	label.font_size = 40
	label.pixel_size = 0.0011
	label.outline_size = 0
	label.modulate = Color(0.08, 0.08, 0.08)
	label.position = Vector3(0, 0.026, 0.112)
	label.rotation.x = deg_to_rad(-20)
	visual.add_child(label)
	_alarm_light = OmniLight3D.new()
	_alarm_light.light_color = Color(1.0, 0.1, 0.05)
	_alarm_light.light_energy = 0.0
	_alarm_light.omni_range = 1.6
	_alarm_light.position = Vector3(0, 0.25, 0)
	visual.add_child(_alarm_light)
	alarm.configure(visual, Vector3(0.24, 0.16, 0.24))
	alarm.activated.connect(func():
		_press = 1.0
		alarm_clicked.emit()
	)


func set_ringing(value: bool) -> void:
	ringing = value


func set_off_hook(value: bool) -> void:
	off_hook = value


## The dome blinks (an anomaly is happening) for this many seconds.
func flash_alarm(seconds: float) -> void:
	_alarm_flash = maxf(_alarm_flash, seconds)


func stop_alarm_flash() -> void:
	_alarm_flash = 0.0


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_handset):
		var target := _handset_rest
		var tilt := 0.0
		if off_hook:
			target = _handset_rest + Vector3(0.05, 0.22, 0.14)
			tilt = 0.9
		elif ringing:
			target = _handset_rest + Vector3(0, absf(sin(_t * 38.0)) * 0.012, 0)
			tilt = sin(_t * 41.0) * 0.06
		_handset.position = _handset.position.lerp(target, clampf(delta * 14.0, 0.0, 1.0))
		_handset.rotation.z = lerpf(_handset.rotation.z, tilt, clampf(delta * 14.0, 0.0, 1.0))
		_led.visible = ringing and fmod(_t, 0.5) < 0.25
	if is_instance_valid(_dome):
		_press = maxf(0.0, _press - delta * 5.0)
		_dome.position.y = 0.095 - _press * 0.02
		var mat := _dome.material_override as StandardMaterial3D
		if _alarm_flash > 0.0:
			_alarm_flash -= delta
			var on := fmod(_t, 0.4) < 0.2
			mat.emission_energy_multiplier = 3.5 if on else 0.6
			_alarm_light.light_energy = 1.6 if on else 0.2
		else:
			mat.emission_energy_multiplier = 0.4 + (0.8 if alarm.hovered else 0.0)
			_alarm_light.light_energy = 0.0
