extends Node

signal changed

const Curriculum = preload("res://scripts/academic/curriculum.gd")
const SAVE_PATH := "user://career_progress.cfg"
const COSTS := {"class": 15.0, "tugas": 5.0, "kuis": 5.0, "uts": 30.0, "uas": 30.0, "project": 20.0, "study": 5.0}
const WEIGHTS := {"tugas": 0.10, "kuis": 0.15, "uts": 0.225, "uas": 0.225, "project": 0.30}

var state: Dictionary = {}
var _active_semester: int = 1


func _ready() -> void:
	reload_progress()
	_active_semester = semester()
	GameClock.minute_changed.connect(_on_time_changed)


func reload_progress() -> void:
	state = {"classes": {}, "results": {}, "pieces": {}, "placed": {}, "assembled": {}, "charged": {}, "flags": {}, "ending": ""}
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) == OK and save.get_value("career", "version", 0) == 1:
		for key: String in state:
			var value: Variant = save.get_value("career", key, state[key])
			if typeof(value) == typeof(state[key]):
				state[key] = value
	changed.emit()


func semester() -> int:
	return Curriculum.semester_at(GameClock.get_week())


func week() -> int:
	return Curriculum.week_at(GameClock.get_week())


func key_for(term: int, study_week: int) -> String:
	return "s%d_w%d" % [term, study_week]


func class_data(term: int, study_week: int) -> Dictionary:
	return state.classes.get(key_for(term, study_week), {"attempted": [], "complete": [], "finished": false}).duplicate(true)


func begin_activity(kind: String, id: String) -> Error:
	if not COSTS.has(kind):
		return ERR_INVALID_PARAMETER
	if state.charged.has(id):
		return OK
	if PlayerStats.get_energy() < COSTS[kind] and not (kind == "class" and PlayerStats.get_energy() <= 0):
		return ERR_UNAVAILABLE
	var previous := state.duplicate(true)
	state.charged[id] = true
	var error := _save(previous)
	if error == OK:
		PlayerStats.set_energy(PlayerStats.get_energy() - COSTS[kind])
		PlayerStats.set_sanity(PlayerStats.get_sanity() + 10.0)
	return error


func attempt_section(term: int, study_week: int, index: int) -> Error:
	if index < 0 or index > 2 or study_week in [8, 16]:
		return ERR_INVALID_PARAMETER
	var data := class_data(term, study_week)
	if data.attempted.has(index):
		return ERR_ALREADY_EXISTS
	var previous := state.duplicate(true)
	data.attempted.append(index)
	state.classes[key_for(term, study_week)] = data
	return _save(previous)


func finish_section(term: int, study_week: int, index: int, success: bool) -> Error:
	var data := class_data(term, study_week)
	if not data.attempted.has(index) or data.finished:
		return ERR_UNAUTHORIZED
	var previous := state.duplicate(true)
	if success and not data.complete.has(index):
		data.complete.append(index)
	state.classes[key_for(term, study_week)] = data
	return _save(previous)


func finish_class(term: int, study_week: int) -> Error:
	var data := class_data(term, study_week)
	if data.attempted.size() != 3:
		return ERR_UNAUTHORIZED
	var previous := state.duplicate(true)
	data.finished = true
	state.classes[key_for(term, study_week)] = data
	if data.complete.size() == 3:
		_grant_piece(term, study_week)
	var error := _save(previous)
	if error == OK:
		error = _journal_class(term, study_week)
	return error


func review_class(term: int, study_week: int, keyword: String) -> Error:
	var data := class_data(term, study_week)
	var lesson := Curriculum.lesson(term, study_week)
	var past_week := (term - 1) * 16 + study_week < GameClock.get_week()
	if (not data.finished and not past_week) or study_week in [8, 16] or keyword.strip_edges().to_lower() != lesson.keyword.to_lower():
		return ERR_UNAUTHORIZED
	var error := begin_activity("study", "review_" + key_for(term, study_week))
	if error != OK:
		return error
	var previous := state.duplicate(true)
	data.complete = [0, 1, 2]
	data.attempted = [0, 1, 2]
	data.finished = true
	state.classes[key_for(term, study_week)] = data
	_grant_piece(term, study_week)
	error = _save(previous)
	if error == OK:
		error = _journal_class(term, study_week)
	return error


func _grant_piece(term: int, study_week: int) -> void:
	var id := str(term)
	var pieces: Array = state.pieces.get(id, []).duplicate()
	var index := (study_week - 1 if study_week < 8 else study_week - 2) % 9
	if not pieces.has(index):
		pieces.append(index)
	state.pieces[id] = pieces


func place_piece(term: int, piece: int, slot: int) -> Error:
	var id := str(term)
	var placed: Array = state.placed.get(id, []).duplicate()
	if piece != slot or not state.pieces.get(id, []).has(piece) or placed.has(slot):
		return ERR_INVALID_PARAMETER
	var previous := state.duplicate(true)
	placed.append(slot)
	state.placed[id] = placed
	return _save(previous)


func blueprint_ready(term: int) -> bool:
	return state.placed.get(str(term), []).size() == 9


func assemble_component(term: int, component: int) -> Error:
	if not blueprint_ready(term):
		return ERR_UNAUTHORIZED
	if term == 8 and not state.flags.has("final_design"):
		return ERR_UNAUTHORIZED
	var assembled: Array = state.assembled.get(str(term), []).duplicate()
	if component != assembled.size() or component >= 6:
		return ERR_INVALID_PARAMETER
	var error := begin_activity("project", "project_s%d" % term)
	if error != OK:
		return error
	var previous := state.duplicate(true)
	assembled.append(component)
	state.assembled[str(term)] = assembled
	error = _save(previous)
	if error == OK and assembled.size() == 6:
		error = PlayerJournal.record_project("machine_s%d" % term, "Mesin semester %d · %s" % [term, Curriculum.COURSES[term - 1][1]], (term - 1) * 16 + week())
	return error


func result_id(term: int, study_week: int, kind: String) -> String:
	return "%s_%s" % [key_for(term, study_week), kind]


func record_result(term: int, study_week: int, kind: String, score: float) -> Error:
	if not WEIGHTS.has(kind) or not is_finite(score) or term < 1 or term > 8 or study_week < 1 or study_week > 16:
		return ERR_INVALID_PARAMETER
	var id := result_id(term, study_week, kind)
	if state.results.has(id):
		return ERR_ALREADY_EXISTS
	var previous := state.duplicate(true)
	state.results[id] = clampf(score, 0.0, 100.0)
	var error := _save(previous)
	if error == OK:
		recalculate_gpa()
	return error


func submit_project(term: int) -> Error:
	if state.assembled.get(str(term), []).size() != 6:
		return ERR_UNAUTHORIZED
	var failures: int = int(state.flags.get("project_failures_%d" % term, 0))
	return record_result(term, 16, "project", 100.0 - minf(40, failures * 5.0))


func record_project_failure(term: int) -> Error:
	var previous := state.duplicate(true)
	var key := "project_failures_%d" % term
	state.flags[key] = int(state.flags.get(key, 0)) + 1
	return _save(previous)


func set_final_design(values: Array[String]) -> Error:
	if values.size() != 3 or values[0] not in ["Engkol", "Cam", "Roda gigi"] or values[1] not in ["Sensor", "Saklar"] or values[2] not in ["Baterai", "Baterai dan saklar"]:
		return ERR_INVALID_PARAMETER
	if state.flags.has("final_design"):
		return ERR_ALREADY_EXISTS
	var previous := state.duplicate(true)
	state.flags.final_design = values
	return _save(previous)


func semester_grade(term: int) -> float:
	var tugas := 0.0
	var kuis := 0.0
	for study_week: int in range(1, 17):
		tugas += float(state.results.get(result_id(term, study_week, "tugas"), 0.0)) / 16.0
		kuis += float(state.results.get(result_id(term, study_week, "kuis"), 0.0)) / 16.0
	return (tugas * WEIGHTS.tugas + kuis * WEIGHTS.kuis + float(state.results.get(result_id(term, 8, "uts"), 0.0)) * WEIGHTS.uts + float(state.results.get(result_id(term, 16, "uas"), 0.0)) * WEIGHTS.uas + float(state.results.get(result_id(term, 16, "project"), 0.0)) * WEIGHTS.project) / 25.0


func recalculate_gpa() -> void:
	var terms := semester()
	var total := 0.0
	for term: int in range(1, terms + 1):
		total += semester_grade(term)
	PlayerStats.set_gpa(total / terms)


func _on_time_changed(_minutes: int) -> void:
	if semester() != _active_semester:
		_active_semester = semester()
		recalculate_gpa()


func rest(hours: int) -> Error:
	if hours not in [1, 8]:
		return ERR_INVALID_PARAMETER
	var previous := state.duplicate(true)
	var hour := float(GameClock.get_absolute_minutes() % 1440) / 60.0
	var late := maxf(0, hour - 22.0) if hour >= 6 else hour + 2.0
	var debt: int = int(state.flags.get("sleep_debt", 0))
	debt = maxi(0, debt - 8) if hours == 8 else mini(10, debt + 1)
	state.flags.sleep_debt = debt
	var error := _save(previous)
	if error != OK:
		return error
	PlayerStats.set_energy(maxf(0, 100.0 - late * 10.0 - debt * 5.0) if hours == 8 else minf(100.0 - debt * 5.0, PlayerStats.get_energy() + 10.0))
	PlayerStats.set_sanity(50)
	GameClock.advance_minutes(hours * 60)
	recalculate_gpa()
	return OK


func can_advance_week() -> bool:
	var term := semester()
	var study_week := week()
	for kind: String in ["tugas", "kuis"]:
		if not state.results.has(result_id(term, study_week, kind)):
			return false
	if study_week in [8, 16]:
		return state.results.has(result_id(term, study_week, "uts" if study_week == 8 else "uas"))
	return class_data(term, study_week).finished


func advance_week() -> Error:
	if not can_advance_week():
		return ERR_UNAUTHORIZED
	var previous := state.duplicate(true)
	state.flags.sleep_debt = 0
	var error := _save(previous)
	if error != OK:
		return error
	PlayerStats.set_energy(100)
	PlayerStats.set_sanity(50)
	GameClock.advance_minutes(GameClock.get_week() * 7 * 1440 + 360 - GameClock.get_absolute_minutes())
	return OK


func pending_story() -> String:
	if not state.flags.has("story_intro"):
		return "intro"
	if semester() >= 3 and not state.flags.has("story_busy"):
		return "busy"
	if GameClock.get_week() >= 72 and not state.flags.has("story_loss"):
		return "loss"
	if semester() >= 6 and not state.flags.has("story_promise"):
		return "promise"
	return ""


func acknowledge_story(id: String) -> Error:
	if id not in ["intro", "busy", "loss", "promise"]:
		return ERR_INVALID_PARAMETER
	var key := "story_" + id
	if state.flags.has(key):
		return ERR_ALREADY_EXISTS
	var previous := state.duplicate(true)
	state.flags[key] = true
	var error := _save(previous)
	if error == OK and id == "loss":
		PlayerStats.set_energy(PlayerStats.get_energy() - 40)
		PlayerStats.set_sanity(PlayerStats.get_sanity() + 40)
	elif error == OK and id == "promise":
		PlayerStats.set_energy(PlayerStats.get_energy() + 20)
		PlayerStats.set_sanity(50)
	return error


func should_graduate() -> bool:
	return GameClock.get_week() > 128 or (semester() == 8 and week() == 16 and state.results.has("s8_w16_uas") and state.results.has("s8_w16_project"))


static func ending_for(gpa: float, final_passed: bool) -> String:
	if not final_passed:
		return "bad"
	return "happy" if gpa >= 3.5 else "basic"


func complete_career() -> Error:
	if not should_graduate():
		return ERR_UNAUTHORIZED
	if not state.ending.is_empty():
		return OK
	recalculate_gpa()
	var previous := state.duplicate(true)
	var final_passed := float(state.results.get("s8_w16_project", 0.0)) >= 60.0
	state.ending = ending_for(PlayerStats.get_gpa(), final_passed)
	state.flags.graduation_gpa = PlayerStats.get_gpa()
	return _save(previous)


func _journal_class(term: int, study_week: int) -> Error:
	var data := class_data(term, study_week)
	var lesson := Curriculum.lesson(term, study_week)
	var lines := PackedStringArray()
	for index: int in 3:
		lines.append(lesson.sections[index] if data.complete.has(index) else "________________ (catatan kosong)")
	return PlayerJournal.record_entry("notes", "career_" + key_for(term, study_week), lesson.title, "\n\n".join(lines), (term - 1) * 16 + study_week)


func _save(previous: Dictionary) -> Error:
	var save := ConfigFile.new()
	save.set_value("career", "version", 1)
	for key: String in state:
		save.set_value("career", key, state[key])
	var error := save.save(SAVE_PATH + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	if error != OK:
		state = previous
	else:
		changed.emit()
	return error
