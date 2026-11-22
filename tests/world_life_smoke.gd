extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var career := root.get_node("CareerProgress")
	var clock := root.get_node("GameClock")
	var stats := root.get_node("PlayerStats")
	var saves := root.get_node("GameSave")
	root.get_node("SceneTransition").fade_seconds = 0.05
	assert(saves.start_new_game("Life Test") == OK)
	await scene_changed
	assert(clock.get_absolute_minutes() >= 360 and clock.get_absolute_minutes() < 370)
	await create_timer(1.0).timeout
	var features := current_scene.get_node("WorldFeatures")
	assert(is_instance_valid(features._overlay) and features._overlay.event_id == "intro")
	assert(paused and features._overlay.window.visible)
	var before: int = clock.get_absolute_minutes()
	await create_timer(0.6).timeout
	assert(clock.get_absolute_minutes() == before)
	features._overlay._continue()
	await process_frame
	assert(not paused and career.state.flags.story_intro)
	clock.restore_save_state({"minutes": 22 * 60, "remainder": 0})
	assert(features._curfew_due)
	clock.restore_save_state({"minutes": 1440 + 360, "remainder": 0})
	features._process(1)
	assert(is_instance_valid(features._guard))
	features._guard._physics_process(2)
	await scene_changed
	await root.get_node("SceneTransition").transition_finished
	assert(current_scene.scene_file_path.ends_with("dorm_floor1.tscn"))
	features = current_scene.get_node("WorldFeatures")
	features._process(1)
	assert(not is_instance_valid(features._guard))
	clock.restore_save_state({"minutes": 32 * 7 * 1440 + 600, "remainder": 0})
	features._process(1)
	await process_frame
	assert(features._overlay.event_id == "busy")
	features._overlay._continue()
	await process_frame
	stats.set_energy(100)
	stats.set_sanity(40)
	clock.restore_save_state({"minutes": 71 * 7 * 1440 + 600, "remainder": 0})
	features._process(1)
	await process_frame
	assert(features._overlay.event_id == "loss")
	features._overlay._continue()
	await process_frame
	assert(stats.get_energy() == 60 and stats.get_sanity() == 80)
	assert(features._blur.visible)
	assert(career.acknowledge_story("loss") == ERR_ALREADY_EXISTS)
	assert(stats.get_energy() == 60)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/career-sanity-blur.png")
	clock.restore_save_state({"minutes": 80 * 7 * 1440 + 600, "remainder": 0})
	features._process(1)
	await process_frame
	assert(features._overlay.event_id == "promise")
	features._overlay._continue()
	await process_frame
	assert(stats.get_sanity() == 50 and not features._blur.visible)
	clock.restore_save_state({"minutes": 7 * 1440 + 600, "remainder": 0})
	change_scene_to_file("res://scenes/movement/campus_classroom.tscn")
	await scene_changed
	var classroom := current_scene.get_node("ClassActivity")
	var player := current_scene.get_node("Player")
	player.position = Vector2(700, 592)
	stats.set_energy(0)
	for frame: int in 6:
		await physics_frame
	classroom._open_lesson()
	var lesson: CanvasLayer = classroom._lesson
	assert(is_instance_valid(lesson))
	for index: int in 3:
		lesson._process(12)
		lesson._process(1.3)
	assert(career.class_data(1, 2).finished)
	assert(career.class_data(1, 2).complete.is_empty())
	await process_frame
	lesson._summary.close()
	await process_frame
	for term: int in range(1, 9):
		for week: int in range(1, 17):
			assert(career.record_result(term, week, "tugas", 100) == OK)
			assert(career.record_result(term, week, "kuis", 100) == OK)
		for item: Array in [[8, "uts"], [16, "uas"], [16, "project"]]:
			assert(career.record_result(term, item[0], item[1], 100) == OK)
	clock.restore_save_state({"minutes": 128 * 7 * 1440 + 360, "remainder": 0})
	assert(career.complete_career() == OK)
	assert(career.state.ending == "happy" and stats.get_gpa() == 4)
	assert(career.ending_for(3.49, true) == "basic")
	assert(career.ending_for(3.5, true) == "happy")
	assert(career.ending_for(4.0, false) == "bad")
	features = current_scene.get_node("WorldFeatures")
	features._process(1)
	await process_frame
	assert(features._overlay.ending)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/career-ending.png")
	features._overlay._happy_trip()
	features._overlay._main_menu()
	await scene_changed
	assert(current_scene.scene_file_path.ends_with("main_menu.tscn"))
	assert(saves.load_game() == OK)
	await scene_changed
	assert(career.state.ending == "happy" and career.state.flags.story_loss)
	print("PASS: normal New Game intro, paused story clock, 22:00 guard escort, safe dorm, four chapters, one-time stat effects, sanity blur/recovery, zero-energy classroom sleep, GPA 4.00, all three ending conditions, ending reload")
	quit()
