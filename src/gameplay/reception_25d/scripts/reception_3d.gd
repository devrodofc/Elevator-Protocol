extends "res://src/gameplay/reception_25d/scripts/reception_presentation.gd"
## The game's reception, in 3D (main flow: menu → tutorial_3d → reception_3d, days 1 → 2 → 3 → end screen).
## Built on the tested 2.5D presentation (session, rules, Marta, departures); this layer adds:
## - full-resolution 3D, fixed world-space speech, a 2D HUD and gameplay camera controls;
## - the desk dressed with the HUD art (desk_dressing.gd) and the horror layer (horror_director.gd);
## - the failure jump scare, the end of day with the indicator rising from the basement, the final scene;
## - tutorial_mode: the tutorial script played in the same room; F9 skips the day (test hack, like the 2D).

const PaperScript = preload("res://src/gameplay/reception_25d/scripts/paper_dialogue.gd")
const DressingScript = preload("res://src/gameplay/reception_25d/scripts/desk_dressing.gd")
const DirectorScript = preload("res://src/gameplay/reception_25d/scripts/horror_director.gd")
const HudScript = preload("res://src/gameplay/reception_25d/scripts/screen_hud.gd")
const DevicesScript = preload("res://src/gameplay/reception_25d/scripts/desk_devices.gd")
const WatchScript = preload("res://src/gameplay/reception_25d/scripts/elevator_watch.gd")
const StoryScript = preload("res://src/gameplay/reception_25d/scripts/story_director.gd")
const NoteScript = preload("res://src/gameplay/reception_25d/scripts/sixth_floor_note.gd")
const GAME_SCENE := "res://src/gameplay/reception_25d/scenes/reception_3d.tscn"
const Lines = preload("res://src/gameplay/reception_25d/scripts/story_lines.gd")
const SKIP_DAY_KEY := KEY_F9
## Camera framing of the game (the experimental scenes keep theirs).
const CAMERA_PITCH_DEG: float = -14.0
const CAMERA_POSITION := Vector3(0.0, 1.62, 2.4)

## Plays tutorial_intro.tres in this room instead of a day, then opens Day 1.
@export var tutorial_mode: bool = false
## Time the alarm remains down, excluding its press and return animations.
@export_range(0.0, 60.0, 0.1, "or_greater", "suffix:s") var alarm_hold_seconds: float = 5.0

var dressing: DressingScript
var director: DirectorScript
var hud: HudScript
var devices: DevicesScript
var watch: WatchScript
var story: StoryScript
var note: NoteScript
var _last_floor: int = 0
var _day_total: int = 0
var _tutorial_done: bool = false
var _scare_point: Marker3D
var _names: Dictionary = {}
## Day that failed (wrong floor or fired): its reload skips the intro and goes straight to the visitors.
static var _retry_day: int = 0
var retrying: bool = false


func _ready() -> void:
	PaperScript.screen_space = false
	_setup_view()
	visual.shaded = true
	# Human size (the 256 px art at 0.01 m/px made everyone ~2.3 m tall) and no odd sprite shadows.
	visual.pixel_size = 0.0084
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orientation.allow_mode_key = false
	var debug := get_node_or_null("DebugFreeCamera")
	if debug:
		debug.enable_debug_exploration = false
	if tutorial_mode:
		_ready_tutorial()
		return
	super()
	_finish_setup()


func _setup_view() -> void:
	var view: SubViewport = $RoomViewport
	view.msaa_3d = Viewport.MSAA_2X
	view.audio_listener_enable_3d = true
	($RoomView as Sprite2D).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_apply_resolution()
	get_tree().root.size_changed.connect(_apply_resolution)
	var camera: Camera3D = $RoomViewport/Room/ReceptionCamera
	camera.position = CAMERA_POSITION
	camera.rotation.x = deg_to_rad(CAMERA_PITCH_DEG)
	camera._base_pitch = camera.rotation.x
	camera.keyboard_look = true
	camera.edge_width = 0.035
	camera.rotation_limit = 62.0
	camera.rotation_speed = 80.0
	camera.far = 60.0


## The 3D renders at the window's real size (not 640x360): sharp geometry and 3D text.
func _apply_resolution() -> void:
	var window := Vector2(get_tree().root.size)
	var factor := clampf(minf(window.x / 640.0, window.y / 360.0), 1.0, 4.0)
	var size := Vector2i(roundi(640.0 * factor), roundi(360.0 * factor))
	($RoomViewport as SubViewport).size = size
	($RoomView as Sprite2D).scale = Vector2(640.0 / size.x, 360.0 / size.y)


func _create_desk() -> void:
	super()
	dressing = DressingScript.new()
	dressing.name = "DeskDressing"
	add_child(dressing)
	dressing.dress(self, desk)
	devices = DevicesScript.new()
	devices.name = "DeskDevices"
	add_child(devices)
	devices.alarm_hold_seconds = alarm_hold_seconds
	devices.cabin_occupied = _has_elevator_occupant
	devices.dialogue_active = _alarm_dialogue_active
	devices.build($RoomViewport/Room)
	note = NoteScript.new()
	note.name = "SixthFloorNote"
	add_child(note)
	note.build($RoomViewport/Room)
	_names = {desk.book: "Livro de andares", desk.clipboard: "Regras do dia", desk.badge: "Crachá do visitante",
		desk.confirm: "Confirmar", devices.phone: "Telefone", devices.alarm: "ALARME do elevador",
		note.body: "Quem pode subir ao 6º andar"}
	for code in desk.buttons:
		_names[desk.buttons[code]] = "Negar acesso" if code == 999 else ("Subsolo" if code == -1 else "%dº andar" % code)


func _finish_setup() -> void:
	var room: Node3D = $RoomViewport/Room
	_scare_point = Marker3D.new()
	_scare_point.name = "ScarePoint"
	room.get_node("VisitorPositions").add_child(_scare_point)
	_scare_point.position = Vector3(0.0, 0.0, -0.3)
	director = DirectorScript.new()
	director.name = "HorrorDirector"
	add_child(director)
	director.setup(self)
	hud = HudScript.new()
	hud.name = "ScreenHUD"
	add_child(hud)
	watch = WatchScript.new()
	watch.name = "ElevatorWatch"
	add_child(watch)
	watch.setup(self, director, dressing.monitor_screen.get_parent())
	if not tutorial_mode:
		story = StoryScript.new()
		story.name = "Story"
		add_child(story)
		story.setup(self)
		watch.anomaly_started.connect(story.on_anomaly)
	_day_total = session.queue_data.size()
	if not rule_announced.is_connected(_on_rule_announced):
		rule_announced.connect(_on_rule_announced)
	var indicator := get_node_or_null("ElevatorUI/ExplorationIndicator") as CanvasItem
	if indicator:
		indicator.hide()


func _alarm_dialogue_active() -> bool:
	if marta and marta.paper and marta.paper.visible:
		return true
	return story != null and story.godofredo.paper.visible


func _has_elevator_occupant() -> bool:
	if not is_inside_tree() or stage in [Stage.CANCELLED, Stage.UNSUPPORTED, Stage.LEAVING_SCENE]:
		return false
	if watch and watch.has_passenger():
		return true
	# Only the session's visitor boards through I4; named actors use separate MartaActor instances.
	return stage == Stage.ENTERING_CABIN and _route_finished(cabin.cabin_stop_point)


func _process(delta: float) -> void:
	super(delta)
	if hud == null or desk == null:
		return
	# A consultation (book, rules, badge) hides the speech balloon instead of fighting it for space.
	var papers: Array = [desk.paper]
	if marta:
		papers.append(marta.paper)
	if story:
		papers.append(story.godofredo.paper)
	for balloon in papers:
		var board: CanvasItem = balloon.dialogue.get_node("Board")
		var target_alpha := 0.0 if not desk.modal.kind.is_empty() else 1.0
		board.modulate.a = move_toward(board.modulate.a, target_alpha, delta * 8.0)
	var hovered: Node = desk.picker.hovered if is_instance_valid(desk.picker.hovered) else null
	hud.set_tooltip(_names.get(hovered, "") if hovered else "")
	$RoomViewport/Room/ReceptionCamera.edge_hold = hovered != null
	if tutorial_mode:
		return
	var status: String = desk.status.text
	if stage == Stage.LEAVING_SCENE or (desk._marta_present and not marta.ground.visible and not story.godofredo.ground.visible):
		status = ""
	if desk._marta_present and story.godofredo.ground.visible and not marta.ground.visible:
		status = "O Godofredo está falando  ·  [Espaço] continuar"
	if watch.alarm_open:
		var alone: bool = watch.title.text.begins_with("!!")
		if session.day_number >= 3:
			# Marta forbade the alarm: the bar no longer tells the player to press it.
			status = "O elevador está descendo sozinho." if alone else "Elevador descendo ao subsolo."
		else:
			status = "O elevador está descendo sozinho!  Aperte o ALARME." if alone \
				else "Elevador descendo ao subsolo  ·  ALARME para impedir"
	elif devices.ringing:
		status = "O telefone está tocando  ·  clique nele para atender"
	hud.set_status(status)
	hud.set_warnings(story.warnings, story.MAX_WARNINGS)
	# The next boarding needs cabin 1: a ride still running ends now.
	if stage == Stage.TO_CABIN and watch.riding:
		watch.finish_now()
	hud.set_day("DIA %d   ·   Atendidos %d/%d" % [session.day_number, session.served_count, _day_total])


# --- day flow (horror versions of the presentation's beats) ------------------------------------

## Each day starts in the dark: the lamps stutter on before Marta comes in.
func _run_intro() -> void:
	stage = Stage.MARTA
	var generation: int = session.generation
	await get_tree().process_frame
	if not _still(generation) or director == null:
		return
	retrying = _retry_day == session.day_number
	_retry_day = 0
	if retrying:
		_skip_intro(generation)
		return
	desk.set_marta_present(true)
	await director.lights_on()
	if not _still(generation):
		return
	if not await story.intro_before_marta(generation) or not _still(generation):
		return
	if not await marta.arrive_from_entrance(_door, _entrance):
		return
	var lines: Array = story.marta_intro_lines()
	lines.append(session.schedule_config.mensagem_inicio)
	lines.append_array(story.marta_intro_after())
	for line in lines:
		if not await marta.speak("Marta", line):
			return
	if not await marta.leave_into_cabin():
		return
	if not _still(generation) or not session.finish_intro(generation):
		return
	director.marta_gone()
	desk.set_marta_present(false)
	_begin_visit()


## Retry after a failure: no lights stutter, no Godofredo or Marta speeches. The day's rules (the 6th-floor
## rule included) are already on the clipboard and the first visitor walks in.
func _skip_intro(generation: int) -> void:
	director.lights_now()
	story.on_retry()
	if not session.finish_intro(generation):
		return
	director.marta_gone()
	desk.set_marta_present(false)
	hud.toast("Dia %d · de novo" % session.day_number, 2.0)
	_begin_visit()


## Before every rule her cabin climbs out of the basement.
func _announce_rule(rule: MartaRule) -> void:
	var generation: int = session.generation
	stage = Stage.MARTA
	desk.set_marta_present(true)
	await director.marta_incoming()
	if not _still(generation):
		return
	if not await marta.arrive_from_cabin():
		return
	for line in story.take_marta_comments():
		if not await marta.speak("Marta", line):
			return
	if not await marta.speak("Marta", rule.fala):
		return
	if not _still(generation) or not session.activate_pending_rule(generation, rule):
		return
	rule_announced.emit(rule)
	desk.flash_rules(1.8)
	if not await marta.leave_into_cabin():
		return
	if not _still(generation) or not session.finish_rule(generation, rule):
		return
	director.marta_gone()
	desk.set_marta_present(false)
	_begin_visit()


## Story beats (Godofredo's visit on day 2) happen between visits, like Marta's rules.
func _begin_visit() -> bool:
	if story and story.has_pending_beat() and stage not in [Stage.CANCELLED, Stage.LEAVING_SCENE]:
		_run_beat_then_visit()
		return true
	return super()


func _run_beat_then_visit() -> void:
	var generation: int = session.generation
	stage = Stage.MARTA
	if not await story.run_beat(generation) or not _still(generation):
		return
	super._begin_visit()


func _on_rule_announced(rule: MartaRule) -> void:
	director.flicker(0.35, 0.6, true)
	director.glitch(0.35)
	if "câmera" in rule.texto_prancheta.to_lower():
		director._set_monitor("SORRIA.", "", Color(1.0, 0.25, 0.2), 4.0)


func _on_decision_processed(result: Dictionary) -> void:
	if result.get("visit_id") == visit_id and result.get("correct", false):
		_last_floor = result.get("floor_code", 0)
	super(result)


func _release() -> void:
	if stage == Stage.ENTERING_CABIN and story:
		# The ride is watched on the desk monitor while the next visitor comes in.
		story.begin_ride(_last_floor, visual.source_texture, str(visit_entry.get("nome", "")))
	super()


## Three warnings: Godofredo fires you... and Marta "gets your job back". The same day starts over.
func _run_fired() -> void:
	if stage in [Stage.LEAVING_SCENE, Stage.CANCELLED, Stage.FAILING, Stage.CONCLUDING]:
		return
	var generation: int = session.generation
	stage = Stage.FAILING
	desk.set_marta_present(true)
	watch.cancel()
	await director.flicker(0.6, 0.9)
	if not _still(generation):
		return
	actor.hide()
	await director.marta_incoming()
	if not await marta.arrive_from_cabin(MartaActor.ANGER_SPRITE):
		return
	for line in story.fired_lines():
		if not await marta.speak("Marta", line):
			return
	if not _still(generation):
		return
	dia_em_andamento = session.schedule_config
	_retry_day = session.day_number
	stage = Stage.LEAVING_SCENE
	session.begin_transition()
	get_tree().reload_current_scene()


## Wrong floor: the lights die, the visitor is gone, and Marta is right at the counter when they return.
## Day 1 is gentle (everything still looks normal): the visitor leaves and Marta comes to talk.
func _run_failure() -> void:
	if session.day_number == 1:
		_run_gentle_failure()
		return
	var generation: int = session.generation
	stage = Stage.FAILING
	Audio.play_sfx(Audio.ERRO)
	desk.set_marta_present(true)
	director.flicker(0.7, 0.6, true)
	await get_tree().create_timer(0.9, false).timeout
	if not _still(generation):
		return
	Audio.fade_out_music(0.25)
	director.light_level = 0.0
	director.ambience.hum_level = 0.0
	director.ambience.crackle(1.3)
	director.event_heart = 0.9
	director.ambience.heartbeat_bpm = 110.0
	actor.hide()
	await get_tree().create_timer(1.5, false).timeout
	if not _still(generation):
		return
	marta.movement.reset_at(_scare_point)
	marta.sprite.apply_visit_texture(MartaActor.ANGER_SPRITE)
	marta.orientation.face_when_idle(marta.orientation.camera)
	marta.ground.show()
	director.light_level = 1.0
	director.scare_impact()
	var red: ColorRect = effects._overlay(Color(0.7, 0.0, 0.0, 0.0))
	var tint := create_tween()
	tint.tween_property(red, "color:a", 0.22, 0.25)
	await get_tree().create_timer(0.9, false).timeout
	if not _still(generation):
		return
	director.event_heart = 0.6
	if not await marta.speak("Marta", session.schedule_config.mensagem_falha, 6.0):
		return
	if not _still(generation):
		return
	dia_em_andamento = session.schedule_config
	_retry_day = session.day_number
	stage = Stage.LEAVING_SCENE
	session.begin_transition()
	get_tree().reload_current_scene()


func _run_gentle_failure() -> void:
	var generation: int = session.generation
	stage = Stage.FAILING
	Audio.play_sfx(Audio.ERRO)
	desk.set_marta_present(true)
	await get_tree().create_timer(0.8, false).timeout
	if not _still(generation):
		return
	# The visitor goes back the way he came; then Marta's cabin comes up.
	stage = Stage.TO_EXIT
	orientation.face_when_idle(null)
	_door.open()
	_follow([$RoomViewport/Room/VisitorPositions/QueueJoinPoint as Marker3D, _entrance])
	var retreat_z: float = ($RoomViewport/Room/ElevatorRoutes/RetreatPoint as Marker3D).global_position.z
	while actor.visible and actor.global_position.z > retreat_z - 0.5:
		await get_tree().process_frame
		if not _still(generation):
			return
	await director.marta_incoming()
	if not _still(generation) or not await marta.arrive_from_cabin():
		return
	if not await marta.speak("Marta", session.schedule_config.mensagem_falha, 6.0):
		return
	if not _still(generation):
		return
	dia_em_andamento = session.schedule_config
	_retry_day = session.day_number
	stage = Stage.LEAVING_SCENE
	session.begin_transition()
	get_tree().reload_current_scene()


## End of day: as the presentation (suspense, Marta's end sprite, red stare), plus the basement indicator
## and, after the last day, the people who went down waiting in the dark.
func _run_conclusion() -> void:
	var generation: int = session.generation
	var schedule: DayScheduleConfig = session.schedule_config
	stage = Stage.CONCLUDING
	actor.hide()
	desk.set_marta_present(true)
	var escuro: ColorRect = null
	if schedule.suspense_antes_do_fim > 0.0:
		director.flicker(1.2, 0.9)
		escuro = await effects.apagar_luzes(schedule.suspense_antes_do_fim, schedule.som_no_escuro)
		if not _still(generation):
			return
		director.light_level = 0.35
	await director.marta_incoming()
	if not _still(generation):
		return
	if not await marta.arrive_from_cabin(null, schedule.sprite_marta_fim):
		return
	if escuro and schedule.som_no_escuro:
		effects.stare_red(escuro)
		director.pulse_red(0.9)
		await get_tree().create_timer(1.8, false).timeout
		if not _still(generation):
			return
	elif escuro:
		effects.dim_partial(escuro)
	if not session.has_next_day():
		marta.speak("Marta", schedule.mensagem_fim)
		return
	if not await marta.speak("Marta", schedule.mensagem_fim):
		return
	if not _still(generation):
		return
	var proximo: DayScheduleConfig = schedule.proximo_dia
	if story:
		marta.ground.hide()
		await hud.show_report(story.report_text())
		if not _still(generation):
			return
	if proximo == null:
		await _finale(generation)
		if not _still(generation):
			return
	dia_em_andamento = proximo
	stage = Stage.LEAVING_SCENE
	session.begin_transition()
	SceneTransition.transition_to(scene_file_path if proximo else schedule.cena_final,
		"Dia %d" % proximo.dia_numero if proximo else "")


## Last day: the lights go out and Marta's cabin descends with you watching; the ones you sent down wait.
func _finale(generation: int) -> void:
	await director.flicker(0.8, 1.0)
	if not _still(generation):
		return
	director.light_level = 0.12
	director.event_heart = 1.0
	director.ambience.heartbeat_bpm = 120.0
	marta.ground.hide()
	director.travel("Elevator02", -1, false)
	await get_tree().create_timer(2.6, false).timeout
	if not _still(generation):
		return
	marta.movement.reset_at(_scare_point)
	marta.sprite.apply_visit_texture(DirectorScript.MARTA_BLOODY)
	marta.ground.show()
	director.light_level = 0.7
	director.scare_impact()
	await get_tree().create_timer(0.35, false).timeout
	director.light_level = 0.0
	marta.ground.hide()
	await get_tree().create_timer(1.2, false).timeout


# --- tutorial --------------------------------------------------------------------------------------

func _ready_tutorial() -> void:
	MusicMenu.stop_music()
	Audio.stop_music()
	dia_em_andamento = null
	_retry_day = 0
	DirectorScript.victims.clear()
	DirectorScript.victim_names.clear()
	_incoming_transition = SceneTransition.is_busy()
	actor.hide()
	session.start_day(DAYS[0])
	_session_generation = session.generation
	_door = $RoomViewport/Room/Entrances/EntranceLeft
	_entrance = $RoomViewport/Room/VisitorPositions/EntranceLeft
	_create_desk()
	Dialogue.clear_dialogue()
	marta = MartaActor.new()
	marta.name = "Marta"
	add_child(marta)
	marta.setup(self)
	effects = Effects.new()
	effects.name = "Effects"
	add_child(effects)
	effects.setup(self)
	_finish_setup()
	var pause := get_node_or_null("Pause")
	if pause:
		pause.queue_free()
	hud.skip_label.show()
	hud.set_day("")
	hud.narration.show()
	_run_tutorial()


func _run_tutorial() -> void:
	var generation: int = session.generation
	desk.set_marta_present(true)
	for step in Lines.TUTORIAL:
		var falante: String = step[0]
		var texto: String = step[1]
		if _tutorial_done or not _still(generation):
			return
		if falante.is_empty():
			await hud.show_narration(texto)
			continue
		if hud.narration.visible:
			hud.narration_label.text = ""
			hud.narration_hint.text = ""
			await director.lights_on()
			await hud.hide_narration(0.9)
			if _tutorial_done:
				return
			hud.set_status("[Espaço] continuar   ·   clique no livro ou na prancheta para consultar")
			hud._hint_time = 14.0
			if not await marta.arrive_from_entrance(_door, _entrance):
				return
		_tutorial_highlight(step[2])
		if not await marta.speak(falante, texto):
			return
	if _tutorial_done or not _still(generation):
		return
	# Day 1 must feel normal: she just goes back to work, down her elevator.
	dressing.highlight("")
	if not await marta.leave_into_cabin():
		return
	director.marta_gone()
	await get_tree().create_timer(0.8, false).timeout
	_finish_tutorial()


func _tutorial_highlight(destaque: int) -> void:
	var kinds := ["", "", "book", "rules", "badge", "panel"]
	var kind: String = kinds[clampi(destaque, 0, kinds.size() - 1)]
	dressing.highlight(kind)
	if kind == "badge":
		desk.badge.show()


func _finish_tutorial() -> void:
	if _tutorial_done:
		return
	_tutorial_done = true
	hud._advance = true
	Audio.stop_loop()
	Dialogue.clear_dialogue()
	SceneTransition.transition_to(GAME_SCENE, "Dia 1")


# --- keys ------------------------------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if tutorial_mode and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_finish_tutorial()
	elif not tutorial_mode and key.keycode == SKIP_DAY_KEY:
		get_viewport().set_input_as_handled()
		_skip_day()


## Test hack (same as the 2D F9): ends the day now and opens the next one (or the end screen).
func _skip_day() -> void:
	if SceneTransition.is_busy() or get_tree().paused or stage == Stage.LEAVING_SCENE:
		return
	var schedule: DayScheduleConfig = session.schedule_config
	var proximo: DayScheduleConfig = schedule.proximo_dia
	dia_em_andamento = proximo
	stage = Stage.LEAVING_SCENE
	session.begin_transition()
	Dialogue.clear_dialogue()
	SceneTransition.transition_to(scene_file_path if proximo else schedule.cena_final,
		"Dia %d" % proximo.dia_numero if proximo else "")


func _exit_tree() -> void:
	super()
	PaperScript.screen_space = false
	var board := Dialogue.get_node_or_null("Board") as CanvasItem
	if board:
		board.modulate.a = 1.0
