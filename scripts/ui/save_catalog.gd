extends RefCounted

const Results = preload("res://scripts/interaction/desktop/lms/lms_results.gd")
const RESULT_TITLES := {"classroom_midterm_week_8": "UTS · Minggu 8", "classroom_final_week_16": "UAS · Minggu 16", "dinosaur_basics": "Kuis LMS · Dinosaur Basics", "submit_field_notes": "Tugas LMS · Field Notes"}


static func get_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var notes := ConfigFile.new()
	if notes.load("user://classroom_notes.cfg") == OK:
		var version: Variant = notes.get_value("notes", "version", 0)
		if version == 1 or version == 2:
			var completed := _count_indices(notes.get_value("notes", "complete", PackedInt32Array()))
			var attempted := maxi(completed, _count_indices(notes.get_value("notes", "attempted", PackedInt32Array())))
			if attempted > 0:
				entries.append({"title": "Autosave · Catatan kelas", "details": "%d / 6 bagian catatan lengkap\n%d / 6 materi sudah dilewati" % [completed, attempted]})
	var blueprint := ConfigFile.new()
	if blueprint.load("user://blueprint_progress.cfg") == OK and blueprint.get_value("project", "version", 0) == 1 and blueprint.get_value("project", "id", "") == "transmission":
		var learned := _count_indices(blueprint.get_value("project", "learned", PackedInt32Array()))
		var placed := _count_indices(blueprint.get_value("project", "placed", PackedInt32Array()))
		if learned > 0:
			entries.append({"title": "Autosave · Blueprint mesin", "details": "%d / 6 potongan diperoleh\n%d / 6 potongan terpasang" % [learned, mini(learned, placed)]})
	var directory := DirAccess.open(Results.DIRECTORY)
	if directory != null:
		var files := directory.get_files()
		files.sort()
		for filename: String in files:
			if filename.get_extension() != "cfg":
				continue
			var id := filename.get_basename()
			var result := Results.read_result(id)
			if not result.is_empty():
				entries.append({"title": RESULT_TITLES.get(id, "LMS · " + id.capitalize()), "details": "Nilai %d / %d\nHasil permainan tersimpan" % [result.score, result.max_score]})
	return entries


static func _count_indices(value: Variant) -> int:
	var unique := PackedInt32Array()
	if value is PackedInt32Array:
		for index: int in value:
			if index >= 0 and index < 6 and not unique.has(index):
				unique.append(index)
	return unique.size()
