extends Control

signal placement_requested(slot: int, origin: Vector2i)
signal pointer_selection_cleared

const Shape = preload("res://scripts/interaction/desktop/blocks/block_shape.gd")
const SIDE := 8
const GAP := 2.0

var source_id := 0
var tiles: Array[Color]
var tray: Array[Shape]
var can_place: Callable
var preview_lines: Callable
var selected_slot := -1
var game_over := false
var _cursor := Vector2i.ZERO
var _hover_cell := Vector2i.ZERO
var _hover_slot := -1
var _keyboard_cursor := false
var _own_drag := false


func _ready() -> void:
	set_process(false)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or game_over:
		return
	if event is InputEventMouseButton and event.pressed:
		_set_keyboard_cursor(false)
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		_set_keyboard_cursor(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		_own_drag = data is Dictionary and data.get("source") == source_id
		if _own_drag:
			_clear_pointer_selection()
			set_process(true)
	elif what == NOTIFICATION_DRAG_END and _own_drag:
		_own_drag = false
		set_process(false)
		_clear_pointer_selection()


func _set_keyboard_cursor(enabled: bool) -> void:
	if _keyboard_cursor != enabled:
		_keyboard_cursor = enabled
		queue_redraw()


func _clear_pointer_selection() -> void:
	_set_keyboard_cursor(false)
	clear_preview()
	pointer_selection_cleared.emit()


func _process(_delta: float) -> void:
	if get_viewport().gui_get_hovered_control() != self or not Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
		clear_preview()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if game_over or not data is Dictionary or data.get("source") != source_id:
		clear_preview()
		return false
	var slot: Variant = data.get("slot", -1)
	if not slot is int or slot < 0 or slot >= tray.size() or tray[slot] == null:
		clear_preview()
		return false
	var origin := _drop_origin(at_position, slot)
	if not can_place.call(slot, origin):
		clear_preview()
		return false
	_hover_cell = origin
	_hover_slot = slot
	queue_redraw()
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	placement_requested.emit(data["slot"], _drop_origin(at_position, data["slot"]))
	_clear_pointer_selection()


func _drop_origin(at_position: Vector2, slot: int) -> Vector2i:
	var center := tray[slot].get_cell_bounds().get_center()
	return Vector2i((at_position / get_cell_size() - center).round())


func clear_preview() -> void:
	if _hover_slot >= 0:
		_hover_slot = -1
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_slot >= 0:
			var cell := Vector2i((event.position / get_cell_size()).floor())
			placement_requested.emit(selected_slot, cell)
		_clear_pointer_selection()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		_set_keyboard_cursor(true)
		if selected_slot >= 0:
			placement_requested.emit(selected_slot, _cursor)
		accept_event()
	else:
		var direction := Vector2i.ZERO
		if event.is_action_pressed("ui_left"):
			direction = Vector2i.LEFT
		elif event.is_action_pressed("ui_right"):
			direction = Vector2i.RIGHT
		elif event.is_action_pressed("ui_up"):
			direction = Vector2i.UP
		elif event.is_action_pressed("ui_down"):
			direction = Vector2i.DOWN
		if direction != Vector2i.ZERO:
			_set_keyboard_cursor(true)
			_cursor = (_cursor + direction).clamp(Vector2i.ZERO, Vector2i.ONE * (SIDE - 1))
			queue_redraw()
			accept_event()


func get_cell_size() -> Vector2:
	return size / float(SIDE)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#a4afb9"))
	for y: int in range(SIDE):
		for x: int in range(SIDE):
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell)
			var fill := tiles[y * SIDE + x] if tiles.size() == SIDE * SIDE else Color.TRANSPARENT
			if fill.a > 0.0:
				draw_rect(rect, Color("#455466"), false, 1.0)
				Shape.draw_cell(self, rect, fill)
			else:
				draw_rect(rect, Color("#eef1f3"))
	if game_over or not can_place.is_valid():
		return
	if _hover_slot >= 0:
		_draw_hint(_hover_slot, _hover_cell)
	elif _keyboard_cursor and has_focus() and not get_viewport().gui_is_dragging():
		_draw_hint(selected_slot, _cursor)
		draw_rect(_cell_rect(_cursor), Color("#153350"), false, 2.0)


func _draw_hint(slot: int, origin: Vector2i) -> void:
	if slot < 0 or slot >= tray.size() or tray[slot] == null:
		return
	if not can_place.call(slot, origin):
		return
	var lines: Dictionary = preview_lines.call(slot, origin)
	for line: int in lines.rows:
		for x: int in range(SIDE):
			draw_rect(_cell_rect(Vector2i(x, line)), Color("#d8922788"))
	for line: int in lines.columns:
		for y: int in range(SIDE):
			if y not in lines.rows:
				draw_rect(_cell_rect(Vector2i(line, y)), Color("#d8922788"))
	var tint := tray[slot].color
	tint.a = 0.55
	for offset: Vector2i in tray[slot].cells:
		var rect := _cell_rect(origin + offset)
		draw_rect(rect, tint)
		draw_rect(rect, Color("#146555"), false, 1.0)


func _cell_rect(cell: Vector2i) -> Rect2:
	var step := get_cell_size()
	return Rect2(Vector2(cell) * step + Vector2.ONE * GAP, step - Vector2.ONE * GAP * 2.0)
