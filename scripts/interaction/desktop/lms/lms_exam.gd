extends CanvasLayer

signal submitted
signal abandoned

const Assignment = preload("res://scripts/interaction/desktop/lms/lms_assignment.gd")
const Quiz = preload("res://scripts/interaction/desktop/lms/lms_quiz.gd")
const QUIZ_SCENE := preload("res://scenes/interaction/desktop/lms/lms_quiz.tscn")

var assignment: Assignment
var university_name: String
var loading_seconds: float
var _finished: bool = false

@onready var _screen: PanelContainer = $Screen
@onready var _content: VBoxContainer = %Content
@onready var _timer: Timer = $LoadingTimer
@onready var _confirm: ConfirmationDialog = %ConfirmExit
@onready var _exit: Button = %ExitQuiz


func _ready() -> void:
	%University.text = university_name
	%LoadingAssignment.text = assignment.title
	_screen.resized.connect(_fit_content)
	_fit_content()
	_exit.pressed.connect(_request_exit)
	_confirm.confirmed.connect(_abandon)
	_confirm.canceled.connect(_resume)
	_exit.grab_focus()
	_timer.timeout.connect(_show_quiz)
	if loading_seconds <= 0.0:
		_show_quiz.call_deferred()
	else:
		_timer.start(loading_seconds)


func _fit_content() -> void:
	_content.custom_minimum_size.x = clampf(_screen.size.x - 40.0, 0.0, 640.0)


func _show_quiz() -> void:
	if _finished or _confirm.visible or not is_inside_tree():
		return
	%Loading.hide()
	var quiz := QUIZ_SCENE.instantiate() as Quiz
	quiz.assignment = assignment
	quiz.submitted.connect(_on_submitted)
	quiz.tree_exited.connect(_on_quiz_removed, CONNECT_DEFERRED)
	_content.add_child(quiz)


func _request_exit() -> void:
	_confirm.popup_centered(Vector2i(360, 0))
	_confirm.get_cancel_button().grab_focus()


func _resume() -> void:
	_exit.grab_focus()
	if %Loading.visible and _timer.is_stopped():
		_show_quiz.call_deferred()


func _abandon() -> void:
	if _finished:
		return
	_finished = true
	abandoned.emit()


func _on_submitted(_score: int, _max_score: int) -> void:
	_finished = true
	submitted.emit()


func _on_quiz_removed() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		_abandon()
