extends Control


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0c1929"))
	draw_circle(Vector2(size.x * 0.84, size.y * 0.22), 60.0, Color("#233349"))
	var horizon := size.y * 0.8
	for index: int in range(9):
		var x := float(index) * size.x / 8.0 - 45.0
		var height := 90.0 + float(index % 3) * 35.0
		draw_rect(Rect2(x, horizon - height, 100, height), Color("#14283d"))
		for row: int in range(2):
			for column: int in range(3):
				draw_rect(Rect2(x + 14 + column * 25, horizon - height + 22 + row * 35, 12, 18), Color("#2b4256"))
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), Color("#101f30"))
	draw_line(Vector2(0, horizon), Vector2(size.x, horizon), Color("#304055"), 2.0)
