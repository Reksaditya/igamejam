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
	assert(not career.blueprint_ready(1))
	var blueprint_ids := ["core_drive", "sediment_sorter", "sieve_shaker", "core_centrifuge"]
	for index in blueprint_ids.size():
		assert(Curriculum.blueprint_for_lesson(index + 1, 1) == blueprint_ids[index])
		assert(Curriculum.blueprint_for_lesson(index + 1, 2).is_empty())
	assert(career.review_class(1, 1, "salah") == ERR_UNAUTHORIZED)
	var review_start: int = clock.get_absolute_minutes()
	assert(career.review_details(1, 1).missing == PackedInt32Array([1]))
	assert(career.review_details(1, 1).minutes == 60)
	assert(DirAccess.make_dir_absolute("user://career_progress.cfg.tmp") == OK)
	assert(career.review_class(1, 1, "tuas") != OK)
	assert(clock.get_absolute_minutes() == review_start and not career.blueprint_ready(1))
	assert(career.class_data(1, 1).complete.size() == 2)
	assert(DirAccess.remove_absolute("user://career_progress.cfg.tmp") == OK)
	assert(career.review_class(1, 1, "tuas") == OK)
	assert(clock.get_absolute_minutes() == review_start + 60)
	assert(career.review_class(1, 1, "") == OK and clock.get_absolute_minutes() == review_start + 60)
	assert(career.blueprint_ready(1))
	assert(career.class_data(1, 1).complete.size() == 3)
	career.reload_progress()
	assert(career.class_data(1, 1).finished)
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
	for index: int in 3:
		assert(career.attempt_section(1, 2, index) == OK)
		assert(career.finish_section(1, 2, index, index == 0) == OK)
	assert(career.finish_class(1, 2) == OK)
	assert(career.review_details(1, 2).missing == PackedInt32Array([1, 2]))
	assert(career.review_details(1, 2).minutes == 120)
	review_start = clock.get_absolute_minutes()
	assert(career.review_class(1, 2, Curriculum.lesson(1, 2).keyword) == OK)
	assert(clock.get_absolute_minutes() == review_start + 120)
	assert(career.class_data(1, 2).complete == [0, 1, 2])
	var blueprints := root.get_node("ProjectBlueprints")
	assert(not blueprints.is_owned("sediment_sorter"))
	career.state.placed["2"] = [0, 1]
	career.state.placed["3"] = [0, 1, 2, 3, 4, 5, 6, 7, 8]
	assert(career._save(career.state.duplicate(true)) == OK)
	career.reload_progress()
	assert(not blueprints.is_owned("sediment_sorter") and blueprints.is_owned("sieve_shaker"))
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
	print("PASS: 8 semesters, 128 weeks, ten valid questions per assessment, energy once per activity, class attempts, review cost and save rollback, blueprint mappings, exact GPA weights, class +120 minutes")
	quit()
