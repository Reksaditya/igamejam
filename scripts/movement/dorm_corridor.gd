extends Node2D

const Interaction = preload("res://scripts/movement/world_interaction.gd")
const FONT := preload("res://assets/fonts/pixelify_sans/pixelify_sans.ttf")
const FLOOR2_NPC_TEXTURE_PATH := "res://assets/textures/characters/npc_floor2.png"
const FLOOR2_NPC_TARGET_HEIGHT := 117.0

@export_range(1, 2) var floor_number: int = 1

var _doors: Array[Vector2i] = []


func _ready() -> void:
	z_index = -1
	var positions := [100, 270, 440, 610, 780, 1100, 1440, 1600, 1760, 1880] if floor_number == 1 else [100, 270, 440, 780, 1100, 1290, 1460, 1630, 1800]
	for index: int in positions.size():
		var number := floor_number * 100 + index + 1
		_doors.append(Vector2i(positions[index], number))
		var interaction := Interaction.new()
		interaction.name = "Room%d" % number
		interaction.position = Vector2(positions[index], 540)
		interaction.interaction_size = Vector2(60, 140)
		interaction.action = "locked_room"
		interaction.caption = "Kamar %d · Terkunci" % number
		add_child(interaction)
	if floor_number == 2:
		_doors.append(Vector2i(650, 210))
		_spawn_floor2_npc_if_available()
	queue_redraw()


func _spawn_floor2_npc_if_available() -> void:
	if not ResourceLoader.exists(FLOOR2_NPC_TEXTURE_PATH):
		return
	var tex := ResourceLoader.load(FLOOR2_NPC_TEXTURE_PATH) as Texture2D
	if tex == null or tex.get_height() <= 0:
		return
	var npc := Sprite2D.new()
	npc.name = &"Floor2Npc"
	npc.texture = tex
	npc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	npc.centered = false
	var scale_factor := FLOOR2_NPC_TARGET_HEIGHT / float(tex.get_height())
	npc.scale = Vector2.ONE * scale_factor
	npc.position = Vector2(1190.0 - tex.get_width() * scale_factor * 0.5, 620.0 - FLOOR2_NPC_TARGET_HEIGHT)
	npc.z_index = 1
	add_child(npc)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 720), Color("#e2d4b9"))
	draw_rect(Rect2(0, 385, 1920, 235), Color("#a6b6ac"))
	draw_rect(Rect2(0, 610, 1920, 10), Color("#615545"))
	draw_rect(Rect2(0, 620, 1920, 100), Color("#756353"))
	for x: int in range(0, 1920, 80):
		draw_line(Vector2(x, 620), Vector2(x - 35, 720), Color("#604e43"), 2)
	for x: int in range(180, 1920, 360):
		draw_rect(Rect2(x, 100, 150, 10), Color("#fff0bc"))
	draw_string(FONT, Vector2(70, 190), "ASRAMA · LANTAI %d" % floor_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#354f59"))
	for door: Vector2i in _doors:
		_draw_door(door.x, str(door.y), door.y == 210)
	_draw_door(925, "KELUAR" if floor_number == 1 else "TANGGA", false)
	if floor_number == 1:
		for index: int in 6:
			draw_rect(Rect2(1195 + index * 25, 610 - index * 16, 25, 10 + index * 16), Color("#6b8283"))
		draw_string(FONT, Vector2(1170, 500), "NAIK · LANTAI 2", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#354f59"))


func _draw_door(x: float, number: String, player_room: bool) -> void:
	var frame := Rect2(x - 39, 449, 78, 171)
	draw_rect(frame, Color("#534239"))
	draw_rect(frame.grow(-5), Color("#5f8278") if player_room else Color("#ae815b"))
	for y: float in [470, 535]:
		draw_rect(Rect2(x - 25, y, 50, 52), Color("#496d64") if player_room else Color("#936a4b"), false, 3)
	draw_circle(Vector2(x + 23, 535), 4, Color("#f0d08b"))
	var width := 56.0 if number.is_valid_int() else 100.0
	draw_rect(Rect2(x - width * 0.5, 410, width, 28), Color("#f1e3c3"))
	draw_string(FONT, Vector2(x - width * 0.5, 431), number, HORIZONTAL_ALIGNMENT_CENTER, width, 22, Color("#354f59"))
