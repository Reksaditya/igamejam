@tool
extends Control

const Launcher = preload("res://scripts/interaction/desktop/desktop_launcher.gd")
const CELL_SIZE := Launcher.ITEM_SIZE
const ICON_ORIGIN := Vector2(18, 17)
const CELL_STEP := CELL_SIZE + Vector2(10, 10)
const DRAG_DISTANCE: float = 6.0
const REFERENCE_COLUMNS := 8
const REFERENCE_ROWS := 5
const FALLBACK_SCATTER: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(3, 1),
	Vector2i(1, 2),
	Vector2i(6, 0),
	Vector2i(5, 3),
	Vector2i(2, 0),
	Vector2i(4, 2),
	Vector2i(7, 1),
	Vector2i(0, 3),
	Vector2i(3, 3),
]

var _cells: Dictionary[Launcher, Vector2i] = {}
var _custom_cells: Dictionary[Launcher, Vector2i] = {}
var _held_icon: Launcher
var _press_point: Vector2
var _grab_offset: Vector2
var _dragging: bool = false
var _suppress_activation: Launcher
var _selecting := false
var _box_origin := Vector2.ZERO
var _box := Rect2()

@onready var _scroll: ScrollContainer = get_parent() as ScrollContainer


func _ready() -> void:
	child_order_changed.connect(_layout_icons, CONNECT_DEFERRED)
	if is_instance_valid(_scroll):
		_scroll.resized.connect(_layout_icons, CONNECT_DEFERRED)
	_layout_icons()


func refresh_layout() -> void:
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
		if _cells.has(_held_icon):
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
		_custom_cells[_held_icon] = cell
		_update_grid_height()


func _layout_icons() -> void:
	if not is_inside_tree() or not is_instance_valid(_scroll):
		return
	cancel_drag()
	var columns: int = _column_count()
	var rows: int = _visible_row_count()
	var used: Dictionary[Vector2i, bool] = {}
	var pending: Array[Launcher] = []
	var updated: Dictionary[Launcher, Vector2i] = {}

	var pruned_custom: Dictionary[Launcher, Vector2i] = {}
	for icon: Launcher in _custom_cells:
		if is_instance_valid(icon) and icon.get_parent() == self:
			pruned_custom[icon] = _custom_cells[icon]
	_custom_cells = pruned_custom

	for child: Node in get_children():
		var icon := child as Launcher
		if icon == null:
			continue
		if _custom_cells.has(icon):
			var custom := _custom_cells[icon]
			if custom.x >= 0 and custom.x < columns and custom.y >= 0 and not used.has(custom):
				updated[icon] = custom
				used[custom] = true
				continue
		pending.append(icon)

	var fallback_index: int = 0
	for icon: Launcher in pending:
		var preferred := icon.default_cell
		if preferred.x < 0 or preferred.y < 0:
			preferred = FALLBACK_SCATTER[fallback_index % FALLBACK_SCATTER.size()]
			fallback_index += 1
		var target := _map_default_cell(preferred, columns, rows)
		var cell := _nearest_free_cell(target, columns, used)
		updated[icon] = cell
		used[cell] = true

	_cells = updated
	for icon: Launcher in _cells:
		icon.position = _cell_origin(_cells[icon])
		icon.size = CELL_SIZE
	_update_grid_height()


func _map_default_cell(preferred: Vector2i, columns: int, rows: int) -> Vector2i:
	var mapped_x := 0 if columns <= 1 else clampi(roundi(float(preferred.x) * float(columns - 1) / float(REFERENCE_COLUMNS - 1)), 0, columns - 1)
	var mapped_y := clampi(preferred.y, 0, rows - 1)
	if rows < REFERENCE_ROWS:
		mapped_y = 0 if rows <= 1 else clampi(roundi(float(preferred.y) * float(rows - 1) / float(REFERENCE_ROWS - 1)), 0, rows - 1)
	return Vector2i(mapped_x, mapped_y)


func _nearest_free_cell(target: Vector2i, columns: int, used: Dictionary[Vector2i, bool]) -> Vector2i:
	var clamped_target := Vector2i(clampi(target.x, 0, columns - 1), maxi(0, target.y))
	if not used.has(clamped_target):
		return clamped_target
	var max_dist := columns + 20
	for dist: int in range(1, max_dist):
		for dy: int in range(-dist, dist + 1):
			var cy := clamped_target.y + dy
			if cy < 0:
				continue
			var rem := dist - absi(dy)
			var dx_options := [0] if rem == 0 else [rem, -rem]
			for dx: int in dx_options:
				var cx := clamped_target.x + dx
				if cx < 0 or cx >= columns:
					continue
				var candidate := Vector2i(cx, cy)
				if not used.has(candidate):
					return candidate
	var row := 0
	while true:
		for col: int in range(columns):
			var fallback := Vector2i(col, row)
			if not used.has(fallback):
				return fallback
		row += 1
	return Vector2i.ZERO


func _cell_origin(cell: Vector2i) -> Vector2:
	return ICON_ORIGIN + Vector2(cell) * CELL_STEP


func _column_count() -> int:
	if not is_instance_valid(_scroll):
		return REFERENCE_COLUMNS
	return maxi(1, floori((_scroll.size.x - ICON_ORIGIN.x * 2.0 + CELL_STEP.x - CELL_SIZE.x) / CELL_STEP.x))


func _visible_row_count() -> int:
	if not is_instance_valid(_scroll):
		return REFERENCE_ROWS
	return maxi(1, floori((_scroll.size.y - ICON_ORIGIN.y * 2.0 + CELL_STEP.y - CELL_SIZE.y) / CELL_STEP.y))


func _update_grid_height() -> void:
	var height: float = 0.0
	for cell: Vector2i in _cells.values():
		height = maxf(height, _cell_origin(cell).y + CELL_SIZE.y + ICON_ORIGIN.y)
	custom_minimum_size.y = height


func _visible_grid() -> Rect2:
	if not is_instance_valid(_scroll):
		return Rect2(Vector2.ZERO, size)
	var transform_to_grid: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var top_left: Vector2 = transform_to_grid * _scroll.get_global_transform_with_canvas().origin
	return Rect2(top_left, Vector2(minf(size.x, _scroll.size.x), _scroll.size.y))
