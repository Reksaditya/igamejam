extends SceneTree


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var clock := root.get_node("GameClock")
	var career := root.get_node("CareerProgress")
	var saves := root.get_node("GameSave")
	var transition := root.get_node("SceneTransition")
	transition.fade_seconds = 0.05
	for floor_number: int in range(1, 4):
		var room_path := "res://scenes/movement/campus_classroom.tscn" if floor_number == 1 else "res://scenes/movement/campus_classroom_floor%d.tscn" % floor_number
		var corridor_path := "res://scenes/movement/classroom_corridor_floor%d.tscn" % floor_number
		clock.restore_save_state({"minutes": (floor_number - 1) * 1440 + 480, "remainder": 0})
		change_scene_to_file(room_path)
		await scene_changed
		await _frames(4)
		var classroom := current_scene.get_node("ClassActivity")
		var player := current_scene.get_node("Player")
		player.position = classroom.get_node("Seat").global_position
		await _frames(4)
		classroom._open_lesson()
		var lesson: CanvasLayer = classroom._lesson
		assert(is_instance_valid(lesson))
		for section: int in 3:
			lesson._process(12)
			lesson._qte._resolve(section != 1)
			lesson._process(1.3)
		assert(career.class_data(1, floor_number).finished)
		assert(career.class_data(1, floor_number).complete.size() == 2)
		await _frames(4)
		assert(current_scene.scene_file_path == room_path and not transition.is_active())
		assert(lesson._summary.close_button.text == "Kembali ke lorong")
		lesson._summary.close_button.pressed.emit()
		await scene_changed
		await transition.transition_finished
		assert(current_scene.scene_file_path == corridor_path and not paused)
		player = current_scene.get_node("Player")
		assert(not player.is_studying())
		assert(player.position.distance_to(current_scene.get_node("DoorSpawn").position) < 1)
		assert(saves.save_now() == OK)
		assert(saves.load_game() == OK)
		await scene_changed
		assert(current_scene.scene_file_path == corridor_path)
		assert(career.class_data(1, floor_number).complete.size() == 2)
		change_scene_to_file(room_path)
		await scene_changed
		await _frames(4)
		classroom = current_scene.get_node("ClassActivity")
		classroom._open_notes()
		assert(classroom._lesson.notes_only)
		classroom._lesson._summary.close()
		await _frames(8)
		assert(current_scene.scene_file_path == room_path and not transition.is_active())
	clock.restore_save_state({"minutes": 3 * 1440 + 480, "remainder": 0})
	var classroom := current_scene.get_node("ClassActivity")
	current_scene.get_node("Player").position = classroom.get_node("Seat").global_position
	await _frames(4)
	classroom._open_lesson()
	classroom._lesson._close()
	await _frames(8)
	assert(current_scene.scene_file_path.ends_with("campus_classroom_floor3.tscn") and not transition.is_active())
	assert(not career.class_data(1, 4).finished)
	print("PASS: read final notes before teleport, correct F1/F2/F3 corridor with fade, incomplete notes retained, autosave/Load, review stays in class and unfinished class does not teleport")
	quit()


func _frames(count: int) -> void:
	for index: int in count:
		await physics_frame
