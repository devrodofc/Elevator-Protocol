extends Control

## Tutorial 3D (abre a recepção 3D no fim). O tutorial 2D antigo continua em src/gameplay/tutorial/.
const GAME_SCENE := "res://src/gameplay/reception_25d/scenes/tutorial_3d.tscn"
const OPTIONS_SCENE := "res://src/ui/menus/scenes/options.tscn"

@onready var play_button: TextureButton = $Play
@onready var options_button: TextureButton = $Options
@onready var quit_button: TextureButton = $Quit

func _ready() -> void:
	preload("res://src/ui/menus/scripts/menu_qr_code.gd").ensure_visible(get_tree())
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	Audio.stop_music() # voltando do jogo (pause → menu principal)
	MusicMenu.play_if_stopped()

func _on_play_pressed() -> void:
	MusicMenu.stop_music()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()
	
