extends Node

signal changed

const SAVE_PATH := "user://classroom_notes.cfg"

var _notes := PackedInt32Array()
var _attempted := PackedInt32Array()
var _pending_material: int = -1


func _ready() -> void:
	reload_progress()


func reload_progress() -> void:
	_notes.clear()
	_attempted.clear()
	_pending_material = -1
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) != OK:
		return
	var version: int = save.get_value("notes", "version", 0)
	if version != 1 and version != 2:
		return
	_notes = _read_indices(save.get_value("notes", "complete", PackedInt32Array()))
	_attempted = _read_indices(save.get_value("notes", "attempted", _notes))
	for index: int in _notes:
		if not _attempted.has(index):
			_attempted.append(index)


func has_note(index: int) -> bool:
	return _notes.has(index)


func has_attempted(index: int) -> bool:
	return _attempted.has(index)


func is_complete() -> bool:
	return _notes.size() == BlueprintProgress.PROJECT.lessons.size()


func is_class_finished() -> bool:
	return _attempted.size() == BlueprintProgress.PROJECT.lessons.size()


func get_unattempted_indices() -> PackedInt32Array:
	var indices := PackedInt32Array()
	for index: int in BlueprintProgress.PROJECT.lessons.size():
		if not has_attempted(index):
			indices.append(index)
	return indices


func begin_material(index: int) -> Error:
	if index < 0 or index >= BlueprintProgress.PROJECT.lessons.size():
		return ERR_INVALID_PARAMETER
	if has_attempted(index):
		return ERR_ALREADY_EXISTS
	_attempted.append(index)
	var error := _save()
	if error != OK:
		_attempted.remove_at(_attempted.find(index))
		return error
	_pending_material = index
	changed.emit()
	return OK


func finish_material(index: int, success: bool) -> Error:
	if _pending_material != index or not has_attempted(index):
		return ERR_UNAUTHORIZED
	if success and not has_note(index):
		_notes.append(index)
		var error := _save()
		if error != OK:
			_notes.remove_at(_notes.find(index))
			_pending_material = -1
			return error
	_pending_material = -1
	changed.emit()
	return OK


func unlock_blueprint() -> Error:
	if not is_complete():
		return ERR_UNAUTHORIZED
	for lesson: Resource in BlueprintProgress.PROJECT.lessons:
		var error := BlueprintProgress.complete_study(lesson.id)
		if error != OK:
			return error
	return ProjectBlueprints.grant("sediment_sorter")


func _save() -> Error:
	var save := ConfigFile.new()
	save.set_value("notes", "version", 2)
	save.set_value("notes", "complete", _notes)
	save.set_value("notes", "attempted", _attempted)
	var error := save.save(SAVE_PATH + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	return error


func _read_indices(value: Variant) -> PackedInt32Array:
	var indices := PackedInt32Array()
	if value is PackedInt32Array:
		for index: int in value:
			if index >= 0 and index < BlueprintProgress.PROJECT.lessons.size() and not indices.has(index):
				indices.append(index)
	return indices
