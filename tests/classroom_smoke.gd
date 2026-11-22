extends SceneTree

const Results = preload("res://scripts/interaction/desktop/lms/lms_results.gd")
const CLASSROOM := "res://scenes/movement/campus_classroom.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var clock := root.get_node("GameClock")
	var notes := root.get_node("ClassroomProgress")
	var blueprint := root.get_node("BlueprintProgress")
	if "--interrupted" in OS.get_cmdline_user_args():
		change_scene_to_file(CLASSROOM)
		await scene_changed
		var actor := current_scene.get_node("Player") as CharacterBody2D
		actor.position.x = 700
		await _frames(5)
		var classroom := current_scene.get_node("ClassActivity")
		assert(classroom.get_node("Seat")._interact())
		var lesson: CanvasLayer = classroom._lesson
		lesson._remaining = 0.0
		lesson._process(0.0)
		assert(notes.has_attempted(0))
		assert(not notes.has_note(0))
		change_scene_to_file("res://scenes/movement/top_down_movement.tscn")
		await scene_changed
		change_scene_to_file(CLASSROOM)
		await scene_changed
		actor = current_scene.get_node("Player") as CharacterBody2D
		actor.position.x = 700
		await _frames(5)
		classroom = current_scene.get_node("ClassActivity")
		assert(classroom.get_node("Seat")._interact())
		lesson = classroom._lesson
		assert(lesson._indices.size() == 5)
		assert(not lesson._indices.has(0))
		assert(notes.begin_material(0) == ERR_ALREADY_EXISTS)
		assert(not lesson.get_node("Screen").visible)
		print("PASS: interrupted QTE is not replayed on classroom re-entry")
		quit()
		return
	if "--reload" in OS.get_cmdline_user_args():
		assert(notes.is_class_finished())
		assert(not notes.is_complete())
		assert(not notes.has_note(2))
		assert(notes.begin_material(2) == ERR_ALREADY_EXISTS)
		assert(notes.finish_material(2, true) == ERR_UNAUTHORIZED)
		assert(Results.read_result("classroom_midterm_week_8").score == 10)
		assert(Results.read_result("classroom_final_week_16").score == 3)
		print("PASS: passed material remains locked, missing notes remain empty, UTS and UAS results persist")
		quit()
		return
	assert(not notes.is_complete(), "Run with fresh isolated APPDATA")
	assert(notes.unlock_blueprint() == ERR_UNAUTHORIZED)
	clock._absolute_minutes = 870
	var token: int = clock.begin_assessment()
	var nested: int = clock.begin_assessment()
	assert(clock._timer.paused)
	clock._assessment_started_msec -= 360000
	clock.end_assessment(token)
	assert(clock.get_absolute_minutes() == 870)
	clock.end_assessment(nested)
	assert(clock.get_formatted_time() == "14:36")
	assert(not clock._timer.paused)
	clock.end_assessment(nested)
	assert(clock.get_formatted_time() == "14:36")
	clock._absolute_minutes = 0
	change_scene_to_file(CLASSROOM)
	await scene_changed
	await _frames(3)
	var classroom := current_scene.get_node("ClassActivity")
	assert(not is_instance_valid(classroom._lesson))
	assert(not paused)
	assert(not classroom.get_node("Computer").available)
	assert(not classroom.get_node("Hud/Panel/Content/Review").visible)
	classroom._open_notes()
	assert(not is_instance_valid(classroom._lesson))
	var actor := current_scene.get_node("Player") as CharacterBody2D
	actor.position.x = 700.0
	await _frames(5)
	assert(classroom.get_node("Seat/Prompt").visible)
	assert(actor.get_node("Visual/AnimatedSprite2D").is_playing())
	seed(1234)
	_press(KEY_E)
	await _frames(2)
	var lesson: CanvasLayer = classroom._lesson
	assert(is_instance_valid(lesson))
	assert(actor.is_studying())
	assert(not actor.get_node("Visual/AnimatedSprite2D").is_playing())
	assert(not paused)
	assert(not lesson.get_node("Screen").visible)
	assert(not lesson.get_node("Qte").visible)
	assert(lesson._remaining > 3.5)
	var seated_position := actor.position
	Input.action_press("move_left")
	await _frames(3)
	Input.action_release("move_left")
	assert(actor.position == seated_position)
	var delays: Array[float] = []
	var all_success := "--all-success" in OS.get_cmdline_user_args()
	for index: int in 6:
		if index > 0:
			delays.append(lesson._remaining)
			assert(lesson._remaining >= lesson.minimum_qte_delay - 0.1)
			assert(lesson._remaining <= lesson.maximum_qte_delay)
		assert(not lesson.get_node("Screen").visible)
		await _resolve_segment(lesson, all_success or index != 2)
	assert(delays[0] != delays[1])
	assert(notes.is_class_finished())
	assert(notes.is_complete() == all_success)
	assert(lesson.get_node("Screen").visible)
	assert(not lesson.get_node("Qte").visible)
	assert(paused)
	assert(lesson.get_node("Screen/Scroll/Content/Blueprint").visible == all_success)
	if all_success:
		for index: int in 6:
			assert(blueprint.has_piece(index))
		lesson._open_blueprint()
		assert(lesson._popup.visible)
		lesson._popup.hide()
	else:
		assert(not notes.has_note(2))
		assert("________________" in lesson.get_node("Screen/Scroll/Content/Notes").text)
		assert(notes.unlock_blueprint() == ERR_UNAUTHORIZED)
		assert(notes.begin_material(2) == ERR_ALREADY_EXISTS)
		assert(notes.finish_material(2, true) == ERR_UNAUTHORIZED)
	lesson._close()
	await _frames(2)
	assert(not paused)
	assert(not actor.is_studying())
	assert(actor.get_node("Visual/AnimatedSprite2D").is_playing())
	assert(not classroom.get_node("Seat").available)
	classroom._open_lesson()
	assert(not is_instance_valid(classroom._lesson))
	classroom._open_notes()
	assert(is_instance_valid(classroom._lesson))
	assert(classroom._lesson.notes_only)
	classroom._lesson._close()
	await _frames(2)
	if all_success:
		print("PASS: seated world QTE, first delay, random intervals, overhead placement, final notes only, all-success blueprint unlock, no classroom replay")
		quit()
		return
	clock._absolute_minutes = 49 * 1440
	assert(clock.get_week() == 8)
	change_scene_to_file(CLASSROOM)
	await scene_changed
	await _frames(5)
	classroom = current_scene.get_node("ClassActivity")
	assert(not is_instance_valid(classroom._lesson))
	assert(classroom.get_node("Computer").available)
	_press(KEY_E)
	await _frames(2)
	assert(not is_instance_valid(classroom._exam))
	current_scene.get_node("Player").position.x = 1290
	await _frames(5)
	_press(KEY_E)
	await _frames(2)
	var exam: CanvasLayer = classroom._exam
	assert(is_instance_valid(exam))
	assert(paused)
	assert(exam.assignment.questions.size() == 10)
	assert(exam.duration_seconds == 600.0)
	assert(clock._timer.paused)
	exam._quiz._select_answer(exam.assignment.questions[0].correct_option)
	var previous_deadline: float = exam._deadline_unix
	exam.free()
	await _frames(2)
	assert(not paused)
	_press(KEY_E)
	await _frames(2)
	exam = classroom._exam
	assert(exam._deadline_unix == previous_deadline)
	assert(exam._quiz._answers[0] == exam.assignment.questions[0].correct_option)
	var start_minutes: int = clock.get_absolute_minutes()
	clock._assessment_started_msec -= 360000
	exam._deadline_msec -= 360000
	for index: int in 10:
		exam._quiz._question_index = index
		exam._quiz._select_answer(exam.assignment.questions[index].correct_option)
	exam._quiz._submit()
	assert(Results.read_result("classroom_midterm_week_8").score == 10)
	assert(clock.get_absolute_minutes() == start_minutes + 6)
	exam._close()
	await _frames(2)
	assert(not paused)
	assert(classroom.get_node("Computer")._interact())
	await _frames(2)
	exam = classroom._exam
	assert(exam._finished)
	assert(not is_instance_valid(exam._quiz))
	exam._close()
	await _frames(2)
	clock._absolute_minutes = 105 * 1440
	assert(clock.get_week() == 16)
	change_scene_to_file(CLASSROOM)
	await scene_changed
	await _frames(5)
	classroom = current_scene.get_node("ClassActivity")
	current_scene.get_node("Player").position.x = 1290
	await _frames(5)
	_press(KEY_E)
	await _frames(2)
	exam = classroom._exam
	assert(exam.assignment.id == "classroom_final_week_16")
	for index: int in 3:
		exam._quiz._question_index = index
		exam._quiz._select_answer(exam.assignment.questions[index].correct_option)
	start_minutes = clock.get_absolute_minutes()
	clock._assessment_started_msec -= 600000
	exam._deadline_msec = Time.get_ticks_msec() - 1
	exam._process(0.0)
	assert(exam._timed_out)
	assert(exam._finished)
	assert(Results.read_result("classroom_final_week_16").score == 3)
	assert(clock.get_absolute_minutes() == start_minutes + 10)
	exam._close()
	await _frames(2)
	assert(not paused)
	assert(not clock._timer.paused)
	change_scene_to_file("res://scenes/movement/campus_lab_room.tscn")
	await scene_changed
	await _frames(3)
	assert(not current_scene.get_node("ClassActivity").classroom_enabled)
	assert(not paused)
	print("PASS: seat interaction, overhead QTE, random intervals, final notes, no replay of missed material, assessment clock, week 8/16 exams, draft resume, timeout, lab isolation")
	quit()


func _resolve_segment(lesson: CanvasLayer, success: bool) -> void:
	lesson._remaining = 0.0
	lesson._process(0.0)
	assert(lesson._phase == lesson.Phase.FOCUS)
	var qte := lesson.get_node("Qte")
	var material: int = lesson._indices[lesson._segment]
	var difficulty := clampf((float(material) / 5.0 - 0.5) * 2.0, 0.0, 1.0)
	assert(is_equal_approx(qte.duration_seconds, lerpf(3.0, 1.8, difficulty)))
	assert(is_equal_approx(qte.target_width, lerpf(0.18, 0.1, difficulty)))
	lesson._position_qte()
	var head: Vector2 = lesson.player.get_global_transform_with_canvas() * Vector2(0, -76)
	assert(absf(qte.position.x + qte.size.x * 0.5 - head.x) < 1.0)
	assert(qte.position.y + qte.size.y < head.y)
	if success:
		qte._elapsed = (qte._target_start + qte.target_width * 0.5) * qte.duration_seconds
		if lesson._indices[lesson._segment] == 0:
			_press(KEY_SPACE)
			await _frames(2)
		else:
			var event := InputEventAction.new()
			event.action = &"class_focus"
			event.pressed = true
			qte._input(event)
	else:
		qte._elapsed = qte.duration_seconds
		qte._process(0.0)
	assert(lesson._phase == lesson.Phase.FEEDBACK)
	lesson._remaining = 0.0
	lesson._process(0.0)
	await _frames(1)


func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _frames(count: int) -> void:
	for frame: int in count:
		await physics_frame
