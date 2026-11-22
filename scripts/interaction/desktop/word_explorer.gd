extends MarginContainer

signal exam_mode_changed(active: bool)

const Route = preload("res://scripts/interaction/desktop/browser_route.gd")
const TabDefinition = preload("res://scripts/interaction/desktop/browser_tab.gd")
const PAGE_SCENE := preload("res://scenes/interaction/desktop/browser_page.tscn")
const ICON_GLOBE: Texture2D = preload("res://assets/textures/desktop/icon_browser.png")
const ICON_BOOK: Texture2D = preload("res://assets/textures/desktop/icon_book.png")
const TAB_FONT: Font = preload("res://assets/fonts/pixelify_sans/PixelifySans-Medium.ttf")
const DISPLAY_FONT: Font = preload("res://assets/fonts/pixelify_sans/PixelifySans-SemiBold.ttf")

const LMS_ADDRESS := "www.redlineuni.com"
const OLD_LMS_ADDRESS := "www.homeworkplace.com"

const TAB_INK := Color("#17273b")
const TAB_MUTED_INK := Color("#394b61")


class Tab:
	var address := ""
	var draft := ""
	var title := "New tab"
	var history := PackedStringArray()
	var history_index := -1
	var container: PanelContainer
	var favicon: TextureRect
	var button: Button
	var close: Button
	var pane: PanelContainer
	var scroll: ScrollContainer
	var page: MarginContainer
	var timer: Timer
	var pending: PackedScene


@export var home_address: String = LMS_ADDRESS
@export var default_tabs: Array[TabDefinition]
@export_range(0, 20, 1, "or_greater") var start_tab := 0
@export var local_routes: Array[Route]
@export_range(0.0, 10.0, 0.05, "or_greater") var loading_seconds: float = 0.55

var _tabs: Array[Tab] = []
var _active: Tab
var _exam_active := false
var _attachment_provider: Callable
var _exam_host: Control

@onready var _address: LineEdit = %Address
@onready var _go: Button = %Go
@onready var _home: Button = %Home
@onready var _back: Button = %Back
@onready var _forward: Button = %Forward
@onready var _reload: Button = %Reload
@onready var _site_icon: TextureRect = %SiteIcon
@onready var _menu: MenuButton = %BrowserMenu


func _ready() -> void:
	_setup_browser_menu()
	_address.focus_entered.connect(_address.edit)
	_address.text_changed.connect(_remember_draft)
	_address.text_submitted.connect(_navigate)
	_go.pressed.connect(func() -> void: _navigate(_address.text))
	_home.pressed.connect(func() -> void: _navigate(home_address))
	_back.pressed.connect(_go_back)
	_forward.pressed.connect(_go_forward)
	_reload.pressed.connect(_reload_active)
	%NewTab.pressed.connect(_open_new_tab)

	%NewTab.draw.connect(_draw_tab_action.bind(%NewTab, true))
	_back.draw.connect(_draw_arrow_glyph.bind(_back, true))
	_forward.draw.connect(_draw_arrow_glyph.bind(_forward, false))
	_reload.draw.connect(_draw_reload_glyph.bind(_reload))
	_home.draw.connect(_draw_home_glyph.bind(_home))

	for definition: TabDefinition in default_tabs:
		if definition != null:
			var tab := _add_tab(definition.title)
			_load_address(tab, definition.address, true)
	if _tabs.is_empty():
		_open_new_tab()
	else:
		_select_tab(_tabs[clampi(start_tab, 0, _tabs.size() - 1)])


func set_attachment_provider(provider: Callable) -> void:
	_attachment_provider = provider


func set_exam_host(host: Control) -> void:
	_exam_host = host


func _setup_browser_menu() -> void:
	var popup := _menu.get_popup()
	popup.clear()
	popup.add_item("New Tab", 0)
	popup.add_item("Home", 1)
	popup.add_separator()
	popup.add_item("Perpustakaan", 2)
	popup.add_item("LMS", 3)
	popup.id_pressed.connect(_on_browser_menu_selected)


func _on_browser_menu_selected(id: int) -> void:
	if _exam_active:
		return
	match id:
		0:
			_open_new_tab()
		1:
			_navigate(home_address)
		2:
			_navigate("www.placetostudy.com")
		3:
			_navigate(home_address)


func _open_new_tab() -> void:
	if _exam_active:
		return
	var tab := _add_tab("New tab")
	_select_tab(tab)
	_show_start_page(tab)
	_address.grab_focus()


func _add_tab(title: String) -> Tab:
	var tab := Tab.new()
	tab.title = title
	tab.pane = PAGE_SCENE.instantiate() as PanelContainer
	tab.pane.hide()
	%PageHost.add_child(tab.pane)
	tab.scroll = tab.pane.get_node("Scroll")
	tab.page = tab.scroll.get_node("Page")
	tab.timer = Timer.new()
	tab.timer.one_shot = true
	tab.timer.ignore_time_scale = true
	tab.pane.add_child(tab.timer)
	tab.timer.timeout.connect(_finish_navigation.bind(tab))

	tab.container = PanelContainer.new()
	tab.container.mouse_filter = Control.MOUSE_FILTER_PASS
	%Tabs.add_child(tab.container)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	tab.container.add_child(row)

	tab.favicon = TextureRect.new()
	tab.favicon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tab.favicon.custom_minimum_size = Vector2(14, 14)
	tab.favicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tab.favicon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tab.favicon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tab.favicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.favicon.texture = ICON_GLOBE
	row.add_child(tab.favicon)

	tab.button = Button.new()
	tab.button.toggle_mode = true
	tab.button.flat = true
	tab.button.custom_minimum_size = Vector2(64, 22)
	tab.button.add_theme_font_override("font", TAB_FONT)
	tab.button.add_theme_font_size_override("font_size", 13)
	tab.button.add_theme_color_override("font_color", TAB_INK)
	tab.button.add_theme_color_override("font_hover_color", TAB_INK)
	tab.button.add_theme_color_override("font_pressed_color", TAB_INK)
	tab.button.add_theme_color_override("font_focus_color", TAB_INK)
	tab.button.add_theme_color_override("font_disabled_color", TAB_MUTED_INK)
	for st: String in ["normal", "hover", "pressed", "disabled"]:
		tab.button.add_theme_stylebox_override(st, _make_empty_style(2))
	tab.button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tab.button.pressed.connect(_select_tab.bind(tab))
	row.add_child(tab.button)

	tab.close = Button.new()
	tab.close.custom_minimum_size = Vector2(18, 18)
	tab.close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tab.close.tooltip_text = "Close tab"
	tab.close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tab.close.add_theme_color_override("font_color", TAB_MUTED_INK)
	tab.close.add_theme_color_override("font_hover_color", Color("#9a2626"))
	tab.close.add_theme_color_override("font_disabled_color", Color("#8a97a8"))
	tab.close.add_theme_stylebox_override("normal", _make_empty_style(0))
	tab.close.add_theme_stylebox_override("hover", _make_tab_close_hover_style())
	tab.close.add_theme_stylebox_override("pressed", _make_tab_close_hover_style())
	tab.close.add_theme_stylebox_override("disabled", _make_empty_style(0))
	tab.close.draw.connect(_draw_tab_action.bind(tab.close, false))
	tab.close.pressed.connect(_close_tab.bind(tab))
	row.add_child(tab.close)

	_tabs.append(tab)
	_apply_tab_container_style(tab, false)
	_update_tab_label(tab)
	return tab


func _make_empty_style(margin_x: int) -> StyleBoxEmpty:
	var s := StyleBoxEmpty.new()
	s.content_margin_left = margin_x
	s.content_margin_right = margin_x
	return s


func _make_tab_close_hover_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.86, 0.25, 0.22, 0.22)
	s.set_corner_radius_all(2)
	return s


func _apply_tab_container_style(tab: Tab, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 7.0
	style.content_margin_top = 3.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 3.0
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 0 if selected else 1
	if selected:
		style.bg_color = Color(0.95, 0.965, 0.98, 1.0)
		style.border_color = Color(0.56, 0.64, 0.73, 1.0)
	else:
		style.bg_color = Color(0.81, 0.865, 0.925, 1.0)
		style.border_color = Color(0.65, 0.72, 0.80, 1.0)
	tab.container.add_theme_stylebox_override("panel", style)
	tab.button.add_theme_color_override("font_color", TAB_INK if selected else TAB_MUTED_INK)


func _draw_tab_action(button: Button, add: bool) -> void:
	var center := (button.size * 0.5).floor() + Vector2(0.5, 0.5)
	var ink := button.get_theme_color("font_disabled_color" if button.disabled else "font_color")
	if add:
		button.draw_line(center - Vector2(4, 0), center + Vector2(4, 0), ink, 2.0)
		button.draw_line(center - Vector2(0, 4), center + Vector2(0, 4), ink, 2.0)
	else:
		button.draw_line(center - Vector2(3, 3), center + Vector2(3, 3), ink, 1.5)
		button.draw_line(center - Vector2(3, -3), center + Vector2(3, -3), ink, 1.5)


func _draw_arrow_glyph(button: Button, is_back: bool) -> void:
	var c := (button.size * 0.5).floor() + Vector2(0.5, 0.5)
	var ink := button.get_theme_color("font_disabled_color" if button.disabled else "font_color")
	var dir := -1.0 if is_back else 1.0
	var span := 4.5 if is_back else 3.5
	button.draw_line(c - Vector2(dir * span, 0.0), c + Vector2(dir * span, 0.0), ink, 2.0)
	button.draw_line(c + Vector2(dir * span, 0.0), c + Vector2(dir * (span - 3.5), -3.5), ink, 2.0)
	button.draw_line(c + Vector2(dir * span, 0.0), c + Vector2(dir * (span - 3.5), 3.5), ink, 2.0)


func _draw_reload_glyph(button: Button) -> void:
	var c := (button.size * 0.5).floor() + Vector2(0.5, 0.5)
	var ink := button.get_theme_color("font_disabled_color" if button.disabled else "font_color")
	button.draw_arc(c, 5.0, -PI * 0.85, PI * 0.72, 16, ink, 1.5, true)
	var tip := c + Vector2.from_angle(-PI * 0.85) * 5.0
	button.draw_line(tip, tip + Vector2(3.5, 0.0), ink, 1.5)
	button.draw_line(tip, tip + Vector2(0.5, -3.5), ink, 1.5)


func _draw_home_glyph(button: Button) -> void:
	var c := (button.size * 0.5).floor() + Vector2(0.5, 0.5)
	var ink := button.get_theme_color("font_disabled_color" if button.disabled else "font_color")
	button.draw_polyline(PackedVector2Array([
		c + Vector2(-6, 0), c + Vector2(0, -5), c + Vector2(6, 0)
	]), ink, 2.0)
	button.draw_rect(Rect2(c + Vector2(-4, 0), Vector2(8, 5)), ink, false, 1.5)
	button.draw_rect(Rect2(c + Vector2(-1, 2), Vector2(2, 3)), ink, true)


func _select_tab(tab: Tab) -> void:
	if _exam_active or not _tabs.has(tab):
		return
	_active = tab
	_address.text = tab.draft
	for other: Tab in _tabs:
		var selected := other == tab
		other.pane.visible = selected
		other.button.set_pressed_no_signal(selected)
		_apply_tab_container_style(other, selected)
	_sync_nav_controls()
	_reveal_tab(tab)


func _reveal_tab(tab: Tab) -> void:
	await get_tree().process_frame
	if tab == _active and _tabs.has(tab) and is_inside_tree():
		%TabScroll.ensure_control_visible(tab.container)


func _close_tab(tab: Tab) -> void:
	if _exam_active or not _tabs.has(tab):
		return
	var index := _tabs.find(tab)
	_tabs.remove_at(index)
	tab.timer.stop()
	tab.pending = null
	%PageHost.remove_child(tab.pane)
	tab.pane.queue_free()
	%Tabs.remove_child(tab.container)
	tab.container.queue_free()
	if tab == _active:
		_active = null
		if _tabs.is_empty():
			_open_new_tab()
		else:
			_select_tab(_tabs[mini(index, _tabs.size() - 1)])
			_active.button.grab_focus()


func _remember_draft(value: String) -> void:
	if _active != null and not _exam_active:
		_active.draft = value


func _navigate(address: String) -> void:
	if _exam_active or _active == null:
		return
	_load_address(_active, address, true)
	_address.text = _active.draft


func _go_back() -> void:
	if _exam_active or _active == null or _active.history_index <= 0:
		return
	_active.history_index -= 1
	_load_address(_active, _active.history[_active.history_index], false)
	_address.text = _active.draft


func _go_forward() -> void:
	if _exam_active or _active == null or _active.history_index < 0 or _active.history_index >= _active.history.size() - 1:
		return
	_active.history_index += 1
	_load_address(_active, _active.history[_active.history_index], false)
	_address.text = _active.draft


func _reload_active() -> void:
	if _exam_active or _active == null:
		return
	if _active.address.is_empty():
		_show_start_page(_active)
	else:
		_load_address(_active, _active.address, false)


func _sync_nav_controls() -> void:
	if _active == null:
		_back.disabled = true
		_forward.disabled = true
		_reload.disabled = true
		_site_icon.texture = ICON_GLOBE
		return
	_back.disabled = _exam_active or _active.history_index <= 0
	_forward.disabled = _exam_active or _active.history_index >= _active.history.size() - 1
	_reload.disabled = _exam_active
	_site_icon.texture = _icon_for_address(_active.address)
	_back.queue_redraw()
	_forward.queue_redraw()
	_reload.queue_redraw()


func _icon_for_address(address: String) -> Texture2D:
	return ICON_BOOK if address == "www.placetostudy.com" else ICON_GLOBE


func _record_history(tab: Tab, normalized_address: String) -> void:
	if tab.history_index >= 0 and tab.history_index < tab.history.size() and tab.history[tab.history_index] == normalized_address:
		return
	if tab.history_index < tab.history.size() - 1:
		tab.history.resize(tab.history_index + 1)
	tab.history.append(normalized_address)
	tab.history_index = tab.history.size() - 1


func _load_address(tab: Tab, address: String, record_history := true) -> void:
	tab.timer.stop()
	tab.pending = null
	_clear_page(tab)
	tab.address = address.strip_edges()
	var site := tab.address.to_lower().trim_prefix("https://").trim_prefix("http://").trim_suffix("/")
	if site in [OLD_LMS_ADDRESS, OLD_LMS_ADDRESS + "/courses", LMS_ADDRESS, "redlineuni.com", "homeworkplace.com"]:
		tab.address = home_address
	tab.draft = tab.address
	if record_history:
		_record_history(tab, tab.address)
	for route: Route in local_routes:
		if route != null and route.address == tab.address and route.page != null:
			tab.title = _route_title(tab.address)
			tab.favicon.texture = _icon_for_address(tab.address)
			_update_tab_label(tab)
			tab.pending = route.page
			if loading_seconds > 0.0:
				_show_loading(tab)
				tab.timer.start(loading_seconds)
			else:
				_finish_navigation(tab)
			if tab == _active:
				_sync_nav_controls()
			return
	if tab.address.is_empty():
		_show_start_page(tab)
	else:
		tab.title = "404"
		tab.favicon.texture = ICON_GLOBE
		var error_page := Label.new()
		error_page.text = "404 · Page not found."
		error_page.theme_type_variation = &"BrowserHeading"
		error_page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		error_page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab.page.add_child(error_page)
	_update_tab_label(tab)
	if tab == _active:
		_sync_nav_controls()


func _show_start_page(tab: Tab) -> void:
	_clear_page(tab)
	tab.address = ""
	tab.draft = ""
	tab.title = "New tab"
	tab.favicon.texture = ICON_GLOBE
	_update_tab_label(tab)
	_record_history(tab, "")

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.page.add_child(box)

	var spacer_top := Control.new()
	spacer_top.custom_minimum_size.y = 14.0
	box.add_child(spacer_top)

	var brand := HBoxContainer.new()
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	brand.add_theme_constant_override("separation", 10)
	box.add_child(brand)

	var logo := TextureRect.new()
	logo.texture = ICON_GLOBE
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.custom_minimum_size = Vector2(40, 40)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand.add_child(logo)

	var heading := Label.new()
	heading.text = "Word Explorer"
	heading.add_theme_font_override("font", DISPLAY_FONT)
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("#173654"))
	brand.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "Akses cepat situs kampus"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("#4a627d"))
	subtitle.add_theme_font_size_override("font_size", 14)
	box.add_child(subtitle)

	var tiles := HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", 14)
	box.add_child(tiles)

	for tile_info: Array in [
		["Perpustakaan", "www.placetostudy.com", ICON_BOOK],
		["LMS", home_address, ICON_GLOBE],
	]:
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(150, 76)
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var card_normal := StyleBoxFlat.new()
		card_normal.bg_color = Color("#f3f7fc")
		card_normal.border_color = Color("#b5c7db")
		card_normal.set_border_width_all(1)
		card_normal.set_corner_radius_all(4)
		var card_hover := card_normal.duplicate() as StyleBoxFlat
		card_hover.bg_color = Color("#e3f0fc")
		card_hover.border_color = Color("#4b87c2")
		tile.add_theme_stylebox_override("normal", card_normal)
		tile.add_theme_stylebox_override("hover", card_hover)
		tile.add_theme_stylebox_override("pressed", card_hover)
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		icon.texture = tile_info[2] as Texture2D
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cap := Label.new()
		cap.text = str(tile_info[0])
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_font_override("font", DISPLAY_FONT)
		cap.add_theme_font_size_override("font_size", 14)
		cap.add_theme_color_override("font_color", Color("#172b42"))
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon)
		inner.add_child(cap)
		tile.add_child(inner)
		var target_url: String = tile_info[1]
		tile.pressed.connect(func() -> void: _navigate(target_url))
		tiles.add_child(tile)

	if tab == _active:
		_address.text = ""
		_sync_nav_controls()


func _route_title(address: String) -> String:
	for definition: TabDefinition in default_tabs:
		if definition != null and definition.address == address and not definition.title.is_empty():
			return definition.title
	return address.trim_prefix("www.")


func _update_tab_label(tab: Tab) -> void:
	tab.button.text = tab.title
	tab.button.tooltip_text = tab.address if not tab.address.is_empty() else "New tab"
	tab.close.accessibility_name = "Close tab " + tab.title


func _clear_page(tab: Tab) -> void:
	for child: Node in tab.page.get_children():
		tab.page.remove_child(child)
		child.queue_free()
	tab.scroll.scroll_vertical = 0
	tab.pane.theme = null


func _show_loading(tab: Tab) -> void:
	var loading := VBoxContainer.new()
	loading.name = "Loading"
	loading.add_theme_constant_override("separation", 8)
	var status := Label.new()
	status.text = "Loading…"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.add_child(status)
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 6.0
	progress.show_percentage = false
	progress.indeterminate = true
	loading.add_child(progress)
	tab.page.add_child(loading)


func _finish_navigation(tab: Tab) -> void:
	if not _tabs.has(tab) or tab.pending == null:
		return
	var local_content := tab.pending.instantiate()
	tab.pending = null
	_clear_page(tab)
	if local_content is Control:
		tab.pane.theme = local_content.theme
	if local_content.has_signal("exam_mode_changed"):
		local_content.connect("exam_mode_changed", _set_exam_mode.bind(tab))
	if local_content.has_method("set_attachment_provider"):
		local_content.call("set_attachment_provider", _attachment_provider)
	if local_content.has_method("set_exam_host"):
		local_content.call("set_exam_host", _exam_host)
	tab.page.add_child(local_content)


func _set_exam_mode(active: bool, tab: Tab) -> void:
	if tab != _active:
		return
	_exam_active = active
	_address.editable = not active
	_address.focus_mode = Control.FOCUS_NONE if active else Control.FOCUS_ALL
	_home.disabled = active
	_go.disabled = active
	_menu.disabled = active
	%NewTab.disabled = active
	for item: Tab in _tabs:
		item.button.disabled = active
		item.close.disabled = active
	_sync_nav_controls()
	exam_mode_changed.emit(active)
