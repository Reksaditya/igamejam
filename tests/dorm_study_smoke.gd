extends SceneTree


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var career := root.get_node("CareerProgress")
	var clock := root.get_node("GameClock")
	var stats := root.get_node("PlayerStats")
	var saves := root.get_node("GameSave")
	if "--reload" in OS.get_cmdline_user_args():
		assert(saves.load_game() == OK)
		await scene_changed
		assert(current_scene.scene_file_path.ends_with("dorm_room210.tscn"))
		assert(career.blueprint_ready(1))
		assert(career.class_data(1, 1).complete.size() == 3)
		print("PASS: dorm, restored notes and assembled blueprint persist across processes")
		quit()
		return
	clock.restore_save_state({"minutes": 23 * 60, "remainder": 0})
	stats.set_energy(20)
	assert(career.rest(8) == OK)
	assert(stats.get_energy() == 90 and stats.get_sanity() == 50)
	assert(clock.get_absolute_minutes() == 31 * 60)
	clock.restore_save_state({"minutes": 10 * 7 * 1440 + 600, "remainder": 0})
	stats.set_energy(100)
	var library: Control = load("res://scenes/interaction/desktop/library.tscn").instantiate()
	root.add_child(library)
	assert(library._books.size() == 9)
	for index: int in library._books.size():
		library._list.select(index)
		library._read(index)
		var book: Vector2i = library._books[index]
		library._keyword.text = career.Curriculum.lesson(book.x, book.y).keyword
		library._study()
	assert(career.state.pieces["1"].size() == 9)
	var project: Control = load("res://scenes/interaction/desktop/career_project.tscn").instantiate()
	root.add_child(project)
	assert(project._slots.get_child_count() == 9)
	project._select(0)
	project._place(1)
	assert(career.state.placed.get("1", []).is_empty())
	for index: int in 9:
		project._select(index)
		project._place(index)
	assert(career.blueprint_ready(1))
	library.queue_free()
	project.queue_free()
	change_scene_to_file("res://scenes/movement/dorm_exterior.tscn")
	await scene_changed
	for target: String in ["dorm_floor1", "dorm_floor2", "dorm_room210"]:
		var door := current_scene.get_node("Door" if target == "dorm_floor1" else "Stairs")
		current_scene.get_node("Player").position = door.position + Vector2(0, 52)
		for frame: int in 6:
			await physics_frame
		assert(door._request_open())
		await scene_changed
		await _transition()
		assert(current_scene.scene_file_path.ends_with(target + ".tscn"))
		assert(saves.save_now() == OK)
	assert(current_scene.get_node("Door").destination.ends_with("dorm_floor2.tscn"))
	var player := current_scene.get_node("Player")
	player.position = current_scene.get_node("ComputerSpawn").position
	for frame: int in 6:
		await physics_frame
	assert(current_scene.get_node("Computer").interact(), "Computer interaction at %s; paused=%s; overlaps=%s" % [player.position, paused, current_scene.get_node("Computer").get_overlapping_bodies()])
	await scene_changed
	await _transition()
	assert(current_scene.scene_file_path.ends_with("desktop.tscn"))
	current_scene.get_node("StartupSound").stop()
	current_scene._login._submit("123")
	var titles := []
	for launcher: Node in current_scene.get_node("%Launchers").get_children():
		titles.append(launcher.display_title)
	assert(titles.has("Library") and titles.has("Project") and titles.has("Blocks n Blast"))
	var blocks: Control = load("res://scenes/interaction/desktop/blocks/blocks_game.tscn").instantiate()
	current_scene.add_child(blocks)
	assert(blocks._tray.size() == 3 and not blocks._game_over)
	var placed := false
	for slot: int in 3:
		for y: int in 8:
			for x: int in 8:
				if not placed and blocks._can_place(slot, Vector2i(x, y)):
					blocks._place_piece(slot, Vector2i(x, y))
					placed = true
	assert(placed and blocks._score > 0)
	blocks.queue_free()
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/career-desktop.png")
		for title: String in ["Library", "Project"]:
			for launcher: Node in current_scene.get_node("%Launchers").get_children():
				if launcher.display_title == title:
					current_scene._open_launcher(launcher)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/career-" + title.to_lower() + ".png")
	current_scene._shutdown()
	await scene_changed
	await _transition()
	assert(current_scene.scene_file_path.ends_with("dorm_room210.tscn"))
	assert(is_equal_approx(current_scene.get_node("Player").position.x, current_scene.get_node("ComputerSpawn").position.x))
	assert(saves.save_now() == OK)
	print("PASS: late sleep, energy recovery, prior-week Library catch-up, keyword rewards, 3x3 silhouette puzzle, four dorm scenes, physical computer interaction, Blocks placement, desktop shutdown returns to room")
	quit()


func _transition() -> void:
	var transition := root.get_node("SceneTransition")
	if transition.is_active():
		await transition.transition_finished
