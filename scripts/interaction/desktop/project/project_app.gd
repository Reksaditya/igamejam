extends PanelContainer

const Blueprint = preload("res://scripts/interaction/desktop/project/blueprint.gd")
const BlueprintState = preload("res://scripts/interaction/desktop/project/blueprint_progress.gd").State

@export var blueprints: Array[Blueprint]
@export var demo_blueprints := false


class BlueprintEntry extends RefCounted:
	var blueprint: Blueprint
	var title: Label
	var badge: PanelContainer
	var badge_label: Label
	var drawing: TextureRect
	var locked_frame: PanelContainer
	var note: Label


var _entries: Dictionary[String, BlueprintEntry] = {}
var _drawings: Dictionary[String, TextureRect] = {}


func _ready() -> void:
	for blueprint: Blueprint in blueprints:
		if blueprint == null or not blueprint.blueprint_id.is_valid_identifier() or blueprint.artwork == null:
			continue
		if not _entries.has(blueprint.blueprint_id):
			_add_blueprint(blueprint)
	%Empty.visible = _entries.is_empty()
	ProjectBlueprints.changed.connect(_refresh)
	_refresh()


func _add_blueprint(blueprint: Blueprint) -> void:
	if not _entries.is_empty():
		var divider := HSeparator.new()
		divider.modulate = Color(0.7, 0.78, 0.84, 0.7)
		%Drawings.add_child(divider)

	var entry := BlueprintEntry.new()
	entry.blueprint = blueprint

	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 8)
	%Drawings.add_child(group)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	group.add_child(header)

	var title := Label.new()
	title.text = blueprint.title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#1b3346"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title)
	entry.title = title

	var badge := PanelContainer.new()
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(badge)
	entry.badge = badge

	var badge_label := Label.new()
	badge_label.add_theme_font_size_override("font_size", 12)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(badge_label)
	entry.badge_label = badge_label

	var locked_frame := PanelContainer.new()
	locked_frame.custom_minimum_size.y = 112.0
	locked_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	locked_frame.add_theme_stylebox_override("panel", _make_locked_style())
	group.add_child(locked_frame)
	entry.locked_frame = locked_frame

	var locked_box := VBoxContainer.new()
	locked_box.alignment = BoxContainer.ALIGNMENT_CENTER
	locked_box.add_theme_constant_override("separation", 4)
	locked_frame.add_child(locked_box)

	var locked_heading := Label.new()
	locked_heading.text = "Blueprint belum terbuka"
	locked_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locked_heading.add_theme_font_size_override("font_size", 14)
	locked_heading.add_theme_color_override("font_color", Color("#4a6070"))
	locked_box.add_child(locked_heading)

	var locked_hint := Label.new()
	locked_hint.text = "Dapatkan blueprint ini dengan menyelesaikan catatan kelas atau membuka bukunya di Perpustakaan."
	locked_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locked_hint.add_theme_font_size_override("font_size", 12)
	locked_hint.add_theme_color_override("font_color", Color("#5c7384"))
	locked_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	locked_box.add_child(locked_hint)

	var drawing := TextureRect.new()
	drawing.texture = blueprint.artwork
	drawing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	drawing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drawing.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drawing.custom_minimum_size.y = 210.0
	drawing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawing.accessibility_name = "Blueprint " + blueprint.title
	group.add_child(drawing)
	entry.drawing = drawing
	_drawings[blueprint.blueprint_id] = drawing

	var note := Label.new()
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color("#314d60"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group.add_child(note)
	entry.note = note

	_entries[blueprint.blueprint_id] = entry


func _refresh() -> void:
	for blueprint_id: String in _entries:
		var entry := _entries[blueprint_id]
		var state: int = ProjectBlueprints.get_state(blueprint_id, entry.blueprint.workshop_puzzle_id)
		if demo_blueprints and state == BlueprintState.LOCKED:
			state = BlueprintState.UNLOCKED
		var unlocked := state != BlueprintState.LOCKED
		entry.drawing.visible = unlocked
		entry.locked_frame.visible = not unlocked
		entry.note.visible = unlocked
		entry.title.add_theme_color_override("font_color", Color("#1b3346") if unlocked else Color("#5c707e"))
		match state:
			BlueprintState.LOCKED:
				_apply_badge(entry, "Terkunci", Color("#e3eaee"), Color("#a5b7c2"), Color("#4b6170"))
			BlueprintState.UNLOCKED:
				_apply_badge(entry, "Terbuka", Color("#d8ecf7"), Color("#4b90b3"), Color("#164b68"))
				entry.note.text = "Siap dibawa ke meja rakit."
			BlueprintState.WORKED:
				_apply_badge(entry, "Dikerjakan", Color("#f8ead0"), Color("#cf913a"), Color("#75480d"))
				entry.note.text = "Sedang dikerjakan di meja rakit."
			BlueprintState.COMPLETED:
				_apply_badge(entry, "Selesai", Color("#d6efe0"), Color("#499d6a"), Color("#195732"))
				entry.note.text = "Sudah dirakit dan teruji di meja rakit."


func _apply_badge(entry: BlueprintEntry, caption: String, fill: Color, border: Color, text_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	entry.badge.add_theme_stylebox_override("panel", style)
	entry.badge_label.text = caption
	entry.badge_label.add_theme_color_override("font_color", text_color)


func _make_locked_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#e8eff3")
	style.border_color = Color("#bfd0da")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style
