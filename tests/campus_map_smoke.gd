extends SceneTree

const CAMPUS := "res://scenes/movement/top_down_movement.tscn"
const ROOM := "res://scenes/movement/dorm_room203.tscn"


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var saves := root.get_node("GameSave")
	var clock := root.get_node("GameClock")
	var stats := root.get_node("PlayerStats")
	root.size = Vector2i(1280, 720)
	root.get_node("SceneTransition").fade_seconds = 0.05
	clock.restore_save_state({"minutes": 720, "remainder": 0})
	change_scene_to_file(CAMPUS)
	await scene_changed
	await _frames(6)
	var world := current_scene
	assert(world.get_node("CampusMap").ART.get_size() == Vector2(3072, 576))
	assert(world.get_node("Player/Camera2D").limit_right == 3072)
	assert(world.left_destination.is_empty() and world.right_destination.is_empty())
	var light := world.get_node("WorldFeatures/WorldLighting")
	for pair: Array in [[1080, 0.0], [1320, 0.2], [0, 0.3], [120, 0.4], [150, 0.4], [180, 0.4], [270, 0.2], [360, 0.0], [720, 0.0]]:
		assert(is_equal_approx(light.darkness_for_minute(pair[0]), pair[1]))
	for point: float in [610, 1755, 2505]:
		world.get_node("Player").position = Vector2(point, 592)
		world.get_node("Player/Camera2D").reset_smoothing()
		await _frames(6)
		await _capture("campus-" + str(int(point)))
	var library := world.get_node("LibraryDoor")
	assert(library.interact())
	await process_frame
	assert(current_scene == world)
	assert(library._panel.content.get_child(0).text == "Gedung belum tersedia")
	library._panel.close()
	await process_frame
	await _enter("DormDoor", "dorm_floor1")
	assert(current_scene.get_node("Decor")._doors.size() == 8)
	assert(current_scene.get_node("Decor")._doors[7].y == 108)
	assert(current_scene.get_node("Decor").DOOR.resource_path.ends_with("single_door.png"))
	assert(current_scene.get_node("Decor").STAIRS.resource_path.ends_with("stairs.png"))
	current_scene.get_node("Player").position = Vector2(2773, 592)
	await _frames(6)
	await _capture("dorm-stairs-native")
	await _enter("Stairs", "dorm_floor2")
	var doors: Array = current_scene.get_node("Decor")._doors
	assert(doors.size() == 8 and doors[0].y == 201 and doors[7].y == 208)
	assert(doors[2] == Vector2i(940, 203))
	assert(not current_scene.has_node("Decor/Room203"))
	assert(current_scene.get_node("Stairs").destination == ROOM)
	await _enter("Stairs", "dorm_room203")
	assert(current_scene.room_rect.size == Vector2(2048, 576))
	assert(current_scene.get_node("Player/Camera2D").enabled)
	assert(current_scene.get_node("Furniture/Bed").scale == Vector2.ONE)
	stats.set_energy(71)
	var id: String = stats.student_id
	assert(saves.save_now() == OK)
	var old := ConfigFile.new()
	assert(old.load(saves.SAVE_PATH) == OK)
	old.set_value("save", "version", 3)
	old.set_value("world", "scene", "res://scenes/movement/dorm_room210.tscn")
	old.set_value("world", "world_scene", "res://scenes/movement/dorm_room210.tscn")
	assert(old.save(saves.SAVE_PATH) == OK)
	assert(saves.load_game() == OK)
	await scene_changed
	await _frames(4)
	assert(current_scene.scene_file_path == ROOM)
	assert(stats.get_energy() == 71 and stats.student_id == id)
	assert(saves.open_desktop_from(current_scene, &"ComputerSpawn"))
	await scene_changed
	if root.get_node("SceneTransition").is_active():
		await root.get_node("SceneTransition").transition_finished
	current_scene.get_node("StartupSound").stop()
	assert(saves.save_now() == OK)
	var desktop_legacy := ConfigFile.new()
	assert(desktop_legacy.load(saves.SAVE_PATH) == OK)
	desktop_legacy.set_value("save", "version", 3)
	desktop_legacy.set_value("world", "world_scene", "res://scenes/movement/dorm_room210.tscn")
	assert(desktop_legacy.save(saves.SAVE_PATH) == OK)
	assert(saves.load_game() == OK)
	await scene_changed
	await _frames(4)
	assert(current_scene.scene_file_path == saves.DESKTOP_SCENE)
	assert(current_scene.return_scene == ROOM)
	current_scene.get_node("StartupSound").stop()
	current_scene._request_turn_off()
	await scene_changed
	if root.get_node("SceneTransition").is_active():
		await root.get_node("SceneTransition").transition_finished
	await _frames(4)
	assert(current_scene.scene_file_path == ROOM)
	await _enter("Door", "dorm_floor2")
	assert(absf(current_scene.get_node("Player").position.x - 940) < 1)
	await _enter("Door", "dorm_floor1")
	assert(absf(current_scene.get_node("Player").position.x - 2773) < 1)
	await _enter("Door", "top_down_movement")
	assert(absf(current_scene.get_node("Player").position.x - 610) < 1)
	await _enter("Door", "classroom_corridor_floor1")
	await _enter("Exit", "top_down_movement")
	assert(absf(current_scene.get_node("Player").position.x - 1755) < 1)
	current_scene.get_node("Player").position.x = 2990
	await _frames(4)
	assert(saves.save_now() == OK and saves.has_save())
	assert(saves.load_game() == OK)
	await scene_changed
	await _frames(4)
	assert(absf(current_scene.get_node("Player").position.x - 2990) < 1)
	clock.restore_save_state({"minutes": 120, "remainder": 0})
	await create_timer(0.4).timeout
	assert(is_equal_approx(current_scene.get_node("WorldFeatures/WorldLighting").screen.color.a, 0.4))
	await _capture("campus-night")
	print("PASS: native campus, three building interactions, dorm/college return spawns, eight-room halls, room 203, version 3 room migration, far-edge save/load and night-light schedule")
	quit()


func _enter(id: String, target: String) -> void:
	var door := current_scene.get_node(id)
	current_scene.get_node("Player").position = Vector2(door.position.x, 592)
	await _frames(6)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	key = InputEventKey.new()
	key.physical_keycode = KEY_E
	Input.parse_input_event(key)
	await scene_changed
	var transition := root.get_node("SceneTransition")
	if transition.is_active():
		await transition.transition_finished
	await _frames(4)
	assert(current_scene.scene_file_path.ends_with(target + ".tscn"))


func _capture(id: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + id + ".png")


func _frames(count: int) -> void:
	for index: int in count:
		await physics_frame
