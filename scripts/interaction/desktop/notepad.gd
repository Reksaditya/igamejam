extends VBoxContainer

enum FileAction { OPEN, SAVE, SAVE_AS }

const NOTES_DIRECTORY := "user://notes"

var starting_text: String

var _document_path: String
var _saved_text: String
var _open_path: String
var _open_text: String

@onready var _editor: TextEdit = $Editor
@onready var _picker: FileDialog = $NotePicker
@onready var _discard_dialog: ConfirmationDialog = $DiscardEdits
@onready var _file_error: AcceptDialog = $FileError


func _ready() -> void:
	_editor.text = starting_text
	_saved_text = _editor.text

	var context_menu := _editor.get_menu()
	for id: int in [TextEdit.MENU_DISPLAY_UCC, TextEdit.MENU_SUBMENU_INSERT_UCC]:
		var index := context_menu.get_item_index(id)
		if index >= 0:
			context_menu.remove_item(index)

	var menu: PopupMenu = %FileMenu.get_popup()
	menu.theme_type_variation = &"NotepadFilePopup"
	menu.add_item("Open…", FileAction.OPEN)
	menu.add_item("Save", FileAction.SAVE)
	menu.add_item("Save As…", FileAction.SAVE_AS)
	menu.id_pressed.connect(_on_file_action)
	_picker.file_selected.connect(_on_file_selected)
	_discard_dialog.confirmed.connect(_open_pending_document)
	_discard_dialog.canceled.connect(_clear_pending_document)


func _on_file_action(action: int) -> void:
	var error := DirAccess.make_dir_recursive_absolute(NOTES_DIRECTORY)
	if error != OK:
		_show_file_error("Could not create the notes folder.", error)
		return

	if action == FileAction.SAVE and not _document_path.is_empty():
		_save_document(_document_path)
		return

	_picker.root_subfolder = NOTES_DIRECTORY
	_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE if action == FileAction.OPEN else FileDialog.FILE_MODE_SAVE_FILE
	_picker.title = "Open note" if action == FileAction.OPEN else "Save note as"
	_picker.current_file = "" if action == FileAction.OPEN else _document_path.get_file()
	_picker.popup_centered_clamped(Vector2i(560, 360))


func _on_file_selected(selected_path: String) -> void:
	var path := selected_path.replace("\\", "/").simplify_path()
	if not path.begins_with(NOTES_DIRECTORY + "/") or path.get_extension().to_lower() != "txt":
		_show_file_error("Choose a .txt file in the notes folder.", ERR_INVALID_PARAMETER)
		return

	if _picker.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		_read_document(path)
	else:
		_save_document(path)


func _read_document(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_show_file_error("Could not open the note.", FileAccess.get_open_error())
		return
	var length := file.get_length()
	var bytes := file.get_buffer(length)
	if bytes.size() != length:
		_show_file_error("Could not read the whole note.", ERR_FILE_CANT_READ)
		return

	if bytes.slice(0, 3) == PackedByteArray([0xef, 0xbb, 0xbf]):
		bytes = bytes.slice(3)
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		_show_file_error("Could not read the note as UTF-8.", ERR_FILE_CORRUPT)
		return

	_open_path = path
	_open_text = text
	if _editor.text == _saved_text:
		_open_pending_document()
	else:
		_discard_dialog.popup_centered(Vector2i(360, 0))
		_discard_dialog.get_cancel_button().grab_focus()


func _open_pending_document() -> void:
	_editor.text = _open_text
	_editor.clear_undo_history()
	_document_path = _open_path
	_saved_text = _editor.text
	_clear_pending_document()


func _clear_pending_document() -> void:
	_open_path = ""
	_open_text = ""


func _save_document(path: String) -> void:
	var temporary_file := ".notepad-%d-%d-%d" % [OS.get_process_id(), get_instance_id(), Time.get_ticks_usec()]
	var temporary_path := path.get_base_dir().path_join(temporary_file)
	var backup_path := temporary_path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		_show_file_error("Could not write the note.", FileAccess.get_open_error())
		return

	var text := _editor.text
	var wrote_text := file.store_string(text)
	file.flush()
	var error := file.get_error() if wrote_text else ERR_FILE_CANT_WRITE
	file.close()
	if error == OK:
		error = _replace_note_file(temporary_path, path, backup_path)
	if error != OK:
		DirAccess.remove_absolute(temporary_path)
		var message := "Could not save the note."
		if FileAccess.file_exists(backup_path):
			message += "\nThe previous note is backed up as " + backup_path.get_file() + "."
		_show_file_error(message, error)
		return

	_document_path = path
	_saved_text = text


func _replace_note_file(temporary_path: String, path: String, backup_path: String) -> Error:
	if not FileAccess.file_exists(path):
		return DirAccess.rename_absolute(temporary_path, path)

	var error := DirAccess.rename_absolute(path, backup_path)
	if error != OK:
		return error

	error = DirAccess.rename_absolute(temporary_path, path)
	if error == OK:
		DirAccess.remove_absolute(backup_path)
	else:
		DirAccess.rename_absolute(backup_path, path)
	return error


func _show_file_error(message: String, error: Error) -> void:
	_file_error.dialog_text = message + "\n" + error_string(error)
	_file_error.popup_centered(Vector2i(360, 0))
