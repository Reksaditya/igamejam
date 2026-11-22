extends Resource

enum Direction { COUNTERCLOCKWISE = -1, CLOCKWISE = 1 }

const MOTOR := 0
const OUTPUT := 1
const IDLER := 2
const FIRST_CARRIER := 3
const CARRIER_COUNT := 3
const SOCKETS_PER_CARRIER := 4
const PLATE_SIZE := Vector2(470, 366)

@export var puzzle_id := "transmission_bench"
@export var linked_blueprint_id := "sediment_sorter"
@export var required_output_direction: Direction = Direction.CLOCKWISE

@export_group("Plate")
@export var motor_socket: Vector2
@export var output_socket: Vector2
@export var idler_socket: Vector2
## Motor, output, idler, then carriers A, B and C.
@export var gear_pitch_radii := PackedFloat32Array([33, 33, 28, 25, 25, 20])
## One pivot and first socket per carrier. The other three sockets are successive clockwise quarter turns.
@export var carrier_pivots: PackedVector2Array
@export var carrier_first_sockets: PackedVector2Array
@export var starting_rotations: PackedInt32Array
## Undirected pairs. Motor = 0, output = 1, idler = 2, then A = 3–6, B = 7–10, C = 11–14.
@export var contact_pairs: Array[Vector2i]
@export_range(3, 14) var clue_socket := 7


func socket_id(carrier: int, rotation: int) -> int:
	return FIRST_CARRIER + carrier * SOCKETS_PER_CARRIER + posmod(rotation, SOCKETS_PER_CARRIER)


func carrier_gear_position(carrier: int, quarter_turn: float) -> Vector2:
	var pivot := carrier_pivots[carrier]
	return pivot + (carrier_first_sockets[carrier] - pivot).rotated(quarter_turn * PI / 2.0)


func socket_position(socket: int) -> Vector2:
	match socket:
		MOTOR:
			return motor_socket
		OUTPUT:
			return output_socket
		IDLER:
			return idler_socket
	@warning_ignore("integer_division")
	var carrier := (socket - FIRST_CARRIER) / SOCKETS_PER_CARRIER
	return carrier_gear_position(carrier, (socket - FIRST_CARRIER) % SOCKETS_PER_CARRIER)


func pitch_radius(socket: int) -> float:
	if socket < FIRST_CARRIER:
		return gear_pitch_radii[socket]
	@warning_ignore("integer_division")
	var carrier := (socket - FIRST_CARRIER) / SOCKETS_PER_CARRIER
	return gear_pitch_radii[FIRST_CARRIER + carrier]


func is_valid() -> bool:
	if not puzzle_id.is_valid_identifier() or not linked_blueprint_id.is_valid_identifier():
		return false
	if required_output_direction != Direction.CLOCKWISE and required_output_direction != Direction.COUNTERCLOCKWISE:
		return false
	if carrier_pivots.size() != CARRIER_COUNT or carrier_first_sockets.size() != CARRIER_COUNT or starting_rotations.size() != CARRIER_COUNT:
		return false
	if gear_pitch_radii.size() != FIRST_CARRIER + CARRIER_COUNT:
		return false
	for radius: float in gear_pitch_radii:
		if not is_finite(radius) or radius < 8.0:
			return false
	var max_socket := socket_id(CARRIER_COUNT - 1, SOCKETS_PER_CARRIER - 1)
	if clue_socket < FIRST_CARRIER or clue_socket > max_socket:
		return false
	var bounds := Rect2(Vector2.ZERO, PLATE_SIZE).grow(-25.0)
	for position: Vector2 in carrier_pivots:
		if not bounds.has_point(position):
			return false
	for socket: int in range(max_socket + 1):
		if not bounds.has_point(socket_position(socket)):
			return false
	for carrier: int in range(CARRIER_COUNT):
		if carrier_pivots[carrier].is_equal_approx(carrier_first_sockets[carrier]) or starting_rotations[carrier] not in range(SOCKETS_PER_CARRIER):
			return false
	for pair: Vector2i in contact_pairs:
		if pair.x == pair.y or mini(pair.x, pair.y) < 0 or maxi(pair.x, pair.y) > max_socket:
			return false
	return true


func trace(rotations: PackedInt32Array, idler_fitted: bool) -> Dictionary:
	var occupied := PackedInt32Array([MOTOR, OUTPUT])
	if idler_fitted:
		occupied.append(IDLER)
	for carrier: int in range(CARRIER_COUNT):
		occupied.append(socket_id(carrier, rotations[carrier]))
	var directions: Dictionary[int, int] = {MOTOR: Direction.CLOCKWISE}
	var depths: Dictionary[int, int] = {MOTOR: 0}
	var order := PackedInt32Array([MOTOR])
	var contacts: Array[Vector2i] = []
	for pair: Vector2i in contact_pairs:
		if pair.x in occupied and pair.y in occupied:
			contacts.append(pair)
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
