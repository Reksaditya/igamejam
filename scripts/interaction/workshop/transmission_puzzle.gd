extends Resource

const RailSlider = preload("res://scripts/interaction/workshop/transmission_slider.gd")

enum Direction { COUNTERCLOCKWISE = -1, CLOCKWISE = 1 }

const MOTOR := 0
const OUTPUT := 1
const FIRST_FIXED := 2
const SOCKETS_PER_CARRIER := 4
const PLATE_SIZE := Vector2(470, 366)
const OVERLAP_MARGIN := 3.5

@export var puzzle_id := "transmission_bench"
@export var linked_blueprint_id := "sediment_sorter"
@export var title := "Pemilah Sedimen"
@export var difficulty := "Sedang"
@export var required_output_direction: Direction = Direction.CLOCKWISE

@export_group("Plate")
@export var motor_socket: Vector2
@export var motor_radius := 33.0
@export var output_socket: Vector2
@export var output_radius := 33.0
@export var output_label_offset := Vector2(82, 42)
@export var fixed_gear_positions: PackedVector2Array
@export var fixed_gear_radii: PackedFloat32Array
## One pivot and first socket per carrier. The other three sockets are successive clockwise quarter turns.
@export var carrier_pivots: PackedVector2Array
@export var carrier_first_sockets: PackedVector2Array
@export var carrier_radii: PackedFloat32Array
@export var starting_rotations: PackedInt32Array
@export var sliders: Array[RailSlider]
## Undirected pairs using socket_id indices. Leave empty to auto-detect tangent gears.
@export var contact_pairs: Array[Vector2i]
@export var clue_socket := -1


func fixed_count() -> int:
	return fixed_gear_positions.size()


func carrier_count() -> int:
	return carrier_pivots.size()


func slider_count() -> int:
	return sliders.size()


func first_carrier_socket() -> int:
	return FIRST_FIXED + fixed_count()


func first_slider_socket() -> int:
	return first_carrier_socket() + carrier_count() * SOCKETS_PER_CARRIER


func fixed_socket_id(index: int) -> int:
	return FIRST_FIXED + index


func carrier_socket_id(carrier: int, rotation: int) -> int:
	return first_carrier_socket() + carrier * SOCKETS_PER_CARRIER + posmod(rotation, SOCKETS_PER_CARRIER)


func slider_socket_id(slider: int, stop: int) -> int:
	var offset := first_slider_socket()
	for index: int in range(slider):
		if sliders[index] != null:
			offset += sliders[index].stops.size()
	var stop_count := sliders[slider].stops.size() if slider >= 0 and slider < sliders.size() and sliders[slider] != null else 1
	return offset + clampi(stop, 0, maxi(0, stop_count - 1))


func socket_count() -> int:
	var total := first_slider_socket()
	for slider: RailSlider in sliders:
		if slider != null:
			total += slider.stops.size()
	return total


func part_count() -> int:
	return FIRST_FIXED + fixed_count() + carrier_count() + slider_count()


func part_for_socket(socket: int) -> int:
	if socket == MOTOR or socket == OUTPUT:
		return socket
	var fixed_end := first_carrier_socket()
	if socket >= FIRST_FIXED and socket < fixed_end:
		return socket
	var carrier_end := first_slider_socket()
	if socket >= fixed_end and socket < carrier_end:
		@warning_ignore("integer_division")
		return FIRST_FIXED + fixed_count() + (socket - fixed_end) / SOCKETS_PER_CARRIER
	var cursor := carrier_end
	for index: int in range(slider_count()):
		var slider := sliders[index]
		var stop_count := slider.stops.size() if slider != null else 0
		if socket >= cursor and socket < cursor + stop_count:
			return FIRST_FIXED + fixed_count() + carrier_count() + index
		cursor += stop_count
	return -1


func part_radius(part: int) -> float:
	if part == MOTOR:
		return motor_radius
	if part == OUTPUT:
		return output_radius
	var fixed_end := FIRST_FIXED + fixed_count()
	if part >= FIRST_FIXED and part < fixed_end:
		return fixed_gear_radii[part - FIRST_FIXED]
	var carrier_end := fixed_end + carrier_count()
	if part >= fixed_end and part < carrier_end:
		return carrier_radii[part - fixed_end]
	var slider_idx := part - carrier_end
	if slider_idx >= 0 and slider_idx < slider_count() and sliders[slider_idx] != null:
		return sliders[slider_idx].pitch_radius
	return 20.0


func default_slider_stops() -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(slider_count())
	for index: int in range(slider_count()):
		result[index] = sliders[index].starting_stop if sliders[index] != null else 0
	return result


func carrier_gear_position(carrier: int, quarter_turn: float) -> Vector2:
	var pivot := carrier_pivots[carrier]
	return pivot + (carrier_first_sockets[carrier] - pivot).rotated(quarter_turn * PI / 2.0)


func slider_gear_position(slider: int, stop_value: float) -> Vector2:
	if slider < 0 or slider >= sliders.size() or sliders[slider] == null:
		return Vector2.ZERO
	return sliders[slider].position_at(stop_value)


func socket_position(socket: int) -> Vector2:
	if socket == MOTOR:
		return motor_socket
	if socket == OUTPUT:
		return output_socket
	var fixed_end := first_carrier_socket()
	if socket >= FIRST_FIXED and socket < fixed_end:
		return fixed_gear_positions[socket - FIRST_FIXED]
	var carrier_end := first_slider_socket()
	if socket >= fixed_end and socket < carrier_end:
		@warning_ignore("integer_division")
		var carrier := (socket - fixed_end) / SOCKETS_PER_CARRIER
		return carrier_gear_position(carrier, float((socket - fixed_end) % SOCKETS_PER_CARRIER))
	var cursor := carrier_end
	for slider: RailSlider in sliders:
		if slider == null:
			continue
		var stop_count := slider.stops.size()
		if socket >= cursor and socket < cursor + stop_count:
			return slider.stops[socket - cursor]
		cursor += stop_count
	return Vector2.ZERO


func pitch_radius(socket: int) -> float:
	var part := part_for_socket(socket)
	return part_radius(part) if part >= 0 else 20.0


func would_overlap(rotations: PackedInt32Array, slider_stops: PackedInt32Array, moving_part: int, candidate_pos: Vector2, candidate_radius: float) -> bool:
	var active_rots := rotations if rotations.size() == carrier_count() else starting_rotations
	var active_stops := slider_stops if slider_stops.size() == slider_count() else default_slider_stops()
	for part: int in range(part_count()):
		if part == moving_part:
			continue
		var other_pos := _active_part_position(part, active_rots, active_stops)
		var other_radius := part_radius(part)
		if candidate_pos.distance_to(other_pos) < candidate_radius + other_radius - OVERLAP_MARGIN:
			return true
	return false


func can_rotate_carrier(rotations: PackedInt32Array, slider_stops: PackedInt32Array, carrier: int, target_rotation: int) -> bool:
	if carrier < 0 or carrier >= carrier_count():
		return false
	var part := FIRST_FIXED + fixed_count() + carrier
	var candidate_pos := carrier_gear_position(carrier, float(posmod(target_rotation, SOCKETS_PER_CARRIER)))
	return not would_overlap(rotations, slider_stops, part, candidate_pos, carrier_radii[carrier])


func can_move_slider(rotations: PackedInt32Array, slider_stops: PackedInt32Array, slider: int, target_stop: int) -> bool:
	if slider < 0 or slider >= slider_count() or sliders[slider] == null:
		return false
	if target_stop < 0 or target_stop >= sliders[slider].stops.size():
		return false
	var part := FIRST_FIXED + fixed_count() + carrier_count() + slider
	var candidate_pos := sliders[slider].stops[target_stop]
	return not would_overlap(rotations, slider_stops, part, candidate_pos, sliders[slider].pitch_radius)


func _active_part_position(part: int, rotations: PackedInt32Array, slider_stops: PackedInt32Array) -> Vector2:
	if part == MOTOR:
		return motor_socket
	if part == OUTPUT:
		return output_socket
	var fixed_end := FIRST_FIXED + fixed_count()
	if part >= FIRST_FIXED and part < fixed_end:
		return fixed_gear_positions[part - FIRST_FIXED]
	var carrier_end := fixed_end + carrier_count()
	if part >= fixed_end and part < carrier_end:
		var carrier := part - fixed_end
		return carrier_gear_position(carrier, float(rotations[carrier]))
	var slider_idx := part - carrier_end
	return slider_gear_position(slider_idx, float(slider_stops[slider_idx]))


func is_valid() -> bool:
	if not puzzle_id.is_valid_identifier() or not linked_blueprint_id.is_valid_identifier():
		return false
	if required_output_direction != Direction.CLOCKWISE and required_output_direction != Direction.COUNTERCLOCKWISE:
		return false
	if fixed_gear_positions.size() != fixed_gear_radii.size():
		return false
	if carrier_pivots.size() != carrier_first_sockets.size() or carrier_pivots.size() != carrier_radii.size() or carrier_pivots.size() != starting_rotations.size():
		return false
	if not is_finite(motor_radius) or motor_radius < 8.0 or not is_finite(output_radius) or output_radius < 8.0:
		return false
	for radius: float in fixed_gear_radii:
		if not is_finite(radius) or radius < 8.0:
			return false
	for radius: float in carrier_radii:
		if not is_finite(radius) or radius < 8.0:
			return false
	var bounds := Rect2(Vector2.ZERO, PLATE_SIZE).grow(-25.0)
	if not bounds.has_point(motor_socket) or not bounds.has_point(output_socket):
		return false
	for pos: Vector2 in fixed_gear_positions:
		if not bounds.has_point(pos):
			return false
	for pivot: Vector2 in carrier_pivots:
		if not bounds.has_point(pivot):
			return false
	for carrier: int in range(carrier_count()):
		if carrier_pivots[carrier].is_equal_approx(carrier_first_sockets[carrier]) or starting_rotations[carrier] not in range(SOCKETS_PER_CARRIER):
			return false
	for slider: RailSlider in sliders:
		if slider == null or not slider.is_valid(bounds):
			return false
	var total_sockets := socket_count()
	if clue_socket != -1 and (clue_socket < 0 or clue_socket >= total_sockets):
		return false
	for socket: int in range(total_sockets):
		if not bounds.has_point(socket_position(socket)):
			return false
	for pair: Vector2i in contact_pairs:
		if pair.x == pair.y or mini(pair.x, pair.y) < 0 or maxi(pair.x, pair.y) >= total_sockets:
			return false
		if part_for_socket(pair.x) == part_for_socket(pair.y):
			return false
	return true


func trace(rotations: PackedInt32Array, slider_stops: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var active_rots := rotations if rotations.size() == carrier_count() else starting_rotations
	var active_stops := slider_stops if slider_stops.size() == slider_count() else default_slider_stops()
	var occupied := PackedInt32Array([MOTOR, OUTPUT])
	for index: int in range(fixed_count()):
		occupied.append(fixed_socket_id(index))
	for carrier: int in range(carrier_count()):
		occupied.append(carrier_socket_id(carrier, active_rots[carrier]))
	for slider: int in range(slider_count()):
		occupied.append(slider_socket_id(slider, active_stops[slider]))

	var source_pairs: Array[Vector2i] = contact_pairs
	if source_pairs.is_empty():
		source_pairs = _detect_contacts_for_occupied(occupied)

	var contacts: Array[Vector2i] = []
	for pair: Vector2i in source_pairs:
		if pair.x in occupied and pair.y in occupied:
			contacts.append(pair)

	var directions: Dictionary[int, int] = {MOTOR: Direction.CLOCKWISE}
	var depths: Dictionary[int, int] = {MOTOR: 0}
	var order := PackedInt32Array([MOTOR])
	var locked := false
	var index := 0
	while index < order.size():
		var socket := order[index]
		index += 1
		for pair: Vector2i in contacts:
			var neighbor := pair.y if pair.x == socket else pair.x if pair.y == socket else -1
			if neighbor < 0:
				continue
			var direction := -directions[socket]
			if not directions.has(neighbor):
				directions[neighbor] = direction
				depths[neighbor] = depths[socket] + 1
				order.append(neighbor)
			elif directions[neighbor] != direction:
				locked = true
	return {"directions": directions, "depths": depths, "contacts": contacts, "locked": locked}


func _detect_contacts_for_occupied(occupied: PackedInt32Array) -> Array[Vector2i]:
	var detected: Array[Vector2i] = []
	for i: int in range(occupied.size()):
		var a := occupied[i]
		var pos_a := socket_position(a)
		var rad_a := pitch_radius(a)
		for j: int in range(i + 1, occupied.size()):
			var b := occupied[j]
			if part_for_socket(a) == part_for_socket(b):
				continue
			var dist := pos_a.distance_to(socket_position(b))
			if absf(dist - (rad_a + pitch_radius(b))) <= 1.2:
				detected.append(Vector2i(a, b))
	return detected
