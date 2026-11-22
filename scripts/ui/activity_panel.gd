extends CanvasLayer

signal closed

var window: Window
var content: VBoxContainer
var close_button: Button
var can_close: bool = true
var _was_paused: bool = false
var _clock_mode: Node.ProcessMode
var _opened: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	window = Window.new()
	window.title = "Deadline"
	window.theme = preload("res://scenes/ui/menu_theme.tres")
	window.visible = false
	window.transient = true
	window.exclusive = true
	window.min_size = Vector2i(540, 320)
	add_child(window)
	window.close_requested.connect(close)
	window.window_input.connect(_window_input)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	get_viewport().size_changed.connect(_fit, CONNECT_DEFERRED)
	open.call_deferred()


func open() -> void:
	if not _opened:
		_was_paused = get_tree().paused
		_clock_mode = GameClock.process_mode
		_opened = true
		get_tree().paused = true
		GameClock.process_mode = Node.PROCESS_MODE_ALWAYS
	_fit()
	if is_instance_valid(close_button):
		close_button.grab_focus()


func _fit() -> void:
	if _opened:
		window.popup_centered_clamped(Vector2i(820, 620), 0.9)


func clear() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	close_button = null


func label(value: String, font_size: int = 20) -> Label:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", font_size)
	content.add_child(item)
	return item


func button(value: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.pressed.connect(action)
	content.add_child(item)
	return item


func add_close() -> void:
	close_button = button("Kembali", close)
	close_button.disabled = not can_close


func close() -> void:
	if not can_close:
		return
	_restore()
	closed.emit()
	queue_free()


func _restore() -> void:
	if _opened:
		get_tree().paused = _was_paused
		GameClock.process_mode = _clock_mode
		_opened = false


func _exit_tree() -> void:
	_restore()


func _window_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		window.set_input_as_handled()
