extends Node2D

const Interaction = preload("res://scripts/movement/world_interaction.gd")
const FONT := preload("res://assets/fonts/pixelify_sans/pixelify_sans.ttf")
const DOOR := preload("res://assets/furniture/dorm/single_door.png")
const STAIRS := preload("res://assets/furniture/dorm/stairs.png")
const WIDTH: float = 3072
const ROOM_START: float = 400
const ROOM_SPACING: float = 270

@export_range(1, 2) var floor_number: int = 1

var _doors: Array[Vector2i] = []


func _ready() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var world := get_parent()
	world.get_node("Ground").position.x = WIDTH * 0.5
	var ground := RectangleShape2D.new()
	ground.size = Vector2(WIDTH, 100)
	world.get_node("Ground/CollisionShape2D").shape = ground
	world.get_node("Walls/Right").position.x = WIDTH
	world.get_node("Player/Camera2D").limit_right = int(WIDTH)
	world.get_node("Door").position = Vector2(100, 540)
	world.get_node("InitialSpawn").position = Vector2(220, 592)
	world.get_node("InteriorSpawn").position = Vector2(220, 592)
	world.get_node("DoorSpawn").position = Vector2(220, 592)
	world.get_node("UpstairsSpawn").position = Vector2(2773, 592)
	for id: String in ["Door", "Stairs"]:
		var prompt := world.get_node(id + "/Prompt") as Control
		prompt.z_index = 5
		prompt.offset_top = -210
		prompt.offset_bottom = -166
	if floor_number == 1:
		world.get_node("Stairs").position = Vector2(2773, 540)
	else:
		world.get_node("Stairs").position = Vector2(940, 540)
		world.get_node("RoomSpawn").position = Vector2(940, 592)
	for index: int in 8:
		var number := floor_number * 100 + index + 1
		var x := int(ROOM_START + index * ROOM_SPACING)
		_doors.append(Vector2i(x, number))
		if number == 203:
			continue
		var interaction := Interaction.new()
		interaction.name = "Room%d" % number
		interaction.position = Vector2(x, 540)
		interaction.interaction_size = Vector2(90, 160)
		interaction.action = "locked_room"
		interaction.caption = "Kamar %d · Terkunci" % number
		add_child(interaction)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, WIDTH, 720), Color("#e2d4b9"))
	draw_rect(Rect2(0, 385, WIDTH, 235), Color("#a6b6ac"))
	draw_rect(Rect2(0, 610, WIDTH, 10), Color("#615545"))
	draw_rect(Rect2(0, 620, WIDTH, 100), Color("#756353"))
	for x: int in range(0, int(WIDTH), 80):
		draw_line(Vector2(x, 620), Vector2(x - 35, 720), Color("#604e43"), 2)
	for x: int in range(180, int(WIDTH), 360):
		draw_rect(Rect2(x, 100, 150, 10), Color("#fff0bc"))
	draw_string(FONT, Vector2(70, 230), "ASRAMA · LANTAI %d" % floor_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#354f59"))
	for door: Vector2i in _doors:
		_draw_door(door.x, str(door.y))
	_draw_door(100, "KELUAR" if floor_number == 1 else "TURUN")
	if floor_number == 1:
		draw_texture_rect_region(STAIRS, Rect2(2630, 134, 286, 486), Rect2(1762, 0, 286, 486))
		draw_string(FONT, Vector2(2400, 250), "NAIK · LANTAI 2", HORIZONTAL_ALIGNMENT_CENTER, 220, 20, Color("#354f59"))


func _draw_door(x: float, number: String) -> void:
	var dimensions := DOOR.get_size()
	draw_texture(DOOR, Vector2(x - dimensions.x * 0.5, 620 - dimensions.y))
	var width := 64.0 if number.is_valid_int() else 110.0
	draw_rect(Rect2(x - width * 0.5, 620 - dimensions.y - 40, width, 30), Color("#f1e3c3"))
	draw_string(FONT, Vector2(x - width * 0.5, 620 - dimensions.y - 17), number, HORIZONTAL_ALIGNMENT_CENTER, width, 22, Color("#354f59"))
