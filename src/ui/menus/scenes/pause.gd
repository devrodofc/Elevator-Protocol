extends CanvasLayer

const MAIN_MENU_PATH := "res://src/ui/menus/scenes/menu.tscn"

@onready var overlay: Control = $Overlay
@onready var options_pause: Control = $OptionsPause

@onready var continue_button: BaseButton = $Overlay/Continue
@onready var options_button: BaseButton = $Overlay/Options
@onready var main_menu_button: BaseButton = $Overlay/MainMenu
@onready var quit_button: BaseButton = $Overlay/Quit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	overlay.hide()
	options_pause.hide()
	options_pause.back_requested.connect(close_options)

	continue_button.pressed.connect(resume_game)
	options_button.pressed.connect(open_options)
	main_menu_button.pressed.connect(go_to_main_menu)
	quit_button.pressed.connect(quit_game)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				if options_pause.visible:
					close_options()
				elif overlay.visible:
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


func open_options() -> void:
	overlay.hide()
	options_pause.refresh()
	options_pause.show()
	get_tree().paused = true


func close_options() -> void:
	options_pause.hide()
	overlay.show()
	get_tree().paused = true


func go_to_main_menu() -> void:
	_hide_global_dialogue()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()


func _hide_global_dialogue() -> void:
	var dialogue = get_node_or_null("/root/Dialogue")

	if dialogue is CanvasLayer or dialogue is CanvasItem:
		dialogue.visible = false
