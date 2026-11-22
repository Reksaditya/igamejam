extends Control

const Puzzle = preload("res://scripts/interaction/workshop/transmission_puzzle.gd")
const RailSlider = preload("res://scripts/interaction/workshop/transmission_slider.gd")
const BRASS := Color("#ecb670")
const STEEL := Color("#add1ce")
const INK := Color("#182527")
const CLUE := Color("#ffe0a1")
const PLATE_FONT: Font = preload("res://assets/fonts/pixelify_sans/PixelifySans-SemiBold.ttf")

var puzzle: Puzzle
var sheet := false
var turns := PackedFloat32Array()
var slider_values := PackedFloat32Array()
var contacts: Array[Vector2i] = []
var spin_rates: Dictionary[int, int] = {}
var spin_angles: Dictionary[int, float] = {}
var output_result := 0
var result_passed := false
var preview_carrier := -1
var preview_slider := -1
var dragging_slider := -1
var locked := false
var _built_puzzle: Puzzle
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


func clear_gear_layer() -> void:
	if is_instance_valid(_gear_layer):
		remove_child(_gear_layer)
		_gear_layer.queue_free()
	_gear_layer = null
	_overlay = null
	_built_puzzle = null
	_gears.clear()


func refresh() -> void:
	queue_redraw()
	if sheet:
		return
	if puzzle == null:
		clear_gear_layer()
		return
	if _gear_layer == null or _built_puzzle != puzzle:
		clear_gear_layer()
		_build_gear_layer()
	_gear_layer.position = screen_position(Vector2.ZERO)
	_gear_layer.scale = Vector2.ONE * plate_scale()

	var fixed_end := Puzzle.FIRST_FIXED + puzzle.fixed_count()
	for socket: int in range(fixed_end):
		_gears[socket].position = puzzle.socket_position(socket)
		_gears[socket].rotation = spin_angles.get(socket, 0.0)

	for carrier: int in range(puzzle.carrier_count()):
		var part_idx := fixed_end + carrier
		var turn := turns[carrier] if carrier < turns.size() else float(puzzle.starting_rotations[carrier])
		var socket := puzzle.carrier_socket_id(carrier, roundi(turn))
		_gears[part_idx].position = puzzle.carrier_gear_position(carrier, turn)
		_gears[part_idx].rotation = spin_angles.get(socket, 0.0)

	var carrier_end := fixed_end + puzzle.carrier_count()
	for slider_idx: int in range(puzzle.slider_count()):
		var part_idx := carrier_end + slider_idx
		var slider := puzzle.sliders[slider_idx]
		var stop_val := slider_values[slider_idx] if slider_idx < slider_values.size() else float(slider.starting_stop)
		var socket := puzzle.slider_socket_id(slider_idx, slider.nearest_stop(stop_val))
		_gears[part_idx].position = puzzle.slider_gear_position(slider_idx, stop_val)
		_gears[part_idx].rotation = spin_angles.get(socket, 0.0)

	_overlay.queue_redraw()


func _build_gear_layer() -> void:
	_built_puzzle = puzzle
	_gear_layer = Node2D.new()
	add_child(_gear_layer)
	move_child(_gear_layer, 0)
	for part: int in range(puzzle.part_count()):
		var gear := Node2D.new()
		var metal := BRASS if part == Puzzle.MOTOR else STEEL
		gear.draw.connect(draw_gear.bind(gear, Vector2.ZERO, metal, 0.0, puzzle.part_radius(part)))
		_gear_layer.add_child(gear)
		_gears.append(gear)
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	_gear_layer.add_child(_overlay)


func _process(delta: float) -> void:
	if puzzle == null or spin_rates.is_empty():
		return
	for socket: int in spin_rates:
		var speed := 165.0 / maxf(puzzle.pitch_radius(socket), 8.0)
		var angle := fposmod(spin_angles.get(socket, 0.0) + delta * spin_rates[socket] * speed, TAU)
		spin_angles[socket] = angle
		var gear := puzzle.part_for_socket(socket)
		if gear >= 0 and gear < _gears.size():
			_gears[gear].rotation = angle


func _draw() -> void:
	draw_set_transform(screen_position(Vector2.ZERO), 0.0, Vector2.ONE * plate_scale())
	var face := Rect2(Vector2(4, 4), Puzzle.PLATE_SIZE - Vector2(8, 8))
	if sheet:
		if puzzle != null:
			_draw_sheet(face)
		return

	draw_rect(Rect2(face.position + Vector2(0, 5), face.size), Color("#121e20"))
	draw_rect(face, Color("#344a49"))
	draw_rect(face.grow(-7.0), Color("#293a3a"))
	draw_rect(face.grow(-8.0), Color("#627979"), false, 1.0)
	for y: float in [22.0, Puzzle.PLATE_SIZE.y - 22.0]:
		for x: float in [22.0, Puzzle.PLATE_SIZE.x - 22.0]:
			_bolt(Vector2(x, y))

	if puzzle == null:
		if locked:
			draw_rect(face, Color(0.04, 0.07, 0.08, 0.49))
		return

	# Draw sliding rail tracks first so carrier arms and collars layer cleanly on top.
	for slider_idx: int in range(puzzle.slider_count()):
		var slider: RailSlider = puzzle.sliders[slider_idx]
		if slider == null or slider.stops.size() < 2:
			continue
		var a := slider.stops[0]
		var b := slider.stops[slider.stops.size() - 1]
		var highlighted := slider_idx == preview_slider or slider_idx == dragging_slider
		draw_circle(a, 10.0, Color("#496260"), true, -1, true)
		draw_circle(b, 10.0, Color("#496260"), true, -1, true)
		draw_line(a, b, Color("#496260"), 20.0, true)
		draw_circle(a, 6.0, Color("#172527"), true, -1, true)
		draw_circle(b, 6.0, Color("#172527"), true, -1, true)
		draw_line(a, b, Color("#172527"), 12.0, true)
		draw_line(a, b, CLUE if highlighted else Color("#6a8280"), 2.5, true)
		for stop_pt: Vector2 in slider.stops:
			_socket(stop_pt, highlighted)

	for fixed_idx: int in range(puzzle.fixed_count()):
		var fixed_pos := puzzle.fixed_gear_positions[fixed_idx]
		draw_circle(fixed_pos, 10.0, Color("#203031"), true, -1, true)
		draw_arc(fixed_pos, 10.0, 0.0, TAU, 24, Color("#566f6e"), 1.0, true)

	for carrier: int in range(puzzle.carrier_count()):
		var pivot := puzzle.carrier_pivots[carrier]
		var radius := pivot.distance_to(puzzle.carrier_first_sockets[carrier])
		draw_arc(pivot, radius, 0, TAU, 48, Color("#364b4b"), 1.0, true)
		for rot_idx: int in range(Puzzle.SOCKETS_PER_CARRIER):
			_socket(puzzle.socket_position(puzzle.carrier_socket_id(carrier, rot_idx)))

	for carrier: int in range(puzzle.carrier_count()):
		var pivot := puzzle.carrier_pivots[carrier]
		var turn := turns[carrier] if carrier < turns.size() else float(puzzle.starting_rotations[carrier])
		var tip := puzzle.carrier_gear_position(carrier, turn)
		var highlighted := carrier == preview_carrier
		draw_line(pivot + Vector2(3, 4), tip + Vector2(3, 4), INK, 11.0, true)
		draw_line(pivot, tip, CLUE if highlighted else Color("#829592"), 8.0, true)
		draw_line(pivot, tip, Color("#526662"), 2.0, true)
		draw_circle(pivot, 15, Color("#111c1e"), true, -1, true)

	# Circular beveled motor collar (replaces the stray rectangular housing outline).
	var motor_r := puzzle.motor_radius
	draw_circle(puzzle.motor_socket + Vector2(2, 3), motor_r + 11.0, Color("#152224"), true, -1, true)
	draw_circle(puzzle.motor_socket, motor_r + 10.0, Color("#3a5050"), true, -1, true)
	draw_arc(puzzle.motor_socket, motor_r + 10.0, 0.0, TAU, 48, Color("#677f7c"), 1.5, true)
	draw_circle(puzzle.motor_socket, motor_r + 4.0, Color("#203031"), true, -1, true)

	_plate_label("MOTOR", puzzle.motor_socket - Vector2(0, motor_r + 17.0))
	_plate_label("OUTPUT", _output_label_position())


func _output_label_position() -> Vector2:
	var raw := puzzle.output_socket + puzzle.output_label_offset
	return Vector2(clampf(raw.x, 52.0, Puzzle.PLATE_SIZE.x - 52.0), clampf(raw.y, 28.0, Puzzle.PLATE_SIZE.y - 18.0))


func _draw_overlay() -> void:
	if puzzle == null:
		return
	for pair: Vector2i in contacts:
		if spin_rates.has(pair.x) and spin_rates.has(pair.y):
			var from := puzzle.socket_position(pair.x)
			var to := puzzle.socket_position(pair.y)
			var contact := from + from.direction_to(to) * puzzle.pitch_radius(pair.x)
			_overlay.draw_circle(contact, 8.0, Color("#ffcf70"), false, 2.0, true)
			_overlay.draw_circle(contact, 3.0, CLUE, true, -1, true)
	if preview_carrier >= 0 and preview_carrier < puzzle.carrier_count():
		_draw_carrier_preview(preview_carrier)
	if dragging_slider >= 0 and dragging_slider < puzzle.slider_count():
		_draw_slider_drag_preview(dragging_slider)
	elif preview_slider >= 0 and preview_slider < puzzle.slider_count():
		_draw_slider_preview(preview_slider)
	if output_result != 0:
		var result_color := Color("#a9e4be") if result_passed else Color("#ffae91")
		var output_arrow_r := _clamped_arc_radius(puzzle.output_socket, -PI / 2.0 - output_result * 0.65, output_result * 4.55, puzzle.output_radius + 13.0, 15.0)
		_arrow(_overlay, puzzle.output_socket, output_arrow_r, output_result, result_color, 5.0, 15.0)
	if locked:
		var face := Rect2(Vector2(4, 4), Puzzle.PLATE_SIZE - Vector2(8, 8))
		_overlay.draw_rect(face, Color(0.04, 0.07, 0.08, 0.49))


func _draw_carrier_preview(carrier: int) -> void:
	var pivot := puzzle.carrier_pivots[carrier]
	var turn := turns[carrier] if carrier < turns.size() else float(puzzle.starting_rotations[carrier])
	var current := puzzle.carrier_gear_position(carrier, turn)
	var next := puzzle.carrier_gear_position(carrier, turn + 1.0)
	var radius := puzzle.carrier_radii[carrier]
	var orbit_radius := pivot.distance_to(current)
	var start_angle := (current - pivot).angle() + 0.06
	var sweep := PI / 2.0 - 0.12
	var arrow_radius := _clamped_arc_radius(pivot, start_angle, sweep, orbit_radius + radius + 10.0, 14.0)
	draw_gear(_overlay, next, Color(1.0, 0.84, 0.54, 0.34), 0.0, radius)
	_overlay.draw_arc(next, radius + 4.5, 0, TAU, 40, Color(INK, 0.82), 5.0, true)
	_overlay.draw_arc(next, radius + 4.5, 0, TAU, 40, Color(1.0, 0.87, 0.58, 0.88), 2.5, true)
	_overlay.draw_arc(current, radius + 4.5, 0, TAU, 40, Color(INK, 0.82), 5.0, true)
	_overlay.draw_arc(current, radius + 4.5, 0, TAU, 40, CLUE, 2.5, true)
	_arc_arrow(_overlay, pivot, arrow_radius, start_angle, sweep, CLUE, 5.0, 14.0)


func _draw_slider_preview(slider_idx: int) -> void:
	var slider := puzzle.sliders[slider_idx]
	if slider == null or slider.stops.size() < 2:
		return
	var stop_val := slider_values[slider_idx] if slider_idx < slider_values.size() else float(slider.starting_stop)
	var cur_stop := slider.nearest_stop(stop_val)
	var next_stop := (cur_stop + 1) % slider.stops.size()
	var current := puzzle.slider_gear_position(slider_idx, stop_val)
	var next := slider.stops[next_stop]
	var radius := slider.pitch_radius
	draw_gear(_overlay, next, Color(1.0, 0.84, 0.54, 0.34), 0.0, radius)
	_overlay.draw_arc(next, radius + 4.5, 0, TAU, 40, Color(INK, 0.82), 5.0, true)
	_overlay.draw_arc(next, radius + 4.5, 0, TAU, 40, Color(1.0, 0.87, 0.58, 0.88), 2.5, true)
	_overlay.draw_arc(current, radius + 4.5, 0, TAU, 40, Color(INK, 0.82), 5.0, true)
	_overlay.draw_arc(current, radius + 4.5, 0, TAU, 40, CLUE, 2.5, true)
	var span := current.distance_to(next)
	if span > 18.0:
		var dir := current.direction_to(next)
		var inset := minf(8.0, span * 0.2)
		_line_arrow(_overlay, current + dir * inset, next - dir * inset, CLUE, 5.0, 14.0)


func _draw_slider_drag_preview(slider_idx: int) -> void:
	var slider := puzzle.sliders[slider_idx]
	if slider == null or slider.stops.size() < 2:
		return
	var stop_val := slider_values[slider_idx] if slider_idx < slider_values.size() else float(slider.starting_stop)
	var snap_stop := slider.nearest_stop(stop_val)
	var current := puzzle.slider_gear_position(slider_idx, stop_val)
	var snap_pos := slider.stops[snap_stop]
	var radius := slider.pitch_radius
	for stop_idx: int in range(slider.stops.size()):
		if stop_idx != snap_stop:
			_overlay.draw_arc(slider.stops[stop_idx], radius * 0.55, 0, TAU, 24, Color(CLUE, 0.45), 2.0, true)
	draw_gear(_overlay, snap_pos, Color(1.0, 0.84, 0.54, 0.3), 0.0, radius)
	_overlay.draw_arc(snap_pos, radius + 4.5, 0, TAU, 40, Color(INK, 0.82), 5.0, true)
	_overlay.draw_arc(snap_pos, radius + 4.5, 0, TAU, 40, CLUE, 2.5, true)
	_overlay.draw_arc(current, radius + 4.0, 0, TAU, 40, Color(1.0, 0.94, 0.78, 0.85), 2.0, true)


func _draw_sheet(face: Rect2) -> void:
	draw_rect(face, Color("#23495f"))
	draw_rect(face.grow(-9.0), Color("#739baa"), false, 2.0)
	for x: int in range(16, 455, 19):
		draw_line(Vector2(x, 15), Vector2(x, 351), Color("#345c71"))
	for y: int in range(15, 352, 19):
		draw_line(Vector2(16, y), Vector2(454, y), Color("#345c71"))

	for slider_idx: int in range(puzzle.slider_count()):
		var slider: RailSlider = puzzle.sliders[slider_idx]
		if slider == null or slider.stops.size() < 2:
			continue
		var a := slider.stops[0]
		var b := slider.stops[slider.stops.size() - 1]
		draw_line(a, b, Color("#7297ac"), 9.0, true)
		draw_line(a, b, Color("#23495f"), 4.0, true)
		for stop_idx: int in range(slider.stops.size()):
			var socket := puzzle.slider_socket_id(slider_idx, stop_idx)
			var pt := slider.stops[stop_idx]
			var is_clue := socket == puzzle.clue_socket
			draw_circle(pt, 9.5, CLUE if is_clue else Color("#d7e7ea"), false, 3.5 if is_clue else 2.0, true)
			if is_clue:
				draw_circle(pt, 3.5, CLUE, true, -1, true)

	for carrier: int in range(puzzle.carrier_count()):
		var pivot := puzzle.carrier_pivots[carrier]
		draw_arc(pivot, pivot.distance_to(puzzle.carrier_first_sockets[carrier]), 0, TAU, 40, Color("#7297ac"), 2.5, true)
		draw_circle(pivot, 4, Color("#e0eef1"), true, -1, true)
		for rot_idx: int in range(Puzzle.SOCKETS_PER_CARRIER):
			var socket := puzzle.carrier_socket_id(carrier, rot_idx)
			var point := puzzle.socket_position(socket)
			var is_clue := socket == puzzle.clue_socket
			draw_circle(point, 11.0, CLUE if is_clue else Color("#d7e7ea"), false, 4.0 if is_clue else 2.0, true)
			if is_clue:
				draw_circle(point, 4.0, CLUE, true, -1, true)

	for fixed_idx: int in range(puzzle.fixed_count()):
		var fixed_pos := puzzle.fixed_gear_positions[fixed_idx]
		var socket := puzzle.fixed_socket_id(fixed_idx)
		var is_clue := socket == puzzle.clue_socket
		draw_circle(fixed_pos, 12.0, CLUE if is_clue else Color("#e4f1f1"), false, 3.0 if is_clue else 2.0, true)
		draw_circle(fixed_pos, 4.0, CLUE if is_clue else Color("#e4f1f1"), false, 1.5, true)

	for endpoint: Vector2 in [puzzle.motor_socket, puzzle.output_socket]:
		draw_circle(endpoint, 18.0, Color("#e4f1f1"), false, 3.0, true)
		draw_circle(endpoint, 6.0, Color("#e4f1f1"), false, 2.0, true)

	_diagram_label("M", puzzle.motor_socket - Vector2(0, puzzle.motor_radius + 10.0))
	var sheet_arrow_r := _clamped_arc_radius(puzzle.output_socket, -PI / 2.0 - puzzle.required_output_direction * 0.65, puzzle.required_output_direction * 4.55, puzzle.output_radius + 13.0, 15.0)
	var out_label_y := minf(puzzle.output_socket.y + sheet_arrow_r + 24.0, Puzzle.PLATE_SIZE.y - 16.0)
	_diagram_label("OUT", Vector2(puzzle.output_socket.x, out_label_y))
	_arrow(self, puzzle.output_socket, sheet_arrow_r, puzzle.required_output_direction, CLUE, 5.0, 15.0)


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


func _arrow(canvas: CanvasItem, center: Vector2, radius: float, direction: int, color: Color, width := 5.5, head_size := 15.0) -> void:
	_arc_arrow(canvas, center, radius, -PI / 2.0 - direction * 0.65, direction * 4.55, color, width, head_size)


func _clamped_arc_radius(center: Vector2, start: float, sweep: float, desired_radius: float, head_size: float) -> float:
	var pad := head_size * 0.55 + 10.0
	var max_r := desired_radius
	for i: int in range(13):
		var t := float(i) / 12.0
		var u := Vector2.from_angle(start + sweep * t)
		if u.x > 0.001:
			max_r = minf(max_r, (Puzzle.PLATE_SIZE.x - pad - center.x) / u.x)
		elif u.x < -0.001:
			max_r = minf(max_r, (center.x - pad) / -u.x)
		if u.y > 0.001:
			max_r = minf(max_r, (Puzzle.PLATE_SIZE.y - pad - center.y) / u.y)
		elif u.y < -0.001:
			max_r = minf(max_r, (center.y - pad) / -u.y)
	return clampf(desired_radius, 18.0, maxf(18.0, max_r))


func _arc_arrow(canvas: CanvasItem, center: Vector2, radius: float, start: float, sweep: float, color: Color, width := 5.0, head_size := 14.0) -> void:
	if is_zero_approx(sweep):
		return
	var dir := signf(sweep)
	var end := start + sweep
	var trim := minf(absf(sweep) * 0.35, (head_size * 0.55) / maxf(radius, 1.0))
	var arc_end := end - dir * trim
	var arc_from := minf(start, arc_end)
	var arc_to := maxf(start, arc_end)
	var outline := Color(INK, 0.92)
	var radial := Vector2.from_angle(end)
	var tip := center + radial * radius
	var tangent := Vector2(-radial.y, radial.x) * dir
	var wing := head_size * 0.52
	var base := tip - tangent * head_size
	var outline_tip := tip + tangent * 3.0
	var outline_base := base - tangent * 2.0
	var outline_wing := wing + 2.8
	canvas.draw_arc(center, radius, arc_from, arc_to, 36, outline, width + 4.5, true)
	canvas.draw_colored_polygon(PackedVector2Array([outline_tip, outline_base - radial * outline_wing, outline_base + radial * outline_wing]), outline)
	canvas.draw_arc(center, radius, arc_from, arc_to, 36, color, width, true)
	canvas.draw_colored_polygon(PackedVector2Array([tip, base - radial * wing, base + radial * wing]), color)


func _line_arrow(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, width := 5.0, head_size := 14.0) -> void:
	var span := from.distance_to(to)
	if span < 8.0:
		return
	var dir := from.direction_to(to)
	var perp := Vector2(-dir.y, dir.x)
	var actual_head := minf(head_size, span * 0.45)
	var wing := actual_head * 0.52
	var base := to - dir * actual_head
	var outline := Color(INK, 0.92)
	var outline_tip := to + dir * 2.5
	var outline_base := base - dir * 1.5
	var outline_wing := wing + 2.6
	canvas.draw_line(from, base, outline, width + 4.5, true)
	canvas.draw_colored_polygon(PackedVector2Array([outline_tip, outline_base - perp * outline_wing, outline_base + perp * outline_wing]), outline)
	canvas.draw_line(from, base, color, width, true)
	canvas.draw_colored_polygon(PackedVector2Array([to, base - perp * wing, base + perp * wing]), color)


func _plate_label(value: String, at: Vector2) -> void:
	var font := PLATE_FONT
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0
	draw_rect(Rect2(at - Vector2(width * 0.5, 15), Vector2(width, 20)), INK)
	draw_string(font, at - Vector2(width * 0.5 - 7, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, STEEL)


func _diagram_label(value: String, at: Vector2) -> void:
	var font := PLATE_FONT
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(font, at - Vector2(width * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#e4f1f1"))
