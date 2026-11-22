extends SceneTree

const Puzzle = preload("res://scripts/interaction/workshop/transmission_puzzle.gd")
const BlueprintState = preload("res://scripts/interaction/desktop/project/blueprint_progress.gd").State

const PUZZLE_PATHS := [
	"res://scenes/interaction/workshop/puzzle_01_easy.tres",
	"res://scenes/interaction/workshop/transmission_bench.tres",
	"res://scenes/interaction/workshop/puzzle_03_hard.tres",
	"res://scenes/interaction/workshop/puzzle_04_expert.tres",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var puzzles: Array[Puzzle] = []
	for path: String in PUZZLE_PATHS:
		var loaded := load(path) as Puzzle
		assert(loaded != null, "Failed to load puzzle: " + path)
		assert(loaded.is_valid(), "Puzzle failed is_valid(): " + path)
		_verify_geometry(loaded, path)
		var stats := _brute_force_solve(loaded)
		print("PUZZLE %s (%s): states=%d solutions=%d wrong_dir=%d jams=%d broken=%d" % [
			loaded.puzzle_id,
			loaded.difficulty,
			stats.states,
			stats.solutions,
			stats.wrong_dir,
			stats.jams,
			stats.broken,
		])
		assert(not stats.start_solved, "Starting configuration must not already be solved: " + loaded.puzzle_id)
		assert(stats.solutions >= 1, "Puzzle must have at least one solution: " + loaded.puzzle_id)
		if loaded.puzzle_id == "centrifuge_drive":
			assert(stats.jams >= 1, "Expert puzzle must exhibit at least one jam state")
		puzzles.append(loaded)

	var blueprints := root.get_node("ProjectBlueprints")
	assert(blueprints.grant("core_drive") == OK)
	assert(blueprints.grant("sieve_shaker") == OK)

	var workshop_scene := load("res://scenes/interaction/workshop/transmission_workshop.tscn") as PackedScene
	var workshop := workshop_scene.instantiate()
	workshop.demo_blueprint = false
	root.add_child(workshop)
	await process_frame

	assert(not workshop._unlocked, "Workshop must start locked awaiting blueprint drop")
	assert(workshop._active_puzzle == null)
	assert(workshop._blueprint_cards.size() == 2, "Only owned blueprints should populate the dock")

	# Drag-and-drop Easy puzzle ("starter_drive") into reader slot.
	var drag_easy := {"source": workshop.get_instance_id(), "type": "workshop_blueprint", "puzzle_id": "starter_drive"}
	assert(workshop._reader_slot._can_drop_data(Vector2.ZERO, drag_easy))
	workshop._reader_slot._drop_data(Vector2.ZERO, drag_easy)
	await _wait_until(func() -> bool: return not workshop._inserting)

	assert(workshop._unlocked, "Bench must unlock after valid blueprint drop")
	assert(workshop._active_puzzle != null and workshop._active_puzzle.puzzle_id == "starter_drive")
	assert(workshop._carrier_buttons.size() == 2)
	assert(workshop._slider_handles.is_empty())
	assert(workshop._plate._gears.size() == 4)
	assert(blueprints.get_state("core_drive", "starter_drive") == BlueprintState.WORKED)

	# Solve Easy puzzle -> solution rotations = (0, 0) from starting (2, 2).
	for carrier: int in range(2):
		for _step: int in range(2):
			workshop._rotate_carrier(carrier)
			await _wait_until(func() -> bool: return not workshop._adjusting)

	workshop._test_crank()
	await _wait_until(func() -> bool: return not workshop._testing and not workshop._relocking)

	assert(not workshop._unlocked, "Bench must re-lock automatically after completion")
	assert(workshop._active_puzzle == null)
	assert(blueprints.get_state("core_drive", "starter_drive") == BlueprintState.COMPLETED)

	# Drag-and-drop Hard sliding puzzle ("slider_relay") into reader slot.
	var drag_hard := {"source": workshop.get_instance_id(), "type": "workshop_blueprint", "puzzle_id": "slider_relay"}
	assert(workshop._reader_slot._can_drop_data(Vector2.ZERO, drag_hard))
	workshop._reader_slot._drop_data(Vector2.ZERO, drag_hard)
	await _wait_until(func() -> bool: return not workshop._inserting)

	assert(workshop._unlocked)
	assert(workshop._active_puzzle != null and workshop._active_puzzle.puzzle_id == "slider_relay")
	assert(workshop._carrier_buttons.size() == 2)
	assert(workshop._slider_handles.size() == 1)

	# Slide gear 0 from stop 1 -> stop 0 via drag callbacks.
	workshop._on_slider_drag_started(0)
	workshop._on_slider_drag_moved(0, 0.1)
	workshop._on_slider_drag_ended(0, 0)
	await _wait_until(func() -> bool: return not workshop._adjusting and workshop._dragging_slider < 0)
	assert(workshop._slider_stops[0] == 0)

	# Rotate carriers from (2, 1) -> (0, 0).
	for _step: int in range(2):
		workshop._rotate_carrier(0)
		await _wait_until(func() -> bool: return not workshop._adjusting)
	for _step: int in range(3):
		workshop._rotate_carrier(1)
		await _wait_until(func() -> bool: return not workshop._adjusting)

	workshop._test_crank()
	await _wait_until(func() -> bool: return not workshop._testing and not workshop._relocking)

	assert(not workshop._unlocked, "Bench must re-lock after solving sliding puzzle")
	assert(blueprints.get_state("sieve_shaker", "slider_relay") == BlueprintState.COMPLETED)

	# Verify Desktop Project app displays all 4 blueprints with accurate states.
	var project_scene := load("res://scenes/interaction/desktop/project/project_app.tscn") as PackedScene
	var project_app := project_scene.instantiate()
	root.add_child(project_app)
	await process_frame
	assert(project_app._entries.size() == 4)
	assert(project_app._drawings["core_drive"].visible)
	assert(project_app._drawings["sieve_shaker"].visible)
	assert(not project_app._drawings["sediment_sorter"].visible)
	assert(not project_app._drawings["core_centrifuge"].visible)
	assert(project_app._entries["core_drive"].badge_label.text == "Completed")
	assert(project_app._entries["sieve_shaker"].badge_label.text == "Completed")
	assert(project_app._entries["sediment_sorter"].badge_label.text == "Locked")

	project_app.queue_free()
	workshop.queue_free()
	await process_frame
	print("PASS: all 4 workshop puzzles verified, drag-to-slot, sliding rail, crank, re-lock, and 3-state Project app")
	quit()


func _verify_geometry(puzzle: Puzzle, path: String) -> void:
	var pair_set: Dictionary[Vector2i, bool] = {}
	for pair: Vector2i in puzzle.contact_pairs:
		var a := mini(pair.x, pair.y)
		var b := maxi(pair.x, pair.y)
		pair_set[Vector2i(a, b)] = true
		var dist := puzzle.socket_position(a).distance_to(puzzle.socket_position(b))
		var target := puzzle.pitch_radius(a) + puzzle.pitch_radius(b)
		assert(absf(dist - target) <= 1.2, "Contact pair %s mismatch in %s: %.2f vs %.2f" % [pair, path, dist, target])

	var total := puzzle.socket_count()
	for a: int in range(total):
		for b: int in range(a + 1, total):
			if puzzle.part_for_socket(a) == puzzle.part_for_socket(b):
				continue
			if pair_set.has(Vector2i(a, b)):
				continue
			var dist := puzzle.socket_position(a).distance_to(puzzle.socket_position(b))
			var target := puzzle.pitch_radius(a) + puzzle.pitch_radius(b)
			assert(dist >= target - 1.2, "Overlapping non-contact sockets (%d, %d) in %s: %.2f < %.2f" % [a, b, path, dist, target])


func _brute_force_solve(puzzle: Puzzle) -> Dictionary:
	var start_res := puzzle.trace(puzzle.starting_rotations, puzzle.default_slider_stops())
	var start_solved: bool = not start_res.locked and start_res.directions.get(Puzzle.OUTPUT, 0) == puzzle.required_output_direction

	var stats := {"states": 0, "solutions": 0, "wrong_dir": 0, "jams": 0, "broken": 0, "start_solved": start_solved}
	var rots := PackedInt32Array()
	rots.resize(puzzle.carrier_count())
	var stops := PackedInt32Array()
	stops.resize(puzzle.slider_count())
	_enumerate_carriers(puzzle, 0, rots, stops, stats)
	return stats


func _enumerate_carriers(puzzle: Puzzle, c_idx: int, rots: PackedInt32Array, stops: PackedInt32Array, stats: Dictionary) -> void:
	if c_idx >= puzzle.carrier_count():
		_enumerate_sliders(puzzle, 0, rots, stops, stats)
		return
	for rot_val: int in range(Puzzle.SOCKETS_PER_CARRIER):
		rots[c_idx] = rot_val
		_enumerate_carriers(puzzle, c_idx + 1, rots, stops, stats)


func _enumerate_sliders(puzzle: Puzzle, s_idx: int, rots: PackedInt32Array, stops: PackedInt32Array, stats: Dictionary) -> void:
	if s_idx >= puzzle.slider_count():
		stats.states += 1
		var res := puzzle.trace(rots, stops)
		if res.locked:
			stats.jams += 1
		else:
			var dir: int = res.directions.get(Puzzle.OUTPUT, 0)
			if dir == puzzle.required_output_direction:
				stats.solutions += 1
			elif dir == -puzzle.required_output_direction:
				stats.wrong_dir += 1
			else:
				stats.broken += 1
		return
	var stop_count := puzzle.sliders[s_idx].stops.size()
	for stop_val: int in range(stop_count):
		stops[s_idx] = stop_val
		_enumerate_sliders(puzzle, s_idx + 1, rots, stops, stats)


func _wait_until(condition: Callable) -> void:
	for _frame: int in range(600):
		if bool(condition.call()):
			return
		await process_frame
	assert(false, "Timed out waiting for async workshop state")
