extends VBoxContainer

const DRAWING := preload("res://assets/textures/transmission_blueprint.svg")

var _term: OptionButton
var _summary: Label
var _slots: GridContainer
var _pieces: GridContainer
var _selected: int = -1


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_term = OptionButton.new()
	for term: int in range(1, CareerProgress.semester() + 1):
		_term.add_item("Blueprint mesin · Semester %d" % term, term)
	_term.select(_term.item_count - 1)
	_term.item_selected.connect(func(_index: int):
		_selected = -1
		_refresh()
	)
	add_child(_term)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary)
	_slots = GridContainer.new()
	_slots.columns = 3
	add_child(_slots)
	var title := Label.new()
	title.text = "Potongan diperoleh dari catatan lengkap / Library. Pilih potongan, lalu pilih posisi pada siluet."
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(title)
	_pieces = GridContainer.new()
	_pieces.columns = 3
	add_child(_pieces)
	CareerProgress.changed.connect(_refresh)
	_refresh()


func _texture(index: int) -> AtlasTexture:
	var tile := AtlasTexture.new()
	tile.atlas = DRAWING
	var cell := DRAWING.get_size() / 3.0
	tile.region = Rect2(Vector2(index % 3, floori(index / 3.0)) * cell, cell)
	return tile


func _refresh() -> void:
	for grid: GridContainer in [_slots, _pieces]:
		for child: Node in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	var term := _term.get_selected_id()
	var placed: Array = CareerProgress.state.placed.get(str(term), [])
	var pieces: Array = CareerProgress.state.pieces.get(str(term), [])
	_summary.text = "%d/9 potongan · %d/9 terpasang%s" % [pieces.size(), placed.size(), " · Blueprint siap untuk bengkel" if placed.size() == 9 else ""]
	for index: int in 9:
		var slot := Button.new()
		slot.icon = _texture(index)
		slot.expand_icon = true
		slot.custom_minimum_size = Vector2(100, 80)
		slot.modulate = Color.WHITE if placed.has(index) else Color(0.24, 0.32, 0.38)
		slot.tooltip_text = "Posisi %d" % (index + 1)
		slot.pressed.connect(_place.bind(index))
		_slots.add_child(slot)
	var order := pieces.duplicate()
	order.reverse()
	for index: int in order:
		if placed.has(index):
			continue
		var piece := Button.new()
		piece.icon = _texture(index)
		piece.expand_icon = true
		piece.custom_minimum_size = Vector2(100, 80)
		piece.text = "✓" if index == _selected else ""
		piece.pressed.connect(_select.bind(index))
		_pieces.add_child(piece)


func _select(index: int) -> void:
	_selected = index
	_refresh()


func _place(slot: int) -> void:
	if _selected < 0:
		return
	var error := CareerProgress.place_piece(_term.get_selected_id(), _selected, slot)
	if error == OK:
		_selected = -1
		_refresh()
	else:
		_summary.text = "Potongan belum cocok dengan posisi siluet ini."
