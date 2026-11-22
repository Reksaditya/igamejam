extends "res://scripts/ui/activity_panel.gd"

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
	var id := CareerProgress.result_id(term, study_week, kind)
	if CareerProgress.state.results.has(id):
		_show_result(float(CareerProgress.state.results[id]))
		return
	if _overdue():
		label("Tenggat pengumpulan telah lewat. Nilai kegiatan ini 0.")
		add_close()
		_finished = true
		return
	var error := CareerProgress.begin_activity(kind, id)
	if error != OK:
		label("Energi tidak cukup atau progres belum dapat disimpan. Istirahat dahulu.")
		add_close()
		_finished = true
		return
	questions = Curriculum.questions(term, study_week, kind)
	answers.resize(10)
	answers.fill(-1)
	var draft := ConfigFile.new()
	if draft.load(_path()) == OK:
		var saved: Variant = draft.get_value("attempt", "answers", [])
		if saved is Array and saved.size() == 10:
			for index: int in 10:
				if saved[index] is int and saved[index] >= -1 and saved[index] < 4:
					answers[index] = saved[index]
		var saved_deadline: Variant = draft.get_value("attempt", "deadline", 0.0)
		if saved_deadline is float or saved_deadline is int:
			deadline = saved_deadline
	if kind != "tugas":
		if deadline <= 0:
			deadline = Time.get_unix_time_from_system() + 600.0
		_clock_token = GameClock.begin_assessment()
		can_close = false
	label("Semester %d · Minggu %d · %s" % [term, study_week, kind.to_upper()], 26)
	_status = label("")
	_error = label("", 16)
	_question_area = VBoxContainer.new()
	_question_area.add_theme_constant_override("separation", 12)
	content.add_child(_question_area)
	_submit = button("Kumpulkan jawaban", submit)
	add_close()
	_save_draft()
	_show_question()


func _path() -> String:
	return "user://career_drafts/" + CareerProgress.result_id(term, study_week, kind) + ".cfg"


func _overdue() -> bool:
	if kind in ["uts", "uas"]:
		return false
	var due := ((term - 1) * 16 * 7 + (study_week - 1) * 7 + 6) * 1440
	return GameClock.get_absolute_minutes() >= due


func _process(_delta: float) -> void:
	if _finished or not is_instance_valid(_status):
		return
	if kind == "tugas":
		_status.text = "10 soal · Tanpa batas durasi pengerjaan · Tenggat 6 hari game"
		if _overdue():
			submit(true)
	else:
		var remaining := maxi(0, ceili(deadline - Time.get_unix_time_from_system()))
		_status.text = "Sisa waktu %02d:%02d · %d/10 terjawab" % [floori(remaining / 60.0), remaining % 60, 10 - answers.count(-1)]
		if remaining == 0 or _overdue():
			submit(true)


func _show_question() -> void:
	for child: Node in _question_area.get_children():
		_question_area.remove_child(child)
		child.queue_free()
	var prompt := Label.new()
	prompt.text = "Soal %d/10\n%s" % [current + 1, questions[current].prompt]
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question_area.add_child(prompt)
	for index: int in 4:
		var option := Button.new()
		option.text = ("✓ " if answers[current] == index else "") + questions[current].options[index]
		option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option.pressed.connect(_answer.bind(index))
		_question_area.add_child(option)
	var previous := Button.new()
	previous.text = "Sebelumnya"
	previous.disabled = current == 0
	previous.pressed.connect(_move.bind(-1))
	_question_area.add_child(previous)
	var next := Button.new()
	next.text = "Selanjutnya"
	next.disabled = current == 9
	next.pressed.connect(_move.bind(1))
	_question_area.add_child(next)


func _answer(index: int) -> void:
	if _finished:
		return
	answers[current] = index
	_save_draft()
	_show_question()


func _move(direction: int) -> void:
	current = clampi(current + direction, 0, 9)
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
	var score := 0.0
	for index: int in 10:
		if answers[index] == questions[index].correct:
			score += 10.0
	if _overdue():
		score = 0.0
	var error := CareerProgress.record_result(term, study_week, kind, score)
	if error != OK:
		_error.text = "Nilai belum tersimpan. Tekan Kumpulkan untuk mencoba kembali."
		return
	_finished = true
	GameClock.end_assessment(_clock_token)
	_clock_token = 0
	DirAccess.remove_absolute(_path())
	_show_result(score)
	if timed_out:
		label("Waktu habis. Jawaban otomatis dikumpulkan.", 16)


func _show_result(score: float) -> void:
	_finished = true
	can_close = true
	clear()
	label("%s selesai · %.0f / 100" % [kind.to_upper(), score], 28)
	label("Hasil tercatat pada riwayat nilai. IPK saat ini: %.2f" % PlayerStats.get_gpa())
	add_close()


func _exit_tree() -> void:
	GameClock.end_assessment(_clock_token)
	super._exit_tree()
