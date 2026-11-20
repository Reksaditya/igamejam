extends RefCounted

const Assignment = preload("res://scripts/interaction/desktop/lms/lms_assignment.gd")


static func grade(assignment: Assignment, attachment: Dictionary) -> int:
	var filename := _normalize(attachment.get("filename", ""))
	if filename.is_empty():
		return 0
	for accepted: String in assignment.accepted_filenames:
		if _normalize(accepted) == filename:
			return 1
	return 0


static func _normalize(filename: String) -> String:
	return filename.strip_edges().replace("\\", "/").get_file().to_lower()
