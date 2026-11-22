extends Control

const CORRIDOR_TEXTURE: Texture2D = preload("res://assets/classroom/corridor/floor1.png")
const SOURCE_LEFT_ANCHOR := 508.0
const VERTICAL_ZOOM := 1.08


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func _draw() -> void:
	if CORRIDOR_TEXTURE == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var tex_size := CORRIDOR_TEXTURE.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var view_aspect := size.x / size.y
	var src_h := tex_size.y / VERTICAL_ZOOM
	var src_w := src_h * view_aspect
	if src_w > tex_size.x:
		src_w = tex_size.x
		src_h = minf(tex_size.y, src_w / view_aspect)
	var src_x := clampf(SOURCE_LEFT_ANCHOR, 0.0, maxf(0.0, tex_size.x - src_w))
	draw_texture_rect_region(
		CORRIDOR_TEXTURE,
		Rect2(Vector2.ZERO, size),
		Rect2(src_x, 0.0, src_w, src_h)
	)
