extends Node

signal changed
signal project_completed(project_id: String)

const Definition = preload("res://scripts/interaction/blueprint/blueprint_definition.gd")
const PROJECT: Definition = preload("res://scenes/interaction/blueprint/transmission.tres")
const SAVE_PATH := "user://blueprint_progress.cfg"

var _learned := PackedInt32Array()
var _placed := PackedInt32Array()


func _ready() -> void:
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) != OK or save.get_value("project", "id", "") != PROJECT.id:
		return
	if save.get_value("project", "version", 0) != 1:
		return
	_learned = _read_indices(save.get_value("project", "learned", PackedInt32Array()))
	for index: int in _read_indices(save.get_value("project", "placed", PackedInt32Array())):
		if _learned.has(index):
			_placed.append(index)


func has_piece(index: int) -> bool:
	return _learned.has(index)


func is_placed(index: int) -> bool:
	return _placed.has(index)


func get_placed_count() -> int:
	return _placed.size()


func is_complete() -> bool:
	return _placed.size() == PROJECT.lessons.size()


## Call only after a classroom activity or desktop lesson has actually finished.
## Repeating the same lesson is safe and never duplicates a piece.
func complete_study(lesson_id: String) -> Error:
	for index: int in PROJECT.lessons.size():
		if PROJECT.lessons[index].id != lesson_id:
			continue
		if has_piece(index):
			return OK
		_learned.append(index)
		var error := _save()
		if error != OK:
			_learned.remove_at(_learned.find(index))
		else:
			changed.emit()
		return error
	return ERR_INVALID_PARAMETER


func place_piece(piece: int, slot: int) -> Error:
	if piece != slot or not has_piece(piece) or is_placed(slot):
		return ERR_INVALID_PARAMETER
	_placed.append(piece)
	var error := _save()
	if error != OK:
		_placed.remove_at(_placed.find(piece))
		return error
	changed.emit()
	if is_complete():
		project_completed.emit(PROJECT.id)
	return OK


func _save() -> Error:
	var save := ConfigFile.new()
	save.set_value("project", "version", 1)
	save.set_value("project", "id", PROJECT.id)
	save.set_value("project", "learned", _learned)
	save.set_value("project", "placed", _placed)
	var temporary_path := SAVE_PATH + ".tmp"
	var error := save.save(temporary_path)
	if error == OK:
		error = DirAccess.rename_absolute(temporary_path, SAVE_PATH)
	return error


func _read_indices(value: Variant) -> PackedInt32Array:
	var indices := PackedInt32Array()
	if value is PackedInt32Array:
		for index: int in value:
			if index >= 0 and index < PROJECT.lessons.size() and not indices.has(index):
				indices.append(index)
	return indices
