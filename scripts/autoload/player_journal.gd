extends Node

signal changed

const SAVE_PATH := "user://player_journal.cfg"

var _entries: Array[Dictionary] = []


func _ready() -> void:
	reload_progress()
	BlueprintProgress.project_completed.connect(_on_blueprint_completed)


func reload_progress() -> void:
	_entries.clear()
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) != OK or save.get_value("journal", "version", 0) != 1:
		return
	var entries: Variant = save.get_value("journal", "entries", [])
	if entries is Array:
		for entry: Variant in entries:
			if _valid_entry(entry):
				_entries.append(entry)
	changed.emit()


func _valid_entry(entry: Variant) -> bool:
	if not entry is Dictionary or entry.get("kind", "") not in ["notes", "project"]:
		return false
	for key: String in ["semester", "week"]:
		if not entry.get(key) is int or entry[key] < 0:
			return false
	if entry.week > 16 or (entry.semester == 0) != (entry.week == 0):
		return false
	for key: String in ["title", "body", "source"]:
		if not entry.get(key) is String:
			return false
	return true


func get_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func record_classroom(absolute_week: int = -1) -> Error:
	if not ClassroomProgress.is_class_finished():
		return ERR_UNAUTHORIZED
	var lines := PackedStringArray()
	for index: int in BlueprintProgress.PROJECT.lessons.size():
		var lesson := BlueprintProgress.PROJECT.lessons[index]
		lines.append("%s\n%s" % [lesson.title, lesson.material if ClassroomProgress.has_note(index) else "________________ (catatan kosong)"])
	return _record("notes", "class_transmission", "Catatan · Struktur Transmisi", "\n\n".join(lines), absolute_week)


func record_project(id: String, title: String, absolute_week: int = -1) -> Error:
	return _record("project", id, title, "Proyek telah selesai dibuat.", absolute_week)


func record_desktop_note(path: String, body: String, absolute_week: int = -1) -> Error:
	var source := "desktop_" + path.trim_prefix("user://")
	for entry: Dictionary in _entries:
		if entry.source == source:
			if entry.body == body:
				return OK
			var previous: String = entry.body
			entry.body = body
			var error := _save_entries()
			if error != OK:
				entry.body = previous
			return error
	return _record("notes", source, path.get_file().get_basename(), body, absolute_week)


func _on_blueprint_completed(id: String) -> void:
	_record("project", "blueprint_" + id, "Blueprint · Struktur Transmisi", "Blueprint telah selesai disusun. Perakitan mesin dicatat terpisah setelah proyek selesai.", -1)


func sync_legacy() -> Error:
	if ClassroomProgress.is_class_finished() and not _has_source("class_transmission"):
		var error := record_classroom(0)
		if error != OK:
			return error
	if BlueprintProgress.is_complete() and not _has_source("blueprint_transmission"):
		var error := _record("project", "blueprint_transmission", "Blueprint · Struktur Transmisi", "Blueprint telah selesai disusun.", 0)
		if error != OK:
			return error
	return _sync_desktop_notes("user://notes")


func _sync_desktop_notes(path: String) -> Error:
	var directory := DirAccess.open(path)
	if directory == null:
		return OK
	for filename: String in directory.get_files():
		if filename.get_extension().to_lower() != "txt":
			continue
		var note_path := path.path_join(filename)
		var file := FileAccess.open(note_path, FileAccess.READ)
		if file == null:
			return FileAccess.get_open_error()
		var error := record_desktop_note(note_path, file.get_as_text(), 0)
		if error != OK:
			return error
	for child: String in directory.get_directories():
		var error := _sync_desktop_notes(path.path_join(child))
		if error != OK:
			return error
	return OK


func _has_source(source: String) -> bool:
	for entry: Dictionary in _entries:
		if entry.source == source:
			return true
	return false


func _record(kind: String, source: String, title: String, body: String, absolute_week: int) -> Error:
	if _has_source(source):
		return OK
	var week := GameClock.get_week() if absolute_week < 0 else absolute_week
	var semester := floori(float(week - 1) / 16.0) + 1 if week > 0 else 0
	var entry := {"kind": kind, "source": source, "title": title, "body": body, "semester": semester, "week": (week - 1) % 16 + 1 if week > 0 else 0}
	_entries.append(entry)
	var error := _save_entries()
	if error != OK:
		_entries.pop_back()
	return error


func _save_entries() -> Error:
	var save := ConfigFile.new()
	save.set_value("journal", "version", 1)
	save.set_value("journal", "entries", _entries)
	var error := save.save(SAVE_PATH + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	if error == OK:
		changed.emit()
	return error
