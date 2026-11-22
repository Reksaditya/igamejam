extends "res://scripts/movement/side_scroller_world.gd"

const FONT := preload("res://assets/fonts/pixelify_sans/pixelify_sans.ttf")

var room_rect := Rect2()
var floor_y: float = 0
var _pixel_scale: float = 4
var _bounds: StaticBody2D
var _desk_rect := Rect2()
var _lamp_point := Vector2()
var _lamp_scale: float = 1


func _ready() -> void:
	$Player/Camera2D.enabled = false
	$Player.z_index = 3
	$Background.hide()
	$Ground/CollisionShape2D.disabled = true
	$LeftExit.monitoring = false
	$RightExit.monitoring = false
	_build_bounds()
	_layout(false)
	super._ready()
	GameClock.set_room_paused(true)
	_confine_player()
	get_viewport().size_changed.connect(_layout, CONNECT_DEFERRED)


func _exit_tree() -> void:
	GameClock.set_room_paused(false)


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
	var ratio := (player.position.x - room_rect.position.x - 22) / (room_rect.size.x - 44) if room_rect.size.x > 44 else 0.4
	var view := get_viewport().get_visible_rect().size
	room_rect = Rect2((view * 0.2).round(), (view * 0.6).round())
	_pixel_scale = clampf(floorf(view.y / 180.0), 2, 4)
	floor_y = room_rect.end.y - 20
	var center := room_rect.get_center()
	_wall("Left", Vector2(room_rect.position.x - 20, center.y), Vector2(40, room_rect.size.y + 80))
	_wall("Right", Vector2(room_rect.end.x + 20, center.y), Vector2(40, room_rect.size.y + 80))
	_wall("Floor", Vector2(center.x, floor_y + 20), Vector2(room_rect.size.x + 80, 40))
	_wall("Ceiling", Vector2(center.x, room_rect.position.y - 20), Vector2(room_rect.size.x + 80, 40))
	var bed := $Furniture/Bed as Sprite2D
	bed.scale = Vector2.ONE * _pixel_scale
	bed.position = Vector2(room_rect.position.x + 25 * _pixel_scale, floor_y - bed.texture.get_height() * _pixel_scale)
	var table := $Furniture/Nightstand as Sprite2D
	var table_scale := maxf(2, _pixel_scale - 1)
	table.scale = Vector2.ONE * table_scale
	table.position = Vector2(bed.position.x + bed.texture.get_width() * _pixel_scale + 3 * _pixel_scale, floor_y - table.texture.get_height() * table_scale)
	_lamp_point = Vector2(table.position.x + table.texture.get_width() * table_scale * 0.5, table.position.y + table_scale)
	_lamp_scale = maxf(1, table_scale * 0.6)
	var clock := $Furniture/Clock as Sprite2D
	clock.scale = Vector2.ONE * table_scale
	clock.position = Vector2(center.x - clock.texture.get_width() * table_scale * 0.5, room_rect.position.y + 28)
	_desk_rect = Rect2(room_rect.end.x - 52 * _pixel_scale, floor_y - 17 * _pixel_scale, 44 * _pixel_scale, 17 * _pixel_scale)
	$Chair.position = Vector2(_desk_rect.position.x - 11 * _pixel_scale, floor_y - 30)
	$Chair.seat_offset = Vector2(0, 20 - 9 * table_scale)
	var chair := $Furniture/Chair as Sprite2D
	chair.scale = Vector2.ONE * table_scale
	chair.position = Vector2($Chair.position.x - chair.texture.get_width() * table_scale * 0.75, floor_y - chair.texture.get_height() * table_scale).round()
	$Bed.position = Vector2(bed.position.x + bed.texture.get_width() * _pixel_scale * 0.5, floor_y - 40)
	$Computer.position = Vector2(_desk_rect.get_center().x, floor_y - 50)
	$Door.position = Vector2(room_rect.position.x + 10 * _pixel_scale, floor_y - 70)
	var door_shape := $Door/CollisionShape2D as CollisionShape2D
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60, 140)
	door_shape.shape = shape
	$InitialSpawn.position = Vector2($Door.position.x + 75, floor_y - 28)
	$InteriorSpawn.position = $InitialSpawn.position
	$DoorSpawn.position = $InitialSpawn.position
	$ComputerSpawn.position = Vector2(_desk_rect.get_center().x, floor_y - 28)
	if keep_position:
		player.position = Vector2(room_rect.position.x + 22 + clampf(ratio, 0, 1) * (room_rect.size.x - 44), floor_y - 28)
		$Chair.update_seat()
	_confine_player()
	queue_redraw()


func get_player_save_position(player: CharacterBody2D) -> Vector2:
	var ratio := clampf((player.position.x - room_rect.position.x - 22) / (room_rect.size.x - 44), 0, 1)
	return Vector2(80 + ratio * 1760, 400)


func restore_player_position(player: CharacterBody2D, saved: Vector2) -> void:
	var ratio := (saved.x - 80) / 1760.0 if saved.y == 400 else saved.x / 1920.0
	player.position = Vector2(room_rect.position.x + 22 + clampf(ratio, 0, 1) * (room_rect.size.x - 44), floor_y - 28)


func _physics_process(_delta: float) -> void:
	_confine_player()


func _confine_player() -> void:
	var player := $Player as CharacterBody2D
	player.position.x = clampf(player.position.x, room_rect.position.x + 22, room_rect.end.x - 22)
	if player.position.y > floor_y - 28:
		player.position.y = floor_y - 28
		player.velocity.y = 0


func _draw() -> void:
	var view := get_viewport().get_visible_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#141416"))
	draw_rect(room_rect.grow(6), Color("#625346"))
	draw_rect(room_rect, Color("#e4d7ba"))
	draw_rect(Rect2(room_rect.position.x, floor_y - 80, room_rect.size.x, 80), Color("#acbbae"))
	draw_rect(Rect2(room_rect.position.x, floor_y - 6, room_rect.size.x, 6), Color("#655140"))
	draw_rect(Rect2(room_rect.position.x, floor_y, room_rect.size.x, room_rect.end.y - floor_y), Color("#8a6c50"))
	for x: int in range(int(room_rect.position.x), int(room_rect.end.x), 48):
		draw_line(Vector2(x, floor_y), Vector2(x + 8, room_rect.end.y), Color("#6f543f"), 2)
	var door_x: float = $Door.position.x
	draw_rect(Rect2(door_x - 30, floor_y - 140, 60, 140), Color("#674d3c"))
	draw_rect(Rect2(door_x - 24, floor_y - 134, 48, 130), Color("#a87e55"))
	draw_circle(Vector2(door_x + 17, floor_y - 72), 3, Color("#ebd19b"))
	draw_rect(Rect2(door_x - 23, floor_y - 170, 46, 24), Color("#f0e0bb"))
	draw_string(FONT, Vector2(door_x - 23, floor_y - 152), "210", HORIZONTAL_ALIGNMENT_CENTER, 46, 20, Color("#3d4e55"))
	draw_rect(Rect2(_desk_rect.position, Vector2(_desk_rect.size.x, 3 * _pixel_scale)), Color("#a77a4e"))
	for x: float in [_desk_rect.position.x + 3 * _pixel_scale, _desk_rect.end.x - 5 * _pixel_scale]:
		draw_rect(Rect2(x, _desk_rect.position.y + 3 * _pixel_scale, 2 * _pixel_scale, _desk_rect.size.y - 3 * _pixel_scale), Color("#795839"))
	var laptop := Rect2(_desk_rect.get_center().x - 9 * _pixel_scale, _desk_rect.position.y - 12 * _pixel_scale, 18 * _pixel_scale, 11 * _pixel_scale)
	draw_rect(laptop, Color("#283c49"))
	draw_rect(laptop.grow(-_pixel_scale), Color("#83b7b4"))
	draw_rect(Rect2(laptop.position.x - 2 * _pixel_scale, laptop.end.y, laptop.size.x + 4 * _pixel_scale, _pixel_scale), Color("#465d67"))
	draw_rect(Rect2(_lamp_point + Vector2(-7, -3) * _lamp_scale, Vector2(14, 3) * _lamp_scale), Color("#6a5b45"))
	draw_rect(Rect2(_lamp_point + Vector2(-1, -20) * _lamp_scale, Vector2(2, 18) * _lamp_scale), Color("#6a5b45"))
	var shade := PackedVector2Array([_lamp_point + Vector2(-6, -33) * _lamp_scale, _lamp_point + Vector2(6, -33) * _lamp_scale, _lamp_point + Vector2(11, -18) * _lamp_scale, _lamp_point + Vector2(-11, -18) * _lamp_scale])
	draw_colored_polygon(shade, Color("#f4dfa0"))
	draw_polyline(PackedVector2Array([shade[0], shade[1], shade[2], shade[3], shade[0]]), Color("#6a5b45"), 2)
