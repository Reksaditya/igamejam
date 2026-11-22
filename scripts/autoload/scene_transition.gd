extends CanvasLayer

signal transition_finished(error: Error)

@export_range(0.05, 2.0, 0.05) var fade_seconds: float = 0.35

var _active: bool = false

@onready var _screen: ColorRect = $Screen


func _input(_event: InputEvent) -> void:
	if _active:
		get_viewport().set_input_as_handled()


func is_active() -> bool:
	return _active


func change_scene(destination: String, spawn: StringName) -> void:
	if _active:
		return
	_active = true
	var was_paused := get_tree().paused
	get_tree().paused = true
	_screen.color.a = 0.0
	_screen.show()
	await _fade_to(1.0)
	if not spawn.is_empty():
		get_tree().set_meta(&"side_scroller_spawn", spawn)
	var error := get_tree().change_scene_to_file(destination)
	if error == OK:
		await get_tree().scene_changed
		await get_tree().process_frame
	elif not spawn.is_empty():
		get_tree().remove_meta(&"side_scroller_spawn")
	await _fade_to(0.0)
	_screen.hide()
	get_tree().paused = was_paused
	_active = false
	transition_finished.emit(error)


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_screen, "color:a", alpha, fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
