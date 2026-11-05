extends Node
## Story of the 3D game. The text lives in story_lines.gd; this node runs it.
## Godofredo (grumpy owner, the obvious suspect) disappears on day 3. Marta seems helpful on day 1, protective
## and controlling on day 2, and on day 3 stops pretending. Whoever goes down to the basement does not come back:
## nobody calls from there. Seu Tião, the cleaner, goes down to clean her mess.
##
## Mechanics owned here:
## - PHONE: the desk phone rings; clicking it answers. Godofredo (Marta on day 3) announces by name who may go
##   up to the 6th floor (PhoneRule, validated by the session like Marta's rules). Missing his call = warning.
## - ELEVATOR: every boarding is watched on the desk monitor (elevator_watch.gd); some rides go down on their own.
##   Days 1-2: the ALARM saves the passenger (a false alarm = warning). Day 3: Marta forbids the alarm; pressing it
##   still stops the cabin, but she answers over the speaker and the player gets a warning, every time.
## - WARNINGS: 3 = fired (the day restarts, Marta "fixed it").

const Lines = preload("res://src/gameplay/reception_25d/scripts/story_lines.gd")
const PhoneRule = preload("res://src/gameplay/scripts/phone_rule.gd")
const MartaActorScript = preload("res://src/gameplay/reception_25d/scripts/marta_actor.gd")
const Director = preload("res://src/gameplay/reception_25d/scripts/horror_director.gd")
const GODOFREDO_SPRITE = preload("res://src/npcs/assets/manfredo/manfredo_diretor.png")
const RING_TIMEOUT: float = 22.0
const MAX_WARNINGS: int = 3
## Elevator rides taken over per day; the day-2 visit of Godofredo happens after this many services.
const TAKEOVERS := {1: 1, 2: 2, 3: 3}
const DAY2_VISIT_AT: int = 3

var presentation: Node2D
var day: int = 1
var guard: Resource
var godofredo: MartaActorScript
var warnings: int = 0
var saved: int = 0
var taken: int = 0
var basement: int = 0
var missed: int = 0
## Call ringing or in progress: {caller, lines, kind}.
var call: Dictionary = {}
var call_active: bool = false
var _calls: Array = []
var _ring_time: float = 0.0
var _beat_done: bool = false
var _takeovers_left: int = 0
var _ride_texture: Texture2D
var _marta_comments: Array[String] = []
var _pending_reaction: Dictionary = {}
var _speaker_queue: Array = []
var _day3_alarms: int = 0
var _reactions: int = 0
var _taken_comments: int = 0
var _fired: bool = false
var _rng := RandomNumberGenerator.new()
## Lore calls and the day-2 visit already heard on this day ({"day": n, keys...}): a retry does not repeat them.
## Guest calls always come back (they give the names the rules need).
static var heard: Dictionary = {}


func setup(owner_scene: Node2D) -> void:
	presentation = owner_scene
	day = clampi(presentation.session.day_number, 1, 3)
	_rng.randomize()
	_apply_texts()
	_takeovers_left = TAKEOVERS.get(day, 0)
	_calls = (Lines.CALLS.get(day, []) as Array).duplicate(true)
	if heard.get("day", 0) != day:
		heard = {"day": day}
	godofredo = MartaActorScript.new()
	godofredo.name = "Godofredo"
	godofredo.cabin_name = "Elevator03"
	godofredo.default_sprite = GODOFREDO_SPRITE
	presentation.add_child(godofredo)
	godofredo.setup(presentation)
	var devices = presentation.devices
	devices.phone_clicked.connect(_on_phone_clicked)
	devices.alarm_clicked.connect(_on_alarm_clicked)
	presentation.watch.ride_ended.connect(_on_ride_ended)
	# Days 2 and 3: the 6th-floor rule is already on the clipboard when the shift starts.
	if day >= 2:
		_add_guard()


## The day's messages and Marta's rule lines come from story_lines.gd (in memory only: nothing is saved).
func _apply_texts() -> void:
	var schedule: DayScheduleConfig = presentation.session.schedule_config
	var messages: Dictionary = Lines.DAY_MESSAGES.get(day, {})
	if not messages.is_empty():
		schedule.mensagem_inicio = messages["inicio"]
		schedule.mensagem_fim = messages["fim"]
		schedule.mensagem_falha = messages["falha"]
	var rules: Array = []
	rules.append_array(schedule.regras_marta)
	rules.append_array(schedule.regras_obrigatorias)
	for rule in rules:
		if rule == null:
			continue
		var original: String = rule.get_meta("texto_original", rule.texto_prancheta)
		if not Lines.RULES.has(original):
			continue
		rule.set_meta("texto_original", original)
		var text: Array = Lines.RULES[original]
		rule.fala = text[0]
		if not str(text[1]).is_empty():
			rule.texto_prancheta = text[1]


func _add_guard() -> void:
	if guard:
		return
	var who := "a Marta" if day >= 3 else "o Godofredo"
	# Not on Marta's clipboard (empty text): it is written on the sheet of paper on the desk.
	guard = PhoneRule.guarda("")
	presentation.session.add_extra_rule(guard)
	presentation.note.set_rule("Só sobe quem %s ligar avisando. Os outros: negar." % who)


# --- intro --------------------------------------------------------------------------------------

## Day 1: Godofredo comes down from the 6th floor before Marta and sets his rules.
func intro_before_marta(generation: int) -> bool:
	if day != 1:
		return true
	if not await godofredo.arrive_from_cabin():
		return false
	for i in Lines.GODOFREDO_INTRO_DAY1.size():
		if not await godofredo.speak("Godofredo", Lines.GODOFREDO_INTRO_DAY1[i]):
			return false
		if i == Lines.GODOFREDO_RULE_LINE:
			_add_guard()
			presentation.note.pulse()
	if not presentation._still(generation):
		return false
	return await godofredo.leave_into_cabin()


## Marta's lines before her day message.
func marta_intro_lines() -> Array:
	return (Lines.MARTA_INTRO.get(day, []) as Array).duplicate()


func marta_intro_after() -> Array:
	return []


## Retry after a failure: the 6th-floor rule is back on the clipboard; what was already heard is skipped.
func on_retry() -> void:
	_add_guard()
	var left: Array = []
	for planned in _calls:
		if planned.get("kind") == "guest" or not heard.has(_call_key(planned)):
			left.append(planned)
	_calls = left
	_beat_done = heard.has("beat")


func fired_lines() -> Array:
	return (Lines.FIRED.get(day, []) as Array).duplicate()


# --- day 2 visit ----------------------------------------------------------------------------------

func has_pending_beat() -> bool:
	return day == 2 and not _beat_done and not _fired and presentation.session.served_count >= DAY2_VISIT_AT


## Godofredo comes down to talk to the player; Marta steps in.
func run_beat(generation: int) -> bool:
	_beat_done = true
	heard["beat"] = true
	var desk = presentation.desk
	var director = presentation.director
	var marta = presentation.marta
	desk.set_marta_present(true)
	if not await godofredo.arrive_from_cabin():
		return false
	for step in Lines.DAY2_VISIT:
		match step[0]:
			"G":
				if not await godofredo.speak("Godofredo", step[1]):
					return false
			"M":
				if not await marta.speak("Marta", step[1]):
					return false
			"marta_chega":
				# He steps aside while her cabin climbs from the basement: she takes the counter.
				var side := Marker3D.new()
				side.name = "GodofredoSide"
				presentation.get_node("RoomViewport/Room/VisitorPositions").add_child(side)
				side.position = Vector3(-1.35, 0.0, -1.9)
				godofredo.movement.follow_route([side] as Array[Marker3D])
				await director.marta_incoming()
				while godofredo.movement.is_processing() and presentation._still(generation):
					await get_tree().process_frame
				godofredo.orientation.face_when_idle(godofredo.orientation.camera)
				if not presentation._still(generation) or not await marta.arrive_from_cabin():
					return false
			"godofredo_sai":
				if not await godofredo.leave_into_cabin():
					return false
			"marta_sai":
				if not await marta.leave_into_cabin():
					return false
				director.marta_gone()
		if not presentation._still(generation):
			return false
	desk.set_marta_present(false)
	return presentation._still(generation)


## Lines Marta says when she comes for a rule (what happened since her last visit).
func take_marta_comments() -> Array:
	var lines := _marta_comments.duplicate()
	_marta_comments.clear()
	return lines


# --- phone ---------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if presentation == null or _fired:
		return
	if not call_active and not _speaker_queue.is_empty():
		_play_speaker(_speaker_queue.pop_front())
	if presentation.devices.ringing:
		_ring_time += delta
		if _ring_time >= RING_TIMEOUT:
			_missed_call()
		return
	if call_active or not _can_ring():
		return
	if not _pending_reaction.is_empty():
		_ring(_pending_reaction)
		_pending_reaction = {}
		return
	var served: int = presentation.session.served_count
	for i in _calls.size():
		if served >= _calls[i]["at"]:
			_ring(_calls.pop_at(i))
			return


func _can_ring() -> bool:
	var stage: int = presentation.stage
	var s = presentation.Stage
	return stage in [s.AT_SERVICE, s.WALKING, s.WAITING_FOR_DOOR, s.TO_CABIN, s.WAITING_FOR_CABIN,
		s.ENTERING_CABIN, s.TO_EXIT, s.EXITING, s.CLOSING_EXIT] and not presentation.desk._marta_present


func _ring(next_call: Dictionary) -> void:
	call = next_call
	_ring_time = 0.0
	presentation.devices.set_ringing(true)
	presentation.director.ambience.ringing = true


func _stop_ringing() -> void:
	presentation.devices.set_ringing(false)
	presentation.director.ambience.ringing = false


func _missed_call() -> void:
	_stop_ringing()
	missed += 1
	var from_boss: bool = call.get("caller") == "Godofredo"
	var kind: String = call.get("kind", "lore")
	call = {}
	if from_boss and kind == "guest":
		_warn("Chamada do Godofredo perdida · advertência")
	else:
		presentation.hud.toast("Chamada perdida")


func _on_phone_clicked() -> void:
	if not presentation.devices.ringing or call_active:
		return
	_stop_ringing()
	_answer()


func _call_key(planned: Dictionary) -> String:
	var lines: Array = planned.get("lines", [""])
	return "call:%s:%s" % [planned.get("caller", ""), lines[0] if not lines.is_empty() else ""]


func _answer() -> void:
	call_active = true
	if call.get("kind") != "guest":
		heard[_call_key(call)] = true
	presentation.devices.set_off_hook(true)
	Audio.play_sfx(Audio.BOTAO, -4.0, 0.6)
	var lines: Array = call.get("lines", [])
	var caller: String = call.get("caller", "")
	var nome := ""
	if call.get("kind") == "guest":
		nome = _stage_guest()
		_add_guard()
		var rule = PhoneRule.convidado(guard, nome, "")
		presentation.session.add_extra_rule(rule)
		presentation.note.add_name(nome)
	for line in lines:
		if not await presentation.hud.show_call(caller, str(line).replace("{nome}", nome)):
			break
	if not nome.is_empty():
		presentation.hud.toast("Anotado no papel do 6º andar: %s" % nome)
	presentation.hud.hide_call()
	presentation.devices.set_off_hook(false)
	call_active = false
	call = {}


## Marta over the speaker (day 3): shown at once, no phone to answer.
func _play_speaker(lines: Array) -> void:
	call_active = true
	presentation.director.ambience.static_burst(0.25)
	for line in lines:
		if not await presentation.hud.show_call(Lines.DAY3_ALARM_SPEAKER, str(line), true):
			break
	presentation.hud.hide_call()
	call_active = false


## A visit that has not arrived yet becomes the announced guest (asking for the 6th floor). Sometimes a
## second one asks for the 6th too, without being announced: that one must be denied.
func _stage_guest() -> String:
	var session = presentation.session
	var queue: Array = session.queue_data
	# Names already seen today or repeated in the queue would make the 6th-floor sheet ambiguous.
	var counts: Dictionary = {str(session.current_entry.get("nome", "")): 2}
	for entry in queue:
		var key := str(entry.get("nome", ""))
		counts[key] = counts.get(key, 0) + 1
	var candidates: Array[int] = []
	for i in range(1, queue.size()):
		var entry: Dictionary = queue[i]
		if not entry.get("fixo", false) and not entry.get("caso_regra", false) 				and counts.get(str(entry.get("nome", "")), 0) == 1 and not guard_has(str(entry.get("nome", ""))):
			candidates.append(i)
	if candidates.is_empty():
		# Nobody left to stage: a name that never shows up (whoever asks for the 6th is denied).
		return ["Sr. Albuquerque", "Dona Cecília", "Dr. Fontes"][_rng.randi() % 3]
	var index: int = candidates[mini(_rng.randi() % 2, candidates.size() - 1)]
	var guest: Dictionary = queue[index]
	session.override_upcoming(index, {"dialogue": _sixth_floor_line()})
	# Uninvited copycat later in the queue.
	for j in candidates:
		if j > index + 1 and _rng.randf() < 0.75:
			session.override_upcoming(j, {"dialogue": _sixth_floor_line()})
			break
	return str(guest.get("nome", ""))


func guard_has(name: String) -> bool:
	return guard != null and guard.convidados.has(name)


func _sixth_floor_line() -> NPCDialogue:
	var line := NPCDialogue.new()
	line.texto = Lines.GUEST_LINES[_rng.randi() % Lines.GUEST_LINES.size()]
	line.andar_desejado = 6
	return line


# --- elevator ------------------------------------------------------------------------------------

## The visitor just boarded cabin 1 to floor_code. Decides whether this ride is taken over.
func begin_ride(floor_code: int, texture: Texture2D, passenger: String) -> void:
	_ride_texture = texture
	var visitor: VisitorData = presentation.visit_entry.get("visitor")
	var cleaner: bool = visitor != null and visitor.has_tag("send_to_basement")
	var takeover := false
	if not cleaner and floor_code >= 2 and _takeovers_left > 0 and (day >= 2 or presentation.session.served_count >= 2):
		var remaining: int = presentation.session.queue_data.size() + 1
		takeover = remaining <= _takeovers_left * 2 or _rng.randf() < 0.45
	if takeover:
		_takeovers_left -= 1
	presentation.watch.start_ride(floor_code, texture, passenger, takeover, cleaner)


func _on_alarm_clicked() -> void:
	presentation.director.ambience.alarm(1.4)
	var stopped: bool = presentation.watch.press_alarm()
	if stopped:
		presentation.devices.stop_alarm_flash()
	if day >= 3:
		# She said not to press it. Every press answers back, and costs a warning.
		_speaker_queue.append([Lines.DAY3_ALARM[mini(_day3_alarms, Lines.DAY3_ALARM.size() - 1)]])
		_day3_alarms += 1
		_warn("Advertência da Marta")
		return
	if stopped:
		return
	presentation.hud.toast("Alarme falso!")
	_pending_reaction = (Lines.FALSE_ALARM as Dictionary).duplicate(true)
	_pending_reaction["kind"] = "lore"
	_warn("Alarme falso · advertência")


func _on_ride_ended(outcome: String, passenger: String, _floor: int) -> void:
	presentation.devices.stop_alarm_flash()
	match outcome:
		"saved":
			saved += 1
			presentation.hud.toast("Você salvou %s" % passenger)
			_queue_reaction(Lines.ALARM_SAVED)
		"saved_basement":
			saved += 1
			presentation.hud.toast("Você impediu %s de descer" % passenger)
			_queue_reaction(Lines.ALARM_SAVED_BASEMENT)
		"taken", "basement":
			if outcome == "taken":
				taken += 1
				presentation.hud.toast("%s sumiu no elevador" % passenger)
			else:
				basement += 1
			Director.victims.append(_ride_texture)
			Director.victim_names.append(passenger)
			while Director.victims.size() > 4:
				Director.victims.pop_front()
				Director.victim_names.pop_front()
			if outcome == "taken" and _marta_comments.is_empty() and Lines.MARTA_AFTER_TAKEN.has(day):
				var options: Array = Lines.MARTA_AFTER_TAKEN[day]
				_marta_comments.append(options[mini(_taken_comments, options.size() - 1)])
				_taken_comments += 1


## Reaction call of this day (none on day 3: Marta already answered over the speaker).
func _queue_reaction(by_day: Dictionary) -> void:
	if not by_day.has(day):
		return
	_reactions += 1
	var source: Dictionary = by_day if _reactions == 1 or not Lines.ALARM_REPEAT.has(day) else Lines.ALARM_REPEAT
	_pending_reaction = (source[day] as Dictionary).duplicate(true)
	_pending_reaction["kind"] = "lore"


## The cabin turned back: the dome blinks.
func on_anomaly() -> void:
	presentation.devices.flash_alarm(6.0)
	presentation.director.glitch(0.4)


# --- warnings ------------------------------------------------------------------------------------

func _warn(text: String) -> void:
	warnings += 1
	presentation.hud.toast(text)
	presentation.director.pulse_red(0.4)
	if warnings >= MAX_WARNINGS and not _fired:
		_fired = true
		presentation.call_deferred("_run_fired")


func report_text() -> String:
	var session = presentation.session
	var lines := [
		"RELATÓRIO DO TURNO · DIA %d" % day,
		"",
		"Atendidos: %d" % session.served_count,
		"Salvos pelo alarme: %d" % saved,
		"Mandados ao subsolo: %d" % basement,
		"Desaparecidos no elevador: %d" % taken,
		"Advertências: %d/%d" % [warnings, MAX_WARNINGS],
		"",
		Lines.REPORT_NOTE.get(day, ""),
	]
	return "\n".join(lines)


func cancel() -> void:
	if presentation and is_instance_valid(presentation.devices):
		_stop_ringing()
	call_active = false
