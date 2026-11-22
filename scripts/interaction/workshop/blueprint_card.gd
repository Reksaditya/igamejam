extends Button

const Puzzle = preload("res://scripts/interaction/workshop/transmission_puzzle.gd")
const CARD_MIN_SIZE := Vector2(96.0, 68.0)

signal card_selected(puzzle_id: String)
signal card_activated(puzzle_id: String)
signal drag_started(puzzle_id: String)

var puzzle: Puzzle
var artwork: Texture2D
var source_id := 0
var completed := false
var active := false
var selected := false

var _artwork_rect: TextureRect
var _fallback_preview: Control
var _status_badge: PanelContainer
var _status_icon: Label


func _init() -> void:
	custom_minimum_size = CARD_MIN_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	_build_content()


func _build_content() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 5)
	add_child(margin)

	_artwork_rect = TextureRect.new()
	_artwork_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_artwork_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_artwork_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_artwork_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_artwork_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_artwork_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_artwork_rect)

	_fallback_preview = Control.new()
	_fallback_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fallback_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fallback_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fallback_preview.visible = false
	_fallback_preview.draw.connect(_draw_fallback_blueprint.bind(_fallback_preview))
	margin.add_child(_fallback_preview)

	_status_badge = PanelContainer.new()
	_status_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_status_badge.offset_left = -22.0
	_status_badge.offset_top = 4.0
	_status_badge.offset_right = -4.0
	_status_badge.offset_bottom = 22.0
	_status_badge.visible = false
	add_child(_status_badge)

	_status_icon = Label.new()
	_status_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_badge.add_child(_status_icon)


func _ready() -> void:
	pressed.connect(_on_pressed)
	refresh_visual()


func configure(target_puzzle: Puzzle, target_artwork: Texture2D, owner_source_id: int, is_completed: bool, is_active: bool, is_selected: bool) -> void:
	puzzle = target_puzzle
	artwork = target_artwork
	source_id = owner_source_id
	completed = is_completed
	active = is_active
	selected = is_selected
	refresh_visual()


func refresh_visual() -> void:
	if puzzle == null:
		return
	_artwork_rect.texture = artwork
	_artwork_rect.visible = artwork != null
	_fallback_preview.visible = artwork == null
	if _fallback_preview.visible:
		_fallback_preview.queue_redraw()

	accessibility_name = "Blueprint %s, %s" % [puzzle.title, "Selesai" if completed else ("Aktif" if active else "Siap")]
	tooltip_text = "%s (%s) — Seret ke Slot atau tekan Enter" % [puzzle.title, puzzle.difficulty]

	var bg := Color("#143040")
	var hover_bg := Color("#1c4257")
	var border := Color("#4e7c90")

	if active:
		bg = Color("#183e4e")
		hover_bg = Color("#215165")
		border = Color("#7bd4eb")
	elif completed:
		bg = Color("#143030")
		hover_bg = Color("#1b3f3e")
		border = Color("#59aa79")
	elif selected:
		bg = Color("#183a4d")
		hover_bg = Color("#204b63")
		border = Color("#ffe0a1")

	_apply_card_style("normal", bg, border, 2 if (selected or active) else 1)
	_apply_card_style("hover", hover_bg, border.lightened(0.18), 2 if (selected or active) else 1)
	_apply_card_style("pressed", hover_bg, Color("#ffe0a1"), 2)
	_apply_card_style("disabled", Color("#112028"), Color("#2c414d"), 1)

	var focus_style := StyleBoxFlat.new()
	focus_style.draw_center = false
	focus_style.border_color = Color("#ffe0a1")
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(4)
	add_theme_stylebox_override("focus", focus_style)

	_update_status_badge()


func _update_status_badge() -> void:
	if not completed and not active:
		_status_badge.visible = false
		return
	_status_badge.visible = true
	_status_icon.text = "✓" if completed else "●"
	_status_icon.add_theme_font_size_override("font_size", 12 if completed else 10)
	_status_icon.add_theme_color_override("font_color", Color("#cef2da") if completed else Color("#dff8ff"))
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("#1e4431") if completed else Color("#1c4b59")
	badge_style.border_color = Color("#59aa79") if completed else Color("#7bd4eb")
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(3)
	badge_style.content_margin_left = 4.0
	badge_style.content_margin_right = 4.0
	badge_style.content_margin_top = 0.0
	badge_style.content_margin_bottom = 0.0
	_status_badge.add_theme_stylebox_override("panel", badge_style)


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
	elif event.is_action_pressed("ui_accept"):
		card_activated.emit(puzzle.puzzle_id)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if puzzle == null or disabled:
		return null
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_as_relative = false
	preview.z_index = 64

	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = Vector2(116.0, 82.0)
	frame.position = Vector2(-58.0, -41.0)
	frame.modulate = Color(1.0, 1.0, 1.0, 0.90)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#183a4d")
	style.border_color = Color("#89d8ed")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(5)
	style.shadow_color = Color(0.03, 0.06, 0.08, 0.5)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 3)
	frame.add_theme_stylebox_override("panel", style)
	preview.add_child(frame)

	if artwork != null:
		var thumb := TextureRect.new()
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		thumb.texture = artwork
		frame.add_child(thumb)
	else:
		var fallback := Control.new()
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fallback.size_flags_vertical = Control.SIZE_EXPAND_FILL
		fallback.draw.connect(_draw_fallback_blueprint.bind(fallback))
		frame.add_child(fallback)

	set_drag_preview(preview)
	drag_started.emit(puzzle.puzzle_id)
	return {"source": source_id, "type": "workshop_blueprint", "puzzle_id": puzzle.puzzle_id}


func _draw_fallback_blueprint(canvas: Control) -> void:
	var rect := Rect2(Vector2.ZERO, canvas.size)
	canvas.draw_rect(rect, Color("#1f4d66"))
	canvas.draw_rect(rect.grow(-2.0), Color("#739baa"), false, 1.0)
	var center := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.24
	canvas.draw_arc(center, r, 0.0, TAU, 16, Color("#e4f1f1"), 2.0, true)
	canvas.draw_circle(center, r * 0.32, Color("#739baa"))
