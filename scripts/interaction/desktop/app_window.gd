extends PanelContainer

signal close_requested(window: Control)

const HANDLE_WIDTH: float = 5.0

var _bounds: Vector2
var _minimum_size: Vector2
var _normal_rect: Rect2
var _maximized: bool = false
var _active: bool = false
var _holding_pointer: bool = false
var _start_pointer: Vector2
var _start_rect: Rect2

@onready var _title_bar: PanelContainer = %TitleBar
@onready var _title: Label = %Title
@onready var _close: Button = %Close
@onready var _maximize: Button = %Maximize
@onready var _maximize_glyph: Control = %MaximizeGlyph
@onready var _body: ScrollContainer = %Body
@onready var _handles: Control = %ResizeHandles


func _ready() -> void:
	_title_bar.gui_input.connect(_handle_pointer.bind(_title_bar, Vector2i.ZERO))
	_title_bar.focus_entered.connect(_refresh_title_style)
	_title_bar.focus_exited.connect(_refresh_title_style)
	_title_bar.draw.connect(_draw_title_highlight)
	_close.pressed.connect(func() -> void: close_requested.emit(self))
	_maximize.pressed.connect(_toggle_maximize)
	_maximize_glyph.draw.connect(_draw_maximize_glyph)
	_maximize_glyph.resized.connect(_maximize_glyph.queue_redraw)
	get_window().focus_exited.connect(_cancel_pointer)
	_create_resize_handles()
	_refresh_title_style()
	_refresh_maximize_button()


func set_content(title: String, app: Control) -> void:
	_title.text = title
	_title_bar.accessibility_name = title
	_close.accessibility_name = "Close " + title
	app.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(app)


func get_content() -> Control:
	return _body.get_child(0) as Control if _body.get_child_count() > 0 else null


func set_initial_size(preferred: Vector2, minimum: Vector2) -> void:
	_minimum_size = minimum
	size = preferred


func set_active(active: bool) -> void:
	_active = active
	_refresh_title_style()


func set_close_enabled(enabled: bool) -> void:
	_close.disabled = not enabled


func focus_title() -> void:
	_title_bar.grab_focus()


func fit_within(bounds: Vector2) -> void:
	_cancel_pointer()
	_bounds = bounds
	if _maximized:
		position = Vector2.ZERO
		size = bounds
	else:
		_fit_normal_rect(Rect2(position, size))


func _fit_normal_rect(rect: Rect2) -> void:
	var minimum: Vector2 = _effective_minimum()
	size = rect.size.clamp(minimum, _bounds.max(minimum))
	position = rect.position.clamp(Vector2.ZERO, (_bounds - size).max(Vector2.ZERO))


func _effective_minimum() -> Vector2:
	return _minimum_size.min(_bounds).max(get_combined_minimum_size())


func _toggle_maximize() -> void:
	_cancel_pointer()
	if _maximized:
		_maximized = false
		_fit_normal_rect(_normal_rect)
	else:
		_normal_rect = Rect2(position, size)
		_maximized = true
		position = Vector2.ZERO
		size = _bounds
	_handles.visible = not _maximized
	_title_bar.mouse_default_cursor_shape = Control.CURSOR_ARROW if _maximized else Control.CURSOR_MOVE
	_refresh_maximize_button()


func _refresh_maximize_button() -> void:
	_maximize.tooltip_text = "Restore window" if _maximized else "Maximize window"
	_maximize.accessibility_name = _maximize.tooltip_text
	_maximize_glyph.queue_redraw()


func _draw_maximize_glyph() -> void:
	var center := _maximize_glyph.size * 0.5 + Vector2(0.5, 0.5)
	var ink := _maximize.get_theme_color("font_color")
	if _maximized:
		var front := Rect2(center + Vector2(-4, -2), Vector2(6, 6))
		_maximize_glyph.draw_polyline(PackedVector2Array([
			center + Vector2(-2, -2),
			center + Vector2(-2, -4),
			center + Vector2(4, -4),
			center + Vector2(4, 2),
			center + Vector2(2, 2),
		]), ink, 1.0)
		_maximize_glyph.draw_rect(front, ink, false, 1.0)
	else:
		_maximize_glyph.draw_rect(Rect2(center - Vector2(4, 4), Vector2(8, 8)), ink, false, 1.0)


func _draw_title_highlight() -> void:
	var highlight := Rect2(2, 2, _title_bar.size.x - 4.0, 1)
	_title_bar.draw_rect(highlight, Color(1, 1, 1, 0.18))


func _create_resize_handles() -> void:
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			var direction := Vector2i(x, y)
			if direction == Vector2i.ZERO:
				continue
			var handle := Control.new()
			_handles.add_child(handle)
			handle.mouse_default_cursor_shape = _resize_cursor(direction)
			handle.anchor_left = 1.0 if x > 0 else 0.0
			handle.anchor_right = 0.0 if x < 0 else 1.0
			handle.anchor_top = 1.0 if y > 0 else 0.0
			handle.anchor_bottom = 0.0 if y < 0 else 1.0
			handle.offset_left = -HANDLE_WIDTH if x > 0 else (0.0 if x < 0 else HANDLE_WIDTH)
			handle.offset_right = HANDLE_WIDTH if x < 0 else (0.0 if x > 0 else -HANDLE_WIDTH)
			handle.offset_top = -HANDLE_WIDTH if y > 0 else (0.0 if y < 0 else HANDLE_WIDTH)
			handle.offset_bottom = HANDLE_WIDTH if y < 0 else (0.0 if y > 0 else -HANDLE_WIDTH)
			handle.gui_input.connect(_handle_pointer.bind(handle, direction))


func _resize_cursor(direction: Vector2i) -> Control.CursorShape:
	if direction.x == 0:
		return Control.CURSOR_VSIZE
	if direction.y == 0:
		return Control.CURSOR_HSIZE
	return Control.CURSOR_FDIAGSIZE if direction.x == direction.y else Control.CURSOR_BDIAGSIZE


func _handle_pointer(event: InputEvent, target: Control, direction: Vector2i) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_cancel_pointer()
		if event.pressed and not event.canceled:
			if direction == Vector2i.ZERO:
				focus_title()
				if event.double_click:
					_toggle_maximize()
					target.accept_event()
					return
			if not _maximized:
				_holding_pointer = true
				_start_pointer = _parent_mouse_position(event)
				_start_rect = Rect2(position, size)
		target.accept_event()
	elif event is InputEventMouseMotion and _holding_pointer:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_cancel_pointer()
			return
		var delta: Vector2 = _parent_mouse_position(event) - _start_pointer
		if direction == Vector2i.ZERO:
			position = (_start_rect.position + delta).clamp(Vector2.ZERO, (_bounds - size).max(Vector2.ZERO))
		else:
			_resize_window(direction, delta)
		target.accept_event()


func _resize_window(direction: Vector2i, delta: Vector2) -> void:
	var start: Vector2 = _start_rect.position
	var end: Vector2 = _start_rect.end
	var minimum: Vector2 = _effective_minimum()
	for axis: int in range(2):
		if direction[axis] < 0:
			start[axis] = clampf(start[axis] + delta[axis], 0.0, end[axis] - minimum[axis])
		elif direction[axis] > 0:
			end[axis] = clampf(end[axis] + delta[axis], start[axis] + minimum[axis], _bounds[axis])
	position = start
	size = end - start


func _cancel_pointer() -> void:
	_holding_pointer = false


func _parent_mouse_position(event: InputEventMouse) -> Vector2:
	var parent := get_parent() as Control
	return parent.get_global_transform_with_canvas().affine_inverse() * event.global_position


func _refresh_title_style() -> void:
	if _title_bar.has_focus():
		_title_bar.theme_type_variation = &"WindowTitleFocused"
	else:
		_title_bar.theme_type_variation = &"WindowTitleActive" if _active else &"WindowTitleInactive"
