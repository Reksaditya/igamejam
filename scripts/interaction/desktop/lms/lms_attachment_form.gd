extends VBoxContainer

signal closed

const Assignment = preload("res://scripts/interaction/desktop/lms/lms_assignment.gd")
const Checker = preload("res://scripts/interaction/desktop/lms/lms_attachment_checker.gd")
const Results = preload("res://scripts/interaction/desktop/lms/lms_results.gd")

var assignment: Assignment
var attachment_provider: Callable
var _selected: Dictionary = {}
var _finished: bool = false

@onready var _picker: ConfirmationDialog = %Picker
@onready var _files: ItemList = %Files
@onready var _choose: Button = %Choose
@onready var _remove: Button = %Remove
@onready var _submit: Button = %Submit
@onready var _error: Label = %SaveError


func _ready() -> void:
	%Title.text = assignment.title
	%Instructions.text = assignment.instructions
	_choose.pressed.connect(_show_picker)
	_remove.pressed.connect(_select.bind({}))
	%Cancel.pressed.connect(_close)
	_submit.pressed.connect(_submit_attachment)
	_picker.confirmed.connect(_attach_selected)
	_picker.canceled.connect(_choose.grab_focus)
	_files.item_selected.connect(func(_index: int) -> void: _picker.get_ok_button().disabled = false)
	_files.item_activated.connect(func(_index: int) -> void:
		_picker.hide()
		_attach_selected()
	)
	_choose.grab_focus.call_deferred()


func _show_picker() -> void:
	_files.clear()
	if attachment_provider.is_valid():
		var attachments: Array[Dictionary] = attachment_provider.call()
		for item: Dictionary in attachments:
			var index := _files.add_item("%s   ·   %s" % [item.filename, item.source])
			_files.set_item_metadata(index, item)
	%EmptyFiles.visible = _files.item_count == 0
	_picker.get_ok_button().disabled = true
	_picker.popup_centered_clamped(Vector2i(460, 310))
	_files.grab_focus()


func _attach_selected() -> void:
	var selected_rows := _files.get_selected_items()
	if not selected_rows.is_empty():
		_select(_files.get_item_metadata(selected_rows[0]))


func _select(metadata: Dictionary) -> void:
	_selected = metadata
	var has_file := not _selected.is_empty()
	%Filename.text = _selected.filename if has_file else "No attachment selected"
	_choose.text = "Replace file" if has_file else "Choose file"
	_remove.disabled = not has_file
	_submit.disabled = not has_file
	_submit.text = "Submit attachment"
	_error.hide()
	_choose.grab_focus()


func _submit_attachment() -> void:
	if _finished or _selected.is_empty():
		return
	var score := Checker.grade(assignment, _selected)
	var error := Results.save_result(assignment.id, score, 1, _selected.filename)
	if error == OK or (error == ERR_ALREADY_EXISTS and not Results.read_result(assignment.id).is_empty()):
		_close()
	else:
		_error.show()
		_submit.text = "Retry submission"


func _close() -> void:
	if not _finished:
		_finished = true
		closed.emit()
