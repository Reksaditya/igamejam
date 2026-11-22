@tool
extends Control

const Launcher = preload("res://scripts/interaction/desktop/desktop_launcher.gd")
const CELL_SIZE := Launcher.ITEM_SIZE
const ICON_ORIGIN := Vector2(18, 17)
const CELL_STEP := CELL_SIZE + Vector2(10, 10)
const DRAG_DISTANCE: float = 6.0

var _cells: Dictionary[Launcher, Vector2i] = {}
var _held_icon: Launcher
var _press_point: Vector2
var _grab_offset: Vector2
var _dragging: bool = false
var _suppress_activation: Launcher
var _selecting := false
var _box_origin := Vector2.ZERO
var _box := Rect2()

@onready var _scroll: ScrollContainer = get_parent()


func _ready() -> void:
	child_order_changed.connect(_layout_icons, CONNECT_DEFERRED)
	_scroll.resized.connect(_layout_icons, CONNECT_DEFERRED)
	_layout_icons()


func handle_pointer(event: InputEventMouse, over_ui: bool) -> bool:
	var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			cancel_drag()
			if over_ui or not _visible_grid().has_point(point):
				return false
			if _begin_press(point):
				return false
			_begin_selection(point)
			return true
		if _selecting:
			if not event.canceled:
				_update_selection(point)
			cancel_drag()
			return true
		if is_instance_valid(_held_icon):
			if _dragging and not event.canceled and not over_ui:
				_drop(point)
			cancel_drag()
	elif event is InputEventMouseMotion:
		if _selecting:
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_update_selection(point)
			else:
				cancel_drag()
			return true
		if is_instance_valid(_held_icon):
			if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				cancel_drag()
			elif _dragging or point.distance_squared_to(_press_point) >= DRAG_DISTANCE * DRAG_DISTANCE:
				_dragging = true
				_held_icon.z_index = 1
				_held_icon.position = point - _grab_offset
	return false


func _begin_selection(point: Vector2) -> void:
	_selecting = true
	_box_origin = point
	_box = Rect2(point, Vector2.ZERO)
	_highlight_intersections(false)
	var focus := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus) and is_ancestor_of(focus):
		focus.release_focus()


func _update_selection(point: Vector2) -> void:
	var bounds := _visible_grid()
	var cursor := point.clamp(bounds.position, bounds.end)
	_box = Rect2(_box_origin, cursor - _box_origin).abs()
	_highlight_intersections(_box.size.length_squared() >= DRAG_DISTANCE * DRAG_DISTANCE)
	queue_redraw()


func _highlight_intersections(has_box: bool) -> void:
	var bounds := _visible_grid()
	for icon: Launcher in _cells:
		if is_instance_valid(icon):
			var hit := has_box and icon.is_visible_in_tree() and not icon.disabled and _box.intersects(icon.get_rect().intersection(bounds))
			icon.set_box_selected(hit)


func _draw() -> void:
	if _selecting and _box.has_area():
		draw_rect(_box, Color(0.25, 0.55, 0.87, 0.24))
		draw_rect(_box, Color(0.63, 0.83, 1.0), false, 1.0)


func suppresses_activation(launcher: Launcher) -> bool:
	return launcher == _suppress_activation or (_dragging and launcher == _held_icon)


func cancel_drag() -> void:
	if _selecting:
		_selecting = false
		queue_redraw()
	if _dragging and is_instance_valid(_held_icon):
		_held_icon.position = _cell_origin(_cells[_held_icon])
		_held_icon.z_index = 0
		_suppress_activation = _held_icon
		_clear_suppression.call_deferred()
	_held_icon = null
	_dragging = false


func _clear_suppression() -> void:
	_suppress_activation = null


func _begin_press(point: Vector2) -> bool:
	_highlight_intersections(false)
	for child: Node in get_children():
		var icon := child as Launcher
		if _cells.has(icon) and icon.visible and not icon.disabled and icon.get_rect().has_point(point):
			_held_icon = icon
			_press_point = point
			_grab_offset = point - icon.position
			return true
	return false


func _drop(point: Vector2) -> void:
	var cell := Vector2i(((point - _grab_offset - ICON_ORIGIN) / CELL_STEP).round())
	var cell_rect := Rect2(_cell_origin(cell), CELL_SIZE)
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
		icon.position = _cell_origin(_cells[icon])
		icon.size = CELL_SIZE
	_update_grid_height()


func _cell_origin(cell: Vector2i) -> Vector2:
	return ICON_ORIGIN + Vector2(cell) * CELL_STEP


func _column_count() -> int:
	return maxi(1, floori((_scroll.size.x - ICON_ORIGIN.x * 2.0 + CELL_STEP.x - CELL_SIZE.x) / CELL_STEP.x))


func _update_grid_height() -> void:
	var height: float = 0.0
	for cell: Vector2i in _cells.values():
		height = maxf(height, _cell_origin(cell).y + CELL_SIZE.y + ICON_ORIGIN.y)
	custom_minimum_size.y = height


func _visible_grid() -> Rect2:
	var transform_to_grid: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var top_left: Vector2 = transform_to_grid * _scroll.get_global_transform_with_canvas().origin
	return Rect2(top_left, Vector2(minf(size.x, _scroll.size.x), _scroll.size.y))
