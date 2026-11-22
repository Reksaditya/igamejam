extends SceneTree

const CAMPUS := "res://scenes/movement/top_down_movement.tscn"


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	root.get_node("GameClock").restore_save_state({"minutes": 720, "remainder": 0})
	change_scene_to_file(CAMPUS)
	await scene_changed
	await _frames(8)
	var world := current_scene
	var player := world.get_node("Player") as CharacterBody2D
	assert(player.is_on_floor())
	var start := player.position
	Input.action_press("move_right")
	await _frames(15)
	Input.action_release("move_right")
	assert(player.position.x > start.x + 20)
	assert(player.get_node("Visual/AnimatedSprite2D").animation == &"walk")
	player.position.x = 1100
	await _frames(4)
	for key: Key in [KEY_SPACE, KEY_W, KEY_UP]:
		_press_key(key)
		await _frames(4)
		assert(absf(player.position.y - start.y) < 1)
		assert(current_scene == world)
	assert(not world.get_node("LeftExit").monitoring and not world.get_node("RightExit").monitoring)
	for right: bool in [false, true]:
		player.position.x = 3049 if right else 23
		var direction := "move_right" if right else "move_left"
		Input.action_press(direction)
		await _frames(30)
		Input.action_release(direction)
		assert(current_scene == world)
		assert(player.position.x >= 20 and player.position.x <= 3052)
	assert(not world.has_node("DesktopAccess"))
	assert(world.get_node("PlayerProfile")._hud_clock.text == root.get_node("GameClock").get_formatted_time())
	print("PASS: native campus walking, walk animation, no jumping, no edge teleports, invisible world bounds and persistent clock HUD")
	quit()


func _press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = key
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for index: int in count:
		await physics_frame
