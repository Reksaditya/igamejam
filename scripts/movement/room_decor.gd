extends Node2D

@export var title: String = "Asrama"
@export var bedroom: bool = false


func _ready() -> void:
	var sign := Label.new()
	sign.text = title
	sign.position = Vector2(150, 200)
	sign.theme = preload("res://scenes/ui/menu_theme.tres")
	sign.add_theme_font_size_override("font_size", 30)
	add_child(sign)


func _draw() -> void:
	draw_rect(Rect2(120, 190, 650, 290), Color("#516a75"))
	if bedroom:
		draw_rect(Rect2(340, 545, 240, 60), Color("#755c4b"))
		draw_rect(Rect2(350, 530, 220, 42), Color("#90b6ac"))
		draw_rect(Rect2(350, 530, 55, 40), Color("#eee3c9"))
		draw_rect(Rect2(1150, 555, 260, 16), Color("#927055"))
		draw_rect(Rect2(1170, 570, 12, 50), Color("#675342"))
		draw_rect(Rect2(1375, 570, 12, 50), Color("#675342"))
		draw_rect(Rect2(1220, 475, 100, 65), Color("#263e4a"))
		draw_rect(Rect2(1230, 485, 80, 43), Color("#80c4be"))
		draw_rect(Rect2(1265, 540, 12, 15), Color("#263e4a"))
	else:
		for index: int in 6:
			draw_rect(Rect2(1180 + index * 24, 610 - index * 15, 26, 18 + index * 15), Color("#87948a"))
