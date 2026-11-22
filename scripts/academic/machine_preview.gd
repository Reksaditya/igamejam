extends Control

var count: int = 0
var components: Array = []


func _draw() -> void:
	var cell := Vector2(size.x / 3.0, 78)
	for index: int in 6:
		var origin := Vector2(index % 3, floori(index / 3.0)) * cell
		var rect := Rect2(origin + Vector2(6, 6), cell - Vector2(12, 12))
		draw_rect(rect, Color("#375e68") if index < count else Color("#192b3d"))
		draw_rect(rect, Color("#b7d5c6"), false, 2)
		if index < count:
			draw_circle(rect.position + Vector2(22, 24), 12, Color("#8bd7bb"))
			draw_circle(rect.position + Vector2(22, 24), 5, Color("#263e51"))
		var title: String = components[index] if index < components.size() else str(index + 1)
		draw_string(get_theme_default_font(), rect.position + Vector2(8, 56), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16, 16, Color("#ece5cf"))
