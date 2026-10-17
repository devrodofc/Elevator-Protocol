class_name Visitor
extends Node2D

signal arrived
signal departed

## Instância visual carregada da cena da Clara (PackedScene)
var current_visual_instance: Node = null

@onready var default_sprite: Sprite2D = get_node_or_null("Sprite2D")

@export var current_data: VisitorData:
	set(value):
		current_data = value
		_apply_data(current_data)

@export_group("Movement & Speed Settings")
## Velocidade constante de deslocamento em pixels por segundo
@export var move_speed: float = 250.0

@export_group("Depth & Scale Settings")
## Escala quando o visitante está esperando na fila (menor, ao fundo)
@export var queue_scale: Vector2 = Vector2(0.75, 0.75)
## Escala completa no balcão de atendimento (frente)
@export var desk_scale: Vector2 = Vector2(1.0, 1.0)

@export_group("Step Animation Settings")
@export var step_bob_height: float = 6.0
## Distância em pixels percorrida para completar 1 passo
@export var step_distance: float = 45.0

var is_moving: bool = false
var _active_move_tween: Tween = null
var _active_bob_tween: Tween = null


func _ready() -> void:
	scale = queue_scale
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
		
	if data and data.cena:
		current_visual_instance = data.cena.instantiate()
		add_child(current_visual_instance)
		if default_sprite:
			default_sprite.visible = false
	elif default_sprite:
		default_sprite.visible = true


func get_visitor_name() -> String:
	if current_data:
		return current_data.nome
	return ""


func has_tag(tag_name: String) -> bool:
	if current_data:
		return current_data.has_tag(tag_name)
	return false


func get_tags() -> Array[String]:
	if current_data:
		return current_data.tags
	return []


func move_to_slot(target_pos: Vector2, on_finished: Callable = Callable(), is_desk_slot: bool = false) -> void:
	_kill_tweens()
	
	var target_scale: Vector2 = desk_scale if is_desk_slot else queue_scale
	var distance: float = global_position.distance_to(target_pos)
	
	if distance <= 1.0 or move_speed <= 0.0:
		global_position = target_pos
		scale = target_scale
		is_moving = false
		arrived.emit()
		if on_finished.is_valid():
			on_finished.call()
		return

	var duration: float = distance / move_speed
	is_moving = true
	
	_active_move_tween = create_tween().set_parallel(true)
	_active_move_tween.tween_property(self, "global_position:x", target_pos.x, duration)\
		.set_trans(Tween.TRANS_LINEAR)
	_active_move_tween.tween_property(self, "global_position:y", target_pos.y, duration)\
		.set_trans(Tween.TRANS_LINEAR)
	
	_active_move_tween.tween_property(self, "scale", target_scale, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	_play_step_animation(distance, duration)
	
	_active_move_tween.chain().tween_callback(func():
		is_moving = false
		_reset_bob()
		arrived.emit()
		if on_finished.is_valid():
			on_finished.call()
	)


func leave_to(exit_position: Vector2) -> void:
	_kill_tweens()
	
	var distance: float = global_position.distance_to(exit_position)
	if distance <= 1.0 or move_speed <= 0.0:
		departed.emit()
		queue_free()
		return

	var duration: float = distance / move_speed
	is_moving = true
	
	_active_move_tween = create_tween().set_parallel(true)
	_active_move_tween.tween_property(self, "global_position:x", exit_position.x, duration)\
		.set_trans(Tween.TRANS_LINEAR)
	_active_move_tween.tween_property(self, "global_position:y", exit_position.y, duration)\
		.set_trans(Tween.TRANS_LINEAR)
	
	_play_step_animation(distance, duration)
	
	_active_move_tween.chain().tween_callback(func():
		is_moving = false
		_reset_bob()
		departed.emit()
		queue_free()
	)


## Retorna a instância carregada ou o Sprite2D padrão para animar
func _get_visual_target() -> Node2D:
	if is_instance_valid(current_visual_instance) and current_visual_instance is Node2D:
		return current_visual_instance as Node2D
	
	if default_sprite and is_instance_valid(default_sprite):
		return default_sprite
		
	# Fallback: busca qualquer Sprite2D ou AnimatedSprite2D filho
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child as Node2D
			
	return null


func _play_step_animation(distance: float, duration: float) -> void:
	var visual_node: Node2D = _get_visual_target()
	if visual_node == null:
		return
		
	var cycles: int = maxi(1, int(round(distance / step_distance)))
	var step_time: float = duration / (cycles * 2)
	
	_active_bob_tween = create_tween()
	for i in range(cycles):
		_active_bob_tween.tween_property(visual_node, "position:y", -step_bob_height, step_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_active_bob_tween.tween_property(visual_node, "position:y", 0.0, step_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _reset_bob() -> void:
	var visual_node: Node2D = _get_visual_target()
	if visual_node:
		visual_node.position.y = 0.0


func _kill_tweens() -> void:
	if _active_move_tween and _active_move_tween.is_valid():
		_active_move_tween.kill()
	if _active_bob_tween and _active_bob_tween.is_valid():
		_active_bob_tween.kill()
