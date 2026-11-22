extends Control

const Blueprint = preload("res://scripts/interaction/desktop/project/blueprint.gd")
const Puzzle = preload("res://scripts/interaction/workshop/transmission_puzzle.gd")
const Plate = preload("res://scripts/interaction/workshop/transmission_plate.gd")
const BlueprintCard = preload("res://scripts/interaction/workshop/blueprint_card.gd")
const ReaderSlot = preload("res://scripts/interaction/workshop/blueprint_reader_slot.gd")
const SliderHandle = preload("res://scripts/interaction/workshop/slider_handle.gd")
const Save = preload("res://scripts/autoload/playthrough_save.gd")
const SAVE_PATH := "user://workshop_progress.cfg"
const TUTORIAL_ID := "blueprint_workshop_intro"
const Spotlight = preload("res://scripts/ui/tutorial_spotlight.gd")
const PLATE_BUTTON_FONT: Font = preload("res://assets/fonts/pixelify_sans/PixelifySans-SemiBold.ttf")

@export var puzzles: Array[Puzzle]
@export var blueprints: Array[Blueprint]
@export_file("*.tscn") var return_scene := "res://scenes/movement/campus_lab_room.tscn"
@export var return_spawn: StringName = &"WorkshopSpawn"
@export var return_label := "Kembali ke lab"
@export var demo_blueprint := false

var _catalog: Array[Puzzle] = []
var _active_puzzle: Puzzle
var _rotations := PackedInt32Array()
var _slider_stops := PackedInt32Array()
var _carrier_buttons: Array[Button] = []
var _gear_buttons: Array[Button] = []
var _slider_handles: Array[SliderHandle] = []
var _fixed_gears: Array[Control] = []
var _blueprint_cards: Dictionary[String, BlueprintCard] = {}
var _selected_puzzle_id := ""
var _dragging_slider := -1
var _inserting := false
var _unlocked := false
var _completed := false
var _adjusting := false
var _testing := false
var _leaving := false
var _relocking := false
var _keyboard_cues := false
var _test_feedback := ""
var _active_tweens: Array[Tween] = []
var _sanity_blur: ColorRect
var _tutorial: TutorialSpotlight

@onready var _plate: Plate = %Plate
@onready var _sheet: Plate = %Sheet
@onready var _status: Label = %Status
@onready var _crank: Button = %Crank
@onready var _return: Button = %Return
@onready var _insert: Button = %Insert
@onready var _reader_slot: ReaderSlot = %ReaderSlot


func _ready() -> void:
	GameClock.resume_timeline()
	GameClock.minute_changed.connect(_update_clock)
	_update_clock(GameClock.get_absolute_minutes())
	_return.text = return_label
	_return.pressed.connect(_leave)
	_return.disabled = return_scene.is_empty()
	SceneTransition.transition_finished.connect(_on_transition_finished)
	_crank.pressed.connect(_test_crank)
	_insert.pressed.connect(_on_insert_button_pressed)
	_reader_slot.source_id = get_instance_id()
	_reader_slot.can_accept_drop = _can_accept_blueprint_drop
	_reader_slot.blueprint_dropped.connect(_insert_blueprint_by_id)
	ProjectBlueprints.changed.connect(_on_blueprints_changed)
	_setup_sanity_blur()
	PlayerStats.changed.connect(_update_sanity_blur)
	_update_sanity_blur()
	%CardStack.resized.connect(_size_blueprint)
	get_window().size_changed.connect(_update_layout)
	resized.connect(_update_layout)
	_plate.resized.connect(_layout_plate_buttons)
	get_viewport().gui_focus_changed.connect(func(_control: Control) -> void: _sync_cue.call_deferred())
	_update_layout()

	for entry: Puzzle in puzzles:
		if entry != null and entry.is_valid():
			_catalog.append(entry)

	if _catalog.is_empty():
		_status.text = "Belum ada teka-teki meja yang diatur."
		%Blueprint.hide()
		%Legend.hide()
		%BlueprintDock.hide()
		_insert.disabled = true
		_plate.locked = true
		_plate.refresh()
		_update_controls()
		_return.grab_focus()
		return

	_plate.locked = true
	_sheet.sheet = true
	_sheet.puzzle = null
	%Blueprint.hide()
	_rebuild_blueprint_dock()
	_update_gate_prompt()
	_refresh_plate()
	_update_controls()
	_focus_dock_or_return()
	_maybe_show_workshop_tutorial()


func _exit_tree() -> void:
	_kill_tweens()


func _update_layout() -> void:
	var width := mini(get_window().size.x, int(size.x)) if size.x > 0.0 else get_window().size.x
	var narrow := width < 760
	%Bench.vertical = narrow
	%Machine.custom_minimum_size.y = clampf(size.x * 0.66, 350.0, 620.0) if narrow else 0.0
	if has_node("%BenchSpacer"):
		%BenchSpacer.visible = not narrow
	if has_node("%KeybindHintText"):
		%KeybindHintText.text = "Seret: Blueprint / Slider · Tab: Fokus · Enter: Pakai" if width < 560 else "Seret: Blueprint / Slider  ·  Klik: Putar / Crank  ·  Tab / Panah: Fokus  ·  Enter / Spasi: Aktifkan"


func _size_blueprint() -> void:
	_sheet.custom_minimum_size.y = clampf((%CardStack.size.x - 24.0) * 0.72, 130.0, 250.0)


func _is_puzzle_owned(entry: Puzzle) -> bool:
	return entry != null and (demo_blueprint or ProjectBlueprints.is_owned(entry.linked_blueprint_id))


func _is_puzzle_completed(entry: Puzzle) -> bool:
	if entry == null:
		return false
	var config := Save.load_config(SAVE_PATH)
	return config.get_value(entry.puzzle_id, "completed", false) == true


func _owned_puzzles() -> Array[Puzzle]:
	var owned: Array[Puzzle] = []
	for entry: Puzzle in _catalog:
		if _is_puzzle_owned(entry):
			owned.append(entry)
	return owned


func _find_owned_puzzle(puzzle_id: String) -> Puzzle:
	for entry: Puzzle in _catalog:
		if entry.puzzle_id == puzzle_id and _is_puzzle_owned(entry):
			return entry
	return null


func _on_blueprints_changed() -> void:
	_rebuild_blueprint_dock()
	if not _unlocked:
		_update_gate_prompt()
		_update_controls()


func _rebuild_blueprint_dock() -> void:
	for child: Node in %BlueprintList.get_children():
		%BlueprintList.remove_child(child)
		child.queue_free()
	_blueprint_cards.clear()

	var owned := _owned_puzzles()
	%NoBlueprints.visible = owned.is_empty()
	if owned.is_empty():
		_selected_puzzle_id = ""
		return

	if _find_owned_puzzle(_selected_puzzle_id) == null:
		_selected_puzzle_id = _pick_default_puzzle_id(owned)

	for entry: Puzzle in owned:
		var card := BlueprintCard.new()
		%BlueprintList.add_child(card)
		card.configure(
			entry,
			_artwork_for_puzzle(entry),
			get_instance_id(),
			_is_puzzle_completed(entry),
			_active_puzzle == entry,
			_selected_puzzle_id == entry.puzzle_id
		)
		card.card_selected.connect(_on_card_selected)
		card.card_activated.connect(_insert_blueprint_by_id)
		card.drag_started.connect(_on_card_selected)
		_blueprint_cards[entry.puzzle_id] = card


func _artwork_for_puzzle(entry: Puzzle) -> Texture2D:
	if entry == null:
		return null
	for bp: Blueprint in blueprints:
		if bp != null and (bp.blueprint_id == entry.linked_blueprint_id or bp.workshop_puzzle_id == entry.puzzle_id):
			return bp.artwork
	return null


func _pick_default_puzzle_id(owned: Array[Puzzle]) -> String:
	for entry: Puzzle in owned:
		if not _is_puzzle_completed(entry):
			return entry.puzzle_id
	return owned[0].puzzle_id if not owned.is_empty() else ""


func _refresh_blueprint_dock_states() -> void:
	for puzzle_id: String in _blueprint_cards:
		var card := _blueprint_cards[puzzle_id]
		if not is_instance_valid(card):
			continue
		card.configure(
			card.puzzle,
			_artwork_for_puzzle(card.puzzle),
			get_instance_id(),
			_is_puzzle_completed(card.puzzle),
			_active_puzzle == card.puzzle,
			_selected_puzzle_id == puzzle_id
		)


func _on_card_selected(puzzle_id: String) -> void:
	_selected_puzzle_id = puzzle_id
	_refresh_blueprint_dock_states()
	_update_controls()


func _can_accept_blueprint_drop(puzzle_id: String) -> bool:
	if _inserting or _testing or _adjusting or _leaving or _relocking or _dragging_slider >= 0:
		return false
	var target := _find_owned_puzzle(puzzle_id)
	if target == null:
		return false
	return _active_puzzle != target


func _on_insert_button_pressed() -> void:
	if _adjusting or _dragging_slider >= 0 or _testing or _inserting or _relocking or _leaving:
		return
	if _unlocked:
		_eject_blueprint("Blueprint dikeluarkan.")
	elif not _selected_puzzle_id.is_empty():
		_insert_blueprint_by_id(_selected_puzzle_id)


func _insert_blueprint_by_id(puzzle_id: String) -> void:
	if not _can_accept_blueprint_drop(puzzle_id):
		return
	var target := _find_owned_puzzle(puzzle_id)
	if target == null:
		return
	if not demo_blueprint:
		if PlayerStats.get_energy() <= 0.0:
			_feedback("Energi habis. Istirahat dahulu di Kamar 210 sebelum merakit proyek.")
			return
		var charge_err := CareerProgress.begin_activity("project", "bp_" + target.linked_blueprint_id)
		if charge_err != OK:
			_feedback("Energi tidak cukup (-20 Energi diperlukan). Istirahat dahulu di Kamar 210.")
			return

	_inserting = true
	if _unlocked:
		_clear_active_puzzle_state()
	_selected_puzzle_id = puzzle_id
	_refresh_blueprint_dock_states()
	_update_controls()

	%Card.position.x = 8.0
	%Card.show()
	_feedback("Membaca Blueprint…")

	var insertion := _track_tween()
	insertion.tween_property(%Card, "position:x", 78.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	insertion.parallel().tween_property(%ReaderLight, "color", Color("#8ed6ab"), 0.3)
	await insertion.finished
	if not is_instance_valid(self) or not is_inside_tree():
		return

	%Card.hide()
	%Gate.hide()
	_inserting = false
	_load_puzzle_into_bench(target)


func _load_puzzle_into_bench(target: Puzzle) -> void:
	_active_puzzle = target
	_unlocked = true
	_completed = false
	_rotations = target.starting_rotations.duplicate()
	_slider_stops = target.default_slider_stops()
	_restore_completion()

	_plate.puzzle = target
	_plate.locked = false
	_plate.output_result = 0
	_plate.result_passed = false
	_plate.preview_carrier = -1
	_plate.preview_slider = -1
	_plate.dragging_slider = -1
	_plate.spin_rates.clear()
	_plate.spin_angles.clear()

	_plate.turns.resize(_rotations.size())
	for carrier: int in range(_rotations.size()):
		_plate.turns[carrier] = float(_rotations[carrier])

	_plate.slider_values.resize(_slider_stops.size())
	for slider_idx: int in range(_slider_stops.size()):
		_plate.slider_values[slider_idx] = float(_slider_stops[slider_idx])

	_sheet.puzzle = target
	%SheetTitle.text = "%s — %s" % [target.title, target.difficulty]
	%Blueprint.show()

	_build_dynamic_plate_controls()
	_record_blueprint_work(_completed)
	_feedback("Perakitan selesai." if _completed else "")
	_refresh_blueprint_dock_states()
	_refresh_plate()
	_update_controls()
	_layout_plate_buttons.call_deferred()
	_focus_first_plate_control()


func _restore_completion() -> void:
	if _active_puzzle == null:
		return
	var config := Save.load_config(SAVE_PATH)
	_completed = config.get_value(_active_puzzle.puzzle_id, "completed", false) == true
	var saved_rots: Variant = config.get_value(_active_puzzle.puzzle_id, "rotations", PackedInt32Array())
	var saved_stops: Variant = config.get_value(_active_puzzle.puzzle_id, "slider_stops", _active_puzzle.default_slider_stops())
	if not _completed:
		return
	if not saved_rots is PackedInt32Array or saved_rots.size() != _active_puzzle.carrier_count():
		return
	if not saved_stops is PackedInt32Array or saved_stops.size() != _active_puzzle.slider_count():
		return
	var result := _active_puzzle.trace(saved_rots, saved_stops)
	if not result.locked and result.directions.get(Puzzle.OUTPUT, 0) == _active_puzzle.required_output_direction:
		_rotations = saved_rots
		_slider_stops = saved_stops


func _clear_active_puzzle_state() -> void:
	_clear_dynamic_plate_controls()
	_active_puzzle = null
	_unlocked = false
	_completed = false
	_dragging_slider = -1
	_rotations = PackedInt32Array()
	_slider_stops = PackedInt32Array()
	_plate.puzzle = null
	_plate.locked = true
	_plate.turns = PackedFloat32Array()
	_plate.slider_values = PackedFloat32Array()
	_plate.contacts.clear()
	_plate.spin_rates.clear()
	_plate.spin_angles.clear()
	_plate.output_result = 0
	_plate.result_passed = false
	_plate.preview_carrier = -1
	_plate.preview_slider = -1
	_plate.dragging_slider = -1
	_sheet.puzzle = null
	%Blueprint.hide()


func _relock_after_completion() -> void:
	await _eject_blueprint("Hasil tersimpan. Seret Blueprint lain ke Slot.")


func _eject_blueprint(status_message: String) -> void:
	if _relocking or not _unlocked:
		return
	_relocking = true
	_update_controls()
	%Card.position.x = 78.0
	%Card.show()
	var ejection := _track_tween()
	ejection.tween_property(%Card, "position:x", 8.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	ejection.parallel().tween_property(%ReaderLight, "color", Color("#b55445"), 0.26)
	await ejection.finished
	if not is_instance_valid(self) or not is_inside_tree():
		return
	%Card.hide()
	_clear_active_puzzle_state()
	_relocking = false
	_selected_puzzle_id = _pick_default_puzzle_id(_owned_puzzles())
	_refresh_blueprint_dock_states()
	_update_gate_prompt()
	_feedback(status_message)
	_refresh_plate()
	_update_controls()
	_focus_dock_or_return()


func _update_gate_prompt() -> void:
	var owned := _owned_puzzles()
	if owned.is_empty():
		%Gate.text = "Blueprint diperlukan"
	else:
		var any_unbuilt := false
		for entry: Puzzle in owned:
			if not _is_puzzle_completed(entry):
				any_unbuilt = true
				break
		%Gate.text = "Seret Blueprint ke Slot" if any_unbuilt else "Semua Blueprint yang dimiliki sudah selesai"
	%Gate.visible = not _unlocked


func _build_dynamic_plate_controls() -> void:
	_clear_dynamic_plate_controls()
	if _active_puzzle == null:
		return

	for carrier: int in range(_active_puzzle.carrier_count()):
		var letter := char(65 + carrier)
		var button := _make_plate_button(letter, "Putar Carrier " + letter + " Clockwise")
		button.pressed.connect(_rotate_carrier.bind(carrier))
		_carrier_buttons.append(button)

		var gear := _make_plate_button("", button.accessibility_name)
		gear.focus_mode = Control.FOCUS_NONE
		gear.pressed.connect(_rotate_carrier.bind(carrier))
		for style: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			gear.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		_gear_buttons.append(gear)

	for slider_idx: int in range(_active_puzzle.slider_count()):
		var handle := SliderHandle.new()
		handle.slider_index = slider_idx
		handle.plate = _plate
		handle.puzzle = _active_puzzle
		handle.tooltip_text = "Seret Slider atau klik untuk menggeser"
		handle.accessibility_name = "Slider Gear %d" % (slider_idx + 1)
		handle.drag_started.connect(_on_slider_drag_started)
		handle.drag_moved.connect(_on_slider_drag_moved)
		handle.drag_ended.connect(_on_slider_drag_ended)
		handle.step_requested.connect(_on_slider_step)
		_plate.add_child(handle)
		_watch_pointer(handle)
		_slider_handles.append(handle)

	var fixed_total := Puzzle.FIRST_FIXED + _active_puzzle.fixed_count()
	for socket: int in range(fixed_total):
		var fixed := Control.new()
		fixed.mouse_filter = Control.MOUSE_FILTER_PASS
		fixed.focus_mode = Control.FOCUS_NONE
		fixed.tooltip_text = "Penggerak Motor" if socket == Puzzle.MOTOR else ("Output Gear" if socket == Puzzle.OUTPUT else "Fixed Gear")
		_plate.add_child(fixed)
		_watch_pointer(fixed)
		_fixed_gears.append(fixed)


func _clear_dynamic_plate_controls() -> void:
	for button: Button in _carrier_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_carrier_buttons.clear()
	for gear: Button in _gear_buttons:
		if is_instance_valid(gear):
			gear.queue_free()
	_gear_buttons.clear()
	for handle: SliderHandle in _slider_handles:
		if is_instance_valid(handle):
			handle.cancel_drag()
			handle.queue_free()
	_slider_handles.clear()
	for fixed: Control in _fixed_gears:
		if is_instance_valid(fixed):
			fixed.queue_free()
	_fixed_gears.clear()


func _make_plate_button(caption: String, description: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.tooltip_text = description
	button.accessibility_name = description
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", PLATE_BUTTON_FONT)
	button.add_theme_font_size_override("font_size", 15)
	_plate.add_child(button)
	_watch_pointer(button)
	return button


func _watch_pointer(control: Control) -> void:
	control.mouse_entered.connect(_sync_cue, CONNECT_DEFERRED)
	control.mouse_exited.connect(_sync_cue, CONNECT_DEFERRED)


func _input(event: InputEvent) -> void:
	if is_tutorial_visible():
		return
	if not _unlocked:
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		if _keyboard_cues:
			_keyboard_cues = false
			_sync_cue.call_deferred()
	elif event is InputEventKey and event.pressed:
		_keyboard_cues = true
		_sync_cue.call_deferred()


func _sync_cue() -> void:
	if not _unlocked or _active_puzzle == null:
		return
	var hovered := get_viewport().gui_get_hovered_control()
	var hovered_button := hovered as Button
	var carrier := _carrier_buttons.find(hovered_button)
	if carrier < 0:
		carrier = _gear_buttons.find(hovered_button)
	var slider_idx := _slider_handles.find(hovered as SliderHandle)

	var hint := ""
	if hovered in _fixed_gears:
		hint = (hovered as Control).tooltip_text
	elif _dragging_slider >= 0:
		hint = "Geser Slider ke salah satu titik henti."
	else:
		if carrier < 0 and slider_idx < 0 and _keyboard_cues:
			var focused := get_viewport().gui_get_focus_owner()
			carrier = _carrier_buttons.find(focused as Button)
			slider_idx = _slider_handles.find(focused as SliderHandle)
		if (carrier >= 0 or slider_idx >= 0) and _testing:
			hint = "Crank sedang berputar."

	var show_preview := not _testing and not _adjusting and not _leaving and not _relocking and _dragging_slider < 0 and hint.is_empty()
	_plate.preview_carrier = carrier if show_preview and carrier >= 0 else -1
	_plate.preview_slider = slider_idx if show_preview and slider_idx >= 0 else -1
	_status.text = hint if not hint.is_empty() else _test_feedback
	%Feedback.visible = not _status.text.is_empty()
	_plate.refresh()


func _feedback(message: String) -> void:
	_test_feedback = message
	_status.text = message
	%Feedback.visible = not message.is_empty()


func _layout_plate_buttons() -> void:
	if not _unlocked or _active_puzzle == null:
		return
	var scale_factor := _plate.plate_scale()
	var side := clampf(scale_factor * 31.0, 26.0, 40.0)
	for carrier: int in range(_carrier_buttons.size()):
		var button := _carrier_buttons[carrier]
		if not is_instance_valid(button):
			continue
		button.size = Vector2.ONE * side
		button.position = _plate.screen_position(_active_puzzle.carrier_pivots[carrier]) - button.size * 0.5
		var socket := _active_puzzle.carrier_socket_id(carrier, _rotations[carrier])
		_place_hit_target(_gear_buttons[carrier], socket)

	for slider_idx: int in range(_slider_handles.size()):
		var handle := _slider_handles[slider_idx]
		if not is_instance_valid(handle):
			continue
		var stop_val := _plate.slider_values[slider_idx] if slider_idx < _plate.slider_values.size() else float(_slider_stops[slider_idx])
		var radius := _active_puzzle.sliders[slider_idx].pitch_radius
		var diameter := clampf(radius * 1.65 * scale_factor, 28.0, 56.0)
		handle.size = Vector2.ONE * diameter
		handle.position = _plate.screen_position(_active_puzzle.slider_gear_position(slider_idx, stop_val)) - handle.size * 0.5

	for socket: int in range(_fixed_gears.size()):
		_place_hit_target(_fixed_gears[socket], socket)

	_crank.size = _crank.get_combined_minimum_size()
	var crank_center := _plate.screen_position(_active_puzzle.motor_socket + Vector2(0, _active_puzzle.motor_radius + 26.0))
	var max_y := maxf(4.0, _plate.size.y - _crank.size.y - 4.0)
	var max_x := maxf(4.0, _plate.size.x - _crank.size.x - 4.0)
	_crank.position = Vector2(clampf(crank_center.x - _crank.size.x * 0.5, 4.0, max_x), clampf(crank_center.y - _crank.size.y * 0.5, 4.0, max_y))


func _place_hit_target(target: Control, socket: int) -> void:
	if not is_instance_valid(target) or _active_puzzle == null:
		return
	var width := _active_puzzle.pitch_radius(socket) * 1.38 * _plate.plate_scale()
	target.size = Vector2.ONE * width
	target.position = _plate.screen_position(_active_puzzle.socket_position(socket)) - target.size * 0.5


func _rotate_carrier(carrier: int) -> void:
	if not _unlocked or _active_puzzle == null or _adjusting or _testing or _leaving or _relocking or _dragging_slider >= 0:
		return
	var step_count := 0
	var next_rot := _rotations[carrier]
	for step: int in range(1, Puzzle.SOCKETS_PER_CARRIER + 1):
		var candidate := posmod(_rotations[carrier] + step, Puzzle.SOCKETS_PER_CARRIER)
		if candidate != _rotations[carrier] and _active_puzzle.can_rotate_carrier(_rotations, _slider_stops, carrier, candidate):
			step_count = step
			next_rot = candidate
			break
	if step_count == 0:
		_feedback("Carrier terhalang Gear lain.")
		return

	_adjusting = true
	_plate.output_result = 0
	_plate.contacts.clear()
	_update_controls()
	_rotations[carrier] = next_rot
	_record_blueprint_work(false)

	var turn := _track_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	turn.tween_method(_set_visual_turn.bind(carrier), _plate.turns[carrier], _plate.turns[carrier] + float(step_count), 0.22)
	_feedback("")
	await turn.finished
	if not is_instance_valid(self) or not is_inside_tree() or _active_puzzle == null:
		return

	_plate.turns[carrier] = float(_rotations[carrier])
	_adjusting = false
	_layout_plate_buttons()
	_refresh_plate()
	_update_controls()


func _set_visual_turn(value: float, carrier: int) -> void:
	if carrier >= 0 and carrier < _plate.turns.size():
		_plate.turns[carrier] = value
		_plate.refresh()


func _on_slider_drag_started(slider: int) -> void:
	if not _unlocked or _active_puzzle == null or _adjusting or _testing or _leaving or _relocking:
		if slider >= 0 and slider < _slider_handles.size():
			_slider_handles[slider].cancel_drag()
		return
	_dragging_slider = slider
	_plate.output_result = 0
	_plate.contacts.clear()
	_plate.preview_carrier = -1
	_plate.preview_slider = -1
	_plate.dragging_slider = slider
	_feedback("Geser Slider ke salah satu titik henti.")
	_plate.refresh()
	_update_controls()


func _on_slider_drag_moved(slider: int, stop_value: float) -> void:
	if _dragging_slider != slider or _active_puzzle == null:
		return
	if slider >= 0 and slider < _plate.slider_values.size():
		_plate.slider_values[slider] = stop_value
		_layout_plate_buttons()
		_plate.refresh()


func _on_slider_drag_ended(slider: int, target_stop: int) -> void:
	if _dragging_slider != slider or _active_puzzle == null:
		_dragging_slider = -1
		_plate.dragging_slider = -1
		return
	_dragging_slider = -1
	_plate.dragging_slider = -1

	if _active_puzzle.can_move_slider(_rotations, _slider_stops, slider, target_stop):
		_slider_stops[slider] = target_stop
		_record_blueprint_work(false)
		_feedback("")
	else:
		_feedback("Titik henti terhalang Gear lain.")

	await _animate_slider_to_stop(slider, _slider_stops[slider], 0.14)


func _on_slider_step(slider: int) -> void:
	if not _unlocked or _active_puzzle == null or _adjusting or _testing or _leaving or _relocking or _dragging_slider >= 0:
		return
	var slider_res := _active_puzzle.sliders[slider]
	var stop_count := slider_res.stops.size()
	var next_stop := -1
	for offset: int in range(1, stop_count):
		var candidate := (_slider_stops[slider] + offset) % stop_count
		if _active_puzzle.can_move_slider(_rotations, _slider_stops, slider, candidate):
			next_stop = candidate
			break
	if next_stop < 0:
		_feedback("Titik henti Slider terhalang Gear lain.")
		return

	_slider_stops[slider] = next_stop
	_record_blueprint_work(false)
	_feedback("")
	await _animate_slider_to_stop(slider, next_stop, 0.18)


func _animate_slider_to_stop(slider: int, target_stop: int, duration: float) -> void:
	if _active_puzzle == null or slider < 0 or slider >= _plate.slider_values.size():
		return
	_adjusting = true
	_plate.output_result = 0
	_plate.contacts.clear()
	_update_controls()
	var tween := _track_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_visual_slider.bind(slider), _plate.slider_values[slider], float(target_stop), duration)
	await tween.finished
	if not is_instance_valid(self) or not is_inside_tree() or _active_puzzle == null:
		return
	_plate.slider_values[slider] = float(_slider_stops[slider])
	_adjusting = false
	_layout_plate_buttons()
	_refresh_plate()
	_update_controls()


func _set_visual_slider(value: float, slider: int) -> void:
	if slider >= 0 and slider < _plate.slider_values.size():
		_plate.slider_values[slider] = value
		_layout_plate_buttons()
		_plate.refresh()


func _test_crank() -> void:
	if not _unlocked or _active_puzzle == null or _adjusting or _testing or _leaving or _relocking or _dragging_slider >= 0:
		return
	_testing = true
	_plate.output_result = 0
	_plate.spin_angles.clear()
	_feedback("Memutar Crank…")
	_update_controls()

	var result := _active_puzzle.trace(_rotations, _slider_stops)
	_plate.contacts.assign(result.contacts)
	var sequence := _track_tween()
	_spin_layer(result, 0)
	var last_depth := 0
	for depth: int in result.depths.values():
		last_depth = maxi(last_depth, depth)
	if not result.locked:
		for depth: int in range(1, last_depth + 1):
			sequence.tween_interval(0.18)
			sequence.tween_callback(_spin_layer.bind(result, depth))
	sequence.tween_callback(_show_result.bind(result))

	var passed: bool = not result.locked and result.directions.get(Puzzle.OUTPUT, 0) == _active_puzzle.required_output_direction
	sequence.tween_interval(1.35 if passed else 0.65)
	await sequence.finished
	if not is_instance_valid(self) or not is_inside_tree():
		return

	_plate.spin_rates.clear()
	_plate.refresh()
	_testing = false
	if passed:
		await _relock_after_completion()
	else:
		_update_controls()
		_crank.grab_focus()


func _spin_layer(result: Dictionary, depth: int) -> void:
	for socket: int in result.depths:
		if result.depths[socket] == depth:
			_plate.spin_rates[socket] = result.directions[socket]
	_plate.refresh()


func _show_result(result: Dictionary) -> void:
	if _active_puzzle == null:
		return
	if result.locked:
		_feedback("Rangkaian Gear macet.")
		return
	var direction: int = result.directions.get(Puzzle.OUTPUT, 0)
	_plate.output_result = direction
	_plate.result_passed = direction == _active_puzzle.required_output_direction
	if direction == 0:
		_feedback("Rantai Gear terputus.")
		return
	var heading := "Clockwise" if direction == Puzzle.Direction.CLOCKWISE else "Counterclockwise"
	if not _plate.result_passed:
		_feedback("Output %s." % heading)
		return

	var config := Save.load_config(SAVE_PATH)
	config.set_value(_active_puzzle.puzzle_id, "completed", true)
	config.set_value(_active_puzzle.puzzle_id, "rotations", _rotations)
	config.set_value(_active_puzzle.puzzle_id, "slider_stops", _slider_stops)
	if Save.write_config(config, SAVE_PATH) == OK:
		_completed = true
		_record_blueprint_work(true)
		_refresh_blueprint_dock_states()
		_feedback("Output %s. Perakitan selesai." % heading)
		var checkpoint := get_node_or_null("/root/GameSave")
		if checkpoint != null:
			checkpoint.request_autosave()
	else:
		_feedback("Lulus. Uji Crank lagi untuk mencoba menyimpan ulang.")


func _record_blueprint_work(completed: bool) -> void:
	if demo_blueprint or _active_puzzle == null:
		return
	ProjectBlueprints.mark_worked(_active_puzzle.linked_blueprint_id, completed)
	if completed:
		CareerProgress.complete_blueprint(_active_puzzle.linked_blueprint_id)


func _setup_sanity_blur() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_sanity_blur = ColorRect.new()
	_sanity_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sanity_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap; void fragment(){ COLOR = textureLod(screen_texture, SCREEN_UV, 2.0); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	_sanity_blur.material = material
	layer.add_child(_sanity_blur)


func _update_sanity_blur() -> void:
	if is_instance_valid(_sanity_blur):
		_sanity_blur.visible = PlayerStats.get_sanity() >= CareerProgress.SANITY_BLUR_THRESHOLD


func _refresh_plate() -> void:
	if _active_puzzle != null:
		_plate.contacts.assign(_active_puzzle.trace(_rotations, _slider_stops).contacts)
	else:
		_plate.contacts.clear()
	_plate.refresh()
	_sheet.refresh()


func _update_controls() -> void:
	var ui_locked := _inserting or _testing or _leaving or _relocking
	_crank.visible = _unlocked and _active_puzzle != null
	%Feedback.visible = not _status.text.is_empty()
	%Legend.visible = _unlocked and _active_puzzle != null
	_crank.disabled = not _unlocked or _active_puzzle == null or ui_locked
	_return.disabled = ui_locked or return_scene.is_empty()

	if _unlocked and _active_puzzle != null:
		_insert.text = "Keluarkan Blueprint"
		_insert.disabled = ui_locked
	else:
		var has_selected := not _selected_puzzle_id.is_empty() and _find_owned_puzzle(_selected_puzzle_id) != null
		_insert.text = "Masukkan terpilih" if has_selected else "Menunggu Blueprint"
		_insert.disabled = not has_selected or ui_locked

	for card: BlueprintCard in _blueprint_cards.values():
		if is_instance_valid(card):
			card.disabled = ui_locked

	if _active_puzzle != null:
		%LegendText.text = (
			"Putar Carrier atau geser Slider.\nUji Crank untuk memeriksa Output."
			if _active_puzzle.slider_count() > 0
			else "Pilih Carrier untuk memutarnya.\nUji Crank untuk memeriksa Output."
		)

	for carrier: int in range(_carrier_buttons.size()):
		if is_instance_valid(_carrier_buttons[carrier]):
			_carrier_buttons[carrier].visible = _unlocked
			_carrier_buttons[carrier].disabled = not _unlocked or ui_locked
		if is_instance_valid(_gear_buttons[carrier]):
			_gear_buttons[carrier].visible = _unlocked
			_gear_buttons[carrier].disabled = not _unlocked or ui_locked

	for handle: SliderHandle in _slider_handles:
		if is_instance_valid(handle):
			handle.visible = _unlocked
			handle.disabled = not _unlocked or ui_locked

	for fixed: Control in _fixed_gears:
		if is_instance_valid(fixed):
			fixed.visible = _unlocked

	_sync_cue.call_deferred()


func _focus_first_plate_control() -> void:
	if not _carrier_buttons.is_empty() and is_instance_valid(_carrier_buttons[0]):
		_carrier_buttons[0].grab_focus()
	elif not _slider_handles.is_empty() and is_instance_valid(_slider_handles[0]):
		_slider_handles[0].grab_focus()
	else:
		_crank.grab_focus()


func _focus_dock_or_return() -> void:
	if not _selected_puzzle_id.is_empty() and _blueprint_cards.has(_selected_puzzle_id):
		var card := _blueprint_cards[_selected_puzzle_id]
		if is_instance_valid(card):
			card.grab_focus()
			return
	_return.grab_focus()


func _track_tween() -> Tween:
	var kept: Array[Tween] = []
	for active: Tween in _active_tweens:
		if is_instance_valid(active) and active.is_running():
			kept.append(active)
	_active_tweens = kept
	var tween := create_tween()
	_active_tweens.append(tween)
	return tween


func _kill_tweens() -> void:
	for active: Tween in _active_tweens:
		if is_instance_valid(active):
			active.kill()
	_active_tweens.clear()


func _update_clock(_minutes: int) -> void:
	%Clock.text = "Hari %d   %s" % [GameClock.get_day(), GameClock.get_formatted_time()]


func _leave() -> void:
	if _leaving or _testing or _inserting or _relocking or SceneTransition.is_active() or return_scene.is_empty():
		return
	_leaving = true
	_kill_tweens()
	_update_controls()
	SceneTransition.change_scene(return_scene, return_spawn)


func _on_transition_finished(error: Error) -> void:
	if not _leaving:
		return
	_leaving = false
	_update_controls()
	if error != OK:
		%Feedback.show()
		_feedback("Gagal kembali ke lab.")
	_return.grab_focus()


func is_tutorial_visible() -> bool:
	return is_instance_valid(_tutorial) and _tutorial.visible


func dismiss_tutorial() -> void:
	GameSettings.mark_tutorial_seen(TUTORIAL_ID)
	if is_instance_valid(_tutorial):
		var active := _tutorial
		_tutorial = null
		active.dismiss_immediately()
	_focus_dock_or_return()


func _on_tutorial_finished() -> void:
	GameSettings.mark_tutorial_seen(TUTORIAL_ID)
	_tutorial = null
	_focus_dock_or_return()


func _tutorial_crank_rect() -> Rect2:
	if is_instance_valid(_crank) and _crank.is_visible_in_tree():
		var rect := _crank.get_global_rect()
		if rect.size.x > 1.0 and rect.size.y > 1.0:
			return rect
	var plate_rect := _plate.get_global_rect()
	var crank_size := Vector2(120.0, 36.0)
	var center_x := plate_rect.position.x + plate_rect.size.x * 0.28
	var bottom_y := plate_rect.end.y - crank_size.y - 24.0
	return Rect2(Vector2(center_x - crank_size.x * 0.5, bottom_y), crank_size)


func _maybe_show_workshop_tutorial() -> void:
	if is_instance_valid(_tutorial) or GameSettings.has_seen_tutorial(TUTORIAL_ID):
		return
	var steps: Array[Dictionary] = [
		{"target": %BlueprintDock, "caption": "Blueprint milikmu muncul di sini."},
		{"target": _reader_slot, "caption": "Seret gambar Blueprint ke Slot ini."},
		{"target": _plate, "caption": "Putar Carrier atau geser Slider."},
		{"target": _crank, "rect_provider": _tutorial_crank_rect, "fallback_target": _plate, "caption": "Tekan Uji Crank untuk mengetes mesin."},
	]
	_tutorial = Spotlight.new()
	_tutorial.name = &"WorkshopTutorialOverlay"
	_tutorial.finished.connect(_on_tutorial_finished, CONNECT_ONE_SHOT)
	add_child(_tutorial)
	_tutorial.start(steps)
