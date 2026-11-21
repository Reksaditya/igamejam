extends SceneTree

const MENU := "res://scenes/ui/main_menu.tscn"
const Results = preload("res://scripts/interaction/desktop/lms/lms_results.gd")


func _initialize() -> void:
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
		menu._show_load()
		assert(menu.get_node("%SaveList").item_count == 3)
		print("PASS: settings and save catalog persist across sessions")
		menu._quit()
		return
	assert(paused)
	assert(menu.get_node("%Load").disabled)
	menu._show_load()
	assert(not menu.get_node("%LoadPanel").visible)
	menu._new_game()
	assert(menu.get_node("%NewGamePlaceholder").visible)
	assert(current_scene == menu)
	menu.get_node("%NewGamePlaceholder").hide()
	assert(menu.get_node("%NewGame").has_focus())
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
	assert(menu.get_node("%Load").disabled, "Settings must not count as gameplay progress")
	var empty_save := ConfigFile.new()
	empty_save.set_value("notes", "version", 2)
	empty_save.set_value("notes", "complete", PackedInt32Array())
	empty_save.set_value("notes", "attempted", PackedInt32Array())
	assert(empty_save.save("user://classroom_notes.cfg") == OK)
	menu._refresh_saves()
	assert(menu.get_node("%Load").disabled, "Empty progress must not count as a save")
	var notes := root.get_node("ClassroomProgress")
	assert(notes.begin_material(0) == OK)
	assert(notes.finish_material(0, true) == OK)
	menu._refresh_saves()
	assert(not menu.get_node("%Load").disabled)
	menu._show_load()
	assert(menu.get_node("%LoadPanel").visible)
	assert(menu.get_node("%SaveList").item_count == 1)
	assert("1 / 6" in menu.get_node("%SaveDetails").text)
	assert(root.get_node("BlueprintProgress").complete_study("transmission_motor") == OK)
	assert(Results.save_result("menu_catalog_quiz", 3, 10) == OK)
	menu._show_load()
	assert(menu.get_node("%SaveList").item_count == 3)
	menu._select_save(1)
	assert("potongan" in menu.get_node("%SaveDetails").text)
	menu._select_save(2)
	assert("3 / 10" in menu.get_node("%SaveDetails").text)
	menu._show_main()
	assert(menu.get_node("%NewGame").has_focus())
	print("PASS: menu entry, placeholder, disabled empty Load, save listing, volume preview/cancel, settings save, keyboard focus, Quit")
	menu._quit()
