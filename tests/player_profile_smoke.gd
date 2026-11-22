extends SceneTree


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var saves := root.get_node("GameSave")
	var stats := root.get_node("PlayerStats")
	var journal := root.get_node("PlayerJournal")
	var notes := root.get_node("ClassroomProgress")
	var clock := root.get_node("GameClock")
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	current_scene._new_game()
	await process_frame
	assert(current_scene.get_node("%NameDialog").visible)
	assert(current_scene.get_node("%NameDialog").get_ok_button().disabled)
	current_scene.get_node("%PlayerName").text = "   "
	current_scene._create_game()
	assert(current_scene.scene_file_path.ends_with("main_menu.tscn"))
	current_scene.get_node("%PlayerName").text = "  Reksa Aditya  "
	current_scene.get_node("%NameDialog").hide()
	current_scene._create_game()
	await scene_changed
	await physics_frame
	assert(stats.player_name == "Reksa Aditya")
	var id: String = stats.student_id
	assert(id.length() == 12 and id.begins_with("607") and id.is_valid_int())
	var profile := current_scene.get_node("PlayerProfile")
	assert(not current_scene.has_node("DesktopAccess"))
	clock.restore_save_state({"minutes": 1501, "remainder": 0})
	assert(profile._hud_clock.text == "01:01")
	assert(profile._profile_clock.text == "01:01")
	assert(profile._profile_date.text == "Hari 2 · Minggu 1")
	clock.restore_save_state({"minutes": 0, "remainder": 0})
	profile.open_profile()
	assert(paused and profile._popup.visible)
	var world := current_scene
	profile._show_settings()
	assert(profile._settings.visible and not profile._overview.visible)
	var settings_time: int = clock.get_absolute_minutes()
	await create_timer(1.2).timeout
	assert(clock.get_absolute_minutes() == settings_time)
	profile._volume.value = 0
	assert(AudioServer.is_bus_mute(0))
	profile._show_overview()
	assert(not AudioServer.is_bus_mute(0))
	profile._show_settings()
	profile._volume.value = 37
	profile._resolution.select(0)
	if "--capture" in OS.get_cmdline_user_args():
		print("CAPTURE: applying profile settings")
	profile._apply_settings()
	if "--capture" in OS.get_cmdline_user_args():
		print("CAPTURE: settings applied")
	assert(is_equal_approx(root.get_node("GameSettings").master_volume, 0.37))
	assert(root.get_node("GameSettings").resolution_index == 0)
	assert(current_scene == world and paused)
	profile._volume.value = 0
	profile._popup.hide()
	assert(not AudioServer.is_bus_mute(0) and not paused)
	profile.open_profile()
	var before: int = clock.get_absolute_minutes()
	await create_timer(1.2).timeout
	assert(clock.get_absolute_minutes() > before)
	assert(profile._profile_clock.text == clock.get_formatted_time())
	stats.set_energy(65)
	stats.set_sanity(72)
	stats.set_gpa(3.65)
	assert(profile._hud_energy.value == 65)
	profile._show_status()
	assert(profile._status.visible)
	assert(profile._status_bars[2].value == 3.65)
	clock.seconds_per_minute = 0.05
	before = clock.get_absolute_minutes()
	await create_timer(0.15).timeout
	assert(clock.get_absolute_minutes() > before)
	profile._show_journal()
	assert(journal.get_entries().is_empty())
	before = clock.get_absolute_minutes()
	await create_timer(0.15).timeout
	assert(clock.get_absolute_minutes() > before)
	clock.seconds_per_minute = 1.0
	profile._popup.hide()
	assert(not paused)
	assert(clock.process_mode == Node.PROCESS_MODE_INHERIT)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	profile.open_profile()
	profile._show_settings()
	profile._popup_input(escape)
	assert(profile._overview.visible and clock.process_mode == Node.PROCESS_MODE_ALWAYS)
	profile._show_status()
	profile._popup_input(escape)
	assert(profile._overview.visible and paused)
	profile._popup_input(escape)
	assert(not paused and not profile._popup.visible)
	assert(journal.record_classroom(18) == ERR_UNAUTHORIZED)
	for index: int in 6:
		assert(notes.begin_material(index) == OK)
		assert(notes.finish_material(index, index != 2) == OK)
	assert(journal.record_classroom(18) == OK)
	assert(journal.get_entries()[0].semester == 2 and journal.get_entries()[0].week == 2)
	assert("catatan kosong" in journal.get_entries()[0].body)
	assert(journal.record_classroom(18) == OK)
	assert(journal.get_entries().size() == 1)
	assert(journal.record_project("test_machine", "Mesin Uji", 0) == OK)
	profile.open_profile()
	profile._show_journal()
	assert(profile._entries.get_child_count() == 1)
	profile._semester.select(1)
	profile._week.select(2)
	profile._refresh_journal()
	assert(profile._entries.get_child(0).get_child(0).get_child(0).text == "Semester 2 · Minggu 2")
	profile._kind.select(1)
	profile._semester.select(profile._semester.item_count - 1)
	profile._refresh_journal()
	assert(profile._week.disabled)
	assert(profile._entries.get_child(0).get_child(0).get_child(0).text == "Arsip Lama")
	profile._popup.hide()
	assert(saves.save_now() == OK)
	saves._enabled = false
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	current_scene._new_game()
	current_scene.get_node("%NewGameConfirm").hide()
	current_scene._start_new_game()
	await process_frame
	current_scene.get_node("%NameDialog").hide()
	assert(stats.student_id == id and journal.get_entries().size() == 2)
	assert(saves.load_game() == OK)
	await scene_changed
	await physics_frame
	assert(stats.student_id == id and stats.player_name == "Reksa Aditya")
	assert(stats.get_energy() == 65 and stats.get_gpa() == 3.65)
	assert(journal.get_entries().size() == 2)
	if "--capture" in OS.get_cmdline_user_args():
		print("CAPTURE: rendering profile pages")
		await _capture()
	assert(saves.start_new_game("Kehidupan Baru") == OK)
	await scene_changed
	await physics_frame
	assert(stats.player_name == "Kehidupan Baru" and stats.student_id != id)
	assert(stats.get_energy() == 100 and stats.get_gpa() == 0)
	assert(journal.get_entries().is_empty())
	for index: int in 6:
		assert(notes.begin_material(index) == OK)
		assert(notes.finish_material(index, true) == OK)
	assert(journal.sync_legacy() == OK)
	assert(journal.get_entries()[0].semester == 0)
	assert(journal.record_desktop_note("user://notes/test.txt", "Catatan awal", 17) == OK)
	assert(journal.record_desktop_note("user://notes/test.txt", "Catatan diperbarui", 18) == OK)
	assert(journal.get_entries().size() == 2)
	assert(journal.get_entries()[1].body == "Catatan diperbarui")
	assert(journal.get_entries()[1].semester == 2 and journal.get_entries()[1].week == 1)
	assert(DirAccess.make_dir_recursive_absolute("user://notes") == OK)
	var notepad: Node = load("res://scenes/interaction/desktop/notepad.tscn").instantiate()
	current_scene.add_child(notepad)
	notepad.get_node("Editor").text = "Catatan dari Notepad"
	notepad._save_document("user://notes/notepad_test.txt")
	assert(journal.get_entries().size() == 3)
	assert(journal.get_entries()[2].body == "Catatan dari Notepad")
	assert(journal.get_entries()[2].semester == 1 and journal.get_entries()[2].week == 1)
	notepad.queue_free()
	var legacy := ConfigFile.new()
	assert(saves.save_now() == OK)
	assert(legacy.load(saves.SAVE_PATH) == OK)
	legacy.set_value("save", "version", 1)
	legacy.erase_section("profile")
	assert(legacy.save(saves.SAVE_PATH) == OK)
	assert(saves.load_game() == OK)
	await scene_changed
	assert(stats.student_id.length() == 12)
	print("PASS: name entry, random ID, pause, status binding, dated and legacy journals, filters, autosave/load, cancellation, new game reset, v1 compatibility")
	quit()


func _capture() -> void:
	var profile := current_scene.get_node("PlayerProfile")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/profile-hud.png")
	profile.open_profile()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/profile-overview.png")
	profile._show_status()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/profile-status.png")
	profile._show_settings()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/profile-settings.png")
	profile._show_journal()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/profile-journal.png")
	profile._popup.hide()
	root.size = Vector2i(720, 480)
	root.content_scale_size = Vector2i(720, 480)
	await process_frame
	profile.open_profile()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/profile-small.png")
	profile._popup.hide()
