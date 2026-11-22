extends Control

const Puzzle = preload("res://scripts/interaction/workshop/transmission_puzzle.gd")
const BRASS := Color("#ecb670")
const STEEL := Color("#add1ce")
const INK := Color("#182527")
const CLUE := Color("#ffe0a1")

var puzzle: Puzzle
var sheet := false
var idler_fitted := false
var idler_selected := false
var turns := PackedFloat32Array()
var contacts: Array[Vector2i] = []
var spin_rates: Dictionary[int, int] = {}
var spin_angles: Dictionary[int, float] = {}
var output_result := 0
var result_passed := false
var preview_carrier := -1
var locked := false
var _gear_layer: Node2D
var _overlay: Node2D
var _gears: Array[Node2D] = []


func _ready() -> void:
	resized.connect(refresh)


func plate_scale() -> float:
	return minf(size.x / Puzzle.PLATE_SIZE.x, size.y / Puzzle.PLATE_SIZE.y)


func screen_position(point: Vector2) -> Vector2:
	var scale_factor := plate_scale()
	return (size - Puzzle.PLATE_SIZE * scale_factor) * 0.5 + point * scale_factor


func refresh() -> void:
	queue_redraw()
	if puzzle == null or sheet:
		return
	if _gear_layer == null:
		_build_gear_layer()
	_gear_layer.position = screen_position(Vector2.ZERO)
	_gear_layer.scale = Vector2.ONE * plate_scale()
	_gears[Puzzle.IDLER].visible = idler_fitted
	for socket: int in range(Puzzle.FIRST_CARRIER):
		_gears[socket].position = puzzle.socket_position(socket)
		_gears[socket].rotation = spin_angles.get(socket, 0.0)
	for carrier: int in range(Puzzle.CARRIER_COUNT):
		var gear := _gears[Puzzle.FIRST_CARRIER + carrier]
		var socket := puzzle.socket_id(carrier, roundi(turns[carrier]))
		gear.position = puzzle.carrier_gear_position(carrier, turns[carrier])
		gear.rotation = spin_angles.get(socket, 0.0)
	_overlay.queue_redraw()


func _build_gear_layer() -> void:
	_gear_layer = Node2D.new()
	add_child(_gear_layer)
	move_child(_gear_layer, 0)
	for part: int in range(Puzzle.FIRST_CARRIER + Puzzle.CARRIER_COUNT):
		var gear := Node2D.new()
		var socket := part if part < Puzzle.FIRST_CARRIER else puzzle.socket_id(part - Puzzle.FIRST_CARRIER, 0)
		var metal := BRASS if part == Puzzle.MOTOR else STEEL
		gear.draw.connect(draw_gear.bind(gear, Vector2.ZERO, metal, 0.0, puzzle.pitch_radius(socket)))
		_gear_layer.add_child(gear)
		_gears.append(gear)
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	_gear_layer.add_child(_overlay)


func _process(delta: float) -> void:
	if spin_rates.is_empty():
		return
	for socket: int in spin_rates:
		var speed := 165.0 / puzzle.pitch_radius(socket)
		var angle := fposmod(spin_angles.get(socket, 0.0) + delta * spin_rates[socket] * speed, TAU)
		spin_angles[socket] = angle
		var gear := socket
		if socket >= Puzzle.FIRST_CARRIER:
			@warning_ignore("integer_division")
			gear = Puzzle.FIRST_CARRIER + (socket - Puzzle.FIRST_CARRIER) / Puzzle.SOCKETS_PER_CARRIER
		_gears[gear].rotation = angle


func _draw() -> void:
	if puzzle == null:
		return
	draw_set_transform(screen_position(Vector2.ZERO), 0.0, Vector2.ONE * plate_scale())
	var face := Rect2(Vector2(4, 4), Puzzle.PLATE_SIZE - Vector2(8, 8))
	if sheet:
		_draw_sheet(face)
		return
	draw_rect(Rect2(face.position + Vector2(0, 5), face.size), Color("#121e20"))
	draw_rect(face, Color("#344a49"))
	draw_rect(face.grow(-7.0), Color("#293a3a"))
	draw_rect(face.grow(-8.0), Color("#627979"), false, 1.0)
	for y: float in [22.0, Puzzle.PLATE_SIZE.y - 22.0]:
		for x: float in [22.0, Puzzle.PLATE_SIZE.x - 22.0]:
			_bolt(Vector2(x, y))

	for carrier: int in range(Puzzle.CARRIER_COUNT):
		var pivot := puzzle.carrier_pivots[carrier]
		var radius := pivot.distance_to(puzzle.carrier_first_sockets[carrier])
		draw_arc(pivot, radius, 0, TAU, 48, Color("#364b4b"), 1.0, true)
		for rotation: int in range(4):
			_socket(puzzle.socket_position(puzzle.socket_id(carrier, rotation)))
	_socket(puzzle.idler_socket, idler_selected)

	for carrier: int in range(Puzzle.CARRIER_COUNT):
		var pivot := puzzle.carrier_pivots[carrier]
		var tip := puzzle.carrier_gear_position(carrier, turns[carrier])
		var highlighted := carrier == preview_carrier
		draw_line(pivot + Vector2(3, 4), tip + Vector2(3, 4), INK, 11.0, true)
		draw_line(pivot, tip, CLUE if highlighted else Color("#829592"), 8.0, true)
		draw_line(pivot, tip, Color("#526662"), 2.0, true)
		draw_circle(pivot, 15, Color("#111c1e"), true, -1, true)

	var housing := Rect2(puzzle.motor_socket - Vector2(53, 50), Vector2(106, 100))
	draw_rect(housing, Color("#3f5756"))
	draw_rect(housing, Color("#718985"), false, 2.0)
	_plate_label("MOTOR", puzzle.motor_socket - Vector2(0, 57))
	_plate_label("OUTPUT", puzzle.output_socket + Vector2(87, 43))


func _draw_overlay() -> void:
	for pair: Vector2i in contacts:
		if spin_rates.has(pair.x) and spin_rates.has(pair.y):
			var from := puzzle.socket_position(pair.x)
			var to := puzzle.socket_position(pair.y)
			var contact := from + from.direction_to(to) * puzzle.pitch_radius(pair.x)
			_overlay.draw_circle(contact, 8.0, Color("#ffcf70"), false, 2.0, true)
			_overlay.draw_circle(contact, 3.0, CLUE, true, -1, true)
	if preview_carrier >= 0:
		_draw_carrier_preview(preview_carrier)
	if output_result != 0:
		var result_color := Color("#a9e4be") if result_passed else Color("#ffae91")
		_arrow(_overlay, puzzle.output_socket, 33.0, output_result, result_color)
	if locked:
		var face := Rect2(Vector2(4, 4), Puzzle.PLATE_SIZE - Vector2(8, 8))
		_overlay.draw_rect(face, Color(0.04, 0.07, 0.08, 0.49))


func _draw_carrier_preview(carrier: int) -> void:
	var pivot := puzzle.carrier_pivots[carrier]
	var turn := turns[carrier]
	var current := puzzle.carrier_gear_position(carrier, turn)
	var next := puzzle.carrier_gear_position(carrier, turn + 1.0)
	var radius := puzzle.pitch_radius(puzzle.socket_id(carrier, roundi(turn)))
	draw_gear(_overlay, next, Color(1.0, 0.84, 0.54, 0.28), 0.0, radius)
	_overlay.draw_arc(next, radius + 4.0, 0, TAU, 40, Color(1.0, 0.84, 0.54, 0.64), 2.0, true)
	_overlay.draw_arc(current, radius + 4.0, 0, TAU, 40, CLUE, 2.0, true)
	_arc_arrow(_overlay, pivot, 27.0, (current - pivot).angle(), PI / 2.0, CLUE)


func _draw_sheet(face: Rect2) -> void:
	draw_rect(face, Color("#23495f"))
	draw_rect(face.grow(-9.0), Color("#739baa"), false, 2.0)
	for x: int in range(16, 455, 19):
		draw_line(Vector2(x, 15), Vector2(x, 351), Color("#345c71"))
	for y: int in range(15, 352, 19):
		draw_line(Vector2(16, y), Vector2(454, y), Color("#345c71"))
	for carrier: int in range(Puzzle.CARRIER_COUNT):
		var pivot := puzzle.carrier_pivots[carrier]
		draw_arc(pivot, pivot.distance_to(puzzle.carrier_first_sockets[carrier]), 0, TAU, 40, Color("#7297ac"), 2.5, true)
		draw_circle(pivot, 4, Color("#e0eef1"), true, -1, true)
		for rotation: int in range(4):
			var socket := puzzle.socket_id(carrier, rotation)
			var point := puzzle.socket_position(socket)
			var clue := socket == puzzle.clue_socket
			draw_circle(point, 11.0, CLUE if clue else Color("#d7e7ea"), false, 4.0 if clue else 2.0, true)
			if clue:
				draw_circle(point, 4.0, CLUE, true, -1, true)
	for position: Vector2 in [puzzle.motor_socket, puzzle.output_socket]:
		draw_circle(position, 18.0, Color("#e4f1f1"), false, 3.0, true)
		draw_circle(position, 6.0, Color("#e4f1f1"), false, 2.0, true)
	draw_circle(puzzle.idler_socket, 9, Color("#e4f1f1"), false, 2.0, true)
	_diagram_label("M", puzzle.motor_socket - Vector2(0, 25))
	_diagram_label("OUT", puzzle.output_socket + Vector2(0, 55))
	_arrow(self, puzzle.output_socket, 30.0, puzzle.required_output_direction, CLUE)


func _socket(point: Vector2, selected := false) -> void:
	draw_circle(point, 10, CLUE if selected else Color("#5a7170"), false, 2 if selected else 1, true)
	draw_circle(point, 4, Color("#1d2e30"), true, -1, true)


func _bolt(point: Vector2) -> void:
	draw_circle(point, 5.5, Color("#788783"), true, -1, true)
	draw_line(point + Vector2(-3, 2), point + Vector2(3, -2), INK, 1.5, true)


static func draw_gear(canvas: CanvasItem, point: Vector2, metal: Color, phase := 0.0, radius := 21.0) -> void:
	var edge := PackedVector2Array()
	var teeth := maxi(8, roundi(radius * 0.57))
	for tooth: int in range(teeth):
		for step: int in range(4):
			var angle := phase + TAU * (tooth + step * 0.25) / teeth
			edge.append(point + Vector2.from_angle(angle) * (radius + 2.0 if step in [1, 2] else radius - 3.0))
	canvas.draw_circle(point + Vector2(2, 3), radius, Color(INK, metal.a), true, -1, true)
	canvas.draw_colored_polygon(edge, metal)
	canvas.draw_circle(point, radius - 6.0, metal.darkened(0.48), true, -1, true)
	canvas.draw_circle(point, radius - 8.0, metal.darkened(0.30), false, 1.0, true)
	for spoke: int in range(3):
		var heading := Vector2.from_angle(phase + spoke * TAU / 3)
		canvas.draw_line(point + heading * 6.0, point + heading * (radius - 8.0), metal, 3.0, true)
	canvas.draw_circle(point, 5.0, Color(INK, metal.a), true, -1, true)
	canvas.draw_circle(point - Vector2(1, 1), 2.0, metal, true, -1, true)


func _arrow(canvas: CanvasItem, center: Vector2, radius: float, direction: int, color: Color) -> void:
	_arc_arrow(canvas, center, radius, -PI / 2 - direction * 0.65, direction * 4.6, color)


func _arc_arrow(canvas: CanvasItem, center: Vector2, radius: float, start: float, sweep: float, color: Color) -> void:
	var end := start + sweep
	canvas.draw_arc(center, radius, minf(start, end), maxf(start, end), 26, color, 4.0, true)
	var radial := Vector2.from_angle(end)
	var tip := center + radial * radius
	var tangent := Vector2(-radial.y, radial.x)
	var tail := tip - tangent * signf(sweep) * 10.0
	canvas.draw_colored_polygon(PackedVector2Array([tip, tail - radial * 5.0, tail + radial * 5.0]), color)


func _plate_label(value: String, at: Vector2) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0
	draw_rect(Rect2(at - Vector2(width * 0.5, 15), Vector2(width, 20)), INK)
	draw_string(font, at - Vector2(width * 0.5 - 7, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, STEEL)


func _diagram_label(value: String, at: Vector2) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(font, at - Vector2(width * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#e4f1f1"))
