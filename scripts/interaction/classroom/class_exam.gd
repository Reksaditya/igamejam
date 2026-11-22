extends CanvasLayer

signal closed

const Assignment = preload("res://scripts/interaction/desktop/lms/lms_assignment.gd")
const Quiz = preload("res://scripts/interaction/desktop/lms/lms_quiz.gd")
const Results = preload("res://scripts/interaction/desktop/lms/lms_results.gd")
const QUIZ_SCENE := preload("res://scenes/interaction/desktop/lms/lms_quiz.tscn")

@export_range(1.0, 3600.0, 1.0) var duration_seconds: float = 600.0

var assignment: Assignment
var _quiz: Quiz
var _deadline_msec: int = 0
var _deadline_unix: float = 0.0
var _finished: bool = false
var _timed_out: bool = false
var _was_paused: bool = false
var _owns_pause: bool = true
var _game_start_minutes: int = 0


func _ready() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	_game_start_minutes = GameClock.get_absolute_minutes()
	%Heading.text = assignment.title
	%Close.pressed.connect(_close)
	%Retry.pressed.connect(_start_exam)
	if has_node("%NotesHint"):
		%NotesHint.pressed.connect(func() -> void: StudyNotes.toggle_book(CareerProgress.semester()))
	var result := Results.read_result(assignment.id)
	if result.is_empty():
		_start_exam()
	else:
		_show_result(result.score, result.max_score)


func _input(event: InputEvent) -> void:
	if _finished or not is_instance_valid(_quiz):
		return
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if key.keycode == KEY_TAB and not key.shift_pressed and not key.ctrl_pressed and not key.alt_pressed and not key.meta_pressed:
			get_viewport().set_input_as_handled()
			if not key.echo:
				StudyNotes.toggle_book(CareerProgress.semester())


func _exit_tree() -> void:
	if StudyNotes.is_book_open():
		StudyNotes.close_book()
	if _owns_pause:
		get_tree().paused = _was_paused


func _start_exam() -> void:
	%Retry.hide()
	%Close.disabled = true
	var draft := ConfigFile.new()
	var stored_answers := PackedInt32Array()
	if draft.load(_draft_path()) == OK:
		var deadline: Variant = draft.get_value("exam", "deadline", 0.0)
		var answers: Variant = draft.get_value("exam", "answers", PackedInt32Array())
		if (deadline is float or deadline is int) and deadline > 0.0:
			_deadline_unix = deadline
		if answers is PackedInt32Array:
			stored_answers = answers
	if _deadline_unix <= 0.0:
		_deadline_unix = Time.get_unix_time_from_system() + duration_seconds
	var error := _save_draft(stored_answers)
	if error != OK:
		%Status.text = "Ujian belum dapat dimulai karena penyimpanan gagal. Coba kembali."
		%Retry.show()
		%Close.disabled = false
		return
	_deadline_msec = Time.get_ticks_msec() + roundi(maxf(0.0, _deadline_unix - Time.get_unix_time_from_system()) * 1000.0)
	_quiz = QUIZ_SCENE.instantiate() as Quiz
	_quiz.assignment = assignment
	_quiz.allow_partial_submission = true
	_quiz.initial_answers = stored_answers
	_quiz.answers_changed.connect(_on_answers_changed)
	_quiz.submitted.connect(_show_result)
	%QuizHost.add_child(_quiz)
	%Status.text = "10 soal pilihan ganda · Batas 10 menit nyata. Jawaban kosong bernilai 0. Waktu habis akan mengumpulkan jawaban otomatis. Jam game mengikuti durasi pengerjaan."


func _process(_delta: float) -> void:
	if _finished or not is_instance_valid(_quiz) or _timed_out:
		return
	var remaining := maxi(0, ceili(float(_deadline_msec - Time.get_ticks_msec()) / 1000.0))
	%Countdown.text = "Sisa waktu %02d:%02d" % [floori(float(remaining) / 60.0), remaining % 60]
	if remaining == 0:
		_timed_out = true
		%Status.text = "Waktu habis. Jawaban dikunci dan dikumpulkan otomatis."
		_quiz.submit_on_timeout()


func _on_answers_changed(answers: PackedInt32Array) -> void:
	if _save_draft(answers) != OK:
		%Status.text = "Draf belum tersimpan. Jawaban masih tersedia pada layar ini."


func _save_draft(answers: PackedInt32Array) -> Error:
	var draft := ConfigFile.new()
	draft.set_value("exam", "deadline", _deadline_unix)
	draft.set_value("exam", "answers", answers)
	var error := draft.save(_draft_path() + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(_draft_path() + ".tmp", _draft_path())
	return error


func _draft_path() -> String:
	return "user://classroom_" + assignment.id + ".cfg"


func _show_result(score: int, max_score: int) -> void:
	_finished = true
	if is_instance_valid(_quiz):
		%QuizHost.remove_child(_quiz)
		_quiz.queue_free()
		_quiz = null
	if FileAccess.file_exists(_draft_path()):
		DirAccess.remove_absolute(_draft_path())
	%Countdown.text = "Ujian selesai · %d / %d" % [score, max_score]
	%Status.text = "Hasil tersimpan. Jam game bertambah %d menit selama sesi ini." % (GameClock.get_absolute_minutes() - _game_start_minutes)
	%Close.disabled = false
	%Close.grab_focus()
	%Retry.hide()


func _close() -> void:
	if is_instance_valid(_quiz) and not _finished:
		return
	get_tree().paused = _was_paused
	_owns_pause = false
	closed.emit()
	queue_free()
