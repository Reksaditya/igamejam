extends Node

signal notes_changed(assignment_id: String)
signal keyword_discovered(keyword_id: String)
const Note = preload("res://scripts/interaction/desktop/study/study_note.gd")
const Save = preload("res://scripts/autoload/playthrough_save.gd")
const SAVE_PATH := "user://study_notes.cfg"

@export var entries: Array[Note]

var _unlocked := PackedStringArray()
var _studied_books := PackedStringArray()
var _keywords := PackedStringArray()


func _ready() -> void:
	reload_progress()


func reload_progress() -> void:
	var saved := Save.load_config(SAVE_PATH)
	_unlocked = _load_ids(saved, "notebook", "unlocked_ids")
	_studied_books = _load_ids(saved, "library", "studied_books")
	_keywords = _load_ids(saved, "library", "discovered_keywords")


func _load_ids(config: ConfigFile, section: String, key: String) -> PackedStringArray:
	var ids: Variant = config.get_value(section, key, PackedStringArray())
	return ids if ids is PackedStringArray else PackedStringArray()


func unlock_note(note_id: String) -> Error:
	return _unlock_notes(PackedStringArray([note_id]))


func get_unlocked_entries(assignment_id: String) -> Array[Note]:
	var unlocked_entries: Array[Note] = []
	for note: Note in _entries_for(assignment_id):
		if note.note_id in _unlocked:
			unlocked_entries.append(note)
	return unlocked_entries


func is_complete(assignment_id: String) -> bool:
	var notes := _entries_for(assignment_id)
	return not notes.is_empty() and get_unlocked_entries(assignment_id).size() == notes.size()


func fill_assignment(assignment_id: String) -> Error:
	var ids := PackedStringArray()
	for note: Note in _entries_for(assignment_id):
		ids.append(note.note_id)
	if ids.is_empty():
		return ERR_DOES_NOT_EXIST
	return _unlock_notes(ids)


func is_book_studied(book_id: String, note_ids: PackedStringArray) -> bool:
	if book_id in _studied_books:
		return true
	if note_ids.is_empty():
		return false
	for id: String in note_ids:
		if id not in _unlocked:
			return false
	return true


func study_book(book_id: String, note_ids: PackedStringArray) -> Error:
	if book_id.is_empty():
		return ERR_INVALID_PARAMETER
	if is_book_studied(book_id, note_ids):
		return OK
	return _unlock_notes(note_ids, book_id)


func has_keyword(keyword_id: String) -> bool:
	return keyword_id in _keywords


func discover_keyword(keyword_id: String) -> Error:
	if keyword_id.is_empty():
		return ERR_INVALID_PARAMETER
	if has_keyword(keyword_id):
		return OK
	var keywords := _keywords.duplicate()
	keywords.append(keyword_id)
	var error := _save(_unlocked, _studied_books, keywords)
	if error == OK:
		_keywords = keywords
		keyword_discovered.emit(keyword_id)
	return error


func _entries_for(assignment_id: String) -> Array[Note]:
	var notes: Array[Note] = []
	for note: Note in entries:
		if note != null and note.assignment_id == assignment_id and not note.note_id.is_empty():
			notes.append(note)
	return notes


func _unlock_notes(note_ids: PackedStringArray, book_id: String = "") -> Error:
	var unlocked := _unlocked.duplicate()
	var affected := PackedStringArray()
	for id: String in note_ids:
		var found := false
		for note: Note in entries:
			if note != null and not id.is_empty() and note.note_id == id:
				found = true
				if id not in unlocked:
					unlocked.append(id)
					if note.assignment_id not in affected:
						affected.append(note.assignment_id)
				break
		if not found:
			return ERR_DOES_NOT_EXIST
	var books := _studied_books.duplicate()
	if not book_id.is_empty() and book_id not in books:
		books.append(book_id)
	if unlocked == _unlocked and books == _studied_books:
		return OK
	var error := _save(unlocked, books, _keywords)
	if error != OK:
		return error
	_unlocked = unlocked
	_studied_books = books
	for assignment_id: String in affected:
		notes_changed.emit(assignment_id)
	return OK


func _save(unlocked: PackedStringArray, books: PackedStringArray, keywords: PackedStringArray) -> Error:
	var config := Save.load_config(SAVE_PATH)
	config.set_value("notebook", "unlocked_ids", unlocked)
	config.set_value("library", "studied_books", books)
	config.set_value("library", "discovered_keywords", keywords)
	return Save.write_config(config, SAVE_PATH)
