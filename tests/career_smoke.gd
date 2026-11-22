extends SceneTree

const Curriculum = preload("res://scripts/academic/curriculum.gd")


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var career := root.get_node("CareerProgress")
	var clock := root.get_node("GameClock")
	var stats := root.get_node("PlayerStats")
	assert(clock.seconds_per_minute == 0.5)
	for term: int in range(1, 9):
		assert(Curriculum.semester_at((term - 1) * 16 + 1) == term)
		for week: int in range(1, 17):
			var lesson := Curriculum.lesson(term, week)
			assert(not lesson.material.is_empty() and lesson.sections.size() == 3)
			var questions := Curriculum.questions(term, week, "kuis")
			assert(questions.size() == 10)
			var prompts: Array[String] = []
			for question: Dictionary in questions:
				assert(not prompts.has(question.prompt))
				prompts.append(question.prompt)
				assert(question.options.size() == 4 and question.correct in range(4))
				assert(question.options.count(question.options[question.correct]) == 1)
	assert(career.begin_activity("class", "class_s1_w1") == OK)
	assert(stats.get_energy() == 85)
	assert(career.begin_activity("class", "class_s1_w1") == OK)
	assert(stats.get_energy() == 85)
	for index: int in 3:
		assert(career.attempt_section(1, 1, index) == OK)
		assert(career.attempt_section(1, 1, index) == ERR_ALREADY_EXISTS)
		assert(career.finish_section(1, 1, index, index != 1) == OK)
	assert(career.finish_class(1, 1) == OK)
	assert(career.state.pieces.is_empty())
	assert(career.review_class(1, 1, "salah") == ERR_UNAUTHORIZED)
	assert(career.review_class(1, 1, "tuas") == OK)
	assert(career.state.pieces["1"].has(0))
	assert(career.class_data(1, 1).complete.size() == 3)
	career.reload_progress()
	assert(career.class_data(1, 1).finished)
	assert(career.place_piece(1, 0, 1) == ERR_INVALID_PARAMETER)
	assert(career.place_piece(1, 0, 0) == OK)
	assert(career.assemble_component(1, 0) == ERR_UNAUTHORIZED)
	for week: int in range(1, 17):
		assert(career.record_result(1, week, "tugas", 100) == OK)
		assert(career.record_result(1, week, "kuis", 100) == OK)
	assert(career.record_result(1, 8, "uts", 100) == OK)
	assert(career.record_result(1, 16, "uas", 100) == OK)
	assert(career.record_result(1, 16, "project", 100) == OK)
	assert(is_equal_approx(career.semester_grade(1), 4.0))
	assert(career.record_result(1, 1, "tugas", 0) == ERR_ALREADY_EXISTS)
	assert(career.can_advance_week())
	assert(career.advance_week() == OK)
	assert(clock.get_week() == 2 and clock.get_formatted_time() == "06:00")
	assert(not career.can_advance_week())
	clock.restore_save_state({"minutes": 600, "remainder": 0})
	var owner := Node.new()
	root.add_child(owner)
	assert(clock.begin_class(owner))
	await create_timer(0.6).timeout
	assert(clock.get_absolute_minutes() == 600)
	assert(clock.complete_class(owner))
	assert(clock.get_absolute_minutes() == 720)
	assert(not clock.complete_class(owner))
	owner.queue_free()
	clock.restore_save_state({"minutes": 105 * 1440 + 600, "remainder": 0})
	assert(career.advance_week() == OK)
	assert(career.semester() == 2 and career.week() == 1)
	assert(stats.get_gpa() == 2.0)
	print("PASS: 8 semesters, 128 weeks, ten valid questions per assessment, energy once per activity, irreversible classroom attempts, dorm review, puzzle gates, exact GPA weights, class +120 minutes")
	quit()
