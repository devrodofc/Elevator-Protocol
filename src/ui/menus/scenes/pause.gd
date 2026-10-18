extends CanvasLayer

@onready var overlay: Control = $Overlay
@onready var continue_button: LinkButton = $Overlay/Continue
@onready var options_button: LinkButton = $Overlay/Options
@onready var main_menu_button: LinkButton = $Overlay/MainMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	overlay.hide()

	continue_button.pressed.connect(resume_game)
	options_button.pressed.connect(open_options)
	main_menu_button.pressed.connect(go_to_main_menu)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				if get_tree().paused:
					resume_game()
				else:
					pause_game()

				get_viewport().set_input_as_handled()

func pause_game() -> void:
	overlay.show()
	get_tree().paused = true

func resume_game() -> void:
	overlay.hide()
	get_tree().paused = false

func go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(
		"res://src/ui/menus/scenes/menu.tscn"
	)

func open_options() -> void:
	pass
