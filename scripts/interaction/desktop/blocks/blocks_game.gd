extends PanelContainer

const Shape = preload("res://scripts/interaction/desktop/blocks/block_shape.gd")
const Board = preload("res://scripts/interaction/desktop/blocks/block_board.gd")
const TrayPiece = preload("res://scripts/interaction/desktop/blocks/block_tray_piece.gd")
const SIDE := Board.SIDE
const TRAY_SIZE := 3
const LINE_POINTS := 10

@export var shape_pool: Array[Shape]

@export_group("Audio")
@export var place_sound: AudioStream
@export var clear_sound: AudioStream
@export var combo_sound: AudioStream
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var sfx_volume_db: float = -6.0

var _board: Array[Color] = []
var _tray: Array[Shape] = []
var _pool: Array[Shape] = []
var _score := 0
var _selected_slot := -1
var _game_over := false
var _clear_streak := 0
var _turns_without_clear := 0

@onready var _playfield: Board = %Board
@onready var _tray_buttons: Array[TrayPiece] = [%Piece1, %Piece2, %Piece3]


func _ready() -> void:
	_configure_audio_players()
	for shape: Shape in shape_pool:
		if _valid_shape(shape):
			_pool.append(shape)
	_playfield.source_id = get_instance_id()
	_playfield.can_place = _can_place
	_playfield.preview_lines = _preview_lines
	_playfield.placement_requested.connect(_place_piece)
	_playfield.pointer_selection_cleared.connect(_clear_selection)
	for index: int in range(TRAY_SIZE):
		var piece := _tray_buttons[index]
		piece.source_id = get_instance_id()
		piece.board = _playfield
		piece.slot = index
		piece.pressed.connect(_select_piece.bind(index))
	%Restart.pressed.connect(_restart)
	_restart()


func _restart() -> void:
	var restart_had_focus: bool = %Restart.has_focus()
	_board.resize(SIDE * SIDE)
	_board.fill(Color.TRANSPARENT)
	_tray.resize(TRAY_SIZE)
	_tray.fill(null)
	_score = 0
	_selected_slot = -1
	_clear_streak = 0
	_turns_without_clear = 0
	_game_over = _pool.is_empty()
	if not _game_over:
		_refill_tray()
	_refresh()
	if restart_had_focus and not _game_over:
		_tray_buttons[0].grab_focus()


func _valid_shape(shape: Shape) -> bool:
	if shape == null or shape.cells.is_empty() or shape.color.a <= 0.0:
		return false
	var seen: Array[Vector2i] = []
	var corner := Vector2i(SIDE, SIDE)
	for cell: Vector2i in shape.cells:
		if not Rect2i(0, 0, SIDE, SIDE).has_point(cell) or cell in seen:
			return false
		seen.append(cell)
		corner = corner.min(cell)
	return corner == Vector2i.ZERO


func _refill_tray() -> void:
	var viable := _pool.filter(_has_placement)
	if viable.is_empty():
		return
	viable.shuffle()
	for index: int in range(TRAY_SIZE):
		_tray[index] = viable[index % viable.size()]


func _can_place(slot: int, origin: Vector2i) -> bool:
	return not _game_over and slot >= 0 and slot < TRAY_SIZE and _tray[slot] != null and _shape_fits(_tray[slot], origin)


func _shape_fits(shape: Shape, origin: Vector2i) -> bool:
	for offset: Vector2i in shape.cells:
		var cell := origin + offset
		if not Rect2i(0, 0, SIDE, SIDE).has_point(cell) or _board[cell.y * SIDE + cell.x].a > 0.0:
			return false
	return true


func _place_piece(slot: int, origin: Vector2i) -> void:
	if not _can_place(slot, origin):
		return
	var piece := _tray[slot]
	_board = _board_with_piece(slot, origin)
	var lines := _completed_lines(_board)
	_clear_lines(lines)
	var cleared: int = lines.rows.size() + lines.columns.size()
	_score += piece.cells.size() + cleared * LINE_POINTS
	_update_streak_and_play_audio(cleared)
	_tray[slot] = null
	_selected_slot = -1
	if _tray.count(null) == TRAY_SIZE:
		_refill_tray()
	_game_over = not _has_moves()
	_refresh()
	if _game_over:
		%Restart.grab_focus()
	else:
		_playfield.grab_focus()


func _board_with_piece(slot: int, origin: Vector2i) -> Array[Color]:
	var board := _board.duplicate()
	var piece := _tray[slot]
	for offset: Vector2i in piece.cells:
		var cell := origin + offset
		board[cell.y * SIDE + cell.x] = piece.color
	return board


func _preview_lines(slot: int, origin: Vector2i) -> Dictionary:
	return _completed_lines(_board_with_piece(slot, origin))


func _completed_lines(board: Array[Color]) -> Dictionary:
	var rows := PackedInt32Array()
	var columns := PackedInt32Array()
	for i: int in range(SIDE):
		var row_full := true
		var column_full := true
		for j: int in range(SIDE):
			row_full = row_full and board[i * SIDE + j].a > 0.0
			column_full = column_full and board[j * SIDE + i].a > 0.0
		if row_full:
			rows.append(i)
		if column_full:
			columns.append(i)
	return {"rows": rows, "columns": columns}


func _clear_lines(lines: Dictionary) -> void:
	for y: int in range(SIDE):
		for x: int in range(SIDE):
			if y in lines.rows or x in lines.columns:
				_board[y * SIDE + x] = Color.TRANSPARENT


func _has_placement(shape: Shape) -> bool:
	for y: int in range(SIDE):
		for x: int in range(SIDE):
			if _shape_fits(shape, Vector2i(x, y)):
				return true
	return false


func _has_moves() -> bool:
	for piece: Shape in _tray:
		if piece != null and _has_placement(piece):
			return true
	return false


func _clear_selection() -> void:
	if _selected_slot != -1:
		_selected_slot = -1
		_refresh()


func _select_piece(slot: int) -> void:
	if _game_over or _tray[slot] == null:
		return
	_selected_slot = slot
	_refresh()
	_playfield.grab_focus()


func _refresh() -> void:
	%Score.text = "Skor %d" % _score
	%Message.text = "Seret kepingan ke papan." if not _game_over else "Tidak ada langkah tersisa. Skor akhir %d." % _score
	if _pool.is_empty():
		%Message.text = "Tidak ada bentuk tersedia."
	%Restart.visible = _game_over and not _pool.is_empty()
	_playfield.tiles = _board
	_playfield.tray = _tray
	_playfield.selected_slot = _selected_slot
	_playfield.game_over = _game_over
	_playfield.queue_redraw()
	for index: int in range(TRAY_SIZE):
		var button := _tray_buttons[index]
		var shape := _tray[index]
		button.shape = shape
		button.disabled = shape == null or _game_over
		button.set_pressed_no_signal(index == _selected_slot)
		button.accessibility_name = shape.title if shape != null else "Slot baki kosong"
		button.tooltip_text = shape.title if shape != null else ""


func _configure_audio_players() -> void:
	var audio_bus := &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	var entries: Array[Array] = [
		[%PlaceSound as AudioStreamPlayer, place_sound],
		[%ClearSound as AudioStreamPlayer, clear_sound],
		[%ComboSound as AudioStreamPlayer, combo_sound],
	]
	for entry: Array in entries:
		var player := entry[0] as AudioStreamPlayer
		var stream := entry[1] as AudioStream
		if player == null:
			continue
		player.bus = audio_bus
		player.volume_db = sfx_volume_db
		player.stream = stream


func _update_streak_and_play_audio(cleared: int) -> void:
	if cleared > 0:
		_turns_without_clear = 0
		_clear_streak += 1
		if _clear_streak >= 4:
			_play_sfx(%ComboSound as AudioStreamPlayer)
			_clear_streak = 0
		else:
			_play_sfx(%ClearSound as AudioStreamPlayer)
		return

	_play_sfx(%PlaceSound as AudioStreamPlayer)
	if _clear_streak > 0:
		_turns_without_clear += 1
		if _turns_without_clear > 2:
			_clear_streak = 0
			_turns_without_clear = 0


func _play_sfx(player: AudioStreamPlayer) -> void:
	if Engine.is_editor_hint() or player == null or player.stream == null:
		return
	player.volume_db = sfx_volume_db
	player.pitch_scale = randf_range(0.98, 1.02)
	player.play()
