extends Node2D

const Lesson = preload("res://scripts/academic/class_lesson.gd")
const Assessment = preload("res://scripts/academic/assessment.gd")
const MIDTERM := preload("res://scenes/interaction/classroom/midterm.tres")
const FINAL := preload("res://scenes/interaction/classroom/final.tres")

@export var classroom_enabled: bool = true
@export_range(0, 16) var week_override: int = 0

var _week: int = 1
var _lesson: CanvasLayer
var _exam: CanvasLayer


func _ready() -> void:
	if not classroom_enabled:
		$Computer.hide()
		$Seat.hide()
		$Hud.hide()
		return
	$Computer.interaction_requested.connect(_open_exam)
	$Seat.interaction_requested.connect(_open_lesson)
	%Review.pressed.connect(_open_notes)
	GameClock.minute_changed.connect(_clock_changed)
	CareerProgress.changed.connect(_refresh_classroom)
	if SceneTransition.is_active():
		SceneTransition.transition_finished.connect(_after_transition, CONNECT_ONE_SHOT)
	else:
		_enter_class.call_deferred()


func _after_transition(error: Error) -> void:
	if error == OK:
		_enter_class()


func _enter_class() -> void:
	if not classroom_enabled or not is_inside_tree():
		return
	_week = week_override if week_override > 0 else CareerProgress.week()
	var exam_week := _week == 8 or _week == 16
	$Computer.available = exam_week
	_refresh_classroom()


func _refresh_classroom() -> void:
	var exam_week := _week == 8 or _week == 16
	var finished: bool = CareerProgress.class_data(CareerProgress.semester(), _week).finished
	$Seat.available = not exam_week and not finished and not is_instance_valid(_lesson)
	%Review.visible = not exam_week and finished
	%ClassStatus.text = "Minggu %d · %s" % [_week, "Ujian: dekati komputer kelas, lalu tekan E." if exam_week else ("Kelas selesai. Materi tidak dapat diulang di kelas." if finished else "Dekati kursi, tekan E untuk duduk dan mulai belajar.")]


func _open_lesson() -> void:
	if is_instance_valid(_lesson) or is_instance_valid(_exam) or SceneTransition.is_active():
		return
	if _week == 8 or _week == 16 or CareerProgress.class_data(CareerProgress.semester(), _week).finished:
		return
	var actor := get_parent().get_node("Player") as CharacterBody2D
	if not $Seat.overlaps_body(actor):
		return
	_lesson = Lesson.new()
	_lesson.term = CareerProgress.semester()
	_lesson.study_week = _week
	_lesson.player = actor
	_lesson.seat_position = $Seat.global_position
	_lesson.closed.connect(_on_lesson_closed)
	add_child(_lesson)
	$Seat.available = false
	$Seat/Prompt.hide()
	$Hud.hide()


func _open_notes() -> void:
	if not CareerProgress.class_data(CareerProgress.semester(), _week).finished or is_instance_valid(_lesson) or is_instance_valid(_exam):
		return
	_lesson = Lesson.new()
	_lesson.term = CareerProgress.semester()
	_lesson.study_week = _week
	_lesson.notes_only = true
	_lesson.closed.connect(_on_lesson_closed)
	add_child(_lesson)
	$Hud.hide()


func _on_lesson_closed() -> void:
	_lesson = null
	$Hud.show()
	_refresh_classroom()


func _open_exam() -> void:
	if (_week != 8 and _week != 16) or is_instance_valid(_lesson) or is_instance_valid(_exam):
		return
	_exam = Assessment.new()
	_exam.term = CareerProgress.semester()
	_exam.study_week = _week
	_exam.kind = "uts" if _week == 8 else "uas"
	add_child(_exam)
	_exam.closed.connect(func() -> void: _exam = null)


func _clock_changed(_minutes: int) -> void:
	if not is_instance_valid(_lesson) and not is_instance_valid(_exam):
		_enter_class()
