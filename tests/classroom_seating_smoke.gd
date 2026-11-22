extends SceneTree


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var clock := root.get_node("GameClock")
	var career := root.get_node("CareerProgress")
	clock.restore_save_state({"minutes": 480, "remainder": 0})
	change_scene_to_file("res://scenes/movement/campus_classroom.tscn")
	await scene_changed
	root.size = Vector2i(1920, 720)
	await _frames(8)
	var room := current_scene
	var classroom := room.get_node("ClassActivity")
	var player := room.get_node("Player") as CharacterBody2D
	var standing_scale: Vector2 = player.get_node("Visual").scale
	assert(classroom._seats.size() == 4)
	assert(room.get_node("Background").CLASSROOM.resource_path == "res://assets/classroom/background.png")
	assert(room.get_node("Background").z_index < player.z_index)
	assert(classroom.get_node("Desks").z_index > player.z_index)
	for index: int in 4:
		var seat: Area2D = classroom._seats[index]
		clock.restore_save_state({"minutes": index * 1440 + 480, "remainder": 0})
		player.position = seat.global_position
		await _frames(8)
		assert(seat.get_node("Chair").texture.resource_path == "res://assets/classroom/chair%d.png" % (index + 1))
		assert(seat.get_node("Chair").z_index < player.z_index)
		assert(seat.get_node("Chair").z_index > room.get_node("Background").z_index)
		assert(seat.get_node("Prompt").visible)
		if index == 0:
			await _capture("classroom-standing")
		_press_e()
		await _frames(4)
		var lesson: CanvasLayer = classroom._lesson
		assert(is_instance_valid(lesson) and player.is_studying())
		assert(player.global_position.is_equal_approx(seat.get_node("SeatPoint").global_position))
		assert(player.get_node("Visual").scale.x > 0)
		assert(player.get_node("Visual/AnimatedSprite2D").animation == &"sit")
		if index == 0:
			await _capture("classroom-seated")
		for section: int in 3:
			lesson._process(12)
			assert(lesson._qte.visible)
			if index == 0 and section == 0:
				await _capture("classroom-qte")
			lesson._qte._resolve(true)
			lesson._process(1.3)
		assert(career.class_data(1, index + 1).finished)
		await _frames(4)
		assert(paused and lesson._summary.window.visible)
		lesson._summary.close()
		await scene_changed
		await root.get_node("SceneTransition").transition_finished
		assert(current_scene.scene_file_path.ends_with("classroom_corridor_floor1.tscn"))
		assert(not paused)
		change_scene_to_file("res://scenes/movement/campus_classroom.tscn")
		await scene_changed
		await _frames(4)
		room = current_scene
		classroom = current_scene.get_node("ClassActivity")
		player = current_scene.get_node("Player")
		seat = classroom._seats[index]
		player.position = seat.global_position
		await _frames(4)
		assert(not player.is_studying())
		assert(player.get_node("Visual").scale.is_equal_approx(standing_scale))
		_press_e()
		await _frames(4)
		assert(classroom._manual_seated and player.is_studying())
		assert(not is_instance_valid(classroom._lesson))
		if index == 0:
			await _capture("classroom-manual-seated")
		var point := player.position
		Input.action_press("move_right")
		await _frames(5)
		Input.action_release("move_right")
		assert(player.position == point)
		seat.get_node("Prompt").pressed.emit()
		await _frames(4)
		assert(not classroom._manual_seated and not player.is_studying())
	clock.restore_save_state({"minutes": 5 * 1440 + 480, "remainder": 0})
	player.position = classroom._seats[1].global_position
	await _frames(8)
	_press_e()
	await _frames(4)
	assert(classroom._manual_seated and not is_instance_valid(classroom._lesson))
	assert(classroom.get_node("Computer").available)
	_press_e()
	await _frames(4)
	assert(not player.is_studying())
	change_scene_to_file("res://scenes/movement/campus_lab_room.tscn")
	await scene_changed
	assert(current_scene.get_node("Background").laboratory)
	assert(not current_scene.get_node("ClassActivity/Desks").visible)
	for seat: Area2D in current_scene.get_node("ClassActivity")._seats:
		assert(not seat.visible and not seat.available)
	print("PASS: supplied classroom assets, four E seats, seated QTE, study once, movement lock, E/button stand, exam-week sitting and unchanged laboratory")
	quit()


func _press_e() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for index: int in count:
		await physics_frame


func _capture(id: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + id + ".png")
