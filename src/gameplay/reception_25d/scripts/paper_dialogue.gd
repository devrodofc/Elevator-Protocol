extends Node3D
## A local instance of the original Dialogue, rendered onto paper in the world.
var viewport: SubViewport
var dialogue: CanvasLayer
var paper: Sprite3D
var actor: Node3D
var camera: Camera3D
var modal: bool = false


func _ready() -> void:
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
	position = Vector3(1.55, maxf(2.55, head + 0.35), 0)
	var speech: NPCDialogue = entry.get("dialogue")
	Dialogue.clear_dialogue()
	dialogue.display_dialogue(entry.get("nome", ""), speech.texto if speech else "")
	show()


func clear() -> void:
	if is_instance_valid(dialogue):
		dialogue.clear_dialogue()
	hide()


func forward_input(event: InputEvent) -> void:
	if visible and not modal:
		# RoomView does not forward input. Preserve the original pagination semantics.
		dialogue._unhandled_input(event)
		if event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	clear()
