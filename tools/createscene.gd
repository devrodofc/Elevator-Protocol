@tool
extends EditorScript

## Caminho onde a cena final será salva
const SCENE_SAVE_PATH: String = "res://src/gameplay/reception/scenes/reception.tscn"

## Caminhos esperados para as cenas filhas
const VISITOR_SCENE_PATH: String = "res://src/npcs/scenes/visitor.tscn"
const DIALOGUE_UI_PATH: String = "res://src/ui/dialogue_ui.tscn"
const ELEVATOR_PANEL_PATH: String = "res://src/ui/elevator_panel.tscn"
const MANUAL_PANEL_PATH: String = "res://src/ui/manual_panel.tscn"
const SHIFT_SUMMARY_PATH: String = "res://src/ui/shift_summary.tscn"
const RECEPTION_MANAGER_SCRIPT_PATH: String = "res://src/gameplay/reception/scripts/reception_manager.gd"


## Helper que instancia a cena se ela existir, ou cria um placeholder tipado
static func instance_or_placeholder(scene_path: String, node_name: String, fallback_type: String) -> Node:
	if ResourceLoader.exists(scene_path):
		var packed: PackedScene = load(scene_path)
		var instance: Node = packed.instantiate()
		instance.name = node_name
		return instance
	
	# Se a cena ainda não existir no disco, cria um nó provisório
	var fallback: Node = ClassDB.instantiate(fallback_type)
	fallback.name = node_name
	print("[BUILDER] Cena '%s' não encontrada. Criado placeholder do tipo '%s'." % [scene_path, fallback_type])
	return fallback


func _run() -> void:
	print("[BUILDER] Iniciando geração da cena Reception...")

	# 1. Nó Raiz: Reception (Node2D)
	var root: Node2D = Node2D.new()
	root.name = "Reception"
	
	if ResourceLoader.exists(RECEPTION_MANAGER_SCRIPT_PATH):
		var manager_script = load(RECEPTION_MANAGER_SCRIPT_PATH)
		root.set_script(manager_script)
	else:
		push_warning("Script reception_manager.gd não encontrado no caminho padrão. Nó raiz ficará sem script por enquanto.")

	# 2. Background (ColorRect provisório de fundo escuro para game jam)
	var background: ColorRect = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.12, 0.13, 0.15, 1.0)
	background.size = Vector2(1152, 648)
	root.add_child(background)
	background.owner = root

	# 3. Posições de navegação do Visitor (Marker2D)
	var spawn_point: Marker2D = Marker2D.new()
	spawn_point.name = "VisitorSpawnPoint"
	spawn_point.position = Vector2(-150, 420)
	root.add_child(spawn_point)
	spawn_point.owner = root

	var desk_point: Marker2D = Marker2D.new()
	desk_point.name = "VisitorDeskPoint"
	desk_point.position = Vector2(400, 420)
	root.add_child(desk_point)
	desk_point.owner = root

	var exit_point: Marker2D = Marker2D.new()
	exit_point.name = "VisitorExitPoint"
	exit_point.position = Vector2(1300, 420)
	root.add_child(exit_point)
	exit_point.owner = root

	# 4. Instância do Visitante
	var visitor_node: Node = instance_or_placeholder(VISITOR_SCENE_PATH, "VisitorInstance", "Node2D")
	root.add_child(visitor_node)
	visitor_node.owner = root

	# 5. UI Layer (CanvasLayer)
	var canvas_layer: CanvasLayer = CanvasLayer.new()
	canvas_layer.name = "UI_CanvasLayer"
	root.add_child(canvas_layer)
	canvas_layer.owner = root

	# 6. Painéis da UI dentro do CanvasLayer
	var dialogue_ui: Node = instance_or_placeholder(DIALOGUE_UI_PATH, "DialogueUI", "Control")
	canvas_layer.add_child(dialogue_ui)
	dialogue_ui.owner = root

	var elevator_panel: Node = instance_or_placeholder(ELEVATOR_PANEL_PATH, "ElevatorPanel", "Control")
	canvas_layer.add_child(elevator_panel)
	elevator_panel.owner = root

	var manual_panel: Node = instance_or_placeholder(MANUAL_PANEL_PATH, "ManualPanel", "Control")
	canvas_layer.add_child(manual_panel)
	manual_panel.owner = root

	var shift_summary: Node = instance_or_placeholder(SHIFT_SUMMARY_PATH, "ShiftSummary", "Control")
	if shift_summary is CanvasItem:
		shift_summary.visible = false
	canvas_layer.add_child(shift_summary)
	shift_summary.owner = root

	# 7. Feedback de Áudio
	var feedback_audio: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	feedback_audio.name = "FeedbackAudio"
	root.add_child(feedback_audio)
	feedback_audio.owner = root

	# 8. Empacotar e Salvar Cena
	var packed_scene: PackedScene = PackedScene.new()
	var pack_result: Error = packed_scene.pack(root)
	
	if pack_result != OK:
		push_error("Falha ao empacotar a cena Reception. Erro: %d" % pack_result)
		return

	var dir_path: String = SCENE_SAVE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var save_result: Error = ResourceSaver.save(packed_scene, SCENE_SAVE_PATH)
	if save_result == OK:
		print("[BUILDER] Sucesso! Cena salva em: %s" % SCENE_SAVE_PATH)
	else:
		push_error("Falha ao salvar a cena no disco. Erro: %d" % save_result)
