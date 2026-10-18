extends Control

const OPTIONS_SCENE := "res://src/ui/menus/scenes/options.tscn"

@onready var back_button: TextureButton = $Back


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE)	
