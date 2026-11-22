extends Node

signal changed
signal semester_evaluated(term: int, summary: Dictionary)
signal class_missed(term: int, day_in_sem: int)

const Curriculum = preload("res://scripts/academic/curriculum.gd")
const SAVE_PATH := "user://career_progress.cfg"
const SAVE_VERSION := 2
const CLASS_START_MINUTES := 8 * 60
const CLASS_LATE_CUTOFF_MINUTES := 9 * 60

## GDD Section 4.4 Energi costs per activity.
const COSTS := {
	"class": 15.0,
	"tugas": 5.0,
	"kuis": 5.0,
	"uts": 30.0,
	"uas": 30.0,
	"project": 20.0,
}

## Exact Semester Final Score weights (sum = 100%, split Blueprint 15% Midterm + 15% Final = 30%).
const WEIGHTS := {
	"tugas": 0.10,
	"kuis": 0.15,
	"uts": 0.225,
	"uas": 0.225,
	"blueprint_midterm": 0.15,
	"blueprint_final": 0.15,
}

const SANITY_NORMAL := 50.0
const SANITY_ACTIVITY_GAIN := 10.0
const SANITY_BLUR_THRESHOLD := 80.0

var state: Dictionary = {}
var _active_day: int = 1


func _ready() -> void:
	reload_progress()
	_active_day = GameClock.get_day()
	GameClock.minute_changed.connect(_on_time_changed)


func reload_progress() -> void:
	state = {
		"classes": {},
		"results": {},
		"blueprints": {},
		"blueprints_completed": {},
		"charged": {},
		"evaluated_semesters": {},
		"pending_khs": 0,
		"flags": {},
		"ending": "",
	}
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) == OK and save.get_value("career", "version", 0) == SAVE_VERSION:
		for key: String in state:
			var value: Variant = save.get_value("career", key, state[key])
			if typeof(value) == typeof(state[key]):
				state[key] = value
	recalculate_gpa()
	changed.emit()


func semester() -> int:
	return Curriculum.semester_for_day(GameClock.get_day())


func day_in_semester() -> int:
	return Curriculum.day_in_semester(GameClock.get_day())


func half() -> int:
	return Curriculum.half_for_day(day_in_semester())


## Backwards-compatible alias: returns current day within the 12-day semester (1..12).
func week() -> int:
	return day_in_semester()


func key_for(term: int, day_in_sem: int) -> String:
	return "s%d_d%d" % [term, day_in_sem]


func half_result_id(term: int, part: int, kind: String) -> String:
	return "s%d_h%d_%s" % [term, part, kind]


func result_id(term: int, slot: int, kind: String) -> String:
	if kind in ["tugas", "kuis"]:
		var part := slot if slot in [1, 2] else Curriculum.half_for_day(slot)
		return half_result_id(term, part, kind)
	if kind == "uts" or kind == "blueprint_midterm":
		return "s%d_d%d_%s" % [term, Curriculum.MIDTERM_DAY, kind]
	if kind == "uas" or kind == "blueprint_final":
		return "s%d_d%d_%s" % [term, Curriculum.FINAL_DAY, kind]
	return "%s_%s" % [key_for(term, slot), kind]


func class_data(term: int, day_in_sem: int) -> Dictionary:
	var data: Dictionary = state.classes.get(key_for(term, day_in_sem), {"attempted": [], "complete": [], "finished": false, "missed": false}).duplicate(true)
	if not data.has("missed"):
		data["missed"] = false
	return data


func is_class_missed(term: int, day_in_sem: int) -> bool:
	if not _is_lesson(term, day_in_sem):
		return false
	var data := class_data(term, day_in_sem)
	if data.finished:
		return false
	if data.get("missed", false) == true:
		return true
	var abs_day := Curriculum.absolute_day_for(term, day_in_sem)
	var current_day := GameClock.get_day()
	if abs_day < current_day:
		return true
	if abs_day == current_day:
		var minute_of_day := posmod(GameClock.get_absolute_minutes(), GameClock.MINUTES_PER_DAY)
		return minute_of_day >= CLASS_LATE_CUTOFF_MINUTES
	return false


func can_enter_class(term: int, day_in_sem: int) -> bool:
	if day_in_sem == Curriculum.MIDTERM_DAY or day_in_sem == Curriculum.FINAL_DAY:
		return true
	if not _is_lesson(term, day_in_sem):
		return true
	var data := class_data(term, day_in_sem)
	if data.finished:
		return true
	return not is_class_missed(term, day_in_sem)


func check_class_attendance_cutoff() -> bool:
	var term := semester()
	var day := day_in_semester()
	if not _is_lesson(term, day):
		return false
	var data := class_data(term, day)
	if data.finished or data.get("missed", false) == true:
		return false
	var minute_of_day := posmod(GameClock.get_absolute_minutes(), GameClock.MINUTES_PER_DAY)
	if minute_of_day < CLASS_LATE_CUTOFF_MINUTES:
		return false
	var previous := state.duplicate(true)
	data["missed"] = true
	state.classes[key_for(term, day)] = data
	var error := _save(previous)
	if error == OK:
		class_missed.emit(term, day)
		return true
	return false


func get_today_schedule_status() -> Dictionary:
	var term := semester()
	var day := day_in_semester()
	var minute_of_day := posmod(GameClock.get_absolute_minutes(), GameClock.MINUTES_PER_DAY)
	if day == Curriculum.MIDTERM_DAY or day == Curriculum.FINAL_DAY:
		var is_midterm := day == Curriculum.MIDTERM_DAY
		var exam_kind := "uts" if is_midterm else "uas"
		var exam_label := "UTS" if is_midterm else "UAS"
		var done: bool = state.results.has(result_id(term, day, exam_kind))
		return {
			"state": "exam_done" if done else "exam_ready",
			"badge": "UJIAN SELESAI" if done else "HARI UJIAN",
			"title": "%s Semester %d tuntas" % [exam_label, term] if done else "Ujian %s · Ruang Kelas" % exam_label,
			"detail": "Istirahat di Kamar 203 untuk lanjut" if done else "Masuk kelas & dekati komputer ujian",
			"semester": term,
			"day_in_semester": day,
			"can_enter": true,
		}
	var data := class_data(term, day)
	var lesson := Curriculum.lesson(term, day)
	if data.finished:
		return {
			"state": "class_done",
			"badge": "KELAS SELESAI",
			"title": "Kelas hari ini tuntas",
			"detail": "Cek LMS/Project di PC atau rakit di Lab",
			"semester": term,
			"day_in_semester": day,
			"can_enter": true,
		}
	if is_class_missed(term, day):
		return {
			"state": "class_missed",
			"badge": "KELAS TERLEWAT",
			"title": "Terlambat > 1 jam (Batas 09:00)",
			"detail": "Kejar catatan di Perpustakaan (PC)",
			"semester": term,
			"day_in_semester": day,
			"can_enter": false,
		}
	if minute_of_day >= CLASS_START_MINUTES:
		var remaining := maxi(1, CLASS_LATE_CUTOFF_MINUTES - minute_of_day)
		return {
			"state": "class_open",
			"badge": "KELAS DIBUKA",
			"title": "Segera ke Kelas · Sisa %d mnt" % remaining,
			"detail": "%s · Tutup 09:00" % lesson.title,
			"semester": term,
			"day_in_semester": day,
			"can_enter": true,
		}
	return {
		"state": "class_upcoming",
		"badge": "JADWAL KELAS",
		"title": "Kelas 08:00 · Batas 09:00",
		"detail": lesson.title,
		"semester": term,
		"day_in_semester": day,
		"can_enter": true,
	}


## GDD 4.4: Charges Energi once per unique activity id and adds +10 Kewarasan.
## Class is allowed even when Energi <= 0 (player falls asleep in class and misses material).
## Projects and assessments require Energi > 0 and sufficient Energi for the activity.
func begin_activity(kind: String, id: String) -> Error:
	if not COSTS.has(kind):
		return ERR_INVALID_PARAMETER
	if state.charged.has(id):
		return OK
	var cost: float = COSTS[kind]
	var current_energy := PlayerStats.get_energy()
	if kind == "project" and current_energy <= 0.0:
		return ERR_UNAVAILABLE
	if current_energy < cost and not (kind == "class" and current_energy <= 0.0):
		return ERR_UNAVAILABLE
	var previous := state.duplicate(true)
	state.charged[id] = true
	var error := _save(previous)
	if error == OK:
		PlayerStats.set_energy(current_energy - cost)
		PlayerStats.set_sanity(PlayerStats.get_sanity() + SANITY_ACTIVITY_GAIN)
	return error


func attempt_section(term: int, day_in_sem: int, index: int) -> Error:
	if index < 0 or index > 2 or not _is_lesson(term, day_in_sem):
		return ERR_INVALID_PARAMETER
	var data := class_data(term, day_in_sem)
	if data.attempted.has(index):
		return ERR_ALREADY_EXISTS
	var previous := state.duplicate(true)
	data.attempted.append(index)
	state.classes[key_for(term, day_in_sem)] = data
	return _save(previous)


func finish_section(term: int, day_in_sem: int, index: int, success: bool) -> Error:
	var data := class_data(term, day_in_sem)
	if not data.attempted.has(index) or data.finished:
		return ERR_UNAUTHORIZED
	var previous := state.duplicate(true)
	if success and not data.complete.has(index):
		data.complete.append(index)
	state.classes[key_for(term, day_in_sem)] = data
	return _save(previous)


func finish_class(term: int, day_in_sem: int) -> Error:
	var data := class_data(term, day_in_sem)
	if not _is_lesson(term, day_in_sem) or data.attempted.size() != 3:
		return ERR_UNAUTHORIZED
	return _save_completed_lesson(term, day_in_sem, data)


func review_details(term: int, day_in_sem: int) -> Dictionary:
	if not _is_lesson(term, day_in_sem):
		return {}
	var data := class_data(term, day_in_sem)
	var abs_day := Curriculum.absolute_day_for(term, day_in_sem)
	var current_day := GameClock.get_day()
	if abs_day > current_day or (abs_day == current_day and not data.finished and not is_class_missed(term, day_in_sem)):
		return {}
	var missing := PackedInt32Array()
	for section: int in 3:
		if not data.complete.has(section):
			missing.append(section)
	var now := GameClock.get_absolute_minutes()
	var minutes := 0
	match missing.size():
		1: minutes = Curriculum.PROGRESSION.one_missing_minutes
		2: minutes = Curriculum.PROGRESSION.two_missing_minutes
		3: minutes = GameClock.MINUTES_PER_DAY - now % GameClock.MINUTES_PER_DAY + GameClock.MORNING_MINUTES
	return {"missing": missing, "minutes": minutes, "overnight": missing.size() == 3}


func review_class(term: int, day_in_sem: int, keyword: String) -> Error:
	var details := review_details(term, day_in_sem)
	if details.is_empty() or GameClock.is_activity_running():
		return ERR_UNAUTHORIZED
	var lesson := Curriculum.lesson(term, day_in_sem)
	if not details.missing.is_empty() and keyword.strip_edges().nocasecmp_to(lesson.keyword) != 0:
		return ERR_UNAUTHORIZED
	var data := class_data(term, day_in_sem)
	for section: int in details.missing:
		if not data.attempted.has(section):
			data.attempted.append(section)
		data.complete.append(section)
	var error := _save_completed_lesson(term, day_in_sem, data)
	if error == OK and details.minutes > 0:
		GameClock.advance_minutes(details.minutes)
	return error


func _is_lesson(term: int, day_in_sem: int) -> bool:
	return term >= 1 and term <= Curriculum.SEMESTER_COUNT and Curriculum.is_lesson_day(day_in_sem)


func _save_completed_lesson(term: int, day_in_sem: int, data: Dictionary) -> Error:
	var key := key_for(term, day_in_sem)
	data.finished = true
	var blueprint_id := Curriculum.blueprint_for_lesson(term, day_in_sem)
	var granted: bool = data.complete.size() == 3 and not blueprint_id.is_empty() and not ProjectBlueprints.is_owned(blueprint_id)
	if not granted and state.classes.get(key) == data:
		return OK
	var previous := state.duplicate(true)
	state.classes[key] = data
	if granted:
		state.blueprints[blueprint_id] = true
	var error := _save(previous)
	if error != OK:
		return error
	if granted:
		ProjectBlueprints.grant(blueprint_id)
	return OK


func can_read_blueprint(blueprint_id: String) -> bool:
	var info := Curriculum.blueprint_info(blueprint_id)
	if info.is_empty():
		return false
	return GameClock.get_day() >= int(info.absolute_unlock_day)


func owns_blueprint(blueprint_id: String) -> bool:
	return state.get("blueprints", {}).get(blueprint_id, false) == true


func is_blueprint_completed_on_time(blueprint_id: String) -> bool:
	return state.get("blueprints_completed", {}).get(blueprint_id, false) == true


func is_blueprint_overdue(blueprint_id: String) -> bool:
	var info := Curriculum.blueprint_info(blueprint_id)
	if info.is_empty():
		return false
	return GameClock.get_day() > int(info.absolute_deadline_day) and not is_blueprint_completed_on_time(blueprint_id)


func blueprint_deadline_text(blueprint_id: String) -> String:
	var info := Curriculum.blueprint_info(blueprint_id)
	if info.is_empty():
		return ""
	return "Tenggat: Sem %d · Hari %d" % [int(info.semester), int(info.deadline_day_in_semester)]


## Records completion of one of the 4 Workshop Blueprints (15% Midterm or 15% Final).
## Awards 100.0 (worth +15 points out of 100) if completed on or before its deadline day; 0.0 if overdue.
func complete_blueprint(blueprint_id: String) -> Error:
	var info := Curriculum.blueprint_info(blueprint_id)
	if info.is_empty():
		return ERR_INVALID_PARAMETER
	var term: int = int(info.semester)
	var slot_kind := "blueprint_" + str(info.slot)
	var deadline_day: int = int(info.absolute_deadline_day)
	var on_time := GameClock.get_day() <= deadline_day
	var id := result_id(term, int(info.deadline_day_in_semester), slot_kind)
	var previous := state.duplicate(true)
	state.blueprints[blueprint_id] = true
	if not state.results.has(id):
		state.results[id] = 100.0 if on_time else 0.0
	if on_time:
		state.blueprints_completed[blueprint_id] = true
	elif not state.blueprints_completed.has(blueprint_id):
		state.blueprints_completed[blueprint_id] = false
	var error := _save(previous)
	if error == OK:
		if on_time:
			PlayerJournal.record_project(
				"bp_" + blueprint_id,
				"%s · %s (Sem %d)" % [str(info.title), str(info.slot_label), term],
				GameClock.get_day()
			)
		recalculate_gpa()
	return error


func record_result(term: int, slot: int, kind: String, score: float) -> Error:
	if not WEIGHTS.has(kind) or not is_finite(score) or term < 1 or term > Curriculum.SEMESTER_COUNT:
		return ERR_INVALID_PARAMETER
	var id := result_id(term, slot, kind)
	if state.results.has(id):
		return ERR_ALREADY_EXISTS
	var previous := state.duplicate(true)
	state.results[id] = clampf(score, 0.0, 100.0)
	var error := _save(previous)
	if error == OK:
		recalculate_gpa()
	return error


func is_assessment_overdue(term: int, slot: int, kind: String) -> bool:
	var deadline_day := 0
	if kind in ["tugas", "kuis"]:
		var part := slot if slot in [1, 2] else Curriculum.half_for_day(slot)
		deadline_day = Curriculum.deadline_day_for_half(term, part)
	elif kind == "uts" or kind == "blueprint_midterm":
		deadline_day = Curriculum.deadline_day_for_half(term, 1)
	elif kind == "uas" or kind == "blueprint_final":
		deadline_day = Curriculum.deadline_day_for_half(term, 2)
	else:
		return false
	return GameClock.get_day() > deadline_day


func is_assessment_unlocked(term: int, slot: int, kind: String) -> bool:
	var unlock_day := 1
	if kind in ["tugas", "kuis"]:
		var part := slot if slot in [1, 2] else Curriculum.half_for_day(slot)
		unlock_day = Curriculum.absolute_day_for(term, 1 if part == 1 else Curriculum.MIDTERM_DAY + 1)
	elif kind == "uts":
		unlock_day = Curriculum.absolute_day_for(term, Curriculum.MIDTERM_DAY)
	elif kind == "uas":
		unlock_day = Curriculum.absolute_day_for(term, Curriculum.FINAL_DAY)
	return GameClock.get_day() >= unlock_day


static func letter_grade_for(score: float) -> String:
	if score >= 85.0:
		return "A"
	if score >= 75.0:
		return "B"
	if score >= 65.0:
		return "C"
	if score >= 50.0:
		return "D"
	return "E"


## Computes exact semester breakdown (0-100), Huruf Mutu (A-E), and IPS (0.00-4.00).
## Split Blueprints: Midterm = 15% (+15 pts), Final = 15% (+15 pts), total 30% (+30 pts).
func semester_breakdown(term: int) -> Dictionary:
	var t1: float = float(state.results.get(result_id(term, 1, "tugas"), 0.0))
	var t2: float = float(state.results.get(result_id(term, 2, "tugas"), 0.0))
	var k1: float = float(state.results.get(result_id(term, 1, "kuis"), 0.0))
	var k2: float = float(state.results.get(result_id(term, 2, "kuis"), 0.0))
	var tugas := (t1 + t2) * 0.5
	var kuis := (k1 + k2) * 0.5
	var uts: float = float(state.results.get(result_id(term, Curriculum.MIDTERM_DAY, "uts"), 0.0))
	var uas: float = float(state.results.get(result_id(term, Curriculum.FINAL_DAY, "uas"), 0.0))
	var bp_mid: float = float(state.results.get(result_id(term, Curriculum.MIDTERM_DAY, "blueprint_midterm"), 0.0))
	var bp_fin: float = float(state.results.get(result_id(term, Curriculum.FINAL_DAY, "blueprint_final"), 0.0))
	var final_score := clampf(
		tugas * WEIGHTS.tugas
		+ kuis * WEIGHTS.kuis
		+ uts * WEIGHTS.uts
		+ uas * WEIGHTS.uas
		+ bp_mid * WEIGHTS.blueprint_midterm
		+ bp_fin * WEIGHTS.blueprint_final,
		0.0,
		100.0
	)
	var ips := clampf(final_score / 25.0, 0.0, 4.0)
	return {
		"semester": term,
		"tugas": tugas,
		"kuis": kuis,
		"uts": uts,
		"uas": uas,
		"blueprint_midterm": bp_mid,
		"blueprint_final": bp_fin,
		"final_score": final_score,
		"letter_grade": letter_grade_for(final_score),
		"ips": ips,
	}


func semester_score(term: int) -> float:
	return float(semester_breakdown(term).final_score)


func semester_grade(term: int) -> float:
	return float(semester_breakdown(term).ips)


## IPK = average IPS across completed (evaluated) semesters; 0.00 before Semester 1 finishes.
func recalculate_gpa() -> void:
	var evaluated: Dictionary = state.get("evaluated_semesters", {})
	if evaluated.is_empty():
		PlayerStats.set_gpa(0.0)
		return
	var total_ips := 0.0
	var count := 0
	for term: int in range(1, Curriculum.SEMESTER_COUNT + 1):
		var key := str(term)
		if evaluated.has(key) and evaluated[key] is Dictionary:
			total_ips += float(evaluated[key].get("ips", 0.0))
			count += 1
	PlayerStats.set_gpa(clampf(total_ips / float(maxi(1, count)), 0.0, 4.0))


## Idempotent end-of-semester evaluation (never double-graded).
func evaluate_semester(term: int) -> Dictionary:
	var key := str(term)
	if term < 1 or term > Curriculum.SEMESTER_COUNT:
		return {}
	var evaluated: Dictionary = state.get("evaluated_semesters", {})
	if evaluated.has(key) and evaluated[key] is Dictionary:
		return evaluated[key]
	var summary := semester_breakdown(term)
	var previous := state.duplicate(true)
	state.evaluated_semesters[key] = summary
	var total_ips := 0.0
	var count := 0
	for t: int in range(1, Curriculum.SEMESTER_COUNT + 1):
		var k := str(t)
		if state.evaluated_semesters.has(k):
			total_ips += float(state.evaluated_semesters[k].get("ips", 0.0))
			count += 1
	var ipk := clampf(total_ips / float(maxi(1, count)), 0.0, 4.0)
	summary["ipk"] = ipk
	state.evaluated_semesters[key] = summary
	state.pending_khs = term
	var error := _save(previous)
	if error == OK:
		PlayerStats.set_gpa(ipk)
		if term == Curriculum.SEMESTER_COUNT:
			_finalize_ending()
		semester_evaluated.emit(term, summary)
	return summary


func get_pending_khs() -> Dictionary:
	var term := int(state.get("pending_khs", 0))
	if term <= 0:
		return {}
	return state.get("evaluated_semesters", {}).get(str(term), {})


func acknowledge_khs() -> Error:
	if int(state.get("pending_khs", 0)) == 0:
		return OK
	var previous := state.duplicate(true)
	state.pending_khs = 0
	return _save(previous)


func _on_time_changed(_minutes: int) -> void:
	var current_day := GameClock.get_day()
	if current_day != _active_day:
		_active_day = current_day
		# End-of-semester rollover check: Day > 12 evaluates Sem 1; Day > 24 evaluates Sem 2.
		if current_day > Curriculum.DAYS_PER_SEMESTER and not state.evaluated_semesters.has("1"):
			evaluate_semester(1)
		if current_day > Curriculum.TOTAL_DAYS and not state.evaluated_semesters.has("2"):
			evaluate_semester(2)
	check_class_attendance_cutoff()


## Exact GDD Section 4.4 sleep & rest rules:
## - Sleep 8h at <= 22:59 -> Energi = 100.0; >= 23:00 -> clamp(100 - hours_past_22 * 10, 0, 100)
##   (23:00 -> 90, 00:00 -> 80, 01:00 -> 70, ...)
## - Short rest 1h -> Energi = clamp(Energi + 15, 0, 100)
## - Both reset Kewarasan to Normal (50.0).
static func wake_energy_for_minute(minute_of_day: int) -> float:
	var m := posmod(minute_of_day, GameClock.MINUTES_PER_DAY)
	var hours_past_22 := 0.0
	if m >= 22 * 60:
		hours_past_22 = floorf(float(m - 22 * 60) / 60.0)
	elif m < 6 * 60:
		hours_past_22 = 2.0 + floorf(float(m) / 60.0)
	return clampf(100.0 - hours_past_22 * 10.0, 0.0, 100.0)


func rest(hours: int) -> Error:
	if hours not in [1, 8]:
		return ERR_INVALID_PARAMETER
	var wake_energy := wake_energy_for_minute(GameClock.get_absolute_minutes()) if hours == 8 else clampf(PlayerStats.get_energy() + 15.0, 0.0, 100.0)
	PlayerStats.set_energy(wake_energy)
	PlayerStats.set_sanity(SANITY_NORMAL)
	GameClock.advance_minutes(hours * 60)
	return OK


## Sleeps until next morning 06:00 using the exact same GDD 4.4 late-sleep penalty + Kewarasan reset.
func sleep_until_morning() -> Error:
	var now := GameClock.get_absolute_minutes()
	var wake_energy := wake_energy_for_minute(now)
	var minute_of_day := posmod(now, GameClock.MINUTES_PER_DAY)
	var delta := (GameClock.MINUTES_PER_DAY - minute_of_day) + GameClock.MORNING_MINUTES
	if minute_of_day < GameClock.MORNING_MINUTES:
		delta = GameClock.MORNING_MINUTES - minute_of_day
	PlayerStats.set_energy(wake_energy)
	PlayerStats.set_sanity(SANITY_NORMAL)
	GameClock.advance_minutes(delta)
	return OK


func can_advance_day() -> bool:
	var term := semester()
	var day := day_in_semester()
	if day == Curriculum.MIDTERM_DAY:
		return state.results.has(result_id(term, day, "uts"))
	if day == Curriculum.FINAL_DAY:
		return state.results.has(result_id(term, day, "uas"))
	return class_data(term, day).finished or is_class_missed(term, day)


## Backwards-compatible alias for bed interaction.
func can_advance_week() -> bool:
	return can_advance_day()


func advance_week() -> Error:
	return sleep_until_morning()


func pending_story() -> String:
	if not state.flags.has("story_intro"):
		return "intro"
	var abs_day := GameClock.get_day()
	if abs_day >= 7 and not state.flags.has("story_busy"):
		return "busy"
	if abs_day >= 16 and not state.flags.has("story_loss"):
		return "loss"
	if abs_day >= 19 and not state.flags.has("story_promise"):
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
		PlayerStats.set_energy(PlayerStats.get_energy() - 40.0)
		PlayerStats.set_sanity(PlayerStats.get_sanity() + 40.0)
	elif error == OK and id == "promise":
		PlayerStats.set_energy(PlayerStats.get_energy() + 20.0)
		PlayerStats.set_sanity(SANITY_NORMAL)
	return error


func should_graduate() -> bool:
	if state.evaluated_semesters.has("2"):
		return true
	if GameClock.get_day() > Curriculum.TOTAL_DAYS:
		return true
	return semester() == Curriculum.SEMESTER_COUNT and day_in_semester() == Curriculum.FINAL_DAY and state.results.has(result_id(2, Curriculum.FINAL_DAY, "uas"))


static func ending_for(gpa: float, passed: bool) -> String:
	if not passed:
		return "bad"
	return "happy" if gpa >= 3.5 else "basic"


func _finalize_ending() -> Error:
	if not state.ending.is_empty():
		return OK
	var s1: Dictionary = state.evaluated_semesters.get("1", semester_breakdown(1))
	var s2: Dictionary = state.evaluated_semesters.get("2", semester_breakdown(2))
	var passed := str(s1.get("letter_grade", "E")) != "E" and str(s2.get("letter_grade", "E")) != "E"
	var ipk := PlayerStats.get_gpa()
	var previous := state.duplicate(true)
	state.ending = ending_for(ipk, passed)
	state.flags["graduation_gpa"] = ipk
	return _save(previous)


func complete_career() -> Error:
	if not should_graduate():
		return ERR_UNAUTHORIZED
	if not state.evaluated_semesters.has("1"):
		evaluate_semester(1)
	if not state.evaluated_semesters.has("2"):
		evaluate_semester(2)
	return _finalize_ending()


func class_journal_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for key: String in state.classes:
		var data: Dictionary = state.classes[key]
		if not data.get("finished", false):
			continue
		var parts := key.split("_")
		if parts.size() != 2:
			continue
		var term := parts[0].trim_prefix("s").to_int()
		var day_num := parts[1].trim_prefix("d").to_int()
		if not _is_lesson(term, day_num):
			continue
		var lesson := Curriculum.lesson(term, day_num)
		var lines := PackedStringArray()
		for index: int in 3:
			lines.append(lesson.sections[index] if data.complete.has(index) else "________________ (catatan kosong)")
		entries.append({
			"kind": "notes",
			"source": "career_" + key,
			"title": lesson.title,
			"body": "\n\n".join(lines),
			"semester": term,
			"week": day_num,
		})
	return entries


func _save(previous: Dictionary) -> Error:
	var save := ConfigFile.new()
	save.set_value("career", "version", SAVE_VERSION)
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
