extends Node2D

const ART := preload("res://assets/campus/main_world.png")
const DOOR := preload("res://scenes/movement/door_interaction.tscn")
const Interaction := preload("res://scripts/movement/world_interaction.gd")
const WIDTH: float = 3072


func _ready() -> void:
	var world := get_parent()
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.get_node("Background").hide()
	world.left_destination = ""
	world.right_destination = ""
	for id: String in ["LeftExit", "RightExit"]:
		world.get_node(id).monitoring = false
	world.get_node("Ground").position.x = WIDTH * 0.5
	var ground := RectangleShape2D.new()
	ground.size = Vector2(WIDTH, 100)
	world.get_node("Ground/CollisionShape2D").shape = ground
	var bounds := StaticBody2D.new()
	bounds.name = "CampusBounds"
	bounds.collision_mask = 0
	world.add_child(bounds)
	for x: float in [-22, WIDTH + 22]:
		var wall := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(44, 1440)
		wall.shape = shape
		wall.position = Vector2(x, 360)
		bounds.add_child(wall)
	var camera := world.get_node("Player/Camera2D") as Camera2D
	camera.limit_right = int(WIDTH)
	camera.limit_bottom = 720
	world.get_node("Player/Visual").scale = Vector2(2.3, 2.3)
	world.get_node("Player/Visual").position.y = -46
	var college := world.get_node("Door")
	college.position = Vector2(1755, 540)
	college.destination = "res://scenes/movement/classroom_corridor_floor1.tscn"
	college.destination_spawn = &"InteriorSpawn"
	college.action_text = "Masuk gedung kuliah"
	college.get_node("Prompt").z_index = 5
	college._refresh_prompt()
	var dorm := DOOR.instantiate()
	dorm.name = "DormDoor"
	dorm.position = Vector2(610, 540)
	dorm.destination = "res://scenes/movement/dorm_floor1.tscn"
	dorm.destination_spawn = &"InteriorSpawn"
	dorm.action_text = "Masuk asrama"
	dorm.get_node("Prompt").z_index = 5
	world.add_child(dorm)
	var library := Interaction.new()
	library.name = "LibraryDoor"
	library.position = Vector2(2505, 540)
	library.action = "unavailable_building"
	library.caption = "Perpustakaan"
	library.interaction_size = Vector2(120, 160)
	world.add_child(library)
	library._prompt.position.y = -220
	_sign("ASRAMA", Vector2(380, 430), 140)
	_sign("GEDUNG KULIAH", Vector2(1480, 425), 170)
	_sign("PERPUSTAKAAN", Vector2(2290, 405), 160)
	_sign("GEDUNG BELUM TERSEDIA", Vector2(2220, 447), 230)
	world.get_node("DoorSpawn").position = Vector2(1755, 592)
	world.get_node("InitialSpawn").position = Vector2(900, 592)
	var dorm_spawn := Marker2D.new()
	dorm_spawn.name = "DormSpawn"
	dorm_spawn.position = Vector2(610, 592)
	world.add_child(dorm_spawn)


func _sign(value: String, point: Vector2, width: float) -> void:
	var label := Label.new()
	label.theme = preload("res://scenes/ui/menu_theme.tres")
	label.text = value
	label.position = point
	label.size = Vector2(width, 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#fff1d2"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#233641")
	style.border_color = Color("#dfc18a")
	style.set_border_width_all(2)
	label.add_theme_stylebox_override("normal", style)
	add_child(label)


func _draw() -> void:
	draw_rect(Rect2(-4096, -4096, WIDTH + 8192, 8192), Color("#97def0"))
	draw_rect(Rect2(-4096, 592, WIDTH + 8192, 4096), Color("#706e65"))
	draw_texture(ART, Vector2(0, 80))
