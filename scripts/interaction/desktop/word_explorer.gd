extends MarginContainer

signal exam_mode_changed(active: bool)

@export var accepted_address: String = "www.homeworkplace.com"
@export var local_page: PackedScene

var _exam_active: bool = false
var _attachment_provider: Callable

@onready var _address: LineEdit = %Address
@onready var _go: Button = %Go
@onready var _home: Button = %Home
@onready var _scroll: ScrollContainer = %Scroll
@onready var _page: MarginContainer = %Page
@onready var _page_panel: PanelContainer = $Layout/PagePanel


func _ready() -> void:
	_address.focus_entered.connect(func() -> void: _address.edit())
	_address.text_submitted.connect(_navigate)
	_go.pressed.connect(func() -> void: _navigate(_address.text))
	_home.pressed.connect(_go_home)
	_go_home()


func set_attachment_provider(provider: Callable) -> void:
	_attachment_provider = provider


func _go_home() -> void:
	if _exam_active:
		return
	_address.text = accepted_address
	_navigate(accepted_address)


func _navigate(address: String) -> void:
	if _exam_active:
		return
	for child: Node in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	_scroll.scroll_vertical = 0
	_page_panel.theme = null

	var submitted_address: String = address.strip_edges()
	if not submitted_address.is_empty() and submitted_address == accepted_address and local_page != null:
		var local_content := local_page.instantiate()
		if local_content is Control:
			_page_panel.theme = local_content.theme
		if local_content.has_signal("exam_mode_changed"):
			local_content.connect("exam_mode_changed", _set_exam_mode)
		if local_content.has_method("set_attachment_provider"):
			local_content.call("set_attachment_provider", _attachment_provider)
		_page.add_child(local_content)
		return

	var error_page := Label.new()
	error_page.text = "404 Page Not Found."
	error_page.theme_type_variation = &"BrowserHeading"
	error_page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(error_page)


func _set_exam_mode(active: bool) -> void:
	_exam_active = active
	_address.editable = not active
	_address.focus_mode = Control.FOCUS_NONE if active else Control.FOCUS_ALL
	_home.disabled = active
	_go.disabled = active
	_scroll.set_deferred("scroll_vertical", 0)
	exam_mode_changed.emit(active)
