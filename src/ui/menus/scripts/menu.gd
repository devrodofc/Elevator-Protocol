extends Control

@onready var play_button: LinkButton = $Play
@onready var options_button: LinkButton = $Options
@onready var quit_button: LinkButton = $Quit


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(
        "res://src/levels/reception.tscn"
	)


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file(
        "res://src/ui/menus/scenes/options.tscn"
	)


func _on_quit_pressed() -> void:
	get_tree().quit()
