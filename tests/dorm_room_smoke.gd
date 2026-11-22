extends SceneTree

const ROOM := "res://scenes/movement/dorm_room210.tscn"


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var saves := root.get_node("GameSave")
	root.get_node("GameClock").restore_save_state({"minutes": 600, "remainder": 0})
	root.get_node("SceneTransition").fade_seconds = 0.05
	for floor_number: int in [1, 2]:
		change_scene_to_file("res://scenes/movement/dorm_floor%d.tscn" % floor_number)
		await scene_changed
		var corridor := current_scene.get_node("Decor")
		assert(corridor._doors.size() == 10)
		assert(corridor.floor_number == floor_number)
		if floor_number == 2:
			assert(corridor._doors.has(Vector2i(650, 210)))
			assert(current_scene.get_node("Stairs").destination == ROOM)
	change_scene_to_file(ROOM)
	await scene_changed
	await _frames(5)
	var room := current_scene
	var player := room.get_node("Player") as CharacterBody2D
	assert(not player.get_node("Camera2D").enabled)
	assert(not room.get_node("Background").visible)
	for id: String in ["Bed", "Nightstand", "Chair", "Clock"]:
		var sprite := room.get_node("Furniture/" + id) as Sprite2D
		assert(sprite.texture != null and sprite.texture.resource_path.begins_with("res://assets/furniture/dorm/"))
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1920, 1080)]:
		root.size = size
		await process_frame
		await process_frame
		var view := root.get_visible_rect().size
		assert(room.room_rect.size.is_equal_approx((view * 0.6).round()))
		assert(room.get_node("RoomBounds").get_child_count() == 4)
		player.position = Vector2(room.room_rect.position.x + 23, room.floor_y - 28)
		Input.action_press("move_left")
		await _frames(12)
		Input.action_release("move_left")
		assert(player.position.x >= room.room_rect.position.x + 21)
		assert(room.get_player_save_position(player).x < 84)
		player.position.x = room.room_rect.end.x - 23
		Input.action_press("move_right")
		await _frames(12)
		Input.action_release("move_right")
		assert(player.position.x <= room.room_rect.end.x - 21)
		assert(room.get_player_save_position(player).x > 1836)
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	var chair := room.get_node("Chair")
	player.position = chair.position + Vector2(0, 2)
	await _frames(6)
	assert(chair.overlaps_body(player), "chair %s player %s paused=%s" % [chair.position, player.position, paused])
	_press_e()
	await _frames(3)
	assert(chair.seated and player.is_studying(), "seated=%s tracked=%s paused=%s" % [chair.seated, chair._player, paused])
	var seated_position := player.position
	Input.action_press("move_right")
	await _frames(8)
	Input.action_release("move_right")
	assert(player.position == seated_position)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/dorm-room-seated.png")
	_press_e()
	await _frames(3)
	assert(not chair.seated and not player.is_studying())
	assert(player.get_node("Visual").scale.is_equal_approx(Vector2(1.5, 1.5)))
	var normalized: Vector2 = room.get_player_save_position(player)
	assert(saves.save_now() == OK)
	saves._enabled = false
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	root.size = Vector2i(960, 540)
	await process_frame
	assert(saves.load_game() == OK)
	await scene_changed
	await _frames(5)
	room = current_scene
	player = room.get_node("Player") as CharacterBody2D
	assert(room.get_player_save_position(player).distance_to(normalized) < 1.0)
	assert(not player.is_studying())
	player.position = room.get_node("ComputerSpawn").position
	await _frames(6)
	assert(room.get_node("Computer").interact())
	await scene_changed
	await _transition()
	current_scene.get_node("StartupSound").stop()
	current_scene._login._submit("123")
	current_scene._shutdown()
	await scene_changed
	await _transition()
	assert(current_scene.scene_file_path == ROOM)
	assert(current_scene.get_node("Player").position.distance_to(current_scene.get_node("ComputerSpawn").position) < 1)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/dorm-room-small.png")
		change_scene_to_file("res://scenes/movement/dorm_floor2.tscn")
		await scene_changed
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/dorm-floor2-doors.png")
	print("PASS: numbered dorm doors, room 210, supplied furniture, 60-percent room at three resolutions, four solid boundaries, E sit/stand, movement lock, normalized save/load, laptop and return spawn")
	quit()


func _press_e() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = false
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for index: int in count:
		await physics_frame


func _transition() -> void:
	if root.get_node("SceneTransition").is_active():
		await root.get_node("SceneTransition").transition_finished
