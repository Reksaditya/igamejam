extends Node

const SAVE_PATH := "user://game_save.cfg"
const SAVE_VERSION := 3
const INITIAL_SCENE := "res://scenes/movement/dorm_room210.tscn"
const COURTYARD_SCENE := "res://scenes/movement/top_down_movement.tscn"
const DESKTOP_RETURN_CONTEXT := &"desktop_return_context"
const DORM_SCENE := "res://scenes/movement/dorm_room210.tscn"
const DESKTOP_SCENE := "res://scenes/interaction/desktop/desktop.tscn"
const WORKSHOP_SCENE := "res://scenes/interaction/workshop/transmission_workshop.tscn"
const WORLD_SCENES := [COURTYARD_SCENE, "res://scenes/movement/campus_lab.tscn", "res://scenes/movement/campus_classroom.tscn", "res://scenes/movement/campus_lab_room.tscn", "res://scenes/movement/dorm_exterior.tscn", "res://scenes/movement/dorm_floor1.tscn", "res://scenes/movement/dorm_floor2.tscn", DORM_SCENE, "res://scenes/movement/lecturer_room.tscn", "res://scenes/movement/classroom_corridor_floor1.tscn", "res://scenes/movement/classroom_corridor_floor2.tscn", "res://scenes/movement/classroom_corridor_floor3.tscn", "res://scenes/movement/campus_classroom_floor2.tscn", "res://scenes/movement/campus_classroom_floor3.tscn"]
const ROOT_FILES := ["classroom_notes.cfg", "blueprint_progress.cfg", "player_journal.cfg", "career_progress.cfg", "classroom_classroom_midterm_week_8.cfg", "classroom_classroom_final_week_16.cfg",
	"blueprint_progress.cfg.bak", "transmission_progress.cfg", "transmission_progress.cfg.bak",
	"study_notes.cfg", "study_notes.cfg.bak", "workshop_progress.cfg", "workshop_progress.cfg.bak",
	"chapter_timeline.cfg", "chapter_timeline.cfg.bak", "tutorials.cfg"]

var last_save_error: Error = OK
var _enabled: bool = false
var _busy: bool = false
var _queued: bool = false
var _elapsed: float = 0.0
var _resume_scene: String = INITIAL_SCENE
var _world_scene: String = INITIAL_SCENE
var _position := Vector2(320, 592)
var _facing: float = 1.0
var _restore_position: bool = false
var _desktop_return_spawn: StringName


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	get_tree().scene_changed.connect(_on_scene_changed)
	SceneTransition.transition_finished.connect(_on_transition_finished)
	ClassroomProgress.changed.connect(request_autosave)
	BlueprintProgress.changed.connect(request_autosave)
	ProjectBlueprints.changed.connect(request_autosave)
	StudyNotes.notes_changed.connect(func(_id: String) -> void: request_autosave())
	StudyNotes.keyword_discovered.connect(func(_id: String) -> void: request_autosave())
	PlayerStats.changed.connect(request_autosave)
	PlayerJournal.changed.connect(request_autosave)
	CareerProgress.changed.connect(request_autosave)


func _process(delta: float) -> void:
	if not _enabled or _busy:
		return
	_elapsed += delta
	if _elapsed >= 2.0:
		_elapsed = 0.0
		save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()
		get_tree().quit()


func register_world(world: Node2D, player: CharacterBody2D) -> void:
	if _restore_position and world.scene_file_path == _world_scene:
		if world.has_method("restore_player_position"):
			world.restore_player_position(player, _position)
		else:
			player.position = _position
		var visual := player.get_node("Visual") as Node2D
		visual.scale.x = absf(visual.scale.x) * _facing
		_restore_position = false
	_world_scene = world.scene_file_path
	_desktop_return_spawn = &""
	_resume_scene = _world_scene
	_position = player.position
	_enabled = true
	request_autosave()


func open_desktop_from(room: Node, spawn: StringName) -> bool:
	if room != get_tree().current_scene or room.scene_file_path not in WORLD_SCENES or SceneTransition.is_active():
		return false
	if not room.get_node_or_null(NodePath(spawn)) is Marker2D:
		return false
	save_now()
	_world_scene = room.scene_file_path
	_desktop_return_spawn = spawn
	_set_desktop_return_context()
	SceneTransition.change_scene(DESKTOP_SCENE, &"")
	return true


func _set_desktop_return_context() -> void:
	get_tree().set_meta(DESKTOP_RETURN_CONTEXT, {"scene": _world_scene, "spawn": _desktop_return_spawn})


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == DESKTOP_SCENE and not _desktop_return_spawn.is_empty():
		_resume_scene = DESKTOP_SCENE
		request_autosave()


func _on_transition_finished(error: Error) -> void:
	if error != OK and get_tree().has_meta(DESKTOP_RETURN_CONTEXT):
		_clear_spawn()
		_desktop_return_spawn = &""
	if error == OK:
		if _resume_scene == DESKTOP_SCENE:
			save_now()
		else:
			request_autosave()


func request_autosave() -> void:
	if not _enabled or _busy or _queued:
		return
	_queued = true
	_flush.call_deferred()


func _flush() -> void:
	_queued = false
	save_now()


func has_save() -> bool:
	return _read_snapshot() != null


func get_return_world() -> String:
	return _world_scene


func save_now() -> Error:
	var scene := get_tree().current_scene
	if not _enabled or _busy or SceneTransition.is_active() or scene == null:
		return ERR_UNAVAILABLE
	if scene.scene_file_path in WORLD_SCENES:
		if scene.get("_transitioning") == true:
			return ERR_BUSY
		var player := scene.get_node_or_null("Player") as CharacterBody2D
		if player == null:
			return ERR_UNAVAILABLE
		_world_scene = scene.scene_file_path
		_resume_scene = _world_scene
		_position = scene.get_player_save_position(player) if scene.has_method("get_player_save_position") else Vector2(clampf(player.position.x, 80.0, 1840.0), clampf(player.position.y, 0.0, 592.0))
		_facing = signf((player.get_node("Visual") as Node2D).scale.x)
	elif scene.scene_file_path == DESKTOP_SCENE:
		if _resume_scene != DESKTOP_SCENE or not scene.has_return_destination():
			return ERR_UNAVAILABLE
	elif scene.scene_file_path != WORKSHOP_SCENE:
		return ERR_UNAVAILABLE
	var files := _collect_files()
	if last_save_error != OK:
		return last_save_error
	var snapshot := _make_snapshot(GameClock.get_save_state(), files)
	last_save_error = snapshot.save(SAVE_PATH + ".tmp")
	if last_save_error == OK:
		last_save_error = DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	return last_save_error


func start_new_game(player_name: String = "Yohan") -> Error:
	if player_name.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	var stats := PlayerStats.make_new_state(player_name)
	_busy = true
	var previous_scene := _resume_scene
	var previous_world := _world_scene
	var previous_position := _position
	var previous_facing := _facing
	var previous_spawn := _desktop_return_spawn
	_desktop_return_spawn = &""
	_resume_scene = INITIAL_SCENE
	_world_scene = INITIAL_SCENE
	_position = Vector2(400, 400)
	_facing = 1.0
	var clock := {"minutes": GameClock.MORNING_MINUTES, "remainder": 0}
	var snapshot := _make_snapshot(clock, {}, stats)
	var error := _replace_files({"game_save.cfg": snapshot.encode_to_text()}, true)
	if error != OK:
		_resume_scene = previous_scene
		_world_scene = previous_world
		_position = previous_position
		_facing = previous_facing
		_desktop_return_spawn = previous_spawn
		_busy = false
		return error
	ClassroomProgress.reload_progress()
	BlueprintProgress.reload_progress()
	StudyNotes.reload_progress()
	PlayerJournal.reload_progress()
	CareerProgress.reload_progress()
	GameSettings.reload_tutorials()
	ProjectBlueprints.changed.emit()
	PlayerStats.restore_save_state(stats)
	GameClock.restore_save_state(clock)
	_clear_spawn()
	_restore_position = false
	_enabled = true
	_busy = false
	get_tree().paused = false
	return get_tree().change_scene_to_file(INITIAL_SCENE)


func load_game(allow_legacy: bool = false) -> Error:
	var snapshot := _read_snapshot()
	if snapshot == null:
		if not allow_legacy:
			return ERR_FILE_CORRUPT
		_resume_scene = INITIAL_SCENE
		_world_scene = INITIAL_SCENE
		_position = Vector2(320, 592)
		_facing = 1.0
		var legacy_files := _collect_files()
		if last_save_error != OK:
			return last_save_error
		GameClock.resume_timeline()
		snapshot = _make_snapshot(GameClock.get_save_state(), legacy_files)
	_busy = true
	var files: Dictionary = {}
	if snapshot.has_section("files"):
		for path: String in snapshot.get_section_keys("files"):
			files[path] = snapshot.get_value("files", path)
	var error := _replace_files(files, false)
	if error != OK:
		_busy = false
		return error
	_resume_scene = snapshot.get_value("world", "scene")
	_world_scene = snapshot.get_value("world", "world_scene")
	var legacy_spawn := &"ComputerSpawn" if _world_scene == DORM_SCENE else &""
	_desktop_return_spawn = StringName(snapshot.get_value("world", "desktop_return_spawn", legacy_spawn))
	_position = snapshot.get_value("world", "position")
	_facing = snapshot.get_value("world", "facing", 1.0)
	ClassroomProgress.reload_progress()
	BlueprintProgress.reload_progress()
	StudyNotes.reload_progress()
	PlayerJournal.reload_progress()
	CareerProgress.reload_progress()
	GameSettings.reload_tutorials()
	var stats := PlayerStats.DEFAULTS.duplicate()
	for key: String in stats:
		stats[key] = snapshot.get_value("profile", key, stats[key])
	PlayerStats.restore_save_state(stats)
	GameClock.restore_save_state({"minutes": snapshot.get_value("clock", "minutes"), "remainder": snapshot.get_value("clock", "remainder", 0)})
	_clear_spawn()
	_restore_position = _resume_scene in WORLD_SCENES
	_enabled = true
	_busy = false
	get_tree().paused = false
	if _resume_scene == DESKTOP_SCENE:
		_set_desktop_return_context()
	var change_error := get_tree().change_scene_to_file(_resume_scene)
	if change_error != OK:
		_clear_spawn()
	return change_error


func _clear_spawn() -> void:
	if get_tree().has_meta(&"side_scroller_spawn"):
		get_tree().remove_meta(&"side_scroller_spawn")
	if get_tree().has_meta(DESKTOP_RETURN_CONTEXT):
		get_tree().remove_meta(DESKTOP_RETURN_CONTEXT)


func _make_snapshot(clock: Dictionary, files: Dictionary, stats: Dictionary = {}) -> ConfigFile:
	var snapshot := ConfigFile.new()
	snapshot.set_value("save", "version", SAVE_VERSION)
	var profile := PlayerStats.get_save_state() if stats.is_empty() else stats
	for key: String in profile:
		snapshot.set_value("profile", key, profile[key])
	snapshot.set_value("world", "scene", _resume_scene)
	snapshot.set_value("world", "world_scene", _world_scene)
	snapshot.set_value("world", "position", _position)
	snapshot.set_value("world", "facing", _facing)
	snapshot.set_value("world", "desktop_return_spawn", str(_desktop_return_spawn))
	snapshot.set_value("clock", "minutes", clock.minutes)
	snapshot.set_value("clock", "remainder", clock.remainder)
	for path: String in files:
		snapshot.set_value("files", path, files[path])
	return snapshot


func _read_snapshot() -> ConfigFile:
	var snapshot := ConfigFile.new()
	if snapshot.load(SAVE_PATH) != OK or snapshot.get_value("save", "version", 0) not in [1, 2, SAVE_VERSION]:
		return null
	var scene: Variant = snapshot.get_value("world", "scene", "")
	var world: Variant = snapshot.get_value("world", "world_scene", "")
	var position: Variant = snapshot.get_value("world", "position", null)
	var minutes: Variant = snapshot.get_value("clock", "minutes", null)
	var remainder: Variant = snapshot.get_value("clock", "remainder", 0)
	var facing: Variant = snapshot.get_value("world", "facing", 1.0)
	if not scene is String or (scene not in WORLD_SCENES and scene != DESKTOP_SCENE) or world not in WORLD_SCENES:
		return null
	var desktop_spawn: Variant = snapshot.get_value("world", "desktop_return_spawn", "")
	if not desktop_spawn is String or (not desktop_spawn.is_empty() and not desktop_spawn.is_valid_identifier()):
		return null
	if not position is Vector2 or not position.is_finite() or position.x < 80.0 or position.x > 1840.0 or position.y < 0.0 or position.y > 592.0:
		return null
	if not minutes is int or minutes < 0 or not remainder is int or remainder < 0 or remainder >= 60000:
		return null
	if (not facing is float and not facing is int) or (facing != -1.0 and facing != 1.0):
		return null
	if snapshot.has_section("files"):
		for path: String in snapshot.get_section_keys("files"):
			if not _is_gameplay_path(path) or not snapshot.get_value("files", path) is String:
				return null
	return snapshot


func _is_gameplay_path(path: String) -> bool:
	if path.is_absolute_path() or path.contains("\\") or path.simplify_path() != path or path.contains(".."):
		return false
	return path in ROOT_FILES or ((path.begins_with("lms_results/") or path.begins_with("career_drafts/")) and path.get_extension() == "cfg") or (path.begins_with("notes/") and path.get_extension() == "txt")


func _collect_files() -> Dictionary:
	var files: Dictionary = {}
	last_save_error = OK
	for path: String in _gameplay_paths():
		var file := FileAccess.open("user://" + path, FileAccess.READ)
		if file == null:
			last_save_error = FileAccess.get_open_error()
			return {}
		var content := file.get_as_text()
		var error := file.get_error()
		file.close()
		if error != OK and error != ERR_FILE_EOF:
			last_save_error = error
			return {}
		files[path] = content
	return files


func _gameplay_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for path: String in ROOT_FILES:
		if FileAccess.file_exists("user://" + path):
			paths.append(path)
	for directory: String in ["lms_results", "notes", "career_drafts"]:
		_scan_directory(directory, paths)
	return paths


func _scan_directory(path: String, paths: PackedStringArray) -> void:
	var directory := DirAccess.open("user://" + path)
	if directory == null:
		return
	for filename: String in directory.get_files():
		var child := path.path_join(filename)
		if _is_gameplay_path(child):
			paths.append(child)
	for child: String in directory.get_directories():
		_scan_directory(path.path_join(child), paths)


func _replace_files(files: Dictionary, include_checkpoint: bool) -> Error:
	var backup := "user://.reset_backup_%d" % Time.get_ticks_usec()
	var paths := _gameplay_paths()
	if include_checkpoint and FileAccess.file_exists(SAVE_PATH):
		paths.append("game_save.cfg")
	var moved := PackedStringArray()
	var written := PackedStringArray()
	var error: Error = OK
	for path: String in paths:
		error = DirAccess.make_dir_recursive_absolute(backup.path_join(path).get_base_dir())
		if error == OK:
			error = DirAccess.rename_absolute("user://" + path, backup.path_join(path))
		if error != OK:
			break
		moved.append(path)
	if error == OK:
		for path: String in files:
			error = DirAccess.make_dir_recursive_absolute(("user://" + path).get_base_dir())
			if error != OK:
				break
			var file := FileAccess.open("user://" + path, FileAccess.WRITE)
			if file == null:
				error = FileAccess.get_open_error()
				break
			written.append(path)
			var stored := file.store_string(files[path])
			file.flush()
			error = file.get_error() if stored else ERR_FILE_CANT_WRITE
			file.close()
			if error != OK:
				break
	if error != OK:
		for path: String in written:
			DirAccess.remove_absolute("user://" + path)
		for path: String in moved:
			DirAccess.rename_absolute(backup.path_join(path), "user://" + path)
	else:
		_remove_backup(backup)
	return error


func _remove_backup(path: String) -> void:
	if not path.begins_with("user://.reset_backup_") or path.contains(".."):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	for child: String in directory.get_directories():
		_remove_backup(path.path_join(child))
	DirAccess.remove_absolute(path)
