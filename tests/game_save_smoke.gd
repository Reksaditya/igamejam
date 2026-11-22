extends SceneTree

const MENU := "res://scenes/ui/main_menu.tscn"
const INITIAL := "res://scenes/movement/top_down_movement.tscn"
const LAB := "res://scenes/movement/campus_lab.tscn"
const DESKTOP := "res://scenes/interaction/desktop/desktop.tscn"
const Results = preload("res://scripts/interaction/desktop/lms/lms_results.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var saves := root.get_node("GameSave")
	var notes := root.get_node("ClassroomProgress")
	var blueprint := root.get_node("BlueprintProgress")
	var clock := root.get_node("GameClock")
	change_scene_to_file(MENU)
	await scene_changed
	await _frames(2)
	if "--legacy" in OS.get_cmdline_user_args():
		assert(notes.begin_material(1) == OK)
		assert(notes.finish_material(1, true) == OK)
		current_scene._refresh_saves()
		assert(not current_scene.get_node("%Load").disabled)
		current_scene._load_game()
		await scene_changed
		await _frames(2)
		assert(current_scene.scene_file_path == INITIAL)
		assert(notes.has_note(1))
		assert(saves.has_save())
		print("PASS: legacy progress migrates without losing notes")
		quit()
		return
	if "--reload" in OS.get_cmdline_user_args():
		assert(not current_scene.get_node("%Load").disabled)
		current_scene._load_game()
		await scene_changed
		await _frames(2)
		assert(current_scene.scene_file_path == INITIAL)
		assert(current_scene.get_node("Player").position.x == 777.0)
		assert(clock.get_absolute_minutes() == 123)
		assert(not notes.has_attempted(0))
		print("PASS: last position and clock restored after a fresh process")
		quit()
		return
	assert(current_scene.get_node("%Load").disabled)
	assert(not saves.has_save())
	current_scene._new_game()
	await scene_changed
	await _frames(2)
	assert(current_scene.scene_file_path == INITIAL)
	assert(not paused)
	assert(saves.has_save())
	var player := current_scene.get_node("Player") as CharacterBody2D
	player.position = Vector2(1350, 592)
	player.get_node("Visual").scale.x = -1.5
	clock.restore_save_state({"minutes": 1776, "remainder": 1234})
	assert(notes.begin_material(0) == OK)
	assert(notes.finish_material(0, true) == OK)
	assert(blueprint.complete_study("transmission_motor") == OK)
	assert(blueprint.place_piece(0, 0) == OK)
	assert(root.get_node("ProjectBlueprints").grant("sediment_sorter") == OK)
	assert(Results.save_result("save_test_quiz", 7, 10) == OK)
	assert(root.get_node("GameSettings").save_settings(0.35, 1) == OK)
	assert(DirAccess.make_dir_recursive_absolute("user://notes/lab") == OK)
	var note := FileAccess.open("user://notes/lab/report.txt", FileAccess.WRITE)
	note.store_string("Catatan desktop yang ikut direset")
	note.close()
	var draft := ConfigFile.new()
	draft.set_value("exam", "deadline", Time.get_unix_time_from_system() + 600.0)
	draft.set_value("exam", "answers", PackedInt32Array([1, -1]))
	assert(draft.save("user://classroom_classroom_midterm_week_8.cfg") == OK)
	assert(saves.save_now() == OK)
	var checkpoint := FileAccess.get_file_as_string(saves.SAVE_PATH)
	assert("report.txt" in checkpoint)
	assert("save_test_quiz.cfg" in checkpoint)
	saves._enabled = false
	change_scene_to_file(MENU)
	await scene_changed
	await _frames(2)
	assert(not current_scene.get_node("%Load").disabled)
	current_scene._new_game()
	var confirm := current_scene.get_node("%NewGameConfirm") as ConfirmationDialog
	assert(confirm.visible)
	assert(confirm.get_node("Content/Question").text == "Apakah Anda yakin ingin memulai permainan baru?")
	assert(confirm.get_node("Content/Subheader").text == "Seluruh data permainan yang tersimpan sebelumnya akan hilang.")
	confirm.hide()
	assert(FileAccess.get_file_as_string(saves.SAVE_PATH) == checkpoint)
	assert(notes.has_note(0))
	DirAccess.remove_absolute("user://classroom_notes.cfg")
	notes.reload_progress()
	assert(not notes.has_note(0))
	current_scene._load_game()
	await scene_changed
	await _frames(2)
	assert(current_scene.scene_file_path == INITIAL)
	player = current_scene.get_node("Player") as CharacterBody2D
	assert(player.position.x == 1350.0)
	assert(player.get_node("Visual").scale.x == -1.5)
	assert(clock.get_absolute_minutes() == 1776)
	assert(notes.has_note(0))
	assert(blueprint.is_placed(0))
	assert(root.get_node("ProjectBlueprints").is_owned("sediment_sorter"))
	assert(Results.read_result("save_test_quiz").score == 7)
	change_scene_to_file(LAB)
	await scene_changed
	await _frames(2)
	player = current_scene.get_node("Player") as CharacterBody2D
	player.position.x = 1500.0
	saves._process(2.1)
	assert(saves.last_save_error == OK)
	saves._enabled = false
	change_scene_to_file(MENU)
	await scene_changed
	current_scene._load_game()
	await scene_changed
	await _frames(2)
	assert(current_scene.scene_file_path == LAB)
	assert(current_scene.get_node("Player").position.x == 1500.0)
	change_scene_to_file(DESKTOP)
	await scene_changed
	current_scene.get_node("StartupSound").stop()
	await _frames(2)
	assert(saves.save_now() == OK)
	saves._enabled = false
	change_scene_to_file(MENU)
	await scene_changed
	current_scene._load_game()
	await scene_changed
	assert(current_scene.scene_file_path == DESKTOP)
	current_scene.get_node("StartupSound").stop()
	await _frames(2)
	saves._enabled = false
	change_scene_to_file(MENU)
	await scene_changed
	current_scene._new_game()
	assert(current_scene.get_node("%NewGameConfirm").visible)
	current_scene.get_node("%NewGameConfirm").confirmed.emit()
	await scene_changed
	await _frames(2)
	assert(current_scene.scene_file_path == INITIAL)
	assert(current_scene.get_node("Player").position.x == 320.0)
	assert(clock.get_absolute_minutes() == clock.MORNING_MINUTES)
	assert(not notes.has_attempted(0))
	assert(not blueprint.has_piece(0))
	assert(not root.get_node("ProjectBlueprints").is_owned("sediment_sorter"))
	assert(Results.read_result("save_test_quiz").is_empty())
	assert(not FileAccess.file_exists("user://classroom_classroom_midterm_week_8.cfg"))
	assert(not FileAccess.file_exists("user://notes/lab/report.txt"))
	assert(FileAccess.file_exists("user://settings.cfg"))
	assert(is_equal_approx(root.get_node("GameSettings").master_volume, 0.35))
	for directory: String in DirAccess.open("user://").get_directories():
		assert(not directory.begins_with(".reset_backup_"))
	current_scene.get_node("Player").position.x = 777.0
	clock.restore_save_state({"minutes": 123, "remainder": 0})
	print("PASS: first New Game, automatic checkpoint, direct Load, position/facing/clock/progress restore, desktop resume, confirmation cancellation, confirmed full gameplay reset, preserved settings, close autosave")
	saves._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)


func _frames(count: int) -> void:
	for frame: int in count:
		await physics_frame
