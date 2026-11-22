extends Resource

@export var title: String
@export var color := Color("#64d5b0")
## List the occupied coordinates. The bounds of a piece start at column 0 and row 0.
@export var cells: Array[Vector2i]


func get_cell_bounds() -> Rect2:
	if cells.is_empty():
		return Rect2()
	var first := cells[0]
	var last := first
	for cell: Vector2i in cells:
		first = first.min(cell)
		last = last.max(cell)
	return Rect2(Vector2(first), Vector2(last - first + Vector2i.ONE))


static func draw_cell(canvas: CanvasItem, rect: Rect2, fill: Color) -> void:
	canvas.draw_rect(rect.grow(-1.0), fill)
	var top := rect.position + Vector2(2.0, 2.0)
	canvas.draw_line(top, Vector2(rect.end.x - 2.0, top.y), fill.lightened(0.22), 2.0)
	var bottom := rect.end - Vector2(2.0, 2.0)
	canvas.draw_line(Vector2(top.x, bottom.y), bottom, fill.darkened(0.20), 2.0)
