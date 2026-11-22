extends Control


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#283538"))
	var window := Rect2(size.x * 0.24, 58.0, size.x * 0.52, size.y * 0.41)
	draw_rect(window.grow(13.0), Color("#17262a"))
	draw_rect(window.grow(7.0), Color("#657371"))
	draw_rect(window, Color("#9eb8b5"))
	draw_circle(window.position + Vector2(window.size.x * 0.78, window.size.y * 0.30), minf(window.size.y * 0.20, 40.0), Color("#f0ddb0"), true, -1, true)
	for column: int in range(7):
		var width := window.size.x / 7.0
		var height := window.size.y * (0.18 + 0.07 * ((column * 7) % 5))
		draw_rect(Rect2(window.position.x + column * width, window.end.y - height, width - 2, height), Color("#637f80"))
		draw_rect(Rect2(window.position.x + column * width + width * 0.22, window.end.y - height + 9, width * 0.15, 4), Color("#c8ccae"))
	draw_line(Vector2(window.get_center().x, window.position.y), Vector2(window.get_center().x, window.end.y), Color("#526966"), 6)
	draw_line(Vector2(window.position.x, window.get_center().y), Vector2(window.end.x, window.get_center().y), Color("#526966"), 6)
	draw_rect(Rect2(window.position.x - 20, window.end.y, window.size.x + 40, 12), Color("#52625d"))

	var top := size.y * 0.31
	var bottom := size.y - 80.0
	draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.08, top), Vector2(size.x * 0.92, top), Vector2(size.x, bottom), Vector2(0, bottom)]), Color("#795943"))
	for line: int in range(5):
		var y := lerpf(top, bottom, (line + 1) / 6.0)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("#71523e"), 2.0)
	draw_rect(Rect2(0, bottom, size.x, 11), Color("#a57b57"))
	draw_rect(Rect2(0, bottom + 11, size.x, size.y), Color("#202b2c"))
