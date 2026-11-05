extends Node
## Elevator camera + ALARM mechanic of the 3D game (presentation only: the session already counted the visit).
## After a visitor boards cabin 1, the desk monitor shows a live feed from a camera inside the cabin while the
## floor indicator climbs. Some rides are taken over: the cabin turns back and goes DOWN to the basement on its
## own, the light turns red and someone appears behind the passenger. Pressing ALARM before it reaches S stops
## it (saved); otherwise the passenger is taken. Rides the rules send to the basement can also be stopped.
## Outcomes: "arrived", "basement" (sent down by the rules), "saved", "saved_basement", "taken".

signal ride_ended(outcome: String, passenger: String, floor_code: int)
signal anomaly_started

const FONT_BOLD = preload("res://assets/fonts/pixeloid_sans_bold.ttf")
const CABIN_NAME := "Elevator01"
const Director = preload("res://src/gameplay/reception_25d/scripts/horror_director.gd")

var presentation: Node2D
var director: Node
var room: Node3D
var cabin: Node3D
var feed: SubViewport
var feed_camera: Camera3D
var screen: MeshInstance3D
var title: Label3D
var floor_label: Label3D
var riding: bool = false
## True while the alarm can still save the passenger.
var alarm_open: bool = false
var _mat: StandardMaterial3D
var _static_tex: ImageTexture
var _rider_holder: Node3D
var _lurker_holder: Node3D
var _cabin_light: OmniLight3D
var _light_color: Color
var _light_energy: float
var _alarm_hit: bool = false
var _version: int = 0
var _passenger: String = ""
## Seu Tião: goes down to clean, and comes back out of the feed alive.
var _cleaner: bool = false
var _floor: int = 0
var _static_time: float = 0.0
var _t: float = 0.0


func setup(owner_scene: Node2D, horror: Node, monitor_holder: Node3D) -> void:
	presentation = owner_scene
	director = horror
	room = presentation.get_node("RoomViewport/Room")
	cabin = room.get_node("Elevators/" + CABIN_NAME)
	_cabin_light = cabin.get_node_or_null("Cabin/Light") as OmniLight3D
	if _cabin_light:
		_light_color = _cabin_light.light_color
		_light_energy = _cabin_light.light_energy
	feed = SubViewport.new()
	feed.name = "ElevatorFeed"
	feed.size = Vector2i(320, 240)
	feed.world_3d = (presentation.get_node("RoomViewport") as SubViewport).find_world_3d()
	feed.render_target_update_mode = SubViewport.UPDATE_DISABLED
	feed.msaa_3d = Viewport.MSAA_DISABLED
	add_child(feed)
	feed_camera = Camera3D.new()
	feed_camera.fov = 78.0
	feed_camera.far = 12.0
	feed.add_child(feed_camera)
	feed_camera.current = true
	_place_camera()
	_static_tex = _make_static()
	# Screen quad in front of the monitor's glass.
	screen = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.44, 0.32)
	screen.mesh = quad
	screen.position = Vector3(0, 0.31, 0.131)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_texture = feed.get_texture()
	_mat.albedo_color = Color(0.78, 1.0, 0.85)
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	screen.material_override = _mat
	monitor_holder.add_child(screen)
	title = _label(monitor_holder, Vector3(-0.1, 0.44, 0.133), 18, "CAM ELEV 01  ● REC")
	floor_label = _label(monitor_holder, Vector3(0.16, 0.19, 0.133), 34, "T")
	_rider_holder = Node3D.new()
	_rider_holder.name = "Rider"
	room.add_child(_rider_holder)
	_lurker_holder = Node3D.new()
	_lurker_holder.name = "Lurker"
	room.add_child(_lurker_holder)
	_show_feed(false)


func _label(parent: Node3D, at: Vector3, size: int, text: String) -> Label3D:
	var label := Label3D.new()
	label.font = FONT_BOLD
	label.font_size = size
	label.pixel_size = 0.0016
	label.outline_size = 6
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.modulate = Color(0.85, 1.0, 0.85)
	label.shaded = false
	label.text = text
	label.position = at
	parent.add_child(label)
	return label


func _place_camera() -> void:
	# Upper corner by the door, looking at the back of the cabin where the passenger stands.
	var eye: Vector3 = cabin.to_global(Vector3(0.95, 2.35, -0.8))
	var look: Vector3 = cabin.to_global(Vector3(-0.15, 1.05, -2.4))
	feed_camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(look, Vector3.UP)


func _make_static() -> ImageTexture:
	var image := Image.create(96, 72, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	for y in 72:
		for x in 96:
			var v := rng.randf()
			image.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(image)


func _show_feed(value: bool) -> void:
	screen.visible = value
	title.visible = value
	floor_label.visible = value
	feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	var dressing = presentation.dressing
	if dressing and dressing.monitor_label:
		dressing.monitor_label.visible = not value
		dressing.monitor_sub.visible = not value


func _figure(holder: Node3D, texture: Texture2D, local: Vector3, tint: Color = Color.WHITE) -> Sprite3D:
	for child in holder.get_children():
		child.queue_free()
	holder.position = room.to_local(cabin.to_global(local))
	holder.position.y = 0.0
	var sprite: Sprite3D = director._sprite_copy(texture)
	sprite.modulate = tint
	holder.add_child(sprite)
	holder.show()
	return sprite


## Starts the ride of the visitor who just boarded (the cabin door is closed behind him).
func start_ride(floor_code: int, texture: Texture2D, passenger: String, takeover: bool, cleaner: bool = false) -> void:
	finish_now()
	_version += 1
	var version := _version
	riding = true
	_alarm_hit = false
	alarm_open = false
	_passenger = passenger
	_floor = floor_code
	_cleaner = cleaner
	_place_camera()
	_figure(_rider_holder, texture, Vector3(0.0, 0.0, -2.1))
	_lurker_holder.hide()
	_show_feed(true)
	_set_floor(0)
	title.text = "CAM ELEV 01  ● REC"
	await _wait(0.6)
	if version != _version:
		return
	if floor_code == -1:
		await _descend(version, false)
		return
	var turn_at := 1 if floor_code > 1 else 0
	var current := 0
	while current < floor_code:
		if takeover and current == turn_at:
			await _descend(version, true)
			if version != _version:
				return
			if not _alarm_hit:
				return
			# Saved: back on track after the emergency stop.
			current = 0
			title.text = "PARADA DE EMERGÊNCIA · retomando"
			_set_floor(0)
			await _wait(1.0)
			if version != _version:
				return
			takeover = false
			continue
		await _wait(0.55)
		if version != _version:
			return
		current += 1
		_set_floor(current)
	await _wait(0.5)
	if version != _version:
		return
	Audio.play_sfx(Audio.CHEGOU_ELEVADOR, -14.0, 1.1)
	_rider_holder.hide()
	await _wait(0.9)
	if version != _version:
		return
	_end("saved" if _alarm_hit else "arrived")


## Going down to S. sabotage: the cabin turned on its own (red light, someone behind the passenger).
func _descend(version: int, sabotage: bool) -> void:
	alarm_open = true
	if sabotage:
		anomaly_started.emit()
		title.text = "!! DESCENDO SOZINHO !!"
		_red_light(true)
		var lurker_texture: Texture2D = Director.MARTA_SPRITE if director.day >= 3 or Director.victims.is_empty() \
			else Director.victims[randi() % Director.victims.size()]
		var lurker := _figure(_lurker_holder, lurker_texture, Vector3(-0.55, 0.0, -2.75), Color(0.25, 0.2, 0.22))
		lurker.shaded = true
		director.ambience.crackle(0.8)
		director.event_heart = 0.8
	else:
		title.text = "▼ SUBSOLO"
	var floors: Array[int] = [_shown_floor()]
	while floors.back() > -1:
		floors.append(floors.back() - 1)
	for i in range(1, floors.size()):
		await _wait(0.95 if sabotage else 0.8)
		if version != _version or _alarm_hit:
			return
		_set_floor(floors[i])
	# Last chance at S before the doors open below.
	await _wait(0.7)
	if version != _version or _alarm_hit:
		return
	alarm_open = false
	if _cleaner:
		# The doors open on the red light; he steps out with his bucket. Nobody is waiting for him.
		_red_light(true)
		title.text = "S · LIMPEZA"
		await _wait(1.4)
		if version != _version:
			return
		_rider_holder.hide()
		await _wait(0.8)
		if version == _version:
			_end("cleaner")
		return
	await _taken(version, sabotage)


func _shown_floor() -> int:
	var text := floor_label.text
	return -1 if text == "S" else (0 if text == "T" else int(text))


func _taken(version: int, sabotage: bool) -> void:
	_red_light(true)
	# She is there when the doors open downstairs.
	var marta_texture: Texture2D = Director.MARTA_BLOODY if director.day >= 2 else Director.MARTA_SPRITE
	_figure(_lurker_holder, marta_texture, Vector3(0.35, 0.0, -1.5), Color(1.0, 0.85, 0.85))
	director.ambience.thump(0.7)
	await _wait(0.55)
	if version != _version:
		return
	_static_time = 0.9
	director.ambience.static_burst(0.9)
	await _wait(0.9)
	if version != _version:
		return
	_rider_holder.hide()
	_lurker_holder.hide()
	_red_light(false)
	director.event_heart = 0.0
	_end("taken" if sabotage else "basement")


## ALARM pressed. Returns true when it stopped a descending cabin.
func press_alarm() -> bool:
	if not riding or not alarm_open:
		return false
	_alarm_hit = true
	alarm_open = false
	_red_light(false)
	_lurker_holder.hide()
	director.event_heart = 0.0
	director.ambience.thump(0.4)
	director.shake(0.3, 0.6)
	if _floor == -1:
		# Sent down by the rules, stopped by the player: back to the ground floor, the passenger walks away.
		_set_floor(0)
		title.text = "PARADA DE EMERGÊNCIA"
		_finish_saved_basement(_version)
	return true


func _finish_saved_basement(version: int) -> void:
	await _wait(1.4)
	if version != _version:
		return
	_rider_holder.hide()
	await _wait(0.6)
	if version == _version:
		_end("saved_basement")


func _red_light(on: bool) -> void:
	if _cabin_light == null:
		return
	_cabin_light.light_color = Color(1.0, 0.08, 0.05) if on else _light_color


func _set_floor(floor_code: int) -> void:
	floor_label.text = director._indicator_text(floor_code)
	floor_label.modulate = Color(1.0, 0.25, 0.2) if floor_code == -1 else Color(0.85, 1.0, 0.85)
	director._set_indicator(CABIN_NAME, floor_code)


func _end(outcome: String) -> void:
	riding = false
	alarm_open = false
	_show_feed(false)
	_red_light(false)
	_rider_holder.hide()
	_lurker_holder.hide()
	var passenger := _passenger
	var floor_code := _floor
	_return_indicator(_version)
	ride_ended.emit(outcome, passenger, floor_code)


func _return_indicator(version: int) -> void:
	var current := _shown_floor() if feed.render_target_update_mode != SubViewport.UPDATE_DISABLED else _indicator_now()
	while current != 0:
		await _wait(0.3)
		if version != _version:
			return
		current += 1 if current < 0 else -1
		director._set_indicator(CABIN_NAME, current)


func _indicator_now() -> int:
	return director._indicator_floor.get(CABIN_NAME, 0)


## The next visitor needs cabin 1: whatever is still running ends now (an open takeover is lost).
func finish_now() -> void:
	if not riding:
		return
	var taken := alarm_open
	_version += 1
	alarm_open = false
	riding = false
	_show_feed(false)
	_red_light(false)
	_rider_holder.hide()
	_lurker_holder.hide()
	director._set_indicator(CABIN_NAME, 0)
	var outcome := "taken" if taken else ("saved" if _alarm_hit else "arrived")
	if _alarm_hit and _floor == -1:
		outcome = "saved_basement"
	ride_ended.emit(outcome, _passenger, _floor)


func _process(delta: float) -> void:
	_t += delta
	if not riding or _mat == null:
		return
	if _static_time > 0.0:
		_static_time -= delta
		_mat.albedo_texture = _static_tex
		_mat.uv1_offset = Vector3(randf(), randf(), 0)
		_mat.albedo_color = Color(0.9, 0.9, 0.9)
	else:
		_mat.albedo_texture = feed.get_texture()
		_mat.uv1_offset = Vector3.ZERO
		var red := alarm_open and fmod(_t, 0.5) < 0.25 and title.text.begins_with("!!")
		_mat.albedo_color = Color(1.0, 0.55, 0.5) if red else Color(0.78, 1.0, 0.85)
	title.modulate = Color(1.0, 0.3, 0.25) if alarm_open else Color(0.85, 1.0, 0.85)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func cancel() -> void:
	_version += 1
	riding = false
	alarm_open = false


func _exit_tree() -> void:
	cancel()
