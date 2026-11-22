extends PanelContainer

var _values: Array[Label] = []
var _bars: Array[ProgressBar] = []


func _ready() -> void:
	add_theme_stylebox_override("panel", _style(Color("#18262ce8"), 8))
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 5)
	add_child(rows)
	_add_stat(rows, "Energi", PlayerStats.ENERGY_MAX, Color("#f2c46d"))
	_add_stat(rows, "Kewarasan", PlayerStats.SANITY_MAX, Color("#80c8ac"))
	_add_stat(rows, "IPK", PlayerStats.GPA_MAX, Color("#91bde9"))
	PlayerStats.changed.connect(_refresh)
	_refresh()


func _add_stat(rows: VBoxContainer, title: String, maximum: float, fill: Color) -> void:
	var group := VBoxContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_theme_constant_override("separation", 2)
	rows.add_child(group)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(heading)
	var caption := Label.new()
	caption.text = title
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_theme_font_size_override("font_size", 14)
	heading.add_child(caption)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 14)
	heading.add_child(value)
	_values.append(value)
	var meter := ProgressBar.new()
	meter.max_value = maximum
	meter.step = 0.0
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.custom_minimum_size.y = 5
	meter.add_theme_stylebox_override("background", _style(Color("#435358"), 0))
	meter.add_theme_stylebox_override("fill", _style(fill, 0))
	group.add_child(meter)
	_bars.append(meter)


func _style(color: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(padding)
	style.set_corner_radius_all(3)
	return style


func _refresh() -> void:
	_bars[0].value = PlayerStats.get_energy()
	_bars[1].value = PlayerStats.get_sanity()
	_bars[2].value = PlayerStats.get_gpa()
	_values[0].text = "%d/100" % roundi(_bars[0].value)
	_values[1].text = "%d/100" % roundi(_bars[1].value)
	_values[2].text = "%.2f/4.00" % _bars[2].value
