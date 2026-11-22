extends Button

const Puzzle = preload("res://scripts/interaction/workshop/transmission_puzzle.gd")

signal card_selected(puzzle_id: String)
signal card_activated(puzzle_id: String)
signal drag_started(puzzle_id: String)

var puzzle: Puzzle
var source_id := 0
var completed := false
var active := false
var selected := false

var _title_label: Label
var _meta_label: Label
var _badge_label: Label
var _badge_panel: PanelContainer


func _init() -> void:
	custom_minimum_size = Vector2(0.0, 48.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	_build_content()


func _build_content() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 1)
	row.add_child(info)

	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(_title_label)

	_meta_label = Label.new()
	_meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meta_label.add_theme_font_size_override("font_size", 12)
	info.add_child(_meta_label)

	_badge_panel = PanelContainer.new()
	_badge_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_badge_panel)

	_badge_label = Label.new()
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_label.add_theme_font_size_override("font_size", 12)
	_badge_panel.add_child(_badge_label)


func _ready() -> void:
	pressed.connect(_on_pressed)
	refresh_visual()


func configure(target_puzzle: Puzzle, owner_source_id: int, is_completed: bool, is_active: bool, is_selected: bool) -> void:
	puzzle = target_puzzle
	source_id = owner_source_id
	completed = is_completed
	active = is_active
	selected = is_selected
	refresh_visual()


func refresh_visual() -> void:
	if puzzle == null:
		return
	_title_label.text = puzzle.title
	var slider_note := "  ·  Slider" if puzzle.slider_count() > 0 else ""
	_meta_label.text = "%s%s" % [puzzle.difficulty, slider_note]
	accessibility_name = "Blueprint %s, %s" % [puzzle.title, "Selesai" if completed else ("Aktif" if active else "Siap")]
	tooltip_text = "Seret ke Slot di atas atau tekan Enter"

	var badge_text := "Aktif" if active else ("Selesai" if completed else "Siap")
	_badge_label.text = badge_text

	var bg := Color("#16282c")
	var hover_bg := Color("#1d353b")
	var border := Color("#426066")
	var badge_bg := Color("#213c44")
	var badge_border := Color("#4e8496")
	var badge_text_color := Color("#cbe9f0")

	if active:
		bg = Color("#183439")
		hover_bg = Color("#204348")
		border = Color("#7bd4eb")
		badge_bg = Color("#204c56")
		badge_border = Color("#7bd4eb")
		badge_text_color = Color("#e2f8ff")
	elif completed:
		bg = Color("#132524")
		hover_bg = Color("#1a3230")
		border = Color("#549e72")
		badge_bg = Color("#1e4431")
		badge_border = Color("#59aa79")
		badge_text_color = Color("#cef2da")
	elif selected:
		bg = Color("#1b3238")
		hover_bg = Color("#223f46")
		border = Color("#ffe0a1")

	_title_label.add_theme_color_override("font_color", Color("#edf4f3"))
	_meta_label.add_theme_color_override("font_color", Color("#a9c0c2"))
	_badge_label.add_theme_color_override("font_color", badge_text_color)

	_apply_card_style("normal", bg, border, 2 if (selected or active) else 1)
	_apply_card_style("hover", hover_bg, border.lightened(0.18), 2 if (selected or active) else 1)
	_apply_card_style("pressed", hover_bg, Color("#ffe0a1"), 2)
	_apply_card_style("disabled", Color("#111b1d"), Color("#2c3c3e"), 1)

	var focus_style := StyleBoxFlat.new()
	focus_style.draw_center = false
	focus_style.border_color = Color("#ffe0a1")
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(4)
	add_theme_stylebox_override("focus", focus_style)

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = badge_bg
	badge_style.border_color = badge_border
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(3)
	badge_style.content_margin_left = 6.0
	badge_style.content_margin_right = 6.0
	badge_style.content_margin_top = 2.0
	badge_style.content_margin_bottom = 2.0
	_badge_panel.add_theme_stylebox_override("panel", badge_style)


func _apply_card_style(state: String, bg: Color, border: Color, border_width: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override(state, style)


func _on_pressed() -> void:
	if puzzle == null:
		return
	card_selected.emit(puzzle.puzzle_id)


func _gui_input(event: InputEvent) -> void:
	if disabled or puzzle == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		card_activated.emit(puzzle.puzzle_id)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if puzzle == null or disabled:
		return null
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_as_relative = false
	preview.z_index = 64
	preview.size = Vector2(160.0, 44.0)
	preview.draw.connect(_draw_drag_preview.bind(preview, puzzle.title, puzzle.difficulty))
	set_drag_preview(preview)
	drag_started.emit(puzzle.puzzle_id)
	return {"source": source_id, "type": "workshop_blueprint", "puzzle_id": puzzle.puzzle_id}


func _draw_drag_preview(canvas: CanvasItem, card_title: String, card_difficulty: String) -> void:
	var rect := Rect2(Vector2.ZERO, canvas.size)
	canvas.draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0.03, 0.06, 0.08, 0.45))
	canvas.draw_rect(rect, Color("#245262"))
	canvas.draw_rect(rect, Color("#89d8ed"), false, 2.0)
	canvas.draw_rect(Rect2(Vector2(6, 7), Vector2(rect.size.x - 12.0, 3.0)), Color("#bcebf4"))
	var font := get_theme_default_font()
	canvas.draw_string(font, Vector2(9, 25), card_title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 18.0, 13, Color("#f2fafb"))
	canvas.draw_string(font, Vector2(9, 38), card_difficulty, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 18.0, 10, Color("#bcebf4"))
