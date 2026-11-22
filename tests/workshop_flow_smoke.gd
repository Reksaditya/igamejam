extends SceneTree


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var career := root.get_node("CareerProgress")
	var clock := root.get_node("GameClock")
	var stats := root.get_node("PlayerStats")
	clock.restore_save_state({"minutes": 10 * 7 * 1440 + 600, "remainder": 0})
	assert(career.submit_project(1) == ERR_UNAUTHORIZED)
	change_scene_to_file("res://scenes/movement/campus_lab_room.tscn")
	await scene_changed
	var Workshop: GDScript = load("res://scripts/academic/workshop.gd")
	var workshop: CanvasLayer = Workshop.new()
	current_scene.add_child(workshop)
	await process_frame
	assert(not is_instance_valid(workshop._qte))
	workshop.close()
	await process_frame
	var overnight_start: int = clock.get_absolute_minutes()
	assert(career.review_class(1, 1, career.Curriculum.lesson(1, 1).keyword) == OK)
	assert(clock.get_absolute_minutes() > overnight_start and clock.get_formatted_time() == "06:00")
	assert(career.blueprint_ready(1))
	workshop = Workshop.new()
	current_scene.add_child(workshop)
	await process_frame
	workshop._pick(1)
	workshop._fit_component()
	assert(not workshop._qte._active)
	workshop._pick(0)
	workshop._fit_component()
	assert(workshop._qte._active)
	workshop._qte._resolve(false)
	assert(career.state.assembled.is_empty())
	for index: int in 6:
		workshop._pick(index)
		workshop._fit_component()
		assert(workshop._qte._active)
		if index == 2 and "--capture" in OS.get_cmdline_user_args():
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/career-workshop.png")
		if index == 2:
			workshop._qte._elapsed = workshop._qte.duration_seconds * (workshop._qte._target_start + workshop._qte.target_width * 0.5)
			var event := InputEventAction.new()
			event.action = "class_focus"
			event.pressed = true
			workshop._qte._input(event)
		else:
			workshop._qte._resolve(true)
	assert(career.state.assembled["1"].size() == 6)
	workshop.close()
	await process_frame
	change_scene_to_file("res://scenes/movement/lecturer_room.tscn")
	await scene_changed
	var lecturer: CanvasLayer = load("res://scripts/academic/lecturer.gd").new()
	current_scene.add_child(lecturer)
	await process_frame
	lecturer._submit(1)
	assert(career.state.results["s1_w16_project"] == 95)
	assert(career.submit_project(1) == ERR_ALREADY_EXISTS)
	lecturer.close()
	await process_frame
	clock.restore_save_state({"minutes": 122 * 7 * 1440 + 600, "remainder": 0})
	stats.set_energy(100)
	for term: int in range(5, 9):
		assert(career.blueprint_ready(term))
		assert(not career.state.pieces.has(str(term)) and not career.state.placed.has(str(term)))
	assert(career.assemble_component(8, 0) == ERR_UNAUTHORIZED)
	workshop = Workshop.new()
	current_scene.add_child(workshop)
	await process_frame
	assert(workshop._design_choices.size() == 3)
	workshop._save_design()
	assert(workshop._components()[1] == "Engkol")
	for index: int in 6:
		workshop._pick(index)
		workshop._fit_component()
		workshop._qte._resolve(true)
	assert(career.submit_project(8) == OK)
	assert(career.state.results["s8_w16_project"] == 100)
	workshop.close()
	await process_frame
	assert(root.get_node("GameSave").save_now() == OK)
	career.reload_progress()
	assert(career.state.flags.final_design[0] == "Engkol")
	assert(career.state.results["s8_w16_project"] == 100)
	print("PASS: blueprint gate, correct component pickup, assembly QTE success/failure, six components, lecturer scoring, no duplicate submission, final design affects components, persisted final project")
	quit()
