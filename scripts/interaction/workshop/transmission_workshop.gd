extends Control

const Puzzle = preload("res://scripts/interaction/workshop/transmission_puzzle.gd")
const Plate = preload("res://scripts/interaction/workshop/transmission_plate.gd")
const Save = preload("res://scripts/autoload/playthrough_save.gd")
const SAVE_PATH := "user://workshop_progress.cfg"

@export var puzzle: Puzzle
@export_file("*.tscn") var return_scene := "res://scenes/movement/campus_lab_room.tscn"
@export var return_spawn: StringName = &"WorkshopSpawn"
@export var return_label := "Back to lab"
@export var demo_blueprint := false

var _rotations := PackedInt32Array()
var _carrier_buttons: Array[Button] = []
var _gear_buttons: Array[Button] = []
var _fixed_gears: Array[Control] = []
var _idler_button: Button
var _has_blueprint := false
var _inserting := false
var _unlocked := false
var _completed := false
var _fitted := false
var _holding_idler := false
var _adjusting := false
var _testing := false
var _leaving := false
var _keyboard_cues := false
var _test_feedback := ""

@onready var _plate: Plate = %Plate
@onready var _sheet: Plate = %Sheet
@onready var _status: Label = %Status
@onready var _tray: Button = %Tray
@onready var _tray_pocket: Control = %TrayPocket
@onready var _crank: Button = %Crank
@onready var _return: Button = %Return
@onready var _insert: Button = %Insert


func _ready() -> void:
	GameClock.resume_timeline()
	GameClock.minute_changed.connect(_update_clock)
	_update_clock(GameClock.get_absolute_minutes())
	_return.text = return_label
	_return.pressed.connect(_leave)
	_return.disabled = return_scene.is_empty()
	SceneTransition.transition_finished.connect(_on_transition_finished)
	_tray.pressed.connect(_pick_up_idler)
	_tray_pocket.draw.connect(_draw_tray)
	_crank.pressed.connect(_test_crank)
	_insert.pressed.connect(_insert_blueprint)
	%CardStack.resized.connect(_size_blueprint)
	get_window().size_changed.connect(_update_layout)
	resized.connect(_update_layout)
	_update_layout()
	if puzzle == null or not puzzle.is_valid():
		_status.text = "The bench puzzle is not configured."
		%Blueprint.hide()
		%Legend.hide()
		%TrayRow.hide()
		_insert.disabled = true
		_update_controls()
		_return.grab_focus()
		return
	_has_blueprint = demo_blueprint or ProjectBlueprints.is_owned(puzzle.linked_blueprint_id)
	_rotations = puzzle.starting_rotations.duplicate()
	_plate.puzzle = puzzle
	_plate.locked = true
	for rotation: int in _rotations:
		_plate.turns.append(float(rotation))
	_sheet.sheet = true
	_sheet.puzzle = puzzle if _has_blueprint else null
	%Blueprint.visible = _has_blueprint
	%Card.visible = _has_blueprint
	%Gate.text = "Insert blueprint" if _has_blueprint else "Blueprint needed"
	%Gate.show()
	_insert.text = "Insert blueprint" if _has_blueprint else "Awaiting blueprint"
	_insert.disabled = not _has_blueprint
	_plate.resized.connect(_layout_plate_buttons)
	get_viewport().gui_focus_changed.connect(func(_control: Control) -> void: _sync_cue.call_deferred())
	for carrier: int in range(Puzzle.CARRIER_COUNT):
		var letter := ["A", "B", "C"][carrier] as String
		var button := _make_plate_button(letter, "Rotate carrier " + letter + " clockwise")
		button.pressed.connect(_rotate_carrier.bind(carrier))
		_carrier_buttons.append(button)
		var gear := _make_plate_button("", button.accessibility_name)
		gear.focus_mode = Control.FOCUS_NONE
		gear.pressed.connect(_rotate_carrier.bind(carrier))
		for style: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			gear.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		_gear_buttons.append(gear)
	for socket: int in [Puzzle.MOTOR, Puzzle.OUTPUT, Puzzle.IDLER]:
		var fixed := Control.new()
		fixed.mouse_filter = Control.MOUSE_FILTER_PASS
		fixed.tooltip_text = "Fixed gear"
		_plate.add_child(fixed)
		_watch_pointer(fixed)
		_fixed_gears.append(fixed)
	_idler_button = _make_plate_button("+", "Fit idler into mounting socket")
	_idler_button.pressed.connect(_fit_idler)
	_layout_plate_buttons.call_deferred()
	_refresh_plate()
	_update_controls()
	if _has_blueprint and not %Bench.vertical:
		_insert.grab_focus()
	else:
		_return.grab_focus()


func _update_layout() -> void:
	var width := mini(get_window().size.x, int(size.x)) if size.x > 0.0 else get_window().size.x
	var narrow := width < 760
	%Bench.vertical = narrow
	%Machine.custom_minimum_size.y = clampf(size.x * 0.66, 350.0, 620.0) if narrow else 0.0
	if has_node("%KeybindHintText"):
		%KeybindHintText.text = "Click: Use · Tab: Focus · Enter: Activate" if width < 520 else "Click: Use  ·  Tab / Arrows: Focus  ·  Enter / Space: Activate"


func _size_blueprint() -> void:
	_sheet.custom_minimum_size.y = clampf((%CardStack.size.x - 24.0) * 0.78, 145.0, 340.0)


func _insert_blueprint() -> void:
	if not _has_blueprint or _inserting or _unlocked or _leaving:
		return
	_inserting = true
	_insert.disabled = true
	_insert.text = "Reading blueprint…"
	var insertion := create_tween()
	insertion.tween_property(%Card, "position:x", 78.0, 0.33).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	insertion.parallel().tween_property(%ReaderLight, "color", Color("#8ed6ab"), 0.33)
	await insertion.finished
	%Card.hide()
	%Gate.hide()
	_insert.text = "Blueprint inserted"
	_inserting = false
	_unlocked = true
	_plate.locked = false
	_restore_completion()
	_record_blueprint_work(_completed)
	for carrier: int in range(_rotations.size()):
		_plate.turns[carrier] = float(_rotations[carrier])
	_feedback("Build complete." if _completed else "Fit the loose idler.")
	_refresh_plate()
	_update_controls()
	_layout_plate_buttons()
	(_crank if _fitted else _tray).grab_focus()


func _restore_completion() -> void:
	var config := Save.load_config(SAVE_PATH)
	_completed = config.get_value(puzzle.puzzle_id, "completed", false) == true
	var saved: Variant = config.get_value(puzzle.puzzle_id, "rotations", PackedInt32Array())
	if not _unlocked or not _completed or not saved is PackedInt32Array or saved.size() != Puzzle.CARRIER_COUNT:
		return
	var result := puzzle.trace(saved, true)
	if not result.locked and result.directions.get(Puzzle.OUTPUT, 0) == puzzle.required_output_direction:
		_fitted = true
		_rotations = saved
		_plate.output_result = puzzle.required_output_direction
		_plate.result_passed = true


func _make_plate_button(caption: String, description: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.tooltip_text = description
	button.accessibility_name = description
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	_plate.add_child(button)
	_watch_pointer(button)
	return button


func _watch_pointer(control: Control) -> void:
	control.mouse_entered.connect(_sync_cue, CONNECT_DEFERRED)
	control.mouse_exited.connect(_sync_cue, CONNECT_DEFERRED)


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_idler_button):
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		if _keyboard_cues:
			_keyboard_cues = false
			_sync_cue.call_deferred()
	elif event is InputEventKey and event.pressed:
		_keyboard_cues = true
		_sync_cue.call_deferred()


func _sync_cue() -> void:
	if not _unlocked or not is_instance_valid(_idler_button):
		return
	var hovered := get_viewport().gui_get_hovered_control()
	var hovered_button := hovered as Button
	var carrier := _carrier_buttons.find(hovered_button)
	if carrier < 0:
		carrier = _gear_buttons.find(hovered_button)
	var hint := ""
	if hovered in _fixed_gears:
		hint = "Fixed gear"
	else:
		if carrier < 0 and _keyboard_cues:
			carrier = _carrier_buttons.find(get_viewport().gui_get_focus_owner() as Button)
		if carrier >= 0 and not _fitted:
			hint = "Fit the idler first."
		elif carrier >= 0 and _testing:
			hint = "Crank in motion."
	_plate.preview_carrier = carrier if _fitted and not _testing and not _adjusting and not _leaving and hint.is_empty() else -1
	_status.text = hint if not hint.is_empty() else _test_feedback
	_plate.refresh()


func _feedback(message: String) -> void:
	_test_feedback = message
	_status.text = message


func _layout_plate_buttons() -> void:
	if not is_instance_valid(_idler_button):
		return
	var side := clampf(_plate.plate_scale() * 31.0, 26.0, 40.0)
	for carrier: int in range(_carrier_buttons.size()):
		var button := _carrier_buttons[carrier]
		button.size = Vector2.ONE * side
		button.position = _plate.screen_position(puzzle.carrier_pivots[carrier]) - button.size * 0.5
		var socket := puzzle.socket_id(carrier, _rotations[carrier])
		_place_hit_target(_gear_buttons[carrier], socket)
	_idler_button.size = Vector2.ONE * side
	_idler_button.position = _plate.screen_position(puzzle.idler_socket) - _idler_button.size * 0.5
	for socket: int in range(_fixed_gears.size()):
		_place_hit_target(_fixed_gears[socket], socket)
	_crank.size = _crank.get_combined_minimum_size()
	var crank_center := _plate.screen_position(puzzle.motor_socket + Vector2(0, puzzle.pitch_radius(Puzzle.MOTOR) + 28))
	_crank.position = crank_center - _crank.size * 0.5


func _place_hit_target(target: Control, socket: int) -> void:
	var width := puzzle.pitch_radius(socket) * 1.38 * _plate.plate_scale()
	target.size = Vector2.ONE * width
	target.position = _plate.screen_position(puzzle.socket_position(socket)) - target.size * 0.5


func _pick_up_idler() -> void:
	if not _unlocked or _fitted or _leaving:
		return
	_holding_idler = not _holding_idler
	_feedback("Select the + socket." if _holding_idler else "Fit the loose idler.")
	_refresh_plate()
	_update_controls()
	if _holding_idler:
		_idler_button.grab_focus()


func _fit_idler() -> void:
	if not _holding_idler or _leaving:
		return
	_holding_idler = false
	_fitted = true
	_record_blueprint_work(false)
	_feedback("Idler fitted.")
	_refresh_plate()
	_update_controls()
	_carrier_buttons[0].grab_focus()


func _rotate_carrier(carrier: int) -> void:
	if not _fitted or _adjusting or _testing or _leaving:
		return
	_adjusting = true
	_plate.output_result = 0
	_plate.contacts.clear()
	_update_controls()
	_rotations[carrier] = posmod(_rotations[carrier] + 1, Puzzle.SOCKETS_PER_CARRIER)
	_record_blueprint_work(false)
	var turn := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	turn.tween_method(_set_visual_turn.bind(carrier), _plate.turns[carrier], _plate.turns[carrier] + 1.0, 0.22)
	_feedback("Ready to test.")
	await turn.finished
	_plate.turns[carrier] = _rotations[carrier]
	_adjusting = false
	_layout_plate_buttons()
	_refresh_plate()
	_update_controls()


func _set_visual_turn(value: float, carrier: int) -> void:
	_plate.turns[carrier] = value
	_plate.refresh()


func _test_crank() -> void:
	if not _fitted or _adjusting or _testing or _leaving:
		return
	_testing = true
	_plate.output_result = 0
	_plate.spin_angles.clear()
	_feedback("Cranking…")
	_update_controls()
	var result := puzzle.trace(_rotations, _fitted)
	_plate.contacts.assign(result.contacts)
	var sequence := create_tween()
	_spin_layer(result, 0)
	var last_depth := 0
	for depth: int in result.depths.values():
		last_depth = maxi(last_depth, depth)
	if not result.locked:
		for depth: int in range(1, last_depth + 1):
			sequence.tween_interval(0.18)
			sequence.tween_callback(_spin_layer.bind(result, depth))
	sequence.tween_callback(_show_result.bind(result))
	var passed: bool = not result.locked and result.directions.get(Puzzle.OUTPUT, 0) == puzzle.required_output_direction
	sequence.tween_interval(1.6 if passed else 0.65)
	await sequence.finished
	_plate.spin_rates.clear()
	_plate.refresh()
	_testing = false
	_update_controls()
	_crank.grab_focus()


func _spin_layer(result: Dictionary, depth: int) -> void:
	for socket: int in result.depths:
		if result.depths[socket] == depth:
			_plate.spin_rates[socket] = result.directions[socket]
	_plate.refresh()


func _show_result(result: Dictionary) -> void:
	if result.locked:
		_feedback("Gear train jammed.")
		return
	var direction: int = result.directions.get(Puzzle.OUTPUT, 0)
	_plate.output_result = direction
	_plate.result_passed = direction == puzzle.required_output_direction
	if direction == 0:
		_feedback("Broken chain.")
		return
	var heading := "Clockwise" if direction == Puzzle.Direction.CLOCKWISE else "Counterclockwise"
	if not _plate.result_passed:
		_feedback("%s output." % heading)
		return
	var config := Save.load_config(SAVE_PATH)
	config.set_value(puzzle.puzzle_id, "completed", true)
	config.set_value(puzzle.puzzle_id, "rotations", _rotations)
	if Save.write_config(config, SAVE_PATH) == OK:
		_completed = true
		_record_blueprint_work(true)
		_feedback("%s. Build complete." % heading)
		var checkpoint := get_node_or_null("/root/GameSave")
		if checkpoint != null:
			checkpoint.request_autosave()
	else:
		_feedback("Passed. Test again to retry saving.")


func _record_blueprint_work(completed: bool) -> void:
	if demo_blueprint or puzzle == null:
		return
	ProjectBlueprints.mark_worked(puzzle.linked_blueprint_id, completed)


func _refresh_plate() -> void:
	_plate.idler_fitted = _fitted
	_plate.idler_selected = _holding_idler
	_plate.contacts.assign(puzzle.trace(_rotations, _fitted).contacts)
	_plate.refresh()
	_sheet.refresh()


func _update_controls() -> void:
	_crank.visible = _unlocked
	%Feedback.visible = _unlocked
	%Legend.visible = _unlocked
	%TrayRow.visible = _unlocked and not _fitted
	_tray.text = "Idler fitted" if _fitted else ("Idler selected" if _holding_idler else "Take idler")
	_tray.disabled = not _unlocked or _fitted or _leaving
	_tray_pocket.queue_redraw()
	_crank.disabled = not _fitted or _testing or _adjusting or _leaving
	_return.disabled = _testing or _leaving or return_scene.is_empty()
	if not is_instance_valid(_idler_button):
		return
	%LegendText.text = "Select a carrier to rotate.\nTest crank to check the output." if _fitted else "Select the idler, then the + socket."
	_idler_button.visible = _unlocked and not _fitted
	_idler_button.disabled = not _holding_idler or _leaving
	for carrier: int in range(_carrier_buttons.size()):
		_carrier_buttons[carrier].visible = _unlocked
		_carrier_buttons[carrier].disabled = not _fitted or _testing or _leaving
		_gear_buttons[carrier].visible = _unlocked and not _adjusting
		_gear_buttons[carrier].disabled = not _fitted or _testing or _leaving
	for socket: int in range(_fixed_gears.size()):
		_fixed_gears[socket].visible = _unlocked and (socket != Puzzle.IDLER or _fitted)
	_sync_cue.call_deferred()


func _draw_tray() -> void:
	var center := _tray_pocket.size * 0.5
	_tray_pocket.draw_circle(center, 15.0, Color("#395253"), true, -1, true)
	_tray_pocket.draw_circle(center, 13.0, Plate.CLUE if _holding_idler else Color("#111d20"), true, -1, true)
	if not _fitted and not _holding_idler:
		_tray_pocket.draw_set_transform(center, 0.0, Vector2.ONE * 0.53)
		Plate.draw_gear(_tray_pocket, Vector2.ZERO, Plate.STEEL if _unlocked else Color("#79908d"))


func _update_clock(_minutes: int) -> void:
	%Clock.text = "Day %d   %s" % [GameClock.get_day(), GameClock.get_formatted_time()]


func _leave() -> void:
	if _leaving or _testing or SceneTransition.is_active() or return_scene.is_empty():
		return
	_leaving = true
	_update_controls()
	SceneTransition.change_scene(return_scene, return_spawn)


func _on_transition_finished(error: Error) -> void:
	if not _leaving:
		return
	_leaving = false
	_update_controls()
	if error != OK:
		%Feedback.show()
		_feedback("Could not return to the lab.")
	_return.grab_focus()
