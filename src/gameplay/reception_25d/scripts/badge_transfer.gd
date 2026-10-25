extends Node
signal delivered
const Interactable = preload("res://src/gameplay/reception_25d/scripts/desk_interactable.gd")
var badge: Interactable
var target: Marker3D
var actor: Node3D
var visit_id: String
var delivering: bool = false
var collecting: bool = false
var _motion: Tween
var _version: int = 0


func deliver(id: String) -> void:
	cancel()
	visit_id = id
	delivering = true
	badge.show()
	badge.global_position = actor.global_position + Vector3(0, 1.45, 0.2)
	badge.rotation = Vector3(PI * 0.5, 0, 0)
	var version := _version
	_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(badge, "global_position", target.global_position + target.global_basis.y * 0.42, 0.4)
	_motion.parallel().tween_property(badge, "rotation", Vector3.ZERO, 0.55)
	_motion.tween_property(badge, "global_position", target.global_position, 0.25)
	_motion.tween_callback(func():
		if version != _version:
			return
		delivering = false
		badge.set_available(true)
		delivered.emit()
	)


func collect(id: String) -> void:
	if id != visit_id or collecting or not badge.visible:
		return
	if _motion:
		_motion.kill()
	_version += 1
	delivering = false
	collecting = true
	badge.set_available(false)
	_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(badge, "global_position", target.global_position + target.global_basis.y * 0.42, 0.2)
	_motion.tween_property(badge, "global_position", actor.global_position + Vector3(0, 1.45, 0.2), 0.45)
	_motion.parallel().tween_property(badge, "rotation:x", PI * 0.5, 0.45)
	_motion.tween_callback(func():
		badge.hide()
		collecting = false
	)


func cancel() -> void:
	_version += 1
	if _motion:
		_motion.kill()
	delivering = false
	collecting = false
	if is_instance_valid(badge):
		badge.set_available(false)
		badge.hide()


func _exit_tree() -> void:
	cancel()
