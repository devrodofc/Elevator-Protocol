extends Node
## Horror layer of the 3D reception. Pure presentation: it never decides a visit, never validates and never
## moves the queue. It reads the presentation's stage and adds atmosphere and scares that grow each day:
## lights (startup, flicker, blackout), fog, floor indicators, the basement's victims coming back, Marta in
## the corner of the room, doors opening by themselves, shaft knocks, subliminal flashes, a security camera,
## procedural ambience, walk animation of the sprites and camera effects.

const Cabin = preload("res://src/gameplay/reception_25d/scripts/elevator_door.gd")
const Door = preload("res://src/gameplay/reception_25d/scripts/automatic_door.gd")
const AmbienceScript = preload("res://src/gameplay/reception_25d/scripts/ambience.gd")
const POST_SHADER = preload("res://src/gameplay/reception_25d/shaders/room_post.gdshader")
const FONT_BOLD = preload("res://assets/fonts/pixeloid_sans_bold.ttf")
const MARTA_SPRITE = preload("res://src/npcs/assets/marta/marta_1_frame.png")
const MARTA_BLOODY = preload("res://src/npcs/assets/marta/marta_bloody.png")
## Walk cycles built from the existing frames (first entry = the sprite used by the agendas).
const WALK_CYCLES := {
	"res://src/npcs/assets/npc_male_1/npc_male_1_frame_1.png": [
		"res://src/npcs/assets/npc_male_1/npc_male_1_frame_1.png",
		"res://src/npcs/assets/npc_male_1/npc_male_1_frame_2.png",
		"res://src/npcs/assets/npc_male_1/npc_male_1_frame_1.png",
		"res://src/npcs/assets/npc_male_1/npc_male_1_frame_3.png"],
	"res://src/npcs/assets/marta/marta_1_frame.png": [
		"res://src/npcs/assets/marta/marta_1_frame.png",
		"res://src/npcs/assets/marta/marta_2_frame.png",
		"res://src/npcs/assets/marta/marta_1_frame.png",
		"res://src/npcs/assets/marta/marta_3_frame.png"],
}
## Per day (index 0 = day 1): light strength, fog, ambient, post effect, how often things happen.
const DAY_LOOK := [
	{"light": 1.0, "fog": 0.010, "ambient": 0.5, "vignette": 0.32, "grain": 0.025, "aberration": 0.0, "events": 0.35, "hum": 0.55},
	{"light": 0.86, "fog": 0.02, "ambient": 0.38, "vignette": 0.45, "grain": 0.04, "aberration": 0.5, "events": 0.7, "hum": 0.75},
	{"light": 0.72, "fog": 0.032, "ambient": 0.28, "vignette": 0.6, "grain": 0.06, "aberration": 1.1, "events": 1.0, "hum": 0.9},
]

## Sprites of everyone sent to the basement (kept across days and reloads; cleared by a new game).
static var victims: Array[Texture2D] = []
## Names of the victims (same order as victims): the basement calls on day 3 use them.
static var victim_names: Array[String] = []

var presentation: Node2D
var room: Node3D
var camera: Camera3D
var env: Environment
var ambience: AmbienceScript
var post: ShaderMaterial
var day: int = 1
var look: Dictionary
var lights: Array[Light3D] = []
var _base_energy: Dictionary = {}
var _flick: Dictionary = {}
## Global light multiplier: 0 = blackout. Lights start off and are turned on by lights_on().
var light_level: float = 0.0
var indicators: Dictionary = {}
var _indicator_floor: Dictionary = {}
var _travel_version: Dictionary = {}
var _ghost: Node3D
var _ghost_sprite: Sprite3D
var _chair_ghosts: Array[Node3D] = []
var _peripheral: Node3D
var _peripheral_state: int = 0 # 0 none, 1 waiting to be seen, 2 seen
var _peripheral_seen_for: float = 0.0
var _peripheral_age: float = 0.0
var _peripheral_done: int = 0
var _cctv: Node3D
var _cctv_led: MeshInstance3D
var _event_timer: float = 12.0
var _clock_minutes: float = 8 * 60.0
var _monitor_override: float = 0.0
var _checked_ghost_visit: String = ""
var _subliminal_visit: String = ""
var _walk_cache: Dictionary = {}
var _walk_phase: Dictionary = {}
var _shake: float = 0.0
var _shake_time: float = 0.0
var _post_pulse: float = 0.0
var _post_glitch: float = 0.0
var _version: int = 0
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _last_stage: int = -1
## Heartbeat while Marta is in the room / during a scare (the louder one wins).
var marta_heart: float = 0.0
var event_heart: float = 0.0


func setup(owner_scene: Node2D) -> void:
	presentation = owner_scene
	room = presentation.get_node("RoomViewport/Room")
	camera = room.get_node("ReceptionCamera")
	day = clampi(presentation.session.day_number, 1, 3)
	look = DAY_LOOK[day - 1]
	_rng.randomize()
	_setup_environment()
	_setup_lights()
	_setup_post()
	_setup_indicators()
	_build_ghosts()
	_build_cctv()
	ambience = AmbienceScript.new()
	ambience.name = "Ambience"
	add_child(ambience)
	ambience.drone_level = 0.0 if day < 3 else 0.5
	_event_timer = _rng.randf_range(14.0, 22.0) / look.events


# --- setup ---------------------------------------------------------------------------------------

func _setup_environment() -> void:
	var world: WorldEnvironment = room.get_node("WorldEnvironment")
	env = world.environment.duplicate()
	world.environment = env
	env.ambient_light_energy = look.ambient
	if day == 3:
		env.ambient_light_color = Color(0.85, 0.7, 0.72)
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.08) if day < 3 else Color(0.08, 0.035, 0.04)
	env.fog_density = look.fog
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0 if day == 1 else (0.85 if day == 2 else 0.7)
	env.adjustment_contrast = 1.05
	# Night falls a little more each day outside the windows.
	var sky: Color = [Color(0.22, 0.36, 0.5), Color(0.09, 0.13, 0.22), Color(0.07, 0.03, 0.05)][day - 1]
	for window in room.get_node("WaitingArea/Windows").get_children():
		var pane := window.get_node_or_null("Pane") as MeshInstance3D
		if pane:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = sky
			mat.emission_enabled = true
			mat.emission = sky
			mat.emission_energy_multiplier = 0.7
			pane.material_override = mat


func _setup_lights() -> void:
	for path in ["CeilingLight", "RearLight", "ReceptionDesk/DeskLamp", "ReceptionDesk/FaceFill"]:
		var light := room.get_node_or_null(path) as Light3D
		if light:
			lights.append(light)
	for cabin in room.get_node("Elevators").get_children():
		var inner := cabin.get_node_or_null("Cabin/Light") as Light3D
		if inner:
			lights.append(inner)
	for light in lights:
		var strength: float = light.light_energy
		if light.name in ["CeilingLight", "RearLight"]:
			strength *= look.light
			light.shadow_enabled = false
		_base_energy[light] = strength
		_flick[light] = 1.0
		light.light_energy = 0.0


func _setup_post() -> void:
	post = ShaderMaterial.new()
	post.shader = POST_SHADER
	var view: Sprite2D = presentation.get_node("RoomView")
	view.material = post
	_apply_post()


func _setup_indicators() -> void:
	for cabin in room.get_node("Elevators").get_children():
		var back := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.46, 0.3, 0.04)
		back.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.03, 0.03, 0.03)
		back.material_override = mat
		back.position = Vector3(0.82, 3.05, 0.34)
		cabin.add_child(back)
		var label := Label3D.new()
		label.font = FONT_BOLD
		label.font_size = 56
		label.pixel_size = 0.0042
		label.outline_size = 0
		label.shaded = false
		label.position = Vector3(0.82, 3.05, 0.365)
		cabin.add_child(label)
		indicators[cabin.name] = label
		# Marta's cabin always rests in the basement.
		_set_indicator(cabin.name, -1 if cabin.name == "Elevator02" else 0)


func _sprite_copy(texture: Texture2D) -> Sprite3D:
	var sprite: Sprite3D = presentation.visual.duplicate()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.rotation = Vector3.ZERO
	sprite.offset = Vector2.ZERO
	sprite.apply_visit_texture(texture)
	return sprite


func _build_ghosts() -> void:
	_ghost = Node3D.new()
	_ghost.name = "CabinGhost"
	room.add_child(_ghost)
	_ghost.hide()
	_chair_ghosts.clear()
	if victims.is_empty() and day < 2:
		return
	# Victims (or, with nobody sent down yet, nobody) wait among the chairs; seen only in the dark.
	var seats: Array = room.get_node("WaitingArea/SittingPositions").get_children()
	for i in mini(victims.size(), seats.size()):
		var seat: Marker3D = seats[i]
		var holder := Node3D.new()
		holder.position = Vector3(seat.position.x + 0.55, 0.0, seat.position.z)
		var sprite := _sprite_copy(victims[victims.size() - 1 - i])
		sprite.shaded = false
		sprite.modulate = Color(0.42, 0.06, 0.06)
		holder.add_child(sprite)
		room.add_child(holder)
		holder.hide()
		_chair_ghosts.append(holder)


func _build_cctv() -> void:
	_cctv = Node3D.new()
	_cctv.name = "SecurityCamera"
	_cctv.position = Vector3(-4.6, 3.45, -0.6)
	room.add_child(_cctv)
	var mount := _box(_cctv, Vector3(0.06, 0.18, 0.06), Vector3(0, 0.12, 0), Color("1b1f22"))
	mount.name = "Mount"
	var head := Node3D.new()
	head.name = "Head"
	_cctv.add_child(head)
	_box(head, Vector3(0.16, 0.14, 0.34), Vector3(0, 0, 0), Color("d8d8d0"))
	_box(head, Vector3(0.1, 0.1, 0.04), Vector3(0, 0, 0.18), Color("101214"))
	_cctv_led = _box(head, Vector3(0.025, 0.025, 0.02), Vector3(0.05, 0.05, 0.18), Color(1, 0.05, 0.05), 4.0)


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	node.material_override = mat
	parent.add_child(node)
	return node


# --- lights --------------------------------------------------------------------------------------

## Fluorescent start of the shift: each lamp stutters on, then the hum settles.
func lights_on() -> void:
	var version := _version
	light_level = 1.0
	for light in lights:
		_flick[light] = 0.0
	ambience.hum_level = look.hum * 0.4
	_set_monitor("PORTARIA", "Dia %d · ligando..." % day)
	await _wait(0.5)
	for light in lights:
		if version != _version:
			return
		for value in [0.6, 0.0, 0.8, 0.1, 1.0, 0.3, 1.0]:
			_flick[light] = value
			ambience.crackle(0.5)
			await _wait(_rng.randf_range(0.04, 0.11))
			if version != _version:
				return
		_flick[light] = 1.0
		await _wait(0.12)
	ambience.hum_level = look.hum


## Lights already on (retry after a failure: straight back to work).
func lights_now() -> void:
	light_level = 1.0
	for light in lights:
		_flick[light] = 1.0
	ambience.hum_level = look.hum


## Random stutter of some lights. strength 0..1; returns when done.
func flicker(duration: float = 0.6, strength: float = 0.8, only_main: bool = false) -> void:
	var version := _version
	var targets: Array[Light3D] = []
	for light in lights:
		if not only_main or light.name in ["CeilingLight", "RearLight", "DeskLamp"]:
			targets.append(light)
	var end := _t + duration
	while _t < end and version == _version:
		for light in targets:
			_flick[light] = 1.0 - strength * (_rng.randf() if _rng.randf() < 0.7 else 1.0)
		ambience.crackle(strength)
		await _wait(_rng.randf_range(0.035, 0.1))
	if version != _version:
		return
	for light in targets:
		_flick[light] = 1.0


## All lights out (level 0) or back (level 1), in seconds.
func set_light_level(level: float, seconds: float = 0.0) -> void:
	if seconds <= 0.0:
		light_level = level
		return
	var tween := create_tween()
	tween.tween_property(self, "light_level", level, seconds)
	await tween.finished


func room_brightness() -> float:
	var total := 0.0
	var count := 0
	for light in lights:
		if light.name in ["CeilingLight", "RearLight"]:
			total += _flick[light]
			count += 1
	return light_level * (total / maxf(count, 1))


# --- indicators ----------------------------------------------------------------------------------

func _indicator_text(floor_code: int) -> String:
	if floor_code == -1:
		return "S"
	return "T" if floor_code == 0 else str(floor_code)


func _set_indicator(cabin_name: String, floor_code: int) -> void:
	_indicator_floor[cabin_name] = floor_code
	var label: Label3D = indicators.get(cabin_name)
	if label == null:
		return
	label.text = _indicator_text(floor_code)
	label.modulate = Color(1.0, 0.12, 0.08) if floor_code == -1 else Color(1.0, 0.68, 0.2)


## The cabin "travels" one floor at a time; ends back on the ground floor after a while.
func travel(cabin_name: String, floor_code: int, come_back: bool = true) -> void:
	var serial: int = _travel_version.get(cabin_name, 0) + 1
	_travel_version[cabin_name] = serial
	var current: int = _indicator_floor.get(cabin_name, 0)
	var target := 0 if floor_code == 999 else floor_code
	while current != target:
		await _wait(0.5)
		if _travel_version.get(cabin_name) != serial or not is_inside_tree():
			return
		current += 1 if target > current else -1
		_set_indicator(cabin_name, current)
		if current == -1:
			_basement_reached()
	if not come_back:
		return
	await _wait(3.0)
	while current != 0:
		await _wait(0.3)
		if _travel_version.get(cabin_name) != serial or not is_inside_tree():
			return
		current += 1 if current < 0 else -1
		_set_indicator(cabin_name, current)


## Someone just arrived where nobody goes.
func _basement_reached() -> void:
	ambience.thump(0.9)
	shake(0.45, 2.0)
	pulse_red(0.55)
	flicker(0.5, 0.7, true)
	_set_monitor("SUBSOLO", "acesso registrado", Color(1.0, 0.25, 0.2), 3.0)


## Marta's cabin climbs from the basement before she shows up: the player learns to dread it.
func marta_incoming() -> void:
	marta_heart = 0.45 + 0.15 * day
	ambience.heartbeat_bpm = 70.0 + 8.0 * day
	var label: Label3D = indicators.get("Elevator02")
	for i in 3:
		if label:
			label.visible = false
		await _wait(0.18)
		if label:
			label.visible = true
		await _wait(0.22)
	_set_indicator("Elevator02", 0)
	flicker(0.35, 0.5, true)
	await _wait(0.25)


func marta_gone() -> void:
	marta_heart = 0.0
	_set_indicator("Elevator02", -1)


## A visitor boarded cabin 1 to floor_code (the cabin just closed with him inside).
func cabin_departed(cabin_name: String, floor_code: int, sprite: Texture2D) -> void:
	if floor_code == -1 and sprite:
		victims.append(sprite)
		while victims.size() > 4:
			victims.pop_front()
	travel(cabin_name, floor_code)


# --- scares --------------------------------------------------------------------------------------

func shake(strength: float, seconds: float) -> void:
	_shake = maxf(_shake, strength)
	_shake_time = maxf(_shake_time, seconds)


func pulse_red(amount: float) -> void:
	_post_pulse = maxf(_post_pulse, amount)


func glitch(amount: float) -> void:
	_post_glitch = maxf(_post_glitch, amount)


func fov_punch(to_fov: float, seconds: float) -> void:
	var base := 70.0
	var tween := create_tween()
	tween.tween_property(camera, "fov", to_fov, 0.08)
	tween.tween_property(camera, "fov", base, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Jump scare: lights cut, Marta's face right at the counter, impact.
func scare_impact() -> void:
	ambience.thump(1.3)
	Audio.play_sfx(Audio.ERRO, 2.0, 0.55)
	Audio.play_sfx(Audio.CHEGOU_ELEVADOR, 0.0, 0.42)
	shake(1.0, 0.9)
	pulse_red(1.0)
	glitch(1.0)
	fov_punch(54.0, 1.6)


## The cabin opens for the visitor... and someone who went down is already inside.
func _try_cabin_ghost(cabin: Node3D) -> void:
	if victims.is_empty() or _rng.randf() > (0.35 + 0.2 * (day - 1)):
		return
	var version := _version
	for child in _ghost.get_children():
		child.queue_free()
	var sprite := _sprite_copy(victims[_rng.randi() % victims.size()])
	sprite.modulate = Color(0.16, 0.14, 0.16)
	_ghost.add_child(sprite)
	var stop: Marker3D = cabin.cabin_stop_point
	_ghost.position = room.to_local(stop.global_position)
	_ghost.position.y = 0.0
	_ghost.show()
	event_heart = 0.5
	await _wait(0.9)
	if version != _version:
		return
	await flicker(0.45, 1.0)
	_ghost.hide()
	event_heart = 0.0


func _maybe_subliminal() -> void:
	var visual: Sprite3D = presentation.visual
	var before: Texture2D = visual.texture
	var flash := _runtime_texture(MARTA_BLOODY)
	_flick_all(0.15)
	visual.texture = flash
	ambience.crackle(1.0)
	await _wait(0.07)
	if is_instance_valid(visual) and visual.texture == flash:
		visual.texture = before
	_flick_all(1.0)


func _flick_all(value: float) -> void:
	for light in lights:
		_flick[light] = value


func _door_opens_alone() -> void:
	var used: Node = presentation._door
	for door in room.get_node("Entrances").get_children():
		if door == used:
			continue
		var version := _version
		door.open()
		ambience.crackle(0.3)
		await _wait(_rng.randf_range(2.0, 3.5))
		if version == _version and is_instance_valid(door):
			door.close()
		return


func _empty_cabin_opens() -> void:
	var cabin: Node3D = room.get_node("Elevators/Elevator03")
	var inner := cabin.get_node_or_null("Cabin/Light") as OmniLight3D
	var version := _version
	var color := Color.WHITE
	if inner:
		color = inner.light_color
		inner.light_color = Color(1.0, 0.1, 0.06)
	_set_indicator("Elevator03", -1)
	await _wait(0.6)
	Audio.play_sfx(Audio.CHEGOU_ELEVADOR, -10.0, 0.55)
	cabin.open()
	await _wait(3.2)
	if version != _version:
		return
	cabin.close()
	await _wait(1.0)
	if inner:
		inner.light_color = color
	_set_indicator("Elevator03", 0)


func _spawn_peripheral() -> void:
	if _peripheral == null:
		_peripheral = Node3D.new()
		_peripheral.name = "MartaInTheCorner"
		var sprite := _sprite_copy(MARTA_SPRITE)
		sprite.shaded = false
		sprite.modulate = Color(0.34, 0.31, 0.36)
		_peripheral.add_child(sprite)
		room.add_child(_peripheral)
	# Back-left corner, between the windows and the left entrance.
	_peripheral.position = Vector3(-6.2, 0.0, -9.4) if _rng.randf() < 0.5 else Vector3(-6.6, 0.0, -4.2)
	_peripheral.show()
	_peripheral_state = 1
	_peripheral_seen_for = 0.0
	_peripheral_age = 0.0


func _update_peripheral(delta: float) -> void:
	if _peripheral_state == 0 or _peripheral == null:
		return
	_peripheral_age += delta
	var at := _peripheral.global_position + Vector3.UP * 1.4
	var seen := false
	if not camera.is_position_behind(at):
		var p := camera.unproject_position(at)
		var size: Vector2 = presentation.get_node("RoomViewport").size
		seen = absf(p.x - size.x * 0.5) < size.x * 0.32
	if seen:
		_peripheral_seen_for += delta
	if (_peripheral_state == 1 and _peripheral_seen_for > 0.75) or _peripheral_age > 30.0:
		_peripheral_state = 0
		_peripheral_done += 1
		if _peripheral_age <= 30.0:
			event_heart = 0.7
			Audio.play_sfx(Audio.CHEGOU_ELEVADOR, -4.0, 0.38)
			await flicker(0.4, 1.0)
			event_heart = 0.0
		if is_instance_valid(_peripheral):
			_peripheral.hide()


## Random event between visits; happens only while a visitor waits at the desk (never during Marta).
func _random_event() -> void:
	var stage: int = presentation.stage
	var serving: bool = stage == presentation.Stage.AT_SERVICE
	var options: Array[String] = ["flicker"]
	if day >= 2 or presentation.session.served_count >= 3:
		options.append("knock")
	var godofredo_busy: bool = presentation.story != null and presentation.story.godofredo.busy
	if serving and day >= 2:
		options.append("door")
		if not godofredo_busy:
			options.append("cabin")
	if day >= 2 and _peripheral_state == 0 and _peripheral_done < day - 1 and absf(camera.look_yaw()) < 0.25:
		options.append("marta")
	if serving and day >= 3:
		options.append("monitor")
	match options[_rng.randi() % options.size()]:
		"flicker":
			flicker(_rng.randf_range(0.3, 0.9), 0.35 + 0.2 * day, true)
		"knock":
			ambience.knock(_rng.randi_range(2, 4))
			shake(0.12, 0.8)
		"door":
			_door_opens_alone()
		"cabin":
			_empty_cabin_opens()
		"marta":
			_spawn_peripheral()
		"monitor":
			_set_monitor("ELA ESTÁ VENDO", "", Color(1.0, 0.2, 0.15), 0.6)
			glitch(0.6)


# --- per frame -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_update_lights()
	_update_ghosts()
	_update_cctv(delta)
	_update_camera(delta)
	_update_post(delta)
	_update_monitor(delta)
	_animate(presentation.visual, presentation.movement, delta)
	var marta = presentation.marta
	if marta and is_instance_valid(marta.sprite):
		_animate(marta.sprite, marta.movement, delta)
	_update_peripheral(delta)
	_watch_stage()
	ambience.heartbeat_level = maxf(marta_heart, event_heart)
	if presentation.stage in [presentation.Stage.AT_SERVICE, presentation.Stage.WALKING]:
		_event_timer -= delta
		if _event_timer <= 0.0:
			_event_timer = _rng.randf_range(10.0, 20.0) / look.events
			_random_event()


func _update_lights() -> void:
	for light in lights:
		var energy: float = _base_energy[light] * _flick[light] * light_level
		if light.name == "DeskLamp":
			# The desk lamp never goes fully dark: the player always sees the counter.
			energy = maxf(energy, _base_energy[light] * 0.12)
		light.light_energy = energy
	if is_instance_valid(env):
		env.ambient_light_energy = look.ambient * lerpf(0.15, 1.0, room_brightness())


func _update_ghosts() -> void:
	var dark := room_brightness() < 0.3 and light_level > 0.05
	for ghost in _chair_ghosts:
		ghost.visible = dark


func _update_cctv(delta: float) -> void:
	var head: Node3D = _cctv.get_node("Head")
	var target := camera.global_position
	if day >= 3 and fmod(_t, 9.0) < 0.4:
		target += Vector3(_rng.randf_range(-2, 2), _rng.randf_range(-1, 1), 0)
	var wanted := head.global_transform.looking_at(target, Vector3.UP, true)
	head.global_basis = head.global_basis.slerp(wanted.basis.orthonormalized(), clampf(delta * 1.5, 0.0, 1.0)).orthonormalized()
	_cctv_led.visible = fmod(_t, 1.2) < 0.6


func _update_camera(delta: float) -> void:
	var breathing := Vector3(sin(_t * 0.8) * 0.006, sin(_t * 0.53) * 0.004, sin(_t * 0.37) * 0.002)
	camera.effect_rotation = breathing
	if _shake_time > 0.0:
		_shake_time -= delta
		var f := _shake * clampf(_shake_time, 0.0, 1.0)
		camera.h_offset = _rng.randf_range(-1, 1) * 0.05 * f
		camera.v_offset = _rng.randf_range(-1, 1) * 0.05 * f
	else:
		_shake = 0.0
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _apply_post() -> void:
	if post == null:
		return
	post.set_shader_parameter("vignette", look.vignette + 0.35 * _post_pulse)
	post.set_shader_parameter("grain", look.grain + 0.05 * _post_glitch)
	post.set_shader_parameter("aberration", look.aberration + 4.0 * _post_glitch)
	post.set_shader_parameter("distortion", 0.9 * _post_glitch + (0.12 if day >= 3 else 0.0))
	post.set_shader_parameter("red_pulse", _post_pulse)


func _update_post(delta: float) -> void:
	_post_pulse = maxf(0.0, _post_pulse - delta * 0.5)
	_post_glitch = maxf(0.0, _post_glitch - delta * 1.2)
	_apply_post()


## Shift clock on the desk monitor (time moves with each service).
func _update_monitor(delta: float) -> void:
	if _monitor_override > 0.0:
		_monitor_override -= delta
		return
	var dressing = presentation.dressing
	if dressing == null:
		return
	var served: int = presentation.session.served_count
	_clock_minutes = lerpf(_clock_minutes, 8 * 60.0 + served * 72.0, clampf(delta * 0.8, 0.0, 1.0))
	var minutes := int(_clock_minutes)
	var clock := "%02d:%02d" % [minutes / 60, minutes % 60]
	if day >= 3 and fmod(_t, 13.0) < 0.5:
		clock = "03:33"
	dressing.set_monitor(clock, "Dia %d · %d atendidos" % [day, served],
		Color(0.45, 1.0, 0.6) if day < 3 else Color(1.0, 0.55, 0.35))


func _set_monitor(text: String, sub: String, color: Color = Color(0.45, 1.0, 0.6), seconds: float = 2.0) -> void:
	var dressing = presentation.dressing
	if dressing == null:
		return
	dressing.set_monitor(text, sub, color)
	_monitor_override = seconds


## Stage transitions that start presentation-only scares.
func _watch_stage() -> void:
	var stage: int = presentation.stage
	if stage == _last_stage:
		return
	_last_stage = stage
	var id: String = presentation.visit_id
	if stage == presentation.Stage.WAITING_FOR_CABIN and id != _checked_ghost_visit:
		_checked_ghost_visit = id
		_try_cabin_ghost(presentation.cabin)
	elif stage == presentation.Stage.AT_SERVICE and day >= 3 and id != _subliminal_visit:
		_subliminal_visit = id
		if _rng.randf() < 0.35:
			await _wait(_rng.randf_range(2.5, 6.0))
			if presentation.stage == presentation.Stage.AT_SERVICE and presentation.visit_id == id:
				_maybe_subliminal()


## Walk cycle from the existing frames + a step bob; still sprites breathe a little.
func _animate(sprite: Sprite3D, movement: Node, delta: float) -> void:
	if not is_instance_valid(sprite) or sprite.texture == null:
		return
	var moving: bool = movement.is_processing() and sprite.is_visible_in_tree()
	var phase: float = _walk_phase.get(sprite, 0.0)
	var source: Texture2D = sprite.source_texture
	var frames: Array = _walk_frames(source)
	if moving:
		phase += delta * 7.5
		sprite.offset.y = absf(sin(phase)) * 5.0
		if not frames.is_empty():
			var frame: Texture2D = frames[int(phase / PI) % frames.size()]
			if sprite.texture != frame:
				sprite.texture = frame
	else:
		phase = 0.0
		sprite.offset.y = sin(_t * 1.6) * 0.6
		if not frames.is_empty() and sprite.texture in frames and sprite.texture != frames[0]:
			sprite.texture = frames[0]
	_walk_phase[sprite] = phase


func _walk_frames(source: Texture2D) -> Array:
	if source == null or not WALK_CYCLES.has(source.resource_path):
		return []
	var path := source.resource_path
	if not _walk_cache.has(path):
		var frames: Array = []
		for frame_path in WALK_CYCLES[path]:
			frames.append(_runtime_texture(load(frame_path)))
		_walk_cache[path] = frames
	return _walk_cache[path]


func _runtime_texture(texture: Texture2D) -> Texture2D:
	var key := "rt:" + texture.resource_path
	if _walk_cache.has(key):
		return _walk_cache[key]
	var runtime := ImageTexture.create_from_image(texture.get_image())
	_walk_cache[key] = runtime
	return runtime


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func cancel() -> void:
	_version += 1
	if ambience:
		ambience.stop()


func _exit_tree() -> void:
	cancel()
