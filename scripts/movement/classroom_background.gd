extends "res://scripts/movement/dummy_background.gd"

const CLASSROOM := preload("res://assets/classroom/background.png")
const LEGACY := preload("res://assets/classroom/background_legacy.png")


func _draw() -> void:
	if laboratory:
		super._draw()
		return
	var activity := get_parent().get_node_or_null("ClassActivity")
	var artwork: Texture2D = LEGACY if activity != null and not activity.classroom_enabled else CLASSROOM
	draw_rect(Rect2(0, 0, 1920, 720), Color("#dfc1a0") if artwork == LEGACY else Color("#ebddcf"))
	draw_texture_rect(artwork, Rect2(0, 80, 1920, 540), false)
	draw_rect(Rect2(0, 620, 1920, 100), Color("#beb6ae"))
