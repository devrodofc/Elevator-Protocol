extends CanvasLayer
## Screen overlays of the 2D reception (failure red, lights out, red stare, shake) for the 2.5D room.
## Same values as reception_manager.gd; the room image (RoomView) is what shakes.

var presentation: Node2D
var _tweens: Array[Tween] = []
var _version: int = 0


func setup(owner_scene: Node2D) -> void:
	presentation = owner_scene
	# Under ElevatorUI (5) and the desk modals: the room and its PAPER speech darken, consultations do not.
	layer = 4


## Failure: the screen reddens slowly, as in the 2D fail().
func fade_red() -> ColorRect:
	var red := _overlay(Color(0.7, 0.0, 0.0, 0.0))
	_track(create_tween()).tween_property(red, "color:a", 0.15, 3.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return red


## End-of-day suspense: music fades, lights flicker and go out; with a sound, it plays in the dark with a shake.
func apagar_luzes(segundos: float, som: AudioStream = null) -> ColorRect:
	var version := _version
	Audio.fade_out_music(1.2)
	await get_tree().create_timer(1.4 if som else 0.6).timeout
	if version != _version:
		return null
	var escuro := _overlay(Color(0.0, 0.0, 0.02, 0.0))
	# Flickers like a failing lamp, then goes out
	var pisca := _track(create_tween())
	for alvo in [0.55, 0.1, 0.7, 0.2, 0.75, 0.35]:
		pisca.tween_property(escuro, "color:a", alvo, 0.07)
		pisca.tween_interval(randf_range(0.05, 0.2))
	pisca.tween_property(escuro, "color:a", 0.9 if som else 0.7, 0.6)
	await pisca.finished
	if version != _version:
		return null
	if som:
		await get_tree().create_timer(1.0).timeout
		if version != _version:
			return null
		var duracao: float = maxf(som.get_length(), 0.5)
		Audio.play_sfx(som)
		tremer(duracao, 3.0)
		# A faint red in the dark while the sound comes from below
		var brilho := _track(create_tween())
		brilho.tween_property(escuro, "color", Color(0.18, 0.0, 0.0, 0.92), duracao * 0.3)
		brilho.tween_property(escuro, "color", Color(0.0, 0.0, 0.02, 0.9), duracao * 0.7)
		await get_tree().create_timer(duracao).timeout
		if version != _version:
			return null
	await get_tree().create_timer(segundos).timeout
	if version != _version:
		return null
	return escuro


## Day with a sound in the dark: little red light comes back, pulsing while Marta speaks.
func stare_red(escuro: ColorRect) -> void:
	var luz := _track(create_tween())
	luz.tween_property(escuro, "color", Color(0.3, 0.0, 0.0, 0.42), 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	luz.tween_callback(func():
		var pulso := _track(create_tween().set_loops())
		pulso.tween_property(escuro, "color:a", 0.3, 1.1).set_trans(Tween.TRANS_SINE)
		pulso.tween_property(escuro, "color:a", 0.42, 1.1).set_trans(Tween.TRANS_SINE)
	)


## Day without a sound: the light comes back only a little while she speaks.
func dim_partial(escuro: ColorRect) -> void:
	_track(create_tween()).tween_property(escuro, "color:a", 0.25, 1.2)


## Shakes the room image (desk and speech included) with decreasing strength.
func tremer(segundos: float, forca: float) -> void:
	var view: Node2D = presentation.get_node("RoomView")
	var origem: Vector2 = view.position
	var passos: int = maxi(1, int(segundos / 0.05))
	var tween := _track(create_tween())
	for i in passos:
		var f: float = forca * (1.0 - float(i) / passos)
		tween.tween_property(view, "position", origem + Vector2(randf_range(-f, f), randf_range(-f, f)), 0.05)
	tween.tween_property(view, "position", origem, 0.05)


func cancel() -> void:
	_version += 1
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	for child in get_children():
		child.queue_free()
		if child is CanvasItem:
			child.hide()


func _overlay(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween


func _exit_tree() -> void:
	cancel()
