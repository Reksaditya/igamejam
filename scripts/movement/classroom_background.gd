extends "res://scripts/movement/dummy_background.gd"

const CLASSROOM := preload("res://assets/classroom/background.png")


func _draw() -> void:
	if laboratory:
		super._draw()
		return
	draw_rect(Rect2(0, 0, 1920, 720), Color("#dfc1a0"))
	draw_texture_rect(CLASSROOM, Rect2(0, 80, 1920, 540), false)
	draw_rect(Rect2(0, 620, 1920, 100), Color("#beb6ae"))
