extends Node3D
## A local instance of the original Dialogue, rendered onto paper in the world.
## screen_space (static, set by the 3D game scene): uses the global Dialogue instead, drawn in the 2D
## canvas at window resolution (sharp text) and placed beside the speaker's head every frame.

## Off by default: the experimental scenes and their tests keep the paper in the world.
static var screen_space: bool = false
## Paper that currently shows its text in the global Dialogue (screen_space only).
static var _screen_owner: Node3D = null

var viewport: SubViewport
var dialogue: CanvasLayer
var paper: Sprite3D
var actor: Node3D
var camera: Camera3D
var modal: bool = false
var _head_height: float = 2.4
var _board: Control
var _board_home: Vector2


func _ready() -> void:
	if screen_space:
		dialogue = get_node("/root/Dialogue") as CanvasLayer
		_board = dialogue.get_node("Board") as Control
		_board_home = _board.position
		hide()
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(189, 113)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = true
	add_child(viewport)
	dialogue = load("res://autoload/dialogue/dialogue.tscn").instantiate()
	viewport.add_child(dialogue)
	dialogue.get_node("Board").position = Vector2.ZERO
	dialogue.set_process_unhandled_input(false)
	paper = Sprite3D.new()
	paper.texture = viewport.get_texture()
	paper.pixel_size = 0.014
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	paper.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	paper.shaded = false
	add_child(paper)
	hide()


func present(entry: Dictionary, visitor: Node3D, sprite: Sprite3D, view_camera: Camera3D) -> void:
	actor = visitor
	camera = view_camera
	var used := sprite.texture.get_image().get_used_rect()
	var head: float = sprite.position.y + (sprite.texture.get_height() * 0.5 - used.position.y) * sprite.pixel_size * sprite.scale.y
	_head_height = head
	position = Vector3(1.55, maxf(2.55, head + 0.35), 0)
	var speech: NPCDialogue = entry.get("dialogue")
	Dialogue.clear_dialogue()
	if screen_space:
		_screen_owner = self
		_place_board()
	dialogue.display_dialogue(entry.get("nome", ""), speech.texto if speech else "")
	show()


func clear() -> void:
	if screen_space:
		# Only the paper that owns the global box may close it (another speaker may be talking).
		if _screen_owner == self:
			_screen_owner = null
			if is_instance_valid(dialogue):
				dialogue.clear_dialogue()
				_board.position = _board_home
		hide()
		return
	if is_instance_valid(dialogue):
		dialogue.clear_dialogue()
	hide()


func forward_input(event: InputEvent) -> void:
	if visible and not modal:
		# RoomView does not forward input. Preserve the original pagination semantics.
		dialogue._unhandled_input(event)
		if event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if screen_space and visible and _screen_owner == self:
		_place_board()


## Balloon to the right of the speaker's head; its tail (left side) points at the face.
func _place_board() -> void:
	if not is_instance_valid(actor) or not is_instance_valid(camera) or _board == null:
		return
	var head_world: Vector3 = actor.global_position + Vector3.UP * (_head_height - 0.25)
	if camera.is_position_behind(head_world):
		return
	var room_view := get_viewport().get_parent().get_node_or_null("RoomView") as Node2D
	if room_view == null:
		return
	var screen: Vector2 = room_view.get_global_transform() * camera.unproject_position(head_world)
	var size: Vector2 = _board.size * _board.scale
	var visible_rect: Rect2 = _board.get_viewport_rect()
	var target := Vector2(screen.x + 26.0, screen.y - size.y * 0.7)
	target.x = clampf(target.x, 6.0, visible_rect.size.x - size.x - 6.0)
	# Upper band of the screen: never over the desk objects or the panel.
	target.y = clampf(target.y, 6.0, maxf(6.0, visible_rect.size.y * 0.42 - size.y))
	_board.position = _board.position.lerp(target, 0.35) if _board.position != _board_home else target


func _exit_tree() -> void:
	clear()
