extends Button

const Shape = preload("res://scripts/interaction/desktop/blocks/block_shape.gd")
const Board = preload("res://scripts/interaction/desktop/blocks/block_board.gd")

var board: Board
var source_id := 0
var slot := -1
var shape: Shape:
	set(value):
		shape = value
		queue_redraw()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if shape == null or disabled or board == null:
		return null
	var bounds := shape.get_cell_bounds()
	var step := board.get_cell_size()
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_as_relative = false
	preview.z_index = 64
	preview.size = bounds.size * step
	preview.draw.connect(_draw_floating_piece.bind(preview, shape, -bounds.get_center() * step, step))
	set_drag_preview(preview)
	return {"source": source_id, "slot": slot}


func _draw() -> void:
	if shape == null:
		return
	var bounds := shape.get_cell_bounds()
	var step := minf(15.0, minf((size.x - 12.0) / bounds.size.x, (size.y - 12.0) / bounds.size.y))
	var origin := (size * 0.5 - bounds.get_center() * step).floor()
	_draw_piece(self, shape, origin, Vector2.ONE * step)


func _draw_floating_piece(canvas: CanvasItem, piece: Shape, origin: Vector2, step: Vector2) -> void:
	for cell: Vector2i in piece.cells:
		var rect := Rect2(origin + Vector2(cell) * step, step)
		canvas.draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color("#101b2677"))
	for cell: Vector2i in piece.cells:
		canvas.draw_rect(Rect2(origin + Vector2(cell) * step, step), Color("#27343e"))
	_draw_piece(canvas, piece, origin, step)


func _draw_piece(canvas: CanvasItem, piece: Shape, origin: Vector2, step: Vector2) -> void:
	for cell: Vector2i in piece.cells:
		Shape.draw_cell(canvas, Rect2(origin + Vector2(cell) * step, step), piece.color)
