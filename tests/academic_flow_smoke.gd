extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var Assessment: GDScript = load("res://scripts/academic/assessment.gd")
	var career := root.get_node("CareerProgress")
	var clock := root.get_node("GameClock")
	var stats := root.get_node("PlayerStats")
	if "--reload" in OS.get_cmdline_user_args():
		assert(root.get_node("GameSave").load_game() == OK)
		await scene_changed
		assert(career.class_data(1, 1).complete.size() == 2)
		assert(career.state.results["s1_w1_kuis"] == 100)
		assert(career.state.results["s1_w8_uts"] == 0)
		print("PASS: academic notes and grades survive a fresh process")
		quit()
		return
	clock.restore_save_state({"minutes": 600, "remainder": 0})
	change_scene_to_file("res://scenes/movement/campus_classroom.tscn")
	await scene_changed
	await physics_frame
	await physics_frame
	var classroom := current_scene.get_node("ClassActivity")
	var player := current_scene.get_node("Player")
	player.position = classroom.get_node("Seat").global_position
	await physics_frame
	await physics_frame
	var class_start: int = clock.get_absolute_minutes()
	classroom._open_lesson()
	var lesson: CanvasLayer = classroom._lesson
	assert(is_instance_valid(lesson) and player.is_studying())
	assert(not lesson._qte.visible and lesson._delay == 4)
	for index: int in 3:
		lesson._process(12)
		assert(lesson._qte.visible and lesson._phase == 1)
		if index == 0 and "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/academic-qte.png")
		lesson._qte._resolve(index != 1)
		lesson._process(1.3)
	assert(career.class_data(1, 1).finished)
	assert(career.class_data(1, 1).complete.size() == 2)
	assert(clock.get_absolute_minutes() == class_start + 120)
	await process_frame
	lesson._summary.close()
	await process_frame
	assert(not player.is_studying() and not paused)
	classroom._open_lesson()
	assert(not is_instance_valid(classroom._lesson))
	var assessment: CanvasLayer = Assessment.new()
	assessment.kind = "kuis"
	current_scene.add_child(assessment)
	await process_frame
	assert(assessment.questions.size() == 10 and assessment.deadline > 0)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/academic-assessment.png")
	assessment._answer(assessment.questions[0].correct)
	var deadline: float = assessment.deadline
	assessment.queue_free()
	await process_frame
	var energy: float = stats.get_energy()
	assessment = Assessment.new()
	current_scene.add_child(assessment)
	await process_frame
	assert(assessment.answers[0] == assessment.questions[0].correct)
	assert(assessment.deadline == deadline)
	assert(stats.get_energy() == energy)
	for index: int in 10:
		assessment.answers[index] = assessment.questions[index].correct
	clock._assessment_started_msec -= 360000
	assessment.submit()
	assert(career.state.results["s1_w1_kuis"] == 100)
	assert(clock.get_absolute_minutes() == class_start + 126)
	assessment.close()
	await process_frame
	stats.set_energy(100)
	clock.restore_save_state({"minutes": 49 * 1440 + 600, "remainder": 0})
	await process_frame
	assert(classroom._week == 8 and classroom.get_node("Computer").available)
	classroom._open_exam()
	await process_frame
	assert(classroom._exam.kind == "uts")
	classroom._exam.deadline = Time.get_unix_time_from_system() - 1
	classroom._exam._process(0)
	assert(career.state.results["s1_w8_uts"] == 0)
	classroom._exam.close()
	await process_frame
	clock.restore_save_state({"minutes": 6 * 1440, "remainder": 0})
	assessment = Assessment.new()
	assessment.kind = "tugas"
	current_scene.add_child(assessment)
	assert(assessment._finished and assessment._overdue())
	assert(not career.state.results.has("s1_w1_tugas"))
	assessment.close()
	await process_frame
	var dashboard := load("res://scenes/interaction/desktop/word_explorer_home.tscn").instantiate() as Control
	current_scene.add_child(dashboard)
	assert(dashboard.get_child_count() >= 8)
	assert(root.get_node("GameSave").save_now() == OK)
	print("PASS: curriculum classroom, overhead QTE, no replay, class +2h, quiz draft/reload, six real minutes, UTS week 8, timeout, task deadline, LMS history")
	quit()
