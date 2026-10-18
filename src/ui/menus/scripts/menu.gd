extends Control

const GAME_SCENE := "res://src/levels/scenes/tutorial.tscn" # o tutorial leva para a recepção no fim (ou ao pular)
const OPTIONS_SCENE := "res://src/ui/menus/scenes/options.tscn"

@onready var play_button: LinkButton = $Play
@onready var options_button: LinkButton = $Options
@onready var quit_button: LinkButton = $Quit

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()
