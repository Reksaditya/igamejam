extends VBoxContainer

signal submitted(score: int, max_score: int)
signal answers_changed(answers: PackedInt32Array)

const Assignment = preload("res://scripts/interaction/desktop/lms/lms_assignment.gd")
const Results = preload("res://scripts/interaction/desktop/lms/lms_results.gd")

var assignment: Assignment
var allow_partial_submission: bool = false
var initial_answers := PackedInt32Array()
var _answers := PackedInt32Array()
var _question_index: int = 0
var _finished: bool = false
var _timed_out: bool = false
var _clock_token: int = 0

@onready var _options: VBoxContainer = %Options
@onready var _submit_button: Button = %Submit
@onready var _save_error: Label = %SaveError


func _ready() -> void:
	%QuizTitle.text = assignment.title
	_answers.resize(assignment.questions.size())
	_answers.fill(-1)
	if initial_answers.size() == _answers.size():
		for index: int in initial_answers.size():
			if initial_answers[index] >= 0 and initial_answers[index] < assignment.questions[index].options.size():
				_answers[index] = initial_answers[index]
	_clock_token = GameClock.begin_assessment()
	%Previous.pressed.connect(_move_question.bind(-1))
	%Next.pressed.connect(_move_question.bind(1))
	_submit_button.pressed.connect(_submit)
	_show_question()


func _exit_tree() -> void:
	GameClock.end_assessment(_clock_token)


func submit_on_timeout() -> void:
	_timed_out = true
	for child: Node in _options.get_children():
		(child as CheckBox).disabled = true
	_submit(true)


func _show_question() -> void:
	var question := assignment.questions[_question_index]
	%QuestionNumber.text = "Question %d of %d" % [_question_index + 1, _answers.size()]
	%Prompt.text = question.prompt

	for child: Node in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	var group := ButtonGroup.new()
	for index: int in question.options.size():
		var choice := CheckBox.new()
		choice.text = question.options[index]
		choice.custom_minimum_size.y = 32.0
		choice.theme_type_variation = &"LmsOption"
		choice.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		choice.button_group = group
		choice.disabled = _timed_out
		choice.set_pressed_no_signal(_answers[_question_index] == index)
		choice.pressed.connect(_select_answer.bind(index))
		_options.add_child(choice)
	%Previous.disabled = _question_index == 0
	%Next.disabled = _question_index == _answers.size() - 1
	_refresh_progress()
	_focus_current_answer.call_deferred()


func _focus_current_answer() -> void:
	if not is_inside_tree():
		return
	var focused_choice := _options.get_child(maxi(_answers[_question_index], 0)) as CheckBox
	focused_choice.grab_focus()


func _move_question(direction: int) -> void:
	var next := _question_index + direction
	if next >= 0 and next < _answers.size():
		_question_index = next
		_show_question()


func _select_answer(option: int) -> void:
	if _finished or _timed_out:
		return
	_answers[_question_index] = option
	answers_changed.emit(_answers.duplicate())
	_refresh_progress()


func _refresh_progress() -> void:
	var answered := _answers.size() - _answers.count(-1)
	%Progress.text = "Exam mode · %d of %d answered" % [answered, _answers.size()]
	_submit_button.disabled = not allow_partial_submission and answered < _answers.size()


func _submit(force: bool = false) -> void:
	if _finished or (not force and not allow_partial_submission and _answers.has(-1)):
		return
	var score := 0
	for index: int in _answers.size():
		if _answers[index] == assignment.questions[index].correct_option:
			score += 1
	var error := Results.save_result(assignment.id, score, _answers.size())
	if error == OK:
		_finish(score, _answers.size())
		return
	if error == ERR_ALREADY_EXISTS:
		var result := Results.read_result(assignment.id)
		if not result.is_empty():
			_finish(result.score, result.max_score)
			return
	_save_error.text = "Could not save your result. Your answers are still here."
	%Progress.hide()
	_save_error.show()
	_submit_button.text = "Retry save"


func _finish(score: int, max_score: int) -> void:
	_finished = true
	GameClock.end_assessment(_clock_token)
	submitted.emit(score, max_score)
