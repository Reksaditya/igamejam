extends Button

const Puzzle = preload("res://scripts/interaction/workshop/transmission_puzzle.gd")
const Plate = preload("res://scripts/interaction/workshop/transmission_plate.gd")

signal drag_started(slider: int)
signal drag_moved(slider: int, stop_value: float)
signal drag_ended(slider: int, target_stop: int)
signal step_requested(slider: int)

var slider_index := -1
var plate: Plate
var puzzle: Puzzle

var _pressing := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _current_stop_value := 0.0


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style_name: String in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	var focus_style := StyleBoxFlat.new()
	focus_style.draw_center = false
	focus_style.border_color = Color("#ffe0a1")
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(12)
	add_theme_stylebox_override("focus", focus_style)
	pressed.connect(_on_pressed)


func cancel_drag() -> void:
	_pressing = false
	_dragging = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_pressed() -> void:
	if disabled or _pressing or _dragging or slider_index < 0:
		return
	step_requested.emit(slider_index)


func _gui_input(event: InputEvent) -> void:
	if disabled or puzzle == null or plate == null or slider_index < 0 or slider_index >= puzzle.slider_count():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_dragging = false
			_press_pos = event.global_position
			grab_focus()
			accept_event()
		elif _pressing:
			var was_dragging := _dragging
			_pressing = false
			_dragging = false
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if was_dragging:
				var target_stop := puzzle.sliders[slider_index].nearest_stop(_current_stop_value)
				drag_ended.emit(slider_index, target_stop)
			else:
				step_requested.emit(slider_index)
			accept_event()
	elif event is InputEventMouseMotion and _pressing:
		if not _dragging and event.global_position.distance_to(_press_pos) >= 5.0:
			_dragging = true
			mouse_default_cursor_shape = Control.CURSOR_DRAG
			drag_started.emit(slider_index)
		if _dragging:
			var scale_factor := maxf(plate.plate_scale(), 0.001)
			var plate_point := (plate.get_local_mouse_position() - plate.screen_position(Vector2.ZERO)) / scale_factor
			_current_stop_value = puzzle.sliders[slider_index].project_to_stop_value(plate_point)
			drag_moved.emit(slider_index, _current_stop_value)
			accept_event()
