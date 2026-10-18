extends Control

const MENU_SCENE := "res://src/ui/menus/scenes/menu.tscn"
const CREDITS_SCENE := "res://src/ui/menus/scenes/credits.tscn"
const DisplayMode = preload("res://src/ui/menus/scripts/display_mode.gd")

# Botões

@onready var fullscreen_button: LinkButton = $Fullscreen
@onready var credits_button: LinkButton = $Credits
@onready var back_button: TextureButton = $Back

# Sliders

@onready var master_slider: HSlider = $MasterVolume
@onready var music_slider: HSlider = $MusicVolume
@onready var sfx_slider: HSlider = $SFXVolume


func _ready() -> void:
	# Carrega o estado atual das configurações

	_update_fullscreen_text()

	_load_volume(master_slider, "Master")
	_load_volume(music_slider, "Music")
	_load_volume(sfx_slider, "SFX")

	# Conecta os botões

	fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	back_button.pressed.connect(_on_back_pressed)

	# Conecta os sliders

	master_slider.value_changed.connect(
		_on_volume_changed.bind("Master")
	)

	music_slider.value_changed.connect(
		_on_volume_changed.bind("Music")
	)

	sfx_slider.value_changed.connect(
		_on_volume_changed.bind("SFX")
	)


# ==========================================
# MODO DE EXIBIÇÃO
# ==========================================

func _on_fullscreen_pressed() -> void:
	await DisplayMode.cycle(get_tree())
	_update_fullscreen_text()


func _process(_delta: float) -> void:
	_update_fullscreen_text()


func _update_fullscreen_text() -> void:
	fullscreen_button.text = DisplayMode.current_text()


# ==========================================
# VOLUME
# ==========================================

func _load_volume(slider: HSlider, bus_name: String) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)

	if bus_index == -1:
		push_warning("Canal não encontrado: " + bus_name)
		return

	var volume := AudioServer.get_bus_volume_linear(bus_index)

	if AudioServer.is_bus_mute(bus_index):
		volume = 0.0

	slider.set_value_no_signal(volume * 100.0)


func _on_volume_changed(value: float, bus_name: String) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)

	if bus_index == -1:
		push_warning("Canal não encontrado: " + bus_name)
		return

	if value <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)

	else:
		AudioServer.set_bus_mute(bus_index, false)

		AudioServer.set_bus_volume_linear(
			bus_index,
			value / 100.0
		)


# ==========================================
# NAVEGAÇÃO
# ==========================================

func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file(CREDITS_SCENE)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
