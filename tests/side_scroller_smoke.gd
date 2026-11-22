extends SceneTree

const COURTYARD := "res://scenes/movement/top_down_movement.tscn"
const LAB := "res://scenes/movement/campus_lab.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var clock := root.get_node("GameClock")
	change_scene_to_file(COURTYARD)
	await scene_changed
	await _wait_transition()
	await _wait_frames(10)
	var player := current_scene.get_node("Player") as CharacterBody2D
	assert(player.is_on_floor())
	var start_x := player.position.x
	Input.action_press("move_right")
	await _wait_frames(12)
	Input.action_release("move_right")
	assert(player.position.x > start_x + 20.0)
	var floor_y := player.position.y
	for key: Key in [KEY_SPACE, KEY_W, KEY_UP, KEY_E]:
		_press_key(key)
		await _wait_frames(10)
		assert(absf(player.position.y - floor_y) < 1.0)
		assert(current_scene.scene_file_path == COURTYARD)
	assert(player.is_on_floor())
	assert(absf(player.position.y - floor_y) < 1.0)
	await _check_door_range()
	await _cross_exit(true, LAB, 120.0)
	await _check_door_range()
	await _cross_exit(false, COURTYARD, 1800.0)
	await _cross_exit(false, LAB, 1800.0)
	await _cross_exit(true, COURTYARD, 120.0)
	assert(root.get_node("GameClock") == clock)
	assert(not current_scene.has_node("DesktopAccess"))
	assert(current_scene.get_node("PlayerProfile")._hud_clock.text == clock.get_formatted_time())
	change_scene_to_file("res://scenes/interaction/desktop/desktop.tscn")
	await scene_changed
	await _wait_transition()
	assert(current_scene.scene_file_path == "res://scenes/interaction/desktop/desktop.tscn")
	assert(root.get_node("GameClock") == clock)
	current_scene.get_node("StartupSound").stop()
	await _wait_frames(10)
	for world: String in [COURTYARD, LAB]:
		change_scene_to_file(world)
		await scene_changed
		await _wait_transition()
		player = current_scene.get_node("Player") as CharacterBody2D
		player.position = Vector2(925, 592)
		await _wait_frames(10)
		assert(current_scene.get_node("Door/Prompt").visible)
		_press_key(KEY_W)
		await _wait_frames(5)
		assert(current_scene.scene_file_path == world)
		_press_key(KEY_E)
		var transition := root.get_node("SceneTransition")
		var before_fade := player.position
		await create_timer(0.15).timeout
		assert(transition.is_active())
		assert(paused)
		assert(current_scene.scene_file_path == world)
		assert(transition.get_node("Screen").color.a > 0.0)
		assert(transition.get_node("Screen").color.a < 1.0)
		assert(player.position == before_fade)
		await scene_changed
		await _wait_transition()
		var room := "res://scenes/movement/campus_classroom.tscn" if world == COURTYARD else "res://scenes/movement/campus_lab_room.tscn"
		assert(current_scene.scene_file_path == room)
		assert(root.get_node("GameClock") == clock)
		await _wait_frames(10)
		player = current_scene.get_node("Player") as CharacterBody2D
		assert(absf(player.position.x - 1060.0) < 1.0)
		assert(not current_scene.get_node("Door/Prompt").visible)
		await _wait_frames(10)
		assert(current_scene.scene_file_path == room)
		player.position.x = 925.0
		await _wait_frames(10)
		assert(current_scene.get_node("Door/Prompt/Button").text == "E · Keluar")
		_press_key(KEY_E)
		await scene_changed
		await _wait_transition()
		await _wait_frames(10)
		assert(current_scene.scene_file_path == world)
		player = current_scene.get_node("Player") as CharacterBody2D
		assert(absf(player.position.x - 925.0) < 1.0)
		assert(current_scene.get_node("Door/Prompt").visible)
		assert(current_scene.get_node("Door/Prompt/Button").text == "E · Masuk")
		current_scene.get_node("Door/Prompt/Button").pressed.emit()
		await scene_changed
		await _wait_transition()
		assert(current_scene.scene_file_path == room)
	print("PASS: E and bubble interaction, both building interiors, exit and return positions, W inactive, walking, portals, world clock, removed desktop button")
	quit()


func _check_door_range() -> void:
	var player := current_scene.get_node("Player") as CharacterBody2D
	var world := current_scene
	player.position = Vector2(925, 592)
	await _wait_frames(10)
	assert(current_scene.get_node("Door/Prompt").visible)
	assert(current_scene == world)
	player.position.x = 700.0
	await _wait_frames(10)
	assert(not current_scene.get_node("Door/Prompt").visible)
	_press_key(KEY_E)
	await _wait_frames(5)
	assert(current_scene == world)


func _press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)


func _cross_exit(right: bool, target: String, spawn_x: float) -> void:
	var previous := current_scene
	var player := current_scene.get_node("Player") as CharacterBody2D
	player.position = Vector2(1800 if right else 120, 592)
	player.velocity = Vector2.ZERO
	var action := &"move_right" if right else &"move_left"
	Input.action_press(action)
	for frame: int in range(120):
		await physics_frame
		if current_scene != previous:
			break
	Input.action_release(action)
	if current_scene == null:
		await scene_changed
		await _wait_transition()
	assert(current_scene.scene_file_path == target)
	await _wait_frames(10)
	player = current_scene.get_node("Player") as CharacterBody2D
	assert(absf(player.position.x - spawn_x) < 10.0)
	assert(player.is_on_floor())
	assert(not current_scene._transitioning)
	assert(current_scene.get_node("LeftExit").get_overlapping_bodies().is_empty())
	assert(current_scene.get_node("RightExit").get_overlapping_bodies().is_empty())
	var arrived := current_scene
	await _wait_frames(10)
	assert(current_scene == arrived)


func _wait_frames(count: int) -> void:
	for frame: int in count:
		await physics_frame


func _wait_transition() -> void:
	var transition := root.get_node("SceneTransition")
	if transition.is_active():
		assert(paused)
		assert(transition.get_node("Screen").visible)
		assert(transition.get_node("Screen").color.a > 0.9)
		await transition.transition_finished
	assert(not transition.is_active())
	assert(not transition.get_node("Screen").visible)
	await process_frame
	var classroom := current_scene.get_node_or_null("ClassActivity")
	if classroom != null and is_instance_valid(classroom._lesson):
		classroom._lesson._close()
	assert(not paused)
