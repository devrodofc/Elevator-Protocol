extends Control

const OPTIONS_SCENE := "res://src/ui/menus/scenes/options.tscn"

@onready var back_button: TextureButton = $Back


func _ready() -> void:
	preload("res://src/ui/menus/scripts/menu_qr_code.gd").ensure_visible(get_tree())
	back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE)	
