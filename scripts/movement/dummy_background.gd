extends Node2D

@export var laboratory: bool = false
@export var interior: bool = false


func _draw() -> void:
	if interior:
		_draw_interior()
		return
	var sky := Color("#b4ccd2") if laboratory else Color("#b9d7df")
	var distant := Color("#819ea8") if laboratory else Color("#95b7be")
	var wall := Color("#d8d3bc") if laboratory else Color("#e5d8bd")
	draw_rect(Rect2(0, 0, 1920, 720), sky)
	draw_circle(Vector2(1550, 110), 52.0, Color("#f7e5b0"))
	for index: int in range(9):
		var x := float(index * 240)
		var height := 140.0 + float(index % 3) * 35.0
		draw_rect(Rect2(x, 420.0 - height, 190, height), distant)
	draw_rect(Rect2(0, 420, 1920, 200), Color("#92aa99"))
	var building := Rect2(330, 220, 1260, 360) if laboratory else Rect2(420, 270, 1080, 310)
	draw_rect(building, wall)
	draw_rect(Rect2(building.position - Vector2(18, 14), Vector2(building.size.x + 36, 20)), Color("#546c78"))
	for row: int in range(2):
		for column: int in range(8):
			var window := Rect2(building.position + Vector2(45 + column * 125, 45 + row * 105), Vector2(74, 65))
			draw_rect(window.grow(5), Color("#f0e9d5"))
			draw_rect(window, Color("#587c8c"))
			draw_line(window.position + Vector2(37, 0), window.position + Vector2(37, 65), Color("#bcd1d1"), 3.0)
	draw_rect(Rect2(880, 460, 90, 120), Color("#476574"))
	draw_rect(Rect2(925, 470, 3, 110), Color("#a3bbc0"))
	draw_rect(Rect2(0, 580, 1920, 40), Color("#b6b8aa"))
	if not laboratory:
		for x: float in [210.0, 1690.0]:
			draw_rect(Rect2(x - 9, 420, 18, 160), Color("#796e58"))
			draw_circle(Vector2(x, 412), 64.0, Color("#648d79"))
			draw_circle(Vector2(x - 30, 445), 42.0, Color("#719b81"))
	else:
		for x: float in [170.0, 1700.0]:
			draw_rect(Rect2(x, 520, 95, 60), Color("#637b88"))
			draw_rect(Rect2(x + 10, 530, 75, 22), Color("#abc5cc"))
	draw_rect(Rect2(0, 620, 1920, 100), Color("#596c6e"))
	draw_rect(Rect2(0, 620, 1920, 8), Color("#ded2ae"))
	for x: int in range(0, 1920, 80):
		draw_line(Vector2(x, 630), Vector2(x + 20, 720), Color("#4e6063"), 2.0)


func _draw_interior() -> void:
	draw_rect(Rect2(0, 0, 1920, 720), Color("#e0dac8"))
	draw_rect(Rect2(0, 0, 1920, 100), Color("#b5b9af"))
	draw_rect(Rect2(0, 510, 1920, 110), Color("#bdc8bd"))
	draw_rect(Rect2(0, 610, 1920, 10), Color("#7a8c85"))
	for x: int in [200, 650, 1100, 1550]:
		draw_rect(Rect2(x, 72, 160, 12), Color("#fff1ca"))
	draw_rect(Rect2(140, 210, 570, 260), Color("#a3a999"))
	draw_rect(Rect2(150, 220, 550, 240), Color("#416963"))
	for index: int in range(4):
		draw_line(Vector2(185, 265 + index * 38), Vector2(470 + index * 35, 265 + index * 38), Color("#cfddd0"), 3.0)
	draw_rect(Rect2(880, 460, 90, 160), Color("#476574"))
	draw_rect(Rect2(890, 475, 70, 75), Color("#9ab9bd"))
	draw_circle(Vector2(952, 572), 4.0, Color("#f5d78b"))
	for x: int in [180, 480, 1200, 1500]:
		draw_rect(Rect2(x, 535, 180, 14), Color("#917c64"))
		draw_rect(Rect2(x + 12, 549, 12, 71), Color("#617573"))
		draw_rect(Rect2(x + 156, 549, 12, 71), Color("#617573"))
		if laboratory:
			draw_rect(Rect2(x + 50, 480, 80, 55), Color("#698b98"))
			draw_rect(Rect2(x + 60, 490, 60, 30), Color("#bde2dd"))
		else:
			draw_rect(Rect2(x + 50, 525, 70, 10), Color("#e9c990"))
	draw_rect(Rect2(0, 620, 1920, 100), Color("#778786"))
	for x: int in range(0, 1920, 120):
		draw_line(Vector2(x, 620), Vector2(x - 50, 720), Color("#647573"), 2.0)
	draw_line(Vector2(0, 665), Vector2(1920, 665), Color("#647573"), 2.0)
