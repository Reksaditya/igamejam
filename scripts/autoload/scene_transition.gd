extends CanvasLayer

signal transition_finished(error: Error)

enum TransitionStyle { FADE, SLIDE_LEFT, SLIDE_RIGHT }

@export_range(0.05, 2.0, 0.05) var fade_seconds: float = 0.35
@export_range(0.05, 1.5, 0.05) var slide_seconds: float = 0.30

var _active: bool = false
var last_style: TransitionStyle = TransitionStyle.FADE

@onready var _screen: ColorRect = $Screen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(_event: InputEvent) -> void:
	if _active:
		get_viewport().set_input_as_handled()


func is_active() -> bool:
	return _active


func change_scene(destination: String, spawn: StringName, style: TransitionStyle = TransitionStyle.FADE) -> void:
	if _active:
		return
	_active = true
	last_style = style
	var was_paused := get_tree().paused
	get_tree().paused = true
	_screen.show()

	if style == TransitionStyle.FADE:
		_reset_screen_full_rect()
		_screen.color.a = 0.0
		await _fade_to(1.0)
	else:
		await _slide_cover(style)

	if spawn != &"":
		get_tree().set_meta(&"side_scroller_spawn", spawn)
	var error := get_tree().change_scene_to_file(destination)
	if error == OK:
		await get_tree().scene_changed
		await get_tree().process_frame
	else:
		get_tree().remove_meta(&"side_scroller_spawn")

	if style == TransitionStyle.FADE:
		await _fade_to(0.0)
	else:
		await _slide_reveal(style)

	_screen.hide()
	_reset_screen_full_rect()
	_screen.color.a = 0.0
	get_tree().paused = was_paused
	_active = false
	transition_finished.emit(error)


func _viewport_size() -> Vector2:
	var rect_size := get_viewport().get_visible_rect().size
	if rect_size.x <= 1.0 or rect_size.y <= 1.0:
		return Vector2(1280.0, 720.0)
	return rect_size


func _reset_screen_full_rect() -> void:
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.position = Vector2.ZERO


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_property(_screen, "color:a", alpha, fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _slide_cover(style: TransitionStyle) -> void:
	var view_size := _viewport_size()
	var start_x := view_size.x if style == TransitionStyle.SLIDE_LEFT else -view_size.x
	_screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_screen.size = view_size
	_screen.position = Vector2(start_x, 0.0)
	_screen.color = Color(0.05, 0.05, 0.06, 0.08)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_property(_screen, "position:x", 0.0, slide_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_screen, "color:a", 0.98, slide_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _slide_reveal(style: TransitionStyle) -> void:
	var view_size := _viewport_size()
	var end_x := -view_size.x if style == TransitionStyle.SLIDE_LEFT else view_size.x
	_screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_screen.size = view_size
	_screen.position = Vector2.ZERO
	_screen.color.a = 0.98
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_property(_screen, "position:x", end_x, slide_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_screen, "color:a", 0.0, slide_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
