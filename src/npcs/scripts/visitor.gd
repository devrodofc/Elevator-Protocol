class_name Visitor
extends Node2D

signal arrived
signal departed

## Referência ao nó visual atualmente instanciado
var current_visual_instance: Node = null

@export var current_data: VisitorData:
	set(value):
		current_data = value
		_apply_data(current_data)

@export_group("Movement & Speed Settings")
## Velocidade constante de deslocamento em pixels por segundo
@export var move_speed: float = 250.0

@export_group("Step Animation Settings")
@export var step_bob_height: float = 6.0
## Distância em pixels percorrida para completar 1 passo (bobbing completo)
@export var step_distance: float = 50.0

var is_moving: bool = false


func _ready() -> void:
	if current_data:
		_apply_data(current_data)


func setup(data: VisitorData) -> void:
	current_data = data


func _apply_data(data: VisitorData) -> void:
	if not is_node_ready():
		return
		
	if is_instance_valid(current_visual_instance):
		current_visual_instance.queue_free()
		current_visual_instance = null
		
	if data and data.animation_scene:
		current_visual_instance = data.animation_scene.instantiate()
		add_child(current_visual_instance)


func get_dialogue_text() -> String:
	if current_data:
		return current_data.get_full_dialogue()
	return ""


func get_visitor_name() -> String:
	if current_data:
		return current_data.visitor_name
	return ""


func has_tag(tag_name: String) -> bool:
	if current_data:
		return current_data.has_tag(tag_name)
	return false


func get_tags() -> Array[String]:
	if current_data:
		return current_data.tags
	return []


## Move o visitante com velocidade constante até uma posição da fila
func move_to_slot(target_pos: Vector2, on_finished: Callable = Callable()) -> void:
	var distance: float = global_position.distance_to(target_pos)
	if distance <= 1.0 or move_speed <= 0.0:
		global_position = target_pos
		if on_finished.is_valid():
			on_finished.call()
		return

	var duration: float = distance / move_speed
	is_moving = true
	
	# Usamos TRANS_LINEAR para manter a velocidade 100% constante
	var move_tween: Tween = create_tween().set_parallel(true)
	move_tween.tween_property(self, "global_position:x", target_pos.x, duration)\
		.set_trans(Tween.TRANS_LINEAR)
	move_tween.tween_property(self, "global_position:y", target_pos.y, duration)\
		.set_trans(Tween.TRANS_LINEAR)
	
	_play_step_animation(distance, duration)
	
	move_tween.chain().tween_callback(func():
		is_moving = false
		_reset_bob()
		if on_finished.is_valid():
			on_finished.call()
	)


## Despede o visitante da recepção com velocidade constante
func leave_to(exit_position: Vector2) -> void:
	var distance: float = global_position.distance_to(exit_position)
	if distance <= 1.0 or move_speed <= 0.0:
		departed.emit()
		queue_free()
		return

	var duration: float = distance / move_speed
	is_moving = true
	
	var move_tween: Tween = create_tween().set_parallel(true)
	move_tween.tween_property(self, "global_position:x", exit_position.x, duration)\
		.set_trans(Tween.TRANS_LINEAR)
	move_tween.tween_property(self, "global_position:y", exit_position.y, duration)\
		.set_trans(Tween.TRANS_LINEAR)
	
	_play_step_animation(distance, duration)
	
	move_tween.chain().tween_callback(func():
		is_moving = false
		_reset_bob()
		departed.emit()
		queue_free()
	)


## Anima os passos com base na distância real percorrida
func _play_step_animation(distance: float, duration: float) -> void:
	if not is_instance_valid(current_visual_instance) or not (current_visual_instance is Node2D):
		return
		
	var visual_node: Node2D = current_visual_instance as Node2D
	var cycles: int = maxi(1, int(round(distance / step_distance)))
	var step_time: float = duration / (cycles * 2)
	
	var bob_tween: Tween = create_tween()
	for i in range(cycles):
		bob_tween.tween_property(visual_node, "position:y", -step_bob_height, step_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		bob_tween.tween_property(visual_node, "position:y", 0.0, step_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _reset_bob() -> void:
	if is_instance_valid(current_visual_instance) and current_visual_instance is Node2D:
		(current_visual_instance as Node2D).position.y = 0.0
