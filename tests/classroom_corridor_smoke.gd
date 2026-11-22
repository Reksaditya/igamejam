extends SceneTree

const CAMPUS := "res://scenes/movement/top_down_movement.tscn"
const F1 := "res://scenes/movement/classroom_corridor_floor1.tscn"
const F2 := "res://scenes/movement/classroom_corridor_floor2.tscn"
const F3 := "res://scenes/movement/classroom_corridor_floor3.tscn"


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	root.get_node("SceneTransition").fade_seconds = 0.05
	var saves := root.get_node("GameSave")
	if "--reload" in OS.get_cmdline_user_args():
		assert(saves.load_game() == OK)
		await scene_changed
		assert(current_scene.scene_file_path.ends_with("campus_classroom_floor3.tscn"))
		await _door("Door", F3)
		await _stairs(F2)
		await _choose("Turun ke lantai 1", F1)
		await _door("Exit", CAMPUS)
		assert(absf(current_scene.get_node("Player").position.x - 925) < 1)
		print("PASS: classroom floor 3 save/reload, correct return floor, stairs down F3-F2-F1 and campus exit")
		quit()
		return
	root.get_node("GameClock").restore_save_state({"minutes": 600, "remainder": 0})
	change_scene_to_file(CAMPUS)
	await scene_changed
	await _door("Door", F1)
	for floor_number: int in 3:
		assert(current_scene.floor_number == floor_number + 1)
		assert(current_scene.BACKGROUNDS[floor_number].resource_path.ends_with("floor%d.png" % (floor_number + 1)))
		assert(not current_scene.get_node("LeftExit").monitoring and not current_scene.get_node("RightExit").monitoring)
		var classroom_path := "res://scenes/movement/campus_classroom.tscn" if floor_number == 0 else "res://scenes/movement/campus_classroom_floor%d.tscn" % (floor_number + 1)
		var corridor_path := current_scene.scene_file_path
		await _capture("corridor-f%d" % (floor_number + 1))
		await _door("Door", classroom_path)
		assert(current_scene.get_node("Player").z_index > current_scene.get_node("ClassActivity/Seat/Chair").z_index)
		if floor_number == 2:
			assert(saves.save_now() == OK and saves.has_save())
			print("PASS: campus entry, supplied F1/F2/F3, E stairs only, F2 direction choice, three classroom doors and floor-aware save")
			quit()
			return
		await _door("Door", corridor_path)
		if floor_number == 0:
			await _stairs(F2)
		else:
			await _approach("Stairs")
			_press(KEY_E)
			await _frames(4)
			assert(is_instance_valid(current_scene._stairs_panel) and paused)
			current_scene._stairs_panel.close()
			await _frames(4)
			assert(not paused and current_scene.scene_file_path == F2)
			await _choose("Naik ke lantai 3", F3)


func _approach(id: String) -> void:
	var target := current_scene.get_node(id) as Area2D
	current_scene.get_node("Player").position = Vector2(target.position.x, 592)
	await _frames(8)
	assert(target.overlaps_body(current_scene.get_node("Player")))
	if id == "Stairs":
		assert(target.get_node("Prompt").visible)
		var path := current_scene.scene_file_path
		_press(KEY_W)
		await _frames(5)
		assert(current_scene.scene_file_path == path)


func _door(id: String, destination: String) -> void:
	await _approach(id)
	_press(KEY_E)
	await scene_changed
	await _settle(destination)


func _stairs(destination: String) -> void:
	await _approach("Stairs")
	_press(KEY_E)
	await scene_changed
	await _settle(destination)


func _choose(label: String, destination: String) -> void:
	await _approach("Stairs")
	_press(KEY_E)
	await _frames(4)
	var panel: CanvasLayer = current_scene._stairs_panel
	assert(is_instance_valid(panel) and paused)
	for child: Node in panel.content.get_children():
		if child is Button and child.text == label:
			child.pressed.emit()
			break
	await scene_changed
	await _settle(destination)


func _settle(destination: String) -> void:
	if root.get_node("SceneTransition").is_active():
		await root.get_node("SceneTransition").transition_finished
	await _frames(8)
	assert(current_scene.scene_file_path == destination and not paused)
	if destination in [F1, F2, F3]:
		assert(not root.get_node("SceneTransition").is_active())


func _frames(count: int) -> void:
	for index: int in count:
		await physics_frame


func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = key
	Input.parse_input_event(event)


func _capture(id: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1920, 720)
		current_scene.get_node("Player").position = Vector2(1620, 592)
		await _frames(5)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + id + ".png")
