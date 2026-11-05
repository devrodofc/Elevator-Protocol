extends CanvasLayer
## One menu-only overlay, retained while the menu scenes replace each other.

const MENU_SCENES := [
	"res://src/ui/menus/scenes/menu.tscn",
	"res://src/ui/menus/scenes/options.tscn",
	"res://src/ui/menus/scenes/credits.tscn",
]


static func ensure_visible(tree: SceneTree) -> void:
	if tree.root.has_node("MenuQrCode"):
		return
	var overlay = load("res://src/ui/menus/scenes/menu_qr_code.tscn").instantiate()
	tree.root.add_child.call_deferred(overlay)


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed()


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.scene_file_path not in MENU_SCENES:
		hide()
		queue_free()
		return
