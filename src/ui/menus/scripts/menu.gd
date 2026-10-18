extends Control

const GAME_SCENE := "res://src/levels/scenes/tutorial.tscn" # o tutorial leva para a recepção no fim (ou ao pular)
const OPTIONS_SCENE := "res://src/ui/menus/scenes/options.tscn"

@onready var play_button: TextureButton = $Play
@onready var options_button: TextureButton = $Options
@onready var quit_button: TextureButton = $Quit

func _ready() -> void:
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
	
