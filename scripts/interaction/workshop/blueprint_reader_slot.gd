extends PanelContainer

signal blueprint_dropped(puzzle_id: String)

var source_id := 0
var can_accept_drop: Callable

var _idle_style: StyleBox
var _drag_active := false
var _drop_hovered := false


func _ready() -> void:
	_idle_style = get_theme_stylebox("panel")
	mouse_exited.connect(_on_mouse_exited)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if _is_valid_drag_payload(data):
			_drag_active = true
			_drop_hovered = false
			_update_style()
	elif what == NOTIFICATION_DRAG_END:
		if _drag_active or _drop_hovered:
			_drag_active = false
			_drop_hovered = false
			_update_style()


func _on_mouse_exited() -> void:
	if _drop_hovered:
		_drop_hovered = false
		_update_style()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var accepted := _is_valid_drag_payload(data)
	if _drop_hovered != accepted:
		_drop_hovered = accepted
		_update_style()
	return accepted


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_drag_active = false
	_drop_hovered = false
	_update_style()
	if _is_valid_drag_payload(data):
		blueprint_dropped.emit(data["puzzle_id"])


func _is_valid_drag_payload(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.get("source") != source_id or data.get("type") != "workshop_blueprint":
		return false
	var puzzle_id: Variant = data.get("puzzle_id", "")
	if not puzzle_id is String or puzzle_id.is_empty():
		return false
	if can_accept_drop.is_valid():
		return bool(can_accept_drop.call(puzzle_id))
	return false


func _update_style() -> void:
	if not _drag_active and not _drop_hovered:
		if _idle_style != null:
			add_theme_stylebox_override("panel", _idle_style)
		return
	var style := StyleBoxFlat.new()
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	style.set_corner_radius_all(4)
	style.set_border_width_all(2)
	if _drop_hovered:
		style.bg_color = Color(0.11, 0.23, 0.24, 0.96)
		style.border_color = Color("#8ed6ab")
	else:
		style.bg_color = Color(0.1, 0.19, 0.22, 0.94)
		style.border_color = Color("#7bd4eb")
	add_theme_stylebox_override("panel", style)
