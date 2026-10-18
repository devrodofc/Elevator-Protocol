extends Control

signal back_requested

@onready var master_slider: HSlider = $MasterVolume
@onready var music_slider: HSlider = $MusicVolume
@onready var sfx_slider: HSlider = $SFXVolume

@onready var fullscreen_button: LinkButton = $Fullscreen
@onready var back_button: LinkButton = $Back


func _ready() -> void:
	master_slider.value_changed.connect(
		func(value): _set_volume("Master", value)
	)

	music_slider.value_changed.connect(
		func(value): _set_volume("Music", value)
	)

	sfx_slider.value_changed.connect(
		func(value): _set_volume("SFX", value)
	)

	fullscreen_button.pressed.connect(_toggle_fullscreen)
	back_button.pressed.connect(_go_back)
	

	refresh()


func refresh() -> void:
	_load_slider(master_slider, "Master")
	_load_slider(music_slider, "Music")
	_load_slider(sfx_slider, "SFX")


func _load_slider(slider: HSlider, bus_name: String) -> void:
	var bus := AudioServer.get_bus_index(bus_name)

	if bus == -1:
		push_warning("Bus de áudio não encontrado: " + bus_name)
		return

	var volume := 0.0

	if not AudioServer.is_bus_mute(bus):
		volume = db_to_linear(
			AudioServer.get_bus_volume_db(bus)
		) * 100.0

	slider.set_value_no_signal(clampf(volume, 0.0, 100.0))


func _set_volume(bus_name: String, value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)

	if bus == -1:
		return

	if value <= 0.0:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(
			bus,
			linear_to_db(value / 100.0)
		)


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED
		)
	else:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN
		)


func _go_back() -> void:
	back_requested.emit()
