extends Node

signal notes_changed(assignment_id: String)
signal keyword_discovered(keyword_id: String)
const Note = preload("res://scripts/interaction/desktop/study/study_note.gd")
const Save = preload("res://scripts/autoload/playthrough_save.gd")
const BOOK_TEXTURE: Texture2D = preload("res://assets/textures/ui/study_notes_book.png")
const BOOK_FONT: Font = preload("res://assets/fonts/pixelify_sans/PixelifySans-SemiBold.ttf")
const SAVE_PATH := "user://study_notes.cfg"
const BOOK_ASPECT := 390.0 / 300.0
const INK_TITLE := Color("#241c18")
const INK_BODY := Color("#2f2620")
const INK_MUTED := Color("#665649")
const ITEMS_PER_PAGE := 2

@export var entries: Array[Note]

var _unlocked := PackedStringArray()
var _studied_books := PackedStringArray()
var _keywords := PackedStringArray()

var _book_layer: CanvasLayer
var _book_root: Control
var _book_frame: Control
var _book_texture: TextureRect
var _left_page: VBoxContainer
var _right_page: VBoxContainer
var _left_entries: VBoxContainer
var _right_entries: VBoxContainer
var _left_header: Label
var _page_indicator: Label
var _prev_btn: Button
var _next_btn: Button
var _close_btn: Button
var _previous_focus: Control
var _context_semester: int = 0
var _spread_index: int = 0
var _cached_items: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reload_progress()
	_build_book_overlay()


func is_book_open() -> bool:
	return is_instance_valid(_book_layer) and _book_layer.visible


func toggle_book(context_semester: int = 0) -> void:
	if is_book_open():
		close_book()
	else:
		open_book(context_semester)


func open_book(context_semester: int = 0) -> void:
	if not is_instance_valid(_book_layer):
		_build_book_overlay()
	_context_semester = context_semester
	_spread_index = 0
	var vp := get_viewport()
	if vp != null:
		_previous_focus = vp.gui_get_focus_owner()
	_collect_book_items()
	_fit_book()
	_render_spread()
	_book_layer.show()
	if is_instance_valid(_close_btn):
		_close_btn.grab_focus.call_deferred()


func close_book() -> void:
	if not is_instance_valid(_book_layer) or not _book_layer.visible:
		return
	_book_layer.hide()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus.call_deferred()
	_previous_focus = null


func _input(event: InputEvent) -> void:
	if not is_book_open():
		return
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if key.keycode == KEY_TAB or key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if not key.echo:
				close_book()
		elif key.keycode == KEY_LEFT and not key.echo:
			get_viewport().set_input_as_handled()
			_turn_spread(-1)
		elif key.keycode == KEY_RIGHT and not key.echo:
			get_viewport().set_input_as_handled()
			_turn_spread(1)


func _build_book_overlay() -> void:
	if is_instance_valid(_book_layer):
		return
	_book_layer = CanvasLayer.new()
	_book_layer.name = &"StudyNotesBookLayer"
	_book_layer.layer = 60
	_book_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_book_layer.visible = false
	add_child(_book_layer)

	_book_root = Control.new()
	_book_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_book_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_book_layer.add_child(_book_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.05, 0.06, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_book_root.add_child(dim)

	_book_frame = Control.new()
	_book_frame.name = &"BookFrame"
	_book_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_book_root.add_child(_book_frame)

	_book_texture = TextureRect.new()
	_book_texture.name = &"BookTexture"
	_book_texture.texture = BOOK_TEXTURE
	_book_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_book_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_book_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_book_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_book_frame.add_child(_book_texture)

	# Left cream page strictly inside (X: 0.095..0.425, Y: 0.080..0.815) — never touches brown border or spine.
	_left_page = VBoxContainer.new()
	_left_page.name = &"LeftPage"
	_left_page.clip_contents = true
	_left_page.anchor_left = 0.095
	_left_page.anchor_right = 0.425
	_left_page.anchor_top = 0.080
	_left_page.anchor_bottom = 0.815
	_left_page.add_theme_constant_override("separation", 6)
	_book_frame.add_child(_left_page)

	_left_header = _book_label(_left_page, "Buku Catatan", 15, INK_TITLE)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left_page.add_child(left_scroll)

	_left_entries = VBoxContainer.new()
	_left_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_entries.add_theme_constant_override("separation", 8)
	left_scroll.add_child(_left_entries)

	# Right cream page strictly inside (X: 0.575..0.905, Y: 0.080..0.815) — never touches brown border or spine.
	_right_page = VBoxContainer.new()
	_right_page.name = &"RightPage"
	_right_page.clip_contents = true
	_right_page.anchor_left = 0.575
	_right_page.anchor_right = 0.905
	_right_page.anchor_top = 0.080
	_right_page.anchor_bottom = 0.815
	_right_page.add_theme_constant_override("separation", 6)
	_book_frame.add_child(_right_page)

	var right_top := HBoxContainer.new()
	right_top.alignment = BoxContainer.ALIGNMENT_END
	_right_page.add_child(right_top)

	_page_indicator = _book_label(right_top, "", 12, INK_MUTED)
	_page_indicator.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_close_btn = _book_button("[Tab] Tutup ×", close_book)
	_close_btn.name = &"CloseBookButton"
	right_top.add_child(_close_btn)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_page.add_child(right_scroll)

	_right_entries = VBoxContainer.new()
	_right_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_entries.add_theme_constant_override("separation", 8)
	right_scroll.add_child(_right_entries)

	var nav_row := HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_END
	nav_row.add_theme_constant_override("separation", 6)
	_right_page.add_child(nav_row)

	_prev_btn = _book_button("◀ Hal", _turn_spread.bind(-1))
	_next_btn = _book_button("Hal ▶", _turn_spread.bind(1))
	nav_row.add_child(_prev_btn)
	nav_row.add_child(_next_btn)

	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_fit_book, CONNECT_DEFERRED)


func _book_label(parent: Node, text_val: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text_val
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", BOOK_FONT)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl


func _book_button(caption: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", BOOK_FONT)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", INK_TITLE)
	btn.add_theme_color_override("font_hover_color", Color("#000000"))
	btn.add_theme_color_override("font_disabled_color", Color("#9a8b7d"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.86, 0.80, 0.70, 0.72)
	normal.border_color = Color("#7a6552")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 7
	normal.content_margin_right = 7
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.79, 0.71, 0.59, 0.92)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", normal)
	btn.pressed.connect(action)
	return btn


func _fit_book() -> void:
	if not is_instance_valid(_book_frame) or get_viewport() == null:
		return
	var view_size := get_viewport().get_visible_rect().size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = Vector2(1280.0, 720.0)
	var max_w := clampf(view_size.x * 0.86, 360.0, 780.0)
	var max_h := clampf(view_size.y * 0.82, 277.0, 600.0)
	var book_w := minf(max_w, max_h * BOOK_ASPECT)
	var book_h := book_w / BOOK_ASPECT
	_book_frame.size = Vector2(floorf(book_w), floorf(book_h))
	_book_frame.position = ((view_size - _book_frame.size) * 0.5).floor()


func _collect_book_items() -> void:
	_cached_items.clear()
	var career := get_node_or_null("/root/CareerProgress")
	if career != null and career.has_method("class_journal_entries"):
		var raw_entries: Array = career.call("class_journal_entries")
		var prioritized: Array[Dictionary] = []
		var others: Array[Dictionary] = []
		for item: Variant in raw_entries:
			if item is Dictionary:
				var entry := item as Dictionary
				var sem := int(entry.get("semester", 0))
				var card := {
					"heading": "Sem %d · H%d — %s" % [sem, int(entry.get("week", 0)), str(entry.get("title", ""))],
					"body": str(entry.get("body", "")),
				}
				if _context_semester > 0 and sem == _context_semester:
					prioritized.append(card)
				else:
					others.append(card)
		_cached_items.append_array(prioritized)
		_cached_items.append_array(others)
	for note: Note in entries:
		if note != null and note.note_id in _unlocked:
			_cached_items.append({
				"heading": "Catatan Perpustakaan",
				"body": note.notebook_text,
			})


func _total_spreads() -> int:
	var per_spread := ITEMS_PER_PAGE * 2
	return maxi(1, ceili(float(_cached_items.size()) / float(per_spread)))


func _turn_spread(delta: int) -> void:
	var next := clampi(_spread_index + delta, 0, _total_spreads() - 1)
	if next != _spread_index:
		_spread_index = next
		_render_spread()


func _render_spread() -> void:
	for box: VBoxContainer in [_left_entries, _right_entries]:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()

	_left_header.text = "Catatan Sem %d" % _context_semester if _context_semester > 0 else "Buku Catatan"
	var total := _total_spreads()
	_spread_index = clampi(_spread_index, 0, total - 1)
	_page_indicator.text = "Hal %d/%d" % [_spread_index + 1, total]
	_prev_btn.visible = total > 1
	_next_btn.visible = total > 1
	_prev_btn.disabled = _spread_index <= 0
	_next_btn.disabled = _spread_index >= total - 1

	if _cached_items.is_empty():
		_book_label(_left_entries, "Belum ada catatan kelas yang terbuka.", 13, INK_BODY)
		_book_label(_left_entries, "Ikuti kelas atau buka Perpustakaan di PC untuk mengisi catatan ringkas jawaban kuis & ujian.", 12, INK_MUTED)
		return

	var base := _spread_index * ITEMS_PER_PAGE * 2
	for offset: int in range(ITEMS_PER_PAGE):
		var idx := base + offset
		if idx < _cached_items.size():
			_add_book_entry(_left_entries, _cached_items[idx])
	for offset: int in range(ITEMS_PER_PAGE):
		var idx := base + ITEMS_PER_PAGE + offset
		if idx < _cached_items.size():
			_add_book_entry(_right_entries, _cached_items[idx])


func _add_book_entry(container: VBoxContainer, item: Dictionary) -> void:
	_book_label(container, str(item.get("heading", "")), 13, INK_TITLE)
	_book_label(container, str(item.get("body", "")), 12, INK_BODY)


func get_book_frame_rect() -> Rect2:
	return _book_frame.get_global_rect() if is_instance_valid(_book_frame) else Rect2()


func get_left_page_rect() -> Rect2:
	return _left_page.get_global_rect() if is_instance_valid(_left_page) else Rect2()


func get_right_page_rect() -> Rect2:
	return _right_page.get_global_rect() if is_instance_valid(_right_page) else Rect2()


func reload_progress() -> void:
	var saved := Save.load_config(SAVE_PATH)
	_unlocked = _load_ids(saved, "notebook", "unlocked_ids")
	_studied_books = _load_ids(saved, "library", "studied_books")
	_keywords = _load_ids(saved, "library", "discovered_keywords")


func _load_ids(config: ConfigFile, section: String, key: String) -> PackedStringArray:
	var ids: Variant = config.get_value(section, key, PackedStringArray())
	return ids if ids is PackedStringArray else PackedStringArray()


func unlock_note(note_id: String) -> Error:
	return _unlock_notes(PackedStringArray([note_id]))


func get_unlocked_entries(assignment_id: String) -> Array[Note]:
	var unlocked_entries: Array[Note] = []
	for note: Note in _entries_for(assignment_id):
		if note.note_id in _unlocked:
			unlocked_entries.append(note)
	return unlocked_entries


func is_complete(assignment_id: String) -> bool:
	var notes := _entries_for(assignment_id)
	return not notes.is_empty() and get_unlocked_entries(assignment_id).size() == notes.size()


func fill_assignment(assignment_id: String) -> Error:
	var ids := PackedStringArray()
	for note: Note in _entries_for(assignment_id):
		ids.append(note.note_id)
	if ids.is_empty():
		return ERR_DOES_NOT_EXIST
	return _unlock_notes(ids)


func is_book_studied(book_id: String, note_ids: PackedStringArray) -> bool:
	if book_id in _studied_books:
		return true
	if note_ids.is_empty():
		return false
	for id: String in note_ids:
		if id not in _unlocked:
			return false
	return true


func study_book(book_id: String, note_ids: PackedStringArray) -> Error:
	if book_id.is_empty():
		return ERR_INVALID_PARAMETER
	if is_book_studied(book_id, note_ids):
		return OK
	return _unlock_notes(note_ids, book_id)


func has_keyword(keyword_id: String) -> bool:
	return keyword_id in _keywords


func discover_keyword(keyword_id: String) -> Error:
	if keyword_id.is_empty():
		return ERR_INVALID_PARAMETER
	if has_keyword(keyword_id):
		return OK
	var keywords := _keywords.duplicate()
	keywords.append(keyword_id)
	var error := _save(_unlocked, _studied_books, keywords)
	if error == OK:
		_keywords = keywords
		keyword_discovered.emit(keyword_id)
	return error


func _entries_for(assignment_id: String) -> Array[Note]:
	var notes: Array[Note] = []
	for note: Note in entries:
		if note != null and note.assignment_id == assignment_id and not note.note_id.is_empty():
			notes.append(note)
	return notes


func _unlock_notes(note_ids: PackedStringArray, book_id: String = "") -> Error:
	var unlocked := _unlocked.duplicate()
	var affected := PackedStringArray()
	for id: String in note_ids:
		var found := false
		for note: Note in entries:
			if note != null and not id.is_empty() and note.note_id == id:
				found = true
				if id not in unlocked:
					unlocked.append(id)
					if note.assignment_id not in affected:
						affected.append(note.assignment_id)
				break
		if not found:
			return ERR_DOES_NOT_EXIST
	var books := _studied_books.duplicate()
	if not book_id.is_empty() and book_id not in books:
		books.append(book_id)
	if unlocked == _unlocked and books == _studied_books:
		return OK
	var error := _save(unlocked, books, _keywords)
	if error != OK:
		return error
	_unlocked = unlocked
	_studied_books = books
	for assignment_id: String in affected:
		notes_changed.emit(assignment_id)
	return OK


func _save(unlocked: PackedStringArray, books: PackedStringArray, keywords: PackedStringArray) -> Error:
	var config := Save.load_config(SAVE_PATH)
	config.set_value("notebook", "unlocked_ids", unlocked)
	config.set_value("library", "studied_books", books)
	config.set_value("library", "discovered_keywords", keywords)
	return Save.write_config(config, SAVE_PATH)
