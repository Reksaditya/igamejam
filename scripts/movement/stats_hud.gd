extends PanelContainer

const ICON_ENERGY: Texture2D = preload("res://assets/textures/hud/icon_energy_pixel.png")
const ICON_SANITY: Texture2D = preload("res://assets/textures/hud/icon_sanity_pixel.png")
const ICON_GPA: Texture2D = preload("res://assets/textures/hud/icon_gpa_pixel.png")
const VALUE_FONT: Font = preload("res://assets/fonts/pixelify_sans/PixelifySans-SemiBold.ttf")

var _pills: Array[PanelContainer] = []
var _values: Array[Label] = []
var _bars: Array[ProgressBar] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 9)
	add_child(rows)
	_add_stat(rows, ICON_ENERGY, PlayerStats.ENERGY_MAX, Color("#f2c46d"))
	_add_stat(rows, ICON_SANITY, PlayerStats.SANITY_MAX, Color("#80c8ac"))
	_add_stat(rows, ICON_GPA, PlayerStats.GPA_MAX, Color("#91bde9"))
	PlayerStats.changed.connect(_refresh)
	_refresh()


func _add_stat(rows: VBoxContainer, icon: Texture2D, maximum: float, fill: Color) -> void:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", _pill_style(fill))
	rows.add_child(pill)
	_pills.append(pill)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	pill.add_child(row)

	var glyph := TextureRect.new()
	glyph.texture = icon
	glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glyph.custom_minimum_size = Vector2(24, 24)
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)

	var meter := ProgressBar.new()
	meter.max_value = maximum
	meter.step = 0.0
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.custom_minimum_size = Vector2(146, 14)
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.add_theme_stylebox_override("background", _track_style())
	meter.add_theme_stylebox_override("fill", _fill_style(fill))
	row.add_child(meter)
	_bars.append(meter)

	var value := Label.new()
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.custom_minimum_size.x = 68.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_override("font", VALUE_FONT)
	value.add_theme_font_size_override("font_size", 15)
	value.add_theme_color_override("font_color", Color("#f2f6f8"))
	row.add_child(value)
	_values.append(value)


func _pill_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#121c22e0")
	style.border_color = Color(accent.lerp(Color("#6b828e"), 0.55), 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_size = 4
	style.content_margin_left = 8.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1216eb")
	style.border_color = Color("#3b4f5a80")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	return style


func _fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(7)
	return style


func _refresh() -> void:
	var energy := PlayerStats.get_energy()
	var sanity := PlayerStats.get_sanity()
	var gpa := PlayerStats.get_gpa()
	_bars[0].value = energy
	_bars[1].value = sanity
	_bars[2].value = gpa
	_values[0].text = "%d/100" % roundi(energy)
	_values[1].text = "%d/100" % roundi(sanity)
	_values[2].text = "%.2f/4.00" % gpa
	var summaries := PackedStringArray([
		"Energi: %s" % _values[0].text,
		"Kewarasan: %s" % _values[1].text,
		"IPK: %s" % _values[2].text,
	])
	for index: int in range(_pills.size()):
		_pills[index].tooltip_text = summaries[index]
		_pills[index].accessibility_name = summaries[index]
