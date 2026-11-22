extends MarginContainer

signal exam_mode_changed(active: bool)

const Route = preload("res://scripts/interaction/desktop/browser_route.gd")
const TabDefinition = preload("res://scripts/interaction/desktop/browser_tab.gd")
const PAGE_SCENE := preload("res://scenes/interaction/desktop/browser_page.tscn")


class Tab:
	var address := ""
	var draft := ""
	var title := "Tab baru"
	var button: Button
	var close: Button
	var pane: PanelContainer
	var scroll: ScrollContainer
	var page: MarginContainer
	var timer: Timer
	var pending: PackedScene


@export var home_address: String = "www.homeworkplace.com"
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


func _ready() -> void:
	_address.focus_entered.connect(_address.edit)
	_address.text_changed.connect(_remember_draft)
	_address.text_submitted.connect(_navigate)
	_go.pressed.connect(func() -> void: _navigate(_address.text))
	_home.pressed.connect(func() -> void: _navigate(home_address))
	%NewTab.pressed.connect(_open_new_tab)
	%NewTab.draw.connect(_draw_tab_action.bind(%NewTab, true))
	for definition: TabDefinition in default_tabs:
		if definition != null:
			var tab := _add_tab(definition.title)
			_load_address(tab, definition.address)
	if _tabs.is_empty():
		_open_new_tab()
	else:
		_select_tab(_tabs[clampi(start_tab, 0, _tabs.size() - 1)])


func set_attachment_provider(provider: Callable) -> void:
	_attachment_provider = provider


func set_exam_host(host: Control) -> void:
	_exam_host = host


func _open_new_tab() -> void:
	if _exam_active:
		return
	_select_tab(_add_tab("Tab baru"))
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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	%Tabs.add_child(row)
	tab.button = Button.new()
	tab.button.toggle_mode = true
	tab.button.pressed.connect(_select_tab.bind(tab))
	row.add_child(tab.button)
	tab.close = Button.new()
	tab.close.draw.connect(_draw_tab_action.bind(tab.close, false))
	tab.close.tooltip_text = "Tutup tab"
	tab.close.custom_minimum_size.x = 29
	tab.close.pressed.connect(_close_tab.bind(tab))
	row.add_child(tab.close)
	for button: Button in [tab.button, tab.close]:
		button.add_theme_font_size_override("font_size", 14)
		button.custom_minimum_size.y = 22
		button.theme_type_variation = &"BrowserButton"
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_tabs.append(tab)
	_update_tab_label(tab)
	return tab


func _draw_tab_action(button: Button, add: bool) -> void:
	var center := (button.size * 0.5).floor()
	var ink := button.get_theme_color("font_color")
	if add:
		button.draw_line(center - Vector2(5, 0), center + Vector2(5, 0), ink, 2)
		button.draw_line(center - Vector2(0, 5), center + Vector2(0, 5), ink, 2)
	else:
		button.draw_line(center - Vector2(4, 4), center + Vector2(4, 4), ink, 1.5, true)
		button.draw_line(center - Vector2(4, -4), center + Vector2(4, -4), ink, 1.5, true)


func _select_tab(tab: Tab) -> void:
	if _exam_active or not _tabs.has(tab):
		return
	_active = tab
	_address.text = tab.draft
	for other: Tab in _tabs:
		var selected := other == tab
		other.pane.visible = selected
		other.button.set_pressed_no_signal(selected)
		other.button.theme_type_variation = &"BrowserActiveTab" if selected else &"BrowserButton"
	_reveal_tab(tab)


func _reveal_tab(tab: Tab) -> void:
	await get_tree().process_frame
	if tab == _active and _tabs.has(tab) and is_inside_tree():
		%TabScroll.ensure_control_visible(tab.button.get_parent())


func _close_tab(tab: Tab) -> void:
	if _exam_active or not _tabs.has(tab):
		return
	var index := _tabs.find(tab)
	_tabs.remove_at(index)
	tab.timer.stop()
	tab.pending = null
	%PageHost.remove_child(tab.pane)
	tab.pane.queue_free()
	var controls := tab.button.get_parent()
	%Tabs.remove_child(controls)
	controls.queue_free()
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
	_load_address(_active, address)
	_address.text = _active.draft


func _load_address(tab: Tab, address: String) -> void:
	tab.timer.stop()
	tab.pending = null
	_clear_page(tab)
	tab.address = address.strip_edges()
	tab.draft = tab.address
	for route: Route in local_routes:
		if route != null and route.address == tab.address and route.page != null:
			tab.title = _route_title(tab.address)
			_update_tab_label(tab)
			tab.pending = route.page
			if loading_seconds > 0.0:
				_show_loading(tab)
				tab.timer.start(loading_seconds)
			else:
				_finish_navigation(tab)
			return
	if tab.address.is_empty():
		tab.title = "Tab baru"
	else:
		tab.title = "404"
		var error_page := Label.new()
		error_page.text = "404 · Halaman tidak ditemukan."
		error_page.theme_type_variation = &"BrowserHeading"
		error_page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		error_page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab.page.add_child(error_page)
	_update_tab_label(tab)


func _route_title(address: String) -> String:
	for definition: TabDefinition in default_tabs:
		if definition != null and definition.address == address and not definition.title.is_empty():
			return definition.title
	return address.trim_prefix("www.")


func _update_tab_label(tab: Tab) -> void:
	tab.button.text = tab.title
	tab.button.tooltip_text = tab.address
	tab.close.accessibility_name = "Tutup tab " + tab.title


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
	status.text = "Memuat…"
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
	%NewTab.disabled = active
	for item: Tab in _tabs:
		item.button.disabled = active
		item.close.disabled = active
	exam_mode_changed.emit(active)
