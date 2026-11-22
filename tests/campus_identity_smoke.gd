extends SceneTree

const CAMPUS := "res://scenes/movement/top_down_movement.tscn"
const F1 := "res://scenes/movement/classroom_corridor_floor1.tscn"
const F2 := "res://scenes/movement/classroom_corridor_floor2.tscn"
const F3 := "res://scenes/movement/classroom_corridor_floor3.tscn"
const LAB := "res://scenes/movement/campus_lab_room.tscn"
const OLD_LAB := "res://scenes/movement/campus_lab.tscn"


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var saves := root.get_node("GameSave")
	var stats := root.get_node("PlayerStats")
	root.get_node("SceneTransition").fade_seconds = 0.05
	if "--reload" in OS.get_cmdline_user_args():
		assert(saves.load_game() == OK)
		await scene_changed
		await _frames(4)
		assert(current_scene.scene_file_path == OLD_LAB and current_scene.floor_number == 3)
		assert(stats.player_name == "Yohan")
		await _enter("Door", LAB)
		await _enter("Door", F3)
		print("PASS: legacy laboratory exterior save opens floor 3 and retains working lab return")
		quit()
		return
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	assert(not current_scene.has_node("NameDialog"))
	current_scene._new_game()
	await scene_changed
	await _frames(4)
	assert(current_scene.scene_file_path == saves.INITIAL_SCENE)
	assert(stats.player_name == "Yohan")
	var original_id: String = stats.student_id
	assert(original_id.length() == 12 and original_id.begins_with("607"))
	stats.set_energy(71)
	assert(saves.save_now() == OK)
	var snapshot := ConfigFile.new()
	assert(snapshot.load(saves.SAVE_PATH) == OK)
	snapshot.set_value("profile", "player_name", "Nama Lama")
	assert(snapshot.save(saves.SAVE_PATH) == OK)
	assert(saves.load_game() == OK)
	await scene_changed
	assert(stats.player_name == "Yohan" and stats.student_id == original_id and stats.get_energy() == 71)
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	current_scene._new_game()
	assert(current_scene.get_node("%NewGameConfirm").visible)
	current_scene.get_node("%NewGameConfirm").hide()
	await _frames(4)
	assert(stats.student_id == original_id and stats.get_energy() == 71)
	current_scene._new_game()
	current_scene.get_node("%NewGameConfirm").confirmed.emit()
	current_scene.get_node("%NewGameConfirm").hide()
	await scene_changed
	assert(stats.player_name == "Yohan" and stats.student_id != original_id and stats.get_energy() == 100)
	change_scene_to_file(CAMPUS)
	await scene_changed
	assert(current_scene.left_destination.is_empty())
	assert(current_scene.right_destination.is_empty())
	await _enter("Door", F1)
	await _enter("Stairs", F2)
	await _enter("Stairs", F3)
	assert(current_scene.get_node("Door").destination == LAB)
	await _capture("college-lab-floor3")
	root.get_node("GameClock").restore_save_state({"minutes": 11 * 60, "remainder": 0})
	assert(not current_scene.get_node("Door")._is_classroom_door())
	await _enter("Door", LAB)
	assert(not current_scene.get_node("ClassActivity").classroom_enabled)
	assert(current_scene.has_node("WorkshopBench"))
	assert(saves.save_now() == OK and saves.load_game() == OK)
	await scene_changed
	assert(current_scene.scene_file_path == LAB)
	await _enter("WorkshopBench", saves.WORKSHOP_SCENE)
	if current_scene.is_tutorial_visible():
		current_scene.dismiss_tutorial()
	assert(current_scene.return_scene == LAB)
	current_scene._leave()
	await scene_changed
	await _settle(LAB)
	await _enter("Door", F3)
	change_scene_to_file(OLD_LAB)
	await scene_changed
	await _frames(4)
	assert(current_scene.floor_number == 3 and current_scene.get_node("Door").destination == LAB)
	assert(saves.save_now() == OK)
	print("PASS: no name input, fixed Yohan, random NIM, legacy name migration, reset confirmation, unified campus, floor 3 lab, workshop and save/Load")
	quit()


func _enter(id: String, destination: String) -> void:
	var target := current_scene.get_node(id) as Area2D
	current_scene.get_node("Player").position = Vector2(target.position.x, 592)
	await _frames(5)
	assert(target.overlaps_body(current_scene.get_node("Player")))
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	Input.parse_input_event(event)
	await scene_changed
	await _settle(destination)


func _settle(destination: String) -> void:
	var transition := root.get_node("SceneTransition")
	if transition.is_active():
		await transition.transition_finished
	await _frames(4)
	assert(current_scene.scene_file_path == destination and not paused)


func _frames(count: int) -> void:
	for index: int in count:
		await physics_frame


func _capture(id: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1920, 720)
		current_scene.get_node("Player").position = Vector2(1170, 592)
		await _frames(4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + id + ".png")
