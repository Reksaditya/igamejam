extends Control

var scene_kind: String = "intro"


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#304d66"))
	draw_rect(Rect2(0, size.y * 0.7, size.x, size.y * 0.3), Color("#719582"))
	if scene_kind in ["loss", "bad", "visit"]:
		draw_circle(Vector2(size.x - 55, 35), 18, Color("#d6d5bd"))
		draw_rect(Rect2(size.x * 0.6, size.y * 0.35, 60, size.y * 0.45), Color("#acb8ad"))
		draw_line(Vector2(size.x * 0.6 + 15, size.y * 0.48), Vector2(size.x * 0.6 + 45, size.y * 0.48), Color("#526675"), 4)
	else:
		draw_circle(Vector2(size.x - 55, 35), 22, Color("#f1d69b"))
		for index: int in 3:
			draw_rect(Rect2(size.x * 0.55 + index * 35, size.y * 0.25, 25, size.y * 0.5), Color("#a2b7bc"))
	for index: int in (2 if scene_kind in ["happy", "visit"] else 1):
		var origin := Vector2(75 + index * 80, size.y * 0.72)
		draw_circle(origin - Vector2(0, 62), 16, Color("#c49d89"))
		draw_rect(Rect2(origin - Vector2(16, 42), Vector2(32, 38)), Color("#eadfc9"))
		draw_rect(Rect2(origin - Vector2(15, 4), Vector2(11, 22)), Color("#1d2b3b"))
		draw_rect(Rect2(origin + Vector2(4, -4), Vector2(11, 22)), Color("#1d2b3b"))
