extends RefCounted

const DIRECTORY := "user://lms_results"
const SECTION := "result"


static func read_result(assignment_id: String) -> Dictionary:
	if not assignment_id.is_valid_identifier():
		return {}
	var result := ConfigFile.new()
	if result.load(_path(assignment_id)) != OK:
		return {}
	if result.get_value(SECTION, "completed", false) != true:
		return {}
	var score: Variant = result.get_value(SECTION, "score", -1)
	var max_score: Variant = result.get_value(SECTION, "max_score", 0)
	if not score is int or not max_score is int or max_score <= 0 or score < 0 or score > max_score:
		return {}
	var data := {"completed": true, "score": score, "max_score": max_score}
	var filename: Variant = result.get_value(SECTION, "attachment_filename", "")
	if filename is String and not filename.is_empty():
		data["attachment_filename"] = filename
	return data


static func save_result(assignment_id: String, score: int, max_score: int, attachment_filename: String = "") -> Error:
	if not assignment_id.is_valid_identifier() or max_score <= 0 or score < 0 or score > max_score:
		return ERR_INVALID_PARAMETER
	var path := _path(assignment_id)
	if FileAccess.file_exists(path):
		return ERR_ALREADY_EXISTS
	var error := DirAccess.make_dir_recursive_absolute(DIRECTORY)
	if error != OK:
		return error

	var result := ConfigFile.new()
	result.set_value(SECTION, "completed", true)
	result.set_value(SECTION, "score", score)
	result.set_value(SECTION, "max_score", max_score)
	if not attachment_filename.is_empty():
		result.set_value(SECTION, "attachment_filename", attachment_filename)
	var temporary_path := "%s.%d.%d.tmp" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	error = result.save(temporary_path)
	if error == OK:
		if FileAccess.file_exists(path):
			error = ERR_ALREADY_EXISTS
		else:
			error = DirAccess.rename_absolute(temporary_path, path)
	if error != OK and FileAccess.file_exists(temporary_path):
		DirAccess.remove_absolute(temporary_path)
	return error


static func _path(assignment_id: String) -> String:
	return DIRECTORY.path_join(assignment_id + ".cfg")
