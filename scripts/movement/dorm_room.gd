extends "res://scripts/movement/side_scroller_world.gd"

const ROOM := preload("res://assets/furniture/dorm/room210.png")

@export_range(0.1, 5.0) var sleep_pose_seconds: float = 1.8

var room_rect := Rect2()
var floor_y: float = 0
var sleeping: bool = false
var _bounds: StaticBody2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	$Player/Camera2D.enabled = true
	$Player/Camera2D.limit_right = 2048
	$Player/Camera2D.limit_bottom = 720
	$Player.z_index = 3
	$Background.hide()
	$Ground/CollisionShape2D.disabled = true
	$LeftExit.monitoring = false
	$RightExit.monitoring = false
	_build_bounds()
	_layout(false)
	super._ready()
	_confine_player()


func _build_bounds() -> void:
	_bounds = StaticBody2D.new()
	_bounds.name = "RoomBounds"
	_bounds.collision_mask = 0
	add_child(_bounds)
	for id: String in ["Left", "Right", "Floor", "Ceiling"]:
		var collision := CollisionShape2D.new()
		collision.name = id
		collision.shape = RectangleShape2D.new()
		_bounds.add_child(collision)


func _wall(id: String, point: Vector2, dimensions: Vector2) -> void:
	var collision := _bounds.get_node(id) as CollisionShape2D
	(collision.shape as RectangleShape2D).size = dimensions
	collision.position = point


func _layout(keep_position: bool = true) -> void:
	var player := $Player as CharacterBody2D
	var ratio := (player.position.x - 22) / (room_rect.size.x - 44) if room_rect.size.x > 44 else 0.12
	var view := Vector2(2048, 576)
	room_rect = Rect2(Vector2(0, 80), view)
	floor_y = 80 + view.y * 0.94
	var center := room_rect.get_center()
	_wall("Left", Vector2(-20, center.y), Vector2(40, 1440))
	_wall("Right", Vector2(view.x + 20, center.y), Vector2(40, 1440))
	_wall("Floor", Vector2(center.x, floor_y + 20), Vector2(view.x + 80, 40))
	_wall("Ceiling", Vector2(center.x, -20), Vector2(view.x + 80, 40))
	$Furniture/Bed.scale = Vector2.ONE
	$Furniture/Bed.position = room_rect.position
	$Furniture/Roommate.scale = Vector2(0.48, 0.48)
	$Furniture/Roommate.position = Vector2(view.x * 0.86, floor_y - 96)
	$Player/Visual.scale = Vector2(3, 3)
	$Player/Visual.position.y = -66
	$Bed.position = Vector2(view.x * 0.39, floor_y - 50)
	$Computer.position = Vector2(view.x * 0.63, floor_y - 50)
	$Door.position = Vector2(view.x * 0.055, floor_y - 70)
	$Door/Prompt.position.x = 0
	$Door/Prompt.z_index = 5
	$Door/Prompt.offset_top = -210
	$Door/Prompt.offset_bottom = -166
	var shape := RectangleShape2D.new()
	shape.size = Vector2(70, 180)
	$Door/CollisionShape2D.shape = shape
	$InitialSpawn.position = Vector2(view.x * 0.13, floor_y - 28)
	$InteriorSpawn.position = $InitialSpawn.position
	$DoorSpawn.position = $InitialSpawn.position
	$ComputerSpawn.position = Vector2($Computer.position.x, floor_y - 28)
	if keep_position and not sleeping:
		player.position = Vector2(22 + clampf(ratio, 0, 1) * (view.x - 44), floor_y - 28)
	_confine_player()
	queue_redraw()


func get_player_save_position(player: CharacterBody2D) -> Vector2:
	var ratio := clampf((player.position.x - 22) / (room_rect.size.x - 44), 0, 1)
	return Vector2(80 + ratio * 1760, 400)


func restore_player_position(player: CharacterBody2D, saved: Vector2) -> void:
	var ratio := (saved.x - 80) / 1760.0 if saved.y == 400 else saved.x / 1920.0
	player.position = Vector2(22 + clampf(ratio, 0, 1) * (room_rect.size.x - 44), floor_y - 28)


func _physics_process(_delta: float) -> void:
	if not sleeping:
		_confine_player()


func _confine_player() -> void:
	var player := $Player as CharacterBody2D
	player.position.x = clampf(player.position.x, 22, room_rect.end.x - 22)
	if player.position.y > floor_y - 28:
		player.position.y = floor_y - 28
		player.velocity.y = 0


func play_sleep() -> void:
	var player := $Player as CharacterBody2D
	var visual := $Player/Visual as Node2D
	var standing_position := player.position
	var standing_offset := visual.position
	sleeping = true
	player.set_studying(true)
	player.z_index = 1
	var sprite := $Player/Visual/AnimatedSprite2D as AnimatedSprite2D
	sprite.play(&"idle")
	sprite.stop()
	sprite.frame = 0
	visual.position = Vector2.ZERO
	visual.rotation = -PI * 0.5
	player.position = room_rect.position + Vector2(room_rect.size.x * 0.37, room_rect.size.y * 0.54)
	await get_tree().create_timer(sleep_pose_seconds, true).timeout
	visual.rotation = 0
	visual.position = standing_offset
	player.set_studying(false)
	player.z_index = 3
	player.position = standing_position
	sleeping = false


func _draw() -> void:
	draw_rect(Rect2(-4096, -4096, 10240, 8192), Color("#c5c5ae"))
	draw_rect(Rect2(-4096, floor_y, 10240, 4096), Color("#bebeb3"))
	draw_texture_rect(ROOM, room_rect, false)
