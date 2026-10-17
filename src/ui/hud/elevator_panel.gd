class_name ElevatorPanel
extends Control

signal floor_selected(floor_number: int)

const DENY_CODE: int = 999

@onready var floor_1_button: Button = %Floor1Button
@onready var floor_2_button: Button = %Floor2Button
@onready var floor_3_button: Button = %Floor3Button
@onready var deny_button: Button = %DenyButton

var locked: bool = true


func _ready() -> void:
	if floor_1_button:
		floor_1_button.pressed.connect(func(): _on_button_clicked(1))
	if floor_2_button:
		floor_2_button.pressed.connect(func(): _on_button_clicked(2))
	if floor_3_button:
		floor_3_button.pressed.connect(func(): _on_button_clicked(3))
	if deny_button:
		deny_button.pressed.connect(func(): _on_button_clicked(DENY_CODE))
	
	set_panel_locked(locked)


func set_panel_locked(is_locked: bool) -> void:
	locked = is_locked
	if floor_1_button:
		floor_1_button.disabled = locked
	if floor_2_button:
		floor_2_button.disabled = locked
	if floor_3_button:
		floor_3_button.disabled = locked
	if deny_button:
		deny_button.disabled = locked


func _on_button_clicked(floor_code: int) -> void:
	if locked:
		return
	set_panel_locked(true)
	floor_selected.emit(floor_code)
