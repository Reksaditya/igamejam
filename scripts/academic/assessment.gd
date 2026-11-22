extends "res://scripts/ui/activity_panel.gd"

signal lock_changed(active: bool)

const Curriculum = preload("res://scripts/academic/curriculum.gd")

var term: int = 1
var study_week: int = 1
var kind: String = "kuis"
var questions: Array[Dictionary] = []
var answers: Array[int] = []
var current: int = 0
var deadline: float = 0
var _clock_token: int = 0
var _finished: bool = false
var _status: Label
var _question_area: VBoxContainer
var _submit: Button
var _error: Label


func _ready() -> void:
	super._ready()
	window.title = "LMS · %s" % kind.to_upper()
	window.min_size = Vector2i(320, 280)
	var id := CareerProgress.result_id(term, study_week, kind)
	if CareerProgress.state.results.has(id):
		_show_result(float(CareerProgress.state.results[id]))
		return
	if _overdue():
		label("Tenggat pengumpulan telah lewat (%s). Nilai kegiatan ini 0 (E)." % deadline_label(term, study_week, kind))
		add_close()
		_finished = true
		return
	if not CareerProgress.is_assessment_unlocked(term, study_week, kind):
		label("Kegiatan ini belum dibuka. Periksa jadwal semester dan hari di LMS.")
		add_close()
		_finished = true
		return
	if kind != "tugas":
		_clock_token = GameClock.begin_assessment()
		if _clock_token == 0:
			label("Selesaikan kegiatan yang sedang berjalan terlebih dahulu.")
			add_close()
			_finished = true
			return
	var error := CareerProgress.begin_activity(kind, id)
	if error != OK:
		GameClock.end_assessment(_clock_token)
		_clock_token = 0
		label("Energi tidak cukup atau progres belum dapat disimpan. Istirahat dahulu di Kamar 203.")
		add_close()
		_finished = true
		return
	questions = Curriculum.questions(term, study_week, kind, 10)
	answers.resize(questions.size())
	answers.fill(-1)
	var draft := ConfigFile.new()
	if draft.load(_path()) == OK:
		var saved: Variant = draft.get_value("attempt", "answers", [])
		if saved is Array and saved.size() == questions.size():
			for index: int in questions.size():
				if saved[index] is int and saved[index] >= -1 and saved[index] < 4:
					answers[index] = saved[index]
		var saved_deadline: Variant = draft.get_value("attempt", "deadline", 0.0)
		if saved_deadline is float or saved_deadline is int:
			deadline = saved_deadline
	if kind != "tugas":
		if deadline <= 0:
			deadline = Time.get_unix_time_from_system() + 600.0
		can_close = false
		lock_changed.emit(true)
	label("%s · %s" % [_heading_prefix(), kind.to_upper()], 24)
	_status = label("")
	_error = label("", 16)
	_question_area = VBoxContainer.new()
	_question_area.add_theme_constant_override("separation", 12)
	content.add_child(_question_area)
	_submit = button("Kumpulkan jawaban", submit)
	add_close()
	_save_draft()
	_show_question()


func _heading_prefix() -> String:
	if kind in ["tugas", "kuis"]:
		var part := study_week if study_week in [1, 2] else Curriculum.half_for_day(study_week)
		return "Semester %d · Paruh %d" % [term, part]
	var day := Curriculum.MIDTERM_DAY if kind == "uts" else Curriculum.FINAL_DAY
	return "Semester %d · Hari %d" % [term, day]


func _path() -> String:
	return "user://career_drafts/" + CareerProgress.result_id(term, study_week, kind) + ".cfg"


func _overdue() -> bool:
	return CareerProgress.is_assessment_overdue(term, study_week, kind)


static func deadline_day_in_semester(slot: int, assessment_kind: String) -> int:
	if assessment_kind == "uts":
		return Curriculum.MIDTERM_DAY
	if assessment_kind == "uas":
		return Curriculum.FINAL_DAY
	var part := slot if slot in [1, 2] else Curriculum.half_for_day(slot)
	return Curriculum.MIDTERM_DAY if part == 1 else Curriculum.FINAL_DAY


static func deadline_minutes(semester: int, slot: int, assessment_kind: String = "tugas") -> int:
	var day_in_sem := deadline_day_in_semester(slot, assessment_kind)
	var abs_deadline_day := Curriculum.absolute_day_for(semester, day_in_sem)
	return abs_deadline_day * GameClock.MINUTES_PER_DAY


static func deadline_label(semester: int, slot: int, assessment_kind: String = "tugas") -> String:
	var day_in_sem := deadline_day_in_semester(slot, assessment_kind)
	return "Tenggat: Sem %d · Hari %d" % [semester, day_in_sem]


func _process(_delta: float) -> void:
	if _finished or not is_instance_valid(_status):
		return
	var total := questions.size()
	if kind == "tugas":
		_status.text = "%d soal · Tanpa timer · %s" % [total, deadline_label(term, study_week, kind)]
		if _overdue():
			submit(true)
	else:
		var remaining := maxi(0, ceili(deadline - Time.get_unix_time_from_system()))
		_status.text = "Sisa waktu %02d:%02d · %d/%d terjawab · %s" % [
			floori(remaining / 60.0),
			remaining % 60,
			total - answers.count(-1),
			total,
			deadline_label(term, study_week, kind),
		]
		if remaining == 0 or _overdue():
			submit(true)


func _show_question() -> void:
	for child: Node in _question_area.get_children():
		_question_area.remove_child(child)
		child.queue_free()
	var total := questions.size()
	var prompt := Label.new()
	prompt.text = "Soal %d/%d\n%s" % [current + 1, total, questions[current].prompt]
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question_area.add_child(prompt)
	var letters := ["A", "B", "C", "D"]
	for index: int in 4:
		var option := Button.new()
		var mark := "✓ " if answers[current] == index else ""
		option.text = "%s%s. %s" % [mark, letters[index], questions[current].options[index]]
		option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option.pressed.connect(_answer.bind(index))
		_question_area.add_child(option)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	_question_area.add_child(nav)
	var previous := Button.new()
	previous.text = "Sebelumnya"
	previous.disabled = current == 0
	previous.pressed.connect(_move.bind(-1))
	nav.add_child(previous)
	var next := Button.new()
	next.text = "Selanjutnya"
	next.disabled = current >= total - 1
	next.pressed.connect(_move.bind(1))
	nav.add_child(next)


func _answer(index: int) -> void:
	if _finished:
		return
	answers[current] = index
	_save_draft()
	_show_question()


func _move(direction: int) -> void:
	current = clampi(current + direction, 0, maxi(0, questions.size() - 1))
	_show_question()


func _save_draft() -> void:
	var error := DirAccess.make_dir_recursive_absolute("user://career_drafts")
	var draft := ConfigFile.new()
	draft.set_value("attempt", "answers", answers)
	draft.set_value("attempt", "deadline", deadline)
	if error == OK:
		error = draft.save(_path() + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(_path() + ".tmp", _path())
	_error.text = "Jawaban belum tersimpan. Coba pilih jawaban lagi." if error != OK else ""


func submit(timed_out: bool = false) -> void:
	if _finished:
		return
	var total := maxi(1, questions.size())
	var correct_count := 0
	for index: int in questions.size():
		if answers[index] == int(questions[index].correct):
			correct_count += 1
	var score := float(correct_count) * (100.0 / float(total))
	if _overdue():
		score = 0.0
	var error := CareerProgress.record_result(term, study_week, kind, score)
	if error != OK:
		_error.text = "Nilai belum tersimpan. Tekan Kumpulkan untuk mencoba kembali."
		return
	_finished = true
	GameClock.end_assessment(_clock_token)
	_clock_token = 0
	if kind != "tugas":
		lock_changed.emit(false)
	DirAccess.remove_absolute(_path())
	_show_result(score)
	if timed_out:
		label("Waktu habis atau tenggat terlampaui. Jawaban otomatis dikumpulkan.", 16)


func _show_result(score: float) -> void:
	_finished = true
	can_close = true
	clear()
	var letter := CareerProgress.letter_grade_for(score)
	label("%s selesai · %.0f / 100 (%s)" % [kind.to_upper(), score, letter], 28)
	var preview := CareerProgress.semester_breakdown(term)
	label("Estimasi Nilai Semester %d: %.1f (%s · IPS %.2f)" % [term, preview.final_score, preview.letter_grade, preview.ips], 18)
	label("IPK Resmi Saat Ini: %.2f" % PlayerStats.get_gpa(), 16)
	add_close()


func _exit_tree() -> void:
	GameClock.end_assessment(_clock_token)
	super._exit_tree()
