extends SceneTree

const MENU := "res://scenes/ui/main_menu.tscn"
const Results = preload("res://scripts/interaction/desktop/lms/lms_results.gd")


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file(MENU)
	await scene_changed
	await process_frame
	var menu := current_scene
	var settings := root.get_node("GameSettings")
	if "--reload" in OS.get_cmdline_user_args():
		assert(is_equal_approx(settings.master_volume, 0.35))
		assert(settings.resolution_index == 1)
		assert(not menu.get_node("%Load").disabled)
		print("PASS: settings and gameplay save detected across sessions")
		menu._quit()
		return
	assert(paused)
	assert(menu.get_node("%Load").disabled)
	menu._load_game()
	assert(current_scene == menu)
	menu._show_settings()
	assert(menu.get_node("%SettingsPanel").visible)
	menu.get_node("%Volume").value = 0.0
	assert(AudioServer.is_bus_mute(0))
	menu._show_main()
	assert(not AudioServer.is_bus_mute(0))
	assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), settings.master_volume))
	menu._show_settings()
	menu.get_node("%Volume").value = 35.0
	menu.get_node("%Resolution").select(1)
	menu._apply_settings()
	assert(is_equal_approx(settings.master_volume, 0.35))
	assert(settings.resolution_index == 1)
	assert(FileAccess.file_exists("user://settings.cfg"))
	menu._show_main()
	assert(menu.get_node("%Load").disabled)
	var notes := root.get_node("ClassroomProgress")
	assert(notes.begin_material(0) == OK)
	assert(notes.finish_material(0, true) == OK)
	menu._refresh_saves()
	assert(not menu.get_node("%Load").disabled)
	menu._new_game()
	assert(menu.get_node("%NewGameConfirm").visible)
	menu.get_node("%NewGameConfirm").hide()
	assert(notes.has_note(0))
	assert(menu.get_node("%NewGame").has_focus())
	print("PASS: disabled empty Load, legacy progress detection, volume preview/cancel, settings save, New Game confirmation and cancellation, Quit")
	menu._quit()
