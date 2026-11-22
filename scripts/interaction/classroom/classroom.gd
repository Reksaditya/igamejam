extends Node2D

const Lesson = preload("res://scripts/academic/class_lesson.gd")
const Assessment = preload("res://scripts/academic/assessment.gd")
const MIDTERM := preload("res://scenes/interaction/classroom/midterm.tres")
const FINAL := preload("res://scenes/interaction/classroom/final.tres")

@export var classroom_enabled: bool = true
@export_range(0, 12) var week_override: int = 0

var _week: int = 1
var _lesson: CanvasLayer
var _exam: CanvasLayer
var _seats: Array[Area2D] = []
var _active_seat: Area2D
var _manual_seated: bool = false


func _ready() -> void:
	for id: String in ["Seat", "Seat2", "Seat3", "Seat4"]:
		_seats.append(get_node(id) as Area2D)
	if not classroom_enabled:
		$Computer.hide()
		$Desks.hide()
		for seat: Area2D in _seats:
			seat.hide()
		$Hud.hide()
		return
	var visual := get_parent().get_node("Player/Visual") as Node2D
	visual.scale = Vector2(3, 3)
	visual.position.y = -66
	$Computer.interaction_requested.connect(_open_exam)
	for seat: Area2D in _seats:
		seat.interaction_requested.connect(_interact_seat.bind(seat))
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
	_week = week_override if week_override > 0 else CareerProgress.day_in_semester()
	CareerProgress.check_class_attendance_cutoff()
	var exam_day := _week == CareerProgress.Curriculum.MIDTERM_DAY or _week == CareerProgress.Curriculum.FINAL_DAY
	$Computer.available = exam_day
	_refresh_classroom()


func _refresh_classroom() -> void:
	CareerProgress.check_class_attendance_cutoff()
	var term := CareerProgress.semester()
	var exam_day := _week == CareerProgress.Curriculum.MIDTERM_DAY or _week == CareerProgress.Curriculum.FINAL_DAY
	var finished: bool = CareerProgress.class_data(term, _week).finished
	var missed: bool = not exam_day and not finished and CareerProgress.is_class_missed(term, _week)
	var actor := get_parent().get_node("Player") as CharacterBody2D
	for seat: Area2D in _seats:
		seat.available = not is_instance_valid(_lesson) and not is_instance_valid(_exam) and (not _manual_seated or seat == _active_seat)
		var prompt := seat.get_node("Prompt") as Button
		if _manual_seated and seat == _active_seat:
			prompt.text = "E · Berdiri"
		elif missed:
			prompt.text = "E · Duduk (Kelas Terlewat)"
		elif exam_day or finished:
			prompt.text = "E · Duduk"
		else:
			prompt.text = "E · Duduk dan Belajar"
		prompt.visible = seat.available and seat.overlaps_body(actor)
	%Review.visible = not exam_day and finished
	var exam_name := "UTS" if _week == CareerProgress.Curriculum.MIDTERM_DAY else "UAS"
	if missed:
		%ClassStatus.text = "KELAS TERLEWAT — Terlambat > 1 jam (Batas 09:00). Kejar catatan di Perpustakaan."
		%ClassStatus.add_theme_color_override("font_color", Color("#ff9b85"))
	else:
		%ClassStatus.remove_theme_color_override("font_color")
		%ClassStatus.text = "Semester %d · Hari %d/12 · %s" % [
			term,
			_week,
			"Ujian %s: dekati komputer kelas, lalu tekan E." % exam_name if exam_day else ("Kelas selesai. Materi tidak dapat diulang di kelas." if finished else "Dekati kursi, tekan E untuk duduk dan mulai belajar.")
		]


func _interact_seat(seat: Area2D) -> void:
	CareerProgress.check_class_attendance_cutoff()
	var term := CareerProgress.semester()
	var exam_day := _week == CareerProgress.Curriculum.MIDTERM_DAY or _week == CareerProgress.Curriculum.FINAL_DAY
	var finished: bool = CareerProgress.class_data(term, _week).finished
	var missed: bool = not exam_day and not finished and CareerProgress.is_class_missed(term, _week)
	if _manual_seated:
		_stand_up()
	elif exam_day or finished or missed:
		_active_seat = seat
		_manual_seated = true
		_pose_player(seat)
		_refresh_classroom()
	else:
		_open_lesson(seat)


func _pose_player(seat: Area2D) -> void:
	var actor := get_parent().get_node("Player") as CharacterBody2D
	actor.set_studying(true)
	actor.global_position = seat.get_node("SeatPoint").global_position
	var visual := actor.get_node("Visual") as Node2D
	visual.scale.x = absf(visual.scale.x)


func _stand_up() -> void:
	var actor := get_parent().get_node("Player") as CharacterBody2D
	actor.set_studying(false)
	if is_instance_valid(_active_seat):
		actor.global_position = _active_seat.global_position
	_active_seat = null
	_manual_seated = false
	_refresh_classroom()


func _open_lesson(seat: Area2D = null) -> void:
	if is_instance_valid(_lesson) or is_instance_valid(_exam) or SceneTransition.is_active():
		return
	CareerProgress.check_class_attendance_cutoff()
	var term := CareerProgress.semester()
	var exam_day := _week == CareerProgress.Curriculum.MIDTERM_DAY or _week == CareerProgress.Curriculum.FINAL_DAY
	if exam_day or CareerProgress.class_data(term, _week).finished or CareerProgress.is_class_missed(term, _week):
		_refresh_classroom()
		return
	var actor := get_parent().get_node("Player") as CharacterBody2D
	if seat == null:
		seat = $Seat
	if not seat.overlaps_body(actor):
		return
	_lesson = Lesson.new()
	_lesson.term = CareerProgress.semester()
	_lesson.study_week = _week
	_lesson.player = actor
	_lesson.seat_position = seat.get_node("SeatPoint").global_position
	_lesson.closed.connect(_on_lesson_closed)
	_lesson.completed.connect(_return_to_corridor)
	_active_seat = seat
	add_child(_lesson)
	if actor.is_studying():
		_pose_player(seat)
	_refresh_classroom()
	$Hud.hide()


func _open_notes() -> void:
	if not CareerProgress.class_data(CareerProgress.semester(), _week).finished or is_instance_valid(_lesson) or is_instance_valid(_exam):
		return
	if _manual_seated:
		_stand_up()
	_lesson = Lesson.new()
	_lesson.term = CareerProgress.semester()
	_lesson.study_week = _week
	_lesson.notes_only = true
	_lesson.closed.connect(_on_lesson_closed)
	add_child(_lesson)
	$Hud.hide()


func _on_lesson_closed() -> void:
	_lesson = null
	_stand_up()
	$Hud.show()
	_refresh_classroom()


func _return_to_corridor() -> void:
	var door := get_parent().get_node("Door") as Area2D
	SceneTransition.change_scene.call_deferred(door.destination, door.destination_spawn, SceneTransition.TransitionStyle.SLIDE_RIGHT)


func _open_exam() -> void:
	var exam_day := _week == CareerProgress.Curriculum.MIDTERM_DAY or _week == CareerProgress.Curriculum.FINAL_DAY
	if not exam_day or is_instance_valid(_lesson) or is_instance_valid(_exam):
		return
	_exam = Assessment.new()
	_exam.term = CareerProgress.semester()
	_exam.study_week = _week
	_exam.kind = "uts" if _week == CareerProgress.Curriculum.MIDTERM_DAY else "uas"
	add_child(_exam)
	_exam.closed.connect(func() -> void: _exam = null)


func _clock_changed(_minutes: int) -> void:
	if not is_instance_valid(_lesson) and not is_instance_valid(_exam):
		_enter_class()
