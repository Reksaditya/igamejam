@tool
extends Control

const Launcher = preload("res://scripts/interaction/desktop/desktop_launcher.gd")
const CELL_SIZE := Launcher.ITEM_SIZE
const CELL_STEP := CELL_SIZE + Vector2(10, 10)
const DRAG_DISTANCE: float = 6.0

var _cells: Dictionary[Launcher, Vector2i] = {}
var _held_icon: Launcher
var _press_point: Vector2
var _grab_offset: Vector2
var _dragging: bool = false
var _suppress_activation: Launcher

@onready var _scroll: ScrollContainer = get_parent()


func _ready() -> void:
	child_order_changed.connect(_layout_icons, CONNECT_DEFERRED)
	_scroll.resized.connect(_layout_icons, CONNECT_DEFERRED)
	_layout_icons()


func handle_pointer(event: InputEventMouse, over_window: bool) -> void:
	var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			cancel_drag()
			if not over_window and _visible_grid().has_point(point):
				_begin_press(point)
		elif is_instance_valid(_held_icon):
			if _dragging and not event.canceled:
				_drop(point)
			cancel_drag()
	elif event is InputEventMouseMotion and is_instance_valid(_held_icon):
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			cancel_drag()
		elif _dragging or point.distance_squared_to(_press_point) >= DRAG_DISTANCE * DRAG_DISTANCE:
			_dragging = true
			_held_icon.z_index = 1
			_held_icon.position = point - _grab_offset


func suppresses_activation(launcher: Launcher) -> bool:
	return launcher == _suppress_activation or (_dragging and launcher == _held_icon)


func cancel_drag() -> void:
	if _dragging and is_instance_valid(_held_icon):
		_held_icon.position = Vector2(_cells[_held_icon]) * CELL_STEP
		_held_icon.z_index = 0
		_suppress_activation = _held_icon
		_clear_suppression.call_deferred()
	_held_icon = null
	_dragging = false


func _clear_suppression() -> void:
	_suppress_activation = null


func _begin_press(point: Vector2) -> void:
	for child: Node in get_children():
		var icon := child as Launcher
		if _cells.has(icon) and icon.visible and not icon.disabled and icon.get_rect().has_point(point):
			_held_icon = icon
			_press_point = point
			_grab_offset = point - icon.position
			return


func _drop(point: Vector2) -> void:
	var cell := Vector2i(((point - _grab_offset) / CELL_STEP).round())
	var cell_rect := Rect2(Vector2(cell) * CELL_STEP, CELL_SIZE)
	var visible_grid: Rect2 = _visible_grid()
	if cell.x < 0 or cell.x >= _column_count() or cell.y < 0:
		return
	if not visible_grid.has_point(point) or not visible_grid.encloses(cell_rect):
		return
	var occupant: Launcher = _cells.find_key(cell)
	if occupant == null or occupant == _held_icon:
		_cells[_held_icon] = cell
		_update_grid_height()


func _layout_icons() -> void:
	if not is_inside_tree():
		return
	cancel_drag()
	var columns: int = _column_count()
	var used: Dictionary[Vector2i, bool] = {}
	var pending: Array[Launcher] = []
	var updated: Dictionary[Launcher, Vector2i] = {}
	for child: Node in get_children():
		var icon := child as Launcher
		if icon == null:
			continue
		var cell: Vector2i = _cells.get(icon, Vector2i(-1, -1))
		if cell.x >= 0 and cell.x < columns:
			updated[icon] = cell
			used[cell] = true
		else:
			pending.append(icon)
	var initial_columns: int = mini(2, columns)
	var index: int = 0
	for icon: Launcher in pending:
		var cell := Vector2i(index % initial_columns, floori(float(index) / initial_columns))
		while used.has(cell):
			index += 1
			cell = Vector2i(index % initial_columns, floori(float(index) / initial_columns))
		updated[icon] = cell
		used[cell] = true
	_cells = updated
	for icon: Launcher in _cells:
		icon.position = Vector2(_cells[icon]) * CELL_STEP
		icon.size = CELL_SIZE
	_update_grid_height()


func _column_count() -> int:
	return maxi(1, floori((_scroll.size.x - 16.0 + CELL_STEP.x - CELL_SIZE.x) / CELL_STEP.x))


func _update_grid_height() -> void:
	var height: float = 0.0
	for cell: Vector2i in _cells.values():
		height = maxf(height, cell.y * CELL_STEP.y + CELL_SIZE.y)
	custom_minimum_size.y = height


func _visible_grid() -> Rect2:
	var transform_to_grid: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var top_left: Vector2 = transform_to_grid * _scroll.get_global_transform_with_canvas().origin
	return Rect2(top_left, Vector2(minf(size.x, _scroll.size.x), _scroll.size.y))
