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
		assert(current_scene.scene_file_path.ends_with("dorm_room203.tscn"))
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
	var library: Control = load("res://scenes/interaction/desktop/study/study_home.tscn").instantiate()
	root.add_child(library)
	var review := library.get_node("%ClassReview")
	var selected: int = review._books.find(Vector2i(1, 1))
	assert(selected >= 0 and not review._books.has(Vector2i(1, 12)))
	review._list.select(selected)
	review._read(selected)
	assert("06.00" in review._cost.text)
	review._keyword.text = career.Curriculum.lesson(1, 1).keyword
	review._study()
	assert(career.class_data(1, 1).complete == [0, 1, 2])
	assert(career.blueprint_ready(1))
	assert(clock.get_formatted_time() == "06:00")
	library.queue_free()
	change_scene_to_file("res://scenes/movement/top_down_movement.tscn")
	await scene_changed
	for target: String in ["dorm_floor1", "dorm_floor2", "dorm_room203"]:
		var door := current_scene.get_node("DormDoor" if target == "dorm_floor1" else "Stairs")
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
	assert(not titles.has("Materi Kuliah") and not titles.has("Proyek Kuliah") and titles.has("Project") and titles.has("Blocks n Blast"))
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
		for title: String in ["Project", "Word Explorer"]:
			for launcher: Node in current_scene.get_node("%Launchers").get_children():
				if launcher.display_title == title:
					current_scene._open_launcher(launcher)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/career-" + title.to_lower() + ".png")
	assert(saves.has_save())
	var checkpoint := ConfigFile.new()
	assert(checkpoint.load(saves.SAVE_PATH) == OK)
	assert(checkpoint.get_value("world", "scene") == saves.DESKTOP_SCENE)
	assert(checkpoint.get_value("world", "desktop_return_spawn") == "ComputerSpawn")
	await _click_turn_off_and_check_room()
	player = current_scene.get_node("Player")
	player.position = current_scene.get_node("ComputerSpawn").position
	for frame: int in 6:
		await physics_frame
	assert(current_scene.get_node("Computer").interact())
	await scene_changed
	await _transition()
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	current_scene._load_game()
	await scene_changed
	assert(current_scene.scene_file_path == saves.DESKTOP_SCENE)
	current_scene._login._submit("123")
	await _click_turn_off_and_check_room()
	assert(saves.save_now() == OK)
	print("PASS: Library overnight review and blueprint, in-room computer interaction, Blocks, normal and loaded desktop Turn off via pointer at ComputerSpawn")
	quit()


func _click_turn_off_and_check_room() -> void:
	while current_scene._boot_cover.visible:
		await process_frame
	var turn_off := current_scene.get_node("%TurnOff") as Button
	assert(not turn_off.disabled)
	var point := turn_off.get_global_rect().get_center()
	var movement := InputEventMouseMotion.new()
	movement.position = point
	root.push_input(movement, true)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.pressed = pressed
		root.push_input(click, true)
	assert(root.get_node("SceneTransition").is_active())
	await scene_changed
	await _transition()
	assert(current_scene.scene_file_path.ends_with("dorm_room203.tscn"))
	assert(is_equal_approx(current_scene.get_node("Player").position.x, current_scene.get_node("ComputerSpawn").position.x))


func _transition() -> void:
	var transition := root.get_node("SceneTransition")
	if transition.is_active():
		await transition.transition_finished
