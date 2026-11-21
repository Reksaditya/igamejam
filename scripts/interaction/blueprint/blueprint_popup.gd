extends Window

const Tile = preload("res://scripts/interaction/blueprint/blueprint_tile.gd")

var _selected_piece: int = -1
var _slots: Array[Tile] = []
var _pieces: Array[Tile] = []

@onready var _status: Label = %Status


func _ready() -> void:
	close_requested.connect(hide)
	%Close.pressed.connect(hide)
	BlueprintProgress.changed.connect(_refresh)
	%Board.get_parent().resized.connect(_fit_board)
	size_changed.connect(_fit_board)
	for index: int in BlueprintProgress.PROJECT.lessons.size():
		var slot := Tile.new()
		slot.piece_index = index
		slot.custom_minimum_size = Vector2(60, 36)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.pressed.connect(_place.bind(index))
		%Board.add_child(slot)
		_slots.append(slot)
		var piece := Tile.new()
		piece.piece_index = index
		piece.custom_minimum_size = Vector2(96, 58)
		piece.tooltip_text = BlueprintProgress.PROJECT.lessons[index].title
		piece.accessibility_name = "Potongan " + piece.tooltip_text
		piece.toggle_mode = true
		piece.pressed.connect(_select.bind(index))
		%Pieces.add_child(piece)
		_pieces.append(piece)
	var tray_order := _pieces.duplicate()
	tray_order.shuffle()
	for piece: Tile in tray_order:
		%Pieces.move_child(piece, -1)
	_refresh()
	_fit_board()


func _fit_board() -> void:
	var frame := %Board.get_parent() as AspectRatioContainer
	frame.custom_minimum_size.y = minf(frame.size.x / frame.ratio, maxf(100.0, size.y - 270.0))


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hide()
		set_input_as_handled()


func open() -> void:
	_refresh()
	popup_centered_clamped(Vector2i(720, 620), 0.9)
	_slots[0].grab_focus()


func _select(index: int) -> void:
	_selected_piece = index
	for piece: Tile in _pieces:
		piece.set_pressed_no_signal(piece.piece_index == index)
	_status.text = "Pilih tempat pada siluet untuk potongan: " + BlueprintProgress.PROJECT.lessons[index].title


func _place(slot: int) -> void:
	if _selected_piece < 0:
		_status.text = "Pilih potongan yang sudah didapatkan di bawah terlebih dahulu."
		return
	if _selected_piece != slot:
		_status.text = "Bentuknya belum cocok. Coba tempat lain pada siluet."
		return
	var error := BlueprintProgress.place_piece(_selected_piece, slot)
	if error != OK:
		_status.text = "Potongan belum tersimpan. Coba lagi. " + error_string(error)
		return
	_selected_piece = -1
	_refresh()
	_slots[slot].grab_focus()


func _refresh() -> void:
	var complete := BlueprintProgress.is_complete()
	%Progress.text = "%s · %d / %d potongan terpasang" % [BlueprintProgress.PROJECT.title, BlueprintProgress.get_placed_count(), _slots.size()]
	var available := 0
	for index: int in _slots.size():
		var placed := BlueprintProgress.is_placed(index)
		_slots[index].silhouette = not placed
		_slots[index].accessibility_name = "Tempat %d, %s" % [index + 1, "terpasang" if placed else "kosong"]
		_slots[index].queue_redraw()
		_pieces[index].visible = BlueprintProgress.has_piece(index) and not placed
		_pieces[index].set_pressed_no_signal(index == _selected_piece)
		available += int(_pieces[index].visible)
	%Empty.visible = available == 0
	%Empty.text = "Semua potongan sudah terpasang." if complete else "Belajar untuk mendapatkan potongan blueprint."
	_status.text = "Blueprint selesai! Rancangan siap digunakan untuk kegiatan lab." if complete else "Pilih potongan, lalu pilih tempat yang sesuai pada siluet."
