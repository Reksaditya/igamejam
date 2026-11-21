extends Resource

const Lesson = preload("res://scripts/interaction/blueprint/blueprint_lesson.gd")

@export var id: String
@export var title: String
@export var image: Texture2D
@export_range(1, 8) var columns: int = 3
@export_range(1, 8) var rows: int = 2
## One lesson unlocks the piece at the same index (left to right, top to bottom).
@export var lessons: Array[Lesson]


func get_region(index: int) -> Rect2:
	var cell := image.get_size() / Vector2(columns, rows)
	return Rect2(Vector2(index % columns, floori(float(index) / columns)) * cell, cell)
